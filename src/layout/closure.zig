//! Maximum-weight closure solver used by layered rank optimization.

const std = @import("std");

pub const Implication = struct {
    from: usize,
    to: usize,
};

const capacity_epsilon = 0.0000001;

/// Selects a maximum-profit set while enforcing `from => to` implications.
///
/// The reduction uses an s-t minimum cut: positive profits are capacities
/// from the source, negative profits are capacities to the sink, and every
/// implication receives a barrier larger than the sum of all positive profit.
/// `selected` is overwritten with the source side of the residual cut.
pub fn solveMaximumWeight(
    allocator: std.mem.Allocator,
    profits: []const f64,
    implications: []const Implication,
    selected: []bool,
) !f64 {
    if (selected.len != profits.len) return error.InvalidSelectionLength;
    @memset(selected, false);
    if (profits.len == 0) return 0;

    const source = profits.len;
    const sink = source + 1;
    var network = try FlowNetwork.init(allocator, profits.len + 2);
    defer network.deinit();

    var total_positive: f64 = 0;
    for (profits, 0..) |profit, node| {
        if (!std.math.isFinite(profit)) return error.NonFiniteProfit;
        if (profit > capacity_epsilon) {
            total_positive += profit;
            if (!std.math.isFinite(total_positive)) return error.NonFiniteProfit;
            try network.addArc(source, node, profit);
        } else if (profit < -capacity_epsilon) {
            try network.addArc(node, sink, -profit);
        }
    }
    if (total_positive <= capacity_epsilon) return 0;

    // Cutting even one implication must cost more than discarding every
    // positive-profit node, so all source-side nodes remain closure-complete.
    const implication_barrier = total_positive + @max(total_positive, 1.0);
    for (implications) |implication| {
        if (implication.from >= profits.len or implication.to >= profits.len) {
            return error.InvalidImplication;
        }
        if (implication.from == implication.to) continue;
        try network.addArc(implication.from, implication.to, implication_barrier);
    }

    _ = network.maximumFlow(source, sink);
    try network.markReachable(allocator, source, selected);

    var result: f64 = 0;
    for (profits, selected) |profit, is_selected| {
        if (is_selected) result += profit;
    }
    return if (result > capacity_epsilon) result else 0;
}

const FlowArc = struct {
    to: usize,
    reverse: usize,
    capacity: f64,
};

const FlowNetwork = struct {
    allocator: std.mem.Allocator,
    adjacency: []std.ArrayList(FlowArc),
    levels: []isize,
    next_arc: []usize,
    queue: []usize,

    fn init(allocator: std.mem.Allocator, node_count: usize) !FlowNetwork {
        const adjacency = try allocator.alloc(std.ArrayList(FlowArc), node_count);
        errdefer allocator.free(adjacency);
        for (adjacency) |*arcs| arcs.* = .empty;
        errdefer for (adjacency) |*arcs| arcs.deinit(allocator);

        const levels = try allocator.alloc(isize, node_count);
        errdefer allocator.free(levels);
        const next_arc = try allocator.alloc(usize, node_count);
        errdefer allocator.free(next_arc);
        const queue = try allocator.alloc(usize, node_count);
        return .{
            .allocator = allocator,
            .adjacency = adjacency,
            .levels = levels,
            .next_arc = next_arc,
            .queue = queue,
        };
    }

    fn deinit(self: *FlowNetwork) void {
        for (self.adjacency) |*arcs| arcs.deinit(self.allocator);
        self.allocator.free(self.adjacency);
        self.allocator.free(self.levels);
        self.allocator.free(self.next_arc);
        self.allocator.free(self.queue);
        self.* = undefined;
    }

    fn addArc(self: *FlowNetwork, from: usize, to: usize, capacity: f64) !void {
        if (from >= self.adjacency.len or to >= self.adjacency.len) return error.InvalidArc;
        const reverse_at_to = self.adjacency[to].items.len;
        try self.adjacency[from].append(self.allocator, .{
            .to = to,
            .reverse = reverse_at_to,
            .capacity = capacity,
        });
        errdefer _ = self.adjacency[from].pop();
        try self.adjacency[to].append(self.allocator, .{
            .to = from,
            .reverse = self.adjacency[from].items.len - 1,
            .capacity = 0,
        });
    }

    fn maximumFlow(self: *FlowNetwork, source: usize, sink: usize) f64 {
        var total: f64 = 0;
        while (self.buildLevels(source, sink)) {
            @memset(self.next_arc, 0);
            while (true) {
                const sent = self.sendFlow(source, sink, std.math.floatMax(f64));
                if (sent <= capacity_epsilon) break;
                total += sent;
            }
        }
        return total;
    }

    fn buildLevels(self: *FlowNetwork, source: usize, sink: usize) bool {
        @memset(self.levels, -1);
        var head: usize = 0;
        var tail: usize = 1;
        self.queue[0] = source;
        self.levels[source] = 0;
        while (head < tail) : (head += 1) {
            const node = self.queue[head];
            for (self.adjacency[node].items) |arc| {
                if (arc.capacity <= capacity_epsilon or self.levels[arc.to] >= 0) continue;
                self.levels[arc.to] = self.levels[node] + 1;
                self.queue[tail] = arc.to;
                tail += 1;
            }
        }
        return self.levels[sink] >= 0;
    }

    fn sendFlow(self: *FlowNetwork, node: usize, sink: usize, available: f64) f64 {
        if (node == sink) return available;
        while (self.next_arc[node] < self.adjacency[node].items.len) {
            const arc_index = self.next_arc[node];
            const arc = self.adjacency[node].items[arc_index];
            if (arc.capacity > capacity_epsilon and self.levels[arc.to] == self.levels[node] + 1) {
                const sent = self.sendFlow(arc.to, sink, @min(available, arc.capacity));
                if (sent > capacity_epsilon) {
                    self.adjacency[node].items[arc_index].capacity -= sent;
                    self.adjacency[arc.to].items[arc.reverse].capacity += sent;
                    return sent;
                }
            }
            self.next_arc[node] += 1;
        }
        return 0;
    }

    fn markReachable(
        self: *FlowNetwork,
        allocator: std.mem.Allocator,
        source: usize,
        reachable: []bool,
    ) !void {
        const visited = try allocator.alloc(bool, self.adjacency.len);
        defer allocator.free(visited);
        @memset(visited, false);
        var head: usize = 0;
        var tail: usize = 1;
        self.queue[0] = source;
        visited[source] = true;
        while (head < tail) : (head += 1) {
            const node = self.queue[head];
            for (self.adjacency[node].items) |arc| {
                if (arc.capacity <= capacity_epsilon or visited[arc.to]) continue;
                visited[arc.to] = true;
                self.queue[tail] = arc.to;
                tail += 1;
            }
        }
        @memcpy(reachable, visited[0..reachable.len]);
    }
};

test "maximum-weight closure combines mutually dependent gains" {
    const allocator = std.testing.allocator;
    const profits = [_]f64{ 4, -3, 2, -1 };
    const implications = [_]Implication{
        .{ .from = 0, .to = 1 },
        .{ .from = 1, .to = 2 },
    };
    var selected = [_]bool{false} ** profits.len;

    const profit = try solveMaximumWeight(
        allocator,
        &profits,
        &implications,
        &selected,
    );

    try std.testing.expectApproxEqAbs(@as(f64, 3), profit, 0.000001);
    try std.testing.expectEqualSlices(
        bool,
        &.{ true, true, true, false },
        &selected,
    );
}

test "maximum-weight closure rejects a dependency whose loss exceeds its gain" {
    const allocator = std.testing.allocator;
    const profits = [_]f64{ 2, -4, 1 };
    const implications = [_]Implication{
        .{ .from = 0, .to = 1 },
    };
    var selected = [_]bool{false} ** profits.len;

    const profit = try solveMaximumWeight(
        allocator,
        &profits,
        &implications,
        &selected,
    );

    try std.testing.expectApproxEqAbs(@as(f64, 1), profit, 0.000001);
    try std.testing.expectEqualSlices(
        bool,
        &.{ false, false, true },
        &selected,
    );
}
