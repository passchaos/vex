//! Render typed node layers and columns with a highlighted main path.
//!
//! Run with: zig build run-api-layer-column-constraints-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{
        .directed = true,
        .name = "LayerColumnConstraints",
        .theme = .light,
    });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .label = "Typed layers and columns" });
    try graph.setGraphAttr(.{ .splines = .ortho });
    try graph.setDefaultEdgeAttr(.{ .style = .rounded });
    try graph.setDefaultEdgeAttr(.{ .radius = 10 });

    const ingest = try graph.addNode("Ingest", .{});
    const parse = try graph.addNode("Parse", .{});
    const reject = try graph.addNode("Reject", .{});
    const enrich = try graph.addNode("Enrich", .{});
    const validate = try graph.addNode("Validate", .{});
    const retry = try graph.addNode("Retry", .{});
    const store = try graph.addNode("Store", .{});
    const publish = try graph.addNode("Publish", .{});
    const alert = try graph.addNode("Alert", .{});

    const ingest_enrich = try graph.addEdge(ingest, enrich, .{ .label = "accepted" });
    _ = try graph.addEdge(ingest, validate, .{ .label = "inspect" });
    _ = try graph.addEdge(parse, validate, .{});
    _ = try graph.addEdge(reject, retry, .{});
    const enrich_store = try graph.addEdge(enrich, store, .{ .label = "ready" });
    _ = try graph.addEdge(validate, publish, .{});
    _ = try graph.addEdge(validate, alert, .{ .label = "escalate" });
    _ = try graph.addEdge(retry, alert, .{});

    try graph.addNodeLayer(&.{ ingest, parse, reject });
    try graph.addNodeLayer(&.{ enrich, validate, retry });
    try graph.addNodeLayer(&.{ store, publish, alert });
    try graph.addNodeColumn(&.{ ingest, enrich, store });
    try graph.addNodeColumn(&.{ parse, validate, publish });
    try graph.addNodeColumn(&.{ reject, retry, alert });
    try graph.highlightNodes(&.{ ingest, enrich, store });
    try graph.highlightEdges(&.{ ingest_enrich, enrich_store });

    var config = vex.VisualTheme.light.layoutConfig();
    config.algorithm = .sugiyama;
    try common.writeSvgWithOptions(
        init.gpa,
        init.io,
        &graph,
        "18_layer_column_constraints.svg",
        config,
        .{ .svg = .{ .metadata = true } },
    );
}
