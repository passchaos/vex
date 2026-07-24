//! Render nested array-packed groups with the independent osage engine.
//!
//! Run with: zig build run-api-osage-layout-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = false, .name = "OsageLayout" });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .layout = .array_packing });
    try graph.setGraphAttr(.{ .packmode = "array_u2" });
    try graph.setGraphAttr(.{ .pack = 10 });

    const gateway = try graph.addNode("Gateway", .{ .shape = .box, .sortv = 10 });
    const api = try graph.addNode("API", .{ .shape = .box, .sortv = 10 });
    const worker = try graph.addNode("Worker", .{ .shape = .box, .sortv = 20 });
    const cache = try graph.addNode("Cache", .{ .shape = .cylinder, .sortv = 30 });
    const database = try graph.addNode("Database", .{ .shape = .cylinder, .sortv = 40 });

    const services = try graph.addSubgraph("Services", null, &.{ api, worker, cache }, .{
        .packmode = "array_u2",
        .pack = 7,
        .sortv = 20,
        .style = .rounded,
    });
    _ = try graph.addSubgraph("Storage", services, &.{ cache, database }, .{
        .packmode = "array_i2",
        .pack = 5,
        .sortv = 10,
        .style = .rounded,
    });

    _ = try graph.addEdge(gateway, api, .{});
    _ = try graph.addEdge(api, worker, .{});
    _ = try graph.addEdge(worker, database, .{});

    try common.writeSvg(init.gpa, init.io, &graph, "14.svg", .{
        .algorithm = .array_packing,
    });
}
