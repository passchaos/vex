//! Deterministic circular layout based on biconnected blocks.

const std = @import("std");
const Point = @import("result.zig").Point;

pub const Edge = struct {
    from: usize,
    to: usize,
};

pub const Options = struct {
    min_dist: f64 = 72,
    component_roots: []const usize = &.{},
    component_gap: f64 = 96,
    one_block: bool = false,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    positions: []Point,
    block_count: usize,
    component_count: usize,

    pub fn deinit(self: *Result) void {
        self.allocator.free(self.positions);
        self.* = undefined;
    }
};

const Block = struct {
    nodes: std.ArrayList(usize) = .empty,

    fn deinit(self: *Block, allocator: std.mem.Allocator) void {
        self.nodes.deinit(allocator);
    }
};

const Component = struct {
    nodes: std.ArrayList(usize) = .empty,

    fn deinit(self: *Component, allocator: std.mem.Allocator) void {
        self.nodes.deinit(allocator);
    }
};

const Tarjan = struct {
    allocator: std.mem.Allocator,
    edges: []const Edge,
    discovery: []usize,
    low: []usize,
    parent: []?usize,
    edge_stack: std.ArrayList(usize) = .empty,
    blocks: std.ArrayList(Block) = .empty,
    time: usize = 0,

    fn deinit(self: *Tarjan) void {
        for (self.blocks.items) |*block| block.deinit(self.allocator);
        self.blocks.deinit(self.allocator);
        self.edge_stack.deinit(self.allocator);
        self.allocator.free(self.discovery);
        self.allocator.free(self.low);
        self.allocator.free(self.parent);
        self.* = undefined;
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
    var components = try connectedComponents(allocator, node_count, edges);
    defer {
        for (components.items) |*component| component.deinit(allocator);
        components.deinit(allocator);
    }

    var total_blocks: usize = 0;
    var cursor_x: f64 = 0;
    for (components.items) |component| {
        var blocks = if (options.one_block)
            try oneBlock(allocator, component.nodes.items)
        else
            try biconnectedBlocks(allocator, node_count, component.nodes.items, edges);
        defer {
            for (blocks.items) |*block| block.deinit(allocator);
            blocks.deinit(allocator);
        }
        total_blocks += blocks.items.len;
        if (blocks.items.len == 0) continue;

        const root_block = chooseRootBlock(blocks.items, preferred_root, options.component_roots);
        const placed_blocks = try allocator.alloc(bool, blocks.items.len);
        defer allocator.free(placed_blocks);
        @memset(placed_blocks, false);
        const placed_nodes = try allocator.alloc(bool, node_count);
        defer allocator.free(placed_nodes);
        @memset(placed_nodes, false);

        try placeBlockTree(
            allocator,
            blocks.items,
            root_block,
            null,
            .{ .x = 0, .y = 0 },
            0,
            @max(options.min_dist, 1.0),
            positions,
            placed_blocks,
            placed_nodes,
        );

        var min_x = std.math.floatMax(f64);
        var min_y = std.math.floatMax(f64);
        var max_x: f64 = -std.math.floatMax(f64);
        var max_y: f64 = -std.math.floatMax(f64);
        for (component.nodes.items) |node| {
            min_x = @min(min_x, positions[node].x);
            min_y = @min(min_y, positions[node].y);
            max_x = @max(max_x, positions[node].x);
            max_y = @max(max_y, positions[node].y);
        }
        const width = @max(options.min_dist, max_x - min_x);
        const shift_x = cursor_x - min_x;
        const shift_y = -(min_y + max_y) / 2.0;
        for (component.nodes.items) |node| {
            positions[node].x += shift_x;
            positions[node].y += shift_y;
        }
        cursor_x += width + @max(options.component_gap, options.min_dist);
    }
    centerPositions(positions);
    return .{
        .allocator = allocator,
        .positions = positions,
        .block_count = total_blocks,
        .component_count = components.items.len,
    };
}

fn oneBlock(allocator: std.mem.Allocator, nodes: []const usize) !std.ArrayList(Block) {
    var blocks = std.ArrayList(Block).empty;
    errdefer blocks.deinit(allocator);
    var block = Block{};
    errdefer block.deinit(allocator);
    try block.nodes.appendSlice(allocator, nodes);
    try blocks.append(allocator, block);
    return blocks;
}

fn biconnectedBlocks(
    allocator: std.mem.Allocator,
    node_count: usize,
    component_nodes: []const usize,
    edges: []const Edge,
) !std.ArrayList(Block) {
    const discovery = try allocator.alloc(usize, node_count);
    errdefer allocator.free(discovery);
    @memset(discovery, 0);
    const low = try allocator.alloc(usize, node_count);
    errdefer allocator.free(low);
    @memset(low, 0);
    const parent = try allocator.alloc(?usize, node_count);
    errdefer allocator.free(parent);
    @memset(parent, null);
    var tarjan = Tarjan{
        .allocator = allocator,
        .edges = edges,
        .discovery = discovery,
        .low = low,
        .parent = parent,
    };
    errdefer tarjan.deinit();

    for (component_nodes) |start| {
        if (tarjan.discovery[start] != 0) continue;
        try tarjanVisit(&tarjan, start);
        if (tarjan.edge_stack.items.len > 0) try emitBlock(&tarjan, null);
    }
    if (tarjan.blocks.items.len == 0 and component_nodes.len > 0) {
        var block = Block{};
        try block.nodes.appendSlice(allocator, component_nodes);
        try tarjan.blocks.append(allocator, block);
    }

    const blocks = tarjan.blocks;
    tarjan.blocks = .empty;
    tarjan.deinit();
    return blocks;
}

fn tarjanVisit(tarjan: *Tarjan, node: usize) !void {
    tarjan.time += 1;
    tarjan.discovery[node] = tarjan.time;
    tarjan.low[node] = tarjan.time;

    for (tarjan.edges, 0..) |edge, edge_index| {
        const neighbor = if (edge.from == node)
            edge.to
        else if (edge.to == node)
            edge.from
        else
            continue;
        if (neighbor == node or neighbor >= tarjan.discovery.len) continue;
        if (tarjan.discovery[neighbor] == 0) {
            tarjan.parent[neighbor] = node;
            try tarjan.edge_stack.append(tarjan.allocator, edge_index);
            try tarjanVisit(tarjan, neighbor);
            tarjan.low[node] = @min(tarjan.low[node], tarjan.low[neighbor]);
            if (tarjan.low[neighbor] >= tarjan.discovery[node]) {
                try emitBlock(tarjan, edge_index);
            }
        } else if (tarjan.parent[node] != neighbor and tarjan.discovery[neighbor] < tarjan.discovery[node]) {
            tarjan.low[node] = @min(tarjan.low[node], tarjan.discovery[neighbor]);
            try tarjan.edge_stack.append(tarjan.allocator, edge_index);
        }
    }
}

fn emitBlock(tarjan: *Tarjan, stop_edge: ?usize) !void {
    var block = Block{};
    errdefer block.deinit(tarjan.allocator);
    while (tarjan.edge_stack.pop()) |edge_index| {
        const edge = tarjan.edges[edge_index];
        if (!contains(block.nodes.items, edge.from)) try block.nodes.append(tarjan.allocator, edge.from);
        if (!contains(block.nodes.items, edge.to)) try block.nodes.append(tarjan.allocator, edge.to);
        if (stop_edge != null and edge_index == stop_edge.?) break;
    }
    if (block.nodes.items.len > 0) {
        std.mem.sort(usize, block.nodes.items, {}, std.sort.asc(usize));
        try tarjan.blocks.append(tarjan.allocator, block);
    }
}

fn chooseRootBlock(blocks: []const Block, preferred_root: ?usize, component_roots: []const usize) usize {
    if (preferred_root) |root| {
        for (blocks, 0..) |block, index| {
            if (contains(block.nodes.items, root)) return index;
        }
    }
    for (component_roots) |root| {
        for (blocks, 0..) |block, index| {
            if (contains(block.nodes.items, root)) return index;
        }
    }
    var best: usize = 0;
    for (blocks[1..], 1..) |block, index| {
        if (block.nodes.items.len > blocks[best].nodes.items.len) best = index;
    }
    return best;
}

fn placeBlockTree(
    allocator: std.mem.Allocator,
    blocks: []const Block,
    block_index: usize,
    parent_articulation: ?usize,
    center: Point,
    outward_angle: f64,
    min_dist: f64,
    positions: []Point,
    placed_blocks: []bool,
    placed_nodes: []bool,
) !void {
    if (block_index >= blocks.len or placed_blocks[block_index]) return;
    placed_blocks[block_index] = true;
    const block = blocks[block_index];
    const count = block.nodes.items.len;
    const radius = if (count <= 1)
        0.0
    else
        @max(min_dist, @as(f64, @floatFromInt(count)) * min_dist / std.math.tau);
    const start_angle = if (parent_articulation != null) outward_angle + std.math.pi else 0;

    const ordered = try allocator.dupe(usize, block.nodes.items);
    defer allocator.free(ordered);
    if (parent_articulation) |articulation| moveNodeFirst(ordered, articulation);
    for (ordered, 0..) |node, index| {
        const angle = start_angle + @as(f64, @floatFromInt(index)) * std.math.tau /
            @as(f64, @floatFromInt(@max(count, 1)));
        const point = if (count == 1) center else Point{
            .x = center.x + std.math.cos(angle) * radius,
            .y = center.y + std.math.sin(angle) * radius,
        };
        if (parent_articulation == null or node != parent_articulation.?) positions[node] = point;
        placed_nodes[node] = true;
    }

    for (block.nodes.items) |articulation| {
        var children: [128]usize = undefined;
        var child_count: usize = 0;
        for (blocks, 0..) |candidate, candidate_index| {
            if (placed_blocks[candidate_index] or candidate_index == block_index) continue;
            if (!contains(candidate.nodes.items, articulation)) continue;
            if (child_count < children.len) {
                children[child_count] = candidate_index;
                child_count += 1;
            }
        }
        if (child_count == 0) continue;
        const base_angle = std.math.atan2(
            positions[articulation].y - center.y,
            positions[articulation].x - center.x,
        );
        for (children[0..child_count], 0..) |child, child_order| {
            const spread = if (child_count == 1)
                0.0
            else
                (@as(f64, @floatFromInt(child_order)) /
                    @as(f64, @floatFromInt(child_count - 1)) - 0.5) * std.math.pi / 2.0;
            const angle = base_angle + spread;
            const child_radius = @max(
                min_dist,
                @as(f64, @floatFromInt(blocks[child].nodes.items.len)) * min_dist / std.math.tau,
            );
            const child_center = Point{
                .x = positions[articulation].x + std.math.cos(angle) * child_radius,
                .y = positions[articulation].y + std.math.sin(angle) * child_radius,
            };
            try placeBlockTree(
                allocator,
                blocks,
                child,
                articulation,
                child_center,
                angle,
                min_dist,
                positions,
                placed_blocks,
                placed_nodes,
            );
        }
    }
}

fn moveNodeFirst(nodes: []usize, target: usize) void {
    for (nodes, 0..) |node, index| {
        if (node != target or index == 0) continue;
        const value = nodes[index];
        var cursor = index;
        while (cursor > 0) : (cursor -= 1) nodes[cursor] = nodes[cursor - 1];
        nodes[0] = value;
        return;
    }
}

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

fn contains(nodes: []const usize, target: usize) bool {
    for (nodes) |node| if (node == target) return true;
    return false;
}

test "component roots choose circular root blocks" {
    const allocator = std.testing.allocator;
    const edges = [_]Edge{
        .{ .from = 0, .to = 1 },
        .{ .from = 1, .to = 2 },
        .{ .from = 2, .to = 0 },
        .{ .from = 2, .to = 3 },
        .{ .from = 4, .to = 5 },
        .{ .from = 5, .to = 6 },
        .{ .from = 6, .to = 4 },
        .{ .from = 6, .to = 7 },
    };
    const roots = [_]usize{ 3, 7 };
    var result = try layout(allocator, 8, &edges, null, .{ .component_roots = &roots });
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 2), result.component_count);
    try std.testing.expect(result.positions[3].x < result.positions[0].x);
    try std.testing.expect(result.positions[7].x < result.positions[4].x);
}
