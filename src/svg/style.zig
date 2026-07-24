//! SVG style parsing and writing helpers.
//!
//! Graphviz style attributes are comma/semicolon/whitespace separated lists
//! where later line-style tokens can override earlier ones.

const std = @import("std");
const Io = std.Io;

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
