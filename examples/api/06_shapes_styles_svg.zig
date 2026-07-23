//! Build common Graphviz-style shapes and edge styles through the API.
//!
//! Run with: zig build run-api-shapes-styles-svg

const std = @import("std");
const vex = @import("vex");

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

    try outputFileAndStdout(init.gpa, init.io, graph, "zig-out/examples", "06.svg");
}

fn outputFileAndStdout(gpa: std.mem.Allocator, io: std.Io, graph: vex.Graph, sub_dir: []const u8, file_name: []const u8) !void {
    var result = try vex.layoutGraph(gpa, &graph, .{});
    defer result.deinit();
    try std.Io.Dir.cwd().createDirPath(io, sub_dir);

    const sub_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ sub_dir, file_name });
    defer gpa.free(sub_path);

    var file = try std.Io.Dir.cwd().createFile(io, sub_path, .{ .truncate = true });
    defer file.close(io);

    var file_buffer: [8192]u8 = undefined;
    var file_writer = file.writer(io, &file_buffer);
    try vex.render(&file_writer.interface, &result, .svg, .{});
    try file_writer.interface.flush();

    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try stdout.interface.writeAll("wrote ");
    try stdout.interface.writeAll(sub_path);
    try stdout.interface.writeAll("\n");
    try stdout.interface.flush();
}

fn styledNode(graph: *vex.Graph, label: []const u8, shape: vex.Shape, fill: []const u8) !vex.NodeId {
    return graph.addNode(label, .{
        .shape = shape,
        .style = .filled,
        .fillcolor = fill,
        .color = "#334155",
    });
}
