//! Deterministic multilevel spring-electrical layout.

const std = @import("std");
const Point = @import("result.zig").Point;

pub const Edge = struct {
    from: usize,
    to: usize,
};

pub const Options = struct {
    width: f64,
    height: f64,
    margin: f64,
    iterations: usize,
    max_levels: usize,
    repulsive_power: f64,
    spring_length: f64,
    stability: f64 = 0,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    positions: []Point,
    levels: usize,

    pub fn deinit(self: *Result) void {
        self.allocator.free(self.positions);
        self.* = undefined;
    }
};

const CoarseGraph = struct {
    allocator: std.mem.Allocator,
    node_count: usize,
    edges: []Edge,
    mapping: []usize,

    fn deinit(self: *CoarseGraph) void {
        self.allocator.free(self.edges);
        self.allocator.free(self.mapping);
        self.* = undefined;
    }
};

const EdgeKey = struct {
    from: usize,
    to: usize,
};

pub fn layout(
    allocator: std.mem.Allocator,
    node_count: usize,
    edges: []const Edge,
    options: Options,
    initial: ?[]const Point,
) !Result {
    var levels: usize = 1;
    const positions = try layoutLevel(allocator, node_count, edges, options, initial, 0, &levels);
    fitToCanvas(positions, options);
    return .{ .allocator = allocator, .positions = positions, .levels = levels };
}

fn layoutLevel(
    allocator: std.mem.Allocator,
    node_count: usize,
    edges: []const Edge,
    options: Options,
    initial: ?[]const Point,
    level: usize,
    levels: *usize,
) ![]Point {
    if (node_count == 0) return allocator.alloc(Point, 0);
    const max_levels = @max(options.max_levels, 1);
    if (node_count <= 12 or level + 1 >= max_levels) {
        const positions = try initialPositions(allocator, node_count, options, initial);
        relax(allocator, positions, edges, options, @max(options.iterations, 1), if (level == 0) initial else null);
        return positions;
    }

    var coarse = try coarsen(allocator, node_count, edges);
    defer coarse.deinit();
    if (coarse.node_count >= node_count or coarse.node_count * 4 > node_count * 3) {
        const positions = try initialPositions(allocator, node_count, options, initial);
        relax(allocator, positions, edges, options, @max(options.iterations, 1), if (level == 0) initial else null);
        return positions;
    }

    levels.* = @max(levels.*, level + 2);
    const coarse_initial = try aggregateInitial(allocator, coarse.node_count, coarse.mapping, initial);
    defer if (coarse_initial) |positions| allocator.free(positions);
    const coarse_positions = try layoutLevel(
        allocator,
        coarse.node_count,
        coarse.edges,
        options,
        coarse_initial,
        level + 1,
        levels,
    );
    defer allocator.free(coarse_positions);

    const positions = try prolongate(allocator, node_count, coarse.mapping, coarse_positions, options.spring_length);
    const level_iterations = @max(8, options.iterations / @max(level + 2, 2));
    relax(allocator, positions, edges, options, level_iterations, if (level == 0) initial else null);
    return positions;
}

fn coarsen(allocator: std.mem.Allocator, node_count: usize, edges: []const Edge) !CoarseGraph {
    const mapping = try allocator.alloc(usize, node_count);
    errdefer allocator.free(mapping);
    @memset(mapping, std.math.maxInt(usize));
    const matched = try allocator.alloc(bool, node_count);
    defer allocator.free(matched);
    @memset(matched, false);

    var coarse_count: usize = 0;
    for (0..node_count) |node| {
        if (matched[node]) continue;
        const neighbor = unmatchedNeighbor(node, node_count, edges, matched);
        matched[node] = true;
        mapping[node] = coarse_count;
        if (neighbor) |other| {
            matched[other] = true;
            mapping[other] = coarse_count;
        }
        coarse_count += 1;
    }

    var edge_map = std.AutoHashMap(EdgeKey, void).init(allocator);
    defer edge_map.deinit();
    var coarse_edges = std.ArrayList(Edge).empty;
    errdefer coarse_edges.deinit(allocator);
    for (edges) |edge| {
        if (edge.from >= node_count or edge.to >= node_count) continue;
        var from = mapping[edge.from];
        var to = mapping[edge.to];
        if (from == to) continue;
        if (from > to) std.mem.swap(usize, &from, &to);
        const result = try edge_map.getOrPut(.{ .from = from, .to = to });
        if (!result.found_existing) try coarse_edges.append(allocator, .{ .from = from, .to = to });
    }

    return .{
        .allocator = allocator,
        .node_count = coarse_count,
        .edges = try coarse_edges.toOwnedSlice(allocator),
        .mapping = mapping,
    };
}

fn unmatchedNeighbor(node: usize, node_count: usize, edges: []const Edge, matched: []const bool) ?usize {
    var best: ?usize = null;
    for (edges) |edge| {
        const neighbor = if (edge.from == node)
            edge.to
        else if (edge.to == node)
            edge.from
        else
            continue;
        if (neighbor >= node_count or matched[neighbor]) continue;
        if (best == null or neighbor < best.?) best = neighbor;
    }
    return best;
}

fn aggregateInitial(
    allocator: std.mem.Allocator,
    coarse_count: usize,
    mapping: []const usize,
    initial: ?[]const Point,
) !?[]Point {
    const source = initial orelse return null;
    if (source.len < mapping.len) return null;
    const positions = try allocator.alloc(Point, coarse_count);
    errdefer allocator.free(positions);
    @memset(positions, .{ .x = 0, .y = 0 });
    const counts = try allocator.alloc(usize, coarse_count);
    defer allocator.free(counts);
    @memset(counts, 0);
    for (mapping, 0..) |coarse, fine| {
        positions[coarse].x += source[fine].x;
        positions[coarse].y += source[fine].y;
        counts[coarse] += 1;
    }
    for (positions, 0..) |*position, coarse| {
        if (counts[coarse] == 0) continue;
        position.x /= @as(f64, @floatFromInt(counts[coarse]));
        position.y /= @as(f64, @floatFromInt(counts[coarse]));
    }
    return positions;
}

fn initialPositions(
    allocator: std.mem.Allocator,
    node_count: usize,
    options: Options,
    initial: ?[]const Point,
) ![]Point {
    const positions = try allocator.alloc(Point, node_count);
    const center_x = options.width / 2.0;
    const center_y = options.height / 2.0;
    const radius = @max(1.0, @min(options.width, options.height) * 0.32);
    for (positions, 0..) |*position, node| {
        if (initial) |source| {
            if (node < source.len) {
                position.* = source[node];
                continue;
            }
        }
        const angle = 2.0 * std.math.pi * @as(f64, @floatFromInt(node)) /
            @as(f64, @floatFromInt(@max(node_count, 1)));
        position.* = .{
            .x = center_x + std.math.cos(angle) * radius,
            .y = center_y + std.math.sin(angle) * radius,
        };
    }
    return positions;
}

fn prolongate(
    allocator: std.mem.Allocator,
    node_count: usize,
    mapping: []const usize,
    coarse_positions: []const Point,
    spring_length: f64,
) ![]Point {
    const positions = try allocator.alloc(Point, node_count);
    const jitter = @max(0.01, spring_length * 0.04);
    for (positions, 0..) |*position, node| {
        const parent = mapping[node];
        const angle = @as(f64, @floatFromInt(node + 1)) * 2.399963229728653;
        position.* = .{
            .x = coarse_positions[parent].x + std.math.cos(angle) * jitter,
            .y = coarse_positions[parent].y + std.math.sin(angle) * jitter,
        };
    }
    return positions;
}

fn relax(
    allocator: std.mem.Allocator,
    positions: []Point,
    edges: []const Edge,
    options: Options,
    iterations: usize,
    anchors: ?[]const Point,
) void {
    if (positions.len == 0) return;
    const displacement = allocator.alloc(Point, positions.len) catch return;
    defer allocator.free(displacement);
    const spring_length = @max(options.spring_length, 1.0);
    const power = std.math.clamp(options.repulsive_power, 0.1, 4.0);
    const initial_temperature = spring_length * std.math.sqrt(@as(f64, @floatFromInt(positions.len))) / 5.0;

    for (0..@max(iterations, 1)) |iteration| {
        @memset(displacement, .{ .x = 0, .y = 0 });
        for (positions, 0..) |position, left| {
            for (positions[left + 1 ..], left + 1..) |other, right| {
                var dx = other.x - position.x;
                var dy = other.y - position.y;
                var distance = std.math.hypot(dx, dy);
                if (distance < 0.001) {
                    const angle = @as(f64, @floatFromInt(left + right + 1)) * 2.399963229728653;
                    dx = std.math.cos(angle) * 0.001;
                    dy = std.math.sin(angle) * 0.001;
                    distance = 0.001;
                }
                const magnitude = std.math.pow(f64, spring_length, power + 1.0) /
                    std.math.pow(f64, distance, power);
                const force_x = dx / distance * magnitude;
                const force_y = dy / distance * magnitude;
                displacement[left].x -= force_x;
                displacement[left].y -= force_y;
                displacement[right].x += force_x;
                displacement[right].y += force_y;
            }
        }
        for (edges) |edge| {
            if (edge.from >= positions.len or edge.to >= positions.len or edge.from == edge.to) continue;
            const dx = positions[edge.to].x - positions[edge.from].x;
            const dy = positions[edge.to].y - positions[edge.from].y;
            const distance = @max(0.001, std.math.hypot(dx, dy));
            const magnitude = distance * distance / spring_length;
            const force_x = dx / distance * magnitude;
            const force_y = dy / distance * magnitude;
            displacement[edge.from].x += force_x;
            displacement[edge.from].y += force_y;
            displacement[edge.to].x -= force_x;
            displacement[edge.to].y -= force_y;
        }

        const remaining = @as(f64, @floatFromInt(@max(iterations, 1) - iteration));
        const temperature = initial_temperature * remaining /
            @as(f64, @floatFromInt(@max(iterations, 1)));
        for (positions, 0..) |*position, node| {
            var dx = displacement[node].x;
            var dy = displacement[node].y;
            const magnitude = std.math.hypot(dx, dy);
            if (magnitude > temperature and magnitude > 0.001) {
                const scale = temperature / magnitude;
                dx *= scale;
                dy *= scale;
            }
            position.x += dx;
            position.y += dy;
            if (anchors) |source| {
                if (node < source.len and options.stability > 0) {
                    position.x = position.x * (1.0 - options.stability) + source[node].x * options.stability;
                    position.y = position.y * (1.0 - options.stability) + source[node].y * options.stability;
                }
            }
        }
    }
}

fn fitToCanvas(positions: []Point, options: Options) void {
    if (positions.len == 0) return;
    var min_x = std.math.floatMax(f64);
    var min_y = std.math.floatMax(f64);
    var max_x: f64 = -std.math.floatMax(f64);
    var max_y: f64 = -std.math.floatMax(f64);
    for (positions) |position| {
        min_x = @min(min_x, position.x);
        min_y = @min(min_y, position.y);
        max_x = @max(max_x, position.x);
        max_y = @max(max_y, position.y);
    }
    const source_width = @max(1.0, max_x - min_x);
    const source_height = @max(1.0, max_y - min_y);
    const target_width = @max(1.0, options.width - options.margin * 2.0);
    const target_height = @max(1.0, options.height - options.margin * 2.0);
    const scale = @min(1.0, @min(target_width / source_width, target_height / source_height));
    const source_center_x = (min_x + max_x) / 2.0;
    const source_center_y = (min_y + max_y) / 2.0;
    for (positions) |*position| {
        position.x = options.width / 2.0 + (position.x - source_center_x) * scale;
        position.y = options.height / 2.0 + (position.y - source_center_y) * scale;
    }
}
