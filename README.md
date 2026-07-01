# Topos

Topos is a Zig graph visualization prototype: DOT-compatible at the boundary,
with a native graph-building API inside. The long-term goal is to keep the
Graphviz ecosystem's strengths while exploring a cleaner, modern layout and
rendering architecture.

See [`docs/PROJECT_GUIDE.md`](docs/PROJECT_GUIDE.md) for the local project guide.

## Current MVP

- Zig 0.16 project.
- Core graph model with a programmatic builder API.
- DOT subset parser compatible with common `graph`/`digraph` files, including subgraphs and ports.
- Basic layered layout with `rankdir=TB|BT|LR|RL`.
- SVG renderer, terminal renderer, and a simple native PNG raster path.
- Output format dispatch for `terminal`, `svg`, `png`, and `pdf`.
- CLI that reads DOT from a file or stdin and writes to a file or stdout.

## CLI

```sh
zig build run -- --input examples/simple.dot --output simple.svg
zig build run -- --input examples/simple.dot --format terminal
zig build run -- --input examples/subgraph.dot --output subgraph.svg
zig build run -- --input examples/mainstream.dot --format terminal
zig build run -- --input examples/simple.dot --output simple.png
# or
cat examples/simple.dot | zig build run -- --format svg > simple.svg
```

## Zig API sketch

```zig
const std = @import("std");
const topos = @import("topos");

var graph = try topos.Graph.init(allocator, .{ .directed = true, .name = "G" });
defer graph.deinit();

const a = try graph.nodeWith("A", .{ .shape = .box, .label = "Start" });
const b = try graph.node("B");
_ = try graph.edge(a, b, .{ .label = "next" });

var layout = try topos.layoutLayered(allocator, &graph, .{});
defer layout.deinit();
try topos.render(writer, &graph, &layout, .svg, .{});
```

## Mainstream DOT support

The parser currently supports a practical, mainstream DOT subset:

- `graph` / `digraph` and optional `strict`.
- Node statements: `A [label="Start", shape=box]`.
- Edge chains: `A -> B -> C [label="flow"]` or `a -- b`.
- Comma node lists in node statements and edge operands: `a, b -- c, d`.
- Subgraph blocks and subgraph edge operands: `{ a b } -> subgraph cluster { c d }`.
- Port syntax in node ids: `a:out:e`.
- Attribute statements: `graph [rankdir=LR]`, `node [...]`, `edge [...]`.
- Quoted strings with common Graphviz escapes (`\n`, `\l`, `\r`, escaped quotes/backslashes, line continuations), quoted-string concatenation with `+`, HTML-like IDs/labels as text, numeric IDs, negative numeric IDs, UTF-8 IDs, and simple boolean attributes.
- Line comments (`//`, `#`) and block comments (`/* ... */`).

## Output backends

- `terminal`: quick text preview for shell workflows.
- `svg`: vector output with labels and basic shapes.
- `png`: simple built-in rasterizer for early snapshots.
- `pdf`: compact vector output using a built-in minimal PDF writer.

The native PNG/PDF paths are intentionally dependency-free MVP backends: PNG currently rasterizes boxes/edges without text; PDF keeps vector edges, boxes, and labels.

Future work should expand remaining non-MVP DOT details—full cluster layout semantics, complete HTML-label rendering, and all Graphviz edge cases—toward the full grammar in Graphviz's local source at
`~/Work/graphviz/lib/cgraph/grammar.y` and `~/Work/graphviz/doc/infosrc/grammar`.
