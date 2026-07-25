const std = @import("std");
const vex = @import("vex");

const chain_node_count: usize = 10_000;
const structured_node_count: usize = 4_096;
const structured_group_size: usize = 64;
const parser_memory_limit: usize = 64 * 1024 * 1024;
const parse_time_limit_ns: i96 = std.time.ns_per_s;
const chain_arena_limit: usize = 32 * 1024 * 1024;
const structured_arena_limit: usize = 32 * 1024 * 1024;

const ParseGateResult = struct {
    nodes: usize,
    edges: usize,
    subgraphs: usize,
    source_bytes: usize,
    arena_bytes: usize,
    elapsed_ns: i96,
};

pub fn main(init: std.process.Init) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const chain_source = try buildChainSource(allocator);
    defer allocator.free(chain_source);
    const structured_source = try buildStructuredSource(allocator);
    defer allocator.free(structured_source);

    const parser_memory = try allocator.alloc(u8, parser_memory_limit);
    defer allocator.free(parser_memory);

    const chain = try runParseGate(
        init,
        parser_memory,
        chain_source,
        chain_node_count,
        chain_node_count - 1,
        0,
        chain_arena_limit,
    );
    const structured = try runParseGate(
        init,
        parser_memory,
        structured_source,
        structured_node_count,
        structured_node_count - 1,
        structured_node_count / structured_group_size,
        structured_arena_limit,
    );

    var stdout_buffer: [512]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), init.io, &stdout_buffer);
    try printGateResult(&stdout.interface, "chain", chain);
    try printGateResult(&stdout.interface, "structured", structured);
    try stdout.interface.flush();
}

fn buildChainSource(allocator: std.mem.Allocator) ![]u8 {
    var source_writer = std.Io.Writer.Allocating.init(allocator);
    errdefer source_writer.deinit();
    try source_writer.writer.writeAll(
        \\digraph Scale {
        \\  node [label="\N"];
        \\  n0;
        \\
    );
    for (1..chain_node_count) |index| {
        try source_writer.writer.print("  n{d} -> n{d};\n", .{ index - 1, index });
    }
    try source_writer.writer.writeAll("}\n");
    return source_writer.toOwnedSlice();
}

fn buildStructuredSource(allocator: std.mem.Allocator) ![]u8 {
    var source_writer = std.Io.Writer.Allocating.init(allocator);
    errdefer source_writer.deinit();
    try source_writer.writer.writeAll(
        \\digraph Structured {
        \\  graph [rankdir=LR, compound=true];
        \\  node [shape=box];
        \\
    );
    for (0..structured_node_count / structured_group_size) |group| {
        try source_writer.writer.print(
            "  subgraph group_{d} {{\n    label=\"Group {d}\"; color=\"#2563eb\"; style=\"rounded\";\n",
            .{ group, group },
        );
        for (0..structured_group_size) |offset| {
            const index = group * structured_group_size + offset;
            try source_writer.writer.print(
                "    n{d} [label=\"Node {d} payload value\", color=\"#334155\", fillcolor=\"#e2e8f0\", style=\"filled,rounded\", fontsize=12, tooltip=\"node-{d}\", id=\"id-{d}\"];\n",
                .{ index, index, index, index },
            );
        }
        try source_writer.writer.writeAll("  }\n");
    }
    for (1..structured_node_count) |index| {
        try source_writer.writer.print(
            "  n{d} -> n{d} [label=\"edge {d}\", color=\"#64748b\", weight=2, minlen=1];\n",
            .{ index - 1, index, index },
        );
    }
    try source_writer.writer.writeAll("}\n");
    return source_writer.toOwnedSlice();
}

fn runParseGate(
    init: std.process.Init,
    parser_memory: []u8,
    source: []const u8,
    expected_nodes: usize,
    expected_edges: usize,
    expected_subgraphs: usize,
    arena_limit: usize,
) !ParseGateResult {
    var fixed = std.heap.FixedBufferAllocator.init(parser_memory);
    const start = std.Io.Clock.awake.now(init.io);
    var graph = try vex.parseDot(fixed.allocator(), source);
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const parser_memory_used = fixed.end_index;
    defer graph.deinit();

    if (graph.nodes.items.len != expected_nodes) return error.ParseScaleNodeCountMismatch;
    if (graph.edges.items.len != expected_edges) return error.ParseScaleEdgeCountMismatch;
    if (graph.subgraphs.items.len != expected_subgraphs) return error.ParseScaleSubgraphCountMismatch;
    if (elapsed_ns > parse_time_limit_ns) return error.ParseScaleTimeLimitExceeded;
    if (parser_memory_used > arena_limit) return error.ParseScaleMemoryLimitExceeded;

    return .{
        .nodes = graph.nodes.items.len,
        .edges = graph.edges.items.len,
        .subgraphs = graph.subgraphs.items.len,
        .source_bytes = source.len,
        .arena_bytes = parser_memory_used,
        .elapsed_ns = elapsed_ns,
    };
}

fn printGateResult(writer: *std.Io.Writer, name: []const u8, result: ParseGateResult) !void {
    try writer.print(
        "parse-scale {s} ok: nodes={d} edges={d} subgraphs={d} source_bytes={d} arena_bytes={d} elapsed_ms={d}\n",
        .{
            name,
            result.nodes,
            result.edges,
            result.subgraphs,
            result.source_bytes,
            result.arena_bytes,
            @divTrunc(result.elapsed_ns, std.time.ns_per_ms),
        },
    );
}
