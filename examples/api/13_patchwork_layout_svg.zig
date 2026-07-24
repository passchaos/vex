//! Render hierarchical area data with the independent patchwork engine.
//!
//! Run with: zig build run-api-patchwork-layout-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = false, .name = "PatchworkLayout" });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .layout = .treemap });

    const api = try graph.addNode("API", .{ .area = 4 });
    const worker = try graph.addNode("Worker", .{ .area = 2 });
    const cache = try graph.addNode("Cache", .{ .area = 1 });
    const database = try graph.addNode("Database", .{ .area = 5 });

    const services = try graph.addSubgraph("Services", null, &.{ api, worker, cache }, .{
        .style = .rounded,
    });
    _ = services;
    _ = try graph.addSubgraph("Data", null, &.{database}, .{
        .style = .rounded,
    });

    try common.writeSvg(init.gpa, init.io, &graph, "13.svg", .{
        .algorithm = .treemap,
        .force = .{ .width = 720, .height = 460, .margin = 24 },
    });
}
