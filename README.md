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
- SVG renderer.
- Output format dispatch with SVG as the currently supported backend.
- CLI that reads DOT from a file or stdin and writes to a file or stdout.
- Native parser/layout/rendering path by default; Graphviz `dot` is used only as a development/test oracle.

## CLI

```sh
zig build run -- --input examples/simple.dot --output simple.svg
zig build run -- --input examples/subgraph.dot --output subgraph.svg
zig build run -- --input examples/mainstream.dot --format svg
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

const a = try graph.addNode("Start", .{ .shape = .box });
const b = try graph.addNode("B", .{});
_ = try graph.addEdge(a, b, .{ .label = "next" });

var layout = try vex.layoutGraph(allocator, &graph, .{});
defer layout.deinit();
try vex.render(writer, &layout, .svg, .{});
```

Default node and edge label attributes set through the API apply to subsequently added items, with per-item options taking precedence. Typed graph attributes include spline routing modes such as `curved`, `polyline`, `line`, `ortho`, and `none`.

## API Examples

The `examples/api` programs build graphs directly with the Zig API and then
render them:

```sh
zig build run-api-basic-svg
zig build run-api-undirected-svg
zig build run-api-clusters-compound
zig build run-api-svg-output
zig build run-api-records-ports-svg
zig build run-api-shapes-styles-svg
zig build run-api-force-layout-svg
```

They progress from small SVG output to broader feature coverage:

- `01_basic_svg.zig`: directed graph construction, labels, layout, and SVG rendering.
- `02_undirected_svg.zig`: undirected API graph, `rankdir=LR`, and SVG rendering.
- `03_clusters_compound.zig`: `addSubgraph`, graph attributes, compound edge hints, and SVG output.
- `04_svg_output.zig`: one API graph rendered through the SVG output dispatch path.
- `05_records_ports_svg.zig`: record labels, record ports, and SVG output.
- `06_shapes_styles_svg.zig`: common Graphviz-style shapes, node/edge attrs, and SVG output.
- `07_force_layout_svg.zig`: cyclic undirected graph rendered with Sugiyama to exercise edge-label avoidance.

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
- Subgraph blocks and subgraph edge operands: `{ a b } -> subgraph group { c d }`.
- Rank subgraphs including `same`, `min`, `max`, `source`, and `sink`, with `source` / `sink` kept as exclusive boundary ranks.
- Port syntax in node ids: `a:out:e`.
- Attribute statements: `graph [rankdir=LR]`, `graph [layout=neato]`, `node [...]`, `edge [...]`.
- Graph `pad` plus graph, node, and subgraph margin attributes with zero and sub-inch values.
- Graphviz-style style lists separated by commas, semicolons, or whitespace.
- Order-sensitive SVG line styles for `solid`, `dashed`, and `dotted`.
- Graphviz `shape=plain` keeps a compact unboxed text node distinct from `shape=plaintext` / `shape=none`.
- SVG rendering for Graphviz-style node `diagonals` on polygonal and ellipse-like shapes.
- SVG rendering for Graphviz SBOLv node shapes `promoter`, `cds`, `terminator`, `utr`, `primersite`, `restrictionsite`, `fivepoverhang`, `threepoverhang`, `noverhang`, `rpromoter`, `lpromoter`, `larrow`, and `rarrow`.
- SVG rendering for node `image`, deprecated `shapefile`, `imagescale`, and `imagepos` attributes inside the node box.
- SVG rendering for Graphviz-style multicolor fills including box/node/subgraph `striped` fills and ellipse/circle `wedged` fills.
- SVG edge labels honor `decorate=true` with a label underline connected to the edge path.
- Edge `labelfloat=true` keeps the main edge label at its unconstrained route position.
- Edge `labelaligned=true` renders plain main edge labels with SVG `textPath` aligned to the edge path.
- M-shape nodes render `toplabel` and `bottomlabel` auxiliary labels where Graphviz defines them.
- Root graph labels default to bottom-center while cluster labels default to top-center; clusters inherit root `labelloc` / `labeljust` and label font attributes unless overridden.
- Clusters inherit root graph `fillcolor` / `pencolor` unless they set their own values.
- SVG group `id` attributes honor Graphviz object escapes and use the root graph `id` as a default prefix for child objects.
- SVG interactive anchors are wrapped in Graphviz-style `a_*` groups, including edge label, head label, and tail label anchors.
- SVG font output honors Graphviz `fontnames=svg|ps|gd` for standard PostScript font aliases, including family, weight, style, and stretch.
- SVG color and color-list attributes resolve Graphviz `colorscheme=bugn9` numeric ColorBrewer colors.
- SVG color attributes map Graphviz `transparent` to non-painted SVG output.
- `splines` routing values including `true` / `false` aliases, `line`, `polyline`, `ortho`, and `none`.
- Common arrow marker shapes including `normal`, `open`, `inv`, `curve`, `vee`, `dot`, `box`, `diamond`, `tee`, `crow`, their open variants where available, and common Graphviz compatibility aliases.
- Quoted strings with common Graphviz escapes (`\n`, `\l`, `\r`, escaped quotes/backslashes, line continuations), quoted-string concatenation with `+`, angle-bracket IDs/labels retained as plain text, numeric IDs, negative numeric IDs, UTF-8 IDs, and simple boolean attributes including `true` / `false`, `yes` / `no`, `on` / `off`, and `1` / `0`. SVG text rendering honors `\l` / `\r` line alignment for graph, node, subgraph, and external labels such as `xlabel`, `headlabel`, and `taillabel`; Graphviz object escapes include `\G`, `\N`, `\E`, `\T`, `\H`, and `\L`; default `node [...]` and `edge [...]` label attributes expand in each concrete node or edge context.
- SVG text rendering honors `nojustify=true` for graph, node, edge, and subgraph labels.
- SVG rendering honors Graphviz `outputorder=edgesfirst|nodesfirst|breadthfirst`.
- Node and cluster `peripheries=0` hide borders while preserving fills.
- Line comments (`//`, `#`) and block comments (`/* ... */`).

## Output backends

- `svg`: vector output with labels and basic shapes.

The public render API keeps an `OutputFormat` dispatch layer so output backends can be added or removed without changing call sites that already pass a format.

Future work should expand remaining non-MVP DOT details—full cluster layout semantics and Graphviz edge cases—toward the full grammar in Graphviz's local source at
`~/Work/graphviz/lib/cgraph/grammar.y` and `~/Work/graphviz/doc/infosrc/grammar`.
