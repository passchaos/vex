//! Layout-aware terminal renderer.
//!
//! This backend intentionally stays small and Vex-local: it consumes the public
//! graph/layout shape through comptime field access and paints a box-drawing
//! canvas without depending on the rest of `root.zig`.

const std = @import("std");
const Io = std.Io;

pub const RenderError = Io.Writer.Error || std.mem.Allocator.Error;

pub const Options = struct {
    unicode: bool = true,
    target_width: usize = 120,
    target_height: usize = 40,
    padding: usize = 2,
    x_scale: f64 = 0.24,
    y_scale: f64 = 0.10,
    show_title: bool = false,
    show_edge_labels: bool = true,
    show_cluster_labels: bool = true,
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
};

const ClusterPlan = struct {
    rect: RectI,
};

const Cell = struct {
    mask: u4 = 0,
    marker: Dir = .none,
    byte: u8 = 0,

    fn empty(self: Cell) bool {
        return self.mask == 0 and self.marker == .none and self.byte == 0;
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
        if (self.index(x, y)) |idx| {
            if (self.cells[idx].byte == 0) self.cells[idx].mask |= mask;
        }
    }

    fn putByte(self: *Canvas, x: i32, y: i32, byte: u8) void {
        if (self.index(x, y)) |idx| {
            self.cells[idx].byte = byte;
            self.cells[idx].marker = .none;
            self.cells[idx].mask = 0;
        }
    }

    fn putMarker(self: *Canvas, x: i32, y: i32, dir: Dir) void {
        if (self.index(x, y)) |idx| {
            if (self.cells[idx].byte == 0) self.cells[idx].marker = dir;
        }
    }

    fn render(self: *const Canvas, writer: *Io.Writer, unicode: bool) Io.Writer.Error!void {
        for (0..self.height) |y| {
            var end = self.width;
            while (end > 0 and self.cells[y * self.width + end - 1].empty()) : (end -= 1) {}
            for (0..end) |x| {
                const cell = self.cells[y * self.width + x];
                if (cell.byte != 0) {
                    try writer.writeByte(cell.byte);
                } else if (cell.marker != .none) {
                    try writer.writeAll(markerGlyph(cell.marker, unicode));
                } else {
                    try writer.writeAll(maskGlyph(cell.mask, unicode));
                }
            }
            try writer.writeByte('\n');
        }
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
        paintCluster(&canvas, cluster_plans[i].rect, cluster_item.label, options);
    }

    for (graph.edges.items) |edge_item| {
        paintEdge(&canvas, graph, layout, edge_item, node_plans, scale, padding, shift_x, shift_y, options);
    }

    for (graph.nodes.items, 0..) |node_item, i| {
        paintNode(&canvas, node_plans[i], node_item.label);
    }

    try canvas.render(writer, options.unicode);
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

    return .{ .rect = rect, .kind = kind };
}

fn clusterPlan(cluster_item: anytype, layout_cluster: anytype, scale: Scale, padding: i32, options: Options) ClusterPlan {
    const x = mapCoord(layout_cluster.x, scale.x, padding, 0);
    const y = mapCoord(layout_cluster.y, scale.y, padding, 0);
    const w: i32 = @intCast(@max(@as(usize, @intFromFloat(@ceil(@max(layout_cluster.width * scale.x, 1.0)))), labelMaxWidth(cluster_item.label) + 4));
    const h: i32 = @intCast(@max(@as(usize, @intFromFloat(@ceil(@max(layout_cluster.height * scale.y, 1.0)))), 3));
    _ = options;
    return .{ .rect = .{ .x = x, .y = y, .w = w, .h = h } };
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

fn paintCluster(canvas: *Canvas, rect: RectI, label: []const u8, options: Options) void {
    if (rect.w < 2 or rect.h < 2) return;
    drawRect(canvas, rect);
    if (options.show_cluster_labels and label.len > 0) {
        putText(canvas, rect.x + 2, rect.y, label, @max(rect.w - 4, 0));
    }
}

fn paintNode(canvas: *Canvas, plan: NodePlan, label: []const u8) void {
    switch (plan.kind) {
        .point => canvas.putByte(plan.rect.x, plan.rect.y, '*'),
        .plain => paintLabelBlock(canvas, plan.rect, label),
        .boxed => {
            drawRect(canvas, plan.rect);
            const inner = RectI{
                .x = plan.rect.x + 1,
                .y = plan.rect.y + 1,
                .w = @max(plan.rect.w - 2, 1),
                .h = @max(plan.rect.h - 2, 1),
            };
            paintLabelBlock(canvas, inner, label);
        },
    }
}

fn paintLabelBlock(canvas: *Canvas, rect: RectI, label: []const u8) void {
    const lines = labelLineCount(label);
    if (lines == 0) return;
    const start_y = rect.y + @divTrunc(@max(rect.h - @as(i32, @intCast(lines)), 0), 2);
    var it = std.mem.splitScalar(u8, label, '\n');
    var row: i32 = 0;
    while (it.next()) |line| : (row += 1) {
        if (row >= rect.h) break;
        const width: i32 = @intCast(labelCellWidth(line));
        const x = rect.x + @divTrunc(@max(rect.w - width, 0), 2);
        putText(canvas, x, start_y + row, line, rect.w);
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
        last_dir = drawPath(canvas, prev, next);
        prev = next;
    }

    const end = nodeOutsidePoint(to_plan.rect, prev);
    last_dir = drawPath(canvas, prev, end);

    if (graph.directed and last_dir != .none) {
        canvas.putMarker(end.x, end.y, last_dir);
    }

    if (options.show_edge_labels) {
        if (edge_item.label) |label| {
            const mid: PointI = if (edge_waypoints.len > 0)
                mapPoint(edge_waypoints[edge_waypoints.len / 2].point, scale, padding, shift_x, shift_y)
            else
                PointI{ .x = @divTrunc(route_start.x + end.x, 2), .y = @divTrunc(route_start.y + end.y, 2) };
            const width: i32 = @intCast(labelCellWidth(label));
            putText(canvas, mid.x - @divTrunc(width, 2), mid.y, label, width);
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
    if (from.x == to.x and from.y == to.y) return .none;
    if (from.x == to.x) {
        drawVertical(canvas, from.x, from.y, to.y);
        return if (to.y > from.y) .down else .up;
    }
    if (from.y == to.y) {
        drawHorizontal(canvas, from.y, from.x, to.x);
        return if (to.x > from.x) .right else .left;
    }
    const dx = @abs(to.x - from.x);
    const dy = @abs(to.y - from.y);
    if (dx >= dy) {
        drawHorizontal(canvas, from.y, from.x, to.x);
        drawVertical(canvas, to.x, from.y, to.y);
        return if (to.y > from.y) .down else .up;
    }
    drawVertical(canvas, from.x, from.y, to.y);
    drawHorizontal(canvas, to.y, from.x, to.x);
    return if (to.x > from.x) .right else .left;
}

fn drawRect(canvas: *Canvas, rect: RectI) void {
    if (rect.w <= 0 or rect.h <= 0) return;
    if (rect.w == 1 and rect.h == 1) {
        canvas.putByte(rect.x, rect.y, '*');
        return;
    }
    drawHorizontal(canvas, rect.y, rect.x, rect.right());
    drawHorizontal(canvas, rect.bottom(), rect.x, rect.right());
    drawVertical(canvas, rect.x, rect.y, rect.bottom());
    drawVertical(canvas, rect.right(), rect.y, rect.bottom());
}

fn drawHorizontal(canvas: *Canvas, y: i32, x0: i32, x1: i32) void {
    const lo = @min(x0, x1);
    const hi = @max(x0, x1);
    var x = lo;
    while (x <= hi) : (x += 1) {
        var mask: u4 = 0;
        if (x > lo) mask |= W;
        if (x < hi) mask |= E;
        if (x == lo and lo != hi) mask |= E;
        if (x == hi and lo != hi) mask |= W;
        canvas.addMask(x, y, mask);
    }
}

fn drawVertical(canvas: *Canvas, x: i32, y0: i32, y1: i32) void {
    const lo = @min(y0, y1);
    const hi = @max(y0, y1);
    var y = lo;
    while (y <= hi) : (y += 1) {
        var mask: u4 = 0;
        if (y > lo) mask |= N;
        if (y < hi) mask |= S;
        if (y == lo and lo != hi) mask |= S;
        if (y == hi and lo != hi) mask |= N;
        canvas.addMask(x, y, mask);
    }
}

fn putText(canvas: *Canvas, x: i32, y: i32, text: []const u8, max_width: i32) void {
    if (max_width <= 0) return;
    var cx = x;
    var used: i32 = 0;
    var i: usize = 0;
    while (i < text.len and used < max_width) {
        const c = text[i];
        if (c == '\n' or c == '\r') break;
        if (c < 0x80) {
            canvas.putByte(cx, y, if (std.ascii.isPrint(c)) c else ' ');
            i += 1;
        } else {
            canvas.putByte(cx, y, '?');
            i += 1;
            while (i < text.len and (text[i] & 0b1100_0000) == 0b1000_0000) : (i += 1) {}
        }
        cx += 1;
        used += 1;
    }
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
