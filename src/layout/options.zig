//! Layout option resolution from graph attributes.

const std = @import("std");

const spacing = @import("spacing.zig");

pub const defaultInterClusterGap: f64 = 35.0;
pub const defaultClusterAlongExtentBudget: f64 = 224.0;
pub const defaultClusterAlongShift: f64 = 4.0;

pub fn withGraphAttrs(base: anytype, graph_attrs: anytype) @TypeOf(base) {
    var result = base;
    if (attrValue(graph_attrs, "ranksep")) |value| {
        result.rank_gap = spacing.graph(value, result.rank_gap);
        result.ranksep_equally = spacing.hasWord(value, "equally");
    }
    if (attrValue(graph_attrs, "nodesep")) |value| {
        result.node_gap = spacing.graph(value, result.node_gap);
    }
    if (attrValue(graph_attrs, "margin") != null) {
        const margin = attrMargin(graph_attrs, result.margin);
        result.margin = margin.x;
        result.margin_y = margin.y;
    }
    if (attrValue(graph_attrs, "label") != null) {
        const font_size = positiveAttrFloat(graph_attrs, "fontsize", 14.0);
        result.margin_y = @max(result.margin_y, font_size + 12.0);
    }
    return result;
}

pub fn clusterAlongBudget(along_margin: f64) f64 {
    return @max(0.0, defaultClusterAlongExtentBudget - along_margin * 2.0);
}

pub const BoxMargin = struct {
    x: f64,
    y: f64,
};

pub fn attrMargin(attrs: anytype, fallback: f64) BoxMargin {
    const value = attrValue(attrs, "margin") orelse return .{ .x = fallback, .y = fallback };
    var parts = std.mem.tokenizeAny(u8, value, ", \t");
    const first = parts.next() orelse return .{ .x = fallback, .y = fallback };
    const x = parseInchMargin(first) orelse fallback;
    const y = if (parts.next()) |second| parseInchMargin(second) orelse x else x;
    return .{ .x = x, .y = y };
}

fn positiveAttrFloat(attrs: anytype, name: []const u8, fallback: f64) f64 {
    const value = attrValue(attrs, name) orelse return fallback;
    const parsed = std.fmt.parseFloat(f64, value) catch return fallback;
    return if (parsed > 0) parsed else fallback;
}

fn parseInchMargin(value: []const u8) ?f64 {
    const inches = std.fmt.parseFloat(f64, value) catch return null;
    if (inches < 0) return null;
    return inches * 72.0;
}

fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    for (attrs) |attr| {
        if (std.ascii.eqlIgnoreCase(attr.name, name)) return attr.value;
    }
    return null;
}
