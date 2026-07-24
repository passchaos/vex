//! Deterministic multilevel spring-electrical layout.

const std = @import("std");
const LayoutControl = @import("options.zig").LayoutControl;
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
    theta: f64 = 0.75,
    exact_repulsion_threshold: usize = 48,
    control: LayoutControl = .{},
    work_start: usize = 0,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    positions: []Point,
    levels: usize,
    repulsion_evaluations: usize,
    work: usize,

    pub fn deinit(self: *Result) void {
        self.allocator.free(self.positions);
        self.* = undefined;
    }
};

pub const RepulsionStats = struct {
    evaluations: usize = 0,
    approximations: usize = 0,
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
    var repulsion_evaluations: usize = 0;
    var work = options.work_start;
    const positions = try layoutLevel(allocator, node_count, edges, options, initial, 0, &levels, &repulsion_evaluations, &work);
    fitToCanvas(positions, options);
    return .{
        .allocator = allocator,
        .positions = positions,
        .levels = levels,
        .repulsion_evaluations = repulsion_evaluations,
        .work = work,
    };
}

fn layoutLevel(
    allocator: std.mem.Allocator,
    node_count: usize,
    edges: []const Edge,
    options: Options,
    initial: ?[]const Point,
    level: usize,
    levels: *usize,
    repulsion_evaluations: *usize,
    work: *usize,
) ![]Point {
    if (node_count == 0) return allocator.alloc(Point, 0);
    work.* +|= node_count +| edges.len +| 1;
    try options.control.checkpoint(work.*);
    const max_levels = @max(options.max_levels, 1);
    if (node_count <= 12 or level + 1 >= max_levels) {
        const positions = try initialPositions(allocator, node_count, options, initial);
        const stats = try relax(allocator, positions, edges, options, @max(options.iterations, 1), if (level == 0) initial else null, work);
        repulsion_evaluations.* += stats.evaluations;
        return positions;
    }

    var coarse = try coarsen(allocator, node_count, edges);
    defer coarse.deinit();
    if (coarse.node_count >= node_count or coarse.node_count * 4 > node_count * 3) {
        const positions = try initialPositions(allocator, node_count, options, initial);
        const stats = try relax(allocator, positions, edges, options, @max(options.iterations, 1), if (level == 0) initial else null, work);
        repulsion_evaluations.* += stats.evaluations;
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
        repulsion_evaluations,
        work,
    );
    defer allocator.free(coarse_positions);

    const positions = try prolongate(allocator, node_count, coarse.mapping, coarse_positions, options.spring_length);
    const level_iterations = @max(8, options.iterations / @max(level + 2, 2));
    const stats = try relax(allocator, positions, edges, options, level_iterations, if (level == 0) initial else null, work);
    repulsion_evaluations.* += stats.evaluations;
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
    work: *usize,
) !RepulsionStats {
    if (positions.len == 0) return .{};
    const displacement = try allocator.alloc(Point, positions.len);
    defer allocator.free(displacement);
    const spring_length = @max(options.spring_length, 1.0);
    const power = std.math.clamp(options.repulsive_power, 0.1, 4.0);
    const initial_temperature = spring_length * std.math.sqrt(@as(f64, @floatFromInt(positions.len))) / 5.0;
    var total_stats = RepulsionStats{};

    for (0..@max(iterations, 1)) |iteration| {
        work.* +|= positions.len +| edges.len +| 1;
        try options.control.checkpoint(work.*);
        @memset(displacement, .{ .x = 0, .y = 0 });
        const stats = try repulsionForces(
            allocator,
            positions,
            spring_length,
            power,
            options.theta,
            positions.len <= options.exact_repulsion_threshold,
            displacement,
        );
        total_stats.evaluations += stats.evaluations;
        total_stats.approximations += stats.approximations;
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
    return total_stats;
}

pub fn repulsionForces(
    allocator: std.mem.Allocator,
    positions: []const Point,
    spring_length: f64,
    power: f64,
    theta: f64,
    exact: bool,
    displacement: []Point,
) !RepulsionStats {
    if (positions.len != displacement.len) return error.InvalidRepulsionState;
    @memset(displacement, .{ .x = 0, .y = 0 });
    if (positions.len <= 1) return .{};
    if (exact) return exactRepulsion(positions, spring_length, power, displacement);

    var tree = try QuadTree.init(allocator, positions);
    defer tree.deinit();
    var stats = RepulsionStats{};
    for (positions, 0..) |position, target| {
        accumulateQuadForce(
            &tree,
            tree.root,
            target,
            position,
            spring_length,
            power,
            @max(theta, 0.05),
            &displacement[target],
            &stats,
        );
    }
    return stats;
}

fn exactRepulsion(
    positions: []const Point,
    spring_length: f64,
    power: f64,
    displacement: []Point,
) RepulsionStats {
    var stats = RepulsionStats{};
    for (positions, 0..) |position, left| {
        for (positions[left + 1 ..], left + 1..) |other, right| {
            const force = repulsiveForce(position, other, spring_length, power, 1.0, left + right + 1);
            displacement[left].x += force.x;
            displacement[left].y += force.y;
            displacement[right].x -= force.x;
            displacement[right].y -= force.y;
            stats.evaluations += 2;
        }
    }
    return stats;
}

fn repulsiveForce(
    target: Point,
    source: Point,
    spring_length: f64,
    power: f64,
    mass: f64,
    seed: usize,
) Point {
    var dx = source.x - target.x;
    var dy = source.y - target.y;
    var distance = std.math.hypot(dx, dy);
    if (distance < 0.001) {
        const angle = @as(f64, @floatFromInt(seed + 1)) * 2.399963229728653;
        dx = std.math.cos(angle) * 0.001;
        dy = std.math.sin(angle) * 0.001;
        distance = 0.001;
    }
    const magnitude = mass * std.math.pow(f64, spring_length, power + 1.0) /
        std.math.pow(f64, distance, power);
    return .{
        .x = -dx / distance * magnitude,
        .y = -dy / distance * magnitude,
    };
}

const QuadNode = struct {
    center: Point,
    half: f64,
    center_of_mass: Point,
    mass: usize,
    start: usize,
    count: usize,
    children: [4]?usize = .{ null, null, null, null },
};

const QuadTree = struct {
    allocator: std.mem.Allocator,
    positions: []const Point,
    indices: []usize,
    scratch: []usize,
    nodes: std.ArrayList(QuadNode),
    root: usize,

    fn init(allocator: std.mem.Allocator, positions: []const Point) !QuadTree {
        const indices = try allocator.alloc(usize, positions.len);
        errdefer allocator.free(indices);
        for (indices, 0..) |*index, value| index.* = value;
        const scratch = try allocator.alloc(usize, positions.len);
        errdefer allocator.free(scratch);

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
        const center = Point{ .x = (min_x + max_x) / 2.0, .y = (min_y + max_y) / 2.0 };
        const half = @max(0.001, @max(max_x - min_x, max_y - min_y) / 2.0 + 0.001);
        var tree = QuadTree{
            .allocator = allocator,
            .positions = positions,
            .indices = indices,
            .scratch = scratch,
            .nodes = .empty,
            .root = 0,
        };
        errdefer tree.deinit();
        tree.root = try tree.buildNode(0, positions.len, center, half, 0);
        return tree;
    }

    fn deinit(self: *QuadTree) void {
        self.nodes.deinit(self.allocator);
        self.allocator.free(self.indices);
        self.allocator.free(self.scratch);
        self.* = undefined;
    }

    fn buildNode(
        self: *QuadTree,
        start: usize,
        count: usize,
        center: Point,
        half: f64,
        depth: usize,
    ) !usize {
        var center_of_mass = Point{ .x = 0, .y = 0 };
        for (self.indices[start .. start + count]) |point_index| {
            center_of_mass.x += self.positions[point_index].x;
            center_of_mass.y += self.positions[point_index].y;
        }
        if (count > 0) {
            center_of_mass.x /= @as(f64, @floatFromInt(count));
            center_of_mass.y /= @as(f64, @floatFromInt(count));
        }
        const node_index = self.nodes.items.len;
        try self.nodes.append(self.allocator, .{
            .center = center,
            .half = half,
            .center_of_mass = center_of_mass,
            .mass = count,
            .start = start,
            .count = count,
        });
        if (count <= 4 or depth >= 24 or half <= 0.0001) return node_index;

        var counts = [_]usize{ 0, 0, 0, 0 };
        for (self.indices[start .. start + count]) |point_index| {
            counts[quadrant(self.positions[point_index], center)] += 1;
        }
        const offsets = [_]usize{ start, start + counts[0], start + counts[0] + counts[1], start + counts[0] + counts[1] + counts[2] };
        var cursors = offsets;
        for (self.indices[start .. start + count]) |point_index| {
            const q = quadrant(self.positions[point_index], center);
            self.scratch[cursors[q]] = point_index;
            cursors[q] += 1;
        }
        @memcpy(self.indices[start .. start + count], self.scratch[start .. start + count]);

        const child_half = half / 2.0;
        for (counts, 0..) |child_count, q| {
            if (child_count == 0) continue;
            const child_center = Point{
                .x = center.x + (if ((q & 1) == 0) -child_half else child_half),
                .y = center.y + (if ((q & 2) == 0) -child_half else child_half),
            };
            const child = try self.buildNode(offsets[q], child_count, child_center, child_half, depth + 1);
            self.nodes.items[node_index].children[q] = child;
        }
        return node_index;
    }
};

fn quadrant(position: Point, center: Point) usize {
    return @as(usize, if (position.x >= center.x) 1 else 0) |
        @as(usize, if (position.y >= center.y) 2 else 0);
}

fn accumulateQuadForce(
    tree: *const QuadTree,
    node_index: usize,
    target: usize,
    target_position: Point,
    spring_length: f64,
    power: f64,
    theta: f64,
    displacement: *Point,
    stats: *RepulsionStats,
) void {
    const node = tree.nodes.items[node_index];
    if (node.mass == 0) return;
    if (node.count <= 4) {
        for (tree.indices[node.start .. node.start + node.count]) |source| {
            if (source == target) continue;
            const force = repulsiveForce(target_position, tree.positions[source], spring_length, power, 1.0, target + source + 1);
            displacement.x += force.x;
            displacement.y += force.y;
            stats.evaluations += 1;
        }
        return;
    }

    const dx = node.center_of_mass.x - target_position.x;
    const dy = node.center_of_mass.y - target_position.y;
    const distance = @max(0.001, std.math.hypot(dx, dy));
    const contains_target = target_position.x >= node.center.x - node.half and
        target_position.x <= node.center.x + node.half and
        target_position.y >= node.center.y - node.half and
        target_position.y <= node.center.y + node.half;
    if (!contains_target and node.half * 2.0 / distance < theta) {
        const force = repulsiveForce(
            target_position,
            node.center_of_mass,
            spring_length,
            power,
            @as(f64, @floatFromInt(node.mass)),
            target + node_index + 1,
        );
        displacement.x += force.x;
        displacement.y += force.y;
        stats.evaluations += 1;
        stats.approximations += 1;
        return;
    }

    for (node.children) |child| {
        if (child) |index| accumulateQuadForce(
            tree,
            index,
            target,
            target_position,
            spring_length,
            power,
            theta,
            displacement,
            stats,
        );
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
