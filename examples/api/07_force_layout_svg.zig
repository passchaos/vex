//! Build a cyclic graph with the API and render a force-directed layout.
//!
//! Run with: zig build run-api-force-layout-svg

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = false, .name = "ForceLayout" });
    defer graph.deinit();

    const ui = try graph.addNode("UI", .{ .shape = .box });
    const api = try graph.addNode("API", .{ .shape = .box });
    const auth = try graph.addNode("Auth", .{ .shape = .box });
    const jobs = try graph.addNode("Jobs", .{ .shape = .box });
    const cache = try graph.addNode("Cache", .{ .shape = .cylinder });
    const db = try graph.addNode("DB", .{ .shape = .cylinder });
    const metrics = try graph.addNode("Metrics", .{ .shape = .ellipse });

    _ = try graph.addEdge(ui, api, .{ .label = "http" });
    _ = try graph.addEdge(api, auth, .{ .label = "token" });
    _ = try graph.addEdge(api, jobs, .{ .label = "enqueue" });
    _ = try graph.addEdge(api, cache, .{ .label = "read" });
    _ = try graph.addEdge(api, db, .{ .label = "write" });
    _ = try graph.addEdge(jobs, db, .{ .label = "batch" });
    _ = try graph.addEdge(jobs, metrics, .{ .label = "events" });
    _ = try graph.addEdge(cache, db, .{ .label = "warm" });
    _ = try graph.addEdge(metrics, ui, .{ .label = "dash" });

    var result = try vex.layoutGraph(allocator, &graph, .{
        .algorithm = .fruchterman_reingold,
        .force = .{ .width = 620, .height = 360, .iterations = 180 },
    });
    defer result.deinit();
    var stdout_buffer: [16384]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try vex.render(&stdout.interface, &result, .svg, .{});
    try stdout.interface.flush();
}
