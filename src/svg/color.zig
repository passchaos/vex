//! SVG color resolution helpers.
//!
//! Graphviz color attributes can be literal SVG colors, color-scheme indexes,
//! or scheme-prefixed names. This module keeps those render-facing rules
//! independent from the graph model.

const std = @import("std");

pub const Segment = struct {
    color: []const u8,
    fraction: f64,
    has_fraction: bool,
};

pub const List = struct {
    segments: [8]Segment = undefined,
    len: usize = 0,
};

pub fn resolve(attrs: anytype, graph_attrs: anytype, color: []const u8) []const u8 {
    if (std.ascii.eqlIgnoreCase(color, "transparent")) return "none";
    if (std.mem.eql(u8, color, "black") or std.mem.eql(u8, color, "white") or std.mem.eql(u8, color, "lightgrey")) return color;
    if (color.len >= 2 and color[0] == '/' and color[1] == '/') {
        const scheme = attrValue(attrs, "colorscheme") orelse attrValue(graph_attrs, "colorscheme") orelse return color[2..];
        return fromScheme(scheme, color[2..]) orelse color[2..];
    }
    if (color.len >= 1 and color[0] == '/') {
        const rest = color[1..];
        if (std.mem.indexOfScalar(u8, rest, '/')) |slash| {
            const scheme = rest[0..slash];
            const name = rest[slash + 1 ..];
            if (std.ascii.eqlIgnoreCase(scheme, "X11") or std.ascii.eqlIgnoreCase(scheme, "Xlib")) return name;
            return fromScheme(scheme, name) orelse color;
        }
        return rest;
    }
    const scheme = attrValue(attrs, "colorscheme") orelse attrValue(graph_attrs, "colorscheme") orelse return color;
    if (std.ascii.eqlIgnoreCase(scheme, "X11") or std.ascii.eqlIgnoreCase(scheme, "Xlib")) return color;
    return fromScheme(scheme, color) orelse color;
}

pub fn parseList(value: []const u8) ?List {
    if (std.mem.indexOfScalar(u8, value, ':') == null) return null;
    var result = List{};
    var left: f64 = 1.0;
    var splitter = std.mem.splitScalar(u8, value, ':');
    while (splitter.next()) |raw_part| {
        if (result.len >= result.segments.len) break;
        const part = std.mem.trim(u8, raw_part, " \t\r\n");
        if (part.len == 0) continue;
        var color = part;
        var fraction: f64 = 0.0;
        var has_fraction = false;
        if (std.mem.indexOfScalar(u8, part, ';')) |semicolon| {
            color = std.mem.trim(u8, part[0..semicolon], " \t\r\n");
            const fraction_text = std.mem.trim(u8, part[semicolon + 1 ..], " \t\r\n");
            if (fraction_text.len == 0) return null;
            const parsed = std.fmt.parseFloat(f64, fraction_text) catch return null;
            if (parsed < 0) return null;
            fraction = @min(parsed, left);
            left -= fraction;
            has_fraction = true;
        }
        if (color.len == 0) continue;
        result.segments[result.len] = .{ .color = color, .fraction = fraction, .has_fraction = has_fraction };
        result.len += 1;
        if (left <= 0.00001) {
            left = 0;
            break;
        }
    }
    if (result.len < 2) return null;

    if (left > 0) {
        var unspecified: usize = 0;
        for (result.segments[0..result.len]) |segment| {
            if (!segment.has_fraction) unspecified += 1;
        }
        if (unspecified > 0) {
            const delta = left / @as(f64, @floatFromInt(unspecified));
            for (result.segments[0..result.len]) |*segment| {
                if (!segment.has_fraction) segment.fraction = delta;
            }
        } else if (result.segments[result.len - 1].fraction > 0) {
            result.segments[result.len - 1].fraction += left;
        }
    }

    while (result.len > 0 and result.segments[result.len - 1].fraction <= 0 and !result.segments[result.len - 1].has_fraction) result.len -= 1;
    return if (result.len >= 2) result else null;
}

fn fromScheme(scheme: []const u8, name: []const u8) ?[]const u8 {
    if (!std.ascii.eqlIgnoreCase(scheme, "bugn9")) return null;
    const index = std.fmt.parseInt(usize, name, 10) catch return null;
    return switch (index) {
        1 => "#f7fcfd",
        2 => "#e5f5f9",
        3 => "#ccece6",
        4 => "#99d8c9",
        5 => "#66c2a4",
        6 => "#41ae76",
        7 => "#238b45",
        8 => "#006d2c",
        9 => "#00441b",
        else => null,
    };
}

fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    var i = attrs.len;
    while (i > 0) {
        i -= 1;
        if (std.ascii.eqlIgnoreCase(attrs[i].name, name)) return attrs[i].value;
    }
    return null;
}
