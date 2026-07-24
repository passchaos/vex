//! SVG image attribute helpers.

const std = @import("std");

pub fn source(attrs: anytype) ?[]const u8 {
    if (attrValue(attrs, "image")) |image| {
        if (image.len > 0) return image;
    }
    if (attrValue(attrs, "shapefile")) |shapefile| {
        if (shapefile.len > 0) return shapefile;
    }
    return null;
}

pub fn preserveAspectRatio(scale: anytype, position: anytype) []const u8 {
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

fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    var i = attrs.len;
    while (i > 0) {
        i -= 1;
        if (std.ascii.eqlIgnoreCase(attrs[i].name, name)) return attrs[i].value;
    }
    return null;
}
