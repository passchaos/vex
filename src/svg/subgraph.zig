//! SVG subgraph visual helpers.

const std = @import("std");

pub const Rect = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

pub fn rawVisualRect(cluster: anytype, boxes: anytype, index: usize) Rect {
    const box = boxes[index];
    var rect = Rect{ .x = box.x, .y = box.y, .width = box.width, .height = box.height };
    if (cluster.parent != null or boxes.len <= 1) return rect;

    var min_x = std.math.floatMax(f64);
    var max_x: f64 = -std.math.floatMax(f64);
    for (boxes) |cluster_box| {
        if (cluster_box.width <= 0 or cluster_box.height <= 0) continue;
        min_x = @min(min_x, cluster_box.x);
        max_x = @max(max_x, cluster_box.x + cluster_box.width);
    }
    if (min_x == std.math.floatMax(f64)) return rect;

    const trim: f64 = 4.0;
    if (@abs(rect.x - min_x) <= 0.01 and rect.width > trim) {
        rect.x += trim;
        rect.width -= trim;
    }
    if (@abs(rect.x + rect.width - max_x) <= 0.01 and rect.width > trim) {
        rect.width -= trim;
    }
    if (hasVerticalTrim(cluster.parent, boxes.len) and rect.height > 1.2) {
        rect.y -= 1.3;
        rect.height -= 1.2;
    }
    return rect;
}

pub fn hasVerticalTrim(parent: anytype, subgraph_count: usize) bool {
    return parent == null and subgraph_count == 2;
}

pub fn labelAnchor(label_just: ?[]const u8) []const u8 {
    if (label_just) |value| {
        if (std.ascii.eqlIgnoreCase(value, "l")) return "start";
        if (std.ascii.eqlIgnoreCase(value, "r")) return "end";
    }
    return "middle";
}

pub fn labelX(rect: anytype, text_anchor: []const u8) f64 {
    if (std.mem.eql(u8, text_anchor, "start")) return rect.x + 12.0;
    if (std.mem.eql(u8, text_anchor, "end")) return rect.x + rect.width - 12.0;
    return rect.x + rect.width / 2.0;
}

pub fn labelY(rect: anytype, label_loc: ?[]const u8, has_vertical_trim: bool) f64 {
    if (label_loc) |value| {
        if (std.ascii.eqlIgnoreCase(value, "b")) return rect.y + rect.height - 10.0;
    }
    const top_offset: f64 = if (has_vertical_trim) 16.6 else 15.3;
    return rect.y + top_offset;
}
