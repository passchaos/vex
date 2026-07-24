#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import os
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bindings" / "python"))
if len(sys.argv) > 1:
    os.environ["VEX_LIBRARY"] = sys.argv[1]

import vex  # noqa: E402


def main() -> None:
    with vex.Graph("Python Smoke", directed=True) as graph:
        start = graph.add_node("Start")
        finish = graph.add_node("Finish")
        edge = graph.add_edge(start, finish, "flow")
        assert (start, finish, edge) == (0, 1, 0)
        svg = graph.render_svg(vex.RenderConfig(metadata=True))
        assert "<title>Python Smoke</title>" in svg
        assert 'data-vex-schema-version="1"' in svg
        assert ">flow</tspan>" in svg

    dot_svg = vex.render_dot(
        "graph D { a -- b; }",
        vex.RenderConfig(layout="neato", iterations=20),
    )
    assert "<title>D</title>" in dot_svg
    radial_svg = vex.render_dot(
        'graph R { graph [root=center]; center -- a; center -- b; a -- c; }',
        vex.RenderConfig(layout="twopi"),
    )
    assert "<title>R</title>" in radial_svg
    circular_svg = vex.render_dot(
        "graph C { a -- b -- c -- a; c -- d -- e -- c; }",
        vex.RenderConfig(layout="circo"),
    )
    assert "<title>C</title>" in circular_svg
    patchwork_svg = vex.render_dot(
        "graph P { a [area=1]; b [area=4] }",
        vex.RenderConfig(layout="patchwork"),
    )
    assert "<title>P</title>" in patchwork_svg
    osage_svg = vex.render_dot(
        "graph O { graph [packmode=array_i2]; a; b; c; }",
        vex.RenderConfig(layout="osage"),
    )
    assert "<title>O</title>" in osage_svg
    nop_svg = vex.render_dot(
        'graph N { a [pos="0,0"]; b [pos="120,0"]; a -- b; }',
        vex.RenderConfig(layout="nop"),
    )
    assert "<title>N</title>" in nop_svg
    nop2_svg = vex.render_dot(
        'digraph N2 { graph [notranslate=true]; a [pos="0,0"]; b [pos="120,0"]; '
        'a -> b [pos="e,105,0 20,0 45,40 75,40 100,0"]; }',
        vex.RenderConfig(layout="nop2"),
    )
    assert "M20,0C45,-40 75,-40 100,0" in nop2_svg

    try:
        vex.render_dot(
            'graph Missing { a [pos="0,0"]; b; }',
            vex.RenderConfig(layout="nop"),
        )
    except vex.VexError as error:
        assert "MissingNodePosition" in str(error)
    else:
        raise AssertionError("expected missing nop position error")

    try:
        vex.render_dot("digraph G { a ->")
    except vex.ParseError:
        pass
    else:
        raise AssertionError("expected ParseError")

    try:
        vex.render_dot(
            "graph G { a -- b -- c -- d -- a; }",
            vex.RenderConfig(layout="sfdp", iterations=200, work_budget=1),
        )
    except vex.LayoutCanceled:
        pass
    else:
        raise AssertionError("expected LayoutCanceled")


if __name__ == "__main__":
    main()
