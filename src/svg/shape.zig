//! SVG shape geometry writers.

const Io = @import("std").Io;
const svg_writer = @import("writer.zig");

pub const RectPointOrder = enum {
    top_left_clockwise,
    bottom_left_clockwise,
    top_right_counterclockwise,
};

pub fn writeRectPolygonPoints(writer: *Io.Writer, rect: anytype, order: RectPointOrder, precise: bool) Io.Writer.Error!void {
    const left = rect.x;
    const right = rect.x + rect.width;
    const top = rect.y;
    const bottom = rect.y + rect.height;
    const points: [5]svg_writer.Point = switch (order) {
        .top_left_clockwise => [_]svg_writer.Point{
            .{ .x = left, .y = top },
            .{ .x = right, .y = top },
            .{ .x = right, .y = bottom },
            .{ .x = left, .y = bottom },
            .{ .x = left, .y = top },
        },
        .bottom_left_clockwise => [_]svg_writer.Point{
            .{ .x = left, .y = bottom },
            .{ .x = left, .y = top },
            .{ .x = right, .y = top },
            .{ .x = right, .y = bottom },
            .{ .x = left, .y = bottom },
        },
        .top_right_counterclockwise => [_]svg_writer.Point{
            .{ .x = right, .y = top },
            .{ .x = left, .y = top },
            .{ .x = left, .y = bottom },
            .{ .x = right, .y = bottom },
            .{ .x = right, .y = top },
        },
    };
    for (points, 0..) |point, index| {
        if (index > 0) try writer.writeByte(' ');
        if (precise) {
            try svg_writer.pointPrecise(writer, point);
        } else {
            try svg_writer.point(writer, point);
        }
    }
}
