//! SVG text writing helpers.
//!
//! This module owns the SVG syntax for text, tspan line breaks, and font
//! attributes. Callers still decide graph-specific text positions and font
//! resolution.

const std = @import("std");
const Io = std.Io;
const svg_writer = @import("writer.zig");

pub const Font = struct {
    family: []const u8,
    weight: ?[]const u8 = null,
    stretch: ?[]const u8 = null,
    style: ?[]const u8 = null,
};

pub const LabelBreaks = struct {
    left: u8,
    right: u8,
};

pub fn renderBlock(
    writer: *Io.Writer,
    text: []const u8,
    x: f64,
    center_y: f64,
    font_size: f64,
    fill_color: []const u8,
    font: Font,
    label_background: bool,
    dominant_middle: bool,
    breaks: LabelBreaks,
) Io.Writer.Error!void {
    try renderBlockWithAnchor(writer, text, x, center_y, font_size, fill_color, font, label_background, dominant_middle, "middle", null, breaks);
}

pub fn renderPlainBlock(
    writer: *Io.Writer,
    text: []const u8,
    x: f64,
    center_y: f64,
    font_size: f64,
    fill_color: []const u8,
    font: Font,
    text_anchor: []const u8,
    breaks: LabelBreaks,
) Io.Writer.Error!void {
    const height = font_size * 1.25;
    const y = center_y - height / 2.0 + height * 0.72;
    try open(writer, text_anchor, x, y, font, font_size);
    try fill(writer, fill_color);
    try writer.writeAll(">");
    try xmlEscaped(writer, text, breaks);
    try writer.writeAll("</text>\n");
}

pub fn renderBlockWithAnchor(
    writer: *Io.Writer,
    text: []const u8,
    x: f64,
    center_y: f64,
    font_size: f64,
    fill_color: []const u8,
    font: Font,
    label_background: bool,
    dominant_middle: bool,
    text_anchor: []const u8,
    forced_line_anchor: ?[]const u8,
    breaks: LabelBreaks,
) Io.Writer.Error!void {
    const count = lineCount(text, breaks);
    const height = font_size * 1.25;
    const block_height = @as(f64, @floatFromInt(count)) * height;
    const first_y = center_y - block_height / 2.0 + height * 0.72;

    if (label_background) {
        const max_len = maxLineLen(text, breaks);
        const width = @as(f64, @floatFromInt(max_len)) * font_size * 0.62 + 12.0;
        const background_height = block_height + 8.0;
        try svg_writer.rectOpen(writer, .{
            .x = x - width / 2.0,
            .y = center_y - background_height / 2.0,
            .width = width,
            .height = background_height,
        }, 4);
        try writer.writeAll(" fill=\"#ffffff\" stroke=\"#e2e8f0\" opacity=\"0.92\"/>\n");
    }

    try open(writer, text_anchor, x, first_y, font, font_size);
    try fill(writer, fill_color);
    if (dominant_middle and count == 1) try writer.writeAll(" dominant-baseline=\"middle\"");
    try writer.writeAll(">");
    try writeTspans(writer, text, x, height, forced_line_anchor, breaks);
    try writer.writeAll("</text>\n");
}

pub fn fill(writer: *Io.Writer, fill_color: []const u8) Io.Writer.Error!void {
    if (std.ascii.eqlIgnoreCase(fill_color, "black")) return;
    try writer.print(" fill=\"{s}\"", .{fill_color});
}

pub fn open(writer: *Io.Writer, text_anchor: []const u8, x: f64, y: f64, font: Font, font_size: f64) Io.Writer.Error!void {
    try writer.print("<text xml:space=\"preserve\" text-anchor=\"{s}\" x=\"", .{text_anchor});
    try svg_writer.number(writer, x);
    try writer.writeAll("\" y=\"");
    try svg_writer.number(writer, y);
    try writer.writeByte('"');
    try fontAttrs(writer, font, font_size);
}

pub fn fontAttrs(writer: *Io.Writer, font: Font, font_size: f64) Io.Writer.Error!void {
    try writer.print(" font-family=\"{s}\" font-size=\"{d:.2}\"", .{ font.family, font_size });
    if (font.weight) |weight| try writer.print(" font-weight=\"{s}\"", .{weight});
    if (font.stretch) |stretch| try writer.print(" font-stretch=\"{s}\"", .{stretch});
    if (font.style) |style| try writer.print(" font-style=\"{s}\"", .{style});
}

pub fn blockCenterY(text: []const u8, baseline_y: f64, font_size: f64, bottom_aligned: bool, breaks: LabelBreaks) f64 {
    const height = font_size * 1.25;
    const count = lineCount(text, breaks);
    const block_height = @as(f64, @floatFromInt(count)) * height;
    const first_baseline_y = if (bottom_aligned)
        baseline_y - @as(f64, @floatFromInt(count - 1)) * height
    else
        baseline_y;
    return first_baseline_y + block_height / 2.0 - height * 0.72;
}

pub fn lineCount(text: []const u8, breaks: LabelBreaks) usize {
    var count: usize = 1;
    for (text) |c| {
        if (isLineBreak(c, breaks)) count += 1;
    }
    return count;
}

pub fn maxLineLen(text: []const u8, breaks: LabelBreaks) usize {
    var current: usize = 0;
    var result: usize = 0;
    for (text) |c| {
        if (isLineBreak(c, breaks)) {
            result = @max(result, current);
            current = 0;
        } else if (c == '\t') {
            current += 4;
        } else if ((c & 0xc0) != 0x80) {
            current += 1;
        }
    }
    return @max(result, current);
}

fn writeTspans(writer: *Io.Writer, text: []const u8, x: f64, line_height: f64, forced_line_anchor: ?[]const u8, breaks: LabelBreaks) Io.Writer.Error!void {
    var start: usize = 0;
    var index: usize = 0;
    var line_index: usize = 0;
    while (index <= text.len) : (index += 1) {
        if (index < text.len and !isLineBreak(text[index], breaks)) continue;
        const anchor = forced_line_anchor orelse lineAnchor(if (index < text.len) text[index] else '\n', breaks);
        if (line_index == 0) {
            try tspanOpen(writer, x, anchor);
        } else {
            try writer.writeAll("</tspan>");
            try tspanOpenDy(writer, x, line_height, anchor);
        }
        const line = text[start..index];
        try xmlEscaped(writer, line, breaks);
        if (index >= text.len) break;
        start = index + 1;
        line_index += 1;
    }
    try writer.writeAll("</tspan>");
}

fn tspanOpen(writer: *Io.Writer, x: f64, anchor: ?[]const u8) Io.Writer.Error!void {
    try writer.writeAll("<tspan x=\"");
    try svg_writer.number(writer, x);
    try writer.writeByte('"');
    if (anchor) |value| try writer.print(" text-anchor=\"{s}\"", .{value});
    try writer.writeByte('>');
}

fn tspanOpenDy(writer: *Io.Writer, x: f64, dy: f64, anchor: ?[]const u8) Io.Writer.Error!void {
    try writer.writeAll("<tspan x=\"");
    try svg_writer.number(writer, x);
    try writer.print("\" dy=\"{d:.1}\"", .{dy});
    if (anchor) |value| try writer.print(" text-anchor=\"{s}\"", .{value});
    try writer.writeByte('>');
}

fn lineAnchor(c: u8, breaks: LabelBreaks) ?[]const u8 {
    return if (c == breaks.left) "start" else if (c == breaks.right) "end" else null;
}

fn isLineBreak(c: u8, breaks: LabelBreaks) bool {
    return c == '\n' or c == breaks.left or c == breaks.right;
}

fn xmlEscaped(writer: *Io.Writer, text: []const u8, breaks: LabelBreaks) Io.Writer.Error!void {
    try svg_writer.xmlEscapedWithLineBreaks(writer, text, breaks.left, breaks.right);
}
