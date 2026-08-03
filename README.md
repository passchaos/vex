# Vex

Vex is a Zig graph visualization prototype: DOT-compatible at the boundary,
with a native graph-building API inside. The goal is to reimplement Graphviz
semantics in Zig while keeping Graphviz as a compatibility oracle for tests,
not as a runtime rendering dependency. The long-term goal is to keep the
Graphviz ecosystem's strengths while exploring a cleaner, modern layout and
rendering architecture.

See [`docs/PROJECT_GUIDE.md`](docs/PROJECT_GUIDE.md) for the local project guide.
See [`docs/CAPABILITY_MATRIX.md`](docs/CAPABILITY_MATRIX.md) for the auditable
completion criteria, current gaps, and explicitly excluded features.

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
zig build run -- --input examples/simple.dot --check
zig build run -- --input examples/simple.dot --validate-all --max-diagnostics 32
zig build run -- --input examples/simple.dot --output simple.svg
zig build run -- --input examples/subgraph.dot --output subgraph.svg
zig build run -- --input examples/mainstream.dot --format svg
zig build run -- --input examples/simple.dot --max-input-bytes 1048576 --output simple.svg
zig build run -- --input examples/simple.dot --layout neato --output force.svg
zig build run -- --input examples/simple.dot --layout neato --layout-iterations 20 --output force-fast.svg
zig build run -- --input examples/simple.dot --layout-work-budget 50000 --output budgeted.svg
zig build run -- --input examples/simple.dot --crossing-passes 2 --coordinate-passes 1 --output layered-fast.svg
zig build run -- --input examples/layers.dot --output interactive.svg --interactive-all
zig build run -- --input examples/layers.dot --output layers.svg --interactive-layers
zig build run -- --input examples/subgraph.dot --output collapse.svg --interactive-collapse
zig build run -- --input examples/simple.dot --output filtered.svg --interactive-filter
zig build run -- --input examples/simple.dot --output labels.svg --interactive-labels
zig build run -- --input examples/simple.dot --output focus.svg --interactive-focus
zig build run -- --input examples/subgraph.dot --output inspect.svg --interactive-inspector
zig build run -- --input examples/simple.dot --output searchable.svg --interactive-search
zig build run -- --input examples/simple.dot --output viewport.svg --interactive-viewport
zig build run -- --input examples/simple.dot --output minimap.svg --interactive-minimap
zig build run -- --input examples/simple.dot --output stats.svg --interactive-stats
zig build run -- --input examples/simple.dot --output indexed.svg --svg-metadata
cat examples/simple.dot | zig build run -- --format svg > simple.svg
```

Math-heavy graph and data-visualization labels can opt into ztex-powered
TeX-like formula rendering with `enable_math_label=true` on graph/node/edge label
attributes, including mixed text plus inline formulas such as
`node [enable_math_label=true]; a [label="Energy $\\frac{x_1}{y^2}$"]`.
Vex owns the DOT/Graphviz label policy and SVG placement; ztex supplies the
reusable formula parsing, mixed-label measurement, layout, metrics, and SVG
fragment primitives.

Layout selection defaults to `dot`/Sugiyama, which honors
`rankdir=TB|BT|LR|RL` during layout. `--layout neato`, `graph
[layout=neato]`, and Graphviz-style `-Kneato` select the deterministic
stress-majorization engine, with Graphviz `mode=major` and `mode=KK`
selecting the majorization and Kamada-Kawai optimization paths; explicit
`Damping` scales the KK step factor. `--layout fdp`, `graph [layout=fdp]`,
and `-Kfdp`
select the independent spring-electrical engine with all-pairs repulsion,
edge-only springs, cluster boxes, graph `K` / `T0`, and edge `len` / `weight`
semantics. Force-style layouts honor Graphviz `normalize` final-coordinate
rotation, `model=subset`, `defaultdist`, `epsilon`, and seeded
`start=randomN` / numeric `start=N` initialization. Neato and fdp also use
complete node `pos` input positions with Graphviz `inputscale` unit semantics.
Explicit force-layout `overlap` values reuse the native Graphviz-family
overlap adjusters and `sep`.
Force-style layouts accept Graphviz `dim` / `dimen` attributes at the model
boundary while Vex continues to produce 2D SVG coordinates.
`--layout fr` selects the deterministic Fruchterman-Reingold engine.
`--layout sfdp`, `graph [layout=sfdp]`, and `-Ksfdp` select the
independent deterministic multilevel spring-electrical engine. It supports
Graphviz-style `levels`, `K`, `repulsiveforce`, `rotation`, and `quadtree`;
like Graphviz sfdp, it does not model clusters or edge `len` / `weight`. Fine-level
repulsion uses a deterministic Barnes-Hut quadtree above the exact small-graph
threshold, with tests bounding force error and repulsion work plus a 512-node
SVG smoke.
`--layout twopi`, `graph [layout=twopi]`, and `-Ktwopi` select the independent
radial engine. It honors graph `root`, node `root=true`, Graphviz-style scalar
and list `ranksep` radial increments, per-component node roots, BFS
graph-distance rings, subtree-weighted angular spans, and disconnected
component packing.
`--layout circo`, `graph [layout=circo]`, and `-Kcirco` select the independent
circular engine. It uses Tarjan biconnected blocks, places each block on a
circle, recursively joins the block-cut tree at articulation nodes, packs
disconnected components, and honors graph `root`, per-component node
`root=true`, `mindist`, and `oneblock`.
`--layout patchwork`, `graph [layout=patchwork]`, and `-Kpatchwork` select the
independent hierarchical squarified treemap engine. Node/subgraph `area`
controls allocation, nested subgraphs form containing rectangles, and edges do
not affect the treemap.
`--layout osage`, `graph [layout=osage]`, and `-Kosage` select the independent
hierarchical array-packing engine. It recursively packs direct nodes and child
subgraphs using their intrinsic rectangle sizes, ignores edges, and supports
graph/subgraph `pack`, Graphviz-style `packmode=array_[ciutblr]N`, plus
node/subgraph `sortv` ordering.
`--layout nop` / `nop1` preserve required node `pos` coordinates and reroute
edges, while `--layout nop2` additionally preserves valid Graphviz `3n+1`
cubic edge `pos` splines and reroutes missing or invalid ones. Both support
`notranslate=true`; the Zig API exposes typed `NodePosition` and
`EdgeSplineSegmentInput` values, plus typed `BoundingBox` and graph/subgraph/
node/edge label positions, instead of leaking DOT geometry strings into core
API calls. Nop honors Graphviz overlap families (`false`/Voronoi, `scale`,
`scalexy`, `compress`, `ortho*`, `portho*`, `prism`, `vpsc`, and `ipsep`)
with deterministic native adjustment and `sep`; nop2 treats input coordinates
as final and never applies overlap adjustment.
`--layout-iterations` caps the selected iterative layout budget
for fast previews or large graph workflows; DOT can set the same budget with
`graph [layout_iterations=20]`; force-style Graphviz input can also use
`graph [maxiter=20]`, and the Zig API can pass
`.{ .force = .{ .iterations = 20 } }`.
`--layout-profile compact|balanced|relaxed|presentation` selects a centralized
set of Vex defaults before CLI overrides and DOT graph attributes are applied.
`balanced` preserves the existing defaults, while `relaxed` and `presentation`
increase the default layered spacing, force-layout canvas, ideal edge length,
and force overlap margin. The Zig API can use
`LayoutConfig.defaults(.relaxed)` and then override individual fields.
`--layout-work-budget` provides a deterministic cross-engine cancellation
budget for CI and bounded previews. The Zig API can use a custom
`LayoutControl` callback or the built-in `LayoutWorkBudget`; cancellation
returns `error.LayoutCanceled` without returning a partial `Layout`.
For layered/Sugiyama layout, `--crossing-passes` and `--coordinate-passes`
control crossing-reduction and coordinate-refinement budgets. DOT can set the
same budgets with `crossing_passes` / `coordinate_passes`, and the Zig API can
pass `LayoutConfig.layered`.

The Zig API also exposes `layoutGraphIncremental`. It accepts a previous
`Layout` and preserves the mental map of nodes that retain the same `NodeId`
while still laying out new nodes and rebuilding subgraph/edge geometry.
`IncrementalLayoutOptions.stability` ranges from `0` (identical to a full
layout) to `1` (strongest previous-position anchoring), and works with both
layered and Fruchterman-Reingold layouts.

DOT parse failures report a line, column, source excerpt, caret, and repair hint
so input mistakes can be fixed without rerunning through another tool.

`--check` / `--validate` parses DOT or Mermaid input and reports graph counts
without running layout or rendering, which is useful for CI and fast input
validation.
`--validate-all` uses statement-boundary recovery to report multiple
recoverable DOT errors in one run; `--max-diagnostics` bounds the result.
Unrecoverable lexical errors such as unterminated strings stop recovery after
their precise line/source diagnostic. The Zig API exposes
`parseDotDiagnostics`.

`--max-input-bytes` caps input reads for DOT and Mermaid sources, including stdin,
so preview workflows can fail early on unexpectedly large graph inputs.

`--svg-metadata` embeds a machine-readable object index in the SVG `<metadata>`
element. It includes graph structure and layout/canvas facts, node geometry,
edge waypoints, subgraph geometry, and layer metadata when present. It also
annotates rendered graph, node, edge, and subgraph groups with
`data-vex-object-*` attributes, including graph direction, strictness, rank
direction and object counts, subgraph parent/member relationships, object layer and effective
`href` / `tooltip` / `target` metadata when known, plus edge waypoint geometry
for long routed edges, edge record/compass ports and compound subgraph
endpoints, edge bounding boxes, and node rank values, for direct tooling hooks.
The metadata index also includes a generic `<vex:attributes>` section so
custom and future graph, node, edge, and subgraph attributes remain available
to downstream tooling without waiting for dedicated schema fields, plus an
explicit rank-constraint index for `same`, `min`, `max`, `source`, and `sink`
groups. Edge metadata records effective `weight`, `constraint`, and `minlen`
values even when they come from built-in defaults rather than explicit DOT
attributes.
The v1 schema and additive compatibility policy are documented in
[`docs/SVG_METADATA_V1.md`](docs/SVG_METADATA_V1.md); consumers can discover
the schema URI, major version, and feature tokens directly in generated SVG.
DOT can enable the same index with
`graph [svg_metadata=true]`, and the Zig API can pass
`.{ .svg = .{ .metadata = true } }`.

`--interactive-all` enables the current SVG-native tool surface at once:
metadata, layer controls when layers exist, collapse, filters, label toggles,
focus, inspector, search, viewport controls, minimap, and stats. DOT can enable
the same preset with `graph [interactive_all=true]`, and the Zig API can
pass `.{ .svg = .{ .interactive_all = true } }`.

`--interactive-layers` is a Vex SVG extension. When a graph declares
Graphviz-style `layers`, it embeds a small self-contained SVG control panel for
toggling layer visibility. The same behavior can be enabled from DOT with
`graph [interactive_layers=true]` or from the Zig API with
`.{ .svg = .{ .interactive_layers = true } }`.

`--interactive-collapse` embeds subgraph collapse and expand controls. It marks
member nodes and internal edges so a generated SVG can hide or restore a
subgraph's contents without re-rendering. It can also be enabled from DOT with
`graph [interactive_collapse=true]` or from the Zig API with
`.{ .svg = .{ .interactive_collapse = true } }`.

`--interactive-filter` embeds object-type filters for nodes, edges, and
subgraphs. It can also be enabled from DOT with
`graph [interactive_filter=true]` or from the Zig API with
`.{ .svg = .{ .interactive_filter = true } }`.

`--interactive-labels` embeds label visibility controls for nodes, edges, and
subgraphs. It can also be enabled from DOT with
`graph [interactive_labels=true]` or from the Zig API with
`.{ .svg = .{ .interactive_labels = true } }`.

`--interactive-focus` lets generated SVGs focus a selected node or edge and its
neighborhood while dimming unrelated objects. It can also be enabled from DOT
with `graph [interactive_focus=true]` or from the Zig API with
`.{ .svg = .{ .interactive_focus = true } }`.

`--interactive-inspector` embeds an object inspector panel. Clicking a node,
edge, or subgraph shows its type, id/label, and selected metadata. It can also
be enabled from DOT with `graph [interactive_inspector=true]` or from the
Zig API with `.{ .svg = .{ .interactive_inspector = true } }`.

`--interactive-search` is another Vex SVG extension. It embeds a self-contained
search and highlight panel and annotates rendered nodes, edges, and subgraphs
with searchable labels and metadata. It can also be enabled from DOT with
`graph [interactive_search=true]` or from the Zig API with
`.{ .svg = .{ .interactive_search = true } }`.

`--interactive-viewport` adds a self-contained pan, zoom, and reset panel around
the rendered graph content. It can also be enabled from DOT with
`graph [interactive_viewport=true]` or from the Zig API with
`.{ .svg = .{ .interactive_viewport = true } }`.

`--interactive-minimap` adds a self-contained overview panel for navigating the
rendered graph. Clicking nodes or subgraph boxes in the minimap recenters the
main SVG viewport. It can also be enabled from DOT with
`graph [interactive_minimap=true]` or from the Zig API with
`.{ .svg = .{ .interactive_minimap = true } }`.

`--interactive-stats` adds a self-contained graph statistics panel with object
counts, layout size, canvas size, direction, and rank direction. It can also be
enabled from DOT with `graph [interactive_stats=true]` or from the Zig API
with `.{ .svg = .{ .interactive_stats = true } }`.

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

Independent graphs can be laid out concurrently while preserving task order:

```zig
const tasks = [_]vex.ParallelLayoutTask{
    .{ .allocator = first_layout_allocator, .graph = &first, .config = .{ .algorithm = .sugiyama } },
    .{ .allocator = second_layout_allocator, .graph = &second, .config = .{ .algorithm = .multilevel_spring_electrical } },
};
var layouts = try vex.layoutGraphsParallel(scheduler_allocator, &tasks, .{
    .max_workers = 4,
    .cancel = &cancel_flag,
});
defer layouts.deinit();
```

Each result is `.layout` or `.failure` at the matching task index. Task
allocators own their successful layouts and must remain valid until
`ParallelLayouts.deinit`; use one allocator per task or an allocator designed
for concurrent access. The scheduler allocator only owns the result array and
worker handles. `cancel_flag` is an optional `std.atomic.Value(bool)` checked
before and during every layout.

For DOT streams with multiple top-level graphs, the CLI uses the same ordered
batch layout path automatically. `--layout-workers N` caps workers (`1` forces
serial layout); SVG documents are still rendered serially in input order, so
worker count does not change output bytes. `--layout-work-budget` is applied
independently to every graph. With `--layout-workers 1`, the CLI uses a bounded
parse→layout→render visitor pipeline and releases each graph/layout after its
SVG is flushed; completed SVG documents remain valid if a later graph fails.

After editing a graph while keeping existing `NodeId` values stable:

```zig
var next_layout = try vex.layoutGraphIncremental(
    allocator,
    &graph,
    &layout,
    .{ .algorithm = .sugiyama },
    .{ .stability = 0.95 },
);
defer next_layout.deinit();
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
zig build run-api-incremental-layout-svg
zig build run-api-fdp-layout-svg
zig build run-api-sfdp-layout-svg
zig build run-api-twopi-layout-svg
zig build run-api-circo-layout-svg
zig build run-api-patchwork-layout-svg
zig build run-api-osage-layout-svg
zig build run-api-positioned-layout-svg
zig build run-api-math-labels-svg
```

They progress from small SVG output to broader feature coverage:

- `01_basic_svg.zig`: directed graph construction, labels, layout, and SVG rendering.
- `02_undirected_svg.zig`: undirected API graph, `rankdir=LR`, and SVG rendering.
- `03_clusters_compound.zig`: `addSubgraph`, graph attributes, compound edge hints, and SVG output.
- `04_svg_output.zig`: one API graph rendered through the SVG output dispatch path.
- `05_records_ports_svg.zig`: record labels, record ports, and SVG output.
- `06_shapes_styles_svg.zig`: common Graphviz-style shapes, node/edge attrs, and SVG output.
- `07_force_layout_svg.zig`: cyclic undirected graph rendered with the independent neato stress-majorization engine.
- `08_incremental_layout_svg.zig`: add a node after the first layout, preserve shared-node positions with `layoutGraphIncremental`, and write the final SVG.
- `09_fdp_layout_svg.zig`: clustered undirected graph rendered with the independent spring-electrical fdp engine.
- `10_sfdp_layout_svg.zig`: larger graph rendered with deterministic coarsen/prolongate/refine sfdp layout.
- `11_twopi_layout_svg.zig`: explicitly rooted graph rendered on BFS rings with subtree-weighted angular spans.
- `12_circo_layout_svg.zig`: biconnected blocks rendered as recursively connected circles.
- `13_patchwork_layout_svg.zig`: hierarchical node/subgraph areas rendered as a squarified treemap.
- `14_osage_layout_svg.zig`: nested subgraphs and intrinsic node rectangles rendered with deterministic array packing.
- `15_positioned_layout_svg.zig`: typed pre-positioned nodes and a preserved nop2 cubic edge rendered to SVG.
- `16_math_labels_svg.zig`: ztex-powered mixed text + inline math labels on nodes and edges.

## Graphviz compatibility target

Vex is intended to reimplement Graphviz behavior rather than shell out to
`dot`. During development, Graphviz should be used as an oracle in tests and
fixtures: compare parsed semantics, layout coordinates, and rendered output for
representative graphs, then close gaps in the native implementation. Runtime CLI
rendering should stay on Vex's native parser/layout/renderers.

For invariant layout-quality work, `zig build audit-layout-quality -Dgraphviz-root=/path/to/graphviz` compares Vex and Graphviz on real sparse-undirected `ngk10_4.gv`, dense-undirected `overlap.gv`, directed-DAG `fig6.gv`, explicit-rank `world.gv` plus its annotation-heavy `share/world.gv` round-trip, partial explicit-rank `shells.gv`, weighted cyclic profile `698066.dot`, wide zero-crossing star `1855.dot`, overlapping-cluster rank fixture `1767.dot`, nested-owner component fixture `2476.dot`, contracted-rank-cycle fixture `2825.dot`, overflowing-node-dimension fixture `2784.dot`, port-constrained small DAG `2734.dot`, disjoint local-timeline cluster `2521_1.dot`, cluster round-trip `share/clust5.gv`, multiline-doublecircle pipeline `pmpipe.gv`, overlapping `ordering=out` fixture `b58.gv`, orthogonal circuit `1658.dot`, sparse cluster palette `grdcolors.gv`, grammar round-trip `share/grammar.gv`, ordered-DAG `awilliams.gv`, cross-cluster cycle `try.gv`, cyclic-workflow `b57.gv`, acyclic fanout `abstract.gv`, heterogeneous workflow `b71.gv`, fragmented DAG `mike.gv`, self-loop/cyclic dependency `NaN.gv`, feedback-heavy workflow `rowe.gv`, cubic undirected `Heawood.gv`, private-branch DAG `unix2.gv` plus its size-annotated `share/unix2.gv` round-trip, annotation-heavy LR `linux.x86/rankdir_dot.gv` round-trip, horizontal fill-aspect `pgram.gv`, reciprocal cluster/rank `dfa.gv`, flat-cluster `proc3d.gv`, entity-heavy `Symbol.gv`, Helvetica ellipse workflow `2193.dot`, Times ellipse fixture `b94.gv`, and deeply nested compound-cluster `1332.dot` fixtures. All must have zero node overlaps and bounded center-line crossings, edge length, and normalized canvas area; the aggregate crossing gate is 770. Current Vex crossing scores are 182/193/58/59/59/8/17/0/0/0/3/0/0/0/0/0/0/1/4/0/0/0/0/57/6/6/48/52/1/2/2/4/0/0/0/0/0/0/8 versus Graphviz's 206/283/62/66/66/8/24/0/0/5/0/0/0/0/0/0/0/1/4/0/0/0/58/11/7/96/63/10/3/3/4/0/0/0/0/0/0/9 (770 versus 990 aggregate). Vex uses substantially shorter edges and about half the normalized area on `ngk10_4`; `fig6` now beats Graphviz crossings while staying within 15% edge length and 10% area; an endpoint-stable explicit-rank restart makes original and annotation-heavy `world` edge-order invariant at 59 crossings versus Graphviz's 66, while reducing normalized area to 7.75; `shells` first uses per-level explicit-rank compaction to reduce normalized edge length from 3.70 to 3.59 without moving its unconstrained level, then a 4,096-combination bounded joint order/coordinate search reaches 8 crossings (matching Graphviz) and 3.09/5.91 normalized edge/area; medium crossed sparse-directed graphs deepen the deterministic center-order restarts from 13 to 64, improving `b71` from 14 to 13 crossings and the expanded `698066.dot` holdout from 29 to 27; equal-weight heavy pass-through rank ties choose the source-side quartile of their feasible interval, reserving sink-side channels for long feedback edges and reducing `698066.dot` to 17 crossings with `2.48/5.88` normalized edge/area versus Graphviz `24/3.92/6.68`; zero-crossing two-level stars with at least eight leaves safely repack at Graphviz's default 18pt nodesep when no explicit nodesep is present, bringing `1855.dot` normalized edge/area to 24.78/49.00 versus Graphviz's 24.81/48.00; two sparse late width-aware checkpoints plus a physical-crossing-safe coordinate-stress plateau reduce `b71` further to 9 crossings versus Graphviz's 11 and improve `jsort` from 68 to 66; clusterless exact rank closure may accept one wider peak only for 24–39-node graphs, reducing `mike` from 10 to 6 crossings versus Graphviz's 7 while shortening edges; `dfa` matches Graphviz's zero crossings and slightly improves normalized edge length; `proc3d` matches zero crossings, uses 5% less normalized area, and keeps edge length within 30%; `pgram` keeps zero crossings while physical-axis fill plus Graphviz-style serif polygon fitting and partial-rank compaction reduce normalized edge/area to 12.02/11.15; deterministic Symbol advances, exact Graphviz ellipse containment, and safe 18pt rank packing bring `Symbol.gv` to zero crossings and normalized edge/area `1.175/3.080` versus Graphviz's `1.170/2.743`; regular Helvetica ASCII ellipses use deterministic DejaVu Sans/Pango 13pt and 14pt advances in graphs up to 128 nodes, reducing all 58 node-dimension errors in `2193.dot` (mean absolute error `42.22pt → 0.37pt`) while keeping zero overlaps/crossings and improving normalized edge/area to `1.859/5.819` versus Graphviz `1.669/5.187`; all-node explicit regular Times ASCII ellipse graphs up to 64 nodes use equivalent DejaVu Serif tables, reducing all 10 `b94.gv` node errors from a 47.32pt mean to 0.002pt with no crossing/overlap regressions; `b94` scores `0/1.051/2.261` versus Graphviz `0/2.080/4.171`; default-font, mixed-shape, or larger Times graphs retain crossing-validated conservative metrics; `1332` reduces the former 126 crossings to 8 with tight-rank closure optimization plus deepest-owner nested spacing, and stays within 20% edge length and 55% area. The same audit runs neato on `Petersen.gv`: Vex/Graphviz score 0/0 overlaps, 9/15 crossings, 0.540/0.643 edge-length CV, and 0.381/0.494 normalized stress, so Vex is no worse on every gated force invariant. It also gates sfdp on `Petersen.gv` (0/0 overlaps, 3/3 crossings, 0.242/0.206 CV, 0.171/0.174 stress) and fdp on attribute-neutral `p2.gv` (0/0 overlaps, 0/1 crossings, 0.250/0.338 CV, 0.040/0.102 stress).

For SVG parity work, `tools/svg_residual.py generated.svg graphviz.svg` reports
screen-space point residuals for ordered `polygon`, `polyline`, and `path`
geometry, skipping the root background polygon by default. Use
`--show-lower-bound` to show the best possible residual on the current
one-decimal coordinate grid, `--max-residual` to gate the absolute residual, and
`--max-gap` to gate only the remaining gap above that one-decimal lower bound.

`zig build test` also runs three ReleaseFast parser scale gates. The chain gate
generates 10,000 nodes / 9,999 edges with default `label="\N"` expansion. The
structured gate generates 4,096 nodes / 4,095 attributed edges across 64 named
subgraphs, with dense node and edge attributes. Each parse has a one-second
limit and an independent 32 MiB parser-arena budget inside a reusable fixed
64 MiB buffer. The stream visitor gate consumes 64 graphs with 256 nodes each
under an 8 MiB active-allocation limit, checks input order/counts, and releases
each graph before parsing the next. All report source bytes, memory budgets,
and elapsed milliseconds.
Run them directly with `zig build test-parse-scale`.

The development-only Graphviz corpus audit is reproducible with
`zig build audit-dot-corpus -Dgraphviz-root=/path/to/graphviz`. It scans every
`.dot` / `.gv` fixture below 16 MiB with the ReleaseFast Vex `--check` path,
covering the full local corpus. It excludes explicit HTML-like label fixtures
and gates the checked-in baseline: 808 candidates, 65 HTML-like exclusions,
737 successful non-HTML parses, five known malformed fixtures, one Graphviz
plain-output fixture, zero timeouts, and zero unexpected results. This command
requires a Graphviz source checkout only as development corpus data; Vex never
calls `dot`.

`zig build audit-cluster-corpus -Dgraphviz-root=/path/to/graphviz` extends the
same policy through native layout and SVG rendering for every non-HTML fixture
below 256 KiB that mentions subgraphs/clusters. Its checked-in baseline is 259
candidates: 257 valid SVG renders, two known malformed fixtures, and zero
timeouts, renderer failures, invalid SVG documents, or subgraph hierarchy
geometry violations. The audit enables SVG metadata and requires every nonempty
child subgraph box to be contained by its declared parent. XML processing
instructions such as `xml-stylesheet` are accepted before the SVG root.

`zig build audit-svg-corpus -Dgraphviz-root=/path/to/graphviz` renders the
entire non-HTML parse corpus. Its fast tier contains all 722 valid XML SVG
results under a two-second per-fixture gate; no slow fixtures remain, and five
known malformed/plain inputs remain excluded.
Any new timeout, renderer failure, non-finite numeric attribute, or invalid XML
fails the audit.

`zig build audit-large-svg-corpus -Dgraphviz-root=/path/to/graphviz` covers
the 16 non-HTML fixtures from 256 KiB through 16 MiB. Fifteen complete as valid XML
SVG under an eight-second per-fixture gate, one trailing-binary fixture is
tracked as malformed, and no large fixture remains excluded for layout speed. New timeouts, failures, non-finite attributes, or
invalid XML fail the audit.

The ReleaseFast `test-layout-render-scale` gate covers every native layout
family: layered, neato, fdp, Fruchterman-Reingold, sfdp, twopi, circo,
patchwork, and osage. Workloads include 256-node / 512-edge iterative graphs, a
192-node / 388-edge crossed layered graph, 2,048-node / 4,096-edge
sfdp/radial/circular graphs, and 4,096-node packing graphs. All use the original
fixed layout/render arenas, time and memory limits, SVG object-group counts,
and output hashes without writing generated SVG to disk. The layered graph is
rendered twice and must be byte-identical;
the combined process enforces a normalized 96 MiB peak-RSS limit.

`zig build test-layered-tall-scale` separately protects the virtual-layer
crossing path with a 5,002-node / 7,330-edge graph spanning 1,002 narrow ranks
and many long edges. Its ReleaseFast gate requires the default 24 crossing
passes to finish within three seconds and a 40 MiB layout arena. This catches
full-graph work accidentally repeated once per narrow rank, which the wider
crossing-grid workload cannot expose.

`zig build test-waypoint-scale` protects long-edge routing with an
18,432-node / 16,896-edge graph containing 152,064 waypoints. It requires
ReleaseFast layout and SVG rendering to stay within two seconds each and fixed
48 MiB arenas. The renderer indexes nodes by rank, so waypoint obstacle checks
visit only the relevant rank while preserving NodeId candidate order and exact
SVG bytes.

## Mainstream DOT support

The parser currently supports a practical, mainstream DOT subset:

- `graph` / `digraph` and optional `strict`.
- DOT graph streams containing multiple top-level graphs. `parseDotGraphs` /
  `parseInputGraphs` return an owned graph sequence, while the existing
  `parseDot` / `parseInput` APIs remain strict single-graph entry points. The
  CLI renders one complete SVG document per input graph in stream order.
  `visitDotGraphs` / `visitInputGraphs` and their diagnostic variants instead
  lend one completed graph to a callback, then immediately release it before
  parsing the next graph; callback code must not retain graph-owned slices.
  CLI `--check` uses this bounded-model path and keeps already-emitted summaries
  before a precise diagnostic from a later graph.
- Node statements: `A [label="Start", shape=box]`.
- Edge chains: `A -> B -> C [label="flow"]` or `a -- b`.
- Graphviz edge `key` is handled as parser-local edge identity: the same
  endpoints and key reopen an edge in non-strict graphs, while different keys
  create parallel edges; strict graphs remain unique by endpoints.
- Comma node lists in node statements and edge operands: `a, b -- c, d`.
- Subgraph blocks and subgraph edge operands: `{ a b } -> subgraph group { c d }`.
- Named subgraphs use parent-relative identity: reopening the same name under
  one parent merges members and attributes, while identical names under
  different parents remain distinct. The textual subgraph ID stays parser-local
  and is not a display label: only an explicit `label` renders text or reserves
  a cluster label band. Within an explicit subgraph label, Graphviz object
  escape `\G` expands to that subgraph's textual ID rather than the root graph;
  node-only `\N` remains literal.
- Empty named subgraphs remain available in the graph model and SVG metadata,
  including their attributes, but produce no layout box or visible cluster
  group. This preserves inspectability without inventing zero-content geometry.
- Anonymous subgraph blocks keep graph attributes local without becoming
  rendered cluster objects.
- Layered layout honors `clusterrank=local|global|none`: `local` enables
  nested subgraph boxes, contiguity, spacing, and compound-boundary routing;
  `global` and `none` retain subgraph structure and rank constraints while
  disabling special subgraph layout. Vex applies this mode by subgraph model
  identity and does not require a `cluster_` name prefix.
- Nested cluster bounds propagate deepest-first, so every ancestor contains
  expanded descendant labels, margins, and sibling boxes even across three or
  more hierarchy levels.
- Compound `ltail` / `lhead` clipping follows endpoint membership: the target
  subgraph or one of its descendants must contain the corresponding tail/head
  node and must not contain both endpoints. Invalid hints remain available as
  attributes/metadata but use ordinary node-boundary routing.
- The typed Zig API stores compound endpoints only as `SubgraphId`; it does not
  serialize a subgraph's display label into raw `ltail` / `lhead` attributes.
  DOT textual values remain parser-local, while SVG metadata exposes stable
  numeric endpoint IDs for both typed and parsed graphs.
- In local cluster ranking, subgraph `compact=true` enables a strong-cluster
  rank objective: member rank span is minimized with nested strong envelopes,
  cross-subgraph edges use a soft directional penalty, and internal `minlen`
  plus explicit rank constraints remain hard. The Zig API exposes this through
  `SubgraphOptions.compact` and `SubgraphAttr.compact`; it works for every Vex
  subgraph identity rather than only names beginning with `cluster_`.
- Layered graphs with subgraphs run cluster-aware crossing minimization a
  second time by default, matching Graphviz `remincross=true`. Set graph
  `remincross=false` to retain the stable first-pass cluster block order; the
  typed Zig API exposes the switch as `GraphAttr.remincross`.
- Layered crossing minimization honors Graphviz `mclimit`: it scales the
  MaxIter=24 and MinQuit=8 effort limits, while `crossing_passes` remains a
  direct maximum-pass override. The typed API exposes `GraphAttr.mclimit`.
- Layered ranking honors Graphviz `nslimit1` as
  `floor(nslimit1 * node_count)` network-simplex pivots. A zero or invalid value
  disables the rank simplex pass; the typed API exposes `GraphAttr.nslimit1`.
- Layered ranking honors Graphviz `searchsize` as the maximum negative
  cut-value tree-edge candidates examined for each ordinary rank-simplex pivot;
  the default is 30. The typed API exposes `GraphAttr.searchsize`.
- Layered rank-simplex subtree intervals use unique preorder ranges, so crossed
  multi-rank DAGs preserve a connected tight tree during pivots instead of
  failing with `DisconnectedTightTree`.
- Layered coordinate refinement honors Graphviz `nslimit` as
  `floor(nslimit * node_count)` refinement passes. `coordinate_passes`
  remains a direct override; the typed API exposes `GraphAttr.nslimit`.
- Layered layout honors Graphviz `ratio=compress` together with `size` by
  compacting complete virtual ranks, including long-edge waypoints, toward the
  rankdir-aware requested width. Node dimensions and hard same-rank spacing
  remain unchanged, and physically infeasible requests stop at the minimum
  non-overlapping extent.
- Layered layout honors Graphviz `ratio=auto` together with `page`: oversized
  layouts snap to an integer page grid using Graphviz `idealsize(.5)` scaling,
  including all rank directions, long-edge waypoints, and subgraph bounds.
  Node and text dimensions remain unchanged. Vex still emits one complete SVG
  document; `page` guides layout aspect but does not split SVG into pages. The
  typed API exposes `GraphAttr.page` and `GraphAttr.ratio = .auto`.
- Layered numeric ratios, `ratio=fill`, and `ratio=expand` also follow
  Graphviz `set_aspect`: node centers, long-edge waypoints, and subgraph bounds
  are stretched in layout space while node/text dimensions stay fixed.
  Horizontal `rankdir` modes swap the internal aspect axes like Graphviz.
- Layered ranking honors Graphviz `TBbalance=min|max`, moving unconstrained
  source/sink floaters to the selected boundary rank in every `rankdir`.
  Explicit `rank=source|sink` constraints remain exclusive and take precedence.
- Layered ranking defaults to integrated `newrank=true` semantics, so rank
  constraints can span sibling subgraphs without Graphviz's recursive-ranking
  restriction. Set `newrank=false` to restore Graphviz's legacy rank-constraint
  scope for local subgraph ranking; the typed API exposes `GraphAttr.newrank`
  and `addSubgraphRankConstraint`. In local mode, Graphviz-named `cluster*`
  subgraphs resolve overlapping membership by depth-first, first-sibling
  induction before applying a scoped rank set or computing the visible box;
  declared members remain intact in the graph model and SVG metadata. On the
  real `1767.dot` fixture this keeps both chain hierarchies while reducing
  normalized edge length/area from `4.30/10.45` to `2.27/8.58` (Graphviz
  `2.13/6.38`), with zero crossings and overlaps.
- After active `rank=same` sets are contracted, layered ranking detects DFS
  feedback constraints in the contracted graph and omits only those private
  rank constraints without reversing public edge endpoints. This keeps cluster
  back-edge routing intact and turns real `2825.dot` from 5 crossings and
  `11.39/21.41` normalized edge/area into 3 crossings and `3.23/5.47`, versus
  Graphviz's 5 crossings and `2.82/5.67`.
- Node `width`/`height` attributes are accepted only while their 72pt/in
  conversion fits signed point space, matching Graphviz's overflow fallback;
  edge-free single-rank graphs then use Graphviz's default 18pt nodesep when no
  explicit `nodesep` is present. Real `2784.dot` now has finite geometry and
  normalized area `1.80` instead of `9.93` (Graphviz `1.30`), while six other
  expanded-holdout fixtures only improve area.
- Small cluster graphs with at most 20 nodes, 40 edges, and 8,192
  combined same-rank slot permutations receive an exact multi-rank search. It
  preserves every rank's existing slots and each cluster's same-rank
  contiguity, accepting only lower physical crossings and then shorter edges.
  This makes original and annotation-heavy `clust5` declaration orders both
  zero-crossing; the round-trip variant improves from `2 / 2.74 / 5.16`
  crossings/edge/area to `0 / 2.61 / 5.03` versus Graphviz `0 / 2.50 / 5.88`.
- Multiline `doublecircle` nodes now use Graphviz's enclosing-ellipse fit
  for the padded label and add the 4pt gap between peripheries. This corrects
  undersized pipeline nodes and reduces original `pmpipe.gv` from 2 crossings
  to zero; normalized edge/area become `2.43/3.85` versus Graphviz
  `2.30/3.22`, while four other expanded-holdout families have no crossing or
  overlap regression.
- Final `ordering=out` projection now applies overlapping per-tail neighbor
  subsequences in stable reverse declaration order, then allows only
  crossing-reducing equal-width transpositions that preserve every ordering
  constraint. On `b58.gv`, both `1→2` and `7→5→4` remain ordered while
  crossings fall from 3 to Graphviz's 1; edge/area are `2.22/3.49` versus
  `2.13/3.12`, and the expanded 480-file audit changes no other fixture.
- Undirected graphs with explicit `splines=ortho` preserve textual endpoint
  direction in their private layered view, because circuit/process DOT uses
  those endpoints as hierarchy even without arrow semantics. Public graph and
  SVG edges remain undirected. Real `1658.dot` changes from 6 crossings and
  `2.50/5.56` normalized edge/area to 4 and `3.28/6.95`, matching Graphviz's
  `4 / 2.91 / 6.95`; no other expanded-holdout fixture changes.
- In local cluster ranking, if every member with incident edges already shares
  one rank, unpinned isolated members join that active rank instead of leaking
  onto root rank zero. This turns sparse cluster palettes into rows:
  `grdcolors.gv` normalized area falls from `14.72` to `3.55` versus Graphviz
  `3.44`, edge length remains slightly better, and two other expanded fixtures
  improve without crossing or overlap changes.
- For zero-crossing clusterless DAGs with `ordering=out`, each rank is
  repacked as a rigid minimum-width sequence and only its translation is solved
  by edge least squares; the candidate must preserve zero crossings and reduce
  extent. This removes NodeId first-declaration sensitivity: round-trip
  `grammar.gv` edge/area drops from `2.88/8.67` to `1.90/4.39`, beating
  Graphviz `2.02/5.18`; original grammar and `awilliams` also improve area.
- A final physical-rank adjacent transpose preserves each unequal-width pair
  boundary and accepts a swap only when true rank-height crossings strictly
  decrease, coordinate stress stays within 4%, and extent does not grow. Across
  the expanded 480-file holdout, 21 fixtures improve with no crossing or overlap
  regression; fixed `NaN` drops `82→51`, `b71` `9→6`, and `abstract` `58→57`,
  while `crazy`, `weight`, and `jsort` families also improve. A separate
  equal-crossing/stress-decreasing plateau starts from the same input, preserving
  the strict-only candidate and selecting only fewer crossings or equal
  crossings with shorter physical edges. The follow-up 480-file diff improves
  48 fixtures with no crossing, overlap, edge-length, or area regression:
  original `NaN` reaches 48, `viewfile` 5, `2413_2` 60, and LR rankdir
  round-trips match Graphviz at 4 crossings.
- Medium (48–64 node) directed clusterless feedback graphs receive one final
  stress-decreasing coordinate plateau after the independent center candidates
  are selected. The candidate is rejected unless physical crossings strictly
  decrease while edge length and extent do not grow and stress stays within 4%.
  Real `b57.gv` drops from 1 crossing to 0 (matching Graphviz), while normalized
  edge/area improve from `3.878/8.092` to `3.803/7.636`; a clean 480-file
  baseline diff changes only `b57` and has no invariant regression. Original
  undirected graphs and explicit rank/group/ordering contracts are excluded.
- The final Graphviz-style visual-padding correction for two cross-linked TB/BT
  clusters is now guarded by the same straight center-line crossing invariant as
  layout proper. If either sub-point correction adds a crossing, both node shifts
  roll back atomically. Real `try.gv` and its `share`/`windows` copies fall from
  1 crossing to 0 (matching Graphviz), with edge/area unchanged at `3.062/3.872`;
  a clean 480-file diff changes only those three copies.
- Nested cluster owners are finally split into weakly connected branch units for
  a bounded coordinate pass. A branch may align to sibling or descendant-owner
  boundaries, but is exposed only when physical crossings strictly decrease,
  edge length and extent do not grow, stress stays within 4%, and clearance plus
  ordering constraints remain valid. Real `2476.dot` improves from 2 crossings
  to 0 versus Graphviz 1, and edge length from `4.322` to `4.053` versus
  Graphviz `4.923`; a clean 480-file diff changes no other fixture.
- Equal-weight heavy pass-through nodes are rank-cost indifferent across their
  feasible interval. Choosing the source-side quartile instead of the midpoint
  keeps them off a boundary while reserving sink-side ranks for long feedback
  channels. Real `698066.dot` falls from 26 to 17 crossings and normalized
  edge length from `3.16` to `2.48`, versus Graphviz `24/3.92`; its area remains
  better at `5.88` versus `6.68`, and all other 479 holdout fixtures are unchanged.
- Low-crossing 32–64-node clusterless graphs retain a separate six-restart
  physical adjacent-swap barrier candidate. It may cross a local crossing
  barrier internally, but every retained state respects the 4% stress and
  non-expanding extent budgets, and only the best completed physical candidate
  can replace strict/plateau paths. Graphviz round-trip `width`/`height` changed
  only two `unix2` nodes by about 2.2pt/0.2pt yet moved four rank orders; the
  barrier candidate makes original and `share`/`windows`/`dotsplines` variants
  stable at 2 crossings versus Graphviz 3. The expanded holdout changes 15
  fixtures with no crossing, overlap, edge-length, or area regression.
- On directed clusterless graphs up to 31 nodes, an equal-weight one-in/one-out
  pass-through has the same weighted rank cost across its feasible interval. Vex
  now chooses that interval midpoint instead of letting a one-node occupancy tie
  pin it to a boundary. Real port-constrained `2734.dot` moves the flexible
  `node22` from rank 9 to rank 8 and drops from 1 crossing to 0, matching
  Graphviz; the other 479 expanded-holdout fixtures are unchanged. Private DAG
  views of undirected graphs are excluded, preserving the `1658.dot` circuit.
- For default local ranking on 2–8 disjoint, non-nested top-level clusters
  (at most 32 nodes/64 edges), when every node belongs to exactly one cluster,
  every cluster has an internal DAG edge, and no rank/newrank override is
  present, Vex now mirrors Graphviz cluster ranking: compute internal local
  offsets, collapse clusters to base variables, translate each inter-cluster
  edge through a Graphviz-style slack node with `CL_BACK=10` tail anchoring,
  then expand offsets. Real `2521_1.dot` contracts from 9 singleton ranks/1
  crossing to 5 local timeline ranks/0 crossings, with normalized edge/area
  `2.12/4.09` versus Graphviz `2.00/4.13`; the other 479 holdout fixtures are
  unchanged. Visual-only clusters and internal cycles are rejected.
- Rank subgraphs including `same`, `min`, `max`, `source`, and `sink`, with `source` / `sink` kept as exclusive boundary ranks.
- Port syntax in node ids: `a:out:e`.
- Attribute statements: `graph [rankdir=LR]`, `graph [layout=neato]`, `node [...]`, `edge [...]`.
- Graph `pad` plus graph/node margin attributes in inches, including zero and
  sub-inch values. Layered cluster `margin` follows Graphviz `dot`'s integer
  point-space semantics (`CL_OFFSET=8` in Graphviz; Vex's existing default
  cluster padding remains 12pt), so `margin=22` means 22 points rather than
  22 inches.
- Graphviz-style style lists separated by commas, semicolons, or whitespace.
- Order-sensitive SVG line styles for `solid`, `dashed`, and `dotted`.
- Graphviz `shape=plain` keeps a compact unboxed text node distinct from `shape=plaintext` / `shape=none`.
- Graph `quantum` rounds estimated label width and height upward in point-space
  quanta before shape sizing, consistently across layered and force layouts;
  invalid or nonpositive values leave dimensions unchanged. Graphviz
  `samplepoints` only affects image-map outline sampling, so Vex keeps it as a
  raw DOT attribute rather than exposing a typed SVG capability.
- SVG rendering for Graphviz-style node `diagonals` on polygonal and ellipse-like shapes.
- SVG rendering for Graphviz SBOLv node shapes `promoter`, `cds`, `terminator`, `utr`, `primersite`, `restrictionsite`, `fivepoverhang`, `threepoverhang`, `noverhang`, `assembly`, `signature`, `insulator`, `ribosite`, `rnastab`, `proteasesite`, `proteinstab`, `rpromoter`, `lpromoter`, `larrow`, and `rarrow`.
- SVG rendering for node `image`, deprecated `shapefile`, `imagescale`, and
  `imagepos` attributes inside the node box. Graph `imagepath` resolves relative
  image names to the first readable path-list entry while absolute and
  unresolved hrefs remain unchanged; the typed API exposes
  `GraphAttr.imagepath`.
- SVG rendering for Graphviz-style multicolor fills including box/node/subgraph `striped` fills and ellipse/circle `wedged` fills.
- SVG edge labels honor `decorate=true` with a label underline connected to the edge path.
- Edge `labelfloat=true` keeps the main edge label at its unconstrained route position.
- Edge `labelaligned=true` renders plain main edge labels with SVG `textPath` aligned to the edge path.
- M-shape nodes render `toplabel` and `bottomlabel` auxiliary labels where Graphviz defines them.
- Root graph labels default to bottom-center while explicit cluster labels default to top-center; unlabeled clusters reserve no label band. Cluster `labelloc=b` reserves the full label band below members (including inherited and nested cases) rather than only moving rendered text. Clusters inherit root `labelloc` / `labeljust` and label font attributes unless overridden.
- Clusters inherit root graph `fillcolor` / `pencolor` unless they set their own values.
- SVG group `id` attributes honor Graphviz object escapes and use the root graph `id` as a default prefix for child objects.
- SVG interactive anchors are wrapped in Graphviz-style `a_*` groups, including edge label, head label, and tail label anchors.
- SVG font output honors Graphviz `fontnames=svg|ps|gd` for standard PostScript font aliases, including family, weight, style, and stretch.
- SVG color and color-list attributes resolve all Graphviz ColorBrewer
  namespaces: 265 palette variants and 1,689 indexed colors across sequential,
  diverging, and qualitative schemes.
- SVG color attributes map Graphviz `transparent` to non-painted SVG output.
- SVG output honors Graphviz `size` for physical output dimensions while preserving layout coordinates in the `viewBox`.
- SVG output honors Graphviz numeric, fill, compress, auto, and expand ratios.
  Layered engines resolve their coordinate aspect before rendering; SVG then
  applies only the final physical `size` / page-grid output without re-scaling
  the viewBox. Node and text sizes remain unchanged by aspect stretching.
- SVG output honors Graphviz `dpi` and `resolution` when converting graph points to SVG device units.
- SVG output honors Graphviz `rotate=90`, `landscape=true`, and `orientation=landscape`.
- SVG output honors Graphviz `center=true` by centering drawings in oversized SVG canvases.
- SVG output honors Graphviz `layers`, `layersep`, `layerlistsep`, `layerselect`, and node, edge, and subgraph `layer` attributes by emitting separate SVG layer groups.
- Vex SVG output can optionally enable the current SVG-native tool surface plus metadata via `--interactive-all`, `interactive_all=true`, or `SvgOptions.interactive_all`.
- Vex SVG output can optionally embed native layer visibility controls via `--interactive-layers`, `interactive_layers=true`, or `SvgOptions.interactive_layers`.
- Vex SVG output can optionally embed native subgraph collapse controls via `--interactive-collapse`, `interactive_collapse=true`, or `SvgOptions.interactive_collapse`.
- Vex SVG output can optionally embed native object-type filter controls via `--interactive-filter`, `interactive_filter=true`, or `SvgOptions.interactive_filter`.
- Vex SVG output can optionally embed native label visibility controls via `--interactive-labels`, `interactive_labels=true`, or `SvgOptions.interactive_labels`.
- Vex SVG output can optionally embed native neighborhood focus controls via `--interactive-focus`, `interactive_focus=true`, or `SvgOptions.interactive_focus`.
- Vex SVG output can optionally embed native object inspector controls via `--interactive-inspector`, `interactive_inspector=true`, or `SvgOptions.interactive_inspector`.
- Vex SVG output can optionally embed native search/highlight controls via `--interactive-search`, `interactive_search=true`, or `SvgOptions.interactive_search`.
- Vex SVG output can optionally embed native pan/zoom viewport controls via `--interactive-viewport`, `interactive_viewport=true`, or `SvgOptions.interactive_viewport`.
- Vex SVG output can optionally embed a native minimap overview via `--interactive-minimap`, `interactive_minimap=true`, or `SvgOptions.interactive_minimap`.
- Vex SVG output can optionally embed a native graph statistics panel via `--interactive-stats`, `interactive_stats=true`, or `SvgOptions.interactive_stats`.
- Vex SVG output can optionally embed a machine-readable SVG metadata object index with graph structure, rank constraints, layout/canvas facts, rendered graph/node/edge/subgraph object attributes including subgraph parent/member relationships, edge record/compass ports, compound subgraph endpoints and effective edge layout values, a generic custom/future attribute index, object layers, effective `href` / `tooltip` / `target` metadata, graph/node/edge/subgraph object geometry, node ranks, edge waypoints, and layer metadata via `--svg-metadata`, `svg_metadata=true`, or `SvgOptions.metadata`.
- `splines` routing values including `true` / `false` aliases, `line`, `polyline`, `ortho`, and `none`.
- Edge `minlen=0` is preserved across DOT and typed APIs, allowing same-rank
  edges without silently raising the minimum rank distance to one.
- Graphviz boolean parsing for edge `constraint` treats unknown explicit text,
  including legacy `constraint=none`, as false instead of retaining the
  inherited default.
- True-default Graphviz booleans keep their default only when absent: explicit
  invalid `remincross`, `headclip`, or `tailclip` text maps to false.
- In layered layout, edge `weight=0` keeps its hard `minlen` constraint but is
  excluded from rank-span and coordinate attraction objectives. It still
  participates in ordinary crossing avoidance, matching Graphviz `xpenalty`.
- Graphviz arrow marker grammar including `normal`, `open`, `inv`, `curve`,
  `vee`, `dot`, `box`, `diamond`, `tee`, `crow`, open variants, `l` / `r`
  half-arrow modifiers, compatibility aliases, and compositions of up to four
  arrow parts. The typed API exposes composite `ArrowPart` sequences through
  `EdgeOptions.arrowheads` / `arrowtails` and `EdgeAttr`.
- Quoted strings with common Graphviz escapes (`\n`, `\l`, `\r`, escaped quotes/backslashes, line continuations), quoted-string concatenation with `+`, balanced angle-bracket IDs/labels retained as plain text, Graphviz NAME/NUMBER lexical boundaries, BOM, whitespace-free edge operators, numeric IDs, negative numeric IDs, UTF-8 IDs, and simple boolean attributes including `true` / `false`, `yes` / `no`, `on` / `off`, and `1` / `0`. Ambiguous numbers follow Graphviz `chkNum` tokenization, so inputs such as `1.2.3` split into `1.2` and `.3`, and the non-HTML Graphviz #2743 corpus parses without treating joined attributes as one malformed number. Bare IDs containing hyphens are rejected with a quote-it diagnostic, matching Graphviz's NAME grammar. Node-list edge fanout preserves each endpoint's record/compass port. SVG text rendering honors `\l` / `\r` line alignment for graph, node, subgraph, and external labels such as `xlabel`, `headlabel`, and `taillabel`; Graphviz object escapes include `\G`, `\N`, `\E`, `\T`, `\H`, and `\L`; default `node [...]` and `edge [...]` label attributes expand in each concrete node or edge context. After charset normalization and object-escape expansion, plain DOT labels decode Graphviz's 252-name HTML 4 entity table plus decimal/hex numeric references; unknown or malformed references remain literal, HTML-like angle labels are not double-decoded, and typed API text remains unchanged.
- DOT graphs declaring any Graphviz Latin-1 alias (`latin-1`, `latin1`, `l1`,
  `ISO-8859-1`, `ISO_8859-1`, `ISO8859-1`, or `ISO-IR-100`) are normalized
  to UTF-8 at the graph-model boundary. Graph, default, node, edge, subgraph,
  and record-port text therefore remains valid XML; the upstream `b56.gv`
  Latin-1 fixture renders as valid UTF-8 SVG.
- When input is declared/defaulted as UTF-8 but contains invalid byte
  sequences, Vex follows Graphviz and falls back to Latin-1 for that graph.
  XML 1.0-forbidden control characters are emitted as U+FFFD, so all SVG text
  and metadata remain UTF-8 and XML-valid.
- Graphviz `big5` / `big-5` graphs use an embedded, runtime-independent Big-5
  decoder covering Graphviz's `0xA1–0xFE` lead and standard trail ranges.
  Valid pairs become UTF-8 model text and malformed bytes become U+FFFD, so SVG
  remains XML-safe without depending on platform `iconv`.
- SVG text rendering honors `nojustify=true` for graph, node, edge, and subgraph labels.
- SVG rendering honors Graphviz `outputorder=edgesfirst|nodesfirst|breadthfirst`.
- Node and cluster `peripheries=0` hide borders while preserving fills.
- Line comments (`//`, `#`) and block comments (`/* ... */`).

## Output backends

- `svg`: vector output with labels and basic shapes.

The public render API keeps an `OutputFormat` dispatch layer so output backends can be added or removed without changing call sites that already pass a format.

Future work should expand remaining non-MVP DOT details—full cluster layout semantics and Graphviz edge cases—toward the full grammar in Graphviz's local source at
`~/Work/graphviz/lib/cgraph/grammar.y` and `~/Work/graphviz/doc/infosrc/grammar`.
Graphviz HTML-like label rendering is intentionally out of scope; angle-string
IDs and labels remain plain text in Vex. This is separate from the HTML 4
character references accepted by Graphviz in ordinary quoted labels, which Vex
does decode.

## Acknowledgments

This product includes color specifications and designs developed by Cynthia
Brewer (`colorbrewer.org`).
