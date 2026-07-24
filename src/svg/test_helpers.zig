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

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const Endpoints = struct {
    start: Point,
    end: Point,
};

pub const GroupIdClass = struct {
    id: []const u8,
    class: []const u8,
};

pub const TextPosition = struct {
    text: []const u8,
    point: Point,
};

pub const ElementName = struct {
    closing: bool,
    name: []const u8,
};

pub const DrawablePoints = struct {
    tag: []const u8,
    numbers: [128]f64,
    count: usize,
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

pub fn pathNumbers(svg: []const u8, title: []const u8, out: []f64) usize {
    const fragment = groupFragmentByTitle(svg, title) orelse return 0;
    return numbersInAttribute(fragment, "d", out);
}

pub fn pathStartEnd(svg: []const u8, title: []const u8) ?Endpoints {
    var numbers: [64]f64 = undefined;
    const count = pathNumbers(svg, title, numbers[0..]);
    if (count < 4 or count % 2 != 0) return null;
    return .{
        .start = .{ .x = numbers[0], .y = numbers[1] },
        .end = .{ .x = numbers[count - 2], .y = numbers[count - 1] },
    };
}

pub fn edgeArrowTip(svg: []const u8, title: []const u8) ?Point {
    const fragment = groupFragmentByTitle(svg, title) orelse return null;
    var numbers: [32]f64 = undefined;
    const count = numbersInAttribute(fragment, "points", numbers[0..]);
    if (count < 4) return null;
    return .{ .x = numbers[2], .y = numbers[3] };
}

pub fn polylineEndpoints(svg: []const u8, title: []const u8, polyline_index: usize) ?Endpoints {
    const fragment = groupFragmentByTitle(svg, title) orelse return null;
    var search_start: usize = 0;
    var current_index: usize = 0;
    while (std.mem.indexOf(u8, fragment[search_start..], "<polyline")) |rel| {
        const polyline_start = search_start + rel;
        const polyline_end_rel = std.mem.indexOf(u8, fragment[polyline_start..], "/>") orelse return null;
        const polyline = fragment[polyline_start .. polyline_start + polyline_end_rel];
        if (current_index == polyline_index) {
            var numbers: [16]f64 = undefined;
            const count = numbersInAttribute(polyline, "points", numbers[0..]);
            if (count < 4) return null;
            return .{
                .start = .{ .x = numbers[0], .y = numbers[1] },
                .end = .{ .x = numbers[count - 2], .y = numbers[count - 1] },
            };
        }
        current_index += 1;
        search_start = polyline_start + polyline_end_rel + 2;
    }
    return null;
}

pub fn polylineCount(svg: []const u8, title: []const u8) usize {
    const fragment = groupFragmentByTitle(svg, title) orelse return 0;
    return countSubstrings(fragment, "<polyline");
}

pub fn nextGroupIdClass(svg: []const u8, index: *usize) ?GroupIdClass {
    while (std.mem.indexOf(u8, svg[index.*..], "<g ")) |rel| {
        const group_start = index.* + rel;
        const tag_end_rel = std.mem.indexOfScalar(u8, svg[group_start..], '>') orelse return null;
        const tag = svg[group_start .. group_start + tag_end_rel];
        index.* = group_start + tag_end_rel + 1;
        const id = attributeValue(tag, "id") orelse continue;
        const class = attributeValue(tag, "class") orelse continue;
        return .{ .id = id, .class = class };
    }
    return null;
}

pub fn attributeValue(tag: []const u8, attr: []const u8) ?[]const u8 {
    var marker_buf: [64]u8 = undefined;
    const marker = std.fmt.bufPrint(&marker_buf, "{s}=\"", .{attr}) catch return null;
    const attr_start = std.mem.indexOf(u8, tag, marker) orelse return null;
    const value_start = attr_start + marker.len;
    const value_end_rel = std.mem.indexOfScalar(u8, tag[value_start..], '"') orelse return null;
    return tag[value_start .. value_start + value_end_rel];
}

pub fn attributeSlice(fragment: []const u8, attr_name: []const u8) ?[]const u8 {
    var marker_buf: [64]u8 = undefined;
    const marker = std.fmt.bufPrint(&marker_buf, " {s}=\"", .{attr_name}) catch return null;
    const attr_start = std.mem.indexOf(u8, fragment, marker) orelse return null;
    const value_start = attr_start + marker.len;
    const value_end_rel = std.mem.indexOfScalar(u8, fragment[value_start..], '"') orelse return null;
    return fragment[value_start .. value_start + value_end_rel];
}

pub fn nextPathCommand(d: []const u8, index: *usize) ?u8 {
    while (index.* < d.len) : (index.* += 1) {
        const c = d[index.*];
        if (c == 'M' or c == 'L' or c == 'C' or c == 'Q' or c == 'Z' or c == 'z') {
            index.* += 1;
            return c;
        }
    }
    return null;
}

pub fn nextTextPosition(svg: []const u8, index: *usize) ?TextPosition {
    while (std.mem.indexOf(u8, svg[index.*..], "<text")) |rel| {
        const text_start = index.* + rel;
        const open_end_rel = std.mem.indexOfScalar(u8, svg[text_start..], '>') orelse return null;
        const tag = svg[text_start .. text_start + open_end_rel + 1];
        const content_start = text_start + open_end_rel + 1;
        const close_rel = std.mem.indexOf(u8, svg[content_start..], "</text>") orelse return null;
        index.* = content_start + close_rel + "</text>".len;
        const content = svg[content_start .. content_start + close_rel];
        const text = textVisibleContent(content) orelse continue;
        const x = numberAfter(tag, " x=\"") orelse return null;
        const y = numberAfter(tag, " y=\"") orelse return null;
        return .{ .text = text, .point = .{ .x = x, .y = y } };
    }
    return null;
}

pub fn nextTextContent(svg: []const u8, index: *usize) ?[]const u8 {
    while (std.mem.indexOf(u8, svg[index.*..], "<text")) |rel| {
        const text_start = index.* + rel;
        const open_end_rel = std.mem.indexOfScalar(u8, svg[text_start..], '>') orelse return null;
        const content_start = text_start + open_end_rel + 1;
        const close_rel = std.mem.indexOf(u8, svg[content_start..], "</text>") orelse return null;
        index.* = content_start + close_rel + "</text>".len;
        const content = svg[content_start .. content_start + close_rel];
        if (textVisibleContent(content)) |text| return text;
    }
    return null;
}

pub fn textVisibleContent(content: []const u8) ?[]const u8 {
    if (std.mem.indexOfScalar(u8, content, '<') == null) return content;
    const tspan_start_rel = std.mem.indexOf(u8, content, "<tspan") orelse return null;
    const tspan_open_end_rel = std.mem.indexOfScalar(u8, content[tspan_start_rel..], '>') orelse return null;
    const text_start = tspan_start_rel + tspan_open_end_rel + 1;
    const text_end_rel = std.mem.indexOf(u8, content[text_start..], "</tspan>") orelse return null;
    const text = content[text_start .. text_start + text_end_rel];
    if (std.mem.indexOfScalar(u8, text, '<') != null) return null;
    return text;
}

pub fn nextOpeningTag(svg: []const u8, index: *usize) ?[]const u8 {
    while (std.mem.indexOfScalar(u8, svg[index.*..], '<')) |rel| {
        const tag_start = index.* + rel;
        index.* = tag_start + 1;
        if (index.* >= svg.len) return null;
        if (svg[index.*] == '!' or svg[index.*] == '?' or svg[index.*] == '/') continue;
        const tag_end_rel = std.mem.indexOfScalar(u8, svg[index.*..], '>') orelse return null;
        index.* += tag_end_rel + 1;
        return svg[tag_start..index.*];
    }
    return null;
}

pub fn nextElementName(svg: []const u8, index: *usize) ?ElementName {
    while (std.mem.indexOfScalar(u8, svg[index.*..], '<')) |rel| {
        const tag_start = index.* + rel;
        index.* = tag_start + 1;
        if (index.* >= svg.len) return null;
        if (svg[index.*] == '!' or svg[index.*] == '?') continue;
        const closing = svg[index.*] == '/';
        const name_start = index.* + @intFromBool(closing);
        var name_end = name_start;
        while (name_end < svg.len and isNameChar(svg[name_end])) : (name_end += 1) {}
        if (name_end == name_start) continue;
        const name = svg[name_start..name_end];
        if (std.mem.eql(u8, name, "svg")) continue;
        return .{ .closing = closing, .name = name };
    }
    return null;
}

pub fn expectTitleSequenceEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_start = std.mem.indexOf(u8, svg[svg_index..], "<title>");
        const oracle_start = std.mem.indexOf(u8, oracle[oracle_index..], "<title>");
        if (svg_start == null or oracle_start == null) {
            try std.testing.expect(svg_start == null and oracle_start == null);
            return;
        }
        const svg_title_start = svg_index + svg_start.? + "<title>".len;
        const oracle_title_start = oracle_index + oracle_start.? + "<title>".len;
        const svg_title_end_rel = std.mem.indexOf(u8, svg[svg_title_start..], "</title>") orelse return error.MissingTitle;
        const oracle_title_end_rel = std.mem.indexOf(u8, oracle[oracle_title_start..], "</title>") orelse return error.MissingTitle;
        const svg_title = svg[svg_title_start .. svg_title_start + svg_title_end_rel];
        const oracle_title = oracle[oracle_title_start .. oracle_title_start + oracle_title_end_rel];
        try std.testing.expectEqualStrings(oracle_title, svg_title);
        svg_index = svg_title_start + svg_title_end_rel + "</title>".len;
        oracle_index = oracle_title_start + oracle_title_end_rel + "</title>".len;
    }
}

pub fn expectCommentSequenceEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_start = std.mem.indexOf(u8, svg[svg_index..], "<!-- ");
        const oracle_start = std.mem.indexOf(u8, oracle[oracle_index..], "<!-- ");
        if (svg_start == null or oracle_start == null) {
            try std.testing.expect(svg_start == null and oracle_start == null);
            return;
        }
        const svg_comment_start = svg_index + svg_start.? + "<!-- ".len;
        const oracle_comment_start = oracle_index + oracle_start.? + "<!-- ".len;
        const svg_comment_end_rel = std.mem.indexOf(u8, svg[svg_comment_start..], " -->") orelse return error.MissingComment;
        const oracle_comment_end_rel = std.mem.indexOf(u8, oracle[oracle_comment_start..], " -->") orelse return error.MissingComment;
        const svg_comment = svg[svg_comment_start .. svg_comment_start + svg_comment_end_rel];
        const oracle_comment = oracle[oracle_comment_start .. oracle_comment_start + oracle_comment_end_rel];
        try std.testing.expectEqualStrings(oracle_comment, svg_comment);
        svg_index = svg_comment_start + svg_comment_end_rel + " -->".len;
        oracle_index = oracle_comment_start + oracle_comment_end_rel + " -->".len;
    }
}

pub fn expectGroupSequenceEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_group = nextGroupIdClass(svg, &svg_index);
        const oracle_group = nextGroupIdClass(oracle, &oracle_index);
        if (svg_group == null or oracle_group == null) {
            try std.testing.expect(svg_group == null and oracle_group == null);
            return;
        }
        try std.testing.expectEqualStrings(oracle_group.?.id, svg_group.?.id);
        try std.testing.expectEqualStrings(oracle_group.?.class, svg_group.?.class);
    }
}

pub fn expectPathCommandSequenceEqual(svg_fragment: []const u8, oracle_fragment: []const u8) !void {
    const svg_d = attributeSlice(svg_fragment, "d") orelse return error.MissingEdge;
    const oracle_d = attributeSlice(oracle_fragment, "d") orelse return error.MissingEdge;
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_command = nextPathCommand(svg_d, &svg_index);
        const oracle_command = nextPathCommand(oracle_d, &oracle_index);
        if (svg_command == null or oracle_command == null) {
            try std.testing.expect(svg_command == null and oracle_command == null);
            return;
        }
        try std.testing.expectEqual(oracle_command.?, svg_command.?);
    }
}

pub fn expectTextSequenceEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_text = nextTextContent(svg, &svg_index);
        const oracle_text = nextTextContent(oracle, &oracle_index);
        if (svg_text == null or oracle_text == null) {
            try std.testing.expect(svg_text == null and oracle_text == null);
            return;
        }
        try std.testing.expectEqualStrings(oracle_text.?, svg_text.?);
    }
}

pub fn expectElementSequenceEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_element = nextElementName(svg, &svg_index);
        const oracle_element = nextElementName(oracle, &oracle_index);
        if (svg_element == null or oracle_element == null) {
            try std.testing.expect(svg_element == null and oracle_element == null);
            return;
        }
        try std.testing.expectEqual(svg_element.?.closing, oracle_element.?.closing);
        try std.testing.expectEqualStrings(oracle_element.?.name, svg_element.?.name);
    }
}

pub fn expectOpeningTagsNormalizedEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_tag = nextOpeningTag(svg, &svg_index);
        const oracle_tag = nextOpeningTag(oracle, &oracle_index);
        if (svg_tag == null or oracle_tag == null) {
            try std.testing.expect(svg_tag == null and oracle_tag == null);
            return;
        }
        try expectNumericNormalizedEqual(svg_tag.?, oracle_tag.?);
    }
}

pub fn expectLinesNumericNormalizedEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_lines = std.mem.splitScalar(u8, svg, '\n');
    var oracle_lines = std.mem.splitScalar(u8, oracle, '\n');
    while (true) {
        const svg_line = svg_lines.next();
        const oracle_line = oracle_lines.next();
        if (svg_line == null or oracle_line == null) {
            try std.testing.expect(svg_line == null and oracle_line == null);
            return;
        }
        try expectNumericNormalizedEqual(svg_line.?, oracle_line.?);
    }
}

pub fn nextDrawablePoints(svg: []const u8, index: *usize) ?DrawablePoints {
    while (std.mem.indexOfScalar(u8, svg[index.*..], '<')) |rel| {
        const tag_start = index.* + rel;
        index.* = tag_start + 1;
        if (index.* >= svg.len) return null;
        if (svg[index.*] == '!' or svg[index.*] == '?' or svg[index.*] == '/') continue;
        const name_start = index.*;
        while (index.* < svg.len and isNameChar(svg[index.*])) : (index.* += 1) {}
        const name = svg[name_start..index.*];
        const tag_end_rel = std.mem.indexOfScalar(u8, svg[index.*..], '>') orelse return null;
        const tag = svg[tag_start .. index.* + tag_end_rel + 1];
        index.* += tag_end_rel + 1;

        const attr_name: []const u8 = if (std.mem.eql(u8, name, "polygon") or std.mem.eql(u8, name, "polyline"))
            "points"
        else if (std.mem.eql(u8, name, "path"))
            "d"
        else
            continue;
        var result = DrawablePoints{ .tag = name, .numbers = undefined, .count = 0 };
        result.count = numbersInAttribute(tag, attr_name, result.numbers[0..]);
        if (result.count >= 2 and result.count % 2 == 0) return result;
    }
    return null;
}

pub fn screenPoint(svg: []const u8, point: Point) Point {
    const translate = graphvizTranslate(svg);
    return .{ .x = point.x + translate.x, .y = point.y + translate.y };
}

pub fn renderedEdgePathCount(svg: []const u8) usize {
    return countSubstrings(svg, "class=\"edge\"") - countSubstrings(svg, "class=\"edges\"");
}

pub fn expectDrawablePointsNear(svg: []const u8, oracle: []const u8, tolerance: f64) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    _ = nextDrawablePoints(svg, &svg_index) orelse return error.MissingSvgDrawable;
    _ = nextDrawablePoints(oracle, &oracle_index) orelse return error.MissingSvgDrawable;
    while (true) {
        const svg_drawable = nextDrawablePoints(svg, &svg_index);
        const oracle_drawable = nextDrawablePoints(oracle, &oracle_index);
        if (svg_drawable == null or oracle_drawable == null) {
            try std.testing.expect(svg_drawable == null and oracle_drawable == null);
            return;
        }
        try std.testing.expectEqualStrings(oracle_drawable.?.tag, svg_drawable.?.tag);
        try std.testing.expectEqual(oracle_drawable.?.count, svg_drawable.?.count);
        var point_index: usize = 0;
        while (point_index + 1 < svg_drawable.?.count) : (point_index += 2) {
            const point = screenPoint(svg, .{ .x = svg_drawable.?.numbers[point_index], .y = svg_drawable.?.numbers[point_index + 1] });
            const oracle_point = screenPoint(oracle, .{ .x = oracle_drawable.?.numbers[point_index], .y = oracle_drawable.?.numbers[point_index + 1] });
            try std.testing.expect(distanceBetween(point, oracle_point) <= tolerance);
        }
    }
}

pub fn expectDrawableOneDecimalGapNear(svg: []const u8, oracle: []const u8, tolerance: f64) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    _ = nextDrawablePoints(svg, &svg_index) orelse return error.MissingSvgDrawable;
    _ = nextDrawablePoints(oracle, &oracle_index) orelse return error.MissingSvgDrawable;
    while (true) {
        const svg_drawable = nextDrawablePoints(svg, &svg_index);
        const oracle_drawable = nextDrawablePoints(oracle, &oracle_index);
        if (svg_drawable == null or oracle_drawable == null) {
            try std.testing.expect(svg_drawable == null and oracle_drawable == null);
            return;
        }
        try std.testing.expectEqualStrings(oracle_drawable.?.tag, svg_drawable.?.tag);
        try std.testing.expectEqual(oracle_drawable.?.count, svg_drawable.?.count);
        var point_index: usize = 0;
        while (point_index + 1 < svg_drawable.?.count) : (point_index += 2) {
            const point = screenPoint(svg, .{ .x = svg_drawable.?.numbers[point_index], .y = svg_drawable.?.numbers[point_index + 1] });
            const oracle_point = screenPoint(oracle, .{ .x = oracle_drawable.?.numbers[point_index], .y = oracle_drawable.?.numbers[point_index + 1] });
            const residual = distanceBetween(point, oracle_point);
            const lower_bound = oneDecimalPointLowerBound(oracle_point);
            try std.testing.expect(residual - lower_bound <= tolerance);
        }
    }
}

pub fn expectEdgeCurveSamplesNear(svg: []const u8, oracle: []const u8, title: []const u8, tolerance: f64) !void {
    var numbers: [64]f64 = undefined;
    const count = pathNumbers(svg, title, numbers[0..]);
    if (count < 8 or count % 6 != 2) return error.MissingEdge;
    var oracle_numbers: [64]f64 = undefined;
    const oracle_count = pathNumbers(oracle, title, oracle_numbers[0..]);
    if (oracle_count != count) return error.MissingEdge;

    var segment_start: usize = 0;
    while (segment_start + 7 < count) : (segment_start += 6) {
        const p0 = screenPoint(svg, .{ .x = numbers[segment_start], .y = numbers[segment_start + 1] });
        const p1 = screenPoint(svg, .{ .x = numbers[segment_start + 2], .y = numbers[segment_start + 3] });
        const p2 = screenPoint(svg, .{ .x = numbers[segment_start + 4], .y = numbers[segment_start + 5] });
        const p3 = screenPoint(svg, .{ .x = numbers[segment_start + 6], .y = numbers[segment_start + 7] });
        const oracle_p0 = screenPoint(oracle, .{ .x = oracle_numbers[segment_start], .y = oracle_numbers[segment_start + 1] });
        const oracle_p1 = screenPoint(oracle, .{ .x = oracle_numbers[segment_start + 2], .y = oracle_numbers[segment_start + 3] });
        const oracle_p2 = screenPoint(oracle, .{ .x = oracle_numbers[segment_start + 4], .y = oracle_numbers[segment_start + 5] });
        const oracle_p3 = screenPoint(oracle, .{ .x = oracle_numbers[segment_start + 6], .y = oracle_numbers[segment_start + 7] });

        var sample: usize = 1;
        while (sample <= 3) : (sample += 1) {
            const t = @as(f64, @floatFromInt(sample)) / 4.0;
            const point = cubicPoint(p0, p1, p2, p3, t);
            const oracle_point = cubicPoint(oracle_p0, oracle_p1, oracle_p2, oracle_p3, t);
            try std.testing.expect(distanceBetween(point, oracle_point) <= tolerance);
        }
    }
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

fn expectNumericNormalizedEqual(a: []const u8, b: []const u8) !void {
    var ai: usize = 0;
    var bi: usize = 0;
    while (ai < a.len or bi < b.len) {
        if (ai < a.len and isNumberStart(a, ai) and bi < b.len and isNumberStart(b, bi)) {
            ai = skipNumber(a, ai);
            bi = skipNumber(b, bi);
            continue;
        }
        try std.testing.expect(ai < a.len and bi < b.len);
        try std.testing.expectEqual(a[ai], b[bi]);
        ai += 1;
        bi += 1;
    }
}

fn isNumberStart(text: []const u8, index: usize) bool {
    const c = text[index];
    if (std.ascii.isDigit(c)) return true;
    if ((c == '-' or c == '+') and index + 1 < text.len and std.ascii.isDigit(text[index + 1])) return true;
    return false;
}

fn skipNumber(text: []const u8, index: usize) usize {
    var i = index;
    if (i < text.len and (text[i] == '-' or text[i] == '+')) i += 1;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    if (i < text.len and text[i] == '.') {
        i += 1;
        while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    }
    return i;
}

fn oneDecimalPointLowerBound(point: Point) f64 {
    const min_x: i64 = @intFromFloat(@floor(point.x * 10.0) - 2.0);
    const max_x: i64 = @intFromFloat(@ceil(point.x * 10.0) + 2.0);
    const min_y: i64 = @intFromFloat(@floor(point.y * 10.0) - 2.0);
    const max_y: i64 = @intFromFloat(@ceil(point.y * 10.0) + 2.0);
    var best = std.math.floatMax(f64);
    var xi = min_x;
    while (xi <= max_x) : (xi += 1) {
        var yi = min_y;
        while (yi <= max_y) : (yi += 1) {
            const candidate = Point{ .x = @as(f64, @floatFromInt(xi)) / 10.0, .y = @as(f64, @floatFromInt(yi)) / 10.0 };
            best = @min(best, distanceBetween(candidate, point));
        }
    }
    return best;
}

fn cubicPoint(p0: Point, p1: Point, p2: Point, p3: Point, t: f64) Point {
    const u = 1.0 - t;
    const tt = t * t;
    const uu = u * u;
    const uuu = uu * u;
    const ttt = tt * t;
    return .{
        .x = uuu * p0.x + 3.0 * uu * t * p1.x + 3.0 * u * tt * p2.x + ttt * p3.x,
        .y = uuu * p0.y + 3.0 * uu * t * p1.y + 3.0 * u * tt * p2.y + ttt * p3.y,
    };
}

fn distanceBetween(a: Point, b: Point) f64 {
    return std.math.hypot(a.x - b.x, a.y - b.y);
}

fn isNameChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '-' or c == ':';
}

pub fn pathDataCommandCount(path_data: []const u8, command: u8) usize {
    var count: usize = 0;
    for (path_data) |c| {
        if (c == command) count += 1;
    }
    return count;
}

fn countSubstrings(haystack: []const u8, needle: []const u8) usize {
    if (needle.len == 0) return 0;
    var count: usize = 0;
    var offset: usize = 0;
    while (std.mem.indexOf(u8, haystack[offset..], needle)) |found| {
        count += 1;
        offset += found + needle.len;
    }
    return count;
}
