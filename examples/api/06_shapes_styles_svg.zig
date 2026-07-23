//! Build common Graphviz-style shapes and edge styles through the API.
//!
//! Run with: zig build run-api-shapes-styles-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "ShapesStylesSubgraphs", .rankdir = .TB });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .nodesep = 0.9 });

    const start_node_id = try styledNode(&graph, "Start", .mdiamond, "#e0f2fe");

    const a0_node_id = try styledNode(&graph, "a0", .box, "#dbeafe");
    const a1_node_id = try styledNode(&graph, "a1", .box, "#dbeafe");
    const a2_node_id = try styledNode(&graph, "a2", .box, "#dbeafe");
    const a3_node_id = try styledNode(&graph, "a3", .box, "#dbeafe");

    const b0_node_id = try styledNode(&graph, "b0", .ellipse, "#dcfce7");
    const b1_node_id = try styledNode(&graph, "b1", .ellipse, "#dcfce7");
    const b2_node_id = try styledNode(&graph, "b2", .ellipse, "#dcfce7");
    const b3_node_id = try styledNode(&graph, "b3", .ellipse, "#dcfce7");

    _ = try graph.addSubgraph("process #1", null, &.{ a0_node_id, a1_node_id, a2_node_id, a3_node_id }, .{
        .color = "#2563eb",
        .fillcolor = "#dbeafe",
        .styles = &.{ .filled, .rounded },
    });
    _ = try graph.addSubgraph("process #2", null, &.{ b0_node_id, b1_node_id, b2_node_id, b3_node_id }, .{
        .color = "#16a34a",
        .fillcolor = "#dcfce7",
        .styles = &.{ .filled, .rounded },
    });

    _ = try graph.addEdge(a0_node_id, a1_node_id, .{ .color = "#2563eb" });
    _ = try graph.addEdge(a1_node_id, a2_node_id, .{ .color = "#2563eb" });
    _ = try graph.addEdge(a2_node_id, a3_node_id, .{ .color = "#2563eb" });
    _ = try graph.addEdge(b0_node_id, b1_node_id, .{ .color = "#16a34a" });
    _ = try graph.addEdge(b1_node_id, b2_node_id, .{ .color = "#16a34a" });
    _ = try graph.addEdge(b2_node_id, b3_node_id, .{ .color = "#16a34a" });

    _ = try graph.addEdge(start_node_id, a0_node_id, .{});
    _ = try graph.addEdge(start_node_id, b0_node_id, .{});
    _ = try graph.addEdge(a1_node_id, b3_node_id, .{
        .label = "handoff",
        .color = "#7c3aed",
        .constraint = false,
        .style = .dashed,
    });

    try common.writeSvg(init.gpa, init.io, &graph, "06.svg", .{});
}

fn styledNode(graph: *vex.Graph, label: []const u8, shape: vex.Shape, fill: []const u8) !vex.NodeId {
    return graph.addNode(label, .{
        .shape = shape,
        .style = .filled,
        .fillcolor = fill,
        .color = "#334155",
    });
}
