//! Deterministic connected-component rectangle packing.

const std = @import("std");

const osage = @import("osage.zig");

pub const Mode = enum {
    graph,
    array,
};

pub const Options = struct {
    mode: Mode = .graph,
    margin: f64 = 8,
    array: osage.PackMode = .{},
};

pub fn parseOptions(raw_pack: ?[]const u8, raw_mode: ?[]const u8) ?Options {
    if (raw_pack == null and raw_mode == null) return null;
    if (raw_mode) |value| {
        if (startsWithIgnoreCase(value, "aspect")) return null;
    }

    const margin = if (raw_pack) |value| parseMargin(value) else null;
    const mode = parseMode(raw_mode);
    if (margin == null and mode == null) return null;
    return .{
        .mode = mode orelse .graph,
        .margin = margin orelse 8,
        .array = osage.parsePackMode(raw_mode),
    };
}

pub const Rect = struct {
    id: usize,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    sort_value: ?usize = null,
};

pub const Bounds = struct {
    id: usize,
    min_x: f64 = std.math.floatMax(f64),
    min_y: f64 = std.math.floatMax(f64),
    max_x: f64 = -std.math.floatMax(f64),
    max_y: f64 = -std.math.floatMax(f64),
    sort_value: ?usize = null,

    pub fn includePoint(self: *Bounds, x: f64, y: f64) void {
        self.min_x = @min(self.min_x, x);
        self.min_y = @min(self.min_y, y);
        self.max_x = @max(self.max_x, x);
        self.max_y = @max(self.max_y, y);
    }

    pub fn includeRect(self: *Bounds, x: f64, y: f64, width: f64, height: f64) void {
        if (width <= 0 or height <= 0) return;
        self.includePoint(x, y);
        self.includePoint(x + width, y + height);
    }

    pub fn includeSortValue(self: *Bounds, value: usize) void {
        self.sort_value = if (self.sort_value) |current| @min(current, value) else value;
    }

    pub fn rect(self: Bounds) Rect {
        return .{
            .id = self.id,
            .x = self.min_x,
            .y = self.min_y,
            .width = @max(1.0, self.max_x - self.min_x),
            .height = @max(1.0, self.max_y - self.min_y),
            .sort_value = self.sort_value,
        };
    }
};

pub const DisjointSet = struct {
    allocator: std.mem.Allocator,
    parents: []usize,

    pub fn init(allocator: std.mem.Allocator, count: usize) !DisjointSet {
        const parents = try allocator.alloc(usize, count);
        for (parents, 0..) |*parent, id| parent.* = id;
        return .{ .allocator = allocator, .parents = parents };
    }

    pub fn deinit(self: *DisjointSet) void {
        self.allocator.free(self.parents);
        self.* = undefined;
    }

    pub fn unite(self: *DisjointSet, left: usize, right: usize) void {
        if (left >= self.parents.len or right >= self.parents.len) return;
        const left_root = self.root(left);
        const right_root = self.root(right);
        if (left_root == right_root) return;
        self.parents[@max(left_root, right_root)] = @min(left_root, right_root);
    }

    pub fn labels(self: *const DisjointSet, allocator: std.mem.Allocator, output: []usize) !usize {
        if (output.len < self.parents.len) return error.OutputTooSmall;
        var component_by_root = std.AutoHashMap(usize, usize).init(allocator);
        defer component_by_root.deinit();
        var component_count: usize = 0;
        for (self.parents, 0..) |_, id| {
            const root_id = self.root(id);
            const entry = try component_by_root.getOrPut(root_id);
            if (!entry.found_existing) {
                entry.value_ptr.* = component_count;
                component_count += 1;
            }
            output[id] = entry.value_ptr.*;
        }
        return component_count;
    }

    fn root(self: *const DisjointSet, id: usize) usize {
        var current = id;
        var remaining = self.parents.len + 1;
        while (self.parents[current] != current and remaining > 0) {
            current = self.parents[current];
            remaining -= 1;
        }
        return current;
    }
};

pub const Placement = struct {
    x: f64,
    y: f64,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    placements: []Placement,
    width: f64,
    height: f64,

    pub fn deinit(self: *Result) void {
        self.allocator.free(self.placements);
        self.* = undefined;
    }
};

const Item = struct {
    rect: Rect,
    input_index: usize,
};

pub fn layout(allocator: std.mem.Allocator, input: []const Rect, options: Options) !Result {
    const placements = try allocator.alloc(Placement, input.len);
    errdefer allocator.free(placements);
    @memset(placements, .{ .x = 0, .y = 0 });
    if (input.len == 0) {
        return .{
            .allocator = allocator,
            .placements = placements,
            .width = 0,
            .height = 0,
        };
    }

    const items = try allocator.alloc(Item, input.len);
    defer allocator.free(items);
    for (input, 0..) |rect, index| {
        items[index] = .{
            .rect = .{
                .id = rect.id,
                .x = rect.x,
                .y = rect.y,
                .width = positiveDimension(rect.width),
                .height = positiveDimension(rect.height),
                .sort_value = rect.sort_value,
            },
            .input_index = index,
        };
    }

    const extent = switch (options.mode) {
        .graph => packGraph(items, placements, positiveOrZero(options.margin)),
        .array => try packArray(
            allocator,
            items,
            placements,
            positiveOrZero(options.margin),
            options.array,
        ),
    };
    return .{
        .allocator = allocator,
        .placements = placements,
        .width = extent.width,
        .height = extent.height,
    };
}

const Extent = struct {
    width: f64,
    height: f64,
};

fn packGraph(items: []Item, placements: []Placement, margin: f64) Extent {
    std.mem.sort(Item, items, {}, largerFirst);

    var padded_area: f64 = 0;
    var widest: f64 = 0;
    for (items) |item| {
        const padded_width = item.rect.width + margin;
        const padded_height = item.rect.height + margin;
        padded_area += padded_width * padded_height;
        widest = @max(widest, item.rect.width);
    }
    const target_width = @max(widest, @sqrt(@max(1.0, padded_area)));

    var cursor_x: f64 = 0;
    var cursor_y: f64 = 0;
    var row_height: f64 = 0;
    var width: f64 = 0;
    for (items) |item| {
        if (cursor_x > 0 and cursor_x + item.rect.width > target_width) {
            cursor_x = 0;
            cursor_y += row_height + margin;
            row_height = 0;
        }
        placements[item.input_index] = .{ .x = cursor_x, .y = cursor_y };
        cursor_x += item.rect.width + margin;
        row_height = @max(row_height, item.rect.height);
        width = @max(width, cursor_x - margin);
    }
    return .{
        .width = width,
        .height = cursor_y + row_height,
    };
}

fn packArray(
    allocator: std.mem.Allocator,
    items: []Item,
    placements: []Placement,
    margin: f64,
    mode: osage.PackMode,
) !Extent {
    switch (mode.order) {
        .input => {},
        .size_descending => std.mem.sort(Item, items, {}, largerFirst),
        .sort_value => std.mem.sort(Item, items, {}, lowerSortValueFirst),
    }

    const grid = gridSize(items.len, mode);
    const column_widths = try allocator.alloc(f64, grid.columns);
    defer allocator.free(column_widths);
    @memset(column_widths, 0);
    const row_heights = try allocator.alloc(f64, grid.rows);
    defer allocator.free(row_heights);
    @memset(row_heights, 0);

    for (items, 0..) |item, index| {
        const cell = gridCell(index, grid, mode.major);
        column_widths[cell.column] = @max(column_widths[cell.column], item.rect.width);
        row_heights[cell.row] = @max(row_heights[cell.row], item.rect.height);
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

    for (items, 0..) |item, index| {
        const cell = gridCell(index, grid, mode.major);
        const free_x = column_widths[cell.column] - item.rect.width;
        const free_y = row_heights[cell.row] - item.rect.height;
        placements[item.input_index] = .{
            .x = column_offsets[cell.column] + switch (mode.horizontal_alignment) {
                .left => 0,
                .center => free_x / 2.0,
                .right => free_x,
            },
            .y = row_offsets[cell.row] + switch (mode.vertical_alignment) {
                .top => 0,
                .center => free_y / 2.0,
                .bottom => free_y,
            },
        };
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

fn gridSize(item_count: usize, mode: osage.PackMode) Grid {
    if (mode.major == .column) {
        const rows = if (mode.count > 0) mode.count else ceilSqrt(item_count);
        const bounded_rows = @min(@max(rows, 1), item_count);
        return .{
            .rows = bounded_rows,
            .columns = ceilDiv(item_count, bounded_rows),
        };
    }
    const columns = if (mode.count > 0) mode.count else ceilSqrt(item_count);
    const bounded_columns = @min(@max(columns, 1), item_count);
    return .{
        .rows = ceilDiv(item_count, bounded_columns),
        .columns = bounded_columns,
    };
}

fn gridCell(index: usize, grid: Grid, major: osage.MajorOrder) Cell {
    return switch (major) {
        .row => .{ .row = index / grid.columns, .column = index % grid.columns },
        .column => .{ .row = index % grid.rows, .column = index / grid.rows },
    };
}

fn largerFirst(_: void, left: Item, right: Item) bool {
    const left_extent = left.rect.width + left.rect.height;
    const right_extent = right.rect.width + right.rect.height;
    if (left_extent == right_extent) return left.rect.id < right.rect.id;
    return left_extent > right_extent;
}

fn lowerSortValueFirst(_: void, left: Item, right: Item) bool {
    const left_value = left.rect.sort_value orelse 0;
    const right_value = right.rect.sort_value orelse 0;
    if (left_value == right_value) return left.rect.id < right.rect.id;
    return left_value < right_value;
}

fn positiveDimension(value: f64) f64 {
    return if (std.math.isFinite(value) and value > 0) value else 1;
}

fn positiveOrZero(value: f64) f64 {
    return if (std.math.isFinite(value) and value > 0) value else 0;
}

fn parseMargin(value: []const u8) ?f64 {
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    if (trimmed.len == 0) return null;
    var end: usize = 0;
    if (trimmed[0] == '+' or trimmed[0] == '-') end = 1;
    const digit_start = end;
    while (end < trimmed.len and std.ascii.isDigit(trimmed[end])) : (end += 1) {}
    if (end > digit_start) {
        const parsed = std.fmt.parseInt(i64, trimmed[0..end], 10) catch return null;
        return if (parsed >= 0) @floatFromInt(parsed) else null;
    }
    return if (trimmed[0] == 't' or trimmed[0] == 'T') 8 else null;
}

fn parseMode(value: ?[]const u8) ?Mode {
    const text = value orelse return null;
    if (startsWithIgnoreCase(text, "array")) return .array;
    if (std.ascii.eqlIgnoreCase(text, "graph") or
        std.ascii.eqlIgnoreCase(text, "node") or
        std.ascii.eqlIgnoreCase(text, "cluster"))
    {
        return .graph;
    }
    return null;
}

fn startsWithIgnoreCase(value: []const u8, prefix: []const u8) bool {
    return value.len >= prefix.len and std.ascii.eqlIgnoreCase(value[0..prefix.len], prefix);
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

fn rectanglesOverlap(left: Rect, left_place: Placement, right: Rect, right_place: Placement) bool {
    return left_place.x < right_place.x + right.width and
        left_place.x + left.width > right_place.x and
        left_place.y < right_place.y + right.height and
        left_place.y + left.height > right_place.y;
}

test "graph mode balances differently sized component rectangles" {
    const allocator = std.testing.allocator;
    const rects = [_]Rect{
        .{ .id = 0, .x = 10, .y = 20, .width = 180, .height = 80 },
        .{ .id = 1, .x = 0, .y = 0, .width = 70, .height = 150 },
        .{ .id = 2, .x = 0, .y = 0, .width = 90, .height = 60 },
        .{ .id = 3, .x = 0, .y = 0, .width = 40, .height = 40 },
    };
    var result = try layout(allocator, &rects, .{ .margin = 12 });
    defer result.deinit();

    try std.testing.expect(result.width > 0);
    try std.testing.expect(result.height > 0);
    for (rects, 0..) |left, left_index| {
        for (rects[left_index + 1 ..], left_index + 1..) |right, right_index| {
            try std.testing.expect(!rectanglesOverlap(
                left,
                result.placements[left_index],
                right,
                result.placements[right_index],
            ));
        }
    }
}

test "array mode honors input order and explicit columns" {
    const allocator = std.testing.allocator;
    const rects = [_]Rect{
        .{ .id = 0, .x = 0, .y = 0, .width = 40, .height = 20 },
        .{ .id = 1, .x = 0, .y = 0, .width = 70, .height = 30 },
        .{ .id = 2, .x = 0, .y = 0, .width = 30, .height = 50 },
    };
    var result = try layout(allocator, &rects, .{
        .mode = .array,
        .margin = 10,
        .array = osage.parsePackMode("array_i2"),
    });
    defer result.deinit();

    try std.testing.expect(result.placements[0].x < result.placements[1].x);
    try std.testing.expect(result.placements[2].y > result.placements[0].y);
    try std.testing.expectApproxEqAbs(@as(f64, 120), result.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 90), result.height, 0.001);
}

test "Graphviz pack options parse numeric margins and implicit enable" {
    const numeric = parseOptions("24suffix", null).?;
    try std.testing.expectEqual(Mode.graph, numeric.mode);
    try std.testing.expectEqual(@as(f64, 24), numeric.margin);

    const automatic = parseOptions(null, "array_ci3").?;
    try std.testing.expectEqual(Mode.array, automatic.mode);
    try std.testing.expectEqual(@as(f64, 8), automatic.margin);
    try std.testing.expectEqual(@as(usize, 3), automatic.array.count);
    try std.testing.expect(parseOptions("false", null) == null);
    try std.testing.expect(parseOptions(null, "bogus") == null);
    try std.testing.expect(parseOptions(null, "aspect2") == null);
    try std.testing.expectEqual(Mode.graph, parseOptions(null, "cluster").?.mode);
    try std.testing.expectEqual(Mode.graph, parseOptions("true", "bogus").?.mode);
    try std.testing.expect(parseOptions("true", "aspect2") == null);
}

test "disjoint set labels deterministic connected components" {
    const allocator = std.testing.allocator;
    var set = try DisjointSet.init(allocator, 5);
    defer set.deinit();
    set.unite(3, 4);
    set.unite(0, 1);
    set.unite(1, 2);
    var labels: [5]usize = undefined;
    try std.testing.expectEqual(@as(usize, 2), try set.labels(allocator, &labels));
    try std.testing.expectEqualSlices(usize, &.{ 0, 0, 0, 1, 1 }, &labels);
}
