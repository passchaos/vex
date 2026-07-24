//! SVG gradient geometry helpers.

const std = @import("std");
const color = @import("color.zig");

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const Line = struct {
    start: Point,
    end: Point,
};

pub fn line(rect: anytype, angle_degrees: f64) Line {
    const cx = rect.x + rect.width / 2.0;
    const cy = rect.y + rect.height / 2.0;
    const angle = degreesToRadians(angle_degrees);
    const dx = std.math.cos(angle);
    const dy = -std.math.sin(angle);
    const half = @max(rect.width, rect.height);
    return .{
        .start = .{ .x = cx - dx * half, .y = cy - dy * half },
        .end = .{ .x = cx + dx * half, .y = cy + dy * half },
    };
}

pub fn focus(angle_degrees: f64) Point {
    if (@abs(angle_degrees) <= 0.0001) return .{ .x = 50, .y = 50 };
    const angle = degreesToRadians(angle_degrees);
    return .{
        .x = @round(50.0 * (1.0 + std.math.cos(angle))),
        .y = @round(50.0 * (1.0 - std.math.sin(angle))),
    };
}

pub fn stopStartOffset(start: color.Segment, stop: color.Segment) f64 {
    _ = stop;
    return if (start.has_fraction) @max(0.0, start.fraction - 0.001) else 0.0;
}

pub fn stopEndOffset(start: color.Segment, stop: color.Segment) f64 {
    if (start.has_fraction) return start.fraction;
    if (stop.has_fraction) return 1.0 - stop.fraction;
    return 1.0;
}

fn degreesToRadians(degrees: f64) f64 {
    return degrees * std.math.pi / 180.0;
}
