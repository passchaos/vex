//! Fixed-worker parallel index scheduling for independent layout tasks.

const std = @import("std");
const builtin = @import("builtin");

pub fn runIndices(
    allocator: std.mem.Allocator,
    item_count: usize,
    max_workers: usize,
    context: anytype,
    comptime execute: fn (@TypeOf(context), usize) void,
) !void {
    if (item_count == 0) return;

    const Runner = struct {
        next: std.atomic.Value(usize) = .init(0),
        item_count: usize,
        context: @TypeOf(context),

        fn work(self: *@This()) void {
            while (true) {
                const index = self.next.fetchAdd(1, .monotonic);
                if (index >= self.item_count) return;
                execute(self.context, index);
            }
        }
    };

    const cpu_count = std.Thread.getCpuCount() catch 1;
    const requested = if (max_workers == 0) cpu_count else max_workers;
    const worker_count = @min(@max(requested, 1), item_count);
    if (builtin.single_threaded) {
        var runner = Runner{ .item_count = item_count, .context = context };
        runner.work();
        return;
    }
    if (worker_count == 1) {
        var runner = Runner{ .item_count = item_count, .context = context };
        runner.work();
        return;
    }

    var runner = Runner{ .item_count = item_count, .context = context };
    const threads = allocator.alloc(std.Thread, worker_count - 1) catch {
        runner.work();
        return;
    };
    defer allocator.free(threads);

    var spawned: usize = 0;
    while (spawned < threads.len) {
        threads[spawned] = std.Thread.spawn(.{}, Runner.work, .{&runner}) catch break;
        spawned += 1;
    }

    runner.work();
    for (threads[0..spawned]) |thread| thread.join();
}
