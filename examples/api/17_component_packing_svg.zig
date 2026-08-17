//! Render disconnected layered components with Graphviz-style node packing.
//!
//! Run with: zig build run-api-component-packing-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{
        .directed = true,
        .name = "ComponentPacking",
        .rankdir = .LR,
        .theme = .light,
    });
    defer graph.deinit();

    try graph.setGraphAttr(.{ .label = "Packed service workflows" });
    try graph.setGraphAttr(.{ .packmode = "node" });
    try graph.setGraphAttr(.{ .pack = 8 });
    try graph.setGraphAttr(.{ .splines = .curved });

    const receive = try graph.addNode("Receive", .{});
    const validate = try graph.addNode("Validate", .{});
    const enqueue = try graph.addNode("Enqueue", .{});
    _ = try graph.addEdge(receive, validate, .{ .label = "request" });
    _ = try graph.addEdge(validate, enqueue, .{ .label = "accepted" });
    _ = try graph.addSubgraph("Ingestion", null, &.{ receive, validate, enqueue }, .{
        .sortv = 10,
    });

    const query = try graph.addNode("Query", .{});
    const cache = try graph.addNode("Cache", .{});
    const compute = try graph.addNode("Compute", .{});
    const respond = try graph.addNode("Respond", .{});
    _ = try graph.addEdge(query, cache, .{ .label = "lookup" });
    _ = try graph.addEdge(query, compute, .{ .label = "miss" });
    _ = try graph.addEdge(cache, respond, .{});
    _ = try graph.addEdge(compute, respond, .{});
    _ = try graph.addSubgraph("Analytics", null, &.{ query, cache, compute, respond }, .{
        .sortv = 20,
    });

    const snapshot = try graph.addNode("Snapshot", .{ .sortv = 30 });
    const archive = try graph.addNode("Archive", .{ .sortv = 30 });
    _ = try graph.addEdge(snapshot, archive, .{ .label = "daily" });

    var config = vex.VisualTheme.light.layoutConfig();
    config.algorithm = .sugiyama;
    try common.writeSvg(init.gpa, init.io, &graph, "17_component_packing.svg", config);
}
