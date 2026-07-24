//! Subgraph layout attribute decisions.

const std = @import("std");

const spacing = @import("spacing.zig");

pub fn compoundEnabled(attrs: anytype) bool {
    const value = attrValue(attrs, "compound") orelse return false;
    return parseBool(value) orelse false;
}

pub fn compoundEnabledInChain(subgraphs: anytype, id: usize) bool {
    var current: ?usize = id;
    while (current) |index| {
        if (index >= subgraphs.len) return false;
        if (compoundEnabled(subgraphs[index].attrs.items)) return true;
        current = subgraphs[index].parent;
    }
    return false;
}

pub fn nodePairGap(subgraphs: anytype, left: usize, right: usize, fallback: f64) f64 {
    var best_gap: ?f64 = null;
    var best_depth: usize = 0;
    for (subgraphs, 0..) |cluster, index| {
        if (!containsNode(cluster.nodes, left) or !containsNode(cluster.nodes, right)) continue;
        const raw_nodesep = attrValue(cluster.attrs.items, "nodesep") orelse continue;
        const gap = spacing.graphValue(raw_nodesep) orelse continue;
        const depth = depthOf(subgraphs, index);
        if (best_gap == null or depth >= best_depth) {
            best_gap = gap;
            best_depth = depth;
        }
    }
    return best_gap orelse fallback;
}

pub fn rankGapBetween(subgraphs: anytype, ranks: []const usize, upper_rank: usize, fallback: f64) f64 {
    var best_gap = fallback;
    for (subgraphs) |cluster| {
        if (!hasMemberOnRank(cluster, ranks, upper_rank) or !hasMemberOnRank(cluster, ranks, upper_rank + 1)) continue;
        const raw_ranksep = attrValue(cluster.attrs.items, "ranksep") orelse continue;
        const gap = spacing.graphValue(raw_ranksep) orelse continue;
        best_gap = @max(best_gap, gap);
    }
    return best_gap;
}

pub fn virtualPairGap(subgraphs: anytype, edge_items: anytype, left: anytype, right: anytype, fallback: f64) f64 {
    var best_gap: ?f64 = null;
    var best_depth: usize = 0;
    for (subgraphs, 0..) |cluster, index| {
        if (!virtualNodeInSubgraph(edge_items, left, cluster) or !virtualNodeInSubgraph(edge_items, right, cluster)) continue;
        const raw_nodesep = attrValue(cluster.attrs.items, "nodesep") orelse continue;
        const gap = spacing.graphValue(raw_nodesep) orelse continue;
        const depth = depthOf(subgraphs, index);
        if (best_gap == null or depth >= best_depth) {
            best_gap = gap;
            best_depth = depth;
        }
    }
    return best_gap orelse fallback;
}

pub fn attrValue(attrs: anytype, name: []const u8) ?[]const u8 {
    for (attrs) |attr| {
        if (std.ascii.eqlIgnoreCase(attr.name, name)) return attr.value;
    }
    return null;
}

fn depthOf(subgraphs: anytype, index: usize) usize {
    var depth: usize = 0;
    var current = if (index < subgraphs.len) subgraphs[index].parent else null;
    while (current) |parent| {
        if (parent >= subgraphs.len) break;
        depth += 1;
        current = subgraphs[parent].parent;
    }
    return depth;
}

fn hasMemberOnRank(cluster: anytype, ranks: []const usize, rank: usize) bool {
    for (cluster.nodes) |node_id| {
        if (node_id < ranks.len and ranks[node_id] == rank) return true;
    }
    return false;
}

fn virtualNodeInSubgraph(edge_items: anytype, node: anytype, cluster: anytype) bool {
    return switch (node) {
        .real => |node_id| containsNode(cluster.nodes, node_id),
        .dummy => |edge_id| blk: {
            if (edge_id >= edge_items.len) break :blk false;
            const edge_item = edge_items[edge_id];
            break :blk containsNode(cluster.nodes, edge_item.from) and containsNode(cluster.nodes, edge_item.to);
        },
    };
}

fn containsNode(nodes: anytype, id: usize) bool {
    for (nodes) |node_id| {
        if (node_id == id) return true;
    }
    return false;
}

fn parseBool(value: []const u8) ?bool {
    if (std.ascii.eqlIgnoreCase(value, "true") or std.ascii.eqlIgnoreCase(value, "yes") or std.ascii.eqlIgnoreCase(value, "on") or std.mem.eql(u8, value, "1")) return true;
    if (std.ascii.eqlIgnoreCase(value, "false") or std.ascii.eqlIgnoreCase(value, "no") or std.ascii.eqlIgnoreCase(value, "off") or std.mem.eql(u8, value, "0")) return false;
    return null;
}
