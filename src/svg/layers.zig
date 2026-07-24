//! SVG layer parsing and Graphviz-style layer range matching.
//!
//! This module is intentionally independent from the graph model. It owns the
//! parsing rules for `layers`, `layersep`, `layerlistsep`, and `layerselect`;
//! callers decide how graph objects participate in a selected layer.

const std = @import("std");

pub const Layers = struct {
    names: []const []const u8,
    delims: []const u8,
    list_delims: []const u8,
    selected: ?[]const usize,
};

pub const Context = struct {
    layers: Layers,
    index: usize,
};

pub fn parse(allocator: std.mem.Allocator, attrs: anytype) ?Layers {
    const raw = attrValue(attrs, "layers") orelse return null;
    const delims = attrValue(attrs, "layersep") orelse ":\t ";
    const raw_list_delims = attrValue(attrs, "layerlistsep") orelse ",";
    const list_delims = if (std.mem.indexOfAny(u8, delims, raw_list_delims) == null) raw_list_delims else "";
    var count: usize = 0;
    var iter = std.mem.tokenizeAny(u8, raw, delims);
    while (iter.next()) |_| count += 1;
    if (count == 0) return null;
    var names = allocator.alloc([]const u8, count) catch return null;
    var fill_iter = std.mem.tokenizeAny(u8, raw, delims);
    var out_index: usize = 0;
    while (fill_iter.next()) |name| : (out_index += 1) names[out_index] = name;
    const base = Layers{ .names = names, .delims = delims, .list_delims = list_delims, .selected = null };
    return .{ .names = names, .delims = delims, .list_delims = list_delims, .selected = selection(allocator, attrs, base) };
}

pub fn selection(allocator: std.mem.Allocator, attrs: anytype, layers: Layers) ?[]const usize {
    const spec = attrValue(attrs, "layerselect") orelse return null;
    if (std.mem.trim(u8, spec, " \t\r\n").len == 0) return null;
    var count: usize = 0;
    for (layers.names, 0..) |_, layer_index| {
        const context = Context{ .layers = layers, .index = layer_index };
        if (matches(context, spec)) count += 1;
    }
    if (count == 0) return null;
    var selected = allocator.alloc(usize, count) catch return null;
    var out: usize = 0;
    for (layers.names, 0..) |_, layer_index| {
        const context = Context{ .layers = layers, .index = layer_index };
        if (matches(context, spec)) {
            selected[out] = layer_index;
            out += 1;
        }
    }
    return selected;
}

pub fn matches(layer: Context, spec: []const u8) bool {
    const current = layer.index + 1;
    if (layer.layers.list_delims.len == 0) return partMatches(layer, spec, current);
    var parts = std.mem.tokenizeAny(u8, spec, layer.layers.list_delims);
    while (parts.next()) |part| {
        if (partMatches(layer, part, current)) return true;
    }
    return false;
}

fn partMatches(layer: Context, part: []const u8, current: usize) bool {
    const trimmed = std.mem.trim(u8, part, " \t\r\n");
    if (trimmed.len == 0) return false;
    var range = std.mem.tokenizeAny(u8, trimmed, layer.layers.delims);
    const first = range.next() orelse return false;
    if (range.next()) |second| {
        const start = layerIndex(layer.layers, first, 0) orelse return false;
        const end = layerIndex(layer.layers, second, layer.layers.names.len) orelse return false;
        const lo = @min(start, end);
        const hi = @max(start, end);
        return current >= lo and current <= hi;
    }
    return if (layerIndex(layer.layers, first, current)) |value| value == current else false;
}

fn layerIndex(layers: Layers, raw: []const u8, all_value: usize) ?usize {
    const text = std.mem.trim(u8, raw, " \t\r\n");
    if (std.ascii.eqlIgnoreCase(text, "all")) return all_value;
    if (std.fmt.parseInt(usize, text, 10)) |value| return value else |_| {}
    for (layers.names, 0..) |name, layer_index| {
        if (std.mem.eql(u8, text, name)) return layer_index + 1;
    }
    return null;
}

fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    var i = attrs.len;
    while (i > 0) {
        i -= 1;
        if (std.ascii.eqlIgnoreCase(attrs[i].name, name)) return attrs[i].value;
    }
    return null;
}
