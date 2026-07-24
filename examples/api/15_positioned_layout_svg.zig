//! Render pre-positioned nodes and a preserved cubic edge with nop2.
//!
//! Run with: zig build run-api-positioned-layout-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "PositionedLayout" });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .layout = .positioned_with_edges });
    try graph.setGraphAttr(.{ .label = "Imported Geometry" });
    try graph.setGraphAttr(.{ .label_position = .{ .x = 170, .y = 150 } });

    const input = try graph.addNode("Input", .{
        .shape = .box,
        .position = .{ .x = 20, .y = 20, .pinned = true },
        .xlabel = "source",
        .external_label_position = .{ .x = 20, .y = 70 },
    });
    const process = try graph.addNode("Process", .{
        .shape = .box,
        .position = .{ .x = 170, .y = 100 },
    });
    const output = try graph.addNode("Output", .{
        .shape = .box,
        .position = .{ .x = 320, .y = 20 },
    });
    _ = try graph.addSubgraph("Pipeline", null, &.{ input, process }, .{
        .bounding_box = .{ .min_x = 0, .min_y = 0, .max_x = 230, .max_y = 130 },
        .label_position = .{ .x = 115, .y = 120 },
        .style = .rounded,
    });

    _ = try graph.addEdge(input, process, .{
        .label = "preserved",
        .label_position = .{ .x = 105, .y = 88 },
        .headlabel = "in",
        .head_label_position = .{ .x = 145, .y = 96 },
        .taillabel = "out",
        .tail_label_position = .{ .x = 55, .y = 45 },
        .spline = &.{.{
            .points = &.{
                .{ .x = 45, .y = 30 },
                .{ .x = 80, .y = 85 },
                .{ .x = 115, .y = 115 },
                .{ .x = 145, .y = 105 },
            },
            .end_tip = .{ .x = 150, .y = 103 },
        }},
    });
    _ = try graph.addEdge(process, output, .{});

    try common.writeSvg(init.gpa, init.io, &graph, "15.svg", .{
        .algorithm = .positioned_with_edges,
    });
}
