//! Build clusters through the API and render cluster panels in the terminal.
//!
//! Run with: zig build run-api-clusters-compound

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "ClusteredApi", .rankdir = .LR });
    defer graph.deinit();
    try graph.setGraphAttr("compound", "true");

    const browser = try graph.nodeWith("browser", .{ .label = "Browser", .shape = .box, .color = "#dbeafe" });
    const edge = try graph.nodeWith("edge", .{ .label = "Edge", .shape = .box, .color = "#dbeafe" });
    const api = try graph.nodeWith("api", .{ .label = "API", .shape = .box, .color = "#dcfce7" });
    const worker = try graph.nodeWith("worker", .{ .label = "Worker", .shape = .box, .color = "#dcfce7" });
    const store = try graph.nodeWith("store", .{ .label = "Store", .shape = .box, .color = "#dcfce7" });

    _ = try graph.addCluster("cluster_frontend", null, &.{ browser, edge }, &.{
        .{ .name = "label", .value = "Frontend" },
        .{ .name = "color", .value = "#2563eb" },
        .{ .name = "fillcolor", .value = "#dbeafe" },
        .{ .name = "style", .value = "filled" },
    });
    _ = try graph.addCluster("cluster_backend", null, &.{ api, worker, store }, &.{
        .{ .name = "label", .value = "Backend" },
        .{ .name = "color", .value = "#16a34a" },
        .{ .name = "fillcolor", .value = "#dcfce7" },
        .{ .name = "style", .value = "filled" },
    });

    _ = try graph.edge(browser, edge, .{ .label = "https" });
    const cross = try graph.edge(edge, api, .{ .label = "json", .ltail = "cluster_frontend", .lhead = "cluster_backend" });
    try graph.setEdgeAttr(cross, "penwidth", "2");
    _ = try graph.edge(api, worker, .{ .label = "job" });
    _ = try graph.edge(worker, store, .{ .label = "write" });
    _ = try graph.edge(api, store, .{ .label = "read", .constraint = false });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();

    var stdout_buffer: [16384]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try vex.render(&stdout.interface, &graph, &result, .terminal, .{
        .terminal = .{ .target_width = 118, .target_height = 36 },
    });
    try stdout.interface.flush();
}
