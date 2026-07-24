//! SVG shape geometry writers.

const Io = @import("std").Io;
const style = @import("style.zig");
const svg_writer = @import("writer.zig");

pub const RectPointOrder = enum {
    top_left_clockwise,
    bottom_left_clockwise,
    top_right_counterclockwise,
};

pub const Paint = struct {
    fill: []const u8 = "none",
    stroke: []const u8,
    width: f64,
    dash: style.Dash,
};

pub const CubicSegment = struct {
    c1: svg_writer.Point,
    c2: svg_writer.Point,
    end: svg_writer.Point,
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

pub fn writeLine(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, paint: Paint) Io.Writer.Error!void {
    const points = [_]svg_writer.Point{
        .{ .x = x1, .y = y1 },
        .{ .x = x2, .y = y2 },
    };
    try writePolylinePath(writer, &points, paint);
}

pub fn writePolylinePath(writer: *Io.Writer, points: anytype, paint: Paint) Io.Writer.Error!void {
    if (points.len == 0) return;
    try writer.print("<path d=\"", .{});
    try svg_writer.pathMove(writer, svgPoint(points[0]));
    for (points[1..]) |item| try svg_writer.pathLine(writer, svgPoint(item));
    try writer.print("\" fill=\"none\" stroke=\"{s}\"", .{paint.stroke});
    try style.writeStrokeWidth(writer, paint.width);
    try style.writeDash(writer, paint.dash);
    try writer.writeAll("/>\n");
}

pub fn writeClosedPath(writer: *Io.Writer, points: anytype, paint: Paint) Io.Writer.Error!void {
    if (points.len == 0) return;
    try writer.print("<path d=\"", .{});
    try svg_writer.pathMove(writer, svgPoint(points[0]));
    for (points[1..]) |item| try svg_writer.pathLine(writer, svgPoint(item));
    try writer.print("Z\" fill=\"{s}\" stroke=\"{s}\"", .{ paint.fill, paint.stroke });
    try style.writeStrokeWidth(writer, paint.width);
    try style.writeDash(writer, paint.dash);
    try writer.writeAll("/>\n");
}

pub fn writeClosedCubicPath(writer: *Io.Writer, start: anytype, segments: []const CubicSegment, paint: Paint) Io.Writer.Error!void {
    try writer.print("<path d=\"", .{});
    try svg_writer.pathMove(writer, svgPoint(start));
    for (segments) |segment| try svg_writer.pathCubic(writer, segment.c1, segment.c2, segment.end);
    try writer.print("Z\" fill=\"{s}\" stroke=\"{s}\"", .{ paint.fill, paint.stroke });
    try style.writeStrokeWidth(writer, paint.width);
    try style.writeDash(writer, paint.dash);
    try writer.writeAll("/>\n");
}

pub fn writePolylineLine(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, paint: Paint) Io.Writer.Error!void {
    try writer.print("<polyline fill=\"none\" stroke=\"{s}\" points=\"", .{paint.stroke});
    try svg_writer.point(writer, .{ .x = x1, .y = y1 });
    try writer.writeByte(' ');
    try svg_writer.point(writer, .{ .x = x2, .y = y2 });
    try writer.writeByte('"');
    try style.writeStrokeWidth(writer, paint.width);
    try style.writeDash(writer, paint.dash);
    try writer.writeAll("/>\n");
}

fn svgPoint(value: anytype) svg_writer.Point {
    return .{ .x = value.x, .y = value.y };
}

pub fn writePolylineLinePrecise(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, paint: Paint) Io.Writer.Error!void {
    try writer.print("<polyline fill=\"none\" stroke=\"{s}\" points=\"", .{paint.stroke});
    try svg_writer.numberPrecise(writer, x1);
    try writer.writeByte(',');
    try svg_writer.numberPrecise(writer, y1);
    try writer.writeByte(' ');
    try svg_writer.numberPrecise(writer, x2);
    try writer.writeByte(',');
    try svg_writer.numberPrecise(writer, y2);
    try writer.writeByte('"');
    try style.writeStrokeWidth(writer, paint.width);
    try style.writeDash(writer, paint.dash);
    try writer.writeAll("/>\n");
}

pub fn writePolylineLineYPrecise(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, paint: Paint) Io.Writer.Error!void {
    try writer.print("<polyline fill=\"none\" stroke=\"{s}\" points=\"", .{paint.stroke});
    try svg_writer.number(writer, x1);
    try writer.writeByte(',');
    try svg_writer.numberPrecise(writer, y1);
    try writer.writeByte(' ');
    try svg_writer.number(writer, x2);
    try writer.writeByte(',');
    try svg_writer.numberPrecise(writer, y2);
    try writer.writeByte('"');
    try style.writeStrokeWidth(writer, paint.width);
    try style.writeDash(writer, paint.dash);
    try writer.writeAll("/>\n");
}
