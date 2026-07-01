const std = @import("std");
const Io = std.Io;
const topos = @import("topos");

const usage =
    \\topos - DOT-compatible graph visualization prototype
    \\
    \\Usage:
    \\  topos [--input file.dot|-i file.dot] [--output file|-o file]
    \\        [--format terminal|svg|png|pdf] [--engine graphviz|native]
    \\  topos --help
    \\
    \\If --input is omitted, DOT is read from stdin. If --output is omitted,
    \\output is written to stdout.
    \\
    \\The default engine is graphviz, which shells out to `dot` so supported
    \\formats are byte-for-byte Graphviz output. Use --engine native to run
    \\Topos' experimental Zig parser/layout/renderers instead.
    \\
;

const Engine = enum {
    graphviz,
    native,

    fn fromString(value: []const u8) ?Engine {
        if (std.ascii.eqlIgnoreCase(value, "graphviz") or std.ascii.eqlIgnoreCase(value, "dot")) return .graphviz;
        if (std.ascii.eqlIgnoreCase(value, "native") or std.ascii.eqlIgnoreCase(value, "topos")) return .native;
        return null;
    }
};

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
    var engine: Engine = .graphviz;
    var dot_path: []const u8 = "dot";

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
        } else if (std.mem.eql(u8, arg, "--engine")) {
            i += 1;
            if (i >= args.len) return error.MissingEngine;
            engine = Engine.fromString(args[i]) orelse return error.UnknownEngine;
        } else if (std.mem.eql(u8, arg, "--dot-path")) {
            i += 1;
            if (i >= args.len) return error.MissingDotPath;
            dot_path = args[i];
        } else if (input_path == null) {
            input_path = arg;
        } else if (output_path == null) {
            output_path = arg;
        } else {
            return error.TooManyArguments;
        }
    }

    const format = format_arg orelse if (output_path) |path|
        (topos.OutputFormat.fromPath(path) orelse .svg)
    else
        .svg;

    if (engine == .graphviz) {
        try runGraphvizExact(allocator, io, input_path, output_path, format, dot_path);
        return;
    }

    const dot = if (input_path) |path|
        if (std.mem.eql(u8, path, "-"))
            try readStdin(allocator, io)
        else
            try Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(64 * 1024 * 1024))
    else blk: {
        break :blk try readStdin(allocator, io);
    };
    defer allocator.free(dot);

    var graph = try topos.parseDot(allocator, dot);
    defer graph.deinit();

    var layout = try topos.layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

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

fn readStdin(allocator: std.mem.Allocator, io: Io) ![]u8 {
    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = Io.File.stdin().readerStreaming(io, &stdin_buffer);
    return stdin_reader.interface.allocRemaining(allocator, .limited(64 * 1024 * 1024));
}

fn graphvizFormat(format: topos.OutputFormat) []const u8 {
    return switch (format) {
        .terminal => "plain",
        .svg => "svg",
        .png => "png",
        .pdf => "pdf",
    };
}

fn runGraphvizExact(
    allocator: std.mem.Allocator,
    io: Io,
    input_path: ?[]const u8,
    output_path: ?[]const u8,
    format: topos.OutputFormat,
    dot_path: []const u8,
) !void {
    const actual_input_path = if (input_path) |path|
        if (std.mem.eql(u8, path, "-"))
            try writeTempDot(allocator, io, try readStdin(allocator, io))
        else
            path
    else
        try writeTempDot(allocator, io, try readStdin(allocator, io));
    const temp_path: ?[]const u8 = if (input_path) |path|
        if (std.mem.eql(u8, path, "-")) actual_input_path else null
    else
        actual_input_path;
    defer if (temp_path) |path| {
        Io.Dir.cwd().deleteFile(io, path) catch {};
        allocator.free(path);
    };

    const format_arg = try std.fmt.allocPrint(allocator, "-T{s}", .{graphvizFormat(format)});
    defer allocator.free(format_arg);

    const argv = [_][]const u8{ dot_path, format_arg, actual_input_path };
    const result = try std.process.run(allocator, io, .{
        .argv = &argv,
        .stdout_limit = .limited(512 * 1024 * 1024),
        .stderr_limit = .limited(64 * 1024 * 1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stderr.len > 0) {
        var stderr_buffer: [8192]u8 = undefined;
        var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
        try stderr_file_writer.interface.writeAll(result.stderr);
        try stderr_file_writer.interface.flush();
    }

    switch (result.term) {
        .exited => |code| if (code != 0) return error.GraphvizFailed,
        else => return error.GraphvizFailed,
    }

    if (output_path) |path| {
        var file = try Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
        defer file.close(io);
        var buffer: [8192]u8 = undefined;
        var file_writer = file.writer(io, &buffer);
        try file_writer.interface.writeAll(result.stdout);
        try file_writer.interface.flush();
    } else {
        var stdout_buffer: [8192]u8 = undefined;
        var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
        try stdout_file_writer.interface.writeAll(result.stdout);
        try stdout_file_writer.interface.flush();
    }
}

fn writeTempDot(allocator: std.mem.Allocator, io: Io, dot: []u8) ![]const u8 {
    defer allocator.free(dot);
    var random: [8]u8 = undefined;
    io.random(&random);
    const path = try std.fmt.allocPrint(
        allocator,
        "/tmp/topos-{d}-{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}.dot",
        .{
            std.os.linux.getpid(),
            random[0],
            random[1],
            random[2],
            random[3],
            random[4],
            random[5],
            random[6],
            random[7],
        },
    );
    errdefer allocator.free(path);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = dot });
    return path;
}
