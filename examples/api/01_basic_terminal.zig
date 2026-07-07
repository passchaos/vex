//! Build a graph with the Vex API and render it to the terminal.
//!
//! Run with: zig build run-api-basic-terminal

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "ApiPipeline" });
    defer graph.deinit();

    const parse = try graph.nodeWith("parse", .{ .shape = .box, .label = "Parse DOT" });
    const model = try graph.nodeWith("model", .{ .shape = .box, .label = "Graph model" });
    const layout = try graph.nodeWith("layout", .{ .shape = .box, .label = "Layered layout" });
    const terminal = try graph.nodeWith("terminal", .{ .shape = .box, .label = "Terminal" });

    _ = try graph.edge(parse, model, .{ .label = "tokens" });
    _ = try graph.edge(model, layout, .{ .label = "nodes + edges" });
    _ = try graph.edge(layout, terminal, .{ .label = "canvas" });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();
    var scene = try vex.RenderScene.init(allocator, &graph, &result);
    defer scene.deinit();

    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try vex.render(&stdout.interface, &scene, .terminal, .{ .terminal = .{ .target_width = 88 } });
    try stdout.interface.flush();
}
