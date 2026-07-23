//! Build a cyclic graph with the API and render it with layered SVG layout.
//!
//! Run with: zig build run-api-force-layout-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = false, .name = "ForceLayout" });
    defer graph.deinit();

    const ui = try graph.addNode("UI", .{ .shape = .box });
    const api = try graph.addNode("API", .{ .shape = .box });
    const auth = try graph.addNode("Auth", .{ .shape = .box });
    const jobs = try graph.addNode("Jobs", .{ .shape = .box });
    const cache = try graph.addNode("Cache", .{ .shape = .cylinder });
    const db = try graph.addNode("DB", .{ .shape = .cylinder });
    const metrics = try graph.addNode("Metrics", .{ .shape = .ellipse });

    // try graph.addRankConstraint(.same, &.{ jobs, api });

    _ = try graph.addEdge(ui, api, .{ .label = "http" });
    _ = try graph.addEdge(api, auth, .{ .label = "token" });
    _ = try graph.addEdge(api, jobs, .{ .label = "enqueue" });
    _ = try graph.addEdge(api, cache, .{ .label = "read" });
    _ = try graph.addEdge(api, db, .{ .label = "write" });
    _ = try graph.addEdge(jobs, db, .{ .label = "batch" });
    _ = try graph.addEdge(jobs, metrics, .{ .label = "events" });
    _ = try graph.addEdge(cache, db, .{ .label = "warm" });
    _ = try graph.addEdge(metrics, ui, .{ .label = "dash" });

    try common.writeSvg(init.gpa, init.io, &graph, "07.svg", .{
        .algorithm = .sugiyama,
        // .algorithm = .fruchterman_reingold,
        // .force = .{ .width = 620, .height = 360, .iterations = 180 },
    });
}
