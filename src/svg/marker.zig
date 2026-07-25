//! SVG marker and Graphviz arrow-shape helpers.

const std = @import("std");
const Io = std.Io;

pub const Shape = enum {
    none,
    gap,
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

pub const Side = enum {
    both,
    left,
    right,
};

pub const Part = struct {
    shape: Shape = .none,
    side: Side = .both,
};

pub const Spec = struct {
    parts: [4]Part = [_]Part{.{}} ** 4,
    len: u3 = 0,

    pub fn none() Spec {
        return .{};
    }

    pub fn single(shape: Shape) Spec {
        if (shape == .none) return .{};
        var result = Spec{};
        result.parts[0] = .{ .shape = shape };
        result.len = 1;
        return result;
    }

    pub fn isNone(self: Spec) bool {
        return self.len == 0;
    }

    pub fn isSingleNormal(self: Spec) bool {
        return self.len == 1 and self.parts[0].shape == .normal and self.parts[0].side == .both;
    }

    pub fn needsDef(self: Spec) bool {
        return !self.isNone() and !self.isSingleNormal();
    }

    pub fn lengthScale(self: Spec) f64 {
        var result: f64 = 0;
        for (self.parts[0..self.len]) |part| result += shapeLengthScale(part.shape);
        return result;
    }
};

pub const AttrOptions = struct {
    start: Spec,
    end: Spec,
    scale: f64,
};

pub fn writeDef(writer: *Io.Writer, edge_id: usize, suffix: []const u8, spec: Spec, stroke: []const u8, fill: []const u8, scale: f64) Io.Writer.Error!void {
    if (scale <= 0 or spec.isNone()) return;
    const segment_width: f64 = 10.0;
    const length_scale = spec.lengthScale();
    const marker_height = 7.0 * scale;
    const marker_width = marker_height * length_scale;
    const view_width = segment_width * length_scale;
    try writer.print("<marker id=\"arrow-{d}-{s}\" viewBox=\"0 0 {d:.1} 10\" refX=\"{d:.1}\" refY=\"5\" markerWidth=\"{d:.2}\" markerHeight=\"{d:.2}\" orient=\"auto", .{ edge_id, suffix, view_width, view_width, marker_width, marker_height });
    if (std.mem.eql(u8, suffix, "tail")) try writer.writeAll("-start-reverse");
    try writer.writeAll("\">");
    var cursor = view_width;
    for (spec.parts[0..spec.len], 0..) |part, index| {
        const part_width = segment_width * shapeLengthScale(part.shape);
        const offset = cursor - refX(part.shape);
        cursor -= part_width;
        if (part.side != .both) {
            try writer.print("<clipPath id=\"arrow-{d}-{s}-clip-{d}\"><rect x=\"0\" y=\"", .{ edge_id, suffix, index });
            try writer.writeAll(if (part.side == .left) "0" else "5");
            try writer.writeAll("\" width=\"10\" height=\"5\"/></clipPath>");
        }
        try writer.print("<g transform=\"translate({d:.1} 0)\"", .{offset});
        if (part.side != .both) {
            try writer.print(" clip-path=\"url(#arrow-{d}-{s}-clip-{d})\"", .{ edge_id, suffix, index });
        }
        try writer.writeByte('>');
        try writeShape(writer, part.shape, stroke, fill);
        try writer.writeAll("</g>");
    }
    try writer.writeAll("</marker>\n");
}

fn writeShape(writer: *Io.Writer, shape: Shape, stroke: []const u8, fill: []const u8) Io.Writer.Error!void {
    switch (shape) {
        .none, .gap => {},
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
}

pub fn writeAttrs(writer: *Io.Writer, directed: bool, edge_id: usize, options: AttrOptions) Io.Writer.Error!void {
    if (!directed) return;
    if (options.scale <= 0) return;
    if (options.start.needsDef()) try writer.print(" marker-start=\"url(#arrow-{d}-tail)\"", .{edge_id});
    if (options.end.needsDef()) try writer.print(" marker-end=\"url(#arrow-{d}-head)\"", .{edge_id});
}

pub fn parseShape(value: ?[]const u8, fallback: Shape) Shape {
    const spec = parseSpec(value, fallback);
    return if (spec.len > 0) spec.parts[0].shape else .none;
}

pub fn parseSpec(value: ?[]const u8, fallback: Shape) Spec {
    const text = value orelse return Spec.single(fallback);
    if (text.len == 0) return Spec.single(fallback);
    var result = Spec{};
    var offset: usize = 0;
    while (offset < text.len and result.len < result.parts.len) {
        const parsed = parsePart(text[offset..]) orelse
            return if (result.len > 0) result else Spec.single(fallback);
        if (parsed.part.shape == .gap and result.len == 0 and parsed.consumed == text.len) return .{};
        if (!(parsed.part.shape == .gap and result.len == result.parts.len - 1)) {
            result.parts[result.len] = parsed.part;
            result.len += 1;
        }
        offset += parsed.consumed;
    }
    if (offset != text.len and result.len < result.parts.len) return Spec.single(fallback);
    return result;
}

const ParsedPart = struct {
    part: Part,
    consumed: usize,
};

fn parsePart(text: []const u8) ?ParsedPart {
    if (startsWithIgnoreCase(text, "invempty")) {
        return .{ .part = .{ .shape = .oinv }, .consumed = "invempty".len };
    }
    var offset: usize = 0;
    var open = false;
    var side = Side.both;
    while (offset < text.len) {
        if (startsWithIgnoreCase(text[offset..], "half")) {
            side = .left;
            offset += "half".len;
        } else if (startsWithIgnoreCase(text[offset..], "o") or startsWithIgnoreCase(text[offset..], "e")) {
            open = true;
            offset += 1;
        } else if (startsWithIgnoreCase(text[offset..], "l")) {
            side = .left;
            offset += 1;
        } else if (startsWithIgnoreCase(text[offset..], "r")) {
            side = .right;
            offset += 1;
        } else break;
    }
    const base = parseBase(text[offset..]) orelse return null;
    open = open or base.open;
    var shape = base.shape;
    if (shape == .normal and base.inverted) {
        shape = if (open) .oinv else .inv;
    } else if (shape == .normal and open) {
        shape = .empty;
    } else if (shape == .dot and open) {
        shape = .odot;
    } else if (shape == .box and open) {
        shape = .obox;
    } else if (shape == .diamond and open) {
        shape = .odiamond;
    } else if (shape == .curve and base.inverted) {
        shape = .icurve;
    } else if (shape == .crow and base.inverted) {
        shape = .vee;
    }
    return .{
        .part = .{ .shape = shape, .side = side },
        .consumed = offset + base.consumed,
    };
}

const ParsedBase = struct {
    shape: Shape,
    inverted: bool = false,
    open: bool = false,
    consumed: usize,
};

fn parseBase(text: []const u8) ?ParsedBase {
    const names = [_]struct {
        name: []const u8,
        shape: Shape,
        inverted: bool = false,
        open: bool = false,
    }{
        .{ .name = "normal", .shape = .normal },
        .{ .name = "diamond", .shape = .diamond },
        .{ .name = "icurve", .shape = .curve, .inverted = true },
        .{ .name = "curve", .shape = .curve },
        .{ .name = "empty", .shape = .normal, .open = true },
        .{ .name = "mpty", .shape = .normal, .open = true },
        .{ .name = "crow", .shape = .crow },
        .{ .name = "open", .shape = .crow, .inverted = true },
        .{ .name = "pen", .shape = .crow, .inverted = true },
        .{ .name = "box", .shape = .box },
        .{ .name = "dot", .shape = .dot },
        .{ .name = "tee", .shape = .tee },
        .{ .name = "none", .shape = .gap },
        .{ .name = "inv", .shape = .normal, .inverted = true },
        .{ .name = "vee", .shape = .crow, .inverted = true },
    };
    for (names) |entry| {
        if (!startsWithIgnoreCase(text, entry.name)) continue;
        return .{
            .shape = entry.shape,
            .inverted = entry.inverted,
            .open = entry.open,
            .consumed = entry.name.len,
        };
    }
    return null;
}

fn startsWithIgnoreCase(text: []const u8, prefix: []const u8) bool {
    return text.len >= prefix.len and std.ascii.eqlIgnoreCase(text[0..prefix.len], prefix);
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

fn shapeLengthScale(shape: Shape) f64 {
    return switch (shape) {
        .none => 0,
        .gap, .tee => 0.5,
        .dot, .odot => 0.8,
        .diamond, .odiamond => 1.2,
        else => 1.0,
    };
}
