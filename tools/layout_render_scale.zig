const std = @import("std");
const vex = @import("vex");

const rank_count: usize = 12;
const rank_width: usize = 16;
const node_count: usize = rank_count * rank_width;
const subgraph_count: usize = 4;
const expected_edge_count: usize = 388;
const layout_memory_limit: usize = 16 * 1024 * 1024;
const render_memory_limit: usize = 8 * 1024 * 1024;
const layout_arena_limit: usize = 8 * 1024 * 1024;
const render_arena_limit: usize = 4 * 1024 * 1024;
const layout_time_limit_ns: i96 = 3 * std.time.ns_per_s;
const render_time_limit_ns: i96 = std.time.ns_per_s;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var graph = try buildGraph(allocator);
    defer graph.deinit();

    const layout_memory = try allocator.alloc(u8, layout_memory_limit);
    defer allocator.free(layout_memory);
    var layout_fixed = std.heap.FixedBufferAllocator.init(layout_memory);
    const layout_start = std.Io.Clock.awake.now(init.io);
    var layout = try vex.layoutGraph(layout_fixed.allocator(), &graph, .{ .algorithm = .sugiyama });
    const layout_elapsed_ns = layout_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const layout_arena_bytes = layout_fixed.end_index;
    defer layout.deinit();

    if (layout.nodes.len != node_count) return error.LayoutScaleNodeCountMismatch;
    if (layout.subgraphs.len != subgraph_count) return error.LayoutScaleSubgraphCountMismatch;
    if (layout_elapsed_ns > layout_time_limit_ns) return error.LayoutScaleTimeLimitExceeded;
    if (layout_arena_bytes > layout_arena_limit) return error.LayoutScaleMemoryLimitExceeded;
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        if (layout.ranks[edge_item.from] >= layout.ranks[edge_item.to]) {
            return error.LayoutScaleRankDirectionMismatch;
        }
    }

    const render_memory = try allocator.alloc(u8, render_memory_limit);
    defer allocator.free(render_memory);
    const first = try renderGate(init, render_memory, &layout);
    const second = try renderGate(init, render_memory, &layout);
    if (first.hash != second.hash or first.bytes != second.bytes) {
        return error.RenderScaleNondeterministicOutput;
    }

    var stdout_buffer: [512]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), init.io, &stdout_buffer);
    try stdout.interface.print(
        "layout-render-scale ok: nodes={d} edges={d} subgraphs={d} layout_ms={d} layout_arena_bytes={d} render_ms={d} render_arena_bytes={d} svg_bytes={d} svg_hash={x}\n",
        .{
            graph.nodes.items.len,
            graph.edges.items.len,
            graph.subgraphs.items.len,
            @divTrunc(layout_elapsed_ns, std.time.ns_per_ms),
            layout_arena_bytes,
            @divTrunc(first.elapsed_ns, std.time.ns_per_ms),
            first.arena_bytes,
            first.bytes,
            first.hash,
        },
    );
    try stdout.interface.flush();
}

fn buildGraph(allocator: std.mem.Allocator) !vex.Graph {
    var graph = try vex.Graph.init(allocator, .{
        .directed = true,
        .name = "LayoutRenderScale",
        .rankdir = .LR,
    });
    errdefer graph.deinit();
    try graph.setGraphAttr(.{ .compound = true });
    try graph.setGraphAttr(.{ .splines = .curved });

    for (0..node_count) |node_id| {
        var label_buffer: [64]u8 = undefined;
        const label = try std.fmt.bufPrint(&label_buffer, "Node {d} payload", .{node_id});
        const id = try graph.addNode(label, .{
            .shape = if (node_id % 5 == 0) .diamond else .box,
        });
        if (node_id % 3 == 0) try graph.setNodeAttr(id, .{ .style = .rounded });
        if (node_id % 7 == 0) try graph.setNodeAttr(id, .{ .fillcolor = "#dbeafe" });
    }

    for (0..subgraph_count) |group| {
        var members: [rank_count * (rank_width / subgraph_count)]vex.NodeId = undefined;
        var member_index: usize = 0;
        for (0..rank_count) |rank| {
            for (0..rank_width / subgraph_count) |offset| {
                members[member_index] = rank * rank_width + group * (rank_width / subgraph_count) + offset;
                member_index += 1;
            }
        }
        var name_buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buffer, "service_{d}", .{group});
        _ = try graph.addSubgraph(name, null, &members, .{});
    }

    for (0..rank_count - 1) |rank| {
        for (0..rank_width) |column| {
            const from = rank * rank_width + column;
            _ = try graph.addEdge(from, (rank + 1) * rank_width + column, .{ .weight = 3 });

            var label_buffer: [32]u8 = undefined;
            const label = try std.fmt.bufPrint(&label_buffer, "e{d}-{d}", .{ rank, column });
            _ = try graph.addEdge(
                from,
                (rank + 1) * rank_width + ((column * 5 + rank * 3 + 1) % rank_width),
                .{ .label = if (column % 4 == 0) label else null },
            );

            if (rank + 3 < rank_count and column % 4 == 0) {
                _ = try graph.addEdge(
                    from,
                    (rank + 3) * rank_width + ((column + 7) % rank_width),
                    .{ .min_len = 3, .color = "#dc2626" },
                );
            }
        }
    }
    if (graph.edges.items.len != expected_edge_count) return error.LayoutScaleEdgeCountMismatch;
    return graph;
}

const RenderGateResult = struct {
    bytes: usize,
    hash: u64,
    arena_bytes: usize,
    elapsed_ns: i96,
};

fn renderGate(init: std.process.Init, render_memory: []u8, layout: *const vex.Layout) !RenderGateResult {
    var render_fixed = std.heap.FixedBufferAllocator.init(render_memory);
    const start = std.Io.Clock.awake.now(init.io);
    const svg = try vex.renderAlloc(render_fixed.allocator(), layout, .svg, .{});
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const arena_bytes = render_fixed.end_index;
    defer render_fixed.allocator().free(svg);

    if (elapsed_ns > render_time_limit_ns) return error.RenderScaleTimeLimitExceeded;
    if (arena_bytes > render_arena_limit) return error.RenderScaleMemoryLimitExceeded;
    if (!std.mem.startsWith(u8, svg, "<svg ")) return error.RenderScaleMissingSvgOpen;
    if (!std.mem.endsWith(u8, svg, "</svg>")) return error.RenderScaleMissingSvgClose;
    if (countOccurrences(svg, " class=\"node\"") != node_count) return error.RenderScaleNodeGroupCountMismatch;
    if (countOccurrences(svg, " class=\"edge\"") != expected_edge_count) return error.RenderScaleEdgeGroupCountMismatch;
    if (countOccurrences(svg, " class=\"cluster\"") != subgraph_count) return error.RenderScaleSubgraphGroupCountMismatch;

    return .{
        .bytes = svg.len,
        .hash = std.hash.Wyhash.hash(0, svg),
        .arena_bytes = arena_bytes,
        .elapsed_ns = elapsed_ns,
    };
}

fn countOccurrences(haystack: []const u8, needle: []const u8) usize {
    var count: usize = 0;
    var offset: usize = 0;
    while (std.mem.indexOfPos(u8, haystack, offset, needle)) |index| {
        count += 1;
        offset = index + needle.len;
    }
    return count;
}
