#!/usr/bin/env python3
"""Audit Vex parse-only coverage against the local Graphviz DOT corpus."""

from __future__ import annotations

import argparse
import concurrent.futures
import re
import subprocess
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


HTML_LABEL_RE = re.compile(
    rb"(?i)\b(?:label|xlabel|headlabel|taillabel)\s*=\s*<"
)
KNOWN_MALFORMED = {
    Path("1308_1.dot"),
    Path("1411.dot"),
    Path("1489.dot"),
    Path("1676.dot"),
}
KNOWN_PLAIN_OUTPUT = {Path("share/b545.gv")}
BASELINE = {
    "candidates": 786,
    "html": 59,
    "ok": 722,
    "malformed": 4,
    "plain": 1,
    "timeout": 0,
    "unexpected": 0,
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


def check_baseline(counts: Counter[str]) -> list[str]:
    failures = []
    for name, expected in BASELINE.items():
        actual = counts[name]
        if actual != expected:
            failures.append(f"{name}: expected {expected}, got {actual}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("graphviz_root", type=Path, help="Graphviz source checkout")
    parser.add_argument("--vex", type=Path, required=True, help="ReleaseFast Vex CLI")
    parser.add_argument("--max-bytes", type=int, default=256 * 1024)
    parser.add_argument("--timeout", type=float, default=2.0)
    parser.add_argument("--jobs", type=int, default=8)
    args = parser.parse_args()

    tests_root = args.graphviz_root / "tests"
    if not tests_root.is_dir():
        raise SystemExit(f"Graphviz tests directory not found: {tests_root}")
    if not args.vex.is_file():
        raise SystemExit(f"Vex executable not found: {args.vex}")

    candidates = candidate_files(tests_root, args.max_bytes)
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

    failures = check_baseline(counts)
    if failures:
        for failure in failures:
            print(f"baseline mismatch: {failure}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
