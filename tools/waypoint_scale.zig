const std = @import("std");
const vex = @import("vex");

const chain_count: usize = 1_536;
const chain_depth: usize = 12;
const node_count: usize = chain_count * chain_depth;
const edge_count: usize = chain_count * (chain_depth - 1);
const layout_memory_limit: usize = 64 * 1024 * 1024;
const render_memory_limit: usize = 64 * 1024 * 1024;
const layout_arena_limit: usize = 48 * 1024 * 1024;
const render_arena_limit: usize = 48 * 1024 * 1024;
const layout_time_limit_ns: i96 = 2 * std.time.ns_per_s;
const render_time_limit_ns: i96 = 2 * std.time.ns_per_s;

pub fn main(init: std.process.Init) !void {
    var graph = try buildGraph(init.gpa);
    defer graph.deinit();

    const layout_memory = try init.gpa.alloc(u8, layout_memory_limit);
    defer init.gpa.free(layout_memory);
    var layout_fixed = std.heap.FixedBufferAllocator.init(layout_memory);
    const layout_start = std.Io.Clock.awake.now(init.io);
    var layout = try vex.layoutGraph(layout_fixed.allocator(), &graph, .{
        .algorithm = .sugiyama,
        .layered = .{
            .crossing_passes = 0,
            .coordinate_passes = 0,
        },
    });
    const layout_elapsed_ns = layout_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    defer layout.deinit();
    if (layout.nodes.len != node_count) return error.WaypointScaleNodeCountMismatch;
    if (layout.edge_waypoints.len != edge_count) return error.WaypointScaleEdgeCountMismatch;
    if (layout_elapsed_ns > layout_time_limit_ns) return error.WaypointScaleLayoutTimeLimitExceeded;
    if (layout_fixed.end_index > layout_arena_limit) return error.WaypointScaleLayoutMemoryLimitExceeded;

    var waypoint_count: usize = 0;
    for (layout.edge_waypoints) |waypoints| waypoint_count += waypoints.points.len;
    if (waypoint_count != edge_count * 9) return error.WaypointScaleCountMismatch;

    const render_memory = try init.gpa.alloc(u8, render_memory_limit);
    defer init.gpa.free(render_memory);
    var render_fixed = std.heap.FixedBufferAllocator.init(render_memory);
    const render_start = std.Io.Clock.awake.now(init.io);
    const svg = try vex.renderAlloc(render_fixed.allocator(), &layout, .svg, .{});
    const render_elapsed_ns = render_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    defer render_fixed.allocator().free(svg);
    if (render_elapsed_ns > render_time_limit_ns) return error.WaypointScaleRenderTimeLimitExceeded;
    if (render_fixed.end_index > render_arena_limit) return error.WaypointScaleRenderMemoryLimitExceeded;
    if (countOccurrences(svg, " class=\"node\"") != node_count) return error.WaypointScaleSvgNodeCountMismatch;
    if (countOccurrences(svg, " class=\"edge\"") != edge_count) return error.WaypointScaleSvgEdgeCountMismatch;

    var stdout_buffer: [512]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), init.io, &stdout_buffer);
    try stdout.interface.print(
        "waypoint-scale ok: nodes={d} edges={d} waypoints={d} layout_ms={d} layout_arena_bytes={d} render_ms={d} render_arena_bytes={d} svg_bytes={d} svg_hash={x}\n",
        .{
            graph.nodes.items.len,
            graph.edges.items.len,
            waypoint_count,
            @divTrunc(layout_elapsed_ns, std.time.ns_per_ms),
            layout_fixed.end_index,
            @divTrunc(render_elapsed_ns, std.time.ns_per_ms),
            render_fixed.end_index,
            svg.len,
            std.hash.Wyhash.hash(0, svg),
        },
    );
    try stdout.interface.flush();
}

fn buildGraph(allocator: std.mem.Allocator) !vex.Graph {
    var graph = try vex.Graph.init(allocator, .{
        .directed = true,
        .name = "WaypointScale",
    });
    errdefer graph.deinit();
    try graph.setGraphAttr(.{ .nslimit1 = 0 });
    try graph.setGraphAttr(.{ .nslimit = 0 });
    try graph.setGraphAttr(.{ .splines = .curved });

    for (0..node_count) |node| {
        var label_buffer: [32]u8 = undefined;
        _ = try graph.addNode(
            try std.fmt.bufPrint(&label_buffer, "n{d}", .{node}),
            .{ .shape = .record },
        );
    }
    // Each edge spans ten ranks. A rank-local obstacle index makes waypoint
    // avoidance scale with chain width instead of the full graph size.
    for (0..chain_count) |chain| {
        for (1..chain_depth) |depth| {
            _ = try graph.addEdge(
                nodeId(chain, depth - 1),
                nodeId(chain, depth),
                .{ .min_len = 10 },
            );
        }
    }
    return graph;
}

fn nodeId(chain: usize, depth: usize) vex.NodeId {
    return depth * chain_count + chain;
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
