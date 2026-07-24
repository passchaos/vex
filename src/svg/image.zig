//! SVG image attribute helpers.

const std = @import("std");

pub const Scale = enum {
    none,
    fit,
    width,
    height,
    both,
};

pub const Position = enum {
    top_left,
    top_center,
    top_right,
    middle_left,
    middle_center,
    middle_right,
    bottom_left,
    bottom_center,
    bottom_right,
};

pub fn source(attrs: anytype) ?[]const u8 {
    if (attrValue(attrs, "image")) |image| {
        if (image.len > 0) return image;
    }
    if (attrValue(attrs, "shapefile")) |shapefile| {
        if (shapefile.len > 0) return shapefile;
    }
    return null;
}

pub fn scaleName(scale: Scale) []const u8 {
    return switch (scale) {
        .none => "false",
        .fit => "true",
        .width => "width",
        .height => "height",
        .both => "both",
    };
}

pub fn positionName(position: Position) []const u8 {
    return switch (position) {
        .top_left => "tl",
        .top_center => "tc",
        .top_right => "tr",
        .middle_left => "ml",
        .middle_center => "mc",
        .middle_right => "mr",
        .bottom_left => "bl",
        .bottom_center => "bc",
        .bottom_right => "br",
    };
}

pub fn parseScale(attrs: anytype) Scale {
    const value = attrValue(attrs, "imagescale") orelse return .none;
    if (parseBool(value)) |enabled| return if (enabled) .fit else .none;
    if (std.ascii.eqlIgnoreCase(value, "width")) return .width;
    if (std.ascii.eqlIgnoreCase(value, "height")) return .height;
    if (std.ascii.eqlIgnoreCase(value, "both")) return .both;
    return .none;
}

pub fn parsePosition(attrs: anytype) Position {
    const value = attrValue(attrs, "imagepos") orelse return .middle_center;
    if (std.ascii.eqlIgnoreCase(value, "tl")) return .top_left;
    if (std.ascii.eqlIgnoreCase(value, "tc")) return .top_center;
    if (std.ascii.eqlIgnoreCase(value, "tr")) return .top_right;
    if (std.ascii.eqlIgnoreCase(value, "ml")) return .middle_left;
    if (std.ascii.eqlIgnoreCase(value, "mc")) return .middle_center;
    if (std.ascii.eqlIgnoreCase(value, "mr")) return .middle_right;
    if (std.ascii.eqlIgnoreCase(value, "bl")) return .bottom_left;
    if (std.ascii.eqlIgnoreCase(value, "bc")) return .bottom_center;
    if (std.ascii.eqlIgnoreCase(value, "br")) return .bottom_right;
    return .middle_center;
}

pub fn preserveAspectRatio(scale: Scale, position: Position) []const u8 {
    if (scale == .both) return "none";
    return switch (position) {
        .top_left => "xMinYMin meet",
        .top_center => "xMidYMin meet",
        .top_right => "xMaxYMin meet",
        .middle_left => "xMinYMid meet",
        .middle_center => "xMidYMid meet",
        .middle_right => "xMaxYMid meet",
        .bottom_left => "xMinYMax meet",
        .bottom_center => "xMidYMax meet",
        .bottom_right => "xMaxYMax meet",
    };
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
