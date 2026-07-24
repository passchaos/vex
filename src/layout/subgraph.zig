//! Subgraph layout attribute decisions.

const std = @import("std");

pub fn compoundEnabled(attrs: anytype) bool {
    const value = attrValue(attrs, "compound") orelse return false;
    return parseBool(value) orelse false;
}

pub fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    for (attrs) |attr| {
        if (std.ascii.eqlIgnoreCase(attr.name, name)) return attr.value;
    }
    return null;
}

fn parseBool(value: []const u8) ?bool {
    if (std.ascii.eqlIgnoreCase(value, "true") or std.ascii.eqlIgnoreCase(value, "yes") or std.ascii.eqlIgnoreCase(value, "on") or std.mem.eql(u8, value, "1")) return true;
    if (std.ascii.eqlIgnoreCase(value, "false") or std.ascii.eqlIgnoreCase(value, "no") or std.ascii.eqlIgnoreCase(value, "off") or std.mem.eql(u8, value, "0")) return false;
    return null;
}
