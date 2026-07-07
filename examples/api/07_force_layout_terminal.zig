//! Build a cyclic graph with the API and render a force-directed layout.
//!
//! Run with: zig build run-api-force-layout-terminal

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = false, .name = "ForceLayout" });
    defer graph.deinit();

    const ui = try graph.nodeWith("ui", .{ .label = "UI", .shape = .box });
    const api = try graph.nodeWith("api", .{ .label = "API", .shape = .box });
    const auth = try graph.nodeWith("auth", .{ .label = "Auth", .shape = .box });
    const jobs = try graph.nodeWith("jobs", .{ .label = "Jobs", .shape = .box });
    const cache = try graph.nodeWith("cache", .{ .label = "Cache", .shape = .cylinder });
    const db = try graph.nodeWith("db", .{ .label = "DB", .shape = .cylinder });
    const metrics = try graph.nodeWith("metrics", .{ .label = "Metrics", .shape = .ellipse });

    _ = try graph.edge(ui, api, .{ .label = "http" });
    _ = try graph.edge(api, auth, .{ .label = "token" });
    _ = try graph.edge(api, jobs, .{ .label = "enqueue" });
    _ = try graph.edge(api, cache, .{ .label = "read" });
    _ = try graph.edge(api, db, .{ .label = "write" });
    _ = try graph.edge(jobs, db, .{ .label = "batch" });
    _ = try graph.edge(jobs, metrics, .{ .label = "events" });
    _ = try graph.edge(cache, db, .{ .label = "warm" });
    _ = try graph.edge(metrics, ui, .{ .label = "dash" });

    var result = try vex.layoutGraph(allocator, &graph, .{
        .algorithm = .fruchterman_reingold,
        .force = .{ .width = 620, .height = 360, .iterations = 180 },
    });
    defer result.deinit();
    var scene = try vex.RenderScene.init(allocator, &graph, &result);
    defer scene.deinit();

    var stdout_buffer: [16384]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try vex.render(&stdout.interface, &scene, .terminal, .{
        .terminal = .{ .target_width = 110, .target_height = 34 },
    });
    try stdout.interface.flush();
}
