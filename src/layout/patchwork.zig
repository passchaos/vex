//! Hierarchical squarified treemap layout for patchwork.

const std = @import("std");
const Rect = @import("result.zig").SubgraphLayout;

pub const Node = struct {
    area: f64,
    parent: ?usize,
};

pub const Subgraph = struct {
    parent: ?usize,
    area_override: ?f64,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    node_rects: []Rect,
    subgraph_rects: []Rect,

    pub fn deinit(self: *Result) void {
        self.allocator.free(self.node_rects);
        self.allocator.free(self.subgraph_rects);
        self.* = undefined;
    }
};

const Item = union(enum) {
    node: usize,
    subgraph: usize,
};

const WeightedItem = struct {
    item: Item,
    weight: f64,
};

pub fn layout(
    allocator: std.mem.Allocator,
    nodes: []const Node,
    subgraphs: []const Subgraph,
    width: f64,
    height: f64,
    padding: f64,
) !Result {
    const node_rects = try allocator.alloc(Rect, nodes.len);
    errdefer allocator.free(node_rects);
    for (node_rects, 0..) |*rect, id| rect.* = .{ .id = id, .x = 0, .y = 0, .width = 0, .height = 0 };
    const subgraph_rects = try allocator.alloc(Rect, subgraphs.len);
    errdefer allocator.free(subgraph_rects);
    for (subgraph_rects, 0..) |*rect, id| rect.* = .{ .id = id, .x = 0, .y = 0, .width = 0, .height = 0 };

    const subgraph_weights = try allocator.alloc(f64, subgraphs.len);
    defer allocator.free(subgraph_weights);
    @memset(subgraph_weights, 0);
    computeSubgraphWeights(nodes, subgraphs, subgraph_weights);

    var root_items = std.ArrayList(WeightedItem).empty;
    defer root_items.deinit(allocator);
    for (subgraphs, 0..) |subgraph, id| {
        if (subgraph.parent == null) try root_items.append(allocator, .{
            .item = .{ .subgraph = id },
            .weight = subgraph_weights[id],
        });
    }
    for (nodes, 0..) |node, id| {
        if (node.parent == null) try root_items.append(allocator, .{
            .item = .{ .node = id },
            .weight = positiveArea(node.area),
        });
    }

    const root = Rect{ .id = 0, .x = 0, .y = 0, .width = @max(width, 1.0), .height = @max(height, 1.0) };
    try layoutItems(
        allocator,
        root_items.items,
        root,
        @max(padding, 0),
        nodes,
        subgraphs,
        subgraph_weights,
        node_rects,
        subgraph_rects,
    );
    return .{ .allocator = allocator, .node_rects = node_rects, .subgraph_rects = subgraph_rects };
}

fn computeSubgraphWeights(nodes: []const Node, subgraphs: []const Subgraph, weights: []f64) void {
    var remaining = subgraphs.len;
    while (remaining > 0) : (remaining -= 1) {
        const id = remaining - 1;
        var child_area: f64 = 0;
        for (nodes) |node| {
            if (node.parent == id) child_area += positiveArea(node.area);
        }
        for (subgraphs, 0..) |child, child_id| {
            if (child.parent == id) child_area += weights[child_id];
        }
        weights[id] = if (subgraphs[id].area_override) |area|
            positiveArea(area)
        else
            @max(child_area, 1.0);
    }
}

fn layoutItems(
    allocator: std.mem.Allocator,
    items: []const WeightedItem,
    rect: Rect,
    padding: f64,
    nodes: []const Node,
    subgraphs: []const Subgraph,
    subgraph_weights: []const f64,
    node_rects: []Rect,
    subgraph_rects: []Rect,
) !void {
    if (items.len == 0 or rect.width <= 0 or rect.height <= 0) return;
    const sorted = try allocator.dupe(WeightedItem, items);
    defer allocator.free(sorted);
    std.mem.sort(WeightedItem, sorted, {}, heavierItemFirst);
    const rects = try allocator.alloc(Rect, sorted.len);
    defer allocator.free(rects);
    squarify(sorted, rect, rects);

    for (sorted, rects) |weighted, item_rect| {
        switch (weighted.item) {
            .node => |id| {
                if (id < node_rects.len) node_rects[id] = .{
                    .id = id,
                    .x = item_rect.x,
                    .y = item_rect.y,
                    .width = item_rect.width,
                    .height = item_rect.height,
                };
            },
            .subgraph => |id| {
                if (id >= subgraph_rects.len) continue;
                subgraph_rects[id] = .{
                    .id = id,
                    .x = item_rect.x,
                    .y = item_rect.y,
                    .width = item_rect.width,
                    .height = item_rect.height,
                };
                var children = std.ArrayList(WeightedItem).empty;
                defer children.deinit(allocator);
                for (subgraphs, 0..) |child, child_id| {
                    if (child.parent == id) try children.append(allocator, .{
                        .item = .{ .subgraph = child_id },
                        .weight = subgraph_weights[child_id],
                    });
                }
                for (nodes, 0..) |node, node_id| {
                    if (node.parent == id) try children.append(allocator, .{
                        .item = .{ .node = node_id },
                        .weight = positiveArea(node.area),
                    });
                }
                const inner = insetRect(item_rect, padding);
                try layoutItems(
                    allocator,
                    children.items,
                    inner,
                    padding,
                    nodes,
                    subgraphs,
                    subgraph_weights,
                    node_rects,
                    subgraph_rects,
                );
            },
        }
    }
}

fn squarify(items: []const WeightedItem, rect: Rect, output: []Rect) void {
    var remaining = rect;
    var index: usize = 0;
    var total_weight: f64 = 0;
    for (items) |item| total_weight += positiveArea(item.weight);
    var remaining_weight = total_weight;

    while (index < items.len and remaining_weight > 0 and remaining.width > 0 and remaining.height > 0) {
        var row_end = index + 1;
        var row_weight = positiveArea(items[index].weight);
        var worst = rowWorst(items[index..row_end], row_weight, remaining, remaining_weight);
        while (row_end < items.len) {
            const candidate_weight = row_weight + positiveArea(items[row_end].weight);
            const candidate = rowWorst(items[index .. row_end + 1], candidate_weight, remaining, remaining_weight);
            if (candidate > worst) break;
            row_weight = candidate_weight;
            worst = candidate;
            row_end += 1;
        }

        const horizontal = remaining.width >= remaining.height;
        const fraction = row_weight / remaining_weight;
        if (horizontal) {
            const row_width = remaining.width * fraction;
            var cursor = remaining.y;
            for (items[index..row_end], index..) |item, output_index| {
                const height = if (output_index + 1 == row_end)
                    remaining.y + remaining.height - cursor
                else
                    remaining.height * positiveArea(item.weight) / row_weight;
                output[output_index] = .{ .id = output_index, .x = remaining.x, .y = cursor, .width = row_width, .height = height };
                cursor += height;
            }
            remaining.x += row_width;
            remaining.width -= row_width;
        } else {
            const row_height = remaining.height * fraction;
            var cursor = remaining.x;
            for (items[index..row_end], index..) |item, output_index| {
                const width = if (output_index + 1 == row_end)
                    remaining.x + remaining.width - cursor
                else
                    remaining.width * positiveArea(item.weight) / row_weight;
                output[output_index] = .{ .id = output_index, .x = cursor, .y = remaining.y, .width = width, .height = row_height };
                cursor += width;
            }
            remaining.y += row_height;
            remaining.height -= row_height;
        }
        remaining_weight -= row_weight;
        index = row_end;
    }
}

fn rowWorst(items: []const WeightedItem, row_weight: f64, rect: Rect, remaining_weight: f64) f64 {
    if (items.len == 0 or row_weight <= 0 or remaining_weight <= 0) return std.math.floatMax(f64);
    const horizontal = rect.width >= rect.height;
    const strip = if (horizontal)
        rect.width * row_weight / remaining_weight
    else
        rect.height * row_weight / remaining_weight;
    const cross = if (horizontal) rect.height else rect.width;
    if (strip <= 0 or cross <= 0) return std.math.floatMax(f64);
    var worst: f64 = 1.0;
    for (items) |item| {
        const cross_size = cross * positiveArea(item.weight) / row_weight;
        if (cross_size <= 0) return std.math.floatMax(f64);
        worst = @max(worst, @max(strip / cross_size, cross_size / strip));
    }
    return worst;
}

fn insetRect(rect: Rect, padding: f64) Rect {
    const inset_x = @min(padding, rect.width / 4.0);
    const inset_y = @min(padding, rect.height / 4.0);
    return .{
        .id = rect.id,
        .x = rect.x + inset_x,
        .y = rect.y + inset_y,
        .width = @max(0, rect.width - inset_x * 2.0),
        .height = @max(0, rect.height - inset_y * 2.0),
    };
}

fn heavierItemFirst(_: void, left: WeightedItem, right: WeightedItem) bool {
    if (left.weight == right.weight) return itemId(left.item) < itemId(right.item);
    return left.weight > right.weight;
}

fn itemId(item: Item) usize {
    return switch (item) {
        .node => |id| id * 2,
        .subgraph => |id| id * 2 + 1,
    };
}

fn positiveArea(area: f64) f64 {
    return if (std.math.isFinite(area) and area > 0) area else 1.0;
}
