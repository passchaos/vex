const std = @import("std");
const vex = @import("vex");

const chain_count: usize = 5;
const rank_count: usize = 1_000;
const node_count: usize = chain_count * rank_count + 2;
const long_edge_spans = [_]usize{ 13, 31, 61, 97, 149 };
const layout_memory_limit: usize = 48 * 1024 * 1024;
const layout_arena_limit: usize = 40 * 1024 * 1024;
const layout_time_limit_ns: i96 = 3 * std.time.ns_per_s;

pub fn main(init: std.process.Init) !void {
    var graph = try buildGraph(init.gpa);
    defer graph.deinit();

    const layout_memory = try init.gpa.alloc(u8, layout_memory_limit);
    defer init.gpa.free(layout_memory);
    var layout_fixed = std.heap.FixedBufferAllocator.init(layout_memory);
    const start = std.Io.Clock.awake.now(init.io);
    var layout = try vex.layoutGraph(layout_fixed.allocator(), &graph, .{
        .algorithm = .sugiyama,
        .layered = .{
            .coordinate_passes = 0,
        },
    });
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    defer layout.deinit();

    if (layout.nodes.len != node_count) return error.LayoutScaleNodeCountMismatch;
    if (layout.ranks.len != node_count) return error.LayoutScaleRankCountMismatch;
    if (elapsed_ns > layout_time_limit_ns) return error.LayoutScaleTimeLimitExceeded;
    if (layout_fixed.end_index > layout_arena_limit) return error.LayoutScaleMemoryLimitExceeded;
    for (0..chain_count) |chain| {
        for (1..rank_count) |rank| {
            const previous = chainNode(chain, rank - 1);
            const current = chainNode(chain, rank);
            if (layout.ranks[current] != layout.ranks[previous] + 1) {
                return error.LayoutScaleRankDirectionMismatch;
            }
        }
    }

    var stdout_buffer: [512]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), init.io, &stdout_buffer);
    try stdout.interface.print(
        "layered-tall-scale ok: nodes={d} edges={d} ranks={d} layout_ms={d} layout_arena_bytes={d}\n",
        .{
            graph.nodes.items.len,
            graph.edges.items.len,
            maxRank(layout.ranks) + 1,
            @divTrunc(elapsed_ns, std.time.ns_per_ms),
            layout_fixed.end_index,
        },
    );
    try stdout.interface.flush();
}

fn buildGraph(allocator: std.mem.Allocator) !vex.Graph {
    var graph = try vex.Graph.init(allocator, .{
        .directed = true,
        .name = "TallNarrowLayeredScale",
    });
    errdefer graph.deinit();
    // This gate isolates crossing reduction. Ranking and coordinate simplex
    // have independent quality/scale coverage elsewhere.
    try graph.setGraphAttr(.{ .nslimit1 = 0 });
    try graph.setGraphAttr(.{ .nslimit = 0 });

    const source = try graph.addNode("source", .{});
    const sink = try graph.addNode("sink", .{});
    for (0..chain_count) |chain| {
        for (0..rank_count) |rank| {
            var label_buffer: [48]u8 = undefined;
            const id = try graph.addNode(
                try std.fmt.bufPrint(&label_buffer, "n{d}_{d}", .{ chain, rank }),
                .{},
            );
            if (id != chainNode(chain, rank)) return error.LayoutScaleNodeIdentityMismatch;
        }
    }

    for (0..chain_count) |chain| {
        _ = try graph.addEdge(source, chainNode(chain, 0), .{});
        for (1..rank_count) |rank| {
            _ = try graph.addEdge(chainNode(chain, rank - 1), chainNode(chain, rank), .{});
        }
        _ = try graph.addEdge(chainNode(chain, rank_count - 1), sink, .{});
    }
    for (long_edge_spans, 0..) |span, chain| {
        var rank = chain % 2;
        while (rank + span < rank_count) : (rank += 2) {
            _ = try graph.addEdge(
                chainNode(chain, rank),
                chainNode((chain + 2) % chain_count, rank + span),
                .{},
            );
        }
    }
    return graph;
}

fn chainNode(chain: usize, rank: usize) vex.NodeId {
    return 2 + chain * rank_count + rank;
}

fn maxRank(ranks: []const usize) usize {
    var result: usize = 0;
    for (ranks) |rank| result = @max(result, rank);
    return result;
}
