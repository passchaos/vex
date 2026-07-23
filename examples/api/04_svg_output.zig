//! Render one API-built graph through the SVG output backend.
//!
//! Run with: zig build run-api-svg-output

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "SvgOutput", .rankdir = .LR });
    defer graph.deinit();

    const source = try graph.addNode("Source", .{ .shape = .box, .color = "#dbeafe" });
    const layout = try graph.addNode("Layout", .{ .shape = .diamond, .color = "#fef3c7" });
    const svg = try graph.addNode("SVG", .{
        .shape = .folder,
        .color = "#dcfce7",
        .url = "https://example.com/vex/svg",
    });

    _ = try graph.addEdge(source, layout, .{ .label = "model" });
    _ = try graph.addEdge(layout, svg, .{ .label = "vector" });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();
    var stdout_buffer: [16384]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);

    try writeRenderedFile(io, &result, .svg, "zig-out/examples/api_svg_output.svg", .{});

    try stdout.interface.writeAll("wrote zig-out/examples/api_svg_output.svg\n");
    try stdout.interface.flush();
}

fn writeRenderedFile(io: std.Io, layout: *const vex.Layout, format: vex.OutputFormat, path: []const u8, options: vex.RenderOptions) !void {
    try std.Io.Dir.cwd().createDirPath(io, "zig-out/examples");
    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);
    var buffer: [8192]u8 = undefined;
    var writer = file.writer(io, &buffer);
    try vex.render(&writer.interface, layout, format, options);
    try writer.interface.flush();
}
