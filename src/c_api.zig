const std = @import("std");
const vex = @import("root.zig");

const allocator = std.heap.c_allocator;

pub const CGraph = opaque {};

pub const CString = extern struct {
    data: ?[*]const u8,
    len: usize,
};

pub const CBuffer = extern struct {
    data: ?[*]u8,
    len: usize,
};

pub const Status = enum(c_int) {
    ok = 0,
    invalid_argument = 1,
    out_of_memory = 2,
    parse = 3,
    invalid_node = 4,
    unknown_layout = 5,
    layout_canceled = 6,
    internal = 255,
};

pub const Layout = enum(c_int) {
    dot = 0,
    neato = 1,
    fdp = 2,
    sfdp = 3,
    fr = 4,
    twopi = 5,
    _,
};

pub const RenderOptions = extern struct {
    layout: Layout,
    iterations: usize,
    work_budget: usize,
    metadata: bool,
};

export fn vex_c_api_version() callconv(.c) u32 {
    return 1;
}

export fn vex_graph_create(
    directed: bool,
    name: CString,
    out_graph: ?*?*CGraph,
    out_error: ?*CBuffer,
) callconv(.c) Status {
    clearBuffer(out_error);
    const output = out_graph orelse return fail(.invalid_argument, out_error, "out_graph is required");
    output.* = null;
    const graph_name = stringSlice(name) orelse return fail(.invalid_argument, out_error, "name has null data with non-zero length");
    const graph = allocator.create(vex.Graph) catch return fail(.out_of_memory, out_error, "unable to allocate graph");
    errdefer allocator.destroy(graph);
    graph.* = vex.Graph.init(allocator, .{
        .directed = directed,
        .name = if (graph_name.len == 0) "G" else graph_name,
    }) catch |err| return failFromError(err, out_error);
    output.* = @ptrCast(graph);
    return .ok;
}

export fn vex_graph_destroy(handle: ?*CGraph) callconv(.c) void {
    const graph = graphFromHandle(handle) orelse return;
    graph.deinit();
    allocator.destroy(graph);
}

export fn vex_graph_add_node(
    handle: ?*CGraph,
    label: CString,
    out_node_id: ?*usize,
    out_error: ?*CBuffer,
) callconv(.c) Status {
    clearBuffer(out_error);
    const graph = graphFromHandle(handle) orelse return fail(.invalid_argument, out_error, "graph is required");
    const output = out_node_id orelse return fail(.invalid_argument, out_error, "out_node_id is required");
    const node_label = stringSlice(label) orelse return fail(.invalid_argument, out_error, "label has null data with non-zero length");
    output.* = graph.addNode(node_label, .{}) catch |err| return failFromError(err, out_error);
    return .ok;
}

export fn vex_graph_add_edge(
    handle: ?*CGraph,
    from: usize,
    to: usize,
    label: CString,
    out_edge_id: ?*usize,
    out_error: ?*CBuffer,
) callconv(.c) Status {
    clearBuffer(out_error);
    const graph = graphFromHandle(handle) orelse return fail(.invalid_argument, out_error, "graph is required");
    const output = out_edge_id orelse return fail(.invalid_argument, out_error, "out_edge_id is required");
    const edge_label = stringSlice(label) orelse return fail(.invalid_argument, out_error, "label has null data with non-zero length");
    output.* = graph.addEdge(from, to, .{
        .label = if (edge_label.len == 0) null else edge_label,
    }) catch |err| return failFromError(err, out_error);
    return .ok;
}

export fn vex_graph_render_svg(
    handle: ?*const CGraph,
    options: RenderOptions,
    out_svg: ?*CBuffer,
    out_error: ?*CBuffer,
) callconv(.c) Status {
    clearBuffer(out_svg);
    clearBuffer(out_error);
    const graph = constGraphFromHandle(handle) orelse return fail(.invalid_argument, out_error, "graph is required");
    return renderGraph(graph, options, out_svg, out_error);
}

export fn vex_dot_render_svg(
    dot: CString,
    options: RenderOptions,
    out_svg: ?*CBuffer,
    out_error: ?*CBuffer,
) callconv(.c) Status {
    clearBuffer(out_svg);
    clearBuffer(out_error);
    const source = stringSlice(dot) orelse return fail(.invalid_argument, out_error, "dot has null data with non-zero length");
    var result = vex.parseDotDiagnostic(allocator, source) catch |err| return failFromError(err, out_error);
    var graph = switch (result) {
        .graph => |graph| graph,
        .diagnostic => |*diagnostic| {
            defer diagnostic.deinit(allocator);
            return fail(.parse, out_error, diagnostic.message);
        },
    };
    defer graph.deinit();
    return renderGraph(&graph, options, out_svg, out_error);
}

export fn vex_buffer_free(buffer: CBuffer) callconv(.c) void {
    const data = buffer.data orelse return;
    if (buffer.len == 0) return;
    allocator.free(data[0..buffer.len]);
}

fn renderGraph(
    graph: *const vex.Graph,
    options: RenderOptions,
    out_svg: ?*CBuffer,
    out_error: ?*CBuffer,
) Status {
    const output = out_svg orelse return fail(.invalid_argument, out_error, "out_svg is required");
    const algorithm = layoutAlgorithm(options.layout) orelse return fail(.unknown_layout, out_error, "unknown layout enum");
    var budget = vex.LayoutWorkBudget{ .limit = if (options.work_budget == 0) std.math.maxInt(usize) else options.work_budget };
    const config = vex.LayoutConfig{
        .algorithm = algorithm,
        .force = if (options.iterations == 0) .{} else .{ .iterations = options.iterations },
        .control = if (options.work_budget == 0) .{} else budget.control(),
    };
    var layout = vex.layoutGraph(allocator, graph, config) catch |err| return failFromError(err, out_error);
    defer layout.deinit();
    const svg = vex.renderAlloc(allocator, &layout, .svg, .{
        .svg = .{ .metadata = options.metadata },
    }) catch |err| return failFromError(err, out_error);
    output.* = .{ .data = svg.ptr, .len = svg.len };
    return .ok;
}

fn layoutAlgorithm(layout: Layout) ?vex.LayoutAlgorithm {
    return switch (layout) {
        .dot => .sugiyama,
        .neato => .stress_majorization,
        .fdp => .spring_electrical,
        .sfdp => .multilevel_spring_electrical,
        .fr => .fruchterman_reingold,
        .twopi => .radial,
        else => null,
    };
}

fn stringSlice(value: CString) ?[]const u8 {
    if (value.len == 0) return "";
    const data = value.data orelse return null;
    return data[0..value.len];
}

fn graphFromHandle(handle: ?*CGraph) ?*vex.Graph {
    return @ptrCast(@alignCast(handle orelse return null));
}

fn constGraphFromHandle(handle: ?*const CGraph) ?*const vex.Graph {
    return @ptrCast(@alignCast(handle orelse return null));
}

fn clearBuffer(buffer: ?*CBuffer) void {
    if (buffer) |output| output.* = .{ .data = null, .len = 0 };
}

fn failFromError(err: anyerror, out_error: ?*CBuffer) Status {
    return if (err == error.OutOfMemory)
        fail(.out_of_memory, out_error, @errorName(err))
    else if (err == error.InvalidNodeId)
        fail(.invalid_node, out_error, @errorName(err))
    else if (err == error.LayoutCanceled)
        fail(.layout_canceled, out_error, @errorName(err))
    else
        fail(.internal, out_error, @errorName(err));
}

fn fail(status: Status, out_error: ?*CBuffer, message: []const u8) Status {
    if (out_error) |output| {
        const copy = allocator.dupe(u8, message) catch return .out_of_memory;
        output.* = .{ .data = copy.ptr, .len = copy.len };
    }
    return status;
}

fn cString(value: []const u8) CString {
    return .{ .data = value.ptr, .len = value.len };
}

fn bufferSlice(buffer: CBuffer) []const u8 {
    const data = buffer.data orelse return "";
    return data[0..buffer.len];
}

test "C API builds and renders SVG" {
    var handle: ?*CGraph = null;
    var error_buffer = CBuffer{ .data = null, .len = 0 };
    try std.testing.expectEqual(Status.ok, vex_graph_create(true, cString("CGraph"), &handle, &error_buffer));
    defer vex_graph_destroy(handle);
    try std.testing.expectEqual(@as(usize, 0), error_buffer.len);

    var a: usize = undefined;
    var b: usize = undefined;
    var edge: usize = undefined;
    try std.testing.expectEqual(Status.ok, vex_graph_add_node(handle, cString("A"), &a, &error_buffer));
    try std.testing.expectEqual(Status.ok, vex_graph_add_node(handle, cString("B"), &b, &error_buffer));
    try std.testing.expectEqual(Status.ok, vex_graph_add_edge(handle, a, b, cString("flow"), &edge, &error_buffer));
    try std.testing.expectEqual(@as(usize, 0), a);
    try std.testing.expectEqual(@as(usize, 1), b);
    try std.testing.expectEqual(@as(usize, 0), edge);

    var svg = CBuffer{ .data = null, .len = 0 };
    try std.testing.expectEqual(Status.ok, vex_graph_render_svg(handle, .{
        .layout = .dot,
        .iterations = 0,
        .work_budget = 0,
        .metadata = true,
    }, &svg, &error_buffer));
    defer vex_buffer_free(svg);
    try std.testing.expect(std.mem.indexOf(u8, bufferSlice(svg), "<title>CGraph</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, bufferSlice(svg), "data-vex-schema-version=\"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, bufferSlice(svg), ">flow</tspan>") != null);
}

test "C API renders DOT and reports parse errors" {
    var svg = CBuffer{ .data = null, .len = 0 };
    var error_buffer = CBuffer{ .data = null, .len = 0 };
    try std.testing.expectEqual(Status.ok, vex_dot_render_svg(cString("graph D { a -- b; }"), .{
        .layout = .neato,
        .iterations = 20,
        .work_budget = 0,
        .metadata = false,
    }, &svg, &error_buffer));
    vex_buffer_free(svg);
    try std.testing.expectEqual(@as(usize, 0), error_buffer.len);

    svg = .{ .data = null, .len = 0 };
    try std.testing.expectEqual(Status.parse, vex_dot_render_svg(cString("digraph G { a ->"), .{
        .layout = .dot,
        .iterations = 0,
        .work_budget = 0,
        .metadata = false,
    }, &svg, &error_buffer));
    defer vex_buffer_free(error_buffer);
    try std.testing.expectEqual(@as(usize, 0), svg.len);
    try std.testing.expect(error_buffer.len > 0);
}

test "C API exposes layout cancellation" {
    var svg = CBuffer{ .data = null, .len = 0 };
    var error_buffer = CBuffer{ .data = null, .len = 0 };
    try std.testing.expectEqual(Status.layout_canceled, vex_dot_render_svg(cString("graph G { a -- b -- c -- d -- a; }"), .{
        .layout = .sfdp,
        .iterations = 200,
        .work_budget = 1,
        .metadata = false,
    }, &svg, &error_buffer));
    defer vex_buffer_free(error_buffer);
    try std.testing.expectEqual(@as(usize, 0), svg.len);
    try std.testing.expectEqualStrings("LayoutCanceled", bufferSlice(error_buffer));
}
