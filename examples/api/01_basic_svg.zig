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

    const parse = try graph.addNode("Parse DOT", .{ .shape = .box });
    const model = try graph.addNode("Graph model", .{ .shape = .box });
    const layout = try graph.addNode("Layered layout", .{ .shape = .box });
    const svg = try graph.addNode("SVG", .{ .shape = .box });

    _ = try graph.addEdge(parse, model, .{ .label = "tokens" });
    _ = try graph.addEdge(model, layout, .{ .label = "nodes + edges" });
    _ = try graph.addEdge(layout, svg, .{ .label = "document" });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();
    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try vex.render(&stdout.interface, &result, .svg, .{});
    try stdout.interface.flush();
}
