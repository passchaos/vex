//! Build subgraphs through the API and render SVG.
//!
//! Run with: zig build run-api-clusters-compound

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "SubgraphApi", .rankdir = .LR });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .compound = true });

    const browser = try graph.addNode("Browser", .{ .shape = .box, .color = "#dbeafe" });
    const edge = try graph.addNode("Edge", .{ .shape = .box, .color = "#dbeafe" });
    const api = try graph.addNode("API", .{ .shape = .box, .color = "#dcfce7" });
    const worker = try graph.addNode("Worker", .{ .shape = .box, .color = "#dcfce7" });
    const store = try graph.addNode("Store", .{ .shape = .box, .color = "#dcfce7" });

    const frontend = try graph.addSubgraph("Frontend", null, &.{ browser, edge }, .{
        .color = "#2563eb",
        .fillcolor = "#dbeafe",
        .style = .filled,
    });
    const backend = try graph.addSubgraph("Backend", null, &.{ api, worker, store }, .{
        .color = "#16a34a",
        .fillcolor = "#dcfce7",
        .style = .filled,
    });

    _ = try graph.addEdge(browser, edge, .{ .label = "https" });
    _ = try graph.addEdge(edge, api, .{
        .label = "json",
        .ltail = frontend,
        .lhead = backend,
        .penwidth = 2,
    });
    _ = try graph.addEdge(api, worker, .{ .label = "job" });
    _ = try graph.addEdge(worker, store, .{ .label = "write" });
    _ = try graph.addEdge(api, store, .{ .label = "read", .constraint = false });

    try common.writeSvg(init.gpa, init.io, &graph, "03.svg", .{});
}
