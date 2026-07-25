//! Shared parsing for Graphviz-style `size` attributes.

const std = @import("std");

pub const Requested = struct {
    width: f64,
    height: f64,
    exact: bool,
};

pub fn attr(attrs: anytype) ?Requested {
    var raw = attrValue(attrs, "size") orelse return null;
    raw = std.mem.trim(u8, raw, " \t\r\n");
    var exact = false;
    if (std.mem.endsWith(u8, raw, "!")) {
        exact = true;
        raw = std.mem.trim(u8, raw[0 .. raw.len - 1], " \t\r\n");
    }
    var parts = std.mem.tokenizeAny(u8, raw, ", \t");
    const first = parts.next() orelse return null;
    const second = parts.next() orelse first;
    const width = inchesToPoints(first) orelse return null;
    const height = inchesToPoints(second) orelse return null;
    if (width <= 0 or height <= 0) return null;
    return .{ .width = width, .height = height, .exact = exact };
}

fn inchesToPoints(value: []const u8) ?f64 {
    const inches = std.fmt.parseFloat(f64, value) catch return null;
    if (!std.math.isFinite(inches) or inches < 0) return null;
    return inches * 72.0;
}

fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    var index = attrs.len;
    while (index > 0) {
        index -= 1;
        if (std.ascii.eqlIgnoreCase(attrs[index].name, name)) return attrs[index].value;
    }
    return null;
}

test "size attr parses points and exact marker" {
    const Attr = struct { name: []const u8, value: []const u8 };
    const attrs = [_]Attr{.{ .name = "size", .value = "2, 1!" }};
    const requested = attr(attrs[0..]).?;
    try std.testing.expectEqual(@as(f64, 144), requested.width);
    try std.testing.expectEqual(@as(f64, 72), requested.height);
    try std.testing.expect(requested.exact);
}

test "size attr rejects invalid and non-positive dimensions" {
    const Attr = struct { name: []const u8, value: []const u8 };
    const invalid = [_]Attr{.{ .name = "size", .value = "wide,tall" }};
    const zero = [_]Attr{.{ .name = "size", .value = "0,1" }};
    try std.testing.expect(attr(invalid[0..]) == null);
    try std.testing.expect(attr(zero[0..]) == null);
}
