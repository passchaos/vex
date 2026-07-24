//! Render clustered undirected data with the independent fdp engine.
//!
//! Run with: zig build run-api-fdp-layout-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = false, .name = "FdpLayout" });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .layout = .spring_electrical });

    const a = try graph.addNode("A", .{ .shape = .box });
    const b = try graph.addNode("B", .{ .shape = .box });
    const c = try graph.addNode("C", .{ .shape = .box });
    const d = try graph.addNode("D", .{ .shape = .box });
    _ = try graph.addSubgraph("Left", null, &.{ a, b }, .{ .style = .rounded });
    _ = try graph.addSubgraph("Right", null, &.{ c, d }, .{ .style = .rounded });

    _ = try graph.addEdge(a, b, .{ .weight = 3 });
    _ = try graph.addEdge(c, d, .{ .weight = 3 });
    _ = try graph.addEdge(b, c, .{ .weight = 1 });

    try common.writeSvg(init.gpa, init.io, &graph, "09.svg", .{
        .algorithm = .spring_electrical,
        .force = .{ .width = 620, .height = 360, .iterations = 180 },
    });
}
