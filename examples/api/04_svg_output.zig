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

    const source = try graph.addNodeWith("Source", .{ .shape = .box, .color = "#dbeafe" });
    const layout = try graph.addNodeWith("Layout", .{ .shape = .diamond, .color = "#fef3c7" });
    const svg = try graph.addNodeWith("SVG", .{ .shape = .folder, .color = "#dcfce7" });
    try graph.setNodeAttr(svg, .{ .url = "https://example.com/vex/svg" });

    _ = try graph.addEdge(source, layout, .{ .label = "model" });
    _ = try graph.addEdge(layout, svg, .{ .label = "vector" });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();
    var scene = try vex.RenderScene.init(allocator, &graph, &result);
    defer scene.deinit();

    var stdout_buffer: [16384]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);

    try writeRenderedFile(io, &scene, .svg, "zig-out/examples/api_svg_output.svg", .{});

    try stdout.interface.writeAll("wrote zig-out/examples/api_svg_output.svg\n");
    try stdout.interface.flush();
}

fn writeRenderedFile(io: std.Io, scene: *const vex.RenderScene, format: vex.OutputFormat, path: []const u8, options: vex.RenderOptions) !void {
    try std.Io.Dir.cwd().createDirPath(io, "zig-out/examples");
    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);
    var buffer: [8192]u8 = undefined;
    var writer = file.writer(io, &buffer);
    try vex.render(&writer.interface, scene, format, options);
    try writer.interface.flush();
}
