//! Render ztex-powered math labels from the Vex API.
//!
//! Run with: zig build run-api-math-labels-svg

const std = @import("std");
const vex = @import("vex");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "MathLabels" });
    defer graph.deinit();

    try graph.setGraphAttr(.{ .label = "ztex-powered formula labels" });
    try graph.setGraphAttr(.{ .vex_math_label = true });

    const energy = try graph.addNode("Energy $E = mc^2$", .{
        .shape = .box,
        .vex_math_label = true,
        .fontsize = 18,
        .fontcolor = "#0f172a",
        .style = .rounded,
    });
    const fraction = try graph.addNode("Ratio $\\frac{x_1}{y^2}$", .{
        .shape = .ellipse,
        .vex_math_label = true,
        .fontsize = 18,
        .fontcolor = "#1d4ed8",
    });
    const velocity = try graph.addNode("Velocity $v^2$", .{
        .shape = .plain,
        .vex_math_label = true,
        .fontsize = 18,
    });
    const plain = try graph.addNode("Plain label", .{
        .shape = .box,
        .fontsize = 14,
    });

    _ = try graph.addEdge(energy, fraction, .{
        .label = "substitute $x_i$",
        .vex_math_label = true,
        .fontsize = 16,
        .labelaligned = true, // Math labels intentionally fall back from textPath.
        .color = "#2563eb",
        .fontcolor = "#2563eb",
    });
    _ = try graph.addEdge(fraction, velocity, .{
        .label = "simplify $\\sqrt{x^2+y^2}$",
        .vex_math_label = true,
        .fontsize = 16,
        .color = "#16a34a",
        .fontcolor = "#166534",
    });
    _ = try graph.addEdge(velocity, plain, .{
        .label = "ordinary edge label",
        .fontsize = 14,
    });

    try common.writeSvg(init.gpa, init.io, &graph, "16_math_labels.svg", .{});
}

test "math label API example builds a graph with opt-in formula labels" {
    const allocator = std.testing.allocator;
    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "MathLabels" });
    defer graph.deinit();
    const a = try graph.addNode("Energy $E=mc^2$", .{ .vex_math_label = true });
    const b = try graph.addNode("Ratio $\\frac{x}{y}$", .{ .vex_math_label = true });
    _ = try graph.addEdge(a, b, .{ .label = "cost $a^2$", .vex_math_label = true, .labelaligned = true });
    var layout = try vex.layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try vex.renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Energy ") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "cost ") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<textPath") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "$a^2$") == null or std.mem.indexOf(u8, svg, "<textPath") == null);
}
