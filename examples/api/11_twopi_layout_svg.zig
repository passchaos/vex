//! Render a rooted tree-like graph with the independent twopi engine.
//!
//! Run with: zig build run-api-twopi-layout-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = false, .name = "TwopiLayout" });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .layout = .radial });
    try graph.setGraphAttr(.{ .ranksep = .{ .value = 1.2 } });

    const root = try graph.addNode("Root", .{ .shape = .doublecircle });
    try graph.setRadialRoot(root);
    const left = try graph.addNode("Left", .{});
    const right = try graph.addNode("Right", .{});
    const leaf_a = try graph.addNode("Leaf A", .{ .shape = .box });
    const leaf_b = try graph.addNode("Leaf B", .{ .shape = .box });
    const leaf_c = try graph.addNode("Leaf C", .{ .shape = .box });

    _ = try graph.addEdge(root, left, .{});
    _ = try graph.addEdge(root, right, .{});
    _ = try graph.addEdge(left, leaf_a, .{});
    _ = try graph.addEdge(left, leaf_b, .{});
    _ = try graph.addEdge(right, leaf_c, .{});

    try common.writeSvg(init.gpa, init.io, &graph, "11.svg", .{
        .algorithm = .radial,
        .force = .{ .width = 620, .height = 420, .margin = 36 },
    });
}
