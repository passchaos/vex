const std = @import("std");
const builtin = @import("builtin");
const vex = @import("vex");

const graph_count: usize = 8;
const node_count: usize = 256;
const edge_count: usize = node_count * 2;
const worker_count: usize = 4;
const task_memory_bytes: usize = 4 * 1024 * 1024;
const task_arena_limit: usize = 2 * 1024 * 1024;
const elapsed_limit_ns: i96 = 2 * std.time.ns_per_s;
const peak_rss_limit: usize = 96 * 1024 * 1024;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var graphs: [graph_count]vex.Graph = undefined;
    var graph_count_initialized: usize = 0;
    defer for (graphs[0..graph_count_initialized]) |*graph| graph.deinit();

    var memories: [graph_count][]u8 = undefined;
    var memory_count_initialized: usize = 0;
    defer for (memories[0..memory_count_initialized]) |memory| allocator.free(memory);

    var fixed: [graph_count]std.heap.FixedBufferAllocator = undefined;
    var tasks: [graph_count]vex.ParallelLayoutTask = undefined;
    for (0..graph_count) |index| {
        graphs[index] = try buildGraph(allocator, index);
        graph_count_initialized += 1;
        memories[index] = try allocator.alloc(u8, task_memory_bytes);
        memory_count_initialized += 1;
        fixed[index] = std.heap.FixedBufferAllocator.init(memories[index]);
        tasks[index] = .{
            .allocator = fixed[index].allocator(),
            .graph = &graphs[index],
            .config = .{
                .algorithm = .multilevel_spring_electrical,
                .force = .{ .width = 1200, .height = 800, .margin = 30, .iterations = 40 },
            },
        };
    }

    const start = std.Io.Clock.awake.now(init.io);
    var layouts = try vex.layoutGraphsParallel(allocator, &tasks, .{ .max_workers = worker_count });
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    defer layouts.deinit();
    if (elapsed_ns > elapsed_limit_ns) return error.ParallelLayoutScaleTimeLimitExceeded;

    var combined_hash: u64 = 0;
    var max_arena_bytes: usize = 0;
    for (layouts.items, 0..) |item, index| {
        const layout = switch (item) {
            .layout => |layout| layout,
            .failure => |err| return err,
        };
        if (layout.nodes.len != node_count or layout.graph.edges.items.len != edge_count) {
            return error.ParallelLayoutScaleCountMismatch;
        }
        var name_buffer: [32]u8 = undefined;
        const expected_name = try std.fmt.bufPrint(&name_buffer, "ParallelScale{d}", .{index});
        if (!std.mem.eql(u8, layout.graph.name, expected_name)) {
            return error.ParallelLayoutScaleOrderMismatch;
        }
        max_arena_bytes = @max(max_arena_bytes, fixed[index].end_index);
        if (fixed[index].end_index > task_arena_limit) {
            return error.ParallelLayoutScaleMemoryLimitExceeded;
        }
        combined_hash = std.hash.Wyhash.hash(combined_hash, std.mem.sliceAsBytes(layout.nodes));
    }

    const serial_memory = try allocator.alloc(u8, task_memory_bytes);
    defer allocator.free(serial_memory);
    var serial_fixed = std.heap.FixedBufferAllocator.init(serial_memory);
    const serial_start = std.Io.Clock.awake.now(init.io);
    var serial_hash: u64 = 0;
    for (0..graph_count) |index| {
        var serial = try vex.layoutGraph(serial_fixed.allocator(), &graphs[index], tasks[index].config);
        serial_hash = std.hash.Wyhash.hash(serial_hash, std.mem.sliceAsBytes(serial.nodes));
        serial.deinit();
        serial_fixed.reset();
    }
    const serial_elapsed_ns = serial_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    if (serial_hash != combined_hash) {
        return error.ParallelLayoutScaleOutputMismatch;
    }
    const cpu_count = std.Thread.getCpuCount() catch 1;
    if (cpu_count >= worker_count and elapsed_ns >= serial_elapsed_ns) {
        return error.ParallelLayoutScaleThroughputRegression;
    }

    const peak_rss_bytes = processPeakRssBytes();
    if (peak_rss_bytes > peak_rss_limit) return error.ParallelLayoutScalePeakRssExceeded;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), init.io, &stdout_buffer);
    try stdout.interface.print(
        "parallel-layout-scale ok: graphs={d} workers={d} nodes_per_graph={d} edges_per_graph={d} parallel_ms={d} serial_ms={d} max_task_arena_bytes={d} combined_hash={x} peak_rss_bytes={d}\n",
        .{
            graph_count,
            worker_count,
            node_count,
            edge_count,
            @divTrunc(elapsed_ns, std.time.ns_per_ms),
            @divTrunc(serial_elapsed_ns, std.time.ns_per_ms),
            max_arena_bytes,
            combined_hash,
            peak_rss_bytes,
        },
    );
    try stdout.interface.flush();
}

fn buildGraph(allocator: std.mem.Allocator, graph_index: usize) !vex.Graph {
    var name_buffer: [32]u8 = undefined;
    var graph = try vex.Graph.init(allocator, .{
        .directed = false,
        .name = try std.fmt.bufPrint(&name_buffer, "ParallelScale{d}", .{graph_index}),
    });
    errdefer graph.deinit();

    for (0..node_count) |node| {
        var label_buffer: [32]u8 = undefined;
        _ = try graph.addNode(try std.fmt.bufPrint(&label_buffer, "g{d}n{d}", .{ graph_index, node }), .{});
    }
    for (0..node_count) |node| {
        _ = try graph.addEdge(node, (node + 1) % node_count, .{});
        _ = try graph.addEdge(node, (node + 17 + graph_index) % node_count, .{});
    }
    return graph;
}

fn processPeakRssBytes() usize {
    if (!@hasDecl(std.posix, "getrusage") or @TypeOf(std.c.rusage) == void) return 0;
    const usage = std.posix.getrusage(std.c.rusage.SELF);
    return switch (builtin.os.tag) {
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => @intCast(usage.maxrss),
        .dragonfly, .freebsd, .netbsd, .openbsd, .illumos, .linux, .serenity => @as(usize, @intCast(usage.maxrss)) * 1024,
        else => 0,
    };
}
