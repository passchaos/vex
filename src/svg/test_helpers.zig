//! SVG string parsing helpers used by tests.

const std = @import("std");

pub const Translate = struct {
    x: f64 = 0,
    y: f64 = 0,
};

pub const ViewBox = struct {
    width: f64,
    height: f64,
};

pub fn pathCommandCount(svg: []const u8, command: u8) usize {
    var count: usize = 0;
    var search_start: usize = 0;
    while (std.mem.indexOf(u8, svg[search_start..], " d=\"")) |rel| {
        const value_start = search_start + rel + " d=\"".len;
        const value_end_rel = std.mem.indexOfScalar(u8, svg[value_start..], '"') orelse break;
        count += pathDataCommandCount(svg[value_start .. value_start + value_end_rel], command);
        search_start = value_start + value_end_rel + 1;
    }
    return count;
}

pub fn cubicSegmentCount(fragment: []const u8) usize {
    if (pathCommandCount(fragment, 'C') == 0) return 0;
    var numbers: [128]f64 = undefined;
    const count = numbersInAttribute(fragment, "d", numbers[0..]);
    if (count < 8) return 0;
    return (count - 2) / 6;
}

pub fn numberAfter(fragment: []const u8, marker: []const u8) ?f64 {
    const start = std.mem.indexOf(u8, fragment, marker) orelse return null;
    const value_start = start + marker.len;
    const value_end_rel = std.mem.indexOfScalar(u8, fragment[value_start..], '"') orelse return null;
    return std.fmt.parseFloat(f64, fragment[value_start .. value_start + value_end_rel]) catch null;
}

pub fn groupFragmentByTitle(svg: []const u8, title: []const u8) ?[]const u8 {
    var title_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&title_buf, "<title>{s}</title>", .{title}) catch return null;
    const title_pos = std.mem.indexOf(u8, svg, needle) orelse return null;
    const end_rel = std.mem.indexOf(u8, svg[title_pos..], "</g>") orelse return null;
    return svg[title_pos .. title_pos + end_rel];
}

pub fn groupFragmentById(svg: []const u8, id: []const u8) ?[]const u8 {
    var id_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&id_buf, "<g id=\"{s}\"", .{id}) catch return null;
    const start = std.mem.indexOf(u8, svg, needle) orelse return null;
    var search = start;
    var depth: usize = 0;
    while (search < svg.len) {
        const next_open_rel = std.mem.indexOf(u8, svg[search..], "<g ");
        const next_close_rel = std.mem.indexOf(u8, svg[search..], "</g>");
        if (next_open_rel == null and next_close_rel == null) return null;
        if (next_close_rel == null or (next_open_rel != null and next_open_rel.? < next_close_rel.?)) {
            search += next_open_rel.? + "<g ".len;
            depth += 1;
            continue;
        }
        const close_start = search + next_close_rel.?;
        if (depth == 0) return null;
        depth -= 1;
        search = close_start + "</g>".len;
        if (depth == 0) return svg[start..search];
    }
    return null;
}

pub fn fragmentHasDash(fragment: []const u8) bool {
    return std.mem.indexOf(u8, fragment, "stroke-dasharray=") != null;
}

pub fn rootFragment(svg: []const u8) ?[]const u8 {
    const title_pos = std.mem.indexOf(u8, svg, "<title>") orelse return null;
    const end_rel = std.mem.indexOf(u8, svg[title_pos..], "</g>") orelse return null;
    return svg[title_pos .. title_pos + end_rel];
}

pub fn viewBox(svg: []const u8) ?ViewBox {
    const marker = " viewBox=\"";
    const start = std.mem.indexOf(u8, svg, marker) orelse return null;
    const value_start = start + marker.len;
    const value_end_rel = std.mem.indexOfScalar(u8, svg[value_start..], '"') orelse return null;
    const value = svg[value_start .. value_start + value_end_rel];
    var parts = std.mem.tokenizeScalar(u8, value, ' ');
    _ = parts.next() orelse return null;
    _ = parts.next() orelse return null;
    const width_text = parts.next() orelse return null;
    const height_text = parts.next() orelse return null;
    return .{
        .width = std.fmt.parseFloat(f64, width_text) catch return null,
        .height = std.fmt.parseFloat(f64, height_text) catch return null,
    };
}

pub fn graphvizTranslate(svg: []const u8) Translate {
    const marker = "translate(";
    var result = Translate{};
    var search_start: usize = 0;
    while (std.mem.indexOf(u8, svg[search_start..], marker)) |rel| {
        const start = search_start + rel;
        const value_start = start + marker.len;
        const value_end_rel = std.mem.indexOfScalar(u8, svg[value_start..], ')') orelse break;
        const values = svg[value_start .. value_start + value_end_rel];
        var parts = std.mem.tokenizeAny(u8, values, " ,");
        const x_text = parts.next() orelse break;
        const y_text = parts.next() orelse break;
        result.x += std.fmt.parseFloat(f64, x_text) catch 0;
        result.y += std.fmt.parseFloat(f64, y_text) catch 0;
        search_start = value_start + value_end_rel + 1;
    }
    return result;
}

pub fn polygonBBoxX(fragment: []const u8) ?f64 {
    var point_numbers: [64]f64 = undefined;
    const count = numbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2) return null;
    var min_x = std.math.floatMax(f64);
    var index: usize = 0;
    while (index + 1 < count) : (index += 2) min_x = @min(min_x, point_numbers[index]);
    return if (min_x == std.math.floatMax(f64)) null else min_x;
}

pub fn polygonBBoxY(fragment: []const u8) ?f64 {
    var point_numbers: [64]f64 = undefined;
    const count = numbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2) return null;
    var min_y = std.math.floatMax(f64);
    var index: usize = 1;
    while (index < count) : (index += 2) min_y = @min(min_y, point_numbers[index]);
    return if (min_y == std.math.floatMax(f64)) null else min_y;
}

pub fn polygonBBoxWidth(fragment: []const u8) ?f64 {
    var point_numbers: [64]f64 = undefined;
    const count = numbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2) return null;
    var min_x = std.math.floatMax(f64);
    var max_x: f64 = -std.math.floatMax(f64);
    var index: usize = 0;
    while (index + 1 < count) : (index += 2) {
        const x = point_numbers[index];
        min_x = @min(min_x, x);
        max_x = @max(max_x, x);
    }
    if (min_x == std.math.floatMax(f64)) return null;
    return max_x - min_x;
}

pub fn polygonBBoxHeight(fragment: []const u8) ?f64 {
    var point_numbers: [64]f64 = undefined;
    const count = numbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2) return null;
    var min_y = std.math.floatMax(f64);
    var max_y: f64 = -std.math.floatMax(f64);
    var index: usize = 1;
    while (index < count) : (index += 2) {
        const y = point_numbers[index];
        min_y = @min(min_y, y);
        max_y = @max(max_y, y);
    }
    if (min_y == std.math.floatMax(f64)) return null;
    return max_y - min_y;
}

pub fn polygonPointCount(fragment: []const u8) ?usize {
    var point_numbers: [128]f64 = undefined;
    const count = numbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2 or count % 2 != 0) return null;
    return count / 2;
}

pub fn clusterRectWidth(svg: []const u8, title: []const u8) ?f64 {
    const fragment = groupFragmentByTitle(svg, title) orelse return null;
    if (polygonBBoxWidth(fragment)) |width| return width;
    return numberAfter(fragment, " width=\"");
}

pub fn clusterRectHeight(svg: []const u8, title: []const u8) ?f64 {
    const fragment = groupFragmentByTitle(svg, title) orelse return null;
    if (polygonBBoxHeight(fragment)) |height| return height;
    return numberAfter(fragment, " height=\"");
}

pub fn clusterRectX(svg: []const u8, title: []const u8) ?f64 {
    const fragment = groupFragmentByTitle(svg, title) orelse return null;
    if (polygonBBoxX(fragment)) |x| return x;
    return numberAfter(fragment, " x=\"");
}

pub fn clusterRectY(svg: []const u8, title: []const u8) ?f64 {
    const fragment = groupFragmentByTitle(svg, title) orelse return null;
    if (polygonBBoxY(fragment)) |y| return y;
    return numberAfter(fragment, " y=\"");
}

pub fn clusterScreenX(svg: []const u8, title: []const u8) ?f64 {
    const x = clusterRectX(svg, title) orelse return null;
    return x + graphvizTranslate(svg).x;
}

pub fn clusterScreenY(svg: []const u8, title: []const u8) ?f64 {
    const y = clusterRectY(svg, title) orelse return null;
    return y + graphvizTranslate(svg).y;
}

pub fn nodeCenterX(svg: []const u8, title: []const u8) ?f64 {
    const fragment = groupFragmentByTitle(svg, title) orelse return null;
    if (numberAfter(fragment, " cx=\"")) |cx| return cx;
    if (numberAfter(fragment, " x=\"")) |x| {
        if (numberAfter(fragment, " width=\"")) |width| return x + width / 2.0;
    }
    var point_numbers: [64]f64 = undefined;
    const count = numbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2) return null;
    var min_x = std.math.floatMax(f64);
    var max_x: f64 = -std.math.floatMax(f64);
    var index_i: usize = 0;
    while (index_i + 1 < count) : (index_i += 2) {
        const x = point_numbers[index_i];
        min_x = @min(min_x, x);
        max_x = @max(max_x, x);
    }
    if (min_x == std.math.floatMax(f64)) return null;
    return (min_x + max_x) / 2.0;
}

pub fn nodeCenterY(svg: []const u8, title: []const u8) ?f64 {
    const fragment = groupFragmentByTitle(svg, title) orelse return null;
    if (numberAfter(fragment, " cy=\"")) |cy| return cy;
    if (numberAfter(fragment, " y=\"")) |y| {
        if (numberAfter(fragment, " height=\"")) |height| return y + height / 2.0;
    }
    var point_numbers: [64]f64 = undefined;
    const count = numbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2) return null;
    var min_y = std.math.floatMax(f64);
    var max_y: f64 = -std.math.floatMax(f64);
    var index_i: usize = 1;
    while (index_i < count) : (index_i += 2) {
        const y = point_numbers[index_i];
        min_y = @min(min_y, y);
        max_y = @max(max_y, y);
    }
    if (min_y == std.math.floatMax(f64)) return null;
    return (min_y + max_y) / 2.0;
}

pub fn nodeScreenCenterX(svg: []const u8, title: []const u8) ?f64 {
    const x = nodeCenterX(svg, title) orelse return null;
    return x + graphvizTranslate(svg).x;
}

pub fn nodeScreenCenterY(svg: []const u8, title: []const u8) ?f64 {
    const y = nodeCenterY(svg, title) orelse return null;
    return y + graphvizTranslate(svg).y;
}

pub fn numbersInAttribute(fragment: []const u8, attr_name: []const u8, out: []f64) usize {
    var marker_buf: [64]u8 = undefined;
    const marker = std.fmt.bufPrint(&marker_buf, " {s}=\"", .{attr_name}) catch return 0;
    const attr_start = std.mem.indexOf(u8, fragment, marker) orelse return 0;
    const value_start = attr_start + marker.len;
    const value_end_rel = std.mem.indexOfScalar(u8, fragment[value_start..], '"') orelse return 0;
    var values = std.mem.tokenizeAny(u8, fragment[value_start .. value_start + value_end_rel], " ,MmLlCcZz");
    var count: usize = 0;
    while (values.next()) |number_text| {
        if (count >= out.len) break;
        out[count] = std.fmt.parseFloat(f64, number_text) catch continue;
        count += 1;
    }
    return count;
}

pub fn pathDataCommandCount(path_data: []const u8, command: u8) usize {
    var count: usize = 0;
    for (path_data) |c| {
        if (c == command) count += 1;
    }
    return count;
}
