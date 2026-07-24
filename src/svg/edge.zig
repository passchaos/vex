//! SVG edge rendering option helpers.

const std = @import("std");

pub const Routing = enum {
    curved,
    line,
    polyline,
    ortho,
};

pub fn routingMode(attrs: anytype) Routing {
    const value = attrValue(attrs, "splines") orelse return .curved;
    if (parseBool(value)) |enabled| return if (enabled) .curved else .line;
    if (std.ascii.eqlIgnoreCase(value, "none") or std.ascii.eqlIgnoreCase(value, "line")) return .line;
    if (std.ascii.eqlIgnoreCase(value, "polyline")) return .polyline;
    if (std.ascii.eqlIgnoreCase(value, "ortho")) return .ortho;
    return .curved;
}

pub fn concentrateEnabled(attrs: anytype) bool {
    const value = attrValue(attrs, "concentrate") orelse return false;
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
