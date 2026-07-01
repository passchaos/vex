const std = @import("std");
const Io = std.Io;
const topos = @import("topos");

const usage =
    \\topos - DOT-compatible graph visualization prototype
    \\
    \\Usage:
    \\  topos [--input file.dot|-i file.dot] [--output file.svg|-o file.svg]
    \\  topos --help
    \\
    \\If --input is omitted, DOT is read from stdin. If --output is omitted,
    \\SVG is written to stdout.
    \\
;

pub fn main(init: std.process.Init) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    var input_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var format_arg: ?topos.OutputFormat = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            var stderr_buffer: [1024]u8 = undefined;
            var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
            try stderr_file_writer.interface.writeAll(usage);
            try stderr_file_writer.interface.flush();
            return;
        } else if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            i += 1;
            if (i >= args.len) return error.MissingInputPath;
            input_path = args[i];
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            i += 1;
            if (i >= args.len) return error.MissingOutputPath;
            output_path = args[i];
        } else if (std.mem.eql(u8, arg, "--format") or std.mem.eql(u8, arg, "-f")) {
            i += 1;
            if (i >= args.len) return error.MissingFormat;
            format_arg = topos.OutputFormat.fromString(args[i]) orelse return error.UnknownFormat;
        } else if (input_path == null) {
            input_path = arg;
        } else if (output_path == null) {
            output_path = arg;
        } else {
            return error.TooManyArguments;
        }
    }

    const dot = if (input_path) |path|
        try Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(64 * 1024 * 1024))
    else blk: {
        var stdin_buffer: [4096]u8 = undefined;
        var stdin_reader = Io.File.stdin().readerStreaming(io, &stdin_buffer);
        break :blk try stdin_reader.interface.allocRemaining(allocator, .limited(64 * 1024 * 1024));
    };
    defer allocator.free(dot);

    var graph = try topos.parseDot(allocator, dot);
    defer graph.deinit();

    var layout = try topos.layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const format = format_arg orelse if (output_path) |path|
        (topos.OutputFormat.fromPath(path) orelse .svg)
    else
        .svg;

    if (output_path) |path| {
        var file = try Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
        defer file.close(io);
        var buffer: [8192]u8 = undefined;
        var file_writer = file.writer(io, &buffer);
        try topos.render(&file_writer.interface, &graph, &layout, format, .{});
        try file_writer.interface.flush();
    } else {
        var stdout_buffer: [8192]u8 = undefined;
        var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
        try topos.render(&stdout_file_writer.interface, &graph, &layout, format, .{});
        try stdout_file_writer.interface.flush();
    }
}
