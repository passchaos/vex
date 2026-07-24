const std = @import("std");
const vex = @import("vex");

const output_dir = "zig-out/examples";

pub fn writeSvg(gpa: std.mem.Allocator, io: std.Io, graph: *const vex.Graph, file_name: []const u8, layout_config: vex.LayoutConfig) !void {
    var layout = try vex.layoutGraph(gpa, graph, layout_config);
    defer layout.deinit();

    try writeLayoutSvg(gpa, io, &layout, file_name);
}

pub fn writeLayoutSvg(gpa: std.mem.Allocator, io: std.Io, layout: *const vex.Layout, file_name: []const u8) !void {
    try std.Io.Dir.cwd().createDirPath(io, output_dir);

    const path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ output_dir, file_name });
    defer gpa.free(path);

    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);

    var file_buffer: [8192]u8 = undefined;
    var file_writer = file.writer(io, &file_buffer);
    try vex.render(&file_writer.interface, layout, .svg, .{});
    try file_writer.interface.flush();

    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try stdout.interface.writeAll("wrote ");
    try stdout.interface.writeAll(path);
    try stdout.interface.writeAll("\n");
    try stdout.interface.flush();
}
