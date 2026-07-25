//! SVG root-canvas sizing helpers.
//!
//! This module intentionally stays independent from the graph model and SVG
//! renderer. It computes Graphviz-style canvas/viewBox sizing from attributes;
//! callers keep ownership of graph data and actual rendering.

const std = @import("std");
const size_attr = @import("../size.zig");

pub const Size = struct {
    x: f64,
    y: f64,
};

pub const Canvas = struct {
    view_box: Size,
    output: Size,
    scale: f64,
};

pub const Padding = struct {
    x: f64,
    y: f64,
};

const RequestedSize = size_attr.Requested;

const Ratio = union(enum) {
    value: f64,
    fill,
    compress,
    expand,
    auto,
};

pub fn landscape(attrs: anytype) bool {
    if (attrValue(attrs, "rotate")) |value| {
        const angle = std.fmt.parseFloat(f64, value) catch return false;
        return @abs(@mod(@abs(angle), 180.0) - 90.0) <= 0.001;
    }
    if (attrValue(attrs, "landscape")) |value| {
        if (parseBool(value)) |enabled| return enabled;
    }
    if (attrValue(attrs, "orientation")) |value| {
        return std.ascii.startsWithIgnoreCase(value, "l");
    }
    return false;
}

pub fn centerTranslate(attrs: anytype, output: Size, natural: Size, landscape_mode: bool) Size {
    if (attrValue(attrs, "center")) |value| {
        if (!(parseBool(value) orelse false)) return .{ .x = 0, .y = 0 };
    } else {
        return .{ .x = 0, .y = 0 };
    }
    const dx = @max(0.0, (output.x - natural.x) / 2.0);
    const dy = @max(0.0, (output.y - natural.y) / 2.0);
    return if (landscape_mode)
        .{ .x = dy, .y = dx }
    else
        .{ .x = dx, .y = dy };
}

pub fn canvas(attrs: anytype, natural: Size) Canvas {
    const requested = size_attr.attr(attrs);
    const ratio = ratioAttr(attrs);
    var view_box = natural;
    var fill_output = false;
    if (ratio) |value| switch (value) {
        .value => |desired| view_box = viewBoxWithRatio(view_box, desired),
        .fill => if (requested) |size| {
            view_box = viewBoxWithRatio(view_box, size.height / size.width);
            fill_output = true;
        },
        .expand => if (requested) |size| {
            if (view_box.x > 0 and view_box.y > 0 and view_box.x < size.width and view_box.y < size.height) {
                const uniform = @min(size.width / view_box.x, size.height / view_box.y);
                view_box = .{ .x = view_box.x * uniform, .y = view_box.y * uniform };
            }
        },
        .compress, .auto => {},
    };
    const output = if (fill_output and requested != null)
        Size{ .x = requested.?.width, .y = requested.?.height }
    else
        outputSize(requested, view_box);
    return .{
        .view_box = view_box,
        .output = output,
        .scale = dpiScale(attrs),
    };
}

pub fn pad(attrs: anytype, fallback: f64) Padding {
    const value = attrValue(attrs, "pad") orelse return .{ .x = fallback, .y = fallback };
    var parts = std.mem.tokenizeAny(u8, value, ", \t");
    const first = parts.next() orelse return .{ .x = fallback, .y = fallback };
    const x = parseInchMargin(first) orelse fallback;
    const y = if (parts.next()) |second| parseInchMargin(second) orelse x else x;
    return .{ .x = x, .y = y };
}

pub fn fitAxis(content_min: f64, content_max: f64, padding: f64, canvas_size: *f64, translate: *f64) void {
    const screen_min = content_min + translate.*;
    const screen_max = content_max + translate.*;
    const left_deficit = padding - screen_min;
    const left_adjust = @max(0.0, left_deficit);
    translate.* += left_adjust;
    const right_deficit = screen_max + left_adjust + padding - canvas_size.*;
    if (right_deficit > 0) canvas_size.* += right_deficit;
}

fn viewBoxWithRatio(current: Size, desired: f64) Size {
    if (desired <= 0 or current.x <= 0 or current.y <= 0) return current;
    const actual = current.y / current.x;
    if (actual < desired) {
        return .{ .x = current.x, .y = @max(current.y, current.x * desired) };
    }
    if (actual > desired) {
        return .{ .x = @max(current.x, current.y / desired), .y = current.y };
    }
    return current;
}

fn outputSize(requested_size: ?RequestedSize, natural: Size) Size {
    const requested = requested_size orelse return natural;
    if (requested.width <= 0 or requested.height <= 0 or natural.x <= 0 or natural.y <= 0) return natural;
    const scale = if (requested.exact)
        @min(requested.width / natural.x, requested.height / natural.y)
    else
        @min(@min(requested.width / natural.x, requested.height / natural.y), 1.0);
    return .{
        .x = @max(1.0, natural.x * scale),
        .y = @max(1.0, natural.y * scale),
    };
}

fn ratioAttr(attrs: anytype) ?Ratio {
    const raw = attrValue(attrs, "ratio") orelse return null;
    const value = std.mem.trim(u8, raw, " \t\r\n");
    if (std.ascii.eqlIgnoreCase(value, "fill")) return .fill;
    if (std.ascii.eqlIgnoreCase(value, "compress")) return .compress;
    if (std.ascii.eqlIgnoreCase(value, "expand")) return .expand;
    if (std.ascii.eqlIgnoreCase(value, "auto")) return .auto;
    const ratio = std.fmt.parseFloat(f64, value) catch return null;
    return if (ratio > 0) .{ .value = ratio } else null;
}

fn dpiScale(attrs: anytype) f64 {
    const raw = attrValue(attrs, "dpi") orelse attrValue(attrs, "resolution") orelse return 1.0;
    const value = std.mem.trim(u8, raw, " \t\r\n");
    const dpi = std.fmt.parseFloat(f64, value) catch return 1.0;
    return if (dpi > 0) dpi / 72.0 else 1.0;
}

fn parseInchMargin(value: []const u8) ?f64 {
    const inches = std.fmt.parseFloat(f64, value) catch return null;
    if (inches < 0) return null;
    return inches * 72.0;
}

fn parseBool(value: []const u8) ?bool {
    if (std.ascii.eqlIgnoreCase(value, "true") or
        std.ascii.eqlIgnoreCase(value, "yes") or
        std.ascii.eqlIgnoreCase(value, "on"))
        return true;
    if (std.ascii.eqlIgnoreCase(value, "false") or
        std.ascii.eqlIgnoreCase(value, "no") or
        std.ascii.eqlIgnoreCase(value, "off"))
        return false;
    const numeric = std.fmt.parseFloat(f64, value) catch return null;
    return numeric != 0;
}

fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    var i = attrs.len;
    while (i > 0) {
        i -= 1;
        if (std.ascii.eqlIgnoreCase(attrs[i].name, name)) return attrs[i].value;
    }
    return null;
}
