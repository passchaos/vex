//! Pre-positioned node and edge geometry support for nop/nop2.

const std = @import("std");
const Point = @import("result.zig").Point;
const Rect = @import("result.zig").SubgraphLayout;

pub const PositionedPoint = struct {
    point: Point,
    pinned: bool = false,
};

pub const Size = struct {
    width: f64,
    height: f64,
};

pub const BoundingBox = struct {
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,
};

pub const SplineSegment = struct {
    points: []Point,
    start_tip: ?Point = null,
    end_tip: ?Point = null,
};

pub const Spline = struct {
    allocator: std.mem.Allocator,
    segments: []SplineSegment,

    pub fn deinit(self: *Spline) void {
        for (self.segments) |segment| self.allocator.free(segment.points);
        self.allocator.free(self.segments);
        self.* = undefined;
    }
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    positions: []Point,
    shift: Point,
    width: f64,
    height: f64,

    pub fn deinit(self: *Result) void {
        self.allocator.free(self.positions);
        self.* = undefined;
    }
};

pub fn parseNodePosition(value: []const u8) !PositionedPoint {
    var text = std.mem.trim(u8, value, " \t\r\n");
    var pinned = false;
    if (std.mem.endsWith(u8, text, "!")) {
        pinned = true;
        text = std.mem.trim(u8, text[0 .. text.len - 1], " \t\r\n");
    }
    return .{
        .point = try parsePointToken(text),
        .pinned = pinned,
    };
}

pub fn parsePoint(value: []const u8) !Point {
    return parsePointToken(std.mem.trim(u8, value, " \t\r\n"));
}

pub fn parseBoundingBox(value: []const u8) !BoundingBox {
    var parts = std.mem.splitScalar(u8, value, ',');
    const x0 = parseFiniteFloat(parts.next() orelse return error.InvalidBoundingBox) catch return error.InvalidBoundingBox;
    const y0 = parseFiniteFloat(parts.next() orelse return error.InvalidBoundingBox) catch return error.InvalidBoundingBox;
    const x1 = parseFiniteFloat(parts.next() orelse return error.InvalidBoundingBox) catch return error.InvalidBoundingBox;
    const y1 = parseFiniteFloat(parts.next() orelse return error.InvalidBoundingBox) catch return error.InvalidBoundingBox;
    if (parts.next() != null) return error.InvalidBoundingBox;
    return .{
        .min_x = @min(x0, x1),
        .min_y = @min(y0, y1),
        .max_x = @max(x0, x1),
        .max_y = @max(y0, y1),
    };
}

pub fn parseSpline(allocator: std.mem.Allocator, value: []const u8) !Spline {
    var segments = std.ArrayList(SplineSegment).empty;
    errdefer {
        for (segments.items) |segment| allocator.free(segment.points);
        segments.deinit(allocator);
    }

    var raw_segments = std.mem.splitScalar(u8, value, ';');
    while (raw_segments.next()) |raw_segment| {
        const text = std.mem.trim(u8, raw_segment, " \t\r\n");
        if (text.len == 0) continue;
        const segment = try parseSplineSegment(allocator, text);
        segments.append(allocator, segment) catch |err| {
            allocator.free(segment.points);
            return err;
        };
    }
    if (segments.items.len == 0) return error.InvalidEdgePosition;
    return .{
        .allocator = allocator,
        .segments = try segments.toOwnedSlice(allocator),
    };
}

fn parseSplineSegment(allocator: std.mem.Allocator, value: []const u8) !SplineSegment {
    var points = std.ArrayList(Point).empty;
    errdefer points.deinit(allocator);
    var start_tip: ?Point = null;
    var end_tip: ?Point = null;
    var tokens = std.mem.tokenizeAny(u8, value, " \t\r\n");
    while (tokens.next()) |token| {
        if (std.mem.startsWith(u8, token, "s,")) {
            if (start_tip != null or points.items.len != 0) return error.InvalidEdgePosition;
            start_tip = try parsePointToken(token[2..]);
            continue;
        }
        if (std.mem.startsWith(u8, token, "e,")) {
            if (end_tip != null or points.items.len != 0) return error.InvalidEdgePosition;
            end_tip = try parsePointToken(token[2..]);
            continue;
        }
        try points.append(allocator, try parsePointToken(token));
    }
    if (points.items.len < 4 or points.items.len % 3 != 1) return error.InvalidEdgePosition;
    return .{
        .points = try points.toOwnedSlice(allocator),
        .start_tip = start_tip,
        .end_tip = end_tip,
    };
}

fn parsePointToken(value: []const u8) !Point {
    var parts = std.mem.splitScalar(u8, value, ',');
    const x_text = parts.next() orelse return error.InvalidPosition;
    const y_text = parts.next() orelse return error.InvalidPosition;
    if (parts.next() != null) return error.InvalidPosition;
    const x = parseFiniteFloat(x_text) catch return error.InvalidPosition;
    const y = parseFiniteFloat(y_text) catch return error.InvalidPosition;
    return .{ .x = x, .y = y };
}

fn parseFiniteFloat(value: []const u8) !f64 {
    const parsed = std.fmt.parseFloat(f64, std.mem.trim(u8, value, " \t\r\n")) catch return error.InvalidNumber;
    if (!std.math.isFinite(parsed)) return error.InvalidNumber;
    return parsed;
}

pub fn layout(
    allocator: std.mem.Allocator,
    input_positions: []const Point,
    sizes: []const Size,
    extra_points: []const Point,
    margin_x: f64,
    margin_y: f64,
    translate: bool,
) !Result {
    if (input_positions.len != sizes.len) return error.PositionCountMismatch;
    const positions = try allocator.alloc(Point, input_positions.len);
    errdefer allocator.free(positions);

    var min_x = std.math.floatMax(f64);
    var min_y = std.math.floatMax(f64);
    var max_x: f64 = -std.math.floatMax(f64);
    var max_y: f64 = -std.math.floatMax(f64);
    for (input_positions, sizes) |position, size| {
        const screen = inputToScreen(position);
        min_x = @min(min_x, screen.x - size.width / 2.0);
        min_y = @min(min_y, screen.y - size.height / 2.0);
        max_x = @max(max_x, screen.x + size.width / 2.0);
        max_y = @max(max_y, screen.y + size.height / 2.0);
    }
    for (extra_points) |point| {
        const screen = inputToScreen(point);
        min_x = @min(min_x, screen.x);
        min_y = @min(min_y, screen.y);
        max_x = @max(max_x, screen.x);
        max_y = @max(max_y, screen.y);
    }

    const has_bounds = input_positions.len > 0 or extra_points.len > 0;
    const shift = if (translate and has_bounds)
        Point{ .x = positiveOrZero(margin_x) - min_x, .y = positiveOrZero(margin_y) - min_y }
    else
        Point{ .x = 0, .y = 0 };
    for (input_positions, positions) |position, *output| {
        output.* = transformPoint(position, shift);
    }

    if (!has_bounds) {
        return .{
            .allocator = allocator,
            .positions = positions,
            .shift = shift,
            .width = 1,
            .height = 1,
        };
    }
    return .{
        .allocator = allocator,
        .positions = positions,
        .shift = shift,
        .width = @max(1.0, if (translate)
            max_x + shift.x + positiveOrZero(margin_x)
        else
            max_x - min_x + positiveOrZero(margin_x) * 2.0),
        .height = @max(1.0, if (translate)
            max_y + shift.y + positiveOrZero(margin_y)
        else
            max_y - min_y + positiveOrZero(margin_y) * 2.0),
    };
}

pub fn transformPoint(point: Point, shift: Point) Point {
    const screen = inputToScreen(point);
    return .{ .x = screen.x + shift.x, .y = screen.y + shift.y };
}

pub fn transformSpline(spline: *Spline, shift: Point) void {
    for (spline.segments) |*segment| {
        for (segment.points) |*point| point.* = transformPoint(point.*, shift);
        if (segment.start_tip) |point| segment.start_tip = transformPoint(point, shift);
        if (segment.end_tip) |point| segment.end_tip = transformPoint(point, shift);
    }
}

pub fn transformBoundingBox(box: BoundingBox, shift: Point, id: usize) Rect {
    const top_left = transformPoint(.{ .x = box.min_x, .y = box.max_y }, shift);
    return .{
        .id = id,
        .x = top_left.x,
        .y = top_left.y,
        .width = box.max_x - box.min_x,
        .height = box.max_y - box.min_y,
    };
}

pub fn appendBoundingBoxCorners(points: *std.ArrayList(Point), allocator: std.mem.Allocator, box: BoundingBox) !void {
    try points.appendSlice(allocator, &.{
        .{ .x = box.min_x, .y = box.min_y },
        .{ .x = box.min_x, .y = box.max_y },
        .{ .x = box.max_x, .y = box.min_y },
        .{ .x = box.max_x, .y = box.max_y },
    });
}

fn inputToScreen(point: Point) Point {
    return .{ .x = point.x, .y = -point.y };
}

fn positiveOrZero(value: f64) f64 {
    return if (std.math.isFinite(value) and value > 0) value else 0;
}

test "node position accepts Graphviz pin suffix" {
    const parsed = try parseNodePosition(" 12.5,-7! ");
    try std.testing.expect(parsed.pinned);
    try std.testing.expectApproxEqAbs(@as(f64, 12.5), parsed.point.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, -7), parsed.point.y, 0.001);
    try std.testing.expectError(error.InvalidPosition, parseNodePosition("12"));
}

test "edge spline requires Graphviz cubic point cardinality" {
    const allocator = std.testing.allocator;
    var spline = try parseSpline(allocator, "s,0,0 e,30,0 0,0 10,20 20,20 30,0");
    defer spline.deinit();
    try std.testing.expectEqual(@as(usize, 1), spline.segments.len);
    try std.testing.expectEqual(@as(usize, 4), spline.segments[0].points.len);
    try std.testing.expect(spline.segments[0].start_tip != null);
    try std.testing.expect(spline.segments[0].end_tip != null);
    try std.testing.expectError(
        error.InvalidEdgePosition,
        parseSpline(allocator, "0,0 10,10 20,0"),
    );
}

test "edge spline supports multiple cubic segments" {
    const allocator = std.testing.allocator;
    var spline = try parseSpline(
        allocator,
        "0,0 10,20 20,20 30,0; 30,0 40,-20 50,-20 60,0",
    );
    defer spline.deinit();
    try std.testing.expectEqual(@as(usize, 2), spline.segments.len);
}

test "bounding boxes normalize and transform y-up coordinates" {
    const parsed = try parseBoundingBox("100,80,20,-10");
    try std.testing.expectApproxEqAbs(@as(f64, 20), parsed.min_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, -10), parsed.min_y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 100), parsed.max_x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 80), parsed.max_y, 0.001);

    const rect = transformBoundingBox(parsed, .{ .x = 12, .y = 100 }, 4);
    try std.testing.expectEqual(@as(usize, 4), rect.id);
    try std.testing.expectApproxEqAbs(@as(f64, 32), rect.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 20), rect.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 80), rect.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 90), rect.height, 0.001);
}

test "pre-positioned layout flips y and translates node bounds" {
    const allocator = std.testing.allocator;
    const positions = [_]Point{
        .{ .x = 10, .y = 20 },
        .{ .x = 110, .y = 70 },
    };
    const sizes = [_]Size{
        .{ .width = 20, .height = 10 },
        .{ .width = 40, .height = 30 },
    };
    var result = try layout(allocator, &positions, &sizes, &.{}, 12, 8, true);
    defer result.deinit();

    try std.testing.expectApproxEqAbs(@as(f64, 22), result.positions[0].x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 73), result.positions[0].y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 154), result.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 86), result.height, 0.001);
}

test "notranslate preserves origin while reporting full extent" {
    const allocator = std.testing.allocator;
    const positions = [_]Point{
        .{ .x = -80, .y = -20 },
        .{ .x = 20, .y = 30 },
    };
    const sizes = [_]Size{
        .{ .width = 20, .height = 10 },
        .{ .width = 40, .height = 30 },
    };
    var result = try layout(allocator, &positions, &sizes, &.{}, 12, 8, false);
    defer result.deinit();

    try std.testing.expectApproxEqAbs(@as(f64, -80), result.positions[0].x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 20), result.positions[0].y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 154), result.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 86), result.height, 0.001);
}

test "preserved spline points contribute to translation bounds" {
    const allocator = std.testing.allocator;
    const positions = [_]Point{
        .{ .x = 0, .y = 0 },
        .{ .x = 100, .y = 0 },
    };
    const sizes = [_]Size{
        .{ .width = 20, .height = 20 },
        .{ .width = 20, .height = 20 },
    };
    const spline_points = [_]Point{
        .{ .x = -40, .y = 30 },
        .{ .x = 140, .y = -30 },
    };
    var result = try layout(allocator, &positions, &sizes, &spline_points, 10, 10, true);
    defer result.deinit();

    try std.testing.expectApproxEqAbs(@as(f64, 50), result.positions[0].x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 40), result.positions[0].y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 200), result.width, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 80), result.height, 0.001);
}
