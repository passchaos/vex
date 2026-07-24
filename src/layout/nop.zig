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

pub const OverlapMode = enum {
    retain,
    remove,
    scale,
    scalexy,
    compress,
    orthogonal,
    orthogonal_yx,
    prism,
    vpsc,
    ipsep,

    pub fn name(self: OverlapMode) []const u8 {
        return switch (self) {
            .retain => "true",
            .remove => "false",
            .scale => "scale",
            .scalexy => "scalexy",
            .compress => "compress",
            .orthogonal => "ortho",
            .orthogonal_yx => "ortho_yx",
            .prism => "prism",
            .vpsc => "vpsc",
            .ipsep => "ipsep",
        };
    }
};

pub const Separation = union(enum) {
    scale: Point,
    add: Point,
};

pub const AdjustmentStats = struct {
    moved: bool = false,
    passes: usize = 0,
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

pub fn parseOverlapMode(value: ?[]const u8) OverlapMode {
    const raw = value orelse return .retain;
    const text = std.mem.trim(u8, raw, " \t\r\n");
    if (text.len == 0) return .retain;
    if (std.ascii.eqlIgnoreCase(text, "true") or
        std.ascii.eqlIgnoreCase(text, "yes") or
        std.ascii.eqlIgnoreCase(text, "on") or
        std.mem.eql(u8, text, "1"))
    {
        return .retain;
    }
    if (std.ascii.eqlIgnoreCase(text, "false") or
        std.ascii.eqlIgnoreCase(text, "no") or
        std.ascii.eqlIgnoreCase(text, "off") or
        std.mem.eql(u8, text, "0") or
        std.ascii.eqlIgnoreCase(text, "voronoi"))
    {
        return .remove;
    }
    if (std.ascii.eqlIgnoreCase(text, "scale") or std.ascii.eqlIgnoreCase(text, "oscale")) return .scale;
    if (std.ascii.eqlIgnoreCase(text, "scalexy")) return .scalexy;
    if (std.ascii.eqlIgnoreCase(text, "compress")) return .compress;
    if (std.ascii.eqlIgnoreCase(text, "ortho") or
        std.ascii.eqlIgnoreCase(text, "orthoxy") or
        std.ascii.eqlIgnoreCase(text, "portho") or
        std.ascii.eqlIgnoreCase(text, "porthoxy"))
    {
        return .orthogonal;
    }
    if (std.ascii.eqlIgnoreCase(text, "ortho_yx") or
        std.ascii.eqlIgnoreCase(text, "orthoyx") or
        std.ascii.eqlIgnoreCase(text, "portho_yx") or
        std.ascii.eqlIgnoreCase(text, "porthoyx"))
    {
        return .orthogonal_yx;
    }
    if (startsWithIgnoreCase(text, "prism")) return .prism;
    if (std.ascii.eqlIgnoreCase(text, "vpsc")) return .vpsc;
    if (std.ascii.eqlIgnoreCase(text, "ipsep")) return .ipsep;
    return .remove;
}

pub fn parseSeparation(value: ?[]const u8) Separation {
    const raw = value orelse return .{ .scale = .{ .x = 0.1, .y = 0.1 } };
    var text = std.mem.trim(u8, raw, " \t\r\n");
    const additive = text.len > 0 and text[0] == '+';
    if (additive) text = std.mem.trim(u8, text[1..], " \t\r\n");
    var parts = std.mem.splitScalar(u8, text, ',');
    const x = parseFiniteFloat(parts.next() orelse return .{ .scale = .{ .x = 0.1, .y = 0.1 } }) catch
        return .{ .scale = .{ .x = 0.1, .y = 0.1 } };
    const y = if (parts.next()) |part| parseFiniteFloat(part) catch x else x;
    const point = Point{ .x = @max(0, x), .y = @max(0, y) };
    return if (additive) .{ .add = point } else .{ .scale = point };
}

pub fn adjustOverlaps(
    allocator: std.mem.Allocator,
    positions: []Point,
    sizes: []const Size,
    mode: OverlapMode,
    separation: Separation,
) !AdjustmentStats {
    if (positions.len != sizes.len) return error.PositionCountMismatch;
    if (positions.len < 2 or mode == .retain) return .{};

    const extents = try allocator.alloc(Size, sizes.len);
    defer allocator.free(extents);
    for (sizes, extents) |size, *extent| {
        extent.* = effectiveExtent(size, separation);
    }

    return switch (mode) {
        .retain => .{},
        .scale => scalePositionsToAvoidOverlap(positions, extents, false),
        .scalexy => scalePositionsToAvoidOverlap(positions, extents, true),
        .compress => compressPositions(positions, extents),
        .orthogonal => resolveOrthogonalOverlaps(allocator, positions, extents, .x),
        .orthogonal_yx => resolveOrthogonalOverlaps(allocator, positions, extents, .y),
        .remove, .prism => resolvePairwiseOverlaps(positions, extents, .minimum),
        .vpsc, .ipsep => resolveOrthogonalOverlaps(allocator, positions, extents, .x),
    };
}

const PreferredAxis = enum {
    minimum,
    x,
    y,
};

fn effectiveExtent(size: Size, separation: Separation) Size {
    return switch (separation) {
        .scale => |factor| .{
            .width = positiveDimension(size.width) * (1.0 + factor.x),
            .height = positiveDimension(size.height) * (1.0 + factor.y),
        },
        .add => |margin| .{
            .width = positiveDimension(size.width) + margin.x * 2.0,
            .height = positiveDimension(size.height) + margin.y * 2.0,
        },
    };
}

fn resolvePairwiseOverlaps(positions: []Point, extents: []const Size, preferred: PreferredAxis) AdjustmentStats {
    var stats = AdjustmentStats{};
    const max_passes = @max(@as(usize, 8), positions.len * 8);
    var pass: usize = 0;
    while (pass < max_passes) : (pass += 1) {
        var changed = false;
        for (0..positions.len) |left_id| {
            for (left_id + 1..positions.len) |right_id| {
                const overlap = overlapAmount(positions[left_id], extents[left_id], positions[right_id], extents[right_id]) orelse continue;
                const axis = switch (preferred) {
                    .minimum => if (overlap.x <= overlap.y) PreferredAxis.x else PreferredAxis.y,
                    else => preferred,
                };
                if (axis == .x) {
                    separateAxis(&positions[left_id].x, &positions[right_id].x, overlap.x, left_id, right_id);
                } else {
                    separateAxis(&positions[left_id].y, &positions[right_id].y, overlap.y, left_id, right_id);
                }
                changed = true;
                stats.moved = true;
            }
        }
        stats.passes = pass + 1;
        if (!changed) break;
    }
    return stats;
}

fn resolveOrthogonalOverlaps(
    allocator: std.mem.Allocator,
    positions: []Point,
    extents: []const Size,
    axis: PreferredAxis,
) !AdjustmentStats {
    const ids = try allocator.alloc(usize, positions.len);
    defer allocator.free(ids);
    for (ids, 0..) |*id, index| id.* = index;
    std.mem.sort(usize, ids, AxisSortContext{ .positions = positions, .axis = axis }, AxisSortContext.lessThan);

    var stats = AdjustmentStats{ .passes = 1 };
    if (ids.len <= 1) return stats;
    for (ids[1..], 1..) |id, sorted_index| {
        const previous_id = ids[sorted_index - 1];
        if (axis == .y) {
            const minimum = positions[previous_id].y + (extents[previous_id].height + extents[id].height) / 2.0 + 0.01;
            if (positions[id].y < minimum) {
                positions[id].y = minimum;
                stats.moved = true;
            }
        } else {
            const minimum = positions[previous_id].x + (extents[previous_id].width + extents[id].width) / 2.0 + 0.01;
            if (positions[id].x < minimum) {
                positions[id].x = minimum;
                stats.moved = true;
            }
        }
    }
    return stats;
}

const AxisSortContext = struct {
    positions: []const Point,
    axis: PreferredAxis,

    fn lessThan(context: AxisSortContext, left: usize, right: usize) bool {
        const left_value = if (context.axis == .y) context.positions[left].y else context.positions[left].x;
        const right_value = if (context.axis == .y) context.positions[right].y else context.positions[right].x;
        if (left_value == right_value) return left < right;
        return left_value < right_value;
    }
};

fn separateAxis(left: *f64, right: *f64, overlap: f64, left_id: usize, right_id: usize) void {
    const epsilon: f64 = 0.01;
    const shift = (overlap + epsilon) / 2.0;
    if (left.* < right.*) {
        left.* -= shift;
        right.* += shift;
    } else if (left.* > right.*) {
        left.* += shift;
        right.* -= shift;
    } else if (left_id < right_id) {
        left.* -= shift;
        right.* += shift;
    } else {
        left.* += shift;
        right.* -= shift;
    }
}

fn scalePositionsToAvoidOverlap(positions: []Point, extents: []const Size, separate_axes: bool) AdjustmentStats {
    const center = positionCenter(positions);
    var scaled = false;
    if (separate_axes) {
        var x_factor: f64 = 1.0;
        var y_factor: f64 = 1.0;
        for (0..positions.len) |left_id| {
            for (left_id + 1..positions.len) |right_id| {
                if (overlapAmount(positions[left_id], extents[left_id], positions[right_id], extents[right_id]) == null) continue;
                const required_x = requiredAxisScale(
                    positions[left_id].x,
                    positions[right_id].x,
                    (extents[left_id].width + extents[right_id].width) / 2.0,
                );
                const required_y = requiredAxisScale(
                    positions[left_id].y,
                    positions[right_id].y,
                    (extents[left_id].height + extents[right_id].height) / 2.0,
                );
                if (required_x <= required_y) {
                    if (std.math.isFinite(required_x)) x_factor = @max(x_factor, required_x);
                } else {
                    if (std.math.isFinite(required_y)) y_factor = @max(y_factor, required_y);
                }
            }
        }
        if (x_factor > 1.0 or y_factor > 1.0) {
            scaleAround(positions, center, x_factor * 1.001, y_factor * 1.001);
            scaled = true;
        }
    } else {
        var factor: f64 = 1.0;
        for (0..positions.len) |left_id| {
            for (left_id + 1..positions.len) |right_id| {
                if (overlapAmount(positions[left_id], extents[left_id], positions[right_id], extents[right_id]) == null) continue;
                const required_x = requiredAxisScale(
                    positions[left_id].x,
                    positions[right_id].x,
                    (extents[left_id].width + extents[right_id].width) / 2.0,
                );
                const required_y = requiredAxisScale(
                    positions[left_id].y,
                    positions[right_id].y,
                    (extents[left_id].height + extents[right_id].height) / 2.0,
                );
                const candidate = @min(required_x, required_y);
                if (std.math.isFinite(candidate)) factor = @max(factor, candidate);
            }
        }
        if (factor > 1.0) {
            scaleAround(positions, center, factor * 1.001, factor * 1.001);
            scaled = true;
        }
    }
    const fallback = resolvePairwiseOverlaps(positions, extents, .minimum);
    return .{ .moved = scaled or fallback.moved, .passes = fallback.passes + @intFromBool(scaled) };
}

fn compressPositions(positions: []Point, extents: []const Size) AdjustmentStats {
    var factor: f64 = 0;
    for (0..positions.len) |left_id| {
        for (left_id + 1..positions.len) |right_id| {
            if (overlapAmount(positions[left_id], extents[left_id], positions[right_id], extents[right_id]) != null) {
                return .{};
            }
            const required_x = requiredAxisScale(
                positions[left_id].x,
                positions[right_id].x,
                (extents[left_id].width + extents[right_id].width) / 2.0,
            );
            const required_y = requiredAxisScale(
                positions[left_id].y,
                positions[right_id].y,
                (extents[left_id].height + extents[right_id].height) / 2.0,
            );
            factor = @max(factor, @min(required_x, required_y));
        }
    }
    const safe_factor = std.math.clamp(factor * 1.001, 0.001, 1.0);
    if (safe_factor >= 0.9999) return .{};
    scaleAround(positions, positionCenter(positions), safe_factor, safe_factor);
    return .{ .moved = true, .passes = 1 };
}

fn requiredAxisScale(left: f64, right: f64, required_distance: f64) f64 {
    const distance = @abs(right - left);
    if (distance <= 0.000001) return std.math.floatMax(f64);
    return required_distance / distance;
}

fn scaleAround(positions: []Point, center: Point, x_factor: f64, y_factor: f64) void {
    for (positions) |*position| {
        position.x = center.x + (position.x - center.x) * x_factor;
        position.y = center.y + (position.y - center.y) * y_factor;
    }
}

fn positionCenter(positions: []const Point) Point {
    var center = Point{ .x = 0, .y = 0 };
    if (positions.len == 0) return center;
    for (positions) |position| {
        center.x += position.x;
        center.y += position.y;
    }
    const count = @as(f64, @floatFromInt(positions.len));
    center.x /= count;
    center.y /= count;
    return center;
}

fn overlapAmount(left: Point, left_size: Size, right: Point, right_size: Size) ?Point {
    const overlap_x = (left_size.width + right_size.width) / 2.0 - @abs(right.x - left.x);
    const overlap_y = (left_size.height + right_size.height) / 2.0 - @abs(right.y - left.y);
    if (overlap_x <= 0 or overlap_y <= 0) return null;
    return .{ .x = overlap_x, .y = overlap_y };
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

fn positiveDimension(value: f64) f64 {
    return if (std.math.isFinite(value) and value > 0) value else 1.0;
}

fn startsWithIgnoreCase(value: []const u8, prefix: []const u8) bool {
    return value.len >= prefix.len and std.ascii.eqlIgnoreCase(value[0..prefix.len], prefix);
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

test "overlap mode parser covers Graphviz families" {
    try std.testing.expectEqual(OverlapMode.retain, parseOverlapMode(null));
    try std.testing.expectEqual(OverlapMode.retain, parseOverlapMode("true"));
    try std.testing.expectEqual(OverlapMode.remove, parseOverlapMode("false"));
    try std.testing.expectEqual(OverlapMode.remove, parseOverlapMode("voronoi"));
    try std.testing.expectEqual(OverlapMode.scale, parseOverlapMode("scale"));
    try std.testing.expectEqual(OverlapMode.scalexy, parseOverlapMode("scalexy"));
    try std.testing.expectEqual(OverlapMode.compress, parseOverlapMode("compress"));
    try std.testing.expectEqual(OverlapMode.orthogonal, parseOverlapMode("orthoxy"));
    try std.testing.expectEqual(OverlapMode.orthogonal_yx, parseOverlapMode("porthoyx"));
    try std.testing.expectEqual(OverlapMode.prism, parseOverlapMode("prism100"));
    try std.testing.expectEqual(OverlapMode.vpsc, parseOverlapMode("vpsc"));
    try std.testing.expectEqual(OverlapMode.ipsep, parseOverlapMode("ipsep"));
}

test "separation parser distinguishes scale and additive forms" {
    const scaled = parseSeparation("0.2,0.3");
    try std.testing.expectApproxEqAbs(@as(f64, 0.2), scaled.scale.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.3), scaled.scale.y, 0.001);
    const additive = parseSeparation("+6,8");
    try std.testing.expectApproxEqAbs(@as(f64, 6), additive.add.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 8), additive.add.y, 0.001);
}

test "remove overlap separates coincident rectangles deterministically" {
    const allocator = std.testing.allocator;
    var positions = [_]Point{
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
    };
    const sizes = [_]Size{
        .{ .width = 40, .height = 20 },
        .{ .width = 40, .height = 20 },
        .{ .width = 40, .height = 20 },
    };
    const stats = try adjustOverlaps(
        allocator,
        &positions,
        &sizes,
        .remove,
        .{ .add = .{ .x = 4, .y = 4 } },
    );
    try std.testing.expect(stats.moved);
    try expectNoOverlaps(&positions, &sizes, .{ .add = .{ .x = 4, .y = 4 } });
    for (positions) |position| {
        try std.testing.expect(std.math.isFinite(position.x));
        try std.testing.expect(std.math.isFinite(position.y));
    }
}

test "scale and orthogonal overlap modes preserve ordering" {
    const allocator = std.testing.allocator;
    const sizes = [_]Size{
        .{ .width = 40, .height = 24 },
        .{ .width = 40, .height = 24 },
        .{ .width = 40, .height = 24 },
    };
    const original = [_]Point{
        .{ .x = 0, .y = 0 },
        .{ .x = 10, .y = 2 },
        .{ .x = 20, .y = 4 },
    };
    var scaled = original;
    _ = try adjustOverlaps(
        allocator,
        &scaled,
        &sizes,
        .scale,
        .{ .scale = .{ .x = 0.1, .y = 0.1 } },
    );
    try expectNoOverlaps(&scaled, &sizes, .{ .scale = .{ .x = 0.1, .y = 0.1 } });
    try std.testing.expect(scaled[0].x < scaled[1].x and scaled[1].x < scaled[2].x);

    var orthogonal = original;
    _ = try adjustOverlaps(
        allocator,
        &orthogonal,
        &sizes,
        .orthogonal_yx,
        .{ .scale = .{ .x = 0.1, .y = 0.1 } },
    );
    try expectNoOverlaps(&orthogonal, &sizes, .{ .scale = .{ .x = 0.1, .y = 0.1 } });
    try std.testing.expect(orthogonal[0].y < orthogonal[1].y and orthogonal[1].y < orthogonal[2].y);
}

test "compress shrinks non-overlapping coordinates without introducing overlap" {
    const allocator = std.testing.allocator;
    var positions = [_]Point{
        .{ .x = 0, .y = 0 },
        .{ .x = 200, .y = 0 },
    };
    const sizes = [_]Size{
        .{ .width = 40, .height = 20 },
        .{ .width = 40, .height = 20 },
    };
    const before = positions[1].x - positions[0].x;
    const stats = try adjustOverlaps(
        allocator,
        &positions,
        &sizes,
        .compress,
        .{ .add = .{ .x = 4, .y = 4 } },
    );
    try std.testing.expect(stats.moved);
    try std.testing.expect(positions[1].x - positions[0].x < before);
    try expectNoOverlaps(&positions, &sizes, .{ .add = .{ .x = 4, .y = 4 } });
}

fn expectNoOverlaps(positions: []const Point, sizes: []const Size, separation: Separation) !void {
    for (0..positions.len) |left_id| {
        for (left_id + 1..positions.len) |right_id| {
            try std.testing.expect(overlapAmount(
                positions[left_id],
                effectiveExtent(sizes[left_id], separation),
                positions[right_id],
                effectiveExtent(sizes[right_id], separation),
            ) == null);
        }
    }
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
