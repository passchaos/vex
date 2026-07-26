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

Layout selection defaults to `dot`/Sugiyama, which honors
`rankdir=TB|BT|LR|RL` during layout. `--layout neato`, `graph
[layout=neato]`, and Graphviz-style `-Kneato` select the deterministic
stress-majorization engine. `--layout fdp`, `graph [layout=fdp]`, and `-Kfdp`
select the independent spring-electrical engine with all-pairs repulsion,
edge-only springs, cluster boxes, graph `K` / `T0`, and edge `len` / `weight`
semantics. `--layout fr` selects the deterministic Fruchterman-Reingold
engine. `--layout sfdp`, `graph [layout=sfdp]`, and `-Ksfdp` select the
independent deterministic multilevel spring-electrical engine. It supports
Graphviz-style `levels`, `K`, and `repulsiveforce`; like Graphviz sfdp, it
does not model clusters or edge `len` / `weight`. Fine-level repulsion uses a
deterministic Barnes-Hut quadtree above the exact small-graph threshold, with
tests bounding force error and repulsion work plus a 512-node SVG smoke.
`--layout twopi`, `graph [layout=twopi]`, and `-Ktwopi` select the independent
radial engine. It honors graph `root`, node `root=true`, `ranksep`, BFS
graph-distance rings, subtree-weighted angular spans, and disconnected
component packing.
`--layout circo`, `graph [layout=circo]`, and `-Kcirco` select the independent
circular engine. It uses Tarjan biconnected blocks, places each block on a
circle, recursively joins the block-cut tree at articulation nodes, packs
disconnected components, and honors `root`, `mindist`, and `oneblock`.
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
`graph [vex_layout_iterations=20]` or
`graph [layout_iterations=20]`, and the Zig API can pass
`.{ .force = .{ .iterations = 20 } }`.
`--layout-work-budget` provides a deterministic cross-engine cancellation
budget for CI and bounded previews. The Zig API can use a custom
`LayoutControl` callback or the built-in `LayoutWorkBudget`; cancellation
returns `error.LayoutCanceled` without returning a partial `Layout`.
For layered/Sugiyama layout, `--crossing-passes` and `--coordinate-passes`
control crossing-reduction and coordinate-refinement budgets. DOT can set the
same budgets with `vex_crossing_passes`, `vex_coordinate_passes`, or the shorter
`crossing_passes` / `coordinate_passes` aliases, and the Zig API can pass
`LayoutConfig.layered`.

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
`graph [vex_svg_metadata=true]`, and the Zig API can pass
`.{ .svg = .{ .metadata = true } }`.

`--interactive-all` enables the current SVG-native tool surface at once:
metadata, layer controls when layers exist, collapse, filters, label toggles,
focus, inspector, search, viewport controls, minimap, and stats. DOT can enable
the same preset with `graph [vex_interactive_all=true]`, and the Zig API can
pass `.{ .svg = .{ .interactive_all = true } }`.

`--interactive-layers` is a Vex SVG extension. When a graph declares
Graphviz-style `layers`, it embeds a small self-contained SVG control panel for
toggling layer visibility. The same behavior can be enabled from DOT with
`graph [vex_interactive_layers=true]` or from the Zig API with
`.{ .svg = .{ .interactive_layers = true } }`.

`--interactive-collapse` embeds subgraph collapse and expand controls. It marks
member nodes and internal edges so a generated SVG can hide or restore a
subgraph's contents without re-rendering. It can also be enabled from DOT with
`graph [vex_interactive_collapse=true]` or from the Zig API with
`.{ .svg = .{ .interactive_collapse = true } }`.

`--interactive-filter` embeds object-type filters for nodes, edges, and
subgraphs. It can also be enabled from DOT with
`graph [vex_interactive_filter=true]` or from the Zig API with
`.{ .svg = .{ .interactive_filter = true } }`.

`--interactive-labels` embeds label visibility controls for nodes, edges, and
subgraphs. It can also be enabled from DOT with
`graph [vex_interactive_labels=true]` or from the Zig API with
`.{ .svg = .{ .interactive_labels = true } }`.

`--interactive-focus` lets generated SVGs focus a selected node or edge and its
neighborhood while dimming unrelated objects. It can also be enabled from DOT
with `graph [vex_interactive_focus=true]` or from the Zig API with
`.{ .svg = .{ .interactive_focus = true } }`.

`--interactive-inspector` embeds an object inspector panel. Clicking a node,
edge, or subgraph shows its type, id/label, and selected metadata. It can also
be enabled from DOT with `graph [vex_interactive_inspector=true]` or from the
Zig API with `.{ .svg = .{ .interactive_inspector = true } }`.

`--interactive-search` is another Vex SVG extension. It embeds a self-contained
search and highlight panel and annotates rendered nodes, edges, and subgraphs
with searchable labels and metadata. It can also be enabled from DOT with
`graph [vex_interactive_search=true]` or from the Zig API with
`.{ .svg = .{ .interactive_search = true } }`.

`--interactive-viewport` adds a self-contained pan, zoom, and reset panel around
the rendered graph content. It can also be enabled from DOT with
`graph [vex_interactive_viewport=true]` or from the Zig API with
`.{ .svg = .{ .interactive_viewport = true } }`.

`--interactive-minimap` adds a self-contained overview panel for navigating the
rendered graph. Clicking nodes or subgraph boxes in the minimap recenters the
main SVG viewport. It can also be enabled from DOT with
`graph [vex_interactive_minimap=true]` or from the Zig API with
`.{ .svg = .{ .interactive_minimap = true } }`.

`--interactive-stats` adds a self-contained graph statistics panel with object
counts, layout size, canvas size, direction, and rank direction. It can also be
enabled from DOT with `graph [vex_interactive_stats=true]` or from the Zig API
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

## Graphviz compatibility target

Vex is intended to reimplement Graphviz behavior rather than shell out to
`dot`. During development, Graphviz should be used as an oracle in tests and
fixtures: compare parsed semantics, layout coordinates, and rendered output for
representative graphs, then close gaps in the native implementation. Runtime CLI
rendering should stay on Vex's native parser/layout/renderers.

For invariant layout-quality work, `zig build audit-layout-quality -Dgraphviz-root=/path/to/graphviz` compares Vex and Graphviz on real sparse-undirected `ngk10_4.gv` and directed-DAG `fig6.gv` fixtures. Both must have zero node overlaps and bounded center-line crossings, edge length, and normalized canvas area; the aggregate crossing gate is 335. Current Vex scores are 234/80 crossings versus Graphviz's 206/62 (314 versus 268 aggregate). Vex uses substantially shorter edges and about half the normalized area on `ngk10_4`; `fig6` stays within 15% edge length and 10% area of Graphviz.

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
  MaxIter=24 and MinQuit=8 effort limits, while `vex_crossing_passes` remains a
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
  `floor(nslimit * node_count)` refinement passes. `vex_coordinate_passes`
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
  and `addSubgraphRankConstraint`.
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
- Vex SVG output can optionally enable the current SVG-native tool surface plus metadata via `--interactive-all`, `vex_interactive_all=true`, or `SvgOptions.interactive_all`.
- Vex SVG output can optionally embed native layer visibility controls via `--interactive-layers`, `vex_interactive_layers=true`, or `SvgOptions.interactive_layers`.
- Vex SVG output can optionally embed native subgraph collapse controls via `--interactive-collapse`, `vex_interactive_collapse=true`, or `SvgOptions.interactive_collapse`.
- Vex SVG output can optionally embed native object-type filter controls via `--interactive-filter`, `vex_interactive_filter=true`, or `SvgOptions.interactive_filter`.
- Vex SVG output can optionally embed native label visibility controls via `--interactive-labels`, `vex_interactive_labels=true`, or `SvgOptions.interactive_labels`.
- Vex SVG output can optionally embed native neighborhood focus controls via `--interactive-focus`, `vex_interactive_focus=true`, or `SvgOptions.interactive_focus`.
- Vex SVG output can optionally embed native object inspector controls via `--interactive-inspector`, `vex_interactive_inspector=true`, or `SvgOptions.interactive_inspector`.
- Vex SVG output can optionally embed native search/highlight controls via `--interactive-search`, `vex_interactive_search=true`, or `SvgOptions.interactive_search`.
- Vex SVG output can optionally embed native pan/zoom viewport controls via `--interactive-viewport`, `vex_interactive_viewport=true`, or `SvgOptions.interactive_viewport`.
- Vex SVG output can optionally embed a native minimap overview via `--interactive-minimap`, `vex_interactive_minimap=true`, or `SvgOptions.interactive_minimap`.
- Vex SVG output can optionally embed a native graph statistics panel via `--interactive-stats`, `vex_interactive_stats=true`, or `SvgOptions.interactive_stats`.
- Vex SVG output can optionally embed a machine-readable SVG metadata object index with graph structure, rank constraints, layout/canvas facts, rendered graph/node/edge/subgraph object attributes including subgraph parent/member relationships, edge record/compass ports, compound subgraph endpoints and effective edge layout values, a generic custom/future attribute index, object layers, effective `href` / `tooltip` / `target` metadata, graph/node/edge/subgraph object geometry, node ranks, edge waypoints, and layer metadata via `--svg-metadata`, `vex_svg_metadata=true`, or `SvgOptions.metadata`.
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
- Quoted strings with common Graphviz escapes (`\n`, `\l`, `\r`, escaped quotes/backslashes, line continuations), quoted-string concatenation with `+`, balanced angle-bracket IDs/labels retained as plain text, Graphviz NAME/NUMBER lexical boundaries, BOM, whitespace-free edge operators, numeric IDs, negative numeric IDs, UTF-8 IDs, and simple boolean attributes including `true` / `false`, `yes` / `no`, `on` / `off`, and `1` / `0`. Ambiguous numbers follow Graphviz `chkNum` tokenization, so inputs such as `1.2.3` split into `1.2` and `.3`, and the non-HTML Graphviz #2743 corpus parses without treating joined attributes as one malformed number. Bare IDs containing hyphens are rejected with a quote-it diagnostic, matching Graphviz's NAME grammar. Node-list edge fanout preserves each endpoint's record/compass port. SVG text rendering honors `\l` / `\r` line alignment for graph, node, subgraph, and external labels such as `xlabel`, `headlabel`, and `taillabel`; Graphviz object escapes include `\G`, `\N`, `\E`, `\T`, `\H`, and `\L`; default `node [...]` and `edge [...]` label attributes expand in each concrete node or edge context.
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
IDs and labels remain plain text in Vex.

## Acknowledgments

This product includes color specifications and designs developed by Cynthia
Brewer (`colorbrewer.org`).
