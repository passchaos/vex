#!/usr/bin/env python3
"""Compare Vex and Graphviz layout quality on a fixed real-world fixture.

This development gate intentionally compares invariant quality metrics rather
than exact coordinates: node overlap count, straight center-line crossings,
normalized mean edge length, and normalized canvas area.
"""

from __future__ import annotations

import argparse
import math
import re
import shlex
import subprocess
import tempfile
from pathlib import Path


ATTR_RE = re.compile(rb'\b([A-Za-z][A-Za-z0-9_-]*)="([^"]*)"')
VEX_NODE_RE = re.compile(rb"<vex:node\b([^>]*)/>")
VEX_EDGE_RE = re.compile(rb"<vex:edge\b([^>]*?)(?:/>|>)")
VEX_GRAPH_RE = re.compile(rb"<vex:graph\b([^>]*)>")


def xml_attrs(raw: bytes) -> dict[str, str]:
    return {
        key.decode("ascii"): value.decode("utf-8", "replace")
        for key, value in ATTR_RE.findall(raw)
    }


def vex_geometry(
    vex: Path, fixture: Path
) -> tuple[dict[str, tuple[float, float, float, float]], list[tuple[str, str]], tuple[float, float]]:
    with tempfile.NamedTemporaryFile(suffix=".svg") as output:
        result = subprocess.run(
            [str(vex), "--input", str(fixture), "--output", output.name, "--svg-metadata"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
            check=False,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.decode("utf-8", "replace"))
        svg = Path(output.name).read_bytes()

    nodes: dict[str, tuple[float, float, float, float]] = {}
    for match in VEX_NODE_RE.finditer(svg):
        attrs = xml_attrs(match.group(1))
        nodes[attrs["label"]] = tuple(
            float(attrs[name]) for name in ("x", "y", "width", "height")
        )
    edges: list[tuple[str, str]] = []
    for match in VEX_EDGE_RE.finditer(svg):
        attrs = xml_attrs(match.group(1))
        if "from-label" in attrs and "to-label" in attrs:
            edges.append((attrs["from-label"], attrs["to-label"]))
    graph_match = VEX_GRAPH_RE.search(svg)
    if graph_match is None:
        raise RuntimeError("Vex SVG metadata has no graph entry")
    graph_attrs = xml_attrs(graph_match.group(1))
    canvas = (
        float(graph_attrs["layout-width"]),
        float(graph_attrs["layout-height"]),
    )
    return nodes, edges, canvas


def graphviz_geometry(
    fixture: Path,
) -> tuple[dict[str, tuple[float, float, float, float]], list[tuple[str, str]], tuple[float, float]]:
    result = subprocess.run(
        ["dot", "-Tplain", str(fixture)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=10,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", "replace"))
    nodes: dict[str, tuple[float, float, float, float]] = {}
    edges: list[tuple[str, str]] = []
    canvas = (0.0, 0.0)
    for line in result.stdout.decode("utf-8", "replace").splitlines():
        fields = shlex.split(line)
        if not fields:
            continue
        if fields[0] == "graph":
            canvas = (float(fields[2]) * 72.0, float(fields[3]) * 72.0)
        elif fields[0] == "node":
            nodes[fields[1]] = (
                float(fields[2]) * 72.0,
                float(fields[3]) * 72.0,
                float(fields[4]) * 72.0,
                float(fields[5]) * 72.0,
            )
        elif fields[0] == "edge":
            edges.append((fields[1], fields[2]))
    return nodes, edges, canvas


def quality(
    nodes: dict[str, tuple[float, float, float, float]],
    edges: list[tuple[str, str]],
    canvas: tuple[float, float],
) -> tuple[int, int, float, float]:
    node_ids = list(nodes)
    overlaps = 0
    for index, left_id in enumerate(node_ids):
        left = nodes[left_id]
        for right_id in node_ids[index + 1 :]:
            right = nodes[right_id]
            if (
                max(left[0] - left[2] / 2, right[0] - right[2] / 2)
                < min(left[0] + left[2] / 2, right[0] + right[2] / 2) - 1e-7
                and max(left[1] - left[3] / 2, right[1] - right[3] / 2)
                < min(left[1] + left[3] / 2, right[1] + right[3] / 2) - 1e-7
            ):
                overlaps += 1

    segments: list[tuple[str, str, tuple[float, float], tuple[float, float]]] = []
    total_length = 0.0
    for source, target in edges:
        if source == target or source not in nodes or target not in nodes:
            continue
        start = nodes[source][:2]
        end = nodes[target][:2]
        total_length += math.dist(start, end)
        segments.append((source, target, start, end))
    crossings = 0
    for index, (source, target, start, end) in enumerate(segments):
        for other_source, other_target, other_start, other_end in segments[index + 1 :]:
            if len({source, target, other_source, other_target}) < 4:
                continue
            if segments_cross(start, end, other_start, other_end):
                crossings += 1

    node_area = sum(width * height for _, _, width, height in nodes.values())
    mean_node_scale = max(math.sqrt(node_area / max(len(nodes), 1)), 1e-9)
    mean_edge_length = total_length / max(len(edges), 1) / mean_node_scale
    normalized_area = canvas[0] * canvas[1] / max(node_area, 1e-9)
    return overlaps, crossings, mean_edge_length, normalized_area


def segments_cross(
    a: tuple[float, float],
    b: tuple[float, float],
    c: tuple[float, float],
    d: tuple[float, float],
) -> bool:
    def orientation(
        left: tuple[float, float],
        middle: tuple[float, float],
        right: tuple[float, float],
    ) -> float:
        return (middle[0] - left[0]) * (right[1] - left[1]) - (
            middle[1] - left[1]
        ) * (right[0] - left[0])

    return (
        orientation(a, b, c) * orientation(a, b, d) < -1e-9
        and orientation(c, d, a) * orientation(c, d, b) < -1e-9
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("graphviz_root", type=Path)
    parser.add_argument("--vex", type=Path, required=True)
    args = parser.parse_args()
    fixture = args.graphviz_root / "tests" / "graphs" / "ngk10_4.gv"
    vex_score = quality(*vex_geometry(args.vex, fixture))
    graphviz_score = quality(*graphviz_geometry(fixture))
    print(
        "layout-quality-audit ngk10_4 "
        f"vex_overlap={vex_score[0]} vex_crossings={vex_score[1]} "
        f"vex_edge_length={vex_score[2]:.3f} vex_area={vex_score[3]:.3f} "
        f"graphviz_overlap={graphviz_score[0]} graphviz_crossings={graphviz_score[1]} "
        f"graphviz_edge_length={graphviz_score[2]:.3f} graphviz_area={graphviz_score[3]:.3f}"
    )
    if vex_score[0] != 0:
        raise SystemExit("Vex introduced node overlaps")
    if vex_score[1] > 260:
        raise SystemExit("Vex crossing count regressed above 260")
    if vex_score[2] > graphviz_score[2] * 0.75:
        raise SystemExit("Vex normalized mean edge length is not at least 25% shorter")
    if vex_score[3] > graphviz_score[3]:
        raise SystemExit("Vex normalized canvas area exceeds Graphviz")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
