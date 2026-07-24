//! Render biconnected blocks with the independent circo engine.
//!
//! Run with: zig build run-api-circo-layout-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = false, .name = "CircoLayout" });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .layout = .circular });

    const a = try graph.addNode("A", .{});
    const b = try graph.addNode("B", .{});
    const articulation = try graph.addNode("Bridge", .{ .shape = .doublecircle });
    const d = try graph.addNode("D", .{});
    const e = try graph.addNode("E", .{});

    _ = try graph.addEdge(a, b, .{});
    _ = try graph.addEdge(b, articulation, .{});
    _ = try graph.addEdge(articulation, a, .{});
    _ = try graph.addEdge(articulation, d, .{});
    _ = try graph.addEdge(d, e, .{});
    _ = try graph.addEdge(e, articulation, .{});

    try common.writeSvg(init.gpa, init.io, &graph, "12.svg", .{
        .algorithm = .circular,
        .force = .{ .width = 620, .height = 420, .margin = 36 },
    });
}
