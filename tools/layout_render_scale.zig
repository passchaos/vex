const std = @import("std");
const builtin = @import("builtin");
const vex = @import("vex");

const rank_count: usize = 12;
const rank_width: usize = 16;
const layered_node_count: usize = rank_count * rank_width;
const layered_subgraph_count: usize = 4;
const layered_edge_count: usize = 388;
const force_node_count: usize = 256;
const force_edge_count: usize = 512;
const layout_memory_limit: usize = 16 * 1024 * 1024;
const render_memory_limit: usize = 8 * 1024 * 1024;
const layout_arena_limit: usize = 8 * 1024 * 1024;
const render_arena_limit: usize = 4 * 1024 * 1024;
const layout_time_limit_ns: i96 = 3 * std.time.ns_per_s;
const render_time_limit_ns: i96 = std.time.ns_per_s;
const peak_rss_limit: usize = 96 * 1024 * 1024;

pub fn main(init: std.process.Init) !void {
    const layered = try runLayeredGate(init);
    const force = try runForceGate(init);
    const peak_rss_bytes = processPeakRssBytes();
    if (peak_rss_bytes > peak_rss_limit) return error.ScalePeakRssLimitExceeded;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), init.io, &stdout_buffer);
    try printGateResult(&stdout.interface, "layered", layered);
    try printGateResult(&stdout.interface, "sfdp", force);
    try stdout.interface.print("layout-render-scale peak_rss_bytes={d}\n", .{peak_rss_bytes});
    try stdout.interface.flush();
}

const LayoutRenderGateResult = struct {
    nodes: usize,
    edges: usize,
    subgraphs: usize,
    layout_arena_bytes: usize,
    layout_elapsed_ns: i96,
    render_arena_bytes: usize,
    render_elapsed_ns: i96,
    svg_bytes: usize,
    svg_hash: u64,
};

fn runLayeredGate(init: std.process.Init) !LayoutRenderGateResult {
    const allocator = init.gpa;
    var graph = try buildLayeredGraph(allocator);
    defer graph.deinit();

    const layout_memory = try allocator.alloc(u8, layout_memory_limit);
    defer allocator.free(layout_memory);
    var layout_fixed = std.heap.FixedBufferAllocator.init(layout_memory);
    const layout_start = std.Io.Clock.awake.now(init.io);
    var layout = try vex.layoutGraph(layout_fixed.allocator(), &graph, .{ .algorithm = .sugiyama });
    const layout_elapsed_ns = layout_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const layout_arena_bytes = layout_fixed.end_index;
    defer layout.deinit();

    if (layout.nodes.len != layered_node_count) return error.LayoutScaleNodeCountMismatch;
    if (layout.subgraphs.len != layered_subgraph_count) return error.LayoutScaleSubgraphCountMismatch;
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
    const first = try renderGate(init, render_memory, &layout, .{
        .nodes = layered_node_count,
        .edges = layered_edge_count,
        .subgraphs = layered_subgraph_count,
    });
    const second = try renderGate(init, render_memory, &layout, .{
        .nodes = layered_node_count,
        .edges = layered_edge_count,
        .subgraphs = layered_subgraph_count,
    });
    if (first.hash != second.hash or first.bytes != second.bytes) {
        return error.RenderScaleNondeterministicOutput;
    }

    return .{
        .nodes = graph.nodes.items.len,
        .edges = graph.edges.items.len,
        .subgraphs = graph.subgraphs.items.len,
        .layout_arena_bytes = layout_arena_bytes,
        .layout_elapsed_ns = layout_elapsed_ns,
        .render_arena_bytes = first.arena_bytes,
        .render_elapsed_ns = first.elapsed_ns,
        .svg_bytes = first.bytes,
        .svg_hash = first.hash,
    };
}

fn buildLayeredGraph(allocator: std.mem.Allocator) !vex.Graph {
    var graph = try vex.Graph.init(allocator, .{
        .directed = true,
        .name = "LayoutRenderScale",
        .rankdir = .LR,
    });
    errdefer graph.deinit();
    try graph.setGraphAttr(.{ .compound = true });
    try graph.setGraphAttr(.{ .splines = .curved });

    for (0..layered_node_count) |node_id| {
        var label_buffer: [64]u8 = undefined;
        const label = try std.fmt.bufPrint(&label_buffer, "Node {d} payload", .{node_id});
        const id = try graph.addNode(label, .{
            .shape = if (node_id % 5 == 0) .diamond else .box,
        });
        if (node_id % 3 == 0) try graph.setNodeAttr(id, .{ .style = .rounded });
        if (node_id % 7 == 0) try graph.setNodeAttr(id, .{ .fillcolor = "#dbeafe" });
    }

    for (0..layered_subgraph_count) |group| {
        var members: [rank_count * (rank_width / layered_subgraph_count)]vex.NodeId = undefined;
        var member_index: usize = 0;
        for (0..rank_count) |rank| {
            for (0..rank_width / layered_subgraph_count) |offset| {
                members[member_index] = rank * rank_width + group * (rank_width / layered_subgraph_count) + offset;
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
    if (graph.edges.items.len != layered_edge_count) return error.LayoutScaleEdgeCountMismatch;
    return graph;
}

fn runForceGate(init: std.process.Init) !LayoutRenderGateResult {
    const allocator = init.gpa;
    var graph = try buildForceGraph(allocator);
    defer graph.deinit();

    const layout_memory = try allocator.alloc(u8, layout_memory_limit);
    defer allocator.free(layout_memory);
    var layout_fixed = std.heap.FixedBufferAllocator.init(layout_memory);
    const layout_start = std.Io.Clock.awake.now(init.io);
    var layout = try vex.layoutGraph(layout_fixed.allocator(), &graph, .{
        .algorithm = .multilevel_spring_electrical,
        .force = .{
            .width = 1200,
            .height = 800,
            .margin = 30,
            .iterations = 40,
        },
    });
    const layout_elapsed_ns = layout_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const layout_arena_bytes = layout_fixed.end_index;
    defer layout.deinit();

    if (layout.nodes.len != force_node_count) return error.LayoutScaleNodeCountMismatch;
    if (layout.subgraphs.len != 0) return error.LayoutScaleSubgraphCountMismatch;
    if (layout_elapsed_ns > layout_time_limit_ns) return error.LayoutScaleTimeLimitExceeded;
    if (layout_arena_bytes > layout_arena_limit) return error.LayoutScaleMemoryLimitExceeded;

    const render_memory = try allocator.alloc(u8, render_memory_limit);
    defer allocator.free(render_memory);
    const rendered = try renderGate(init, render_memory, &layout, .{
        .nodes = force_node_count,
        .edges = force_edge_count,
        .subgraphs = 0,
    });

    return .{
        .nodes = graph.nodes.items.len,
        .edges = graph.edges.items.len,
        .subgraphs = graph.subgraphs.items.len,
        .layout_arena_bytes = layout_arena_bytes,
        .layout_elapsed_ns = layout_elapsed_ns,
        .render_arena_bytes = rendered.arena_bytes,
        .render_elapsed_ns = rendered.elapsed_ns,
        .svg_bytes = rendered.bytes,
        .svg_hash = rendered.hash,
    };
}

fn buildForceGraph(allocator: std.mem.Allocator) !vex.Graph {
    var graph = try vex.Graph.init(allocator, .{
        .directed = false,
        .name = "ForceScale",
    });
    errdefer graph.deinit();

    for (0..force_node_count) |node| {
        var label_buffer: [32]u8 = undefined;
        _ = try graph.addNode(
            try std.fmt.bufPrint(&label_buffer, "n{d}", .{node}),
            .{ .shape = if (node % 11 == 0) .diamond else .ellipse },
        );
    }
    for (0..force_node_count) |node| {
        _ = try graph.addEdge(node, (node + 1) % force_node_count, .{});
        _ = try graph.addEdge(node, (node + 17) % force_node_count, .{});
    }
    if (graph.edges.items.len != force_edge_count) return error.LayoutScaleEdgeCountMismatch;
    return graph;
}

const RenderGateResult = struct {
    bytes: usize,
    hash: u64,
    arena_bytes: usize,
    elapsed_ns: i96,
};

const RenderExpectedCounts = struct {
    nodes: usize,
    edges: usize,
    subgraphs: usize,
};

fn renderGate(init: std.process.Init, render_memory: []u8, layout: *const vex.Layout, expected: RenderExpectedCounts) !RenderGateResult {
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
    if (countOccurrences(svg, " class=\"node\"") != expected.nodes) return error.RenderScaleNodeGroupCountMismatch;
    if (countOccurrences(svg, " class=\"edge\"") != expected.edges) return error.RenderScaleEdgeGroupCountMismatch;
    if (countOccurrences(svg, " class=\"cluster\"") != expected.subgraphs) return error.RenderScaleSubgraphGroupCountMismatch;

    return .{
        .bytes = svg.len,
        .hash = std.hash.Wyhash.hash(0, svg),
        .arena_bytes = arena_bytes,
        .elapsed_ns = elapsed_ns,
    };
}

fn printGateResult(writer: *std.Io.Writer, name: []const u8, result: LayoutRenderGateResult) !void {
    try writer.print(
        "layout-render-scale {s} ok: nodes={d} edges={d} subgraphs={d} layout_ms={d} layout_arena_bytes={d} render_ms={d} render_arena_bytes={d} svg_bytes={d} svg_hash={x}\n",
        .{
            name,
            result.nodes,
            result.edges,
            result.subgraphs,
            @divTrunc(result.layout_elapsed_ns, std.time.ns_per_ms),
            result.layout_arena_bytes,
            @divTrunc(result.render_elapsed_ns, std.time.ns_per_ms),
            result.render_arena_bytes,
            result.svg_bytes,
            result.svg_hash,
        },
    );
}

fn processPeakRssBytes() usize {
    if (!@hasDecl(std.posix, "getrusage") or @TypeOf(std.c.rusage) == void) return 0;
    const usage = std.posix.getrusage(std.c.rusage.SELF);
    return switch (builtin.os.tag) {
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => @intCast(usage.maxrss),
        .dragonfly, .freebsd, .netbsd, .openbsd, .illumos, .linux, .serenity => @as(usize, @intCast(usage.maxrss)) * 1024,
        else => 0,
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
