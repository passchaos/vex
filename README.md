# Vex

Vex is a Zig graph visualization prototype: DOT-compatible at the boundary,
with a native graph-building API inside. The goal is to reimplement Graphviz
semantics in Zig while keeping Graphviz as a compatibility oracle for tests,
not as a runtime rendering dependency. The long-term goal is to keep the
Graphviz ecosystem's strengths while exploring a cleaner, modern layout and
rendering architecture.

See [`docs/PROJECT_GUIDE.md`](docs/PROJECT_GUIDE.md) for the local project guide.

## Current MVP

- Zig 0.16 project.
- Core graph model with a programmatic builder API.
- DOT subset parser compatible with common `graph`/`digraph` files, including subgraphs and ports.
- Basic layered layout with `rankdir=TB|BT|LR|RL`.
- SVG renderer, layout-aware terminal renderer, and a simple native PNG raster path.
- Output format dispatch for `terminal`, `svg`, `png`, and `pdf`.
- CLI that reads DOT from a file or stdin and writes to a file or stdout.
- Native parser/layout/rendering path by default; Graphviz `dot` is used only as a development/test oracle.

## CLI

```sh
zig build run -- --input examples/simple.dot --output simple.svg
zig build run -- --input examples/simple.dot --format terminal
zig build run -- --input examples/subgraph.dot --output subgraph.svg
zig build run -- --input examples/mainstream.dot --format terminal
zig build run -- --input examples/simple.dot --layout neato --output force.svg
cat examples/simple.dot | zig build run -- --format svg > simple.svg
```

Layout selection defaults to `dot`/Sugiyama, which honors
`rankdir=TB|BT|LR|RL` during layout. `--layout fr`, `--layout neato`, `--layout
fdp`, and Graphviz-style `-Kneato` select the deterministic
Fruchterman-Reingold force-directed layout.

## Zig API sketch

```zig
const std = @import("std");
const vex = @import("vex");

var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "G" });
defer graph.deinit();

const a = try graph.nodeWith("A", .{ .shape = .box, .label = "Start" });
const b = try graph.node("B");
_ = try graph.edge(a, b, .{ .label = "next" });

var layout = try vex.layoutGraph(allocator, &graph, .{});
defer layout.deinit();
try vex.render(writer, &graph, &layout, .svg, .{});
```

## API Examples

The `examples/api` programs build graphs directly with the Zig API and then
render them:

```sh
zig build run-api-basic-terminal
zig build run-api-ascii-undirected
zig build run-api-clusters-compound
zig build run-api-output-formats
zig build run-api-records-ports-svg
zig build run-api-shapes-styles-svg
zig build run-api-force-layout-terminal
```

They progress from small terminal output to broader feature coverage:

- `01_basic_terminal.zig`: directed graph construction, labels, layout, and terminal rendering.
- `02_ascii_undirected.zig`: undirected API graph, `rankdir=LR`, and ASCII terminal fallback.
- `03_clusters_compound.zig`: `addCluster`, graph attributes, compound edge hints, and terminal cluster panels.
- `04_output_formats.zig`: one API graph rendered to plain/truecolor terminal, OSC 8 hyperlinks, semantic HTML `<pre>`, SVG, PNG, and PDF.
- `05_records_ports_svg.zig`: record labels, record ports, HTML-like table labels, and SVG output.
- `06_shapes_styles_svg.zig`: common Graphviz-style shapes, node/edge attrs, terminal preview, and SVG output.
- `07_force_layout_terminal.zig`: force-directed layout via `.fruchterman_reingold` and terminal rendering.

## Graphviz compatibility target

Vex is intended to reimplement Graphviz behavior rather than shell out to
`dot`. During development, Graphviz should be used as an oracle in tests and
fixtures: compare parsed semantics, layout coordinates, and rendered output for
representative graphs, then close gaps in the native implementation. Runtime CLI
rendering should stay on Vex's native parser/layout/renderers.

For SVG parity work, `tools/svg_residual.py generated.svg graphviz.svg` reports
screen-space point residuals for ordered `polygon`, `polyline`, and `path`
geometry, skipping the root background polygon by default. Use
`--show-lower-bound` to show the best possible residual on the current
one-decimal coordinate grid, `--max-residual` to gate the absolute residual, and
`--max-gap` to gate only the remaining gap above that one-decimal lower bound.

## Mainstream DOT support

The parser currently supports a practical, mainstream DOT subset:

- `graph` / `digraph` and optional `strict`.
- Node statements: `A [label="Start", shape=box]`.
- Edge chains: `A -> B -> C [label="flow"]` or `a -- b`.
- Comma node lists in node statements and edge operands: `a, b -- c, d`.
- Subgraph blocks and subgraph edge operands: `{ a b } -> subgraph cluster { c d }`.
- Port syntax in node ids: `a:out:e`.
- Attribute statements: `graph [rankdir=LR]`, `graph [layout=neato]`, `node [...]`, `edge [...]`.
- Quoted strings with common Graphviz escapes (`\n`, `\l`, `\r`, escaped quotes/backslashes, line continuations), quoted-string concatenation with `+`, HTML-like IDs/labels as text, numeric IDs, negative numeric IDs, UTF-8 IDs, and simple boolean attributes.
- Line comments (`//`, `#`) and block comments (`/* ... */`).

## Output backends

- `terminal`: layout-aware shell preview with box-drawn nodes, clusters, edges, arrow markers, edge labels, ASCII fallback, DOT/API color/style attributes, ANSI 256/truecolor, optional OSC 8 hyperlinks, and semantic HTML `<pre>` output with links, titles, `data-vex-kind` metadata, and safe style fallback.
- `svg`: vector output with labels and basic shapes.
- `png`: simple built-in rasterizer for early snapshots.
- `pdf`: compact vector output using a built-in minimal PDF writer.

The native PNG/PDF paths are intentionally dependency-free MVP backends: PNG currently rasterizes boxes/edges without text; PDF keeps vector edges, boxes, and labels.

Future work should expand remaining non-MVP DOT details—full cluster layout semantics, complete HTML-label rendering, and all Graphviz edge cases—toward the full grammar in Graphviz's local source at
`~/Work/graphviz/lib/cgraph/grammar.y` and `~/Work/graphviz/doc/infosrc/grammar`.
