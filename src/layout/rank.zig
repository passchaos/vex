//! Rank direction and constraint types.

const std = @import("std");

pub const RankDir = enum {
    TB,
    BT,
    LR,
    RL,

    pub fn fromString(value: []const u8) ?RankDir {
        if (std.ascii.eqlIgnoreCase(value, "TB")) return .TB;
        if (std.ascii.eqlIgnoreCase(value, "BT")) return .BT;
        if (std.ascii.eqlIgnoreCase(value, "LR")) return .LR;
        if (std.ascii.eqlIgnoreCase(value, "RL")) return .RL;
        return null;
    }

    pub fn name(self: RankDir) []const u8 {
        return switch (self) {
            .TB => "TB",
            .BT => "BT",
            .LR => "LR",
            .RL => "RL",
        };
    }
};

pub const RankKind = enum {
    same,
    min,
    max,
    source,
    sink,

    pub fn fromString(value: []const u8) ?RankKind {
        if (std.ascii.eqlIgnoreCase(value, "same")) return .same;
        if (std.ascii.eqlIgnoreCase(value, "min")) return .min;
        if (std.ascii.eqlIgnoreCase(value, "max")) return .max;
        if (std.ascii.eqlIgnoreCase(value, "source")) return .source;
        if (std.ascii.eqlIgnoreCase(value, "sink")) return .sink;
        return null;
    }
};

pub const RankSep = union(enum) {
    value: f64,
    equally: f64,
};
