//! SVG edge rendering option helpers.

const std = @import("std");
const color = @import("color.zig");

pub const CompassPort = enum {
    auto,
    center,
    north,
    north_east,
    east,
    south_east,
    south,
    south_west,
    west,
    north_west,

    pub fn name(self: CompassPort) []const u8 {
        return switch (self) {
            .auto => "_",
            .center => "c",
            .north => "n",
            .north_east => "ne",
            .east => "e",
            .south_east => "se",
            .south => "s",
            .south_west => "sw",
            .west => "w",
            .north_west => "nw",
        };
    }

    pub fn fromString(value: []const u8) ?CompassPort {
        if (std.ascii.eqlIgnoreCase(value, "n")) return .north;
        if (std.ascii.eqlIgnoreCase(value, "ne")) return .north_east;
        if (std.ascii.eqlIgnoreCase(value, "e")) return .east;
        if (std.ascii.eqlIgnoreCase(value, "se")) return .south_east;
        if (std.ascii.eqlIgnoreCase(value, "s")) return .south;
        if (std.ascii.eqlIgnoreCase(value, "sw")) return .south_west;
        if (std.ascii.eqlIgnoreCase(value, "w")) return .west;
        if (std.ascii.eqlIgnoreCase(value, "nw")) return .north_west;
        if (std.ascii.eqlIgnoreCase(value, "c")) return .center;
        if (std.ascii.eqlIgnoreCase(value, "_")) return .auto;
        return null;
    }
};

pub const ArrowShape = enum {
    normal,
    none,
    open,
    inv,
    oinv,
    curve,
    icurve,
    vee,
    dot,
    odot,
    box,
    obox,
    diamond,
    odiamond,
    tee,
    crow,
    empty,

    pub fn name(self: ArrowShape) []const u8 {
        return switch (self) {
            .normal => "normal",
            .none => "none",
            .open => "open",
            .inv => "inv",
            .oinv => "oinv",
            .curve => "curve",
            .icurve => "icurve",
            .vee => "vee",
            .dot => "dot",
            .odot => "odot",
            .box => "box",
            .obox => "obox",
            .diamond => "diamond",
            .odiamond => "odiamond",
            .tee => "tee",
            .crow => "crow",
            .empty => "empty",
        };
    }
};

pub const Dir = enum {
    forward,
    back,
    both,
    none,

    pub fn name(self: Dir) []const u8 {
        return switch (self) {
            .forward => "forward",
            .back => "back",
            .both => "both",
            .none => "none",
        };
    }
};

pub const SplineMode = enum {
    curved,
    polyline,
    line,
    ortho,
    none,

    pub fn name(self: SplineMode) []const u8 {
        return switch (self) {
            .curved => "curved",
            .polyline => "polyline",
            .line => "line",
            .ortho => "ortho",
            .none => "none",
        };
    }
};

pub const Routing = enum {
    curved,
    line,
    polyline,
    ortho,
};

pub fn routingMode(attrs: anytype) Routing {
    const value = attrValue(attrs, "splines") orelse return .curved;
    return routingValue(value);
}

pub fn routingValue(value: []const u8) Routing {
    if (parseBool(value)) |enabled| return if (enabled) .curved else .line;
    if (std.ascii.eqlIgnoreCase(value, "none") or std.ascii.eqlIgnoreCase(value, "line")) return .line;
    if (std.ascii.eqlIgnoreCase(value, "polyline")) return .polyline;
    if (std.ascii.eqlIgnoreCase(value, "ortho")) return .ortho;
    return .curved;
}

pub fn concentrateEnabled(attrs: anytype) bool {
    const value = attrValue(attrs, "concentrate") orelse return false;
    return concentrateValueEnabled(value);
}

pub fn concentrateValueEnabled(value: []const u8) bool {
    return parseBool(value) orelse false;
}

pub fn isConcentratedDuplicate(directed: bool, edges: anytype, edge_id: usize) bool {
    const edge_item = edges[edge_id];
    for (edges[0..edge_id]) |candidate| {
        if (candidate.from == candidate.to or edge_item.from == edge_item.to) continue;
        if (directed) {
            if (candidate.from == edge_item.from and candidate.to == edge_item.to) return true;
        } else {
            const same = candidate.from == edge_item.from and candidate.to == edge_item.to;
            const reverse = candidate.from == edge_item.to and candidate.to == edge_item.from;
            if (same or reverse) return true;
        }
    }
    return false;
}

pub fn colorList(edge: anytype) ?color.List {
    const raw_color = attrValue(edge.attrs.items, "color") orelse edge.color;
    return color.parseList(raw_color);
}

pub fn colorListOffset(count: usize, index: usize, spacing: f64) f64 {
    if (count <= 1) return 0;
    return (@as(f64, @floatFromInt(index)) - @as(f64, @floatFromInt(count - 1)) / 2.0) * spacing;
}

pub fn markerColorToken(edge: anytype, fallback: []const u8, head: bool) []const u8 {
    const colors = colorList(edge) orelse return fallback;
    if (head) return colors.segments[0].color;
    if (colors.len >= 2) return colors.segments[1].color;
    return colors.segments[0].color;
}

pub fn markerFillToken(edge: anytype, fallback: []const u8, head: bool) []const u8 {
    if (attrValue(edge.attrs.items, "fillcolor")) |fillcolor| return fillcolor;
    return markerColorToken(edge, fallback, head);
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
