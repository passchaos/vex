//! SVG color resolution helpers.
//!
//! Graphviz color attributes can be literal SVG colors, color-scheme indexes,
//! or scheme-prefixed names. This module keeps those render-facing rules
//! independent from the graph model.

const std = @import("std");

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
