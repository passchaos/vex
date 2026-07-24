//! Small SVG writing primitives shared by SVG renderer modules.

const std = @import("std");
const Io = std.Io;

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const Rect = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

pub fn xmlEscaped(writer: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    for (text) |c| {
        switch (c) {
            '&' => try writer.writeAll("&amp;"),
            '<' => try writer.writeAll("&lt;"),
            '>' => try writer.writeAll("&gt;"),
            '"' => try writer.writeAll("&quot;"),
            0x27 => try writer.writeAll("&apos;"),
            else => try writer.writeByte(c),
        }
    }
}

pub fn xmlEscapedWithLineBreaks(writer: *Io.Writer, text: []const u8, left_break: u8, right_break: u8) Io.Writer.Error!void {
    for (text) |c| {
        if (c == left_break or c == right_break) {
            try writer.writeByte('\n');
        } else {
            try xmlEscapedByte(writer, c);
        }
    }
}

fn xmlEscapedByte(writer: *Io.Writer, c: u8) Io.Writer.Error!void {
    switch (c) {
        '&' => try writer.writeAll("&amp;"),
        '<' => try writer.writeAll("&lt;"),
        '>' => try writer.writeAll("&gt;"),
        '"' => try writer.writeAll("&quot;"),
        0x27 => try writer.writeAll("&apos;"),
        else => try writer.writeByte(c),
    }
}

pub fn title(writer: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    try writer.writeAll("<title>");
    try xmlEscaped(writer, text);
    try writer.writeAll("</title>");
}

pub fn number(writer: *Io.Writer, value: f64) Io.Writer.Error!void {
    const normalized = if (@abs(value) < 0.05) 0.0 else value;
    const rounded = @round(normalized);
    if (@abs(normalized - rounded) < 0.05) {
        try writer.print("{d:.0}", .{rounded});
    } else {
        try writer.print("{d:.1}", .{normalized});
    }
}

pub fn numberPrecise(writer: *Io.Writer, value: f64) Io.Writer.Error!void {
    const normalized = if (@abs(value) < 0.005) 0.0 else value;
    const rounded = @round(normalized);
    if (@abs(normalized - rounded) < 0.005) {
        try writer.print("{d:.0}", .{rounded});
    } else {
        try writer.print("{d:.2}", .{normalized});
    }
}

pub fn point(writer: *Io.Writer, value: Point) Io.Writer.Error!void {
    try number(writer, value.x);
    try writer.writeByte(',');
    try number(writer, value.y);
}

pub fn pointPrecise(writer: *Io.Writer, value: Point) Io.Writer.Error!void {
    try numberPrecise(writer, value.x);
    try writer.writeByte(',');
    try numberPrecise(writer, value.y);
}

pub fn rectOpen(writer: *Io.Writer, rect: Rect, radius: f64) Io.Writer.Error!void {
    try writer.writeAll("<rect x=\"");
    try number(writer, rect.x);
    try writer.writeAll("\" y=\"");
    try number(writer, rect.y);
    try writer.writeAll("\" width=\"");
    try number(writer, rect.width);
    try writer.writeAll("\" height=\"");
    try number(writer, rect.height);
    try writer.writeAll("\" rx=\"");
    try number(writer, radius);
    try writer.writeByte('"');
}

pub fn circleOpen(writer: *Io.Writer, center: Point, radius: f64) Io.Writer.Error!void {
    try writer.writeAll("<circle cx=\"");
    try number(writer, center.x);
    try writer.writeAll("\" cy=\"");
    try number(writer, center.y);
    try writer.writeAll("\" r=\"");
    try number(writer, radius);
    try writer.writeByte('"');
}

pub fn pathMove(writer: *Io.Writer, value: Point) Io.Writer.Error!void {
    try writer.writeByte('M');
    try pathPoint(writer, value);
}

pub fn pathMovePrecise(writer: *Io.Writer, value: Point) Io.Writer.Error!void {
    try writer.writeByte('M');
    try pathPointPrecise(writer, value);
}

pub fn pathLine(writer: *Io.Writer, value: Point) Io.Writer.Error!void {
    try writer.writeByte('L');
    try pathPoint(writer, value);
}

pub fn pathCubic(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try pathPoint(writer, c1);
    try writer.writeByte(' ');
    try pathPoint(writer, c2);
    try writer.writeByte(' ');
    try pathPoint(writer, end);
}

pub fn pathCubicC1Precise(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try pathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try pathPoint(writer, c2);
    try writer.writeByte(' ');
    try pathPoint(writer, end);
}

pub fn pathCubicPrecise(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try pathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try pathPointPrecise(writer, c2);
    try writer.writeByte(' ');
    try pathPointPrecise(writer, end);
}

pub fn pathCubicPreciseControls(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try pathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try pathPointPrecise(writer, c2);
    try writer.writeByte(' ');
    try pathPoint(writer, end);
}

pub fn pathCubicEndPrecise(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try pathPoint(writer, c1);
    try writer.writeByte(' ');
    try pathPoint(writer, c2);
    try writer.writeByte(' ');
    try pathPointPrecise(writer, end);
}

pub fn pathCubicContinuation(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte(' ');
    try pathPoint(writer, c1);
    try writer.writeByte(' ');
    try pathPoint(writer, c2);
    try writer.writeByte(' ');
    try pathPoint(writer, end);
}

pub fn pathCubicContinuationPrecise(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte(' ');
    try pathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try pathPointPrecise(writer, c2);
    try writer.writeByte(' ');
    try pathPointPrecise(writer, end);
}

pub fn pathCubicContinuationPreciseControls(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte(' ');
    try pathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try pathPointPrecise(writer, c2);
    try writer.writeByte(' ');
    try pathPoint(writer, end);
}

fn pathPoint(writer: *Io.Writer, value: Point) Io.Writer.Error!void {
    try number(writer, value.x);
    try writer.writeByte(',');
    try number(writer, value.y);
}

fn pathPointPrecise(writer: *Io.Writer, value: Point) Io.Writer.Error!void {
    try numberPrecise(writer, value.x);
    try writer.writeByte(',');
    try numberPrecise(writer, value.y);
}
