//! Render one API-built graph to terminal, SVG, PNG, and PDF.
//!
//! Run with: zig build run-api-output-formats

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "Formats", .rankdir = .LR });
    defer graph.deinit();

    const source = try graph.nodeWith("source", .{ .label = "Source", .shape = .box, .color = "#dbeafe" });
    const layout = try graph.nodeWith("layout", .{ .label = "Layout", .shape = .diamond, .color = "#fef3c7" });
    const terminal = try graph.nodeWith("terminal", .{ .label = "Terminal", .shape = .msquare, .color = "#dcfce7" });
    const svg = try graph.nodeWith("svg", .{ .label = "SVG", .shape = .folder, .color = "#f3e8ff" });
    const png = try graph.nodeWith("png", .{ .label = "PNG", .shape = .component, .color = "#fee2e2" });
    const pdf = try graph.nodeWith("pdf", .{ .label = "PDF", .shape = .note, .color = "#e0f2fe" });

    _ = try graph.edge(source, layout, .{ .label = "model" });
    _ = try graph.edge(layout, terminal, .{ .label = "box canvas" });
    _ = try graph.edge(layout, svg, .{ .label = "vector" });
    _ = try graph.edge(layout, png, .{ .label = "raster" });
    _ = try graph.edge(layout, pdf, .{ .label = "document" });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();

    var stdout_buffer: [16384]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try stdout.interface.writeAll("terminal:\n");
    try vex.render(&stdout.interface, &graph, &result, .terminal, .{ .terminal = .{ .target_width = 110 } });
    try stdout.interface.writeAll("\nwrote:\n");

    try writeRenderedFile(io, &graph, &result, .svg, "zig-out/examples/api_output_formats.svg");
    try writeRenderedFile(io, &graph, &result, .png, "zig-out/examples/api_output_formats.png");
    try writeRenderedFile(io, &graph, &result, .pdf, "zig-out/examples/api_output_formats.pdf");

    try stdout.interface.writeAll("  zig-out/examples/api_output_formats.svg\n");
    try stdout.interface.writeAll("  zig-out/examples/api_output_formats.png\n");
    try stdout.interface.writeAll("  zig-out/examples/api_output_formats.pdf\n");
    try stdout.interface.flush();
}

fn writeRenderedFile(io: std.Io, graph: *const vex.Graph, layout: *const vex.Layout, format: vex.OutputFormat, path: []const u8) !void {
    try std.Io.Dir.cwd().createDirPath(io, "zig-out/examples");
    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);
    var buffer: [8192]u8 = undefined;
    var writer = file.writer(io, &buffer);
    try vex.render(&writer.interface, graph, layout, format, .{});
    try writer.interface.flush();
}
