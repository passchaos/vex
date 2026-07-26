#!/usr/bin/env python3
"""Audit Vex parse-only coverage against the local Graphviz DOT corpus."""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ElementTree
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


HTML_LABEL_RE = re.compile(
    rb"(?i)\b(?:label|xlabel|headlabel|taillabel)\s*=\s*<"
)
CLUSTER_RE = re.compile(rb"(?i)\bsubgraph\b|\bcluster\b")
SUBGRAPH_METADATA_RE = re.compile(rb"<vex:subgraph\b([^>]*)/>")
XML_ATTR_RE = re.compile(rb'\b([A-Za-z][A-Za-z0-9_-]*)="([^"]*)"')
NONFINITE_ATTR_RE = re.compile(
    rb'="[^"]*(?<![A-Za-z])(?:nan|[+-]?inf)(?![A-Za-z])[^"]*"',
    re.IGNORECASE,
)
KNOWN_MALFORMED = {
    Path("1308_1.dot"),
    Path("1411.dot"),
    Path("1474.dot"),
    Path("1489.dot"),
    Path("1676.dot"),
}
KNOWN_PLAIN_OUTPUT = {Path("share/b545.gv")}
KNOWN_SLOW_SVG: set[Path] = set()
KNOWN_LARGE_SLOW_SVG = {
    Path("2064.dot"),
    Path("2108.dot"),
    Path("2593.dot"),
}
LARGE_SVG_MIN_BYTES = 256 * 1024
BASELINE = {
    "candidates": 808,
    "html": 65,
    "ok": 737,
    "malformed": 5,
    "plain": 1,
    "timeout": 0,
    "unexpected": 0,
}
CLUSTER_BASELINE = {
    "candidates": 259,
    "ok": 257,
    "malformed": 2,
    "timeout": 0,
    "failed": 0,
    "invalid_svg": 0,
    "invalid_hierarchy": 0,
}
SVG_BASELINE = {
    "candidates": 727,
    "ok": 722,
    "excluded": 5,
    "slow": 0,
    "timeout": 0,
    "failed": 0,
    "nonfinite": 0,
    "invalid_svg": 0,
}
LARGE_SVG_BASELINE = {
    "candidates": 16,
    "ok": 12,
    "malformed": 1,
    "slow": 3,
    "timeout": 0,
    "failed": 0,
    "nonfinite": 0,
    "invalid_svg": 0,
}


@dataclass(frozen=True)
class AuditResult:
    kind: str
    path: Path
    detail: str = ""


def candidate_files(tests_root: Path, max_bytes: int) -> list[Path]:
    return sorted(
        path
        for path in tests_root.rglob("*")
        if path.is_file()
        and path.suffix in {".dot", ".gv"}
        and path.stat().st_size < max_bytes
    )


def parse_one(vex: Path, tests_root: Path, path: Path, timeout: float) -> AuditResult:
    relative = path.relative_to(tests_root)
    try:
        result = subprocess.run(
            [str(vex), "--check", "--input", str(path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return AuditResult("timeout", relative)

    if result.returncode == 0:
        if relative in KNOWN_MALFORMED or relative in KNOWN_PLAIN_OUTPUT:
            return AuditResult("unexpected", relative, "known exclusion parsed successfully")
        return AuditResult("ok", relative)

    stderr = result.stderr.decode("utf-8", "replace").strip().splitlines()
    detail = stderr[0] if stderr else f"exit {result.returncode}"
    if relative in KNOWN_MALFORMED:
        return AuditResult("malformed", relative, detail)
    if relative in KNOWN_PLAIN_OUTPUT:
        return AuditResult("plain", relative, detail)
    return AuditResult("unexpected", relative, detail)


def check_baseline(counts: Counter[str], baseline: dict[str, int]) -> list[str]:
    failures = []
    for name, expected in baseline.items():
        actual = counts[name]
        if actual != expected:
            failures.append(f"{name}: expected {expected}, got {actual}")
    return failures


def render_one(
    vex: Path,
    tests_root: Path,
    output_root: Path,
    path: Path,
    timeout: float,
    metadata: bool = True,
) -> AuditResult:
    relative = path.relative_to(tests_root)
    if relative in KNOWN_MALFORMED:
        return AuditResult("malformed", relative)
    output_name = hashlib.sha256(str(relative).encode("utf-8")).hexdigest() + ".svg"
    output = output_root / output_name
    try:
        command = [str(vex), "--input", str(path), "--output", str(output)]
        if metadata:
            command.append("--svg-metadata")
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return AuditResult("timeout", relative)
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", "replace").strip().splitlines()
        return AuditResult(
            "failed",
            relative,
            stderr[0] if stderr else f"exit {result.returncode}",
        )
    svg = output.read_bytes() if output.is_file() else b""
    xml_error = validate_svg_documents(svg)
    if xml_error:
        return AuditResult("invalid_svg", relative, xml_error)
    if NONFINITE_ATTR_RE.search(svg):
        return AuditResult("nonfinite", relative)
    if metadata:
        hierarchy_error = validate_subgraph_hierarchy(svg)
        if hierarchy_error:
            return AuditResult("invalid_hierarchy", relative, hierarchy_error)
    return AuditResult("ok", relative, f"bytes={len(svg)}")


def validate_svg_documents(svg: bytes) -> str:
    starts = [match.start() for match in re.finditer(rb"<svg\b", svg)]
    ends = [match.end() for match in re.finditer(rb"</svg>", svg)]
    if not starts:
        return "no SVG root"
    if len(starts) != len(ends):
        return f"roots={len(starts)} closes={len(ends)}"
    try:
        svg.decode("utf-8")
    except UnicodeDecodeError as error:
        return str(error)
    for start, end in zip(starts, ends):
        try:
            ElementTree.fromstring(svg[start:end])
        except ElementTree.ParseError as error:
            return str(error)
    return ""


def validate_subgraph_hierarchy(svg: bytes) -> str:
    boxes: dict[int, tuple[int | None, float, float, float, float]] = {}
    for match in SUBGRAPH_METADATA_RE.finditer(svg):
        attrs = {
            name.decode("ascii"): value.decode("utf-8", "replace")
            for name, value in XML_ATTR_RE.findall(match.group(1))
        }
        if not {"id", "x", "y", "width", "height"} <= attrs.keys():
            continue
        graph_id = int(attrs["id"])
        boxes[graph_id] = (
            int(attrs["parent"]) if "parent" in attrs else None,
            float(attrs["x"]),
            float(attrs["y"]),
            float(attrs["width"]),
            float(attrs["height"]),
        )
    epsilon = 0.02
    for graph_id, (parent_id, x, y, width, height) in boxes.items():
        if parent_id is None or width <= epsilon or height <= epsilon:
            continue
        parent = boxes.get(parent_id)
        if parent is None:
            return f"subgraph {graph_id} missing parent {parent_id}"
        _, px, py, pwidth, pheight = parent
        if pwidth <= epsilon or pheight <= epsilon:
            return f"subgraph {graph_id} has empty parent {parent_id}"
        if (
            x < px - epsilon
            or y < py - epsilon
            or x + width > px + pwidth + epsilon
            or y + height > py + pheight + epsilon
        ):
            return (
                f"subgraph {graph_id} box=({x},{y},{width},{height}) outside "
                f"parent {parent_id}=({px},{py},{pwidth},{pheight})"
            )
    return ""


def run_cluster_audit(
    vex: Path,
    tests_root: Path,
    candidates: list[Path],
    timeout: float,
    jobs: int,
) -> int:
    paths = [
        path
        for path in candidates
        if not HTML_LABEL_RE.search(path.read_bytes())
        and CLUSTER_RE.search(path.read_bytes())
    ]
    with tempfile.TemporaryDirectory(prefix="vex-cluster-audit-") as output_dir:
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(jobs, 1)) as pool:
            results = list(
                pool.map(
                    lambda path: render_one(
                        vex,
                        tests_root,
                        Path(output_dir),
                        path,
                        timeout,
                        True,
                    ),
                    paths,
                )
            )
    counts: Counter[str] = Counter(result.kind for result in results)
    counts["candidates"] = len(paths)
    print(
        "cluster-layout-audit "
        + " ".join(f"{name}={counts[name]}" for name in CLUSTER_BASELINE)
    )
    for result in results:
        if result.kind in {"timeout", "failed", "invalid_svg", "invalid_hierarchy"}:
            suffix = f": {result.detail}" if result.detail else ""
            print(f"{result.kind}: {result.path}{suffix}")
    failures = check_baseline(counts, CLUSTER_BASELINE)
    if failures:
        for failure in failures:
            print(f"cluster baseline mismatch: {failure}")
        return 1
    return 0


def run_svg_audit(
    vex: Path,
    tests_root: Path,
    candidates: list[Path],
    timeout: float,
    jobs: int,
) -> int:
    paths = [path for path in candidates if not HTML_LABEL_RE.search(path.read_bytes())]
    with tempfile.TemporaryDirectory(prefix="vex-svg-audit-") as output_dir:
        output_root = Path(output_dir)

        def render(path: Path) -> AuditResult:
            relative = path.relative_to(tests_root)
            if relative in KNOWN_MALFORMED or relative in KNOWN_PLAIN_OUTPUT:
                return AuditResult("excluded", relative)
            if relative in KNOWN_SLOW_SVG:
                return AuditResult("slow", relative)
            return render_one(vex, tests_root, output_root, path, timeout, False)

        with concurrent.futures.ThreadPoolExecutor(max_workers=max(jobs, 1)) as pool:
            results = list(pool.map(render, paths))
    counts: Counter[str] = Counter(result.kind for result in results)
    counts["candidates"] = len(paths)
    print(
        "svg-corpus-audit "
        + " ".join(f"{name}={counts[name]}" for name in SVG_BASELINE)
    )
    for result in results:
        if result.kind in {"timeout", "failed", "nonfinite", "invalid_svg"}:
            suffix = f": {result.detail}" if result.detail else ""
            print(f"{result.kind}: {result.path}{suffix}")
    failures = check_baseline(counts, SVG_BASELINE)
    if failures:
        for failure in failures:
            print(f"SVG baseline mismatch: {failure}")
        return 1
    return 0


def run_large_svg_audit(
    vex: Path,
    tests_root: Path,
    candidates: list[Path],
    timeout: float,
    jobs: int,
) -> int:
    paths = [
        path
        for path in candidates
        if path.stat().st_size >= LARGE_SVG_MIN_BYTES
        and not HTML_LABEL_RE.search(path.read_bytes())
    ]
    with tempfile.TemporaryDirectory(prefix="vex-large-svg-audit-") as output_dir:
        output_root = Path(output_dir)

        def render(path: Path) -> AuditResult:
            relative = path.relative_to(tests_root)
            if relative in KNOWN_MALFORMED:
                return AuditResult("malformed", relative)
            if relative in KNOWN_LARGE_SLOW_SVG:
                return AuditResult("slow", relative)
            return render_one(vex, tests_root, output_root, path, timeout, False)

        with concurrent.futures.ThreadPoolExecutor(max_workers=max(jobs, 1)) as pool:
            results = list(pool.map(render, paths))
    counts: Counter[str] = Counter(result.kind for result in results)
    counts["candidates"] = len(paths)
    print(
        "large-svg-corpus-audit "
        + " ".join(f"{name}={counts[name]}" for name in LARGE_SVG_BASELINE)
    )
    for result in results:
        if result.kind in {"timeout", "failed", "nonfinite", "invalid_svg"}:
            suffix = f": {result.detail}" if result.detail else ""
            print(f"{result.kind}: {result.path}{suffix}")
    failures = check_baseline(counts, LARGE_SVG_BASELINE)
    if failures:
        for failure in failures:
            print(f"large SVG baseline mismatch: {failure}")
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("graphviz_root", type=Path, help="Graphviz source checkout")
    parser.add_argument("--vex", type=Path, required=True, help="ReleaseFast Vex CLI")
    parser.add_argument("--max-bytes", type=int, default=16 * 1024 * 1024)
    parser.add_argument("--timeout", type=float, default=2.0)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--render-clusters", action="store_true")
    parser.add_argument("--render-all", action="store_true")
    parser.add_argument("--render-large", action="store_true")
    args = parser.parse_args()

    tests_root = args.graphviz_root / "tests"
    if not tests_root.is_dir():
        raise SystemExit(f"Graphviz tests directory not found: {tests_root}")
    if not args.vex.is_file():
        raise SystemExit(f"Vex executable not found: {args.vex}")

    candidates = candidate_files(tests_root, args.max_bytes)
    if args.render_large:
        return run_large_svg_audit(
            args.vex,
            tests_root,
            candidates,
            args.timeout,
            args.jobs,
        )
    if args.render_all:
        return run_svg_audit(
            args.vex,
            tests_root,
            candidates,
            args.timeout,
            args.jobs,
        )
    if args.render_clusters:
        return run_cluster_audit(
            args.vex,
            tests_root,
            candidates,
            args.timeout,
            args.jobs,
        )
    html_paths = []
    parse_paths = []
    for path in candidates:
        if HTML_LABEL_RE.search(path.read_bytes()):
            html_paths.append(path)
        else:
            parse_paths.append(path)

    results: list[AuditResult] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(args.jobs, 1)) as pool:
        for result in pool.map(
            lambda path: parse_one(args.vex, tests_root, path, args.timeout),
            parse_paths,
        ):
            results.append(result)

    counts: Counter[str] = Counter(result.kind for result in results)
    counts["candidates"] = len(candidates)
    counts["html"] = len(html_paths)
    print(
        "dot-corpus-audit "
        + " ".join(f"{name}={counts[name]}" for name in BASELINE)
    )

    for result in results:
        if result.kind in {"timeout", "unexpected"}:
            suffix = f": {result.detail}" if result.detail else ""
            print(f"{result.kind}: {result.path}{suffix}")

    failures = check_baseline(counts, BASELINE)
    if failures:
        for failure in failures:
            print(f"baseline mismatch: {failure}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
