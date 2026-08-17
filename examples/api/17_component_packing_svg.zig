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
    });
    defer graph.deinit();

    try graph.setGraphAttr(.{ .label = "Packed service workflows" });
    try graph.setGraphAttr(.{ .packmode = "node" });
    try graph.setGraphAttr(.{ .pack = 8 });
    try graph.setGraphAttr(.{ .splines = .curved });
    try graph.setGraphAttr(.{ .bgcolor = "#fcfcfc" });
    try graph.setGraphAttr(.{ .fontcolor = "#202328" });
    try graph.setDefaultNodeAttr(.{ .shape = .box });
    try graph.setDefaultNodeAttr(.{ .styles = &.{ .filled, .rounded } });
    try graph.setDefaultNodeAttr(.{ .fillcolor = "#f6f8fa" });
    try graph.setDefaultNodeAttr(.{ .color = "#d2d9df" });
    try graph.setDefaultNodeAttr(.{ .fontcolor = "#5b636d" });
    try graph.setDefaultNodeAttr(.{ .fontname = "Helvetica" });
    try graph.setDefaultNodeAttr(.{ .penwidth = 0.8 });
    try graph.setDefaultEdgeAttr(.{ .color = "#aeb8c2" });
    try graph.setDefaultEdgeAttr(.{ .fontcolor = "#5b636d" });
    try graph.setDefaultEdgeAttr(.{ .fontname = "Helvetica" });
    try graph.setDefaultEdgeAttr(.{ .penwidth = 1.0 });
    try graph.setDefaultEdgeAttr(.{ .arrowsize = 0.8 });

    const receive = try graph.addNode("Receive", .{});
    const validate = try graph.addNode("Validate", .{});
    const enqueue = try graph.addNode("Enqueue", .{});
    _ = try graph.addEdge(receive, validate, .{ .label = "request" });
    _ = try graph.addEdge(validate, enqueue, .{ .label = "accepted" });
    _ = try graph.addSubgraph("Ingestion", null, &.{ receive, validate, enqueue }, .{
        .sortv = 10,
        .color = "#cbd5e1",
        .fillcolor = "#f8fafc",
        .styles = &.{ .filled, .rounded },
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
        .color = "#cbd5e1",
        .fillcolor = "#f8fafc",
        .styles = &.{ .filled, .rounded },
    });

    const snapshot = try graph.addNode("Snapshot", .{ .sortv = 30 });
    const archive = try graph.addNode("Archive", .{ .sortv = 30 });
    _ = try graph.addEdge(snapshot, archive, .{ .label = "daily" });

    var config = vex.LayoutConfig.defaults(.relaxed);
    config.algorithm = .sugiyama;
    try common.writeSvg(init.gpa, init.io, &graph, "17_component_packing.svg", config);
}
