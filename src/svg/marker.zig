//! SVG marker and Graphviz arrow-shape helpers.

const std = @import("std");
const Io = std.Io;

pub const Shape = enum {
    none,
    normal,
    open,
    inv,
    oinv,
    curve,
    icurve,
    vee,
    dot,
    odot,
    box,
    obox,
    diamond,
    odiamond,
    tee,
    crow,
    empty,
};

pub const AttrOptions = struct {
    start: Shape,
    end: Shape,
    scale: f64,
};

pub fn writeDef(writer: *Io.Writer, edge_id: usize, suffix: []const u8, shape: Shape, stroke: []const u8, fill: []const u8, scale: f64) Io.Writer.Error!void {
    if (scale <= 0) return;
    const marker_size = 7.0 * scale;
    try writer.print("<marker id=\"arrow-{d}-{s}\" viewBox=\"0 0 10 10\" refX=\"{d:.1}\" refY=\"5\" markerWidth=\"{d:.2}\" markerHeight=\"{d:.2}\" orient=\"auto", .{ edge_id, suffix, refX(shape), marker_size, marker_size });
    if (std.mem.eql(u8, suffix, "tail")) try writer.writeAll("-start-reverse");
    try writer.writeAll("\">");
    switch (shape) {
        .none => {},
        .normal => try writer.print("<path d=\"M 1.2 1.4 L 9.2 5 L 1.2 8.6 z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"0.5\"/>", .{ fill, stroke }),
        .open => try writer.print("<path d=\"M 1 1 L 9 5 L 1 9\" fill=\"none\" stroke=\"{s}\" stroke-width=\"1.4\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>", .{stroke}),
        .inv => try writer.print("<path d=\"M 9 1.4 L 0.8 5 L 9 8.6 z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"0.5\"/>", .{ fill, stroke }),
        .oinv => try writer.print("<path d=\"M 9 1.4 L 0.8 5 L 9 8.6 z\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{stroke}),
        .curve => try writer.print("<path d=\"M 1.5 1.2 C 8.5 1.2 8.5 8.8 1.5 8.8\" fill=\"none\" stroke=\"{s}\" stroke-width=\"1.6\" stroke-linecap=\"round\"/>", .{stroke}),
        .icurve => try writer.print("<path d=\"M 8.5 1.2 C 1.5 1.2 1.5 8.8 8.5 8.8\" fill=\"none\" stroke=\"{s}\" stroke-width=\"1.6\" stroke-linecap=\"round\"/>", .{stroke}),
        .vee => try writer.print("<path d=\"M 1 1 L 9 5 L 1 9\" fill=\"none\" stroke=\"{s}\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>", .{stroke}),
        .dot => try writer.print("<circle cx=\"5\" cy=\"5\" r=\"4\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"0.5\"/>", .{ fill, stroke }),
        .odot => try writer.print("<circle cx=\"5\" cy=\"5\" r=\"3.5\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{stroke}),
        .box => try writer.print("<rect x=\"1.5\" y=\"1.5\" width=\"7\" height=\"7\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"0.5\"/>", .{ fill, stroke }),
        .obox => try writer.print("<rect x=\"1.5\" y=\"1.5\" width=\"7\" height=\"7\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{stroke}),
        .diamond => try writer.print("<path d=\"M 5 0.8 L 9.2 5 L 5 9.2 L 0.8 5 z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"0.5\"/>", .{ fill, stroke }),
        .odiamond => try writer.print("<path d=\"M 5 0.8 L 9.2 5 L 5 9.2 L 0.8 5 z\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{stroke}),
        .tee => try writer.print("<path d=\"M 8.5 1 L 8.5 9\" fill=\"none\" stroke=\"{s}\" stroke-width=\"2\" stroke-linecap=\"round\"/>", .{stroke}),
        .crow => try writer.print("<path d=\"M 9 1 L 1 5 L 9 9 M 1 5 L 9 5\" fill=\"none\" stroke=\"{s}\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>", .{stroke}),
        .empty => try writer.print("<path d=\"M 0.8 0.8 L 9.2 5 L 0.8 9.2 z\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{stroke}),
    }
    try writer.writeAll("</marker>\n");
}

pub fn writeAttrs(writer: *Io.Writer, directed: bool, edge_id: usize, options: AttrOptions) Io.Writer.Error!void {
    if (!directed) return;
    if (options.scale <= 0) return;
    if (options.start != .none and options.start != .normal) try writer.print(" marker-start=\"url(#arrow-{d}-tail)\"", .{edge_id});
    if (options.end != .none and options.end != .normal) try writer.print(" marker-end=\"url(#arrow-{d}-head)\"", .{edge_id});
}

pub fn parseShape(value: ?[]const u8, fallback: Shape) Shape {
    const text = value orelse return fallback;
    if (std.ascii.eqlIgnoreCase(text, "none")) return .none;
    if (std.ascii.eqlIgnoreCase(text, "normal")) return .normal;
    if (std.ascii.eqlIgnoreCase(text, "lnormal") or std.ascii.eqlIgnoreCase(text, "rnormal")) return .normal;
    if (std.ascii.eqlIgnoreCase(text, "open")) return .open;
    if (std.ascii.eqlIgnoreCase(text, "halfopen")) return .open;
    if (std.ascii.eqlIgnoreCase(text, "onormal")) return .empty;
    if (std.ascii.eqlIgnoreCase(text, "olnormal") or std.ascii.eqlIgnoreCase(text, "ornormal")) return .empty;
    if (std.ascii.eqlIgnoreCase(text, "inv")) return .inv;
    if (std.ascii.eqlIgnoreCase(text, "linv") or std.ascii.eqlIgnoreCase(text, "rinv")) return .inv;
    if (std.ascii.eqlIgnoreCase(text, "oinv")) return .oinv;
    if (std.ascii.eqlIgnoreCase(text, "olinv") or std.ascii.eqlIgnoreCase(text, "orinv")) return .oinv;
    if (std.ascii.eqlIgnoreCase(text, "invempty")) return .oinv;
    if (std.ascii.eqlIgnoreCase(text, "curve")) return .curve;
    if (std.ascii.eqlIgnoreCase(text, "icurve")) return .icurve;
    if (std.ascii.eqlIgnoreCase(text, "lcurve") or std.ascii.eqlIgnoreCase(text, "rcurve")) return .curve;
    if (std.ascii.eqlIgnoreCase(text, "licurve") or std.ascii.eqlIgnoreCase(text, "ricurve")) return .icurve;
    if (std.ascii.eqlIgnoreCase(text, "vee")) return .vee;
    if (std.ascii.eqlIgnoreCase(text, "lvee") or std.ascii.eqlIgnoreCase(text, "rvee")) return .vee;
    if (std.ascii.eqlIgnoreCase(text, "dot")) return .dot;
    if (std.ascii.eqlIgnoreCase(text, "invdot")) return .dot;
    if (std.ascii.eqlIgnoreCase(text, "odot")) return .odot;
    if (std.ascii.eqlIgnoreCase(text, "invodot") or std.ascii.eqlIgnoreCase(text, "oinvdot")) return .odot;
    if (std.ascii.eqlIgnoreCase(text, "box")) return .box;
    if (std.ascii.eqlIgnoreCase(text, "lbox") or std.ascii.eqlIgnoreCase(text, "rbox")) return .box;
    if (std.ascii.eqlIgnoreCase(text, "obox")) return .obox;
    if (std.ascii.eqlIgnoreCase(text, "olbox") or std.ascii.eqlIgnoreCase(text, "orbox")) return .obox;
    if (std.ascii.eqlIgnoreCase(text, "diamond")) return .diamond;
    if (std.ascii.eqlIgnoreCase(text, "ldiamond") or std.ascii.eqlIgnoreCase(text, "rdiamond")) return .diamond;
    if (std.ascii.eqlIgnoreCase(text, "ediamond")) return .odiamond;
    if (std.ascii.eqlIgnoreCase(text, "odiamond")) return .odiamond;
    if (std.ascii.eqlIgnoreCase(text, "oldiamond") or std.ascii.eqlIgnoreCase(text, "ordiamond")) return .odiamond;
    if (std.ascii.eqlIgnoreCase(text, "tee")) return .tee;
    if (std.ascii.eqlIgnoreCase(text, "ltee") or std.ascii.eqlIgnoreCase(text, "rtee")) return .tee;
    if (std.ascii.eqlIgnoreCase(text, "crow")) return .crow;
    if (std.ascii.eqlIgnoreCase(text, "lcrow") or std.ascii.eqlIgnoreCase(text, "rcrow")) return .crow;
    if (std.ascii.eqlIgnoreCase(text, "empty")) return .empty;
    return fallback;
}

pub fn enabledByDir(dir: ?[]const u8, head: bool) bool {
    const value = dir orelse return head;
    if (std.ascii.eqlIgnoreCase(value, "none")) return false;
    if (std.ascii.eqlIgnoreCase(value, "both")) return true;
    if (std.ascii.eqlIgnoreCase(value, "back")) return !head;
    if (std.ascii.eqlIgnoreCase(value, "forward")) return head;
    return head;
}

fn refX(shape: Shape) f64 {
    return switch (shape) {
        .normal => 9.2,
        else => 9.0,
    };
}
