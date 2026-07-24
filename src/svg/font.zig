//! SVG font resolution helpers.
//!
//! Graphviz exposes `fontnames=gd|ps|svg` to choose how standard PostScript
//! font names are emitted. This module keeps that compatibility table out of
//! the main renderer.

const std = @import("std");
const text = @import("text.zig");

pub const Font = text.Font;

pub const Names = enum {
    gd,
    ps,
    svg,
};

pub const default_graphviz_name = "Times-Roman";
pub const default_svg_family = "Times,serif";

pub fn namesName(fontnames: Names) []const u8 {
    return switch (fontnames) {
        .gd => "gd",
        .ps => "ps",
        .svg => "svg",
    };
}

pub fn parseNames(value: []const u8) ?Names {
    if (std.ascii.eqlIgnoreCase(value, "gd")) return .gd;
    if (std.ascii.eqlIgnoreCase(value, "ps")) return .ps;
    if (std.ascii.eqlIgnoreCase(value, "svg")) return .svg;
    return null;
}

pub fn resolve(mode: Names, fontname: []const u8) Font {
    if (postscriptAlias(fontname)) |alias| {
        return switch (mode) {
            .svg => .{
                .family = alias.svg_family,
                .weight = alias.svg_weight,
                .stretch = alias.stretch,
                .style = alias.svg_style,
            },
            .ps => .{
                .family = alias.ps_family,
                .weight = alias.weight,
                .stretch = alias.stretch,
                .style = alias.style,
            },
            .gd => .{
                .family = alias.gd_family,
                .weight = alias.weight,
                .stretch = alias.stretch,
                .style = alias.style,
            },
        };
    }
    return .{ .family = fontname };
}

const Alias = struct {
    ps_family: []const u8,
    gd_family: []const u8,
    svg_family: []const u8,
    weight: ?[]const u8 = null,
    stretch: ?[]const u8 = null,
    style: ?[]const u8 = null,
    svg_weight: ?[]const u8 = null,
    svg_style: ?[]const u8 = null,
};

fn postscriptAlias(fontname: []const u8) ?Alias {
    if (std.ascii.eqlIgnoreCase(fontname, "AvantGarde-Book")) return .{ .ps_family = "AvantGarde-Book,sans-Serif", .gd_family = "URW Gothic L,sans-Serif", .svg_family = "sans-Serif", .weight = "book" };
    if (std.ascii.eqlIgnoreCase(fontname, "AvantGarde-BookOblique")) return .{ .ps_family = "AvantGarde-BookOblique,sans-Serif", .gd_family = "URW Gothic L,sans-Serif", .svg_family = "sans-Serif", .weight = "book", .style = "oblique", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "AvantGarde-Demi")) return .{ .ps_family = "AvantGarde-Demi,sans-Serif", .gd_family = "URW Gothic L,sans-Serif", .svg_family = "sans-Serif", .weight = "demi", .svg_weight = "bold" };
    if (std.ascii.eqlIgnoreCase(fontname, "AvantGarde-DemiOblique")) return .{ .ps_family = "AvantGarde-DemiOblique,sans-Serif", .gd_family = "URW Gothic L,sans-Serif", .svg_family = "sans-Serif", .weight = "demi", .style = "oblique", .svg_weight = "bold", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Bookman-Demi")) return .{ .ps_family = "Bookman-Demi,serif", .gd_family = "URW Bookman L,serif", .svg_family = "serif", .weight = "demi", .svg_weight = "bold" };
    if (std.ascii.eqlIgnoreCase(fontname, "Bookman-DemiItalic")) return .{ .ps_family = "Bookman-DemiItalic,serif", .gd_family = "URW Bookman L,serif", .svg_family = "serif", .weight = "demi", .style = "italic", .svg_weight = "bold", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Bookman-Light")) return .{ .ps_family = "Bookman-Light,serif", .gd_family = "URW Bookman L,serif", .svg_family = "serif", .weight = "light" };
    if (std.ascii.eqlIgnoreCase(fontname, "Bookman-LightItalic")) return .{ .ps_family = "Bookman-LightItalic,serif", .gd_family = "URW Bookman L,serif", .svg_family = "serif", .weight = "light", .style = "italic", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Times-Roman")) return .{ .ps_family = "Times-Roman,serif", .gd_family = "Times,serif", .svg_family = "serif" };
    if (std.ascii.eqlIgnoreCase(fontname, "Times-Bold")) return .{ .ps_family = "Times-Bold,serif", .gd_family = "Times,serif", .svg_family = "serif", .weight = "bold", .svg_weight = "bold" };
    if (std.ascii.eqlIgnoreCase(fontname, "Times-Italic")) return .{ .ps_family = "Times-Italic,serif", .gd_family = "Times,serif", .svg_family = "serif", .style = "italic", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Times-BoldItalic")) return .{ .ps_family = "Times-BoldItalic,serif", .gd_family = "Times,serif", .svg_family = "serif", .weight = "bold", .style = "italic", .svg_weight = "bold", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Courier")) return .{ .ps_family = "Courier,monospace", .gd_family = "Courier,monospace", .svg_family = "monospace" };
    if (std.ascii.eqlIgnoreCase(fontname, "Courier-Bold")) return .{ .ps_family = "Courier-Bold,monospace", .gd_family = "Courier,monospace", .svg_family = "monospace", .weight = "bold", .svg_weight = "bold" };
    if (std.ascii.eqlIgnoreCase(fontname, "Courier-Oblique")) return .{ .ps_family = "Courier-Oblique,monospace", .gd_family = "Courier,monospace", .svg_family = "monospace", .style = "oblique", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Courier-BoldOblique")) return .{ .ps_family = "Courier-BoldOblique,monospace", .gd_family = "Courier,monospace", .svg_family = "monospace", .weight = "bold", .style = "oblique", .svg_weight = "bold", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Helvetica")) return .{ .ps_family = "Helvetica,sans-Serif", .gd_family = "Helvetica,sans-Serif", .svg_family = "sans-Serif" };
    if (std.ascii.eqlIgnoreCase(fontname, "Helvetica-Bold")) return .{ .ps_family = "Helvetica-Bold,sans-Serif", .gd_family = "Helvetica,sans-Serif", .svg_family = "sans-Serif", .weight = "bold", .svg_weight = "bold" };
    if (std.ascii.eqlIgnoreCase(fontname, "Helvetica-Oblique")) return .{ .ps_family = "Helvetica-Oblique,sans-Serif", .gd_family = "Helvetica,sans-Serif", .svg_family = "sans-Serif", .style = "oblique", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Helvetica-BoldOblique")) return .{ .ps_family = "Helvetica-BoldOblique,sans-Serif", .gd_family = "Helvetica,sans-Serif", .svg_family = "sans-Serif", .weight = "bold", .style = "oblique", .svg_weight = "bold", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Helvetica-Narrow")) return .{ .ps_family = "Helvetica-Narrow,sans-Serif", .gd_family = "Helvetica,sans-Serif", .svg_family = "sans-Serif", .stretch = "condensed" };
    if (std.ascii.eqlIgnoreCase(fontname, "Helvetica-Narrow-Bold")) return .{ .ps_family = "Helvetica-Narrow-Bold,sans-Serif", .gd_family = "Helvetica,sans-Serif", .svg_family = "sans-Serif", .weight = "bold", .stretch = "condensed", .svg_weight = "bold" };
    if (std.ascii.eqlIgnoreCase(fontname, "Helvetica-Narrow-Oblique")) return .{ .ps_family = "Helvetica-Narrow-Oblique,sans-Serif", .gd_family = "Helvetica,sans-Serif", .svg_family = "sans-Serif", .stretch = "condensed", .style = "oblique", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Helvetica-Narrow-BoldOblique")) return .{ .ps_family = "Helvetica-Narrow-BoldOblique,sans-Serif", .gd_family = "Helvetica,sans-Serif", .svg_family = "sans-Serif", .weight = "bold", .stretch = "condensed", .style = "oblique", .svg_weight = "bold", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "NewCenturySchlbk-Bold")) return .{ .ps_family = "NewCenturySchlbk-Bold,serif", .gd_family = "Century Schoolbook L,serif", .svg_family = "serif", .weight = "bold", .svg_weight = "bold" };
    if (std.ascii.eqlIgnoreCase(fontname, "NewCenturySchlbk-BoldItalic")) return .{ .ps_family = "NewCenturySchlbk-BoldItalic,serif", .gd_family = "Century Schoolbook L,serif", .svg_family = "serif", .weight = "bold", .style = "italic", .svg_weight = "bold", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "NewCenturySchlbk-Italic")) return .{ .ps_family = "NewCenturySchlbk-Italic,serif", .gd_family = "Century Schoolbook L,serif", .svg_family = "serif", .style = "italic", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "NewCenturySchlbk-Roman")) return .{ .ps_family = "NewCenturySchlbk-Roman,serif", .gd_family = "Century Schoolbook L,serif", .svg_family = "serif", .weight = "roman" };
    if (std.ascii.eqlIgnoreCase(fontname, "Palatino-Bold")) return .{ .ps_family = "Palatino-Bold,serif", .gd_family = "Palatino Linotype,serif", .svg_family = "serif", .weight = "bold", .svg_weight = "bold" };
    if (std.ascii.eqlIgnoreCase(fontname, "Palatino-BoldItalic")) return .{ .ps_family = "Palatino-BoldItalic,serif", .gd_family = "Palatino Linotype,serif", .svg_family = "serif", .weight = "bold", .style = "italic", .svg_weight = "bold", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Palatino-Italic")) return .{ .ps_family = "Palatino-Italic,serif", .gd_family = "Palatino Linotype,serif", .svg_family = "serif", .style = "italic", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "Palatino-Roman")) return .{ .ps_family = "Palatino-Roman,serif", .gd_family = "Palatino Linotype,serif", .svg_family = "serif", .weight = "roman" };
    if (std.ascii.eqlIgnoreCase(fontname, "Symbol")) return .{ .ps_family = "Symbol,fantasy", .gd_family = "Symbol,fantasy", .svg_family = "fantasy" };
    if (std.ascii.eqlIgnoreCase(fontname, "ZapfChancery-MediumItalic")) return .{ .ps_family = "ZapfChancery-MediumItalic,serif", .gd_family = "URW Chancery L,serif", .svg_family = "serif", .weight = "medium", .style = "italic", .svg_style = "italic" };
    if (std.ascii.eqlIgnoreCase(fontname, "ZapfDingbats")) return .{ .ps_family = "ZapfDingbats,fantasy", .gd_family = "Dingbats,fantasy", .svg_family = "fantasy" };
    return null;
}
