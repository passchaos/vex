//! Build subgraphs through the API and render SVG.
//!
//! Run with: zig build run-api-clusters-compound

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "SubgraphApi", .rankdir = .LR });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .compound = true });

    const browser = try graph.nodeWith("Browser", .{ .shape = .box, .color = "#dbeafe" });
    const edge = try graph.nodeWith("Edge", .{ .shape = .box, .color = "#dbeafe" });
    const api = try graph.nodeWith("API", .{ .shape = .box, .color = "#dcfce7" });
    const worker = try graph.nodeWith("Worker", .{ .shape = .box, .color = "#dcfce7" });
    const store = try graph.nodeWith("Store", .{ .shape = .box, .color = "#dcfce7" });

    const frontend = try graph.addSubgraph("Frontend", null, &.{ browser, edge }, &.{
        .{ .name = "color", .value = "#2563eb" },
        .{ .name = "fillcolor", .value = "#dbeafe" },
        .{ .name = "style", .value = "filled" },
    });
    const backend = try graph.addSubgraph("Backend", null, &.{ api, worker, store }, &.{
        .{ .name = "color", .value = "#16a34a" },
        .{ .name = "fillcolor", .value = "#dcfce7" },
        .{ .name = "style", .value = "filled" },
    });

    _ = try graph.edge(browser, edge, .{ .label = "https" });
    const cross = try graph.edge(edge, api, .{ .label = "json", .ltail = frontend, .lhead = backend });
    try graph.setEdgeAttr(cross, .{ .penwidth = 2 });
    _ = try graph.edge(api, worker, .{ .label = "job" });
    _ = try graph.edge(worker, store, .{ .label = "write" });
    _ = try graph.edge(api, store, .{ .label = "read", .constraint = false });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();
    var scene = try vex.RenderScene.init(allocator, &graph, &result);
    defer scene.deinit();

    var stdout_buffer: [16384]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try vex.render(&stdout.interface, &scene, .svg, .{});
    try stdout.interface.flush();
}
