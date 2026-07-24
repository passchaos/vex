//! Preserve the mental map while adding nodes, then render the final SVG.
//!
//! Run with: zig build run-api-incremental-layout-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "IncrementalLayout" });
    defer graph.deinit();

    const source = try graph.addNode("Source", .{ .shape = .box });
    const api = try graph.addNode("API", .{ .shape = .box });
    const worker = try graph.addNode("Worker", .{ .shape = .box });
    const store = try graph.addNode("Store", .{ .shape = .cylinder });
    _ = try graph.addEdge(source, api, .{});
    _ = try graph.addEdge(source, worker, .{});
    _ = try graph.addEdge(api, store, .{});
    _ = try graph.addEdge(worker, store, .{});

    var previous = try vex.layoutGraph(allocator, &graph, .{ .algorithm = .sugiyama });
    defer previous.deinit();

    const cache = try graph.addNode("Cache", .{ .shape = .cylinder });
    _ = try graph.addEdge(source, cache, .{});
    _ = try graph.addEdge(cache, store, .{});

    var layout = try vex.layoutGraphIncremental(
        allocator,
        &graph,
        &previous,
        .{ .algorithm = .sugiyama },
        .{ .stability = 0.95 },
    );
    defer layout.deinit();

    try common.writeLayoutSvg(allocator, init.io, &layout, "08.svg");
}
