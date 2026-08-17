//! Deterministic connected-component rectangle packing.

const std = @import("std");

const osage = @import("osage.zig");

pub const maxPolyominoComponents: usize = 128;
pub const maxPolyominoPrimitives: usize = 16_384;

pub const Mode = enum {
    graph,
    node,
    cluster,
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

pub const GeometryRect = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const Segment = struct {
    start: Point,
    end: Point,
};

pub const Component = struct {
    bounds: Rect,
    rectangles: []const GeometryRect = &.{},
    segments: []const Segment = &.{},
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
    const components = try allocator.alloc(Component, input.len);
    defer allocator.free(components);
    for (input, 0..) |rect, index| {
        components[index] = .{ .bounds = rect };
    }
    return layoutComponents(allocator, components, options);
}

pub fn layoutComponents(
    allocator: std.mem.Allocator,
    input: []const Component,
    options: Options,
) !Result {
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
    for (input, 0..) |component, index| {
        const rect = component.bounds;
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
        .node, .cluster => return packPolyominoes(
            allocator,
            input,
            placements,
            positiveOrZero(options.margin),
        ),
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

const Cell = struct {
    x: i64,
    y: i64,
};

const Polyomino = struct {
    allocator: std.mem.Allocator,
    cells: []Cell,
    perimeter: usize,
    input_index: usize,

    fn deinit(self: *Polyomino) void {
        self.allocator.free(self.cells);
        self.* = undefined;
    }
};

fn packPolyominoes(
    allocator: std.mem.Allocator,
    input: []const Component,
    placements: []Placement,
    margin: f64,
) !Result {
    if (!polyominoBudgetAllows(input)) {
        const extent = try packComponentsAsGraph(
            allocator,
            input,
            placements,
            margin,
        );
        return .{
            .allocator = allocator,
            .placements = placements,
            .width = extent.width,
            .height = extent.height,
        };
    }
    const step = computeGridStep(input, margin);
    const polyominoes = try allocator.alloc(Polyomino, input.len);
    defer allocator.free(polyominoes);
    var initialized: usize = 0;
    defer for (polyominoes[0..initialized]) |*polyomino| polyomino.deinit();
    for (input, 0..) |component, index| {
        polyominoes[index] = try buildPolyomino(allocator, component, step, margin, index);
        initialized += 1;
    }
    std.mem.sort(Polyomino, polyominoes, {}, largerPolyominoFirst);

    var occupied = std.AutoHashMap(Cell, void).init(allocator);
    defer occupied.deinit();
    for (polyominoes, 0..) |polyomino, packed_index| {
        const offset = try findPlacement(&occupied, polyomino, packed_index, step, input);
        placements[polyomino.input_index] = .{
            .x = @as(f64, @floatFromInt(offset.x)) * step,
            .y = @as(f64, @floatFromInt(offset.y)) * step,
        };
    }

    var min_x = std.math.floatMax(f64);
    var min_y = std.math.floatMax(f64);
    var max_x = -std.math.floatMax(f64);
    var max_y = -std.math.floatMax(f64);
    for (input, 0..) |component, index| {
        const placement = placements[index];
        min_x = @min(min_x, placement.x);
        min_y = @min(min_y, placement.y);
        max_x = @max(max_x, placement.x + component.bounds.width);
        max_y = @max(max_y, placement.y + component.bounds.height);
    }
    for (placements) |*placement| {
        placement.x -= min_x;
        placement.y -= min_y;
    }
    const polyomino_extent = Extent{
        .width = max_x - min_x,
        .height = max_y - min_y,
    };
    const rectangular_placements = try allocator.alloc(Placement, input.len);
    defer allocator.free(rectangular_placements);
    const rectangular_extent = try packComponentsAsGraph(
        allocator,
        input,
        rectangular_placements,
        margin,
    );
    if (extentArea(rectangular_extent) + 0.001 < extentArea(polyomino_extent)) {
        @memcpy(placements, rectangular_placements);
        return .{
            .allocator = allocator,
            .placements = placements,
            .width = rectangular_extent.width,
            .height = rectangular_extent.height,
        };
    }
    return .{
        .allocator = allocator,
        .placements = placements,
        .width = polyomino_extent.width,
        .height = polyomino_extent.height,
    };
}

fn polyominoBudgetAllows(input: []const Component) bool {
    if (input.len > maxPolyominoComponents) return false;
    var primitive_count: usize = 0;
    for (input) |component| {
        const component_primitives = if (component.rectangles.len == 0 and
            component.segments.len == 0)
            1
        else
            component.rectangles.len +| component.segments.len;
        primitive_count +|= component_primitives;
        if (primitive_count > maxPolyominoPrimitives) return false;
    }
    return true;
}

fn packComponentsAsGraph(
    allocator: std.mem.Allocator,
    input: []const Component,
    placements: []Placement,
    margin: f64,
) !Extent {
    const items = try allocator.alloc(Item, input.len);
    defer allocator.free(items);
    for (input, 0..) |component, index| {
        items[index] = .{
            .rect = component.bounds,
            .input_index = index,
        };
    }
    return packGraph(items, placements, margin);
}

fn extentArea(extent: Extent) f64 {
    return @max(0.0, extent.width) * @max(0.0, extent.height);
}

fn computeGridStep(input: []const Component, margin: f64) f64 {
    if (input.len == 0) return 1;
    const component_count = @as(f64, @floatFromInt(input.len));
    const coefficient_a = 100.0 * component_count - 1.0;
    var coefficient_b: f64 = 0;
    var coefficient_c: f64 = 0;
    for (input) |component| {
        const width = positiveDimension(component.bounds.width) + margin * 2.0;
        const height = positiveDimension(component.bounds.height) + margin * 2.0;
        coefficient_b -= width + height;
        coefficient_c -= width * height;
    }
    const discriminant = @max(
        0.0,
        coefficient_b * coefficient_b -
            4.0 * coefficient_a * coefficient_c,
    );
    const root = (-coefficient_b + @sqrt(discriminant)) / (2.0 * coefficient_a);
    if (!std.math.isFinite(root) or root < 1.0) return 1;
    return @floor(root);
}

fn buildPolyomino(
    allocator: std.mem.Allocator,
    component: Component,
    step: f64,
    margin: f64,
    input_index: usize,
) !Polyomino {
    var cells = std.AutoHashMap(Cell, void).init(allocator);
    defer cells.deinit();
    if (component.rectangles.len == 0 and component.segments.len == 0) {
        try addRectCells(
            &cells,
            .{
                .x = component.bounds.x,
                .y = component.bounds.y,
                .width = component.bounds.width,
                .height = component.bounds.height,
            },
            component.bounds,
            step,
            margin,
        );
    } else {
        for (component.rectangles) |rect| {
            try addRectCells(&cells, rect, component.bounds, step, margin);
        }
        for (component.segments) |segment| {
            try addSegmentCells(&cells, segment, component.bounds, step);
        }
    }
    const owned_cells = try allocator.alloc(Cell, cells.count());
    var iterator = cells.keyIterator();
    var index: usize = 0;
    while (iterator.next()) |cell| : (index += 1) owned_cells[index] = cell.*;
    std.mem.sort(Cell, owned_cells, {}, cellLessThan);
    const width_cells = gridCellCount(component.bounds.width + margin * 2.0, step);
    const height_cells = gridCellCount(component.bounds.height + margin * 2.0, step);
    return .{
        .allocator = allocator,
        .cells = owned_cells,
        .perimeter = width_cells + height_cells,
        .input_index = input_index,
    };
}

fn addRectCells(
    cells: *std.AutoHashMap(Cell, void),
    rect: GeometryRect,
    bounds: Rect,
    step: f64,
    margin: f64,
) !void {
    if (rect.width <= 0 or rect.height <= 0) return;
    const min_x = cellCoordinate(rect.x - bounds.x - margin, step);
    const min_y = cellCoordinate(rect.y - bounds.y - margin, step);
    const max_x = cellCoordinate(rect.x - bounds.x + rect.width + margin, step);
    const max_y = cellCoordinate(rect.y - bounds.y + rect.height + margin, step);
    var x = min_x;
    while (x <= max_x) : (x += 1) {
        var y = min_y;
        while (y <= max_y) : (y += 1) {
            try cells.put(.{ .x = x, .y = y }, {});
        }
    }
}

fn addSegmentCells(
    cells: *std.AutoHashMap(Cell, void),
    segment: Segment,
    bounds: Rect,
    step: f64,
) !void {
    const start = Cell{
        .x = cellCoordinate(segment.start.x - bounds.x, step),
        .y = cellCoordinate(segment.start.y - bounds.y, step),
    };
    const end = Cell{
        .x = cellCoordinate(segment.end.x - bounds.x, step),
        .y = cellCoordinate(segment.end.y - bounds.y, step),
    };
    var x = start.x;
    var y = start.y;
    const delta_x = if (end.x >= start.x) end.x - start.x else start.x - end.x;
    const delta_y = -(if (end.y >= start.y) end.y - start.y else start.y - end.y);
    const step_x: i64 = if (start.x < end.x) 1 else -1;
    const step_y: i64 = if (start.y < end.y) 1 else -1;
    var error_value = delta_x + delta_y;
    while (true) {
        try cells.put(.{ .x = x, .y = y }, {});
        if (x == end.x and y == end.y) break;
        const doubled = error_value * 2;
        if (doubled >= delta_y) {
            error_value += delta_y;
            x += step_x;
        }
        if (doubled <= delta_x) {
            error_value += delta_x;
            y += step_y;
        }
    }
}

fn findPlacement(
    occupied: *std.AutoHashMap(Cell, void),
    polyomino: Polyomino,
    packed_index: usize,
    step: f64,
    input: []const Component,
) !Cell {
    if (packed_index == 0) {
        const bounds = input[polyomino.input_index].bounds;
        const width = @as(i64, @intCast(gridCellCount(bounds.width, step)));
        const height = @as(i64, @intCast(gridCellCount(bounds.height, step)));
        const centered = Cell{ .x = @divTrunc(-width, 2), .y = @divTrunc(-height, 2) };
        if (try placeIfFits(occupied, polyomino, centered)) return centered;
    }
    if (try placeIfFits(occupied, polyomino, .{ .x = 0, .y = 0 })) {
        return .{ .x = 0, .y = 0 };
    }

    const bounds = input[polyomino.input_index].bounds;
    const wide = bounds.width >= bounds.height;
    var radius: i64 = 1;
    while (true) : (radius += 1) {
        if (wide) {
            var x: i64 = 0;
            var y: i64 = -radius;
            while (x < radius) : (x += 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
            while (y < radius) : (y += 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
            while (x > -radius) : (x -= 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
            while (y > -radius) : (y -= 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
            while (x < 0) : (x += 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
        } else {
            var y: i64 = 0;
            var x: i64 = -radius;
            while (y > -radius) : (y -= 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
            while (x < radius) : (x += 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
            while (y < radius) : (y += 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
            while (x > -radius) : (x -= 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
            while (y > 0) : (y -= 1) {
                const offset = Cell{ .x = x, .y = y };
                if (try placeIfFits(occupied, polyomino, offset)) return offset;
            }
        }
    }
}

fn placeIfFits(
    occupied: *std.AutoHashMap(Cell, void),
    polyomino: Polyomino,
    offset: Cell,
) !bool {
    for (polyomino.cells) |cell| {
        if (occupied.contains(.{
            .x = cell.x + offset.x,
            .y = cell.y + offset.y,
        })) return false;
    }
    for (polyomino.cells) |cell| {
        try occupied.put(.{
            .x = cell.x + offset.x,
            .y = cell.y + offset.y,
        }, {});
    }
    return true;
}

fn largerPolyominoFirst(_: void, left: Polyomino, right: Polyomino) bool {
    if (left.perimeter == right.perimeter) return left.input_index < right.input_index;
    return left.perimeter > right.perimeter;
}

fn cellLessThan(_: void, left: Cell, right: Cell) bool {
    if (left.x == right.x) return left.y < right.y;
    return left.x < right.x;
}

fn cellCoordinate(value: f64, step: f64) i64 {
    return @intFromFloat(@floor(value / step));
}

fn gridCellCount(value: f64, step: f64) usize {
    return @max(1, @as(usize, @intFromFloat(@ceil(@max(0.0, value) / step))));
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

const GridCell = struct {
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

fn gridCell(index: usize, grid: Grid, major: osage.MajorOrder) GridCell {
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
    if (std.ascii.eqlIgnoreCase(text, "graph")) return .graph;
    if (std.ascii.eqlIgnoreCase(text, "node")) return .node;
    if (std.ascii.eqlIgnoreCase(text, "cluster")) return .cluster;
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
    try std.testing.expectEqual(Mode.node, parseOptions(null, "node").?.mode);
    try std.testing.expectEqual(Mode.cluster, parseOptions(null, "cluster").?.mode);
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

test "node polyomino packing nests a square inside an L-shaped component" {
    const allocator = std.testing.allocator;
    const first_rectangles = [_]GeometryRect{
        .{ .x = 0, .y = 0, .width = 30, .height = 100 },
        .{ .x = 0, .y = 0, .width = 100, .height = 30 },
    };
    const second_rectangles = [_]GeometryRect{
        .{ .x = 0, .y = 0, .width = 50, .height = 50 },
    };
    const components = [_]Component{
        .{
            .bounds = .{ .id = 0, .x = 0, .y = 0, .width = 100, .height = 100 },
            .rectangles = &first_rectangles,
        },
        .{
            .bounds = .{ .id = 1, .x = 0, .y = 0, .width = 50, .height = 50 },
            .rectangles = &second_rectangles,
        },
    };
    var compact = try layoutComponents(allocator, &components, .{ .mode = .node, .margin = 0 });
    defer compact.deinit();
    var rectangular = try layoutComponents(allocator, &components, .{ .mode = .graph, .margin = 0 });
    defer rectangular.deinit();

    try std.testing.expect(
        compact.width * compact.height <
            rectangular.width * rectangular.height,
    );
    try std.testing.expect(rectanglesOverlap(
        components[0].bounds,
        compact.placements[0],
        components[1].bounds,
        compact.placements[1],
    ));
    for (first_rectangles) |left| {
        for (second_rectangles) |right| {
            try std.testing.expect(!geometryRectsOverlap(
                left,
                compact.placements[0],
                right,
                compact.placements[1],
            ));
        }
    }
}

test "polyomino component budget falls back exactly to graph packing" {
    const allocator = std.testing.allocator;
    const components = try allocator.alloc(Component, maxPolyominoComponents + 1);
    defer allocator.free(components);
    for (components, 0..) |*component, index| {
        component.* = .{
            .bounds = .{
                .id = index,
                .x = 0,
                .y = 0,
                .width = 40 + @as(f64, @floatFromInt(index % 3)) * 5,
                .height = 24 + @as(f64, @floatFromInt(index % 5)) * 3,
            },
        };
    }
    var compact = try layoutComponents(allocator, components, .{
        .mode = .node,
        .margin = 4,
    });
    defer compact.deinit();
    var graph = try layoutComponents(allocator, components, .{
        .mode = .graph,
        .margin = 4,
    });
    defer graph.deinit();

    try std.testing.expectEqual(graph.width, compact.width);
    try std.testing.expectEqual(graph.height, compact.height);
    for (graph.placements, compact.placements) |expected, actual| {
        try std.testing.expectEqual(expected.x, actual.x);
        try std.testing.expectEqual(expected.y, actual.y);
    }
}

test "polyomino primitive budget falls back exactly to graph packing" {
    const allocator = std.testing.allocator;
    const segments = try allocator.alloc(Segment, maxPolyominoPrimitives + 1);
    defer allocator.free(segments);
    for (segments, 0..) |*segment, index| {
        const x = @as(f64, @floatFromInt(index % 100));
        const y = @as(f64, @floatFromInt(index / 100));
        segment.* = .{
            .start = .{ .x = x, .y = y },
            .end = .{ .x = x + 1, .y = y + 1 },
        };
    }
    const components = [_]Component{
        .{
            .bounds = .{ .id = 0, .x = 0, .y = 0, .width = 200, .height = 200 },
            .segments = segments,
        },
        .{
            .bounds = .{ .id = 1, .x = 0, .y = 0, .width = 50, .height = 50 },
        },
    };
    var compact = try layoutComponents(allocator, &components, .{
        .mode = .node,
        .margin = 4,
    });
    defer compact.deinit();
    var graph = try layoutComponents(allocator, &components, .{
        .mode = .graph,
        .margin = 4,
    });
    defer graph.deinit();

    try std.testing.expectEqual(graph.width, compact.width);
    try std.testing.expectEqual(graph.height, compact.height);
    try std.testing.expectEqualSlices(Placement, graph.placements, compact.placements);
}

test "node polyomino packing is deterministic" {
    const allocator = std.testing.allocator;
    const first_rectangles = [_]GeometryRect{
        .{ .x = 0, .y = 0, .width = 30, .height = 100 },
        .{ .x = 0, .y = 0, .width = 100, .height = 30 },
    };
    const second_rectangles = [_]GeometryRect{
        .{ .x = 0, .y = 0, .width = 50, .height = 50 },
    };
    const components = [_]Component{
        .{
            .bounds = .{ .id = 0, .x = 0, .y = 0, .width = 100, .height = 100 },
            .rectangles = &first_rectangles,
        },
        .{
            .bounds = .{ .id = 1, .x = 0, .y = 0, .width = 50, .height = 50 },
            .rectangles = &second_rectangles,
        },
    };
    var first = try layoutComponents(allocator, &components, .{ .mode = .node });
    defer first.deinit();
    var second = try layoutComponents(allocator, &components, .{ .mode = .node });
    defer second.deinit();
    try std.testing.expectEqual(first.width, second.width);
    try std.testing.expectEqual(first.height, second.height);
    try std.testing.expectEqualSlices(Placement, first.placements, second.placements);
}

fn geometryRectsOverlap(
    left: GeometryRect,
    left_place: Placement,
    right: GeometryRect,
    right_place: Placement,
) bool {
    return left.x + left_place.x < right.x + right_place.x + right.width and
        left.x + left_place.x + left.width > right.x + right_place.x and
        left.y + left_place.y < right.y + right_place.y + right.height and
        left.y + left_place.y + left.height > right.y + right_place.y;
}
