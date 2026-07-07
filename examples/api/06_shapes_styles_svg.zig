//! Build common Graphviz-style shapes and edge styles through the API.
//!
//! Run with: zig build run-api-shapes-styles-svg

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "ShapesStyles" });
    defer graph.deinit();
    try graph.setGraphAttr("splines", "ortho");
    try graph.setGraphAttr("label", "API-built shapes and styles");

    const start = try styledNode(&graph, "start", "Start", .msquare, "#dbeafe");
    const decision = try styledNode(&graph, "decision", "Valid?", .diamond, "#fef3c7");
    const retry = try styledNode(&graph, "retry", "Retry", .octagon, "#fee2e2");
    const success = try styledNode(&graph, "success", "Done", .doublecircle, "#dcfce7");
    const note = try styledNode(&graph, "note", "audit\nlog", .note, "#e0f2fe");
    const hidden = try graph.nodeWith("hidden", .{ .shape = .point, .label = "ignored" });

    const input = try graph.edge(start, decision, .{ .label = "input", .color = "#2563eb" });
    try graph.setEdgeAttr(input, "penwidth", "2");
    const yes = try graph.edge(decision, success, .{ .label = "yes", .color = "#16a34a" });
    try graph.setEdgeAttr(yes, "penwidth", "2");
    const no = try graph.edge(decision, retry, .{ .label = "no", .color = "#dc2626" });
    try graph.setEdgeAttr(no, "style", "dashed");
    _ = try graph.edge(retry, decision, .{ .label = "again", .constraint = false });
    _ = try graph.edge(success, note, .{ .label = "emit" });
    const dotted = try graph.edge(hidden, start, .{ .constraint = false });
    try graph.setEdgeAttr(dotted, "style", "dotted");
    try graph.setEdgeAttr(dotted, "arrowhead", "none");

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();
    var scene = try vex.RenderScene.init(allocator, &graph, &result);
    defer scene.deinit();

    try std.Io.Dir.cwd().createDirPath(io, "zig-out/examples");
    var file = try std.Io.Dir.cwd().createFile(io, "zig-out/examples/api_shapes_styles.svg", .{ .truncate = true });
    defer file.close(io);
    var file_buffer: [8192]u8 = undefined;
    var file_writer = file.writer(io, &file_buffer);
    try vex.render(&file_writer.interface, &scene, .svg, .{});
    try file_writer.interface.flush();

    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try vex.render(&stdout.interface, &scene, .terminal, .{ .terminal = .{ .target_width = 92 } });
    try stdout.interface.writeAll("\nwrote zig-out/examples/api_shapes_styles.svg\n");
    try stdout.interface.flush();
}

fn styledNode(graph: *vex.Graph, name: []const u8, label: []const u8, shape: vex.Shape, fill: []const u8) !vex.NodeId {
    const id = try graph.nodeWith(name, .{ .label = label, .shape = shape });
    try graph.setNodeAttr(id, "style", "filled");
    try graph.setNodeAttr(id, "fillcolor", fill);
    try graph.setNodeAttr(id, "color", "#334155");
    return id;
}
