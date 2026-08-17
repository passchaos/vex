//! Centralized visual themes inspired by high-quality diagram defaults.

const std = @import("std");
const layout_options = @import("layout/options.zig");

pub const Theme = enum {
    light,
    dark,
    print,

    pub fn tokens(self: Theme) Tokens {
        return switch (self) {
            .light => .{},
            .dark => .{
                .graph_background = "#161b22",
                .graph_font = "#f4f4f4",
                .node_fill = "#272c35",
                .node_stroke = "#3e444c",
                .node_font = "#d2d7df",
                .edge_stroke = "#59616c",
                .edge_font = "#d2d7df",
                .edge_label_fill = "#1e2229",
                .edge_label_stroke = "#3e444c",
                .subgraph_fill = "#272c35",
                .subgraph_stroke = "#3e444c",
                .subgraph_font = "#d2d7df",
            },
            .print => .{
                .graph_background = "#ffffff",
                .graph_font = "#111827",
                .node_fill = "#ffffff",
                .node_stroke = "#64748b",
                .node_font = "#111827",
                .edge_stroke = "#64748b",
                .edge_font = "#374151",
                .edge_label_fill = "#ffffff",
                .edge_label_stroke = "#cbd5e1",
                .subgraph_fill = "#ffffff",
                .subgraph_stroke = "#94a3b8",
                .subgraph_font = "#374151",
            },
        };
    }

    pub fn layoutProfile(self: Theme) layout_options.LayoutProfile {
        return switch (self) {
            .light, .dark => .relaxed,
            .print => .balanced,
        };
    }

    pub fn layoutConfig(self: Theme) layout_options.LayoutConfig {
        return layout_options.LayoutConfig.defaults(self.layoutProfile());
    }
};

pub const Tokens = struct {
    graph_background: []const u8 = "#fcfcfc",
    graph_font: []const u8 = "#202328",
    graph_font_name: []const u8 = "IBM Plex Mono,monospace",
    graph_font_size: f64 = 14,

    node_fill: []const u8 = "#f6f8fa",
    node_stroke: []const u8 = "#d2d9df",
    node_font: []const u8 = "#5b636d",
    node_font_name: []const u8 = "IBM Plex Mono,monospace",
    node_font_size: f64 = 12,
    node_pen_width: f64 = 0.8,
    node_margin: []const u8 = "0.16,0.10",

    edge_stroke: []const u8 = "#aeb8c2",
    edge_font: []const u8 = "#5b636d",
    edge_font_name: []const u8 = "IBM Plex Mono,monospace",
    edge_font_size: f64 = 11,
    edge_pen_width: f64 = 0.9,
    edge_arrow_size: f64 = 0.8,
    edge_label_fill: []const u8 = "#f4f5f6",
    edge_label_stroke: []const u8 = "#d2d9df",

    subgraph_fill: []const u8 = "#f7f7f8",
    subgraph_stroke: []const u8 = "#d2d9df",
    subgraph_font: []const u8 = "#5b636d",
    subgraph_font_name: []const u8 = "IBM Plex Mono,monospace",
    subgraph_font_size: f64 = 12,
    subgraph_pen_width: f64 = 0.8,
    subgraph_margin: []const u8 = "18",
};

test "themes select semantic layout profiles" {
    const light = Theme.light.layoutConfig();
    const dark = Theme.dark.layoutConfig();
    const print = Theme.print.layoutConfig();
    const relaxed = layout_options.LayoutConfig.defaults(.relaxed);
    const balanced = layout_options.LayoutConfig.defaults(.balanced);

    try std.testing.expectEqual(relaxed.layered.rank_gap, light.layered.rank_gap);
    try std.testing.expectEqual(relaxed.force.spring_length, light.force.spring_length);
    try std.testing.expectEqual(light.layered.rank_gap, dark.layered.rank_gap);
    try std.testing.expectEqual(light.force.spring_length, dark.force.spring_length);
    try std.testing.expectEqual(balanced.layered.rank_gap, print.layered.rank_gap);
    try std.testing.expectEqual(balanced.force.spring_length, print.force.spring_length);
}
