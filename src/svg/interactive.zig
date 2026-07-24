//! SVG interactive metadata selection helpers.

const std = @import("std");

pub const Kind = enum {
    default,
    edge,
    label,
    head,
    tail,
};

pub fn href(attrs: anytype, kind: Kind) ?[]const u8 {
    return switch (kind) {
        .default => attrValue(attrs, "href") orelse attrValue(attrs, "URL") orelse attrValue(attrs, "url"),
        .edge => attrValue(attrs, "edgehref") orelse attrValue(attrs, "edgeURL") orelse attrValue(attrs, "edgeurl") orelse attrValue(attrs, "href") orelse attrValue(attrs, "URL") orelse attrValue(attrs, "url"),
        .label => attrValue(attrs, "labelhref") orelse attrValue(attrs, "labelURL") orelse attrValue(attrs, "labelurl") orelse href(attrs, .edge),
        .head => attrValue(attrs, "headhref") orelse attrValue(attrs, "headURL") orelse attrValue(attrs, "headurl") orelse href(attrs, .edge),
        .tail => attrValue(attrs, "tailhref") orelse attrValue(attrs, "tailURL") orelse attrValue(attrs, "tailurl") orelse href(attrs, .edge),
    };
}

pub fn tooltip(attrs: anytype, kind: Kind) ?[]const u8 {
    return switch (kind) {
        .default => attrValue(attrs, "tooltip") orelse attrValue(attrs, "title"),
        .edge => attrValue(attrs, "edgetooltip") orelse attrValue(attrs, "tooltip") orelse attrValue(attrs, "title"),
        .label => attrValue(attrs, "labeltooltip"),
        .head => attrValue(attrs, "headtooltip"),
        .tail => attrValue(attrs, "tailtooltip"),
    };
}

pub fn target(attrs: anytype, kind: Kind) ?[]const u8 {
    return switch (kind) {
        .default => attrValue(attrs, "target"),
        .edge => attrValue(attrs, "edgetarget") orelse attrValue(attrs, "target"),
        .label => attrValue(attrs, "labeltarget") orelse target(attrs, .edge),
        .head => attrValue(attrs, "headtarget") orelse target(attrs, .edge),
        .tail => attrValue(attrs, "tailtarget") orelse target(attrs, .edge),
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
