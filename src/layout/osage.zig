//! Hierarchical array packing for the osage layout engine.

const std = @import("std");
const Rect = @import("result.zig").SubgraphLayout;

pub const MajorOrder = enum {
    row,
    column,
};

pub const ItemOrder = enum {
    size_descending,
    input,
    sort_value,
};

pub const HorizontalAlignment = enum {
    center,
    left,
    right,
};

pub const VerticalAlignment = enum {
    center,
    top,
    bottom,
};

pub const PackMode = struct {
    major: MajorOrder = .row,
    order: ItemOrder = .size_descending,
    horizontal_alignment: HorizontalAlignment = .center,
    vertical_alignment: VerticalAlignment = .center,
    count: usize = 0,
};

pub const ScopeOptions = struct {
    pack_mode: PackMode = .{},
    pack_margin: f64 = 4,
    padding: f64 = 8,
    label_height: f64 = 0,
    minimum_width: f64 = 0,
};

pub const Node = struct {
    width: f64,
    height: f64,
    parent: ?usize,
    sort_value: ?usize = null,
};

pub const Subgraph = struct {
    parent: ?usize,
    sort_value: ?usize = null,
    options: ScopeOptions = .{},
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    node_rects: []Rect,
    subgraph_rects: []Rect,
    width: f64,
    height: f64,

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

const PackItem = struct {
    item: Item,
    width: f64,
    height: f64,
    sort_value: ?usize,
    input_index: usize,
};

const Extent = struct {
    width: f64,
    height: f64,
};

const SubgraphState = enum {
    pending,
    active,
    complete,
};

pub fn parsePackMode(value: ?[]const u8) PackMode {
    const text = value orelse return .{};
    if (!startsWithIgnoreCase(text, "array")) return .{};

    var result = PackMode{};
    var index: usize = "array".len;
    var column_major = false;
    var input_order = false;
    var user_order = false;
    var top_align = false;
    var bottom_align = false;
    var left_align = false;
    var right_align = false;
    if (index < text.len and text[index] == '_') {
        index += 1;
        while (index < text.len) : (index += 1) {
            switch (std.ascii.toLower(text[index])) {
                'c' => column_major = true,
                'i' => input_order = true,
                'u' => user_order = true,
                't' => top_align = true,
                'b' => bottom_align = true,
                'l' => left_align = true,
                'r' => right_align = true,
                else => break,
            }
        }
    }
    result.major = if (column_major) .column else .row;
    result.order = if (user_order) .sort_value else if (input_order) .input else .size_descending;
    result.horizontal_alignment = if (left_align) .left else if (right_align) .right else .center;
    result.vertical_alignment = if (top_align) .top else if (bottom_align) .bottom else .center;
    const count_start = index;
    while (index < text.len and std.ascii.isDigit(text[index])) : (index += 1) {}
    if (index > count_start) {
        result.count = std.fmt.parseInt(usize, text[count_start..index], 10) catch 0;
    }
    return result;
}

pub fn layout(
    allocator: std.mem.Allocator,
    nodes: []const Node,
    subgraphs: []const Subgraph,
    root_options: ScopeOptions,
) !Result {
    const node_rects = try allocator.alloc(Rect, nodes.len);
    errdefer allocator.free(node_rects);
    for (node_rects, 0..) |*rect, id| {
        rect.* = .{ .id = id, .x = 0, .y = 0, .width = 0, .height = 0 };
    }
    const subgraph_rects = try allocator.alloc(Rect, subgraphs.len);
    errdefer allocator.free(subgraph_rects);
    for (subgraph_rects, 0..) |*rect, id| {
        rect.* = .{ .id = id, .x = 0, .y = 0, .width = 0, .height = 0 };
    }

    const states = try allocator.alloc(SubgraphState, subgraphs.len);
    defer allocator.free(states);
    @memset(states, .pending);
    for (subgraphs, 0..) |subgraph, id| {
        if (subgraph.parent == null) {
            _ = try layoutSubgraph(allocator, id, nodes, subgraphs, states, node_rects, subgraph_rects);
        }
    }
    for (states, 0..) |state, id| {
        if (state == .pending) {
            _ = try layoutSubgraph(allocator, id, nodes, subgraphs, states, node_rects, subgraph_rects);
        }
    }

    const root_extent = try layoutScope(
        allocator,
        null,
        root_options,
        nodes,
        subgraphs,
        node_rects,
        subgraph_rects,
    );
    for (subgraphs, 0..) |subgraph, id| {
        if (subgraph.parent == null) makeSubgraphAbsolute(id, subgraphs, subgraph_rects);
    }
    for (nodes, 0..) |node, id| {
        if (node.parent) |parent| {
            if (parent < subgraph_rects.len) {
                node_rects[id].x += subgraph_rects[parent].x;
                node_rects[id].y += subgraph_rects[parent].y;
            }
        }
    }

    return .{
        .allocator = allocator,
        .node_rects = node_rects,
        .subgraph_rects = subgraph_rects,
        .width = root_extent.width,
        .height = root_extent.height,
    };
}

fn layoutSubgraph(
    allocator: std.mem.Allocator,
    id: usize,
    nodes: []const Node,
    subgraphs: []const Subgraph,
    states: []SubgraphState,
    node_rects: []Rect,
    subgraph_rects: []Rect,
) !Extent {
    if (id >= subgraphs.len) return .{ .width = 0, .height = 0 };
    switch (states[id]) {
        .complete => return .{
            .width = subgraph_rects[id].width,
            .height = subgraph_rects[id].height,
        },
        .active => return error.SubgraphCycle,
        .pending => states[id] = .active,
    }
    errdefer states[id] = .pending;

    for (subgraphs, 0..) |child, child_id| {
        if (child.parent == id) {
            _ = try layoutSubgraph(
                allocator,
                child_id,
                nodes,
                subgraphs,
                states,
                node_rects,
                subgraph_rects,
            );
        }
    }
    const extent = try layoutScope(
        allocator,
        id,
        subgraphs[id].options,
        nodes,
        subgraphs,
        node_rects,
        subgraph_rects,
    );
    subgraph_rects[id].width = extent.width;
    subgraph_rects[id].height = extent.height;
    states[id] = .complete;
    return extent;
}

fn layoutScope(
    allocator: std.mem.Allocator,
    parent: ?usize,
    options: ScopeOptions,
    nodes: []const Node,
    subgraphs: []const Subgraph,
    node_rects: []Rect,
    subgraph_rects: []Rect,
) !Extent {
    var items = std.ArrayList(PackItem).empty;
    defer items.deinit(allocator);
    var input_index: usize = 0;
    for (subgraphs, 0..) |subgraph, id| {
        if (subgraph.parent != parent) continue;
        try items.append(allocator, .{
            .item = .{ .subgraph = id },
            .width = positiveDimension(subgraph_rects[id].width),
            .height = positiveDimension(subgraph_rects[id].height),
            .sort_value = subgraph.sort_value,
            .input_index = input_index,
        });
        input_index += 1;
    }
    for (nodes, 0..) |node, id| {
        if (node.parent != parent) continue;
        try items.append(allocator, .{
            .item = .{ .node = id },
            .width = positiveDimension(node.width),
            .height = positiveDimension(node.height),
            .sort_value = node.sort_value,
            .input_index = input_index,
        });
        input_index += 1;
    }

    const padding = positiveOrZero(options.padding);
    const label_height = positiveOrZero(options.label_height);
    const inner = try packItems(
        allocator,
        items.items,
        options.pack_mode,
        positiveOrZero(options.pack_margin),
        padding,
        padding + label_height,
        node_rects,
        subgraph_rects,
    );
    const content_width = inner.width + padding * 2.0;
    const width = @max(@max(1.0, content_width), positiveOrZero(options.minimum_width));
    if (width > content_width) {
        shiftScopeItems(parent, (width - content_width) / 2.0, nodes, subgraphs, node_rects, subgraph_rects);
    }
    return .{
        .width = width,
        .height = @max(1.0, inner.height + padding * 2.0 + label_height),
    };
}

fn shiftScopeItems(
    parent: ?usize,
    offset_x: f64,
    nodes: []const Node,
    subgraphs: []const Subgraph,
    node_rects: []Rect,
    subgraph_rects: []Rect,
) void {
    for (subgraphs, 0..) |subgraph, id| {
        if (subgraph.parent == parent) subgraph_rects[id].x += offset_x;
    }
    for (nodes, 0..) |node, id| {
        if (node.parent == parent) node_rects[id].x += offset_x;
    }
}

fn packItems(
    allocator: std.mem.Allocator,
    input: []const PackItem,
    mode: PackMode,
    margin: f64,
    offset_x: f64,
    offset_y: f64,
    node_rects: []Rect,
    subgraph_rects: []Rect,
) !Extent {
    if (input.len == 0) return .{ .width = 0, .height = 0 };
    const items = try allocator.dupe(PackItem, input);
    defer allocator.free(items);
    switch (mode.order) {
        .input => {},
        .size_descending => std.mem.sort(PackItem, items, {}, largerFirst),
        .sort_value => std.mem.sort(PackItem, items, {}, lowerSortValueFirst),
    }

    const grid = gridSize(items.len, mode);
    const column_widths = try allocator.alloc(f64, grid.columns);
    defer allocator.free(column_widths);
    @memset(column_widths, 0);
    const row_heights = try allocator.alloc(f64, grid.rows);
    defer allocator.free(row_heights);
    @memset(row_heights, 0);

    for (items, 0..) |item, packed_index| {
        const cell = gridCell(packed_index, grid, mode.major);
        column_widths[cell.column] = @max(column_widths[cell.column], item.width);
        row_heights[cell.row] = @max(row_heights[cell.row], item.height);
    }
    const column_offsets = try allocator.alloc(f64, grid.columns);
    defer allocator.free(column_offsets);
    const row_offsets = try allocator.alloc(f64, grid.rows);
    defer allocator.free(row_offsets);
    var width: f64 = 0;
    for (column_widths, 0..) |column_width, column| {
        column_offsets[column] = width;
        width += column_width;
        if (column + 1 < grid.columns) width += margin;
    }
    var height: f64 = 0;
    for (row_heights, 0..) |row_height, row| {
        row_offsets[row] = height;
        height += row_height;
        if (row + 1 < grid.rows) height += margin;
    }

    for (items, 0..) |item, packed_index| {
        const cell = gridCell(packed_index, grid, mode.major);
        const free_x = column_widths[cell.column] - item.width;
        const free_y = row_heights[cell.row] - item.height;
        const x = offset_x + column_offsets[cell.column] + switch (mode.horizontal_alignment) {
            .left => 0,
            .center => free_x / 2.0,
            .right => free_x,
        };
        const y = offset_y + row_offsets[cell.row] + switch (mode.vertical_alignment) {
            .top => 0,
            .center => free_y / 2.0,
            .bottom => free_y,
        };
        switch (item.item) {
            .node => |id| node_rects[id] = .{
                .id = id,
                .x = x,
                .y = y,
                .width = item.width,
                .height = item.height,
            },
            .subgraph => |id| {
                subgraph_rects[id].x = x;
                subgraph_rects[id].y = y;
            },
        }
    }
    return .{ .width = width, .height = height };
}

const Grid = struct {
    rows: usize,
    columns: usize,
};

const Cell = struct {
    row: usize,
    column: usize,
};

fn gridSize(item_count: usize, mode: PackMode) Grid {
    if (mode.major == .column) {
        const rows = if (mode.count > 0) mode.count else ceilSqrt(item_count);
        return .{
            .rows = @min(@max(rows, 1), item_count),
            .columns = ceilDiv(item_count, @min(@max(rows, 1), item_count)),
        };
    }
    const columns = if (mode.count > 0) mode.count else ceilSqrt(item_count);
    return .{
        .rows = ceilDiv(item_count, @min(@max(columns, 1), item_count)),
        .columns = @min(@max(columns, 1), item_count),
    };
}

fn gridCell(index: usize, grid: Grid, major: MajorOrder) Cell {
    return switch (major) {
        .row => .{ .row = index / grid.columns, .column = index % grid.columns },
        .column => .{ .row = index % grid.rows, .column = index / grid.rows },
    };
}

fn makeSubgraphAbsolute(id: usize, subgraphs: []const Subgraph, rects: []Rect) void {
    if (id >= rects.len) return;
    for (subgraphs, 0..) |subgraph, child_id| {
        if (subgraph.parent != id) continue;
        rects[child_id].x += rects[id].x;
        rects[child_id].y += rects[id].y;
        makeSubgraphAbsolute(child_id, subgraphs, rects);
    }
}

fn largerFirst(_: void, left: PackItem, right: PackItem) bool {
    const left_extent = left.width + left.height;
    const right_extent = right.width + right.height;
    if (left_extent == right_extent) return left.input_index < right.input_index;
    return left_extent > right_extent;
}

fn lowerSortValueFirst(_: void, left: PackItem, right: PackItem) bool {
    const left_value = left.sort_value orelse 0;
    const right_value = right.sort_value orelse 0;
    if (left_value == right_value) return left.input_index < right.input_index;
    return left_value < right_value;
}

fn startsWithIgnoreCase(value: []const u8, prefix: []const u8) bool {
    return value.len >= prefix.len and std.ascii.eqlIgnoreCase(value[0..prefix.len], prefix);
}

fn positiveDimension(value: f64) f64 {
    return if (std.math.isFinite(value) and value > 0) value else 1.0;
}

fn positiveOrZero(value: f64) f64 {
    return if (std.math.isFinite(value) and value > 0) value else 0;
}

fn ceilDiv(numerator: usize, denominator: usize) usize {
    return numerator / denominator + @intFromBool(numerator % denominator != 0);
}

fn ceilSqrt(value: usize) usize {
    if (value <= 1) return value;
    var root: usize = 1;
    while (root <= value / root) : (root += 1) {
        if (root * root == value) return root;
    }
    return root;
}

test "parsePackMode supports Graphviz array flags" {
    const row = parsePackMode("array_i3");
    try std.testing.expectEqual(MajorOrder.row, row.major);
    try std.testing.expectEqual(ItemOrder.input, row.order);
    try std.testing.expectEqual(@as(usize, 3), row.count);

    const column = parsePackMode("array_cur2");
    try std.testing.expectEqual(MajorOrder.column, column.major);
    try std.testing.expectEqual(ItemOrder.sort_value, column.order);
    try std.testing.expectEqual(HorizontalAlignment.right, column.horizontal_alignment);
    try std.testing.expectEqual(@as(usize, 2), column.count);

    const precedence = parsePackMode("array_uirlbt4suffix");
    try std.testing.expectEqual(ItemOrder.sort_value, precedence.order);
    try std.testing.expectEqual(HorizontalAlignment.left, precedence.horizontal_alignment);
    try std.testing.expectEqual(VerticalAlignment.top, precedence.vertical_alignment);
    try std.testing.expectEqual(@as(usize, 4), precedence.count);
}

test "row-major input order honors fixed column count and margin" {
    const allocator = std.testing.allocator;
    const nodes = [_]Node{
        .{ .width = 20, .height = 10, .parent = null },
        .{ .width = 30, .height = 20, .parent = null },
        .{ .width = 10, .height = 10, .parent = null },
    };
    var result = try layout(allocator, &nodes, &.{}, .{
        .pack_mode = parsePackMode("array_i2"),
        .pack_margin = 5,
        .padding = 0,
    });
    defer result.deinit();

    try std.testing.expectApproxEqAbs(@as(f64, 0), result.node_rects[0].x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 25), result.node_rects[1].x, 0.001);
    try std.testing.expect(result.node_rects[2].y >= 25);
    try std.testing.expectApproxEqAbs(@as(f64, 55), result.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 35), result.height, 0.001);
}

test "sort values determine osage array order" {
    const allocator = std.testing.allocator;
    const nodes = [_]Node{
        .{ .width = 10, .height = 10, .parent = null, .sort_value = 20 },
        .{ .width = 10, .height = 10, .parent = null, .sort_value = 10 },
        .{ .width = 10, .height = 10, .parent = null, .sort_value = 30 },
    };
    var result = try layout(allocator, &nodes, &.{}, .{
        .pack_mode = parsePackMode("array_u3"),
        .pack_margin = 2,
        .padding = 0,
    });
    defer result.deinit();

    try std.testing.expect(result.node_rects[1].x < result.node_rects[0].x);
    try std.testing.expect(result.node_rects[0].x < result.node_rects[2].x);
}

test "array alignment flags place rectangles on cell edges" {
    const allocator = std.testing.allocator;
    const nodes = [_]Node{
        .{ .width = 30, .height = 20, .parent = null },
        .{ .width = 10, .height = 10, .parent = null },
        .{ .width = 10, .height = 10, .parent = null },
        .{ .width = 10, .height = 10, .parent = null },
    };
    var top_left = try layout(allocator, &nodes, &.{}, .{
        .pack_mode = parsePackMode("array_ilt2"),
        .pack_margin = 0,
        .padding = 0,
    });
    defer top_left.deinit();
    var bottom_right = try layout(allocator, &nodes, &.{}, .{
        .pack_mode = parsePackMode("array_irb2"),
        .pack_margin = 0,
        .padding = 0,
    });
    defer bottom_right.deinit();

    try std.testing.expectApproxEqAbs(@as(f64, 0), top_left.node_rects[2].x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 20), bottom_right.node_rects[2].x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0), top_left.node_rects[1].y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 10), bottom_right.node_rects[1].y, 0.001);
}

test "nested osage subgraphs contain descendants" {
    const allocator = std.testing.allocator;
    const nodes = [_]Node{
        .{ .width = 24, .height = 16, .parent = 1 },
        .{ .width = 32, .height = 20, .parent = 0 },
        .{ .width = 18, .height = 18, .parent = null },
    };
    const subgraphs = [_]Subgraph{
        .{ .parent = null, .options = .{ .padding = 7, .label_height = 12 } },
        .{ .parent = 0, .options = .{ .padding = 5, .label_height = 10 } },
    };
    var result = try layout(allocator, &nodes, &subgraphs, .{
        .pack_mode = parsePackMode("array_i2"),
        .padding = 0,
    });
    defer result.deinit();

    try expectContains(result.subgraph_rects[0], result.subgraph_rects[1]);
    try expectContains(result.subgraph_rects[1], result.node_rects[0]);
    try expectContains(result.subgraph_rects[0], result.node_rects[1]);
}

fn expectContains(outer: Rect, inner: Rect) !void {
    try std.testing.expect(inner.x >= outer.x);
    try std.testing.expect(inner.y >= outer.y);
    try std.testing.expect(inner.x + inner.width <= outer.x + outer.width);
    try std.testing.expect(inner.y + inner.height <= outer.y + outer.height);
}
