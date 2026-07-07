//! Layout-aware terminal renderer.
//!
//! This backend intentionally stays small and Vex-local: it consumes the public
//! graph/layout shape through comptime field access and paints a box-drawing
//! canvas without depending on the rest of `root.zig`.

const std = @import("std");
const Io = std.Io;

pub const RenderError = Io.Writer.Error || std.mem.Allocator.Error;

pub const default_html_pre_style = "font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; line-height: 1.2; white-space: pre;";

pub const Options = struct {
    unicode: bool = true,
    color_mode: ColorMode = .none,
    output_format: OutputFormat = .raw,
    hyperlinks: bool = false,
    target_width: usize = 120,
    target_height: usize = 40,
    padding: usize = 2,
    x_scale: f64 = 0.24,
    y_scale: f64 = 0.10,
    show_title: bool = false,
    show_edge_labels: bool = true,
    show_cluster_labels: bool = true,
    html_pre_style: []const u8 = default_html_pre_style,
};

pub const ColorMode = enum {
    none,
    ansi256,
    truecolor,
};

pub const OutputFormat = enum {
    raw,
    html_pre,
};

pub const Rgb = struct {
    r: u8,
    g: u8,
    b: u8,

    fn eql(a: Rgb, b: Rgb) bool {
        return a.r == b.r and a.g == b.g and a.b == b.b;
    }
};

pub const Color = union(enum) {
    default,
    rgb: Rgb,

    fn isSet(self: Color) bool {
        return switch (self) {
            .default => false,
            .rgb => true,
        };
    }

    fn eql(a: Color, b: Color) bool {
        return switch (a) {
            .default => switch (b) {
                .default => true,
                .rgb => false,
            },
            .rgb => |a_rgb| switch (b) {
                .default => false,
                .rgb => |b_rgb| a_rgb.eql(b_rgb),
            },
        };
    }
};

pub const TextAttrs = packed struct {
    bold: bool = false,
    dim: bool = false,
    underline: bool = false,
    _pad: u5 = 0,

    fn isSet(self: TextAttrs) bool {
        return self.bold or self.dim or self.underline;
    }

    fn eql(a: TextAttrs, b: TextAttrs) bool {
        return a.bold == b.bold and a.dim == b.dim and a.underline == b.underline;
    }
};

const Style = struct {
    fg: Color = .default,
    bg: Color = .default,
    attrs: TextAttrs = .{},
    link: ?[]const u8 = null,
    title: ?[]const u8 = null,
    kind: ?[]const u8 = null,

    fn isSet(self: Style) bool {
        return self.fg.isSet() or self.bg.isSet() or self.attrs.isSet() or self.link != null or self.title != null or self.kind != null;
    }

    fn eql(a: Style, b: Style) bool {
        return a.fg.eql(b.fg) and
            a.bg.eql(b.bg) and
            a.attrs.eql(b.attrs) and
            optionalEql(a.link, b.link) and
            optionalEql(a.title, b.title) and
            optionalEql(a.kind, b.kind);
    }
};

const Dir = enum {
    none,
    up,
    right,
    down,
    left,
};

const PointI = struct {
    x: i32,
    y: i32,
};

const RectI = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    fn right(self: RectI) i32 {
        return self.x + self.w - 1;
    }

    fn bottom(self: RectI) i32 {
        return self.y + self.h - 1;
    }

    fn center(self: RectI) PointI {
        return .{
            .x = self.x + @divTrunc(self.w, 2),
            .y = self.y + @divTrunc(self.h, 2),
        };
    }

    fn shift(self: *RectI, dx: i32, dy: i32) void {
        self.x += dx;
        self.y += dy;
    }
};

const NodeKind = enum {
    boxed,
    plain,
    point,
};

const NodePlan = struct {
    rect: RectI,
    kind: NodeKind,
    style: Style = .{},
};

const ClusterPlan = struct {
    rect: RectI,
    style: Style = .{},
};

const Cell = struct {
    mask: u4 = 0,
    marker: Dir = .none,
    byte: u8 = 0,
    style: Style = .{},

    fn empty(self: Cell) bool {
        return self.mask == 0 and self.marker == .none and self.byte == 0 and !self.style.isSet();
    }
};

const Canvas = struct {
    allocator: std.mem.Allocator,
    width: usize,
    height: usize,
    cells: []Cell,

    fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Canvas {
        const safe_width = @max(width, 1);
        const safe_height = @max(height, 1);
        const cells = try allocator.alloc(Cell, safe_width * safe_height);
        @memset(cells, .{});
        return .{
            .allocator = allocator,
            .width = safe_width,
            .height = safe_height,
            .cells = cells,
        };
    }

    fn deinit(self: *Canvas) void {
        self.allocator.free(self.cells);
        self.* = undefined;
    }

    fn index(self: *const Canvas, x: i32, y: i32) ?usize {
        if (x < 0 or y < 0) return null;
        const ux: usize = @intCast(x);
        const uy: usize = @intCast(y);
        if (ux >= self.width or uy >= self.height) return null;
        return uy * self.width + ux;
    }

    fn addMask(self: *Canvas, x: i32, y: i32, mask: u4) void {
        self.addMaskStyled(x, y, mask, .{});
    }

    fn addMaskStyled(self: *Canvas, x: i32, y: i32, mask: u4, style: Style) void {
        if (self.index(x, y)) |idx| {
            if (self.cells[idx].byte == 0) {
                self.cells[idx].mask |= mask;
                if (style.isSet()) self.cells[idx].style = style;
            }
        }
    }

    fn putByte(self: *Canvas, x: i32, y: i32, byte: u8) void {
        self.putByteStyled(x, y, byte, .{});
    }

    fn putByteStyled(self: *Canvas, x: i32, y: i32, byte: u8, style: Style) void {
        if (self.index(x, y)) |idx| {
            self.cells[idx].byte = byte;
            self.cells[idx].marker = .none;
            self.cells[idx].mask = 0;
            self.cells[idx].style = style;
        }
    }

    fn putMarker(self: *Canvas, x: i32, y: i32, dir: Dir) void {
        self.putMarkerStyled(x, y, dir, .{});
    }

    fn putMarkerStyled(self: *Canvas, x: i32, y: i32, dir: Dir, style: Style) void {
        if (self.index(x, y)) |idx| {
            if (self.cells[idx].byte == 0) {
                self.cells[idx].marker = dir;
                if (style.isSet()) self.cells[idx].style = style;
            }
        }
    }

    fn render(self: *const Canvas, writer: *Io.Writer, options: Options) Io.Writer.Error!void {
        switch (options.output_format) {
            .raw => try self.renderRaw(writer, options),
            .html_pre => try self.renderHtmlPre(writer, options),
        }
    }

    fn renderRaw(self: *const Canvas, writer: *Io.Writer, options: Options) Io.Writer.Error!void {
        var active: Style = .{};
        for (0..self.height) |y| {
            var end = self.width;
            while (end > 0 and self.cells[y * self.width + end - 1].empty()) : (end -= 1) {}
            for (0..end) |x| {
                const cell = self.cells[y * self.width + x];
                if (options.color_mode != .none and !cell.style.eql(active)) {
                    if (options.hyperlinks and active.link != null) try writeOsc8End(writer);
                    try writeAnsiReset(writer);
                    try writeAnsiStyle(writer, cell.style, options.color_mode);
                    if (options.hyperlinks) try writeOsc8Start(writer, cell.style.link);
                    active = cell.style;
                } else if (options.color_mode == .none and options.hyperlinks and !optionalEql(cell.style.link, active.link)) {
                    if (active.link != null) try writeOsc8End(writer);
                    try writeOsc8Start(writer, cell.style.link);
                    active = cell.style;
                }
                if (cell.byte != 0) {
                    try writer.writeByte(cell.byte);
                } else if (cell.marker != .none) {
                    try writer.writeAll(markerGlyph(cell.marker, options.unicode));
                } else {
                    try writer.writeAll(maskGlyph(cell.mask, options.unicode));
                }
            }
            if (options.color_mode != .none and active.isSet()) {
                if (options.hyperlinks and active.link != null) try writeOsc8End(writer);
                try writeAnsiReset(writer);
                active = .{};
            } else if (options.color_mode == .none and options.hyperlinks and active.link != null) {
                try writeOsc8End(writer);
                active = .{};
            }
            try writer.writeByte('\n');
        }
    }

    fn renderHtmlPre(self: *const Canvas, writer: *Io.Writer, options: Options) Io.Writer.Error!void {
        try writer.writeAll("<pre style=\"");
        try writer.writeAll(safeHtmlPreStyle(options.html_pre_style));
        try writer.writeAll("\">");
        for (0..self.height) |y| {
            var end = self.width;
            while (end > 0 and self.cells[y * self.width + end - 1].empty()) : (end -= 1) {}
            var active: Style = .{};
            var span_open = false;
            for (0..end) |x| {
                const cell = self.cells[y * self.width + x];
                if (!cell.style.eql(active)) {
                    if (span_open) try closeHtmlStyledRun(writer, active);
                    active = cell.style;
                    span_open = active.isSet();
                    if (span_open) try writeHtmlStyledRunOpen(writer, active);
                }
                if (cell.byte != 0) {
                    try writeHtmlByte(writer, cell.byte);
                } else if (cell.marker != .none) {
                    try writeHtmlEscaped(writer, markerGlyph(cell.marker, options.unicode));
                } else {
                    try writeHtmlEscaped(writer, maskGlyph(cell.mask, options.unicode));
                }
            }
            if (span_open) try closeHtmlStyledRun(writer, active);
            try writer.writeByte('\n');
        }
        try writer.writeAll("</pre>\n");
    }
};

const N: u4 = 1;
const E: u4 = 2;
const S: u4 = 4;
const W: u4 = 8;

pub fn renderGraph(writer: *Io.Writer, graph: anytype, layout: anytype, options: Options) RenderError!void {
    const allocator = graph.allocator;
    const node_count = graph.nodes.items.len;

    if (options.show_title) {
        try writer.print("{s} {s} ({d} nodes, {d} edges)\n", .{
            if (graph.directed) "digraph" else "graph",
            graph.name,
            graph.nodes.items.len,
            graph.edges.items.len,
        });
    }

    if (node_count == 0) {
        return;
    }

    const scale = chooseScale(layout, options);
    const padding: i32 = @intCast(@min(options.padding, 16));

    var node_plans = try allocator.alloc(NodePlan, node_count);
    defer allocator.free(node_plans);

    var min_x: i32 = std.math.maxInt(i32);
    var min_y: i32 = std.math.maxInt(i32);
    var max_x: i32 = std.math.minInt(i32);
    var max_y: i32 = std.math.minInt(i32);

    for (graph.nodes.items, 0..) |node_item, i| {
        const layout_node = layout.nodes[i];
        node_plans[i] = nodePlan(node_item, layout_node, scale, padding);
        includeRect(&min_x, &min_y, &max_x, &max_y, node_plans[i].rect);
    }

    var cluster_plans = try allocator.alloc(ClusterPlan, graph.clusters.items.len);
    defer allocator.free(cluster_plans);

    for (graph.clusters.items, 0..) |cluster_item, i| {
        const layout_cluster = layout.clusters[i];
        cluster_plans[i] = clusterPlan(cluster_item, layout_cluster, scale, padding, options);
        includeRect(&min_x, &min_y, &max_x, &max_y, cluster_plans[i].rect);
    }

    const shift_x = if (min_x < padding) padding - min_x else 0;
    const shift_y = if (min_y < padding) padding - min_y else 0;
    if (shift_x != 0 or shift_y != 0) {
        for (node_plans) |*plan| plan.rect.shift(shift_x, shift_y);
        for (cluster_plans) |*plan| plan.rect.shift(shift_x, shift_y);
        min_x += shift_x;
        max_x += shift_x;
        min_y += shift_y;
        max_y += shift_y;
    }

    const width: usize = @intCast(@max(max_x + padding + 1, 1));
    const height: usize = @intCast(@max(max_y + padding + 1, 1));
    var canvas = try Canvas.init(allocator, width, height);
    defer canvas.deinit();

    for (graph.clusters.items, 0..) |cluster_item, i| {
        paintCluster(&canvas, cluster_plans[i], cluster_item.label, options);
    }

    for (graph.edges.items) |edge_item| {
        paintEdge(&canvas, graph, layout, edge_item, node_plans, scale, padding, shift_x, shift_y, options);
    }

    for (graph.nodes.items, 0..) |node_item, i| {
        paintNode(&canvas, node_plans[i], node_item.label);
    }

    try canvas.render(writer, options);
}

const Scale = struct {
    x: f64,
    y: f64,
};

fn chooseScale(layout: anytype, options: Options) Scale {
    const target_width = @max(options.target_width, 20);
    const target_height = @max(options.target_height, 10);
    const padding = @as(f64, @floatFromInt(@min(options.padding, 16) * 2));
    const layout_width = @max(layout.width, 1.0);
    const layout_height = @max(layout.height, 1.0);
    const fit_x = (@as(f64, @floatFromInt(target_width)) - padding) / layout_width;
    const fit_y = (@as(f64, @floatFromInt(target_height)) - padding) / layout_height;
    return .{
        .x = @max(@min(options.x_scale, fit_x), 0.035),
        .y = @max(@min(options.y_scale, fit_y), 0.025),
    };
}

fn nodePlan(node_item: anytype, layout_node: anytype, scale: Scale, padding: i32) NodePlan {
    const kind = nodeKind(node_item.shape);
    const lines = labelLineCount(node_item.label);
    const label_width = labelMaxWidth(node_item.label);
    const cx = mapCoord(layout_node.center.x, scale.x, padding, 0);
    const cy = mapCoord(layout_node.center.y, scale.y, padding, 0);

    const rect = switch (kind) {
        .point => RectI{ .x = cx, .y = cy, .w = 1, .h = 1 },
        .plain => blk: {
            const w: i32 = @intCast(@max(label_width, 1));
            const h: i32 = @intCast(@max(lines, 1));
            break :blk centeredRect(cx, cy, w, h);
        },
        .boxed => blk: {
            const scaled_w: usize = @intFromFloat(@ceil(@max(layout_node.width * scale.x, 1.0)));
            const label_w = label_width + 4;
            const w: i32 = @intCast(@max(@max(scaled_w, label_w), 5));
            const h: i32 = @intCast(@max(lines + 2, 3));
            break :blk centeredRect(cx, cy, w, h);
        },
    };

    return .{ .rect = rect, .kind = kind, .style = nodeStyle(node_item) };
}

fn clusterPlan(cluster_item: anytype, layout_cluster: anytype, scale: Scale, padding: i32, options: Options) ClusterPlan {
    const x = mapCoord(layout_cluster.x, scale.x, padding, 0);
    const y = mapCoord(layout_cluster.y, scale.y, padding, 0);
    const w: i32 = @intCast(@max(@as(usize, @intFromFloat(@ceil(@max(layout_cluster.width * scale.x, 1.0)))), labelMaxWidth(cluster_item.label) + 4));
    const h: i32 = @intCast(@max(@as(usize, @intFromFloat(@ceil(@max(layout_cluster.height * scale.y, 1.0)))), 3));
    _ = options;
    return .{ .rect = .{ .x = x, .y = y, .w = w, .h = h }, .style = clusterStyle(cluster_item) };
}

fn nodeKind(shape: anytype) NodeKind {
    return switch (shape) {
        .plaintext => .plain,
        .point => .point,
        else => .boxed,
    };
}

fn centeredRect(cx: i32, cy: i32, w: i32, h: i32) RectI {
    return .{
        .x = cx - @divTrunc(w, 2),
        .y = cy - @divTrunc(h, 2),
        .w = w,
        .h = h,
    };
}

fn includeRect(min_x: *i32, min_y: *i32, max_x: *i32, max_y: *i32, rect: RectI) void {
    min_x.* = @min(min_x.*, rect.x);
    min_y.* = @min(min_y.*, rect.y);
    max_x.* = @max(max_x.*, rect.right());
    max_y.* = @max(max_y.*, rect.bottom());
}

fn mapCoord(value: f64, scale: f64, padding: i32, shift: i32) i32 {
    return padding + shift + @as(i32, @intFromFloat(@round(value * scale)));
}

fn mapPoint(point: anytype, scale: Scale, padding: i32, shift_x: i32, shift_y: i32) PointI {
    return .{
        .x = mapCoord(point.x, scale.x, padding, shift_x),
        .y = mapCoord(point.y, scale.y, padding, shift_y),
    };
}

fn paintCluster(canvas: *Canvas, plan: ClusterPlan, label: []const u8, options: Options) void {
    const rect = plan.rect;
    if (rect.w < 2 or rect.h < 2) return;
    drawRectStyled(canvas, rect, plan.style);
    if (options.show_cluster_labels and label.len > 0) {
        putTextStyled(canvas, rect.x + 2, rect.y, label, @max(rect.w - 4, 0), plan.style);
    }
}

fn paintNode(canvas: *Canvas, plan: NodePlan, label: []const u8) void {
    switch (plan.kind) {
        .point => canvas.putByteStyled(plan.rect.x, plan.rect.y, '*', plan.style),
        .plain => paintLabelBlockStyled(canvas, plan.rect, label, plan.style),
        .boxed => {
            drawRectStyled(canvas, plan.rect, plan.style);
            const inner = RectI{
                .x = plan.rect.x + 1,
                .y = plan.rect.y + 1,
                .w = @max(plan.rect.w - 2, 1),
                .h = @max(plan.rect.h - 2, 1),
            };
            paintLabelBlockStyled(canvas, inner, label, plan.style);
        },
    }
}

fn paintLabelBlock(canvas: *Canvas, rect: RectI, label: []const u8) void {
    paintLabelBlockStyled(canvas, rect, label, .{});
}

fn paintLabelBlockStyled(canvas: *Canvas, rect: RectI, label: []const u8, style: Style) void {
    const lines = labelLineCount(label);
    if (lines == 0) return;
    const start_y = rect.y + @divTrunc(@max(rect.h - @as(i32, @intCast(lines)), 0), 2);
    var it = std.mem.splitScalar(u8, label, '\n');
    var row: i32 = 0;
    while (it.next()) |line| : (row += 1) {
        if (row >= rect.h) break;
        const width: i32 = @intCast(labelCellWidth(line));
        const x = rect.x + @divTrunc(@max(rect.w - width, 0), 2);
        putTextStyled(canvas, x, start_y + row, line, rect.w, style);
    }
}

fn paintEdge(
    canvas: *Canvas,
    graph: anytype,
    layout: anytype,
    edge_item: anytype,
    node_plans: []const NodePlan,
    scale: Scale,
    padding: i32,
    shift_x: i32,
    shift_y: i32,
    options: Options,
) void {
    if (edge_item.from >= node_plans.len or edge_item.to >= node_plans.len) return;
    const style = edgeStyle(edge_item);
    const from_plan = node_plans[edge_item.from];
    const to_plan = node_plans[edge_item.to];
    const edge_waypoints = if (edge_item.id < layout.edge_waypoints.len) layout.edge_waypoints[edge_item.id].points else &.{};
    const first_target = if (edge_waypoints.len > 0)
        mapPoint(edge_waypoints[0].point, scale, padding, shift_x, shift_y)
    else
        to_plan.rect.center();

    var prev = nodeOutsidePoint(from_plan.rect, first_target);
    const route_start = prev;
    var last_dir: Dir = .none;

    for (edge_waypoints) |waypoint| {
        const next = mapPoint(waypoint.point, scale, padding, shift_x, shift_y);
        last_dir = drawPathStyled(canvas, prev, next, style);
        prev = next;
    }

    const end = nodeOutsidePoint(to_plan.rect, prev);
    last_dir = drawPathStyled(canvas, prev, end, style);

    if (graph.directed and last_dir != .none) {
        canvas.putMarkerStyled(end.x, end.y, last_dir, style);
    }

    if (options.show_edge_labels) {
        if (edge_item.label) |label| {
            const mid: PointI = if (edge_waypoints.len > 0)
                mapPoint(edge_waypoints[edge_waypoints.len / 2].point, scale, padding, shift_x, shift_y)
            else
                PointI{ .x = @divTrunc(route_start.x + end.x, 2), .y = @divTrunc(route_start.y + end.y, 2) };
            const width: i32 = @intCast(labelCellWidth(label));
            putTextStyled(canvas, mid.x - @divTrunc(width, 2), mid.y, label, width, edgeLabelStyle(edge_item, style));
        }
    }
}

fn nodeOutsidePoint(rect: RectI, toward: PointI) PointI {
    const center = rect.center();
    const dx = toward.x - center.x;
    const dy = toward.y - center.y;
    if (@abs(dx) >= @abs(dy)) {
        if (dx >= 0) return .{ .x = rect.right() + 1, .y = center.y };
        return .{ .x = rect.x - 1, .y = center.y };
    }
    if (dy >= 0) return .{ .x = center.x, .y = rect.bottom() + 1 };
    return .{ .x = center.x, .y = rect.y - 1 };
}

fn drawPath(canvas: *Canvas, from: PointI, to: PointI) Dir {
    return drawPathStyled(canvas, from, to, .{});
}

fn drawPathStyled(canvas: *Canvas, from: PointI, to: PointI, style: Style) Dir {
    if (from.x == to.x and from.y == to.y) return .none;
    if (from.x == to.x) {
        drawVerticalStyled(canvas, from.x, from.y, to.y, style);
        return if (to.y > from.y) .down else .up;
    }
    if (from.y == to.y) {
        drawHorizontalStyled(canvas, from.y, from.x, to.x, style);
        return if (to.x > from.x) .right else .left;
    }
    const dx = @abs(to.x - from.x);
    const dy = @abs(to.y - from.y);
    if (dx >= dy) {
        drawHorizontalStyled(canvas, from.y, from.x, to.x, style);
        drawVerticalStyled(canvas, to.x, from.y, to.y, style);
        return if (to.y > from.y) .down else .up;
    }
    drawVerticalStyled(canvas, from.x, from.y, to.y, style);
    drawHorizontalStyled(canvas, to.y, from.x, to.x, style);
    return if (to.x > from.x) .right else .left;
}

fn drawRect(canvas: *Canvas, rect: RectI) void {
    drawRectStyled(canvas, rect, .{});
}

fn drawRectStyled(canvas: *Canvas, rect: RectI, style: Style) void {
    if (rect.w <= 0 or rect.h <= 0) return;
    if (rect.w == 1 and rect.h == 1) {
        canvas.putByteStyled(rect.x, rect.y, '*', style);
        return;
    }
    drawHorizontalStyled(canvas, rect.y, rect.x, rect.right(), style);
    drawHorizontalStyled(canvas, rect.bottom(), rect.x, rect.right(), style);
    drawVerticalStyled(canvas, rect.x, rect.y, rect.bottom(), style);
    drawVerticalStyled(canvas, rect.right(), rect.y, rect.bottom(), style);
}

fn drawHorizontal(canvas: *Canvas, y: i32, x0: i32, x1: i32) void {
    drawHorizontalStyled(canvas, y, x0, x1, .{});
}

fn drawHorizontalStyled(canvas: *Canvas, y: i32, x0: i32, x1: i32, style: Style) void {
    const lo = @min(x0, x1);
    const hi = @max(x0, x1);
    var x = lo;
    while (x <= hi) : (x += 1) {
        var mask: u4 = 0;
        if (x > lo) mask |= W;
        if (x < hi) mask |= E;
        if (x == lo and lo != hi) mask |= E;
        if (x == hi and lo != hi) mask |= W;
        canvas.addMaskStyled(x, y, mask, style);
    }
}

fn drawVertical(canvas: *Canvas, x: i32, y0: i32, y1: i32) void {
    drawVerticalStyled(canvas, x, y0, y1, .{});
}

fn drawVerticalStyled(canvas: *Canvas, x: i32, y0: i32, y1: i32, style: Style) void {
    const lo = @min(y0, y1);
    const hi = @max(y0, y1);
    var y = lo;
    while (y <= hi) : (y += 1) {
        var mask: u4 = 0;
        if (y > lo) mask |= N;
        if (y < hi) mask |= S;
        if (y == lo and lo != hi) mask |= S;
        if (y == hi and lo != hi) mask |= N;
        canvas.addMaskStyled(x, y, mask, style);
    }
}

fn putText(canvas: *Canvas, x: i32, y: i32, text: []const u8, max_width: i32) void {
    putTextStyled(canvas, x, y, text, max_width, .{});
}

fn putTextStyled(canvas: *Canvas, x: i32, y: i32, text: []const u8, max_width: i32, style: Style) void {
    if (max_width <= 0) return;
    var cx = x;
    var used: i32 = 0;
    var i: usize = 0;
    while (i < text.len and used < max_width) {
        const c = text[i];
        if (c == '\n' or c == '\r') break;
        if (c < 0x80) {
            canvas.putByteStyled(cx, y, if (std.ascii.isPrint(c)) c else ' ', style);
            i += 1;
        } else {
            canvas.putByteStyled(cx, y, '?', style);
            i += 1;
            while (i < text.len and (text[i] & 0b1100_0000) == 0b1000_0000) : (i += 1) {}
        }
        cx += 1;
        used += 1;
    }
}

fn nodeStyle(node_item: anytype) Style {
    const font = attrValue(node_item.attrs.items, "fontcolor");
    const fill = attrValue(node_item.attrs.items, "fillcolor");
    const border = attrValue(node_item.attrs.items, "color") orelse node_item.color;
    const style = attrValue(node_item.attrs.items, "style");
    return .{
        .fg = parseColor(font orelse border),
        .bg = if (styleHas(style, "filled")) parseColor(fill orelse node_item.color) else .default,
        .attrs = .{
            .bold = styleHas(style, "bold"),
            .dim = styleHas(style, "dotted"),
            .underline = node_item.shape == .underline,
        },
        .link = attrValue(node_item.attrs.items, "href") orelse attrValue(node_item.attrs.items, "URL") orelse attrValue(node_item.attrs.items, "url"),
        .title = attrValue(node_item.attrs.items, "tooltip") orelse attrValue(node_item.attrs.items, "title") orelse node_item.name,
        .kind = "node",
    };
}

fn edgeStyle(edge_item: anytype) Style {
    const style = attrValue(edge_item.attrs.items, "style");
    return .{
        .fg = parseColor(attrValue(edge_item.attrs.items, "color") orelse edge_item.color),
        .attrs = .{
            .bold = styleHas(style, "bold") or attrFloat(edge_item.attrs.items, "penwidth", 1.0) >= 2.0,
            .dim = styleHas(style, "dotted") or styleHas(style, "dashed"),
        },
        .link = attrValue(edge_item.attrs.items, "href") orelse attrValue(edge_item.attrs.items, "URL") orelse attrValue(edge_item.attrs.items, "url"),
        .title = attrValue(edge_item.attrs.items, "tooltip") orelse attrValue(edge_item.attrs.items, "title"),
        .kind = "edge",
    };
}

fn edgeLabelStyle(edge_item: anytype, fallback: Style) Style {
    var style = fallback;
    if (attrValue(edge_item.attrs.items, "fontcolor")) |color| style.fg = parseColor(color);
    style.attrs.bold = true;
    return style;
}

fn clusterStyle(cluster_item: anytype) Style {
    const style = attrValue(cluster_item.attrs.items, "style");
    return .{
        .fg = parseColor(attrValue(cluster_item.attrs.items, "color") orelse "#64748b"),
        .bg = if (styleHas(style, "filled")) parseColor(attrValue(cluster_item.attrs.items, "fillcolor") orelse "#f8fafc") else .default,
        .attrs = .{ .bold = true },
        .link = attrValue(cluster_item.attrs.items, "href") orelse attrValue(cluster_item.attrs.items, "URL") orelse attrValue(cluster_item.attrs.items, "url"),
        .title = attrValue(cluster_item.attrs.items, "tooltip") orelse attrValue(cluster_item.attrs.items, "title") orelse cluster_item.label,
        .kind = "cluster",
    };
}

fn optionalEql(a: ?[]const u8, b: ?[]const u8) bool {
    if (a) |av| {
        if (b) |bv| return std.mem.eql(u8, av, bv);
        return false;
    }
    return b == null;
}

fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    for (attrs) |attr| {
        if (std.ascii.eqlIgnoreCase(attr.name, name)) return attr.value;
    }
    return null;
}

fn styleHas(style: ?[]const u8, needle: []const u8) bool {
    const value = style orelse return false;
    var parts = std.mem.tokenizeAny(u8, value, ", ");
    while (parts.next()) |part| {
        if (std.ascii.eqlIgnoreCase(part, needle)) return true;
    }
    return false;
}

fn attrFloat(attrs: anytype, name: []const u8, fallback: f64) f64 {
    const value = attrValue(attrs, name) orelse return fallback;
    return std.fmt.parseFloat(f64, value) catch fallback;
}

fn parseColor(value: []const u8) Color {
    if (std.ascii.eqlIgnoreCase(value, "none") or std.ascii.eqlIgnoreCase(value, "transparent")) return .default;
    if (value.len == 4 and value[0] == '#') {
        const r = std.fmt.parseInt(u8, value[1..2], 16) catch return namedColor(value);
        const g = std.fmt.parseInt(u8, value[2..3], 16) catch return namedColor(value);
        const b = std.fmt.parseInt(u8, value[3..4], 16) catch return namedColor(value);
        return .{ .rgb = .{ .r = r * 17, .g = g * 17, .b = b * 17 } };
    }
    if (value.len == 7 and value[0] == '#') {
        return .{ .rgb = .{
            .r = std.fmt.parseInt(u8, value[1..3], 16) catch return namedColor(value),
            .g = std.fmt.parseInt(u8, value[3..5], 16) catch return namedColor(value),
            .b = std.fmt.parseInt(u8, value[5..7], 16) catch return namedColor(value),
        } };
    }
    return namedColor(value);
}

fn namedColor(value: []const u8) Color {
    if (std.ascii.eqlIgnoreCase(value, "black")) return .{ .rgb = .{ .r = 0, .g = 0, .b = 0 } };
    if (std.ascii.eqlIgnoreCase(value, "white")) return .{ .rgb = .{ .r = 255, .g = 255, .b = 255 } };
    if (std.ascii.eqlIgnoreCase(value, "red")) return .{ .rgb = .{ .r = 255, .g = 0, .b = 0 } };
    if (std.ascii.eqlIgnoreCase(value, "green")) return .{ .rgb = .{ .r = 0, .g = 128, .b = 0 } };
    if (std.ascii.eqlIgnoreCase(value, "blue")) return .{ .rgb = .{ .r = 0, .g = 0, .b = 255 } };
    if (std.ascii.eqlIgnoreCase(value, "yellow")) return .{ .rgb = .{ .r = 255, .g = 255, .b = 0 } };
    if (std.ascii.eqlIgnoreCase(value, "orange")) return .{ .rgb = .{ .r = 255, .g = 165, .b = 0 } };
    if (std.ascii.eqlIgnoreCase(value, "purple")) return .{ .rgb = .{ .r = 128, .g = 0, .b = 128 } };
    if (std.ascii.eqlIgnoreCase(value, "pink")) return .{ .rgb = .{ .r = 255, .g = 192, .b = 203 } };
    if (std.ascii.eqlIgnoreCase(value, "gray") or std.ascii.eqlIgnoreCase(value, "grey")) return .{ .rgb = .{ .r = 128, .g = 128, .b = 128 } };
    if (std.ascii.eqlIgnoreCase(value, "lightgrey") or std.ascii.eqlIgnoreCase(value, "lightgray")) return .{ .rgb = .{ .r = 211, .g = 211, .b = 211 } };
    return .default;
}

fn writeAnsiReset(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.writeAll("\x1b[0m");
}

fn writeAnsiStyle(writer: *Io.Writer, style: Style, mode: ColorMode) Io.Writer.Error!void {
    if (style.attrs.bold) try writer.writeAll("\x1b[1m");
    if (style.attrs.dim) try writer.writeAll("\x1b[2m");
    if (style.attrs.underline) try writer.writeAll("\x1b[4m");
    try writeAnsiColor(writer, style.fg, mode, false);
    try writeAnsiColor(writer, style.bg, mode, true);
}

fn writeAnsiColor(writer: *Io.Writer, color: Color, mode: ColorMode, background: bool) Io.Writer.Error!void {
    const rgb = switch (color) {
        .default => return,
        .rgb => |value| value,
    };
    switch (mode) {
        .none => {},
        .ansi256 => try writer.print("\x1b[{d};5;{d}m", .{ if (background) @as(u8, 48) else @as(u8, 38), rgbToAnsi256(rgb) }),
        .truecolor => try writer.print("\x1b[{d};2;{d};{d};{d}m", .{ if (background) @as(u8, 48) else @as(u8, 38), rgb.r, rgb.g, rgb.b }),
    }
}

fn rgbToAnsi256(rgb: Rgb) u8 {
    if (rgb.r == rgb.g and rgb.g == rgb.b) {
        if (rgb.r < 8) return 16;
        if (rgb.r > 248) return 231;
        return @intCast(@as(u16, 232) + @divTrunc(@as(u16, rgb.r) - 8, 10));
    }
    const r: u8 = @intCast(@divTrunc(@as(u16, rgb.r) * 5 + 127, 255));
    const g: u8 = @intCast(@divTrunc(@as(u16, rgb.g) * 5 + 127, 255));
    const b: u8 = @intCast(@divTrunc(@as(u16, rgb.b) * 5 + 127, 255));
    return @intCast(@as(u16, 16) + 36 * @as(u16, r) + 6 * @as(u16, g) + @as(u16, b));
}

fn writeOsc8Start(writer: *Io.Writer, link: ?[]const u8) Io.Writer.Error!void {
    const url = link orelse return;
    try writer.writeAll("\x1b]8;;");
    try writer.writeAll(url);
    try writer.writeAll("\x1b\\");
}

fn writeOsc8End(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.writeAll("\x1b]8;;\x1b\\");
}

fn writeHtmlStyledRunOpen(writer: *Io.Writer, style: Style) Io.Writer.Error!void {
    if (style.link) |link| {
        try writer.writeAll("<a href=\"");
        try writeHtmlEscaped(writer, link);
        try writer.writeByte('"');
    } else {
        try writer.writeAll("<span");
    }
    if (style.title) |title| {
        try writer.writeAll(" title=\"");
        try writeHtmlEscaped(writer, title);
        try writer.writeByte('"');
    }
    if (style.kind) |kind| {
        try writer.writeAll(" data-vex-kind=\"");
        try writeHtmlEscaped(writer, kind);
        try writer.writeByte('"');
    }
    try writer.writeAll(" style=\"");
    switch (style.fg) {
        .default => {},
        .rgb => |rgb| try writer.print("color:#{x:0>2}{x:0>2}{x:0>2};", .{ rgb.r, rgb.g, rgb.b }),
    }
    switch (style.bg) {
        .default => {},
        .rgb => |rgb| try writer.print("background-color:#{x:0>2}{x:0>2}{x:0>2};", .{ rgb.r, rgb.g, rgb.b }),
    }
    if (style.attrs.bold) try writer.writeAll("font-weight:700;");
    if (style.attrs.dim) try writer.writeAll("opacity:0.72;");
    if (style.attrs.underline) try writer.writeAll("text-decoration:underline;");
    try writer.writeAll("\">");
}

fn closeHtmlStyledRun(writer: *Io.Writer, style: Style) Io.Writer.Error!void {
    try writer.writeAll(if (style.link != null) "</a>" else "</span>");
}

fn writeHtmlByte(writer: *Io.Writer, byte: u8) Io.Writer.Error!void {
    switch (byte) {
        '&' => try writer.writeAll("&amp;"),
        '<' => try writer.writeAll("&lt;"),
        '>' => try writer.writeAll("&gt;"),
        '"' => try writer.writeAll("&quot;"),
        else => try writer.writeByte(byte),
    }
}

fn writeHtmlEscaped(writer: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    for (text) |byte| try writeHtmlByte(writer, byte);
}

fn safeHtmlPreStyle(style: []const u8) []const u8 {
    if (style.len == 0) return default_html_pre_style;
    for (style) |byte| {
        switch (byte) {
            '"', '<', '>' => return default_html_pre_style,
            0...0x1f, 0x7f => return default_html_pre_style,
            else => {},
        }
    }
    return style;
}

fn labelLineCount(label: []const u8) usize {
    if (label.len == 0) return 1;
    var count: usize = 1;
    for (label) |c| {
        if (c == '\n') count += 1;
    }
    return count;
}

fn labelMaxWidth(label: []const u8) usize {
    var max_width: usize = 0;
    var it = std.mem.splitScalar(u8, label, '\n');
    while (it.next()) |line| {
        max_width = @max(max_width, labelCellWidth(line));
    }
    return max_width;
}

fn labelCellWidth(label: []const u8) usize {
    var width: usize = 0;
    var i: usize = 0;
    while (i < label.len) {
        const c = label[i];
        if (c == '\n' or c == '\r') break;
        width += 1;
        if (c < 0x80) {
            i += 1;
        } else {
            i += 1;
            while (i < label.len and (label[i] & 0b1100_0000) == 0b1000_0000) : (i += 1) {}
        }
    }
    return width;
}

fn markerGlyph(dir: Dir, unicode: bool) []const u8 {
    return if (unicode)
        switch (dir) {
            .up => "↑",
            .right => "→",
            .down => "↓",
            .left => "←",
            .none => " ",
        }
    else switch (dir) {
        .up => "^",
        .right => ">",
        .down => "v",
        .left => "<",
        .none => " ",
    };
}

fn maskGlyph(mask: u4, unicode: bool) []const u8 {
    if (!unicode) {
        if (mask == 0) return " ";
        const horizontal = (mask & (E | W)) != 0;
        const vertical = (mask & (N | S)) != 0;
        if (horizontal and !vertical) return "-";
        if (vertical and !horizontal) return "|";
        return "+";
    }

    return switch (mask) {
        0 => " ",
        E, W, E | W => "─",
        N, S, N | S => "│",
        E | S => "┌",
        W | S => "┐",
        N | E => "└",
        N | W => "┘",
        N | S | E => "├",
        N | S | W => "┤",
        E | W | S => "┬",
        N | E | W => "┴",
        N | E | S | W => "┼",
    };
}
