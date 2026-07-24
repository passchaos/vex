//! Render a larger graph with the independent multilevel sfdp engine.
//!
//! Run with: zig build run-api-sfdp-layout-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = false, .name = "SfdpLayout" });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .layout = .multilevel_spring_electrical });

    const node_count: usize = 48;
    for (0..node_count) |node| {
        var label_buf: [32]u8 = undefined;
        const label = try std.fmt.bufPrint(&label_buf, "N{d}", .{node});
        _ = try graph.addNode(label, .{});
    }
    for (0..node_count) |node| {
        _ = try graph.addEdge(node, (node + 1) % node_count, .{});
        _ = try graph.addEdge(node, (node + 7) % node_count, .{});
    }

    try common.writeSvg(init.gpa, init.io, &graph, "10.svg", .{
        .algorithm = .multilevel_spring_electrical,
        .force = .{ .width = 840, .height = 560, .iterations = 100 },
    });
}
