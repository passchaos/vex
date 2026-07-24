//! Spacing attribute parsing for layout engines.

const std = @import("std");

pub fn hasWord(value: []const u8, word: []const u8) bool {
    var parts = std.mem.tokenizeAny(u8, value, " \t,");
    while (parts.next()) |part| {
        if (std.ascii.eqlIgnoreCase(part, word)) return true;
    }
    return false;
}

pub fn graph(value: []const u8, fallback: f64) f64 {
    return graphValue(value) orelse fallback;
}

pub fn graphValue(value: []const u8) ?f64 {
    var parts = std.mem.tokenizeAny(u8, value, " \t,");
    const first = parts.next() orelse return null;
    const inches = std.fmt.parseFloat(f64, first) catch return null;
    if (inches <= 0) return null;
    // Graphviz ranksep/nodesep are in inches. Use a conservative 72 px/in
    // scale and keep the existing defaults as a lower bound for unset attrs.
    return @max(12.0, inches * 72.0);
}
