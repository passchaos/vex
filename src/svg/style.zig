//! SVG style parsing and writing helpers.
//!
//! Graphviz style attributes are comma/semicolon/whitespace separated lists
//! where later line-style tokens can override earlier ones.

const std = @import("std");
const Io = std.Io;
const svg_writer = @import("writer.zig");

pub const NodeStyle = enum {
    solid,
    filled,
    bold,
    dashed,
    dotted,
    rounded,
    diagonals,
    striped,
    radial,
    wedged,
    invis,

    pub fn name(self: NodeStyle) []const u8 {
        return switch (self) {
            .solid => "solid",
            .filled => "filled",
            .bold => "bold",
            .dashed => "dashed",
            .dotted => "dotted",
            .rounded => "rounded",
            .diagonals => "diagonals",
            .striped => "striped",
            .radial => "radial",
            .wedged => "wedged",
            .invis => "invis",
        };
    }
};

pub const SubgraphStyle = enum {
    solid,
    filled,
    bold,
    dashed,
    dotted,
    rounded,
    striped,
    radial,
    invis,

    pub fn name(self: SubgraphStyle) []const u8 {
        return switch (self) {
            .solid => "solid",
            .filled => "filled",
            .bold => "bold",
            .dashed => "dashed",
            .dotted => "dotted",
            .rounded => "rounded",
            .striped => "striped",
            .radial => "radial",
            .invis => "invis",
        };
    }
};

pub const EdgeStyle = enum {
    solid,
    bold,
    dashed,
    dotted,
    rounded,
    invis,

    pub fn name(self: EdgeStyle) []const u8 {
        return switch (self) {
            .solid => "solid",
            .bold => "bold",
            .dashed => "dashed",
            .dotted => "dotted",
            .rounded => "rounded",
            .invis => "invis",
        };
    }
};

pub const Dash = enum {
    none,
    dashed,
    dotted,
};

pub fn has(style: ?[]const u8, needle: []const u8) bool {
    const value = style orelse return false;
    var parts = std.mem.tokenizeAny(u8, value, ",; \t\r\n");
    while (parts.next()) |part| {
        if (std.ascii.eqlIgnoreCase(part, needle)) return true;
    }
    return false;
}

pub fn dashFromAttr(style: ?[]const u8) Dash {
    const value = style orelse return .none;
    var result = Dash.none;
    var parts = std.mem.tokenizeAny(u8, value, ",; \t\r\n");
    while (parts.next()) |part| {
        if (std.ascii.eqlIgnoreCase(part, "dotted")) {
            result = .dotted;
        } else if (std.ascii.eqlIgnoreCase(part, "dashed")) {
            result = .dashed;
        } else if (std.ascii.eqlIgnoreCase(part, "solid")) {
            result = .none;
        }
    }
    return result;
}

pub fn writeDash(writer: *Io.Writer, dash: Dash) Io.Writer.Error!void {
    switch (dash) {
        .none => {},
        .dashed => try writer.writeAll(" stroke-dasharray=\"8,5\""),
        .dotted => try writer.writeAll(" stroke-dasharray=\"2,5\""),
    }
}

pub fn writeFillOpacity(writer: *Io.Writer, opacity: []const u8) Io.Writer.Error!void {
    if (std.mem.eql(u8, opacity, "1.0") or std.mem.eql(u8, opacity, "1") or std.mem.eql(u8, opacity, "1.00")) return;
    try writer.print(" fill-opacity=\"{s}\"", .{opacity});
}

pub fn writeStrokeWidth(writer: *Io.Writer, width: f64) Io.Writer.Error!void {
    if (@abs(width - 1.0) <= 0.0001) return;
    try writer.writeAll(" stroke-width=\"");
    try svg_writer.number(writer, width);
    try writer.writeByte('"');
}
