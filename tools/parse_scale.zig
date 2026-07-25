const std = @import("std");
const vex = @import("vex");

const node_count: usize = 10_000;
const parser_memory_limit: usize = 64 * 1024 * 1024;
const parse_time_limit_ns: i96 = std.time.ns_per_s;

pub fn main(init: std.process.Init) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var source_writer = std.Io.Writer.Allocating.init(allocator);
    defer source_writer.deinit();
    try source_writer.writer.writeAll(
        \\digraph Scale {
        \\  node [label="\N"];
        \\  n0;
        \\
    );
    for (1..node_count) |index| {
        try source_writer.writer.print("  n{d} -> n{d};\n", .{ index - 1, index });
    }
    try source_writer.writer.writeAll("}\n");
    const source = try source_writer.toOwnedSlice();
    defer allocator.free(source);

    const parser_memory = try allocator.alloc(u8, parser_memory_limit);
    defer allocator.free(parser_memory);
    var fixed = std.heap.FixedBufferAllocator.init(parser_memory);

    const start = std.Io.Clock.awake.now(init.io);
    var graph = try vex.parseDot(fixed.allocator(), source);
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const parser_memory_used = fixed.end_index;
    defer graph.deinit();

    if (graph.nodes.items.len != node_count) return error.ParseScaleNodeCountMismatch;
    if (graph.edges.items.len != node_count - 1) return error.ParseScaleEdgeCountMismatch;
    if (elapsed_ns > parse_time_limit_ns) return error.ParseScaleTimeLimitExceeded;

    var stdout_buffer: [256]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), init.io, &stdout_buffer);
    try stdout.interface.print(
        "parse-scale ok: nodes={d} edges={d} source_bytes={d} arena_bytes={d} elapsed_ms={d}\n",
        .{
            graph.nodes.items.len,
            graph.edges.items.len,
            source.len,
            parser_memory_used,
            @divTrunc(elapsed_ns, std.time.ns_per_ms),
        },
    );
    try stdout.interface.flush();
}
