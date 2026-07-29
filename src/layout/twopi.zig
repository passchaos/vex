//! Deterministic radial layout using BFS rings and subtree angular spans.

const std = @import("std");
const Point = @import("result.zig").Point;

pub const Edge = struct {
    from: usize,
    to: usize,
};

pub const Options = struct {
    ring_gap: f64 = 72,
    rank_radii: []const f64 = &.{},
    component_gap: f64 = 96,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    positions: []Point,
    depths: []usize,
    roots: []usize,
    component_count: usize,

    pub fn deinit(self: *Result) void {
        self.allocator.free(self.positions);
        self.allocator.free(self.depths);
        self.allocator.free(self.roots);
        self.* = undefined;
    }
};

const Component = struct {
    nodes: std.ArrayList(usize) = .empty,

    fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        self.nodes.deinit(allocator);
    }
};

pub fn layout(
    allocator: std.mem.Allocator,
    node_count: usize,
    edges: []const Edge,
    preferred_root: ?usize,
    options: Options,
) !Result {
    const positions = try allocator.alloc(Point, node_count);
    errdefer allocator.free(positions);
    @memset(positions, .{ .x = 0, .y = 0 });
    const depths = try allocator.alloc(usize, node_count);
    errdefer allocator.free(depths);
    @memset(depths, 0);

    var components = try connectedComponents(allocator, node_count, edges);
    defer {
        for (components.items) |*component| component.deinit(allocator);
        components.deinit(allocator);
    }
    const roots = try allocator.alloc(usize, components.items.len);
    errdefer allocator.free(roots);

    var cursor_x: f64 = 0;
    const gap = @max(options.ring_gap, 1.0);
    for (components.items, 0..) |component, component_index| {
        const root = if (preferred_root) |candidate|
            if (contains(component.nodes.items, candidate)) candidate else chooseCenter(
                allocator,
                component.nodes.items,
                edges,
                node_count,
            ) catch component.nodes.items[0]
        else
            try chooseCenter(allocator, component.nodes.items, edges, node_count);
        roots[component_index] = root;

        var tree = try buildTree(allocator, component.nodes.items, edges, node_count, root);
        defer tree.deinit();
        assignSubtreeLeaves(&tree, component.nodes.items);
        assignAngles(&tree, root, 0, std.math.tau);

        var min_x = std.math.floatMax(f64);
        var max_x: f64 = -std.math.floatMax(f64);
        var min_y = std.math.floatMax(f64);
        var max_y: f64 = -std.math.floatMax(f64);
        for (component.nodes.items) |node| {
            const radius = radiusForDepth(options, tree.depth[node]);
            const point = Point{
                .x = std.math.cos(tree.angle[node]) * radius,
                .y = std.math.sin(tree.angle[node]) * radius,
            };
            positions[node] = point;
            depths[node] = tree.depth[node];
            min_x = @min(min_x, point.x);
            max_x = @max(max_x, point.x);
            min_y = @min(min_y, point.y);
            max_y = @max(max_y, point.y);
        }
        const component_width = @max(gap, max_x - min_x);
        const shift_x = cursor_x - min_x;
        const shift_y = -(min_y + max_y) / 2.0;
        for (component.nodes.items) |node| {
            positions[node].x += shift_x;
            positions[node].y += shift_y;
        }
        cursor_x += component_width + @max(options.component_gap, gap);
    }

    centerPositions(positions);
    return .{
        .allocator = allocator,
        .positions = positions,
        .depths = depths,
        .roots = roots,
        .component_count = components.items.len,
    };
}

const Tree = struct {
    allocator: std.mem.Allocator,
    parent: []?usize,
    depth: []usize,
    leaf_count: []usize,
    angle: []f64,
    children: []std.ArrayList(usize),

    fn deinit(self: *Tree) void {
        for (self.children) |*children| children.deinit(self.allocator);
        self.allocator.free(self.children);
        self.allocator.free(self.parent);
        self.allocator.free(self.depth);
        self.allocator.free(self.leaf_count);
        self.allocator.free(self.angle);
        self.* = undefined;
    }
};

fn connectedComponents(
    allocator: std.mem.Allocator,
    node_count: usize,
    edges: []const Edge,
) !std.ArrayList(Component) {
    var components = std.ArrayList(Component).empty;
    errdefer {
        for (components.items) |*component| component.deinit(allocator);
        components.deinit(allocator);
    }
    const visited = try allocator.alloc(bool, node_count);
    defer allocator.free(visited);
    @memset(visited, false);
    var queue = std.ArrayList(usize).empty;
    defer queue.deinit(allocator);

    for (0..node_count) |start| {
        if (visited[start]) continue;
        var component = Component{};
        errdefer component.deinit(allocator);
        queue.clearRetainingCapacity();
        try queue.append(allocator, start);
        visited[start] = true;
        var head: usize = 0;
        while (head < queue.items.len) : (head += 1) {
            const node = queue.items[head];
            try component.nodes.append(allocator, node);
            for (edges) |edge| {
                const neighbor = if (edge.from == node)
                    edge.to
                else if (edge.to == node)
                    edge.from
                else
                    continue;
                if (neighbor >= node_count or visited[neighbor]) continue;
                visited[neighbor] = true;
                try queue.append(allocator, neighbor);
            }
        }
        try components.append(allocator, component);
    }
    return components;
}

fn chooseCenter(
    allocator: std.mem.Allocator,
    nodes: []const usize,
    edges: []const Edge,
    node_count: usize,
) !usize {
    if (nodes.len == 0) return error.EmptyComponent;
    const distance = try allocator.alloc(usize, node_count);
    defer allocator.free(distance);
    @memset(distance, std.math.maxInt(usize));
    var queue = std.ArrayList(usize).empty;
    defer queue.deinit(allocator);

    var leaf_count: usize = 0;
    for (nodes) |node| {
        if (distinctDegree(node, edges) <= 1) {
            distance[node] = 0;
            try queue.append(allocator, node);
            leaf_count += 1;
        }
    }
    if (leaf_count == 0) return nodes[0];

    var head: usize = 0;
    while (head < queue.items.len) : (head += 1) {
        const node = queue.items[head];
        for (edges) |edge| {
            const neighbor = if (edge.from == node)
                edge.to
            else if (edge.to == node)
                edge.from
            else
                continue;
            if (neighbor >= node_count or distance[neighbor] <= distance[node] + 1) continue;
            distance[neighbor] = distance[node] + 1;
            try queue.append(allocator, neighbor);
        }
    }

    var center = nodes[0];
    for (nodes[1..]) |node| {
        if (distance[node] > distance[center] or
            (distance[node] == distance[center] and node < center))
        {
            center = node;
        }
    }
    return center;
}

fn distinctDegree(node: usize, edges: []const Edge) usize {
    var neighbors: [128]usize = undefined;
    var count: usize = 0;
    for (edges) |edge| {
        const neighbor = if (edge.from == node)
            edge.to
        else if (edge.to == node)
            edge.from
        else
            continue;
        if (neighbor == node) continue;
        var seen = false;
        for (neighbors[0..count]) |existing| {
            if (existing == neighbor) {
                seen = true;
                break;
            }
        }
        if (!seen) {
            if (count == neighbors.len) return count + 1;
            neighbors[count] = neighbor;
            count += 1;
        }
    }
    return count;
}

fn buildTree(
    allocator: std.mem.Allocator,
    component_nodes: []const usize,
    edges: []const Edge,
    node_count: usize,
    root: usize,
) !Tree {
    const parent = try allocator.alloc(?usize, node_count);
    errdefer allocator.free(parent);
    @memset(parent, null);
    const depth = try allocator.alloc(usize, node_count);
    errdefer allocator.free(depth);
    @memset(depth, std.math.maxInt(usize));
    const leaf_count = try allocator.alloc(usize, node_count);
    errdefer allocator.free(leaf_count);
    @memset(leaf_count, 0);
    const angle = try allocator.alloc(f64, node_count);
    errdefer allocator.free(angle);
    @memset(angle, 0);
    const children = try allocator.alloc(std.ArrayList(usize), node_count);
    errdefer allocator.free(children);
    for (children) |*list| list.* = .empty;
    errdefer for (children) |*list| list.deinit(allocator);

    var queue = std.ArrayList(usize).empty;
    defer queue.deinit(allocator);
    try queue.append(allocator, root);
    depth[root] = 0;
    var head: usize = 0;
    while (head < queue.items.len) : (head += 1) {
        const node = queue.items[head];
        for (edges) |edge| {
            const neighbor = if (edge.from == node)
                edge.to
            else if (edge.to == node)
                edge.from
            else
                continue;
            if (neighbor >= node_count or depth[neighbor] != std.math.maxInt(usize)) continue;
            if (!contains(component_nodes, neighbor)) continue;
            parent[neighbor] = node;
            depth[neighbor] = depth[node] + 1;
            try children[node].append(allocator, neighbor);
            try queue.append(allocator, neighbor);
        }
    }
    return .{
        .allocator = allocator,
        .parent = parent,
        .depth = depth,
        .leaf_count = leaf_count,
        .angle = angle,
        .children = children,
    };
}

fn assignSubtreeLeaves(tree: *Tree, nodes: []const usize) void {
    var max_depth: usize = 0;
    for (nodes) |node| max_depth = @max(max_depth, tree.depth[node]);
    var depth = max_depth + 1;
    while (depth > 0) {
        depth -= 1;
        for (nodes) |node| {
            if (tree.depth[node] != depth) continue;
            var leaves: usize = 0;
            for (tree.children[node].items) |child| leaves += tree.leaf_count[child];
            tree.leaf_count[node] = if (leaves == 0) 1 else leaves;
        }
    }
}

fn assignAngles(tree: *Tree, node: usize, lower: f64, span: f64) void {
    tree.angle[node] = lower + span / 2.0;
    if (tree.children[node].items.len == 0) return;
    const total = @as(f64, @floatFromInt(tree.leaf_count[node]));
    var cursor = lower;
    for (tree.children[node].items) |child| {
        const child_span = span * @as(f64, @floatFromInt(tree.leaf_count[child])) / total;
        assignAngles(tree, child, cursor, child_span);
        cursor += child_span;
    }
}

fn centerPositions(positions: []Point) void {
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
    const shift_x = -(min_x + max_x) / 2.0;
    const shift_y = -(min_y + max_y) / 2.0;
    for (positions) |*position| {
        position.x += shift_x;
        position.y += shift_y;
    }
}

fn radiusForDepth(options: Options, depth: usize) f64 {
    if (depth == 0) return 0;
    if (depth < options.rank_radii.len) return options.rank_radii[depth];
    const gap = @max(options.ring_gap, 1.0);
    if (options.rank_radii.len > 0) {
        return options.rank_radii[options.rank_radii.len - 1] +
            @as(f64, @floatFromInt(depth - (options.rank_radii.len - 1))) * gap;
    }
    return @as(f64, @floatFromInt(depth)) * gap;
}

fn contains(nodes: []const usize, target: usize) bool {
    for (nodes) |node| if (node == target) return true;
    return false;
}
