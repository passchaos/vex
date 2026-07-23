//! Build a graph with the Vex API and render it to SVG.
//!
//! Run with: zig build run-api-basic-svg

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "ApiPipeline" });
    defer graph.deinit();

    const parse = try graph.addNodeWith("Parse DOT", .{ .shape = .box });
    const model = try graph.addNodeWith("Graph model", .{ .shape = .box });
    const layout = try graph.addNodeWith("Layered layout", .{ .shape = .box });
    const svg = try graph.addNodeWith("SVG", .{ .shape = .box });

    _ = try graph.addEdge(parse, model, .{ .label = "tokens" });
    _ = try graph.addEdge(model, layout, .{ .label = "nodes + edges" });
    _ = try graph.addEdge(layout, svg, .{ .label = "document" });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();
    var scene = try vex.RenderScene.init(allocator, &graph, &result);
    defer scene.deinit();

    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try vex.render(&stdout.interface, &scene, .svg, .{});
    try stdout.interface.flush();
}
