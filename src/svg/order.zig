//! SVG output ordering helpers.

const std = @import("std");

pub const Order = enum {
    breadthfirst,
    nodesfirst,
    edgesfirst,
};

pub fn name(order: Order) []const u8 {
    return switch (order) {
        .breadthfirst => "breadthfirst",
        .nodesfirst => "nodesfirst",
        .edgesfirst => "edgesfirst",
    };
}

pub fn parse(attrs: anytype) Order {
    const value = attrValue(attrs, "outputorder") orelse return .breadthfirst;
    if (std.ascii.eqlIgnoreCase(value, "edgesfirst")) return .edgesfirst;
    if (std.ascii.eqlIgnoreCase(value, "nodesfirst")) return .nodesfirst;
    return .breadthfirst;
}

fn attrValue(attrs: anytype, attr_name: []const u8) ?[]const u8 {
    var i = attrs.len;
    while (i > 0) {
        i -= 1;
        if (std.ascii.eqlIgnoreCase(attrs[i].name, attr_name)) return attrs[i].value;
    }
    return null;
}
