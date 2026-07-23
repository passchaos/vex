//! Build a graph with the Vex API and render it to SVG.
//!
//! Run with: zig build run-api-basic-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "ApiPipeline" });
    defer graph.deinit();

    const parse = try graph.addNode("Parse DOT", .{ .shape = .box });
    const model = try graph.addNode("Graph model", .{ .shape = .box });
    const layout = try graph.addNode("Layered layout", .{ .shape = .box });
    const svg = try graph.addNode("SVG", .{ .shape = .box });

    _ = try graph.addEdge(parse, model, .{ .label = "tokens" });
    _ = try graph.addEdge(model, layout, .{ .label = "nodes + edges" });
    _ = try graph.addEdge(layout, svg, .{ .label = "document" });

    try common.writeSvg(init.gpa, init.io, &graph, "01.svg", .{});
}
