//! Layout option resolution from graph attributes.

const std = @import("std");

const spacing = @import("spacing.zig");

pub const defaultInterClusterGap: f64 = 35.0;
pub const defaultClusterAlongExtentBudget: f64 = 224.0;
pub const defaultClusterAlongShift: f64 = 4.0;

pub const LayoutOptions = struct {
    node_width: f64 = 54,
    node_height: f64 = 36,
    rank_gap: f64 = 36,
    node_gap: f64 = 36,
    margin: f64 = 16,
    margin_y: f64 = 5.5,
    label_char_width: f64 = 8,
    label_line_height: f64 = 18,
    node_padding_x: f64 = 14,
    node_padding_y: f64 = 9,
    quantum: f64 = 0,
    crossing_passes: usize = 24,
    crossing_min_quit: usize = 8,
    coordinate_passes: usize = 4,
    ranksep_equally: bool = false,
};

pub const ForceLayoutOptions = struct {
    width: f64 = 640,
    height: f64 = 420,
    margin: f64 = 40,
    iterations: usize = 120,
    area_scale: f64 = 1.0,
};

pub const IncrementalLayoutOptions = struct {
    stability: f64 = 0.9,
};

pub const LayoutControl = struct {
    context: ?*anyopaque = null,
    should_cancel: ?*const fn (context: ?*anyopaque, work: usize) bool = null,

    pub fn checkpoint(self: LayoutControl, work: usize) error{LayoutCanceled}!void {
        const callback = self.should_cancel orelse return;
        if (callback(self.context, work)) return error.LayoutCanceled;
    }
};

pub const LayoutWorkBudget = struct {
    limit: usize,
    checkpoints: usize = 0,
    last_work: usize = 0,

    pub fn control(self: *LayoutWorkBudget) LayoutControl {
        return .{
            .context = self,
            .should_cancel = shouldCancel,
        };
    }

    fn shouldCancel(context: ?*anyopaque, work: usize) bool {
        const self: *LayoutWorkBudget = @ptrCast(@alignCast(context.?));
        self.checkpoints += 1;
        self.last_work = work;
        return work > self.limit;
    }
};

pub const LayoutAlgorithm = enum {
    auto,
    sugiyama,
    fruchterman_reingold,
    stress_majorization,
    spring_electrical,
    multilevel_spring_electrical,
    radial,
    circular,
    treemap,
    array_packing,
    positioned,
    positioned_with_edges,

    pub fn fromString(value: []const u8) ?LayoutAlgorithm {
        if (std.ascii.eqlIgnoreCase(value, "auto")) return .auto;
        if (std.ascii.eqlIgnoreCase(value, "dot") or
            std.ascii.eqlIgnoreCase(value, "sugiyama") or
            std.ascii.eqlIgnoreCase(value, "layered"))
        {
            return .sugiyama;
        }
        if (std.ascii.eqlIgnoreCase(value, "neato") or
            std.ascii.eqlIgnoreCase(value, "stress") or
            std.ascii.eqlIgnoreCase(value, "stress-majorization") or
            std.ascii.eqlIgnoreCase(value, "stress_majorization"))
        {
            return .stress_majorization;
        }
        if (std.ascii.eqlIgnoreCase(value, "fdp") or
            std.ascii.eqlIgnoreCase(value, "spring-electrical") or
            std.ascii.eqlIgnoreCase(value, "spring_electrical"))
        {
            return .spring_electrical;
        }
        if (std.ascii.eqlIgnoreCase(value, "sfdp") or
            std.ascii.eqlIgnoreCase(value, "multilevel-spring-electrical") or
            std.ascii.eqlIgnoreCase(value, "multilevel_spring_electrical"))
        {
            return .multilevel_spring_electrical;
        }
        if (std.ascii.eqlIgnoreCase(value, "twopi") or
            std.ascii.eqlIgnoreCase(value, "radial"))
        {
            return .radial;
        }
        if (std.ascii.eqlIgnoreCase(value, "circo") or
            std.ascii.eqlIgnoreCase(value, "circular"))
        {
            return .circular;
        }
        if (std.ascii.eqlIgnoreCase(value, "patchwork") or
            std.ascii.eqlIgnoreCase(value, "treemap"))
        {
            return .treemap;
        }
        if (std.ascii.eqlIgnoreCase(value, "osage") or
            std.ascii.eqlIgnoreCase(value, "array-packing") or
            std.ascii.eqlIgnoreCase(value, "array_packing"))
        {
            return .array_packing;
        }
        if (std.ascii.eqlIgnoreCase(value, "nop") or
            std.ascii.eqlIgnoreCase(value, "nop1") or
            std.ascii.eqlIgnoreCase(value, "positioned"))
        {
            return .positioned;
        }
        if (std.ascii.eqlIgnoreCase(value, "nop2") or
            std.ascii.eqlIgnoreCase(value, "positioned-with-edges") or
            std.ascii.eqlIgnoreCase(value, "positioned_with_edges"))
        {
            return .positioned_with_edges;
        }
        if (std.ascii.eqlIgnoreCase(value, "fr") or
            std.ascii.eqlIgnoreCase(value, "force") or
            std.ascii.eqlIgnoreCase(value, "fruchterman-reingold") or
            std.ascii.eqlIgnoreCase(value, "fruchterman_reingold"))
        {
            return .fruchterman_reingold;
        }
        return null;
    }

    pub fn name(self: LayoutAlgorithm) []const u8 {
        return switch (self) {
            .auto => "auto",
            .sugiyama => "dot",
            .fruchterman_reingold => "fr",
            .stress_majorization => "neato",
            .spring_electrical => "fdp",
            .multilevel_spring_electrical => "sfdp",
            .radial => "twopi",
            .circular => "circo",
            .treemap => "patchwork",
            .array_packing => "osage",
            .positioned => "nop",
            .positioned_with_edges => "nop2",
        };
    }
};

pub const LayoutConfig = struct {
    algorithm: LayoutAlgorithm = .auto,
    layered: LayoutOptions = .{},
    force: ForceLayoutOptions = .{},
    control: LayoutControl = .{},
};

pub fn withGraphAttrs(base: LayoutOptions, graph_attrs: anytype) LayoutOptions {
    var result = base;
    if (attrValue(graph_attrs, "ranksep")) |value| {
        result.rank_gap = spacing.graph(value, result.rank_gap);
        result.ranksep_equally = spacing.hasWord(value, "equally");
    }
    if (attrValue(graph_attrs, "nodesep")) |value| {
        result.node_gap = spacing.graph(value, result.node_gap);
    }
    if (attrValue(graph_attrs, "quantum")) |value| {
        if (positiveAttrFloatValue(value)) |inches| result.quantum = inches * 72.0;
    }
    if (attrValue(graph_attrs, "mclimit")) |value| {
        if (positiveAttrFloatValue(value)) |scale| {
            result.crossing_passes = scaledPositiveUsize(24, scale);
            result.crossing_min_quit = scaledPositiveUsize(8, scale);
        }
    }
    if (attrValue(graph_attrs, "vex_crossing_passes") orelse attrValue(graph_attrs, "crossing_passes")) |value| {
        result.crossing_passes = attrUsize(value, result.crossing_passes);
    }
    if (attrValue(graph_attrs, "vex_coordinate_passes") orelse attrValue(graph_attrs, "coordinate_passes")) |value| {
        result.coordinate_passes = attrUsize(value, result.coordinate_passes);
    }
    if (attrValue(graph_attrs, "margin") != null) {
        const margin = attrMargin(graph_attrs, result.margin);
        result.margin = margin.x;
        result.margin_y = margin.y;
    }
    if (attrValue(graph_attrs, "label") != null) {
        const font_size = positiveAttrFloat(graph_attrs, "fontsize", 14.0);
        result.margin_y = @max(result.margin_y, font_size + 12.0);
    }
    return result;
}

pub fn withForceGraphAttrs(base: ForceLayoutOptions, graph_attrs: anytype) ForceLayoutOptions {
    var result = base;
    if (attrValue(graph_attrs, "vex_layout_iterations") orelse attrValue(graph_attrs, "layout_iterations")) |value| {
        result.iterations = positiveAttrUsize(value, result.iterations);
    } else if (attrValue(graph_attrs, "maxiter")) |value| {
        result.iterations = attrUsize(value, result.iterations);
    }
    return result;
}

pub fn clusterAlongBudget(along_margin: f64) f64 {
    return @max(0.0, defaultClusterAlongExtentBudget - along_margin * 2.0);
}

pub const BoxMargin = struct {
    x: f64,
    y: f64,
};

pub fn attrMargin(attrs: anytype, fallback: f64) BoxMargin {
    const value = attrValue(attrs, "margin") orelse return .{ .x = fallback, .y = fallback };
    var parts = std.mem.tokenizeAny(u8, value, ", \t");
    const first = parts.next() orelse return .{ .x = fallback, .y = fallback };
    const x = parseInchMargin(first) orelse fallback;
    const y = if (parts.next()) |second| parseInchMargin(second) orelse x else x;
    return .{ .x = x, .y = y };
}

pub fn clusterMargin(attrs: anytype, fallback: f64) BoxMargin {
    const value = attrValue(attrs, "margin") orelse return .{ .x = fallback, .y = fallback };
    const margin = parseGraphvizIntMargin(value, fallback);
    return .{ .x = margin, .y = margin };
}

fn positiveAttrFloat(attrs: anytype, name: []const u8, fallback: f64) f64 {
    const value = attrValue(attrs, name) orelse return fallback;
    return positiveAttrFloatValue(value) orelse fallback;
}

fn positiveAttrFloatValue(value: []const u8) ?f64 {
    const parsed = std.fmt.parseFloat(f64, value) catch return null;
    return if (std.math.isFinite(parsed) and parsed > 0) parsed else null;
}

fn scaledPositiveUsize(value: usize, scale: f64) usize {
    const scaled = @as(f64, @floatFromInt(value)) * scale;
    if (!std.math.isFinite(scaled) or scaled >= @as(f64, @floatFromInt(std.math.maxInt(usize)))) {
        return std.math.maxInt(usize);
    }
    return @max(1, @as(usize, @intFromFloat(scaled)));
}

fn positiveAttrUsize(value: []const u8, fallback: usize) usize {
    const parsed = attrUsize(value, fallback);
    return if (parsed > 0) parsed else fallback;
}

fn attrUsize(value: []const u8, fallback: usize) usize {
    return std.fmt.parseInt(usize, value, 10) catch fallback;
}

fn parseInchMargin(value: []const u8) ?f64 {
    const inches = std.fmt.parseFloat(f64, value) catch return null;
    if (inches < 0) return null;
    return inches * 72.0;
}

fn parseGraphvizIntMargin(value: []const u8, fallback: f64) f64 {
    var start: usize = 0;
    while (start < value.len and std.ascii.isWhitespace(value[start])) start += 1;
    const trimmed = value[start..];
    if (trimmed.len == 0) return fallback;
    var end: usize = 0;
    if (trimmed[0] == '+' or trimmed[0] == '-') end = 1;
    const digit_start = end;
    while (end < trimmed.len and std.ascii.isDigit(trimmed[end])) end += 1;
    if (end == digit_start) return fallback;
    if (trimmed[0] == '-') return 0;
    const parsed = std.fmt.parseInt(i64, trimmed[0..end], 10) catch return fallback;
    if (parsed > std.math.maxInt(i32)) return fallback;
    return @floatFromInt(parsed);
}

fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    for (attrs) |attr| {
        if (std.ascii.eqlIgnoreCase(attr.name, name)) return attr.value;
    }
    return null;
}
