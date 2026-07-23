//! Render an undirected graph with the API and SVG output.
//!
//! Run with: zig build run-api-undirected-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{
        .directed = false,
        .name = "UndirectedNetwork",
        .rankdir = .LR,
    });
    defer graph.deinit();

    const client = try graph.addNode("Client", .{ .shape = .ellipse });
    const gateway = try graph.addNode("Gateway", .{ .shape = .box });
    const api = try graph.addNode("API", .{ .shape = .box });
    const cache = try graph.addNode("Cache", .{ .shape = .cylinder });
    const db = try graph.addNode("DB", .{ .shape = .cylinder });

    _ = try graph.addEdge(client, gateway, .{ .label = "tls" });
    _ = try graph.addEdge(gateway, api, .{ .label = "http" });
    _ = try graph.addEdge(api, db, .{ .label = "sql" });
    _ = try graph.addEdge(gateway, cache, .{ .label = "lookup" });
    _ = try graph.addEdge(cache, db, .{ .label = "warm" });

    try common.writeSvg(init.gpa, init.io, &graph, "02.svg", .{});
}
