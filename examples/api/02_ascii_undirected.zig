//! Render an undirected graph with the API and the terminal ASCII fallback.
//!
//! Run with: zig build run-api-ascii-undirected

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{
        .directed = false,
        .name = "UndirectedNetwork",
        .rankdir = .LR,
    });
    defer graph.deinit();

    const client = try graph.nodeWith("client", .{ .label = "Client", .shape = .ellipse });
    const gateway = try graph.nodeWith("gateway", .{ .label = "Gateway", .shape = .box });
    const api = try graph.nodeWith("api", .{ .label = "API", .shape = .box });
    const cache = try graph.nodeWith("cache", .{ .label = "Cache", .shape = .cylinder });
    const db = try graph.nodeWith("db", .{ .label = "DB", .shape = .cylinder });

    _ = try graph.edge(client, gateway, .{ .label = "tls" });
    _ = try graph.edge(gateway, api, .{ .label = "http" });
    _ = try graph.edge(api, db, .{ .label = "sql" });
    _ = try graph.edge(gateway, cache, .{ .label = "lookup" });
    _ = try graph.edge(cache, db, .{ .label = "warm" });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();

    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try vex.render(&stdout.interface, &graph, &result, .terminal, .{
        .terminal = .{ .unicode = false, .target_width = 96 },
    });
    try stdout.interface.flush();
}
