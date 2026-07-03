const std = @import("std");
const Io = std.Io;
const vex = @import("vex");

const usage =
    \\vex - DOT-compatible graph visualization prototype
    \\
    \\Usage:
    \\  vex [--input file.dot|-i file.dot] [--output file|-o file]
    \\        [--format terminal|svg|png|pdf] [--layout dot|sugiyama|fr|neato|fdp]
    \\        [--input-format auto|dot|mermaid]
    \\  vex --help
    \\
    \\If --input is omitted, DOT is read from stdin. If --output is omitted,
    \\output is written to stdout.
    \\Default input format is auto. Default layout is DOT/Sugiyama and honors
    \\rankdir=TB|BT|LR|RL.
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
    var format_arg: ?vex.OutputFormat = null;
    var layout_arg: vex.LayoutAlgorithm = .auto;
    var input_format: vex.InputFormat = .auto;

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
            format_arg = vex.OutputFormat.fromString(args[i]) orelse return error.UnknownFormat;
        } else if (std.mem.eql(u8, arg, "--input-format")) {
            i += 1;
            if (i >= args.len) return error.MissingInputFormat;
            input_format = vex.InputFormat.fromString(args[i]) orelse return error.UnknownInputFormat;
        } else if (std.mem.eql(u8, arg, "--mermaid")) {
            input_format = .mermaid;
        } else if (std.mem.eql(u8, arg, "--layout") or std.mem.eql(u8, arg, "-K")) {
            i += 1;
            if (i >= args.len) return error.MissingLayout;
            layout_arg = vex.LayoutAlgorithm.fromString(args[i]) orelse return error.UnknownLayout;
        } else if (std.mem.startsWith(u8, arg, "-K") and arg.len > 2) {
            layout_arg = vex.LayoutAlgorithm.fromString(arg[2..]) orelse return error.UnknownLayout;
        } else if (input_path == null) {
            input_path = arg;
        } else if (output_path == null) {
            output_path = arg;
        } else {
            return error.TooManyArguments;
        }
    }

    const format = format_arg orelse if (output_path) |path|
        (vex.OutputFormat.fromPath(path) orelse .svg)
    else
        .svg;

    const dot = if (input_path) |path|
        if (std.mem.eql(u8, path, "-"))
            try readStdin(allocator, io)
        else
            try Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(64 * 1024 * 1024))
    else blk: {
        break :blk try readStdin(allocator, io);
    };
    defer allocator.free(dot);

    var graph = try vex.parseInput(allocator, dot, input_format);
    defer graph.deinit();

    var layout = try vex.layoutGraph(allocator, &graph, .{ .algorithm = layout_arg });
    defer layout.deinit();

    if (output_path) |path| {
        var file = try Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
        defer file.close(io);
        var buffer: [8192]u8 = undefined;
        var file_writer = file.writer(io, &buffer);
        try vex.render(&file_writer.interface, &graph, &layout, format, .{});
        try file_writer.interface.flush();
    } else {
        var stdout_buffer: [8192]u8 = undefined;
        var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
        try vex.render(&stdout_file_writer.interface, &graph, &layout, format, .{});
        try stdout_file_writer.interface.flush();
    }
}

fn readStdin(allocator: std.mem.Allocator, io: Io) ![]u8 {
    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = Io.File.stdin().readerStreaming(io, &stdin_buffer);
    return stdin_reader.interface.allocRemaining(allocator, .limited(64 * 1024 * 1024));
}
