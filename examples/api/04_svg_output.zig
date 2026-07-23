//! Render one API-built graph through the SVG output backend.
//!
//! Run with: zig build run-api-svg-output

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "SvgOutput", .rankdir = .LR });
    defer graph.deinit();

    const source = try graph.addNode("Source", .{ .shape = .box, .color = "#dbeafe" });
    const layout = try graph.addNode("Layout", .{ .shape = .diamond, .color = "#fef3c7" });
    const svg = try graph.addNode("SVG", .{
        .shape = .folder,
        .color = "#dcfce7",
        .url = "https://example.com/vex/svg",
    });

    _ = try graph.addEdge(source, layout, .{ .label = "model" });
    _ = try graph.addEdge(layout, svg, .{ .label = "vector" });

    try common.writeSvg(init.gpa, init.io, &graph, "04.svg", .{});
}
