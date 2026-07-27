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
    vex: Path, fixture: Path, layout: str | None = None
) -> tuple[dict[str, tuple[float, float, float, float]], list[tuple[str, str]], tuple[float, float]]:
    with tempfile.NamedTemporaryFile(suffix=".svg") as output:
        command = [
            str(vex),
            "--input",
            str(fixture),
            "--output",
            output.name,
            "--svg-metadata",
        ]
        if layout is not None:
            command.extend(("--layout", layout))
        result = subprocess.run(
            command,
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
        # Display labels are not identities: real corpora such as 1332.dot
        # contain many nodes with the same record label. Metadata IDs and edge
        # endpoint IDs preserve the actual graph topology.
        nodes[attrs["id"]] = tuple(
            float(attrs[name]) for name in ("x", "y", "width", "height")
        )
    edges: list[tuple[str, str]] = []
    for match in VEX_EDGE_RE.finditer(svg):
        attrs = xml_attrs(match.group(1))
        if "from" in attrs and "to" in attrs:
            edges.append((attrs["from"], attrs["to"]))
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
    fixture: Path, engine: str = "dot",
) -> tuple[dict[str, tuple[float, float, float, float]], list[tuple[str, str]], tuple[float, float]]:
    result = subprocess.run(
        [engine, "-Tplain", str(fixture)],
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


def force_quality(
    nodes: dict[str, tuple[float, float, float, float]],
    edges: list[tuple[str, str]],
) -> tuple[float, float]:
    lengths = [
        math.dist(nodes[source][:2], nodes[target][:2])
        for source, target in edges
        if source != target and source in nodes and target in nodes
    ]
    mean_length = sum(lengths) / max(len(lengths), 1)
    coefficient_of_variation = (
        math.sqrt(
            sum((length - mean_length) ** 2 for length in lengths)
            / max(len(lengths), 1)
        )
        / max(mean_length, 1e-9)
    )

    node_ids = list(nodes)
    node_index = {node_id: index for index, node_id in enumerate(node_ids)}
    node_count = len(node_ids)
    distances = [[node_count + 1] * node_count for _ in range(node_count)]
    for node_id in range(node_count):
        distances[node_id][node_id] = 0
    for source, target in edges:
        if source not in node_index or target not in node_index:
            continue
        left = node_index[source]
        right = node_index[target]
        distances[left][right] = 1
        distances[right][left] = 1
    for middle in range(node_count):
        for left in range(node_count):
            for right in range(node_count):
                distances[left][right] = min(
                    distances[left][right],
                    distances[left][middle] + distances[middle][right],
                )
    pairs: list[tuple[float, float]] = []
    for left in range(node_count):
        for right in range(left + 1, node_count):
            graph_distance = distances[left][right]
            if graph_distance > node_count:
                continue
            geometric_distance = math.dist(
                nodes[node_ids[left]][:2], nodes[node_ids[right]][:2]
            )
            pairs.append((float(graph_distance), geometric_distance))
    scale = sum(
        graph_distance * geometric_distance
        for graph_distance, geometric_distance in pairs
    ) / max(
        sum(graph_distance * graph_distance for graph_distance, _ in pairs), 1e-9
    )
    stress = sum(
        (
            (geometric_distance - scale * graph_distance)
            / max(scale * graph_distance, 1e-9)
        )
        ** 2
        for graph_distance, geometric_distance in pairs
    ) / max(len(pairs), 1)
    return coefficient_of_variation, stress


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
    cases = (
        (
            "ngk10_4",
            args.graphviz_root / "tests" / "graphs" / "ngk10_4.gv",
            190,
            0.75,
            1.10,
        ),
        (
            "overlap",
            args.graphviz_root / "tests" / "graphs" / "overlap.gv",
            200,
            1.00,
            1.05,
        ),
        (
            "fig6",
            args.graphviz_root / "tests" / "graphs" / "fig6.gv",
            60,
            1.15,
            1.10,
        ),
        (
            "world",
            args.graphviz_root / "tests" / "graphs" / "world.gv",
            59,
            1.20,
            1.40,
        ),
        (
            "world-annotated",
            args.graphviz_root / "tests" / "share" / "world.gv",
            59,
            1.35,
            1.40,
        ),
        (
            "shells",
            args.graphviz_root / "tests" / "share" / "shells.gv",
            8,
            1.05,
            1.18,
        ),
        (
            "698066",
            args.graphviz_root / "tests" / "698066.dot",
            17,
            1.00,
            1.00,
        ),
        (
            "1855",
            args.graphviz_root / "tests" / "1855.dot",
            0,
            1.00,
            1.03,
        ),
        (
            "1767",
            args.graphviz_root / "tests" / "1767.dot",
            0,
            1.10,
            1.36,
        ),
        (
            "2825",
            args.graphviz_root / "tests" / "2825.dot",
            3,
            1.15,
            1.00,
        ),
        (
            "2784",
            args.graphviz_root / "tests" / "2784.dot",
            0,
            1.00,
            1.40,
        ),
        (
            "2734",
            args.graphviz_root / "tests" / "2734.dot",
            0,
            1.02,
            1.22,
        ),
        (
            "clust5-roundtrip",
            args.graphviz_root / "tests" / "share" / "clust5.gv",
            0,
            1.05,
            1.00,
        ),
        (
            "pmpipe",
            args.graphviz_root / "tests" / "graphs" / "pmpipe.gv",
            0,
            1.06,
            1.20,
        ),
        (
            "b58",
            args.graphviz_root / "tests" / "graphs" / "b58.gv",
            1,
            1.05,
            1.12,
        ),
        (
            "1658",
            args.graphviz_root / "tests" / "1658.dot",
            4,
            1.13,
            1.00,
        ),
        (
            "grdcolors",
            args.graphviz_root / "tests" / "graphs" / "grdcolors.gv",
            0,
            1.00,
            1.04,
        ),
        (
            "grammar-roundtrip",
            args.graphviz_root / "tests" / "share" / "grammar.gv",
            0,
            1.00,
            1.00,
        ),
        (
            "awilliams",
            args.graphviz_root / "tests" / "graphs" / "awilliams.gv",
            0,
            1.20,
            1.20,
        ),
        (
            "b57",
            args.graphviz_root / "tests" / "graphs" / "b57.gv",
            1,
            1.00,
            1.00,
        ),
        (
            "abstract",
            args.graphviz_root / "tests" / "graphs" / "abstract.gv",
            57,
            1.21,
            1.01,
        ),
        (
            "b71",
            args.graphviz_root / "tests" / "graphs" / "b71.gv",
            6,
            1.45,
            1.06,
        ),
        (
            "mike",
            args.graphviz_root / "tests" / "graphs" / "mike.gv",
            6,
            1.12,
            1.52,
        ),
        (
            "NaN",
            args.graphviz_root / "tests" / "graphs" / "NaN.gv",
            48,
            1.00,
            1.00,
        ),
        (
            "rowe",
            args.graphviz_root / "tests" / "graphs" / "rowe.gv",
            52,
            1.16,
            1.41,
        ),
        (
            "Heawood",
            args.graphviz_root / "tests" / "graphs" / "Heawood.gv",
            1,
            1.00,
            1.00,
        ),
        (
            "unix2",
            args.graphviz_root / "tests" / "graphs" / "unix2.gv",
            2,
            1.15,
            1.25,
        ),
        (
            "unix2-roundtrip",
            args.graphviz_root / "tests" / "share" / "unix2.gv",
            2,
            1.15,
            1.25,
        ),
        (
            "rankdir-roundtrip",
            args.graphviz_root / "tests" / "linux.x86" / "rankdir_dot.gv",
            4,
            1.00,
            1.14,
        ),
        (
            "pgram",
            args.graphviz_root / "tests" / "graphs" / "pgram.gv",
            0,
            1.57,
            1.45,
        ),
        (
            "dfa",
            args.graphviz_root / "tests" / "graphs" / "dfa.gv",
            0,
            1.05,
            1.30,
        ),
        (
            "proc3d",
            args.graphviz_root / "tests" / "graphs" / "proc3d.gv",
            0,
            1.30,
            1.00,
        ),
        (
            "1332",
            args.graphviz_root / "tests" / "1332.dot",
            9,
            1.20,
            1.55,
        ),
    )
    aggregate_vex_crossings = 0
    aggregate_graphviz_crossings = 0
    for name, fixture, crossing_limit, edge_length_limit, area_limit in cases:
        vex_score = quality(*vex_geometry(args.vex, fixture))
        graphviz_score = quality(*graphviz_geometry(fixture))
        print(
            f"layout-quality-audit {name} "
            f"vex_overlap={vex_score[0]} vex_crossings={vex_score[1]} "
            f"vex_edge_length={vex_score[2]:.3f} vex_area={vex_score[3]:.3f} "
            f"graphviz_overlap={graphviz_score[0]} graphviz_crossings={graphviz_score[1]} "
            f"graphviz_edge_length={graphviz_score[2]:.3f} graphviz_area={graphviz_score[3]:.3f}"
        )
        if vex_score[0] != 0:
            raise SystemExit(f"{name}: Vex introduced node overlaps")
        if vex_score[1] > crossing_limit:
            raise SystemExit(
                f"{name}: Vex crossing count regressed above {crossing_limit}"
            )
        if vex_score[2] > graphviz_score[2] * edge_length_limit:
            raise SystemExit(f"{name}: Vex normalized mean edge length regressed")
        if vex_score[3] > graphviz_score[3] * area_limit:
            raise SystemExit(f"{name}: Vex normalized canvas area regressed")
        aggregate_vex_crossings += vex_score[1]
        aggregate_graphviz_crossings += graphviz_score[1]
    if aggregate_vex_crossings > 772:
        raise SystemExit("aggregate Vex crossing count regressed above 772")
    print(
        "layout-quality-audit aggregate "
        f"vex_crossings={aggregate_vex_crossings} "
        f"graphviz_crossings={aggregate_graphviz_crossings}"
    )

    force_fixture = args.graphviz_root / "tests" / "graphs" / "Petersen.gv"
    vex_force_geometry = vex_geometry(args.vex, force_fixture, "neato")
    graphviz_force_geometry = graphviz_geometry(force_fixture, "neato")
    vex_force_score = quality(*vex_force_geometry)
    graphviz_force_score = quality(*graphviz_force_geometry)
    vex_cv, vex_stress = force_quality(
        vex_force_geometry[0], vex_force_geometry[1]
    )
    graphviz_cv, graphviz_stress = force_quality(
        graphviz_force_geometry[0], graphviz_force_geometry[1]
    )
    print(
        "layout-quality-audit petersen-neato "
        f"vex_overlap={vex_force_score[0]} vex_crossings={vex_force_score[1]} "
        f"vex_edge_cv={vex_cv:.3f} vex_stress={vex_stress:.3f} "
        f"graphviz_overlap={graphviz_force_score[0]} "
        f"graphviz_crossings={graphviz_force_score[1]} "
        f"graphviz_edge_cv={graphviz_cv:.3f} graphviz_stress={graphviz_stress:.3f}"
    )
    if vex_force_score[0] != 0:
        raise SystemExit("petersen-neato: Vex introduced node overlaps")
    if vex_force_score[1] > graphviz_force_score[1]:
        raise SystemExit("petersen-neato: Vex crossing count exceeds Graphviz")
    if vex_cv > graphviz_cv:
        raise SystemExit("petersen-neato: Vex edge-length CV exceeds Graphviz")
    if vex_stress > graphviz_stress:
        raise SystemExit("petersen-neato: Vex stress exceeds Graphviz")

    vex_sfdp_geometry = vex_geometry(args.vex, force_fixture, "sfdp")
    graphviz_sfdp_geometry = graphviz_geometry(force_fixture, "sfdp")
    vex_sfdp_score = quality(*vex_sfdp_geometry)
    graphviz_sfdp_score = quality(*graphviz_sfdp_geometry)
    vex_sfdp_cv, vex_sfdp_stress = force_quality(
        vex_sfdp_geometry[0], vex_sfdp_geometry[1]
    )
    graphviz_sfdp_cv, graphviz_sfdp_stress = force_quality(
        graphviz_sfdp_geometry[0], graphviz_sfdp_geometry[1]
    )
    print(
        "layout-quality-audit petersen-sfdp "
        f"vex_overlap={vex_sfdp_score[0]} vex_crossings={vex_sfdp_score[1]} "
        f"vex_edge_cv={vex_sfdp_cv:.3f} vex_stress={vex_sfdp_stress:.3f} "
        f"graphviz_overlap={graphviz_sfdp_score[0]} "
        f"graphviz_crossings={graphviz_sfdp_score[1]} "
        f"graphviz_edge_cv={graphviz_sfdp_cv:.3f} "
        f"graphviz_stress={graphviz_sfdp_stress:.3f}"
    )
    if vex_sfdp_score[0] != 0:
        raise SystemExit("petersen-sfdp: Vex introduced node overlaps")
    if vex_sfdp_score[1] > graphviz_sfdp_score[1]:
        raise SystemExit("petersen-sfdp: Vex crossing count exceeds Graphviz")
    if vex_sfdp_cv > graphviz_sfdp_cv * 1.20:
        raise SystemExit("petersen-sfdp: Vex edge-length CV is over 20% worse")
    if vex_sfdp_stress > graphviz_sfdp_stress:
        raise SystemExit("petersen-sfdp: Vex stress exceeds Graphviz")

    fdp_fixture = args.graphviz_root / "tests" / "graphs" / "p2.gv"
    vex_fdp_geometry = vex_geometry(args.vex, fdp_fixture, "fdp")
    graphviz_fdp_geometry = graphviz_geometry(fdp_fixture, "fdp")
    vex_fdp_score = quality(*vex_fdp_geometry)
    graphviz_fdp_score = quality(*graphviz_fdp_geometry)
    vex_fdp_cv, vex_fdp_stress = force_quality(
        vex_fdp_geometry[0], vex_fdp_geometry[1]
    )
    graphviz_fdp_cv, graphviz_fdp_stress = force_quality(
        graphviz_fdp_geometry[0], graphviz_fdp_geometry[1]
    )
    print(
        "layout-quality-audit p2-fdp "
        f"vex_overlap={vex_fdp_score[0]} vex_crossings={vex_fdp_score[1]} "
        f"vex_edge_cv={vex_fdp_cv:.3f} vex_stress={vex_fdp_stress:.3f} "
        f"graphviz_overlap={graphviz_fdp_score[0]} "
        f"graphviz_crossings={graphviz_fdp_score[1]} "
        f"graphviz_edge_cv={graphviz_fdp_cv:.3f} "
        f"graphviz_stress={graphviz_fdp_stress:.3f}"
    )
    if vex_fdp_score[0] != 0:
        raise SystemExit("p2-fdp: Vex introduced node overlaps")
    if vex_fdp_score[1] > graphviz_fdp_score[1]:
        raise SystemExit("p2-fdp: Vex crossing count exceeds Graphviz")
    if vex_fdp_cv > graphviz_fdp_cv:
        raise SystemExit("p2-fdp: Vex edge-length CV exceeds Graphviz")
    if vex_fdp_stress > graphviz_fdp_stress:
        raise SystemExit("p2-fdp: Vex stress exceeds Graphviz")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
