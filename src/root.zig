//! Vex core library.
//!
//! The public API is intentionally split around a single graph model:
//! code can build graphs directly and parsers such as DOT lower into the
//! same model before layout/rendering.

const std = @import("std");
const Io = std.Io;

pub const NodeId = usize;
pub const EdgeId = usize;

pub const Shape = enum {
    ellipse,
    egg,
    box,
    polygon,
    square,
    circle,
    doublecircle,
    point,
    diamond,
    mdiamond,
    msquare,
    mcircle,
    triangle,
    invtriangle,
    parallelogram,
    trapezium,
    invtrapezium,
    house,
    invhouse,
    pentagon,
    hexagon,
    septagon,
    octagon,
    doubleoctagon,
    tripleoctagon,
    star,
    note,
    tab,
    folder,
    box3d,
    component,
    underline,
    cylinder,
    plaintext,
    record,
    mrecord,
};

pub const RankDir = enum {
    TB,
    BT,
    LR,
    RL,

    pub fn fromString(value: []const u8) ?RankDir {
        if (std.ascii.eqlIgnoreCase(value, "TB")) return .TB;
        if (std.ascii.eqlIgnoreCase(value, "BT")) return .BT;
        if (std.ascii.eqlIgnoreCase(value, "LR")) return .LR;
        if (std.ascii.eqlIgnoreCase(value, "RL")) return .RL;
        return null;
    }
};

pub const RankKind = enum {
    same,
    min,
    max,
    source,
    sink,

    pub fn fromString(value: []const u8) ?RankKind {
        if (std.ascii.eqlIgnoreCase(value, "same")) return .same;
        if (std.ascii.eqlIgnoreCase(value, "min")) return .min;
        if (std.ascii.eqlIgnoreCase(value, "max")) return .max;
        if (std.ascii.eqlIgnoreCase(value, "source")) return .source;
        if (std.ascii.eqlIgnoreCase(value, "sink")) return .sink;
        return null;
    }
};

pub const Attr = struct {
    name: []const u8,
    value: []const u8,
};

pub const RankConstraint = struct {
    kind: RankKind,
    node_ids: []NodeId,
};

pub const CompassPort = enum {
    auto,
    center,
    north,
    north_east,
    east,
    south_east,
    south,
    south_west,
    west,
    north_west,
};

pub const EdgeOptions = struct {
    label: ?[]const u8 = null,
    color: ?[]const u8 = null,
    weight: ?f64 = null,
    constraint: ?bool = null,
    min_len: ?usize = null,
    tail_port: CompassPort = .auto,
    head_port: CompassPort = .auto,
    tail_record_port: ?[]const u8 = null,
    head_record_port: ?[]const u8 = null,
    ltail: ?[]const u8 = null,
    lhead: ?[]const u8 = null,
};

pub const NodeOptions = struct {
    label: ?[]const u8 = null,
    color: ?[]const u8 = null,
    shape: ?Shape = null,
};

pub const GraphOptions = struct {
    directed: bool = true,
    strict: bool = false,
    name: []const u8 = "G",
    rankdir: RankDir = .TB,
};

pub const Node = struct {
    id: NodeId,
    name: []const u8,
    label: []const u8,
    color: []const u8,
    shape: Shape,
    attrs: std.ArrayList(Attr) = .empty,
};

pub const Edge = struct {
    id: EdgeId,
    from: NodeId,
    to: NodeId,
    label: ?[]const u8 = null,
    color: []const u8 = "black",
    weight: f64 = 1.0,
    constraint: bool = true,
    min_len: usize = 1,
    tail_port: CompassPort = .auto,
    head_port: CompassPort = .auto,
    tail_record_port: ?[]const u8 = null,
    head_record_port: ?[]const u8 = null,
    ltail: ?[]const u8 = null,
    lhead: ?[]const u8 = null,
    attrs: std.ArrayList(Attr) = .empty,
};

pub const Cluster = struct {
    id: usize,
    parent_name: ?[]const u8 = null,
    name: []const u8,
    label: []const u8,
    nodes: []NodeId,
    attrs: std.ArrayList(Attr) = .empty,
};

const NodeDefaults = struct {
    color: []const u8 = "black",
    shape: Shape = .ellipse,
};

const EdgeDefaults = struct {
    color: []const u8 = "black",
    weight: f64 = 1.0,
    constraint: bool = true,
    min_len: usize = 1,
};

pub const Graph = struct {
    allocator: std.mem.Allocator,
    directed: bool,
    strict: bool,
    name: []const u8,
    rankdir: RankDir,
    nodes: std.ArrayList(Node) = .empty,
    edges: std.ArrayList(Edge) = .empty,
    clusters: std.ArrayList(Cluster) = .empty,
    rank_constraints: std.ArrayList(RankConstraint) = .empty,
    attrs: std.ArrayList(Attr) = .empty,
    node_default_attrs: std.ArrayList(Attr) = .empty,
    edge_default_attrs: std.ArrayList(Attr) = .empty,
    node_index: std.StringHashMap(NodeId),
    node_defaults: NodeDefaults = .{},
    edge_defaults: EdgeDefaults = .{},

    pub fn init(allocator: std.mem.Allocator, options: GraphOptions) !Graph {
        const name = try allocator.dupe(u8, options.name);
        errdefer allocator.free(name);
        const node_color = try allocator.dupe(u8, "black");
        errdefer allocator.free(node_color);
        const edge_color = try allocator.dupe(u8, "black");
        errdefer allocator.free(edge_color);
        return .{
            .allocator = allocator,
            .directed = options.directed,
            .strict = options.strict,
            .name = name,
            .rankdir = options.rankdir,
            .node_index = std.StringHashMap(NodeId).init(allocator),
            .node_defaults = .{ .color = node_color },
            .edge_defaults = .{ .color = edge_color },
        };
    }

    pub fn deinit(self: *Graph) void {
        for (self.nodes.items) |*n| {
            self.allocator.free(n.name);
            if (n.label.ptr != n.name.ptr) self.allocator.free(n.label);
            self.allocator.free(n.color);
            for (n.attrs.items) |attr| {
                self.allocator.free(attr.name);
                self.allocator.free(attr.value);
            }
            n.attrs.deinit(self.allocator);
        }
        for (self.edges.items) |*e| {
            if (e.label) |label| self.allocator.free(label);
            if (e.tail_record_port) |port| self.allocator.free(port);
            if (e.head_record_port) |port| self.allocator.free(port);
            if (e.ltail) |cluster_name| self.allocator.free(cluster_name);
            if (e.lhead) |cluster_name| self.allocator.free(cluster_name);
            self.allocator.free(e.color);
            for (e.attrs.items) |attr| {
                self.allocator.free(attr.name);
                self.allocator.free(attr.value);
            }
            e.attrs.deinit(self.allocator);
        }
        for (self.attrs.items) |attr| {
            self.allocator.free(attr.name);
            self.allocator.free(attr.value);
        }
        for (self.clusters.items) |*cluster| {
            self.allocator.free(cluster.name);
            if (cluster.parent_name) |parent_name| self.allocator.free(parent_name);
            if (cluster.label.ptr != cluster.name.ptr) self.allocator.free(cluster.label);
            self.allocator.free(cluster.nodes);
            freeAttrList(self.allocator, &cluster.attrs);
        }
        for (self.rank_constraints.items) |constraint| {
            self.allocator.free(constraint.node_ids);
        }
        freeAttrList(self.allocator, &self.node_default_attrs);
        freeAttrList(self.allocator, &self.edge_default_attrs);
        self.nodes.deinit(self.allocator);
        self.edges.deinit(self.allocator);
        self.clusters.deinit(self.allocator);
        self.rank_constraints.deinit(self.allocator);
        self.attrs.deinit(self.allocator);
        self.node_index.deinit();
        self.allocator.free(self.node_defaults.color);
        self.allocator.free(self.edge_defaults.color);
        self.allocator.free(self.name);
        self.* = undefined;
    }

    pub fn node(self: *Graph, name: []const u8) !NodeId {
        if (self.node_index.get(name)) |id| return id;

        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        const owned_color = try self.allocator.dupe(u8, self.node_defaults.color);
        errdefer self.allocator.free(owned_color);

        var attrs = try copyAttrList(self.allocator, self.node_default_attrs.items);
        errdefer {
            for (attrs.items) |attr| {
                self.allocator.free(attr.name);
                self.allocator.free(attr.value);
            }
            attrs.deinit(self.allocator);
        }
        try setAttrInList(self.allocator, &attrs, "color", owned_color);
        try setAttrInList(self.allocator, &attrs, "shape", shapeName(self.node_defaults.shape));

        const id = self.nodes.items.len;
        const n = Node{
            .id = id,
            .name = owned_name,
            .label = owned_name,
            .color = owned_color,
            .shape = self.node_defaults.shape,
            .attrs = attrs,
        };
        try self.nodes.append(self.allocator, n);
        errdefer _ = self.nodes.pop();
        try self.node_index.put(owned_name, id);
        return id;
    }

    pub fn nodeWith(self: *Graph, name: []const u8, options: NodeOptions) !NodeId {
        const id = try self.node(name);
        if (options.label) |label| try self.setNodeAttr(id, "label", label);
        if (options.color) |color| try self.setNodeAttr(id, "color", color);
        if (options.shape) |shape| try self.setNodeShape(id, shape);
        return id;
    }

    pub fn edge(self: *Graph, from: NodeId, to: NodeId, options: EdgeOptions) !EdgeId {
        if (from >= self.nodes.items.len or to >= self.nodes.items.len) return error.InvalidNodeId;
        if (self.strict) {
            for (self.edges.items) |existing| {
                const same_directed = existing.from == from and existing.to == to;
                const same_undirected = !self.directed and existing.from == to and existing.to == from;
                if (same_directed or same_undirected) return existing.id;
            }
        }

        const owned_label = if (options.label) |label| try expandEdgeLabel(self.allocator, self, from, to, label) else null;
        errdefer if (owned_label) |label| self.allocator.free(label);
        const owned_color = try self.allocator.dupe(u8, options.color orelse self.edge_defaults.color);
        errdefer self.allocator.free(owned_color);
        const owned_tail_record_port = if (options.tail_record_port) |port| try self.allocator.dupe(u8, port) else null;
        errdefer if (owned_tail_record_port) |port| self.allocator.free(port);
        const owned_head_record_port = if (options.head_record_port) |port| try self.allocator.dupe(u8, port) else null;
        errdefer if (owned_head_record_port) |port| self.allocator.free(port);
        const owned_ltail = if (options.ltail) |cluster_name| try self.allocator.dupe(u8, cluster_name) else null;
        errdefer if (owned_ltail) |cluster_name| self.allocator.free(cluster_name);
        const owned_lhead = if (options.lhead) |cluster_name| try self.allocator.dupe(u8, cluster_name) else null;
        errdefer if (owned_lhead) |cluster_name| self.allocator.free(cluster_name);

        var attrs = try copyAttrList(self.allocator, self.edge_default_attrs.items);
        errdefer {
            for (attrs.items) |attr| {
                self.allocator.free(attr.name);
                self.allocator.free(attr.value);
            }
            attrs.deinit(self.allocator);
        }
        try setAttrInList(self.allocator, &attrs, "color", owned_color);
        if (owned_label) |label| try setAttrInList(self.allocator, &attrs, "label", label);

        const id = self.edges.items.len;
        const e = Edge{
            .id = id,
            .from = from,
            .to = to,
            .label = owned_label,
            .color = owned_color,
            .weight = options.weight orelse self.edge_defaults.weight,
            .constraint = options.constraint orelse self.edge_defaults.constraint,
            .min_len = @max(options.min_len orelse self.edge_defaults.min_len, 1),
            .tail_port = options.tail_port,
            .head_port = options.head_port,
            .tail_record_port = owned_tail_record_port,
            .head_record_port = owned_head_record_port,
            .ltail = owned_ltail,
            .lhead = owned_lhead,
            .attrs = attrs,
        };
        try self.edges.append(self.allocator, e);
        return id;
    }

    pub fn edgeByName(self: *Graph, from_name: []const u8, to_name: []const u8, options: EdgeOptions) !EdgeId {
        const from = try self.node(from_name);
        const to = try self.node(to_name);
        return self.edge(from, to, options);
    }

    pub fn addRankConstraint(self: *Graph, kind: RankKind, node_ids: []const NodeId) !void {
        if (node_ids.len == 0) return;
        const owned_nodes = try self.allocator.dupe(NodeId, node_ids);
        errdefer self.allocator.free(owned_nodes);
        try self.rank_constraints.append(self.allocator, .{ .kind = kind, .node_ids = owned_nodes });
    }

    pub fn addCluster(self: *Graph, name: []const u8, parent_name: ?[]const u8, node_ids: []const NodeId, attrs: []const Attr) !usize {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        const owned_parent_name = if (parent_name) |value| try self.allocator.dupe(u8, value) else null;
        errdefer if (owned_parent_name) |value| self.allocator.free(value);
        const owned_nodes = try self.allocator.dupe(NodeId, node_ids);
        errdefer self.allocator.free(owned_nodes);
        var owned_attrs = try copyAttrList(self.allocator, attrs);
        errdefer freeAttrList(self.allocator, &owned_attrs);
        const label_value = attrValue(owned_attrs.items, "label") orelse owned_name;
        const owned_label = if (label_value.ptr == owned_name.ptr)
            owned_name
        else
            try self.allocator.dupe(u8, label_value);
        errdefer if (owned_label.ptr != owned_name.ptr) self.allocator.free(owned_label);
        const id = self.clusters.items.len;
        try self.clusters.append(self.allocator, .{
            .id = id,
            .parent_name = owned_parent_name,
            .name = owned_name,
            .label = owned_label,
            .nodes = owned_nodes,
            .attrs = owned_attrs,
        });
        return id;
    }

    pub fn setGraphAttr(self: *Graph, name: []const u8, value: []const u8) !void {
        if (std.ascii.eqlIgnoreCase(name, "rankdir")) {
            if (RankDir.fromString(value)) |rankdir| self.rankdir = rankdir;
        }
        try setAttrInList(self.allocator, &self.attrs, name, value);
    }

    pub fn setDefaultNodeAttr(self: *Graph, name: []const u8, value: []const u8) !void {
        try setAttrInList(self.allocator, &self.node_default_attrs, name, value);
        if (std.ascii.eqlIgnoreCase(name, "color") or std.ascii.eqlIgnoreCase(name, "fillcolor")) {
            const owned = try self.allocator.dupe(u8, value);
            self.allocator.free(self.node_defaults.color);
            self.node_defaults.color = owned;
        } else if (std.ascii.eqlIgnoreCase(name, "shape")) {
            self.node_defaults.shape = parseShape(value);
        }
    }

    pub fn setDefaultEdgeAttr(self: *Graph, name: []const u8, value: []const u8) !void {
        try setAttrInList(self.allocator, &self.edge_default_attrs, name, value);
        if (std.ascii.eqlIgnoreCase(name, "color")) {
            const owned = try self.allocator.dupe(u8, value);
            self.allocator.free(self.edge_defaults.color);
            self.edge_defaults.color = owned;
        } else if (std.ascii.eqlIgnoreCase(name, "weight")) {
            self.edge_defaults.weight = std.fmt.parseFloat(f64, value) catch self.edge_defaults.weight;
        } else if (std.ascii.eqlIgnoreCase(name, "constraint")) {
            self.edge_defaults.constraint = parseBool(value) orelse self.edge_defaults.constraint;
        } else if (std.ascii.eqlIgnoreCase(name, "minlen") or std.ascii.eqlIgnoreCase(name, "min_len")) {
            self.edge_defaults.min_len = @max(std.fmt.parseInt(usize, value, 10) catch self.edge_defaults.min_len, 1);
        }
    }

    pub fn setNodeAttr(self: *Graph, id: NodeId, name: []const u8, value: []const u8) !void {
        if (id >= self.nodes.items.len) return error.InvalidNodeId;
        var n = &self.nodes.items[id];
        if (std.ascii.eqlIgnoreCase(name, "label")) {
            const expanded = try expandNodeLabel(self.allocator, self, n.name, value);
            if (n.label.ptr != n.name.ptr) self.allocator.free(n.label);
            n.label = expanded;
        } else if (std.ascii.eqlIgnoreCase(name, "color") or std.ascii.eqlIgnoreCase(name, "fillcolor")) {
            const owned = try self.allocator.dupe(u8, value);
            self.allocator.free(n.color);
            n.color = owned;
        } else if (std.ascii.eqlIgnoreCase(name, "shape")) {
            n.shape = parseShape(value);
        }
        try setAttrInList(self.allocator, &n.attrs, name, value);
    }

    pub fn setNodeShape(self: *Graph, id: NodeId, shape: Shape) !void {
        if (id >= self.nodes.items.len) return error.InvalidNodeId;
        self.nodes.items[id].shape = shape;
        try setAttrInList(self.allocator, &self.nodes.items[id].attrs, "shape", shapeName(shape));
    }

    pub fn setEdgeAttr(self: *Graph, id: EdgeId, name: []const u8, value: []const u8) !void {
        if (id >= self.edges.items.len) return error.InvalidEdgeId;
        var e = &self.edges.items[id];
        if (std.ascii.eqlIgnoreCase(name, "label")) {
            const expanded = try expandEdgeLabel(self.allocator, self, e.from, e.to, value);
            if (e.label) |label| self.allocator.free(label);
            e.label = expanded;
        } else if (std.ascii.eqlIgnoreCase(name, "color")) {
            const owned = try self.allocator.dupe(u8, value);
            self.allocator.free(e.color);
            e.color = owned;
        } else if (std.ascii.eqlIgnoreCase(name, "weight")) {
            e.weight = std.fmt.parseFloat(f64, value) catch e.weight;
        } else if (std.ascii.eqlIgnoreCase(name, "constraint")) {
            e.constraint = parseBool(value) orelse e.constraint;
        } else if (std.ascii.eqlIgnoreCase(name, "minlen") or std.ascii.eqlIgnoreCase(name, "min_len")) {
            e.min_len = @max(std.fmt.parseInt(usize, value, 10) catch e.min_len, 1);
        } else if (std.ascii.eqlIgnoreCase(name, "ltail")) {
            if (e.ltail) |cluster_name| self.allocator.free(cluster_name);
            e.ltail = try self.allocator.dupe(u8, value);
        } else if (std.ascii.eqlIgnoreCase(name, "lhead")) {
            if (e.lhead) |cluster_name| self.allocator.free(cluster_name);
            e.lhead = try self.allocator.dupe(u8, value);
        }
        try setAttrInList(self.allocator, &e.attrs, name, value);
    }
};

fn freeAttrList(allocator: std.mem.Allocator, list: *std.ArrayList(Attr)) void {
    for (list.items) |attr| {
        allocator.free(attr.name);
        allocator.free(attr.value);
    }
    list.deinit(allocator);
}

fn copyAttrList(allocator: std.mem.Allocator, source: []const Attr) !std.ArrayList(Attr) {
    var result = std.ArrayList(Attr).empty;
    errdefer freeAttrList(allocator, &result);
    for (source) |attr| try setAttrInList(allocator, &result, attr.name, attr.value);
    return result;
}

fn setAttrInList(allocator: std.mem.Allocator, list: *std.ArrayList(Attr), name: []const u8, value: []const u8) !void {
    for (list.items) |*attr| {
        if (std.ascii.eqlIgnoreCase(attr.name, name)) {
            const new_value = try allocator.dupe(u8, value);
            allocator.free(attr.value);
            attr.value = new_value;
            return;
        }
    }

    try list.append(allocator, .{
        .name = try allocator.dupe(u8, name),
        .value = try allocator.dupe(u8, value),
    });
}

fn parseShape(value: []const u8) Shape {
    if (std.ascii.eqlIgnoreCase(value, "box") or std.ascii.eqlIgnoreCase(value, "rect") or std.ascii.eqlIgnoreCase(value, "rectangle")) return .box;
    if (std.ascii.eqlIgnoreCase(value, "polygon")) return .polygon;
    if (std.ascii.eqlIgnoreCase(value, "square")) return .square;
    if (std.ascii.eqlIgnoreCase(value, "ellipse") or std.ascii.eqlIgnoreCase(value, "oval")) return .ellipse;
    if (std.ascii.eqlIgnoreCase(value, "egg")) return .egg;
    if (std.ascii.eqlIgnoreCase(value, "circle")) return .circle;
    if (std.ascii.eqlIgnoreCase(value, "doublecircle")) return .doublecircle;
    if (std.ascii.eqlIgnoreCase(value, "point")) return .point;
    if (std.ascii.eqlIgnoreCase(value, "diamond")) return .diamond;
    if (std.ascii.eqlIgnoreCase(value, "Mdiamond")) return .mdiamond;
    if (std.ascii.eqlIgnoreCase(value, "Msquare")) return .msquare;
    if (std.ascii.eqlIgnoreCase(value, "Mcircle")) return .mcircle;
    if (std.ascii.eqlIgnoreCase(value, "triangle")) return .triangle;
    if (std.ascii.eqlIgnoreCase(value, "invtriangle")) return .invtriangle;
    if (std.ascii.eqlIgnoreCase(value, "parallelogram")) return .parallelogram;
    if (std.ascii.eqlIgnoreCase(value, "trapezium") or std.ascii.eqlIgnoreCase(value, "trapezoid")) return .trapezium;
    if (std.ascii.eqlIgnoreCase(value, "invtrapezium") or std.ascii.eqlIgnoreCase(value, "invtrapezoid")) return .invtrapezium;
    if (std.ascii.eqlIgnoreCase(value, "house")) return .house;
    if (std.ascii.eqlIgnoreCase(value, "invhouse")) return .invhouse;
    if (std.ascii.eqlIgnoreCase(value, "pentagon")) return .pentagon;
    if (std.ascii.eqlIgnoreCase(value, "hexagon")) return .hexagon;
    if (std.ascii.eqlIgnoreCase(value, "septagon")) return .septagon;
    if (std.ascii.eqlIgnoreCase(value, "octagon")) return .octagon;
    if (std.ascii.eqlIgnoreCase(value, "doubleoctagon")) return .doubleoctagon;
    if (std.ascii.eqlIgnoreCase(value, "tripleoctagon")) return .tripleoctagon;
    if (std.ascii.eqlIgnoreCase(value, "star")) return .star;
    if (std.ascii.eqlIgnoreCase(value, "note")) return .note;
    if (std.ascii.eqlIgnoreCase(value, "tab")) return .tab;
    if (std.ascii.eqlIgnoreCase(value, "folder")) return .folder;
    if (std.ascii.eqlIgnoreCase(value, "box3d")) return .box3d;
    if (std.ascii.eqlIgnoreCase(value, "component")) return .component;
    if (std.ascii.eqlIgnoreCase(value, "underline")) return .underline;
    if (std.ascii.eqlIgnoreCase(value, "cylinder")) return .cylinder;
    if (std.ascii.eqlIgnoreCase(value, "plaintext") or std.ascii.eqlIgnoreCase(value, "plain") or std.ascii.eqlIgnoreCase(value, "none")) return .plaintext;
    if (std.ascii.eqlIgnoreCase(value, "record")) return .record;
    if (std.ascii.eqlIgnoreCase(value, "mrecord")) return .mrecord;
    return .ellipse;
}

fn shapeName(shape: Shape) []const u8 {
    return switch (shape) {
        .ellipse => "ellipse",
        .egg => "egg",
        .box => "box",
        .polygon => "polygon",
        .square => "square",
        .circle => "circle",
        .doublecircle => "doublecircle",
        .point => "point",
        .diamond => "diamond",
        .mdiamond => "Mdiamond",
        .msquare => "Msquare",
        .mcircle => "Mcircle",
        .triangle => "triangle",
        .invtriangle => "invtriangle",
        .parallelogram => "parallelogram",
        .trapezium => "trapezium",
        .invtrapezium => "invtrapezium",
        .house => "house",
        .invhouse => "invhouse",
        .pentagon => "pentagon",
        .hexagon => "hexagon",
        .septagon => "septagon",
        .octagon => "octagon",
        .doubleoctagon => "doubleoctagon",
        .tripleoctagon => "tripleoctagon",
        .star => "star",
        .note => "note",
        .tab => "tab",
        .folder => "folder",
        .box3d => "box3d",
        .component => "component",
        .underline => "underline",
        .cylinder => "cylinder",
        .plaintext => "plaintext",
        .record => "record",
        .mrecord => "Mrecord",
    };
}

fn parseBool(value: []const u8) ?bool {
    if (std.ascii.eqlIgnoreCase(value, "true") or std.mem.eql(u8, value, "1")) return true;
    if (std.ascii.eqlIgnoreCase(value, "false") or std.mem.eql(u8, value, "0")) return false;
    return null;
}

fn isCompassPort(value: []const u8) bool {
    return parseCompassPort(value) != null;
}

fn parseCompassPort(value: []const u8) ?CompassPort {
    if (std.ascii.eqlIgnoreCase(value, "n")) return .north;
    if (std.ascii.eqlIgnoreCase(value, "ne")) return .north_east;
    if (std.ascii.eqlIgnoreCase(value, "e")) return .east;
    if (std.ascii.eqlIgnoreCase(value, "se")) return .south_east;
    if (std.ascii.eqlIgnoreCase(value, "s")) return .south;
    if (std.ascii.eqlIgnoreCase(value, "sw")) return .south_west;
    if (std.ascii.eqlIgnoreCase(value, "w")) return .west;
    if (std.ascii.eqlIgnoreCase(value, "nw")) return .north_west;
    if (std.ascii.eqlIgnoreCase(value, "c")) return .center;
    if (std.ascii.eqlIgnoreCase(value, "_")) return .auto;
    return null;
}

const TokenTag = enum {
    eof,
    id,
    string,
    html,
    lbrace,
    rbrace,
    lbracket,
    rbracket,
    equal,
    comma,
    semicolon,
    colon,
    plus,
    arrow,
    dashdash,
};

const Token = struct {
    tag: TokenTag,
    lexeme: []const u8,
    line: usize,
    column: usize,
};

const Lexer = struct {
    source: []const u8,
    index: usize = 0,
    line: usize = 1,
    column: usize = 1,

    fn next(self: *Lexer) !Token {
        try self.skipIgnored();
        if (self.index >= self.source.len) return self.token(.eof, self.index, self.index);

        const start = self.index;
        const line = self.line;
        const column = self.column;
        const c = self.advance();
        return switch (c) {
            '{' => .{ .tag = .lbrace, .lexeme = self.source[start..self.index], .line = line, .column = column },
            '}' => .{ .tag = .rbrace, .lexeme = self.source[start..self.index], .line = line, .column = column },
            '[' => .{ .tag = .lbracket, .lexeme = self.source[start..self.index], .line = line, .column = column },
            ']' => .{ .tag = .rbracket, .lexeme = self.source[start..self.index], .line = line, .column = column },
            '=' => .{ .tag = .equal, .lexeme = self.source[start..self.index], .line = line, .column = column },
            ',' => .{ .tag = .comma, .lexeme = self.source[start..self.index], .line = line, .column = column },
            ';' => .{ .tag = .semicolon, .lexeme = self.source[start..self.index], .line = line, .column = column },
            ':' => .{ .tag = .colon, .lexeme = self.source[start..self.index], .line = line, .column = column },
            '+' => .{ .tag = .plus, .lexeme = self.source[start..self.index], .line = line, .column = column },
            '<' => blk: {
                while (self.index < self.source.len) {
                    const ch = self.advance();
                    if (ch == '>') {
                        var lookahead = self.index;
                        while (lookahead < self.source.len and std.ascii.isWhitespace(self.source[lookahead])) : (lookahead += 1) {}
                        if (lookahead >= self.source.len or isHtmlIdTerminator(self.source[lookahead])) break;
                    }
                } else return error.UnterminatedHtmlString;
                break :blk .{ .tag = .html, .lexeme = self.source[start + 1 .. self.index - 1], .line = line, .column = column };
            },
            '-' => blk: {
                if (self.index >= self.source.len) return error.UnexpectedCharacter;
                if (self.peek() == '>') {
                    _ = self.advance();
                    break :blk .{ .tag = .arrow, .lexeme = self.source[start..self.index], .line = line, .column = column };
                }
                if (self.peek() == '-') {
                    _ = self.advance();
                    break :blk .{ .tag = .dashdash, .lexeme = self.source[start..self.index], .line = line, .column = column };
                }
                if (self.index < self.source.len and (std.ascii.isDigit(self.peek()) or self.peek() == '.')) {
                    while (self.index < self.source.len and isIdChar(self.peek())) _ = self.advance();
                    break :blk .{ .tag = .id, .lexeme = self.source[start..self.index], .line = line, .column = column };
                }
                return error.UnexpectedCharacter;
            },
            '"' => blk: {
                while (self.index < self.source.len) {
                    const ch = self.advance();
                    if (ch == '\\' and self.index < self.source.len) {
                        _ = self.advance();
                    } else if (ch == '"') {
                        break;
                    }
                } else return error.UnterminatedString;
                break :blk .{ .tag = .string, .lexeme = self.source[start + 1 .. self.index - 1], .line = line, .column = column };
            },
            else => blk: {
                if (!isIdChar(c)) return error.UnexpectedCharacter;
                while (self.index < self.source.len and isIdChar(self.peek())) _ = self.advance();
                break :blk .{ .tag = .id, .lexeme = self.source[start..self.index], .line = line, .column = column };
            },
        };
    }

    fn token(self: Lexer, tag: TokenTag, start: usize, end: usize) Token {
        return .{ .tag = tag, .lexeme = self.source[start..end], .line = self.line, .column = self.column };
    }

    fn skipIgnored(self: *Lexer) !void {
        while (self.index < self.source.len) {
            const c = self.peek();
            switch (c) {
                ' ', '\t', '\r' => _ = self.advance(),
                '\n' => _ = self.advance(),
                '/' => {
                    if (self.index + 1 >= self.source.len) return;
                    const next_c = self.source[self.index + 1];
                    if (next_c == '/') {
                        while (self.index < self.source.len and self.peek() != '\n') _ = self.advance();
                    } else if (next_c == '*') {
                        _ = self.advance();
                        _ = self.advance();
                        while (self.index + 1 < self.source.len) {
                            const a = self.advance();
                            if (a == '*' and self.peek() == '/') {
                                _ = self.advance();
                                break;
                            }
                        } else return error.UnterminatedComment;
                    } else return;
                },
                '#' => {
                    while (self.index < self.source.len and self.peek() != '\n') _ = self.advance();
                },
                else => return,
            }
        }
    }

    fn peek(self: Lexer) u8 {
        return self.source[self.index];
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.index];
        self.index += 1;
        if (c == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
        return c;
    }
};

fn isIdChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '.' or c == '-' or c >= 0x80;
}

fn isHtmlIdTerminator(c: u8) bool {
    return switch (c) {
        ']', ',', ';', '{', '}', '-' => true,
        else => false,
    };
}

const AttrList = std.ArrayList(Attr);
const NodeSet = std.ArrayList(NodeId);

const NodeRef = struct {
    id: NodeId,
    port: CompassPort = .auto,
    record_port: ?[]const u8 = null,
};

const NodeRefSet = std.ArrayList(NodeRef);

const ParsedPort = struct {
    compass: CompassPort = .auto,
    record_port: ?[]const u8 = null,
};

fn containsNode(nodes: []const NodeId, id: NodeId) bool {
    for (nodes) |existing| if (existing == id) return true;
    return false;
}

fn freeNodeRefSet(allocator: std.mem.Allocator, refs: *NodeRefSet) void {
    for (refs.items) |ref| {
        if (ref.record_port) |port| allocator.free(port);
    }
    refs.deinit(allocator);
}

fn isClusterName(name: []const u8) bool {
    return std.ascii.startsWithIgnoreCase(name, "cluster");
}

const DefaultScope = struct {
    node_attrs: AttrList,
    edge_attrs: AttrList,
    node_color: []const u8,
    node_shape: Shape,
    edge_color: []const u8,
    edge_weight: f64,
    edge_constraint: bool,
    edge_min_len: usize,
    restored: bool = false,

    fn snapshot(allocator: std.mem.Allocator, graph: *const Graph) !DefaultScope {
        var node_attrs = try copyAttrList(allocator, graph.node_default_attrs.items);
        errdefer freeAttrList(allocator, &node_attrs);
        var edge_attrs = try copyAttrList(allocator, graph.edge_default_attrs.items);
        errdefer freeAttrList(allocator, &edge_attrs);
        const node_color = try allocator.dupe(u8, graph.node_defaults.color);
        errdefer allocator.free(node_color);
        const edge_color = try allocator.dupe(u8, graph.edge_defaults.color);
        errdefer allocator.free(edge_color);
        return .{
            .node_attrs = node_attrs,
            .edge_attrs = edge_attrs,
            .node_color = node_color,
            .node_shape = graph.node_defaults.shape,
            .edge_color = edge_color,
            .edge_weight = graph.edge_defaults.weight,
            .edge_constraint = graph.edge_defaults.constraint,
            .edge_min_len = graph.edge_defaults.min_len,
        };
    }

    fn restore(self: *DefaultScope, allocator: std.mem.Allocator, graph: *Graph) void {
        freeAttrList(allocator, &graph.node_default_attrs);
        freeAttrList(allocator, &graph.edge_default_attrs);
        allocator.free(graph.node_defaults.color);
        allocator.free(graph.edge_defaults.color);

        graph.node_default_attrs = self.node_attrs;
        graph.edge_default_attrs = self.edge_attrs;
        graph.node_defaults = .{ .color = self.node_color, .shape = self.node_shape };
        graph.edge_defaults = .{
            .color = self.edge_color,
            .weight = self.edge_weight,
            .constraint = self.edge_constraint,
            .min_len = self.edge_min_len,
        };

        self.node_attrs = .empty;
        self.edge_attrs = .empty;
        self.restored = true;
    }

    fn deinit(self: *DefaultScope, allocator: std.mem.Allocator) void {
        if (self.restored) return;
        freeAttrList(allocator, &self.node_attrs);
        freeAttrList(allocator, &self.edge_attrs);
        allocator.free(self.node_color);
        allocator.free(self.edge_color);
    }
};

const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    current: Token,
    collectors: std.ArrayList(*NodeSet) = .empty,
    rank_scopes: std.ArrayList(*?RankKind) = .empty,
    cluster_scopes: std.ArrayList(?*AttrList) = .empty,
    cluster_stack: std.ArrayList([]const u8) = .empty,

    fn init(allocator: std.mem.Allocator, source: []const u8) !Parser {
        var lexer: Lexer = .{ .source = source };
        const first = try lexer.next();
        return .{ .allocator = allocator, .lexer = lexer, .current = first };
    }

    fn parse(self: *Parser) !Graph {
        defer self.collectors.deinit(self.allocator);
        defer self.rank_scopes.deinit(self.allocator);
        defer self.cluster_scopes.deinit(self.allocator);
        defer self.cluster_stack.deinit(self.allocator);
        var strict = false;
        if (self.matchKeyword("strict")) strict = true;

        const directed = if (self.matchKeyword("digraph")) true else if (self.matchKeyword("graph")) false else return error.ExpectedGraph;
        const name = if (self.current.tag == .id or self.current.tag == .string or self.current.tag == .html) blk: {
            const n = self.current.lexeme;
            try self.advance();
            break :blk n;
        } else "G";

        var graph = try Graph.init(self.allocator, .{ .directed = directed, .strict = strict, .name = name });
        errdefer graph.deinit();

        try self.expect(.lbrace);
        try self.parseStmtList(&graph);
        try self.expect(.rbrace);
        try self.expect(.eof);
        return graph;
    }

    fn parseStmtList(self: *Parser, graph: *Graph) anyerror!void {
        while (self.current.tag != .rbrace and self.current.tag != .eof) {
            if (self.current.tag == .semicolon or self.current.tag == .comma) {
                try self.advance();
                continue;
            }
            try self.parseStmt(graph);
            _ = self.match(.semicolon);
        }
    }

    fn parseStmt(self: *Parser, graph: *Graph) anyerror!void {
        if (self.matchKeyword("graph")) {
            var attrs = AttrList.empty;
            defer freeTempAttrs(self.allocator, &attrs);
            try self.parseAttrLists(&attrs);
            for (attrs.items) |attr| {
                if (try self.recordRankAttr(attr.name, attr.value)) continue;
                if (try self.recordClusterAttr(attr.name, attr.value)) continue;
                try graph.setGraphAttr(attr.name, attr.value);
            }
            return;
        }
        if (self.matchKeyword("node")) {
            var attrs = AttrList.empty;
            defer freeTempAttrs(self.allocator, &attrs);
            try self.parseAttrLists(&attrs);
            for (attrs.items) |attr| try graph.setDefaultNodeAttr(attr.name, attr.value);
            return;
        }
        if (self.matchKeyword("edge")) {
            var attrs = AttrList.empty;
            defer freeTempAttrs(self.allocator, &attrs);
            try self.parseAttrLists(&attrs);
            for (attrs.items) |attr| try graph.setDefaultEdgeAttr(attr.name, attr.value);
            return;
        }
        if (self.isSubgraphStart()) {
            var first = try self.parseOperand(graph);
            defer first.deinit(self.allocator);
            if (self.current.tag == .arrow or self.current.tag == .dashdash) {
                try self.parseEdgeTail(graph, &first);
            } else {
                var attrs = AttrList.empty;
                defer freeTempAttrs(self.allocator, &attrs);
                try self.parseAttrLists(&attrs);
                for (first.items) |node_id| {
                    for (attrs.items) |attr| try graph.setNodeAttr(node_id, attr.name, attr.value);
                }
            }
            return;
        }

        const first_name = try self.parseIdText();
        defer self.allocator.free(first_name);
        const first_port = try self.parseOptionalPort();
        defer if (first_port.record_port) |port| self.allocator.free(port);

        if (self.match(.equal)) {
            const value = try self.parseIdText();
            defer self.allocator.free(value);
            if (try self.recordRankAttr(first_name, value)) return;
            if (try self.recordClusterAttr(first_name, value)) return;
            try graph.setGraphAttr(first_name, value);
            return;
        }

        var first = NodeSet.empty;
        defer first.deinit(self.allocator);
        const first_id = try graph.node(first_name);
        try self.recordNode(first_id);
        try first.append(self.allocator, first_id);
        while (self.match(.comma)) {
            const name = try self.parseNodeIdText();
            defer self.allocator.free(name);
            const id = try graph.node(name);
            try self.recordNode(id);
            if (!containsNode(first.items, id)) try first.append(self.allocator, id);
        }

        if (self.current.tag == .arrow or self.current.tag == .dashdash) {
            var first_refs = NodeRefSet.empty;
            defer freeNodeRefSet(self.allocator, &first_refs);
            try first_refs.append(self.allocator, .{
                .id = first_id,
                .port = first_port.compass,
                .record_port = if (first_port.record_port) |port| try self.allocator.dupe(u8, port) else null,
            });
            for (first.items[1..]) |id| try first_refs.append(self.allocator, .{ .id = id });
            try self.parseEdgeTailRefs(graph, &first_refs);
        } else {
            var attrs = AttrList.empty;
            defer freeTempAttrs(self.allocator, &attrs);
            try self.parseAttrLists(&attrs);
            for (first.items) |node_id| {
                for (attrs.items) |attr| try graph.setNodeAttr(node_id, attr.name, attr.value);
            }
        }
    }

    fn parseEdgeTail(self: *Parser, graph: *Graph, first: *NodeSet) anyerror!void {
        var first_refs = NodeRefSet.empty;
        errdefer freeNodeRefSet(self.allocator, &first_refs);
        for (first.items) |id| try first_refs.append(self.allocator, .{ .id = id });
        try self.parseEdgeTailRefs(graph, &first_refs);
        first.deinit(self.allocator);
        first.* = .empty;
    }

    fn parseEdgeTailRefs(self: *Parser, graph: *Graph, first_refs: *NodeRefSet) anyerror!void {
        var operands = std.ArrayList(NodeRefSet).empty;
        defer {
            for (operands.items) |*operand| freeNodeRefSet(self.allocator, operand);
            operands.deinit(self.allocator);
        }
        errdefer freeNodeRefSet(self.allocator, first_refs);
        try operands.append(self.allocator, first_refs.*);
        first_refs.* = .empty;

        while (self.current.tag == .arrow or self.current.tag == .dashdash) {
            const op = self.current.tag;
            try self.advance();
            if (graph.directed and op != .arrow) return error.EdgeOpMismatch;
            if (!graph.directed and op != .dashdash) return error.EdgeOpMismatch;
            try operands.append(self.allocator, try self.parseOperandRefs(graph));
        }

        var attrs = AttrList.empty;
        defer freeTempAttrs(self.allocator, &attrs);
        try self.parseAttrLists(&attrs);

        var i: usize = 0;
        while (i + 1 < operands.items.len) : (i += 1) {
            for (operands.items[i].items) |from| {
                for (operands.items[i + 1].items) |to| {
                    const edge_id = try graph.edge(from.id, to.id, .{
                        .tail_port = from.port,
                        .head_port = to.port,
                        .tail_record_port = from.record_port,
                        .head_record_port = to.record_port,
                    });
                    for (attrs.items) |attr| try graph.setEdgeAttr(edge_id, attr.name, attr.value);
                }
            }
        }
    }

    fn parseOperandRefs(self: *Parser, graph: *Graph) anyerror!NodeRefSet {
        if (self.isSubgraphStart()) {
            var nodes = try self.parseSubgraph(graph);
            defer nodes.deinit(self.allocator);
            var refs = NodeRefSet.empty;
            errdefer freeNodeRefSet(self.allocator, &refs);
            for (nodes.items) |id| try refs.append(self.allocator, .{ .id = id });
            return refs;
        }
        return self.parseNodeRefList(graph);
    }

    fn parseOperand(self: *Parser, graph: *Graph) anyerror!NodeSet {
        if (self.isSubgraphStart()) return self.parseSubgraph(graph);
        return self.parseNodeList(graph);
    }

    fn parseNodeRefList(self: *Parser, graph: *Graph) !NodeRefSet {
        var refs = NodeRefSet.empty;
        errdefer freeNodeRefSet(self.allocator, &refs);
        while (true) {
            const parsed = try self.parseNodeRef(graph);
            try self.recordNode(parsed.id);
            try refs.append(self.allocator, parsed);
            if (!self.match(.comma)) break;
        }
        return refs;
    }

    fn parseNodeList(self: *Parser, graph: *Graph) !NodeSet {
        var nodes = NodeSet.empty;
        errdefer nodes.deinit(self.allocator);
        while (true) {
            const name = try self.parseNodeIdText();
            defer self.allocator.free(name);
            const id = try graph.node(name);
            try self.recordNode(id);
            if (!containsNode(nodes.items, id)) try nodes.append(self.allocator, id);
            if (!self.match(.comma)) break;
        }
        return nodes;
    }

    fn parseNodeRef(self: *Parser, graph: *Graph) !NodeRef {
        const name = try self.parseIdText();
        defer self.allocator.free(name);
        const id = try graph.node(name);
        const parsed_port = try self.parseOptionalPort();
        return .{ .id = id, .port = parsed_port.compass, .record_port = parsed_port.record_port };
    }

    fn parseOptionalPort(self: *Parser) !ParsedPort {
        if (!self.match(.colon)) return .{};

        const port = try self.parseIdText();
        defer self.allocator.free(port);

        var result: ParsedPort = .{};
        if (parseCompassPort(port)) |compass| {
            result.compass = compass;
        } else {
            result.record_port = try self.allocator.dupe(u8, port);
        }

        if (self.match(.colon)) {
            const compass = try self.parseIdText();
            if (parseCompassPort(compass)) |compass_port| result.compass = compass_port;
            self.allocator.free(compass);
        }

        return result;
    }

    fn parseSubgraph(self: *Parser, graph: *Graph) anyerror!NodeSet {
        var subgraph_name: ?[]const u8 = null;
        if (self.matchKeyword("subgraph")) {
            if (self.current.tag == .id or self.current.tag == .string or self.current.tag == .html) {
                subgraph_name = self.current.lexeme;
                try self.advance();
            }
        }
        try self.expect(.lbrace);

        var defaults = try DefaultScope.snapshot(self.allocator, graph);
        defer defaults.deinit(self.allocator);

        var cluster_attrs = AttrList.empty;
        defer freeAttrList(self.allocator, &cluster_attrs);
        const is_cluster = if (subgraph_name) |name| isClusterName(name) else false;
        const parent_cluster = if (is_cluster and self.cluster_stack.items.len > 0) self.cluster_stack.items[self.cluster_stack.items.len - 1] else null;

        var nodes = NodeSet.empty;
        errdefer nodes.deinit(self.allocator);
        var rank_kind: ?RankKind = null;
        try self.collectors.append(self.allocator, &nodes);
        errdefer self.collectors.items.len -= 1;
        try self.rank_scopes.append(self.allocator, &rank_kind);
        errdefer self.rank_scopes.items.len -= 1;
        try self.cluster_scopes.append(self.allocator, if (is_cluster) &cluster_attrs else null);
        errdefer self.cluster_scopes.items.len -= 1;
        if (is_cluster) try self.cluster_stack.append(self.allocator, subgraph_name.?);
        errdefer {
            if (is_cluster) self.cluster_stack.items.len -= 1;
        }
        try self.parseStmtList(graph);
        self.collectors.items.len -= 1;
        self.rank_scopes.items.len -= 1;
        self.cluster_scopes.items.len -= 1;
        if (is_cluster) self.cluster_stack.items.len -= 1;
        try self.expect(.rbrace);
        if (rank_kind) |kind| try graph.addRankConstraint(kind, nodes.items);
        if (is_cluster) _ = try graph.addCluster(subgraph_name.?, parent_cluster, nodes.items, cluster_attrs.items);
        defaults.restore(self.allocator, graph);
        return nodes;
    }

    fn isSubgraphStart(self: Parser) bool {
        return self.current.tag == .lbrace or (self.current.tag == .id and std.ascii.eqlIgnoreCase(self.current.lexeme, "subgraph"));
    }

    fn recordNode(self: *Parser, id: NodeId) !void {
        for (self.collectors.items) |collector| {
            if (!containsNode(collector.items, id)) try collector.append(self.allocator, id);
        }
    }

    fn recordRankAttr(self: *Parser, name: []const u8, value: []const u8) !bool {
        if (!std.ascii.eqlIgnoreCase(name, "rank")) return false;
        const kind = RankKind.fromString(value) orelse return false;
        if (self.rank_scopes.items.len == 0) return false;
        self.rank_scopes.items[self.rank_scopes.items.len - 1].* = kind;
        return true;
    }

    fn recordClusterAttr(self: *Parser, name: []const u8, value: []const u8) !bool {
        if (self.cluster_scopes.items.len == 0) return false;
        const attrs = self.cluster_scopes.items[self.cluster_scopes.items.len - 1] orelse return false;
        try setAttrInList(self.allocator, attrs, name, value);
        return true;
    }

    fn parseAttrLists(self: *Parser, attrs: *AttrList) !void {
        while (self.match(.lbracket)) {
            while (self.current.tag != .rbracket and self.current.tag != .eof) {
                if (self.current.tag == .comma or self.current.tag == .semicolon) {
                    try self.advance();
                    continue;
                }
                const name = try self.parseIdText();
                errdefer self.allocator.free(name);
                const value = if (self.match(.equal))
                    try self.parseIdText()
                else
                    try self.allocator.dupe(u8, "true");
                errdefer self.allocator.free(value);
                try attrs.append(self.allocator, .{ .name = name, .value = value });
                _ = self.match(.comma) or self.match(.semicolon);
            }
            try self.expect(.rbracket);
        }
    }

    fn parseNodeIdText(self: *Parser) ![]const u8 {
        const name = try self.parseIdText();
        if (self.match(.colon)) {
            const port = try self.parseIdText();
            self.allocator.free(port);
            if (self.match(.colon)) {
                const compass = try self.parseIdText();
                self.allocator.free(compass);
            }
        }
        return name;
    }

    fn parseIdText(self: *Parser) ![]const u8 {
        if (self.current.tag != .id and self.current.tag != .string and self.current.tag != .html) return error.ExpectedId;
        var value = if (self.current.tag == .string)
            try dupeDotString(self.allocator, self.current.lexeme)
        else
            try self.allocator.dupe(u8, self.current.lexeme);
        errdefer self.allocator.free(value);
        try self.advance();
        while (self.current.tag == .plus) {
            try self.advance();
            if (self.current.tag != .string) return error.ExpectedStringAfterConcat;
            const rhs = try dupeDotString(self.allocator, self.current.lexeme);
            defer self.allocator.free(rhs);
            const joined = try std.mem.concat(self.allocator, u8, &.{ value, rhs });
            self.allocator.free(value);
            value = joined;
            try self.advance();
        }
        return value;
    }

    fn matchKeyword(self: *Parser, keyword: []const u8) bool {
        if (self.current.tag == .id and std.ascii.eqlIgnoreCase(self.current.lexeme, keyword)) {
            self.advance() catch unreachable;
            return true;
        }
        return false;
    }

    fn match(self: *Parser, tag: TokenTag) bool {
        if (self.current.tag == tag) {
            self.advance() catch unreachable;
            return true;
        }
        return false;
    }

    fn expect(self: *Parser, tag: TokenTag) !void {
        if (self.current.tag != tag) return error.UnexpectedToken;
        try self.advance();
    }

    fn advance(self: *Parser) !void {
        self.current = try self.lexer.next();
    }
};

fn freeTempAttrs(allocator: std.mem.Allocator, attrs: *AttrList) void {
    for (attrs.items) |attr| {
        allocator.free(attr.name);
        allocator.free(attr.value);
    }
    attrs.deinit(allocator);
}

fn dupeDotString(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    if (std.mem.indexOfScalar(u8, value, '\\') == null) return allocator.dupe(u8, value);
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < value.len) : (i += 1) {
        const c = value[i];
        if (c != '\\' or i + 1 >= value.len) {
            try out.append(allocator, c);
            continue;
        }
        i += 1;
        const escaped = value[i];
        switch (escaped) {
            'n', 'l', 'r' => try out.append(allocator, '\n'),
            't' => try out.append(allocator, '\t'),
            '"' => try out.append(allocator, '"'),
            '\\' => try out.append(allocator, '\\'),
            '\n' => {},
            else => {
                try out.append(allocator, '\\');
                try out.append(allocator, escaped);
            },
        }
    }
    return out.toOwnedSlice(allocator);
}

fn expandNodeLabel(allocator: std.mem.Allocator, graph: *const Graph, node_name: []const u8, value: []const u8) ![]u8 {
    return expandLabelEscapes(allocator, value, .{
        .graph_name = graph.name,
        .node_name = node_name,
    });
}

fn expandEdgeLabel(allocator: std.mem.Allocator, graph: *const Graph, from: NodeId, to: NodeId, value: []const u8) ![]u8 {
    const tail = graph.nodes.items[from].name;
    const head = graph.nodes.items[to].name;
    var edge_name_buf: [256]u8 = undefined;
    const op = if (graph.directed) "->" else "--";
    const edge_name = std.fmt.bufPrint(&edge_name_buf, "{s}{s}{s}", .{ tail, op, head }) catch tail;
    return expandLabelEscapes(allocator, value, .{
        .graph_name = graph.name,
        .node_name = null,
        .tail_name = tail,
        .head_name = head,
        .edge_name = edge_name,
    });
}

const LabelEscapeContext = struct {
    graph_name: []const u8,
    node_name: ?[]const u8 = null,
    tail_name: ?[]const u8 = null,
    head_name: ?[]const u8 = null,
    edge_name: ?[]const u8 = null,
};

fn expandLabelEscapes(allocator: std.mem.Allocator, value: []const u8, context: LabelEscapeContext) ![]u8 {
    if (std.mem.indexOfScalar(u8, value, '\\') == null) return allocator.dupe(u8, value);
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < value.len) : (i += 1) {
        const c = value[i];
        if (c != '\\' or i + 1 >= value.len) {
            try out.append(allocator, c);
            continue;
        }
        i += 1;
        switch (value[i]) {
            'G' => try out.appendSlice(allocator, context.graph_name),
            'N' => if (context.node_name) |name| try out.appendSlice(allocator, name) else try out.appendSlice(allocator, "\\N"),
            'T' => if (context.tail_name) |name| try out.appendSlice(allocator, name) else try out.appendSlice(allocator, "\\T"),
            'H' => if (context.head_name) |name| try out.appendSlice(allocator, name) else try out.appendSlice(allocator, "\\H"),
            'E' => if (context.edge_name) |name| try out.appendSlice(allocator, name) else try out.appendSlice(allocator, "\\E"),
            else => |escaped| {
                try out.append(allocator, '\\');
                try out.append(allocator, escaped);
            },
        }
    }
    return out.toOwnedSlice(allocator);
}

pub fn parseDot(allocator: std.mem.Allocator, source: []const u8) !Graph {
    var parser = try Parser.init(allocator, source);
    return parser.parse();
}

pub const InputFormat = enum {
    auto,
    dot,
    mermaid,

    pub fn fromString(value: []const u8) ?InputFormat {
        if (std.ascii.eqlIgnoreCase(value, "auto")) return .auto;
        if (std.ascii.eqlIgnoreCase(value, "dot") or std.ascii.eqlIgnoreCase(value, "graphviz")) return .dot;
        if (std.ascii.eqlIgnoreCase(value, "mermaid") or std.ascii.eqlIgnoreCase(value, "mmd")) return .mermaid;
        return null;
    }
};

pub fn parseInput(allocator: std.mem.Allocator, source: []const u8, format: InputFormat) !Graph {
    return switch (if (format == .auto) detectInputFormat(source) else format) {
        .auto => unreachable,
        .dot => parseDot(allocator, source),
        .mermaid => parseMermaid(allocator, source),
    };
}

pub fn detectInputFormat(source: []const u8) InputFormat {
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line_raw| {
        const line = trimMermaidLine(line_raw);
        if (line.len == 0 or std.mem.startsWith(u8, line, "%%")) continue;
        if (startsWithMermaidHeader(line)) return .mermaid;
        return .dot;
    }
    return .dot;
}

pub fn parseMermaid(allocator: std.mem.Allocator, source: []const u8) !Graph {
    var lines = std.mem.splitScalar(u8, source, '\n');
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "Mermaid" });
    errdefer graph.deinit();

    var class_defs = std.ArrayList(MermaidClassDef).empty;
    defer class_defs.deinit(allocator);
    var saw_header = false;
    var subgraph_name: ?[]const u8 = null;
    var subgraph_label: ?[]const u8 = null;
    var subgraph_nodes = std.ArrayList(NodeId).empty;
    defer subgraph_nodes.deinit(allocator);
    while (lines.next()) |line_raw| {
        const line = trimMermaidLine(line_raw);
        if (line.len == 0 or std.mem.startsWith(u8, line, "%%")) continue;
        if (!saw_header and startsWithMermaidHeader(line)) {
            saw_header = true;
            try applyMermaidDirection(&graph, line);
            continue;
        }
        if (std.mem.startsWith(u8, line, "style ")) {
            try applyMermaidStyleStatement(&graph, line);
            continue;
        }
        if (std.mem.startsWith(u8, line, "classDef ")) {
            try parseMermaidClassDef(allocator, &class_defs, line);
            continue;
        }
        if (std.mem.startsWith(u8, line, "class ")) {
            try applyMermaidClassStatement(&graph, class_defs.items, line);
            continue;
        }
        if (std.mem.startsWith(u8, line, "linkStyle ")) {
            try applyMermaidLinkStyleStatement(&graph, line);
            continue;
        }
        if (parseMermaidSubgraphHeader(line)) |header| {
            if (subgraph_name) |name| {
                try addMermaidSubgraph(&graph, name, subgraph_label orelse name, subgraph_nodes.items);
                subgraph_nodes.clearRetainingCapacity();
            }
            subgraph_name = header.name;
            subgraph_label = header.label;
            continue;
        }
        if (std.mem.eql(u8, line, "end")) {
            if (subgraph_name) |name| {
                try addMermaidSubgraph(&graph, name, subgraph_label orelse name, subgraph_nodes.items);
                subgraph_name = null;
                subgraph_label = null;
                subgraph_nodes.clearRetainingCapacity();
            }
            continue;
        }
        try parseMermaidStatement(&graph, line, if (subgraph_name != null) &subgraph_nodes else null, class_defs.items);
    }
    if (subgraph_name) |name| {
        try addMermaidSubgraph(&graph, name, subgraph_label orelse name, subgraph_nodes.items);
    }

    return graph;
}

fn startsWithMermaidHeader(line: []const u8) bool {
    var parts = std.mem.tokenizeAny(u8, line, " \t");
    const first = parts.next() orelse return false;
    if (!std.mem.eql(u8, first, "graph") and !std.mem.eql(u8, first, "flowchart")) return false;
    const second = parts.next() orelse return true;
    return std.ascii.eqlIgnoreCase(second, "TD") or
        std.ascii.eqlIgnoreCase(second, "TB") or
        std.ascii.eqlIgnoreCase(second, "BT") or
        std.ascii.eqlIgnoreCase(second, "LR") or
        std.ascii.eqlIgnoreCase(second, "RL");
}

fn trimMermaidLine(line: []const u8) []const u8 {
    var trimmed = std.mem.trim(u8, line, " \t\r\n;");
    if (std.mem.indexOf(u8, trimmed, "%%")) |comment| {
        trimmed = std.mem.trim(u8, trimmed[0..comment], " \t\r\n;");
    }
    return trimmed;
}

fn applyMermaidDirection(graph: *Graph, line: []const u8) !void {
    var parts = std.mem.tokenizeAny(u8, line, " \t");
    _ = parts.next();
    const dir = parts.next() orelse "TD";
    if (std.ascii.eqlIgnoreCase(dir, "LR")) {
        try graph.setGraphAttr("rankdir", "LR");
    } else if (std.ascii.eqlIgnoreCase(dir, "RL")) {
        try graph.setGraphAttr("rankdir", "RL");
    } else if (std.ascii.eqlIgnoreCase(dir, "BT")) {
        try graph.setGraphAttr("rankdir", "BT");
    } else {
        try graph.setGraphAttr("rankdir", "TB");
    }
}

fn applyMermaidStyleStatement(graph: *Graph, line: []const u8) !void {
    var rest = std.mem.trim(u8, line["style".len..], " \t\r\n");
    if (rest.len == 0) return;
    var split_at: usize = 0;
    while (split_at < rest.len and !std.ascii.isWhitespace(rest[split_at])) : (split_at += 1) {}
    if (split_at == 0 or split_at >= rest.len) return;
    const ids_text = rest[0..split_at];
    rest = std.mem.trim(u8, rest[split_at..], " \t\r\n");
    var ids = std.mem.splitScalar(u8, ids_text, ',');
    while (ids.next()) |raw_id| {
        const id = std.mem.trim(u8, raw_id, " \t\r\n");
        if (id.len == 0) continue;
        const node_id = try graph.node(id);
        try applyMermaidStyleAttrs(graph, node_id, rest);
    }
}

const MermaidClassDef = struct {
    name: []const u8,
    attrs: []const u8,
};

fn parseMermaidClassDef(allocator: std.mem.Allocator, class_defs: *std.ArrayList(MermaidClassDef), line: []const u8) !void {
    var rest = std.mem.trim(u8, line["classDef".len..], " \t\r\n");
    if (rest.len == 0) return;
    var split_at: usize = 0;
    while (split_at < rest.len and !std.ascii.isWhitespace(rest[split_at])) : (split_at += 1) {}
    if (split_at == 0 or split_at >= rest.len) return;
    const name = rest[0..split_at];
    const attrs = std.mem.trim(u8, rest[split_at..], " \t\r\n");
    for (class_defs.items) |*def| {
        if (std.mem.eql(u8, def.name, name)) {
            def.attrs = attrs;
            return;
        }
    }
    try class_defs.append(allocator, .{ .name = name, .attrs = attrs });
}

fn applyMermaidClassStatement(graph: *Graph, class_defs: []const MermaidClassDef, line: []const u8) !void {
    var rest = std.mem.trim(u8, line["class".len..], " \t\r\n");
    if (rest.len == 0) return;
    var split_at: usize = 0;
    while (split_at < rest.len and !std.ascii.isWhitespace(rest[split_at])) : (split_at += 1) {}
    if (split_at == 0 or split_at >= rest.len) return;
    const ids_text = rest[0..split_at];
    const classes_text = std.mem.trim(u8, rest[split_at..], " \t\r\n");
    var ids = std.mem.splitScalar(u8, ids_text, ',');
    while (ids.next()) |raw_id| {
        const id = std.mem.trim(u8, raw_id, " \t\r\n");
        if (id.len == 0) continue;
        const node_id = try graph.node(id);
        var classes = std.mem.splitScalar(u8, classes_text, ',');
        while (classes.next()) |raw_class| {
            const class_name = std.mem.trim(u8, raw_class, " \t\r\n");
            const attrs = mermaidClassAttrs(class_defs, class_name) orelse continue;
            try applyMermaidStyleAttrs(graph, node_id, attrs);
        }
    }
}

fn mermaidClassAttrs(class_defs: []const MermaidClassDef, name: []const u8) ?[]const u8 {
    for (class_defs) |def| {
        if (std.mem.eql(u8, def.name, name)) return def.attrs;
    }
    return null;
}

fn applyMermaidLinkStyleStatement(graph: *Graph, line: []const u8) !void {
    var rest = std.mem.trim(u8, line["linkStyle".len..], " \t\r\n");
    if (rest.len == 0) return;
    var split_at: usize = 0;
    while (split_at < rest.len and !std.ascii.isWhitespace(rest[split_at])) : (split_at += 1) {}
    if (split_at == 0 or split_at >= rest.len) return;
    const selector_text = rest[0..split_at];
    const attrs_text = std.mem.trim(u8, rest[split_at..], " \t\r\n");
    if (std.ascii.eqlIgnoreCase(selector_text, "default")) {
        for (graph.edges.items, 0..) |_, edge_index| try applyMermaidEdgeStyleAttrs(graph, edge_index, attrs_text);
        return;
    }
    var selectors = std.mem.splitScalar(u8, selector_text, ',');
    while (selectors.next()) |raw_selector| {
        const selector = std.mem.trim(u8, raw_selector, " \t\r\n");
        if (selector.len == 0) continue;
        const index = std.fmt.parseInt(usize, selector, 10) catch continue;
        if (index < graph.edges.items.len) try applyMermaidEdgeStyleAttrs(graph, index, attrs_text);
    }
}

fn applyMermaidEdgeStyleAttrs(graph: *Graph, edge_id: EdgeId, attrs_text: []const u8) !void {
    var attrs = std.mem.splitScalar(u8, attrs_text, ',');
    while (attrs.next()) |raw_attr| {
        const attr = std.mem.trim(u8, raw_attr, " \t\r\n;");
        if (attr.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, attr, ':') orelse continue;
        const key = std.mem.trim(u8, attr[0..colon], " \t\r\n");
        const value = std.mem.trim(u8, attr[colon + 1 ..], " \t\r\n");
        if (value.len == 0) continue;
        if (std.ascii.eqlIgnoreCase(key, "stroke")) {
            try graph.setEdgeAttr(edge_id, "color", value);
        } else if (std.ascii.eqlIgnoreCase(key, "stroke-width")) {
            try graph.setEdgeAttr(edge_id, "penwidth", trimMermaidCssUnit(value));
        } else if (std.ascii.eqlIgnoreCase(key, "stroke-dasharray")) {
            try graph.setEdgeAttr(edge_id, "style", "dashed");
        } else if (std.ascii.eqlIgnoreCase(key, "color")) {
            try graph.setEdgeAttr(edge_id, "fontcolor", value);
        }
    }
}

fn applyMermaidStyleAttrs(graph: *Graph, node_id: NodeId, attrs_text: []const u8) !void {
    var attrs = std.mem.splitScalar(u8, attrs_text, ',');
    while (attrs.next()) |raw_attr| {
        const attr = std.mem.trim(u8, raw_attr, " \t\r\n;");
        if (attr.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, attr, ':') orelse continue;
        const key = std.mem.trim(u8, attr[0..colon], " \t\r\n");
        const value = std.mem.trim(u8, attr[colon + 1 ..], " \t\r\n");
        if (value.len == 0) continue;
        if (std.ascii.eqlIgnoreCase(key, "fill")) {
            try graph.setNodeAttr(node_id, "fillcolor", value);
            try graph.setNodeAttr(node_id, "style", "filled");
        } else if (std.ascii.eqlIgnoreCase(key, "stroke")) {
            try graph.setNodeAttr(node_id, "color", value);
        } else if (std.ascii.eqlIgnoreCase(key, "stroke-width")) {
            try graph.setNodeAttr(node_id, "penwidth", trimMermaidCssUnit(value));
        } else if (std.ascii.eqlIgnoreCase(key, "color")) {
            try graph.setNodeAttr(node_id, "fontcolor", value);
        } else if (std.ascii.eqlIgnoreCase(key, "stroke-dasharray")) {
            try graph.setNodeAttr(node_id, "style", "dashed");
        }
    }
}

fn trimMermaidCssUnit(value: []const u8) []const u8 {
    if (std.mem.endsWith(u8, value, "px")) return std.mem.trim(u8, value[0 .. value.len - 2], " \t\r\n");
    return value;
}

const MermaidSubgraphHeader = struct {
    name: []const u8,
    label: ?[]const u8 = null,
};

fn parseMermaidSubgraphHeader(line: []const u8) ?MermaidSubgraphHeader {
    if (!std.mem.startsWith(u8, line, "subgraph")) return null;
    var rest = std.mem.trim(u8, line["subgraph".len..], " \t\r\n");
    if (rest.len == 0) return .{ .name = "subgraph" };
    if (std.mem.indexOfScalar(u8, rest, '[')) |open| {
        if (std.mem.lastIndexOfScalar(u8, rest, ']')) |close| {
            if (close > open) {
                const name = std.mem.trim(u8, rest[0..open], " \t\r\n");
                const label = stripMermaidLabelQuotes(std.mem.trim(u8, rest[open + 1 .. close], " \t\r\n"));
                return .{ .name = if (name.len == 0) label else name, .label = label };
            }
        }
    }
    rest = stripMermaidLabelQuotes(rest);
    return .{ .name = rest, .label = rest };
}

fn addMermaidSubgraph(graph: *Graph, name: []const u8, label: []const u8, nodes: []const NodeId) !void {
    if (nodes.len == 0) return;
    const attrs = [_]Attr{.{ .name = "label", .value = label }};
    _ = try graph.addCluster(name, null, nodes, &attrs);
}

fn parseMermaidStatement(graph: *Graph, line: []const u8, subgraph_nodes: ?*std.ArrayList(NodeId), class_defs: []const MermaidClassDef) !void {
    var pos: usize = 0;
    var current = try parseMermaidNodeRef(graph, line, &pos, subgraph_nodes, class_defs) orelse return;
    while (findMermaidArrow(line, pos)) |arrow| {
        pos = arrow.start;
        const edge_label = arrow.label orelse mermaidEdgeLabelBeforeArrow(line, &pos);
        const arrow_text = line[arrow.start..arrow.end];
        pos = arrow.end;
        const label_after_arrow = mermaidEdgeLabelAfterArrow(line, &pos);
        const target = try parseMermaidNodeRef(graph, line, &pos, subgraph_nodes, class_defs) orelse break;
        const edge_id = try graph.edge(current, target, .{ .label = edge_label orelse label_after_arrow });
        try applyMermaidEdgeStyle(graph, edge_id, arrow_text);
        current = target;
    }
}

const MermaidArrow = struct {
    start: usize,
    end: usize,
    label: ?[]const u8 = null,
};

fn findMermaidArrow(line: []const u8, start: usize) ?MermaidArrow {
    var i = start;
    while (i < line.len) : (i += 1) {
        if (parseMermaidArrowAt(line, i)) |arrow| return arrow;
    }
    return null;
}

fn parseMermaidArrowAt(line: []const u8, start: usize) ?MermaidArrow {
    const rest = line[start..];
    const candidates = [_][]const u8{ "-->", "---", "-.->", "==>", "===", "--o", "--x" };
    for (candidates) |candidate| {
        if (std.mem.startsWith(u8, rest, candidate)) return .{ .start = start, .end = start + candidate.len };
    }

    if (std.mem.startsWith(u8, rest, "--")) {
        if (parseMermaidDelimitedArrowLabel(line, start, "--", &.{ "-->", "---", "--o", "--x" })) |arrow| return arrow;
    } else if (std.mem.startsWith(u8, rest, "==")) {
        if (parseMermaidDelimitedArrowLabel(line, start, "==", &.{ "==>", "===" })) |arrow| return arrow;
    } else if (std.mem.startsWith(u8, rest, "-.")) {
        if (parseMermaidDelimitedArrowLabel(line, start, "-.", &.{ ".->", ".-" })) |arrow| return arrow;
    }
    return null;
}

fn parseMermaidDelimitedArrowLabel(line: []const u8, start: usize, prefix: []const u8, terminators: []const []const u8) ?MermaidArrow {
    const label_start = start + prefix.len;
    if (label_start >= line.len) return null;
    if (line[label_start] == '|') {
        const close = std.mem.indexOfScalarPos(u8, line, label_start + 1, '|') orelse return null;
        const suffix_start = close + 1;
        for (terminators) |terminator| {
            if (std.mem.startsWith(u8, line[suffix_start..], terminator)) {
                const label = std.mem.trim(u8, line[label_start + 1 .. close], " \t\r\n");
                return .{
                    .start = start,
                    .end = suffix_start + terminator.len,
                    .label = if (label.len == 0) null else stripMermaidLabelQuotes(label),
                };
            }
        }
        return null;
    }
    if (findMermaidArrowLabelTerminator(line, label_start, terminators)) |term| {
        const label = std.mem.trim(u8, line[label_start..term.start], " \t\r\n");
        if (label.len == 0) return null;
        return .{
            .start = start,
            .end = term.end,
            .label = stripMermaidLabelQuotes(label),
        };
    }
    return null;
}

const MermaidArrowTerminator = struct {
    start: usize,
    end: usize,
};

fn findMermaidArrowLabelTerminator(line: []const u8, start: usize, terminators: []const []const u8) ?MermaidArrowTerminator {
    var quote: ?u8 = null;
    var i = start;
    while (i < line.len) : (i += 1) {
        const c = line[i];
        if (quote) |q| {
            if (c == '\\' and i + 1 < line.len) {
                i += 1;
            } else if (c == q) {
                quote = null;
            }
            continue;
        }
        if (c == '"' or c == '\'') {
            quote = c;
            continue;
        }
        for (terminators) |terminator| {
            if (std.mem.startsWith(u8, line[i..], terminator)) {
                return .{ .start = i, .end = i + terminator.len };
            }
        }
    }
    return null;
}

fn startsMermaidEdgeOperator(line: []const u8, pos: usize) bool {
    if (pos >= line.len) return false;
    const rest = line[pos..];
    return std.mem.startsWith(u8, rest, "--") or
        std.mem.startsWith(u8, rest, "==") or
        std.mem.startsWith(u8, rest, "-.");
}

fn mermaidEdgeLabelBeforeArrow(line: []const u8, arrow_start: *usize) ?[]const u8 {
    var start = arrow_start.*;
    while (start > 0 and std.ascii.isWhitespace(line[start - 1])) : (start -= 1) {}
    if (start == 0 or line[start - 1] != '|') return null;
    const close = start - 1;
    var open = close;
    while (open > 0) : (open -= 1) {
        if (line[open - 1] == '|') {
            const label = std.mem.trim(u8, line[open..close], " \t\r\n");
            arrow_start.* = open - 1;
            return if (label.len == 0) null else stripMermaidLabelQuotes(label);
        }
    }
    return null;
}

fn mermaidEdgeLabelAfterArrow(line: []const u8, pos: *usize) ?[]const u8 {
    while (pos.* < line.len and std.ascii.isWhitespace(line[pos.*])) : (pos.* += 1) {}
    if (pos.* >= line.len or line[pos.*] != '|') return null;
    const start = pos.* + 1;
    var end = start;
    while (end < line.len and line[end] != '|') : (end += 1) {}
    if (end >= line.len) return null;
    pos.* = end + 1;
    const label = std.mem.trim(u8, line[start..end], " \t\r\n");
    return if (label.len == 0) null else stripMermaidLabelQuotes(label);
}

fn parseMermaidNodeRef(graph: *Graph, line: []const u8, pos: *usize, subgraph_nodes: ?*std.ArrayList(NodeId), class_defs: []const MermaidClassDef) !?NodeId {
    while (pos.* < line.len and std.ascii.isWhitespace(line[pos.*])) : (pos.* += 1) {}
    if (pos.* >= line.len) return null;
    const id_start = pos.*;
    while (pos.* < line.len and isMermaidIdChar(line[pos.*]) and (pos.* == id_start or !startsMermaidEdgeOperator(line, pos.*))) : (pos.* += 1) {}
    if (pos.* == id_start) return null;
    const id_text = std.mem.trim(u8, line[id_start..pos.*], " \t\r\n");
    const node_id = try graph.node(id_text);
    if (subgraph_nodes) |nodes| try appendUniqueMermaidNode(graph.allocator, nodes, node_id);
    try parseMermaidNodeSuffix(graph, node_id, line, pos);
    try parseMermaidInlineClasses(graph, node_id, line, pos, class_defs);
    return node_id;
}

fn appendUniqueMermaidNode(allocator: std.mem.Allocator, nodes: *std.ArrayList(NodeId), node_id: NodeId) !void {
    if (containsNode(nodes.items, node_id)) return;
    try nodes.append(allocator, node_id);
}

fn parseMermaidInlineClasses(graph: *Graph, node_id: NodeId, line: []const u8, pos: *usize, class_defs: []const MermaidClassDef) !void {
    if (pos.* + 3 > line.len or !std.mem.eql(u8, line[pos.* .. pos.* + 3], ":::")) return;
    pos.* += 3;
    const start = pos.*;
    while (pos.* < line.len and (isMermaidIdChar(line[pos.*]) or line[pos.*] == ',') and (pos.* == start or !startsMermaidEdgeOperator(line, pos.*))) : (pos.* += 1) {}
    const classes_text = line[start..pos.*];
    var classes = std.mem.splitScalar(u8, classes_text, ',');
    while (classes.next()) |raw_class| {
        const class_name = std.mem.trim(u8, raw_class, " \t\r\n");
        const attrs = mermaidClassAttrs(class_defs, class_name) orelse continue;
        try applyMermaidStyleAttrs(graph, node_id, attrs);
    }
}

fn isMermaidIdChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '-' or c == '.' or c >= 0x80;
}

fn parseMermaidNodeSuffix(graph: *Graph, node_id: NodeId, line: []const u8, pos: *usize) !void {
    if (pos.* >= line.len) return;
    const c = line[pos.*];
    if (c == '[') {
        if (findMatchingMermaidClose(line, pos.* + 1, ']')) |end| {
            try graph.setNodeAttr(node_id, "label", stripMermaidLabelQuotes(std.mem.trim(u8, line[pos.* + 1 .. end], " \t\r\n")));
            try graph.setNodeShape(node_id, .box);
            pos.* = end + 1;
        }
    } else if (c == '(') {
        const double = pos.* + 1 < line.len and line[pos.* + 1] == '(';
        const content_start = pos.* + if (double) @as(usize, 2) else @as(usize, 1);
        if (findMatchingMermaidClose(line, content_start, ')')) |end| {
            var content_end = end;
            if (double and end + 1 < line.len and line[end + 1] == ')') {
                content_end = end;
                pos.* = end + 2;
                try graph.setNodeShape(node_id, .circle);
            } else {
                pos.* = end + 1;
                try graph.setNodeShape(node_id, .box);
                try graph.setNodeAttr(node_id, "style", "rounded");
            }
            try graph.setNodeAttr(node_id, "label", stripMermaidLabelQuotes(std.mem.trim(u8, line[content_start..content_end], " \t\r\n")));
        }
    } else if (c == '{') {
        if (findMatchingMermaidClose(line, pos.* + 1, '}')) |end| {
            try graph.setNodeAttr(node_id, "label", stripMermaidLabelQuotes(std.mem.trim(u8, line[pos.* + 1 .. end], " \t\r\n")));
            try graph.setNodeShape(node_id, .diamond);
            pos.* = end + 1;
        }
    }
}

fn findMatchingMermaidClose(line: []const u8, start: usize, close: u8) ?usize {
    var i = start;
    while (i < line.len) : (i += 1) {
        if (line[i] == close) return i;
    }
    return null;
}

fn stripMermaidLabelQuotes(label: []const u8) []const u8 {
    if (label.len >= 2 and ((label[0] == '"' and label[label.len - 1] == '"') or (label[0] == '\'' and label[label.len - 1] == '\''))) {
        return label[1 .. label.len - 1];
    }
    if (label.len >= 2 and label[0] == '[' and label[label.len - 1] == ']') {
        return label[1 .. label.len - 1];
    }
    return label;
}

fn applyMermaidEdgeStyle(graph: *Graph, edge_id: EdgeId, arrow: []const u8) !void {
    if (std.mem.indexOf(u8, arrow, ".")) |_| try graph.setEdgeAttr(edge_id, "style", "dotted");
    if (std.mem.indexOf(u8, arrow, "=")) |_| try graph.setEdgeAttr(edge_id, "style", "bold");
    if (!std.mem.endsWith(u8, arrow, ">")) try graph.setEdgeAttr(edge_id, "arrowhead", "none");
}

pub const Point = struct {
    x: f64,
    y: f64,
};

pub const NodeLayout = struct {
    center: Point,
    width: f64,
    height: f64,
};

pub const ClusterLayout = struct {
    id: usize,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

pub const EdgeWaypoint = struct {
    rank: usize,
    point: Point,
};

pub const EdgeWaypoints = struct {
    points: []EdgeWaypoint,
};

pub const Layout = struct {
    allocator: std.mem.Allocator,
    rankdir: RankDir,
    nodes: []NodeLayout,
    clusters: []ClusterLayout,
    edge_waypoints: []EdgeWaypoints,
    ranks: []usize,
    rank_depths: []f64,
    rank_heights: []f64,
    margin: f64,
    margin_x: f64,
    margin_y: f64,
    width: f64,
    height: f64,

    pub fn deinit(self: *Layout) void {
        for (self.edge_waypoints) |waypoints| self.allocator.free(waypoints.points);
        self.allocator.free(self.nodes);
        self.allocator.free(self.clusters);
        self.allocator.free(self.edge_waypoints);
        self.allocator.free(self.ranks);
        self.allocator.free(self.rank_depths);
        self.allocator.free(self.rank_heights);
        self.* = undefined;
    }
};

const LayoutAxes = struct {
    rankdir: RankDir,

    fn init(rankdir: RankDir) LayoutAxes {
        return .{ .rankdir = rankdir };
    }

    fn horizontalRanks(self: LayoutAxes) bool {
        return self.rankdir == .LR or self.rankdir == .RL;
    }

    fn reversedRanks(self: LayoutAxes) bool {
        return self.rankdir == .BT or self.rankdir == .RL;
    }

    fn orientSize(self: LayoutAxes, size: NodeSize) NodeSize {
        return switch (self.rankdir) {
            .TB, .BT => size,
            .LR, .RL => .{ .width = size.height, .height = size.width },
        };
    }

    fn orientPoint(self: LayoutAxes, along: f64, depth: f64, total_depth: f64, margin_x: f64, margin_y: f64) Point {
        return switch (self.rankdir) {
            .TB => .{ .x = margin_x + along, .y = margin_y + depth },
            .BT => .{ .x = margin_x + along, .y = total_depth + margin_y * 2.0 - (margin_y + depth) },
            .LR => .{ .x = margin_x + depth, .y = margin_y + along },
            .RL => .{ .x = total_depth + margin_x * 2.0 - (margin_x + depth), .y = margin_y + along },
        };
    }

    fn alongMargin(self: LayoutAxes, options: LayoutOptions) f64 {
        return if (self.horizontalRanks()) options.margin_y else options.margin;
    }

    fn depthMargin(self: LayoutAxes, options: LayoutOptions) f64 {
        return if (self.horizontalRanks()) options.margin else options.margin_y;
    }

    fn layoutWidth(self: LayoutAxes, base_along: f64, base_depth: f64) f64 {
        return if (self.horizontalRanks()) base_depth else base_along;
    }

    fn layoutHeight(self: LayoutAxes, base_along: f64, base_depth: f64) f64 {
        return if (self.horizontalRanks()) base_along else base_depth;
    }

    fn pointAlong(self: LayoutAxes, point: Point) f64 {
        return switch (self.rankdir) {
            .TB, .BT => point.x,
            .LR, .RL => point.y,
        };
    }

    fn orientWaypoint(self: LayoutAxes, along_screen: f64, depth: f64, layout: *const Layout) Point {
        return switch (self.rankdir) {
            .TB => .{ .x = along_screen, .y = layout.margin_y + depth },
            .BT => .{ .x = along_screen, .y = layout.height - (layout.margin_y + depth) },
            .LR => .{ .x = layout.margin_x + depth, .y = along_screen },
            .RL => .{ .x = layout.width - (layout.margin_x + depth), .y = along_screen },
        };
    }

    fn offsetPoint(self: LayoutAxes, point: Point, offset: f64) Point {
        return switch (self.rankdir) {
            .TB, .BT => .{ .x = point.x + offset, .y = point.y },
            .LR, .RL => .{ .x = point.x, .y = point.y + offset },
        };
    }

    fn rankAxisDelta(self: LayoutAxes, dx: f64, dy: f64) f64 {
        return if (self.horizontalRanks()) @abs(dx) else @abs(dy);
    }

    fn nodeAlongHalfSize(self: LayoutAxes, node: NodeLayout) f64 {
        return switch (self.rankdir) {
            .TB, .BT => node.width / 2.0,
            .LR, .RL => node.height / 2.0,
        };
    }
};

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
    crossing_passes: usize = 8,
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

pub const LayoutAlgorithm = enum {
    auto,
    sugiyama,
    fruchterman_reingold,

    pub fn fromString(value: []const u8) ?LayoutAlgorithm {
        if (std.ascii.eqlIgnoreCase(value, "auto")) return .auto;
        if (std.ascii.eqlIgnoreCase(value, "dot") or
            std.ascii.eqlIgnoreCase(value, "sugiyama") or
            std.ascii.eqlIgnoreCase(value, "layered"))
        {
            return .sugiyama;
        }
        if (std.ascii.eqlIgnoreCase(value, "fr") or
            std.ascii.eqlIgnoreCase(value, "force") or
            std.ascii.eqlIgnoreCase(value, "fdp") or
            std.ascii.eqlIgnoreCase(value, "neato") or
            std.ascii.eqlIgnoreCase(value, "sfdp") or
            std.ascii.eqlIgnoreCase(value, "fruchterman-reingold") or
            std.ascii.eqlIgnoreCase(value, "fruchterman_reingold"))
        {
            return .fruchterman_reingold;
        }
        return null;
    }
};

pub const LayoutConfig = struct {
    algorithm: LayoutAlgorithm = .auto,
    layered: LayoutOptions = .{},
    force: ForceLayoutOptions = .{},
};

const defaultInterClusterGap: f64 = 39.0;
const defaultClusterAlongExtentBudget: f64 = 224.0;
const defaultClusterAlongShift: f64 = 4.0;

pub fn layoutGraph(allocator: std.mem.Allocator, graph: *const Graph, config: LayoutConfig) !Layout {
    return switch (resolvedLayoutAlgorithm(graph, config.algorithm)) {
        .auto => unreachable,
        .sugiyama => layoutLayered(allocator, graph, config.layered),
        .fruchterman_reingold => layoutFruchtermanReingold(allocator, graph, config.force),
    };
}

fn resolvedLayoutAlgorithm(graph: *const Graph, requested: LayoutAlgorithm) LayoutAlgorithm {
    if (requested != .auto) return requested;
    if (attrValue(graph.attrs.items, "layout")) |value| {
        if (LayoutAlgorithm.fromString(value)) |algorithm| {
            if (algorithm != .auto) return algorithm;
        }
    }
    return .sugiyama;
}

fn layoutOptionsWithGraphAttrs(options: LayoutOptions, graph: *const Graph) LayoutOptions {
    var result = options;
    if (attrValue(graph.attrs.items, "ranksep")) |value| {
        result.rank_gap = parseGraphSpacing(value, result.rank_gap);
        result.ranksep_equally = spacingHasWord(value, "equally");
    }
    if (attrValue(graph.attrs.items, "nodesep")) |value| {
        result.node_gap = parseGraphSpacing(value, result.node_gap);
    }
    if (attrValue(graph.attrs.items, "label") != null) {
        const font_size = parsePositiveAttrFloat(graph.attrs.items, "fontsize", 14.0);
        result.margin_y = @max(result.margin_y, font_size + 12.0);
    }
    return result;
}

fn spacingHasWord(value: []const u8, word: []const u8) bool {
    var parts = std.mem.tokenizeAny(u8, value, " \t,");
    while (parts.next()) |part| {
        if (std.ascii.eqlIgnoreCase(part, word)) return true;
    }
    return false;
}

fn parseGraphSpacing(value: []const u8, fallback: f64) f64 {
    var parts = std.mem.tokenizeAny(u8, value, " \t,");
    const first = parts.next() orelse return fallback;
    const inches = std.fmt.parseFloat(f64, first) catch return fallback;
    if (inches <= 0) return fallback;
    // Graphviz ranksep/nodesep are in inches. Use a conservative 72 px/in
    // scale and keep the existing defaults as a lower bound for unset attrs.
    return @max(12.0, inches * 72.0);
}

fn clusterSpacingAlongBudget(axes: LayoutAxes, options: LayoutOptions) f64 {
    return @max(0.0, defaultClusterAlongExtentBudget - axes.alongMargin(options) * 2.0);
}

fn freeEdgeWaypoints(allocator: std.mem.Allocator, edge_waypoints: []EdgeWaypoints) void {
    for (edge_waypoints) |waypoints| allocator.free(waypoints.points);
}

pub fn layoutLayered(allocator: std.mem.Allocator, graph: *const Graph, options: LayoutOptions) !Layout {
    const effective_options = layoutOptionsWithGraphAttrs(options, graph);
    const axes = LayoutAxes.init(graph.rankdir);
    const n = graph.nodes.items.len;
    const nodes = try allocator.alloc(NodeLayout, n);
    errdefer allocator.free(nodes);
    const cluster_layouts = try allocator.alloc(ClusterLayout, graph.clusters.items.len);
    errdefer allocator.free(cluster_layouts);
    const edge_waypoints = try allocator.alloc(EdgeWaypoints, graph.edges.items.len);
    errdefer allocator.free(edge_waypoints);
    for (edge_waypoints) |*waypoints| waypoints.* = .{ .points = &.{} };
    errdefer freeEdgeWaypoints(allocator, edge_waypoints);
    const layout_ranks = try allocator.alloc(usize, n);
    errdefer allocator.free(layout_ranks);

    if (n == 0) {
        const empty_rank_depths = try allocator.alloc(f64, 0);
        errdefer allocator.free(empty_rank_depths);
        const empty_rank_heights = try allocator.alloc(f64, 0);
        errdefer allocator.free(empty_rank_heights);
        return .{
            .allocator = allocator,
            .rankdir = axes.rankdir,
            .nodes = nodes,
            .clusters = cluster_layouts,
            .edge_waypoints = edge_waypoints,
            .ranks = layout_ranks,
            .rank_depths = empty_rank_depths,
            .rank_heights = empty_rank_heights,
            .margin = effective_options.margin,
            .margin_x = effective_options.margin,
            .margin_y = effective_options.margin_y,
            .width = effective_options.margin * 2.0,
            .height = effective_options.margin_y * 2.0,
        };
    }

    const ranks = try allocator.alloc(usize, n);
    defer allocator.free(ranks);
    @memset(ranks, 0);

    var indegree = try allocator.alloc(usize, n);
    defer allocator.free(indegree);
    @memset(indegree, 0);
    var acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, false);

    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        if (edge_item.to < n) indegree[edge_item.to] += 1;
    }

    var queue = std.ArrayList(NodeId).empty;
    defer queue.deinit(allocator);
    for (indegree, 0..) |degree, id| if (degree == 0) try queue.append(allocator, id);

    var head: usize = 0;
    while (head < queue.items.len) : (head += 1) {
        const u = queue.items[head];
        for (graph.edges.items) |edge_item| {
            if (!edge_item.constraint) continue;
            if (edge_item.from != u) continue;
            const min_len = @max(edge_item.min_len, 1);
            if (ranks[edge_item.to] < ranks[u] + min_len) ranks[edge_item.to] = ranks[u] + min_len;
            acyclic_edge[edge_item.id] = true;
            if (indegree[edge_item.to] > 0) {
                indegree[edge_item.to] -= 1;
                if (indegree[edge_item.to] == 0) try queue.append(allocator, edge_item.to);
            }
        }
    }

    assignRanksForCyclicComponents(graph, ranks, acyclic_edge);
    applyRankConstraints(graph, ranks);
    tightenRanksTowardSinks(graph, ranks, acyclic_edge);
    improveRanksByLocalSearch(graph, ranks, acyclic_edge, 2);
    _ = try improveRanksByNetworkSimplex(allocator, graph, ranks, acyclic_edge, n * 2);
    applyRankConstraints(graph, ranks);

    var max_rank: usize = 0;
    for (ranks) |rank| max_rank = @max(max_rank, rank);

    var levels = try allocator.alloc(std.ArrayList(NodeId), max_rank + 1);
    defer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    defer for (levels) |*level| level.deinit(allocator);

    for (ranks, 0..) |rank, id| try levels[rank].append(allocator, id);
    var virtual_levels = try buildVirtualLevels(allocator, graph, ranks);
    defer virtual_levels.deinit();
    try reduceVirtualLevelCrossings(allocator, graph, &virtual_levels, ranks, effective_options.crossing_passes);
    replaceLevelsFromVirtual(allocator, levels, &virtual_levels) catch try reduceLayerCrossings(allocator, graph, levels, ranks, effective_options.crossing_passes);
    refineAdjacentExchanges(graph, levels, ranks, 2);
    applyOrderingHints(graph, levels, ranks);
    enforceClusterContiguity(graph, levels);
    alignGroupedNodes(graph, levels);
    syncVirtualRealOrder(&virtual_levels, levels);

    const sizes = try allocator.alloc(NodeSize, n);
    defer allocator.free(sizes);
    for (graph.nodes.items, 0..) |node_item, id| sizes[id] = measureNode(node_item, effective_options);

    const axis_sizes = try allocator.alloc(NodeSize, n);
    defer allocator.free(axis_sizes);
    for (sizes, 0..) |size, id| axis_sizes[id] = axes.orientSize(size);
    const centers = try allocator.alloc(f64, n);
    defer allocator.free(centers);
    @memset(centers, 0);

    var initial_virtual_positions = try computeVirtualPositions(allocator, &virtual_levels, graph, axis_sizes, effective_options.node_gap, null);
    defer initial_virtual_positions.deinit();
    applyVirtualRealPositions(&virtual_levels, &initial_virtual_positions, centers);

    refineLayerCoordinates(graph, levels, ranks, axis_sizes, centers, effective_options);
    refineLongEdgeDummyCoordinates(graph, levels, ranks, centers, axis_sizes, effective_options.node_gap);
    straightenSimpleAdjacentEdges(graph, levels, ranks, centers, axis_sizes, effective_options.node_gap, 2);
    alignGroupedCenters(graph, levels, centers, axis_sizes, effective_options.node_gap);
    normalizeCenters(centers, axis_sizes);
    var virtual_positions = try computeVirtualPositions(allocator, &virtual_levels, graph, axis_sizes, effective_options.node_gap, centers);
    defer virtual_positions.deinit();
    applyVirtualRealPositions(&virtual_levels, &virtual_positions, centers);
    straightenSimpleAdjacentEdges(graph, levels, ranks, centers, axis_sizes, effective_options.node_gap, 1);
    alignGroupedCenters(graph, levels, centers, axis_sizes, effective_options.node_gap);
    normalizeCenters(centers, axis_sizes);
    const cluster_along_budget = clusterSpacingAlongBudget(axes, effective_options);
    applyInterClusterSpacingWithBudget(graph, levels, centers, axis_sizes, defaultInterClusterGap, cluster_along_budget);
    var final_virtual_positions = try computeVirtualPositions(allocator, &virtual_levels, graph, axis_sizes, effective_options.node_gap, centers);
    defer final_virtual_positions.deinit();
    applyVirtualRealPositionsExceptGroups(graph, &virtual_levels, &final_virtual_positions, centers);
    if (!graphHasExplicitEdgeWeight(graph)) {
        alignLevelsToNeighborSpansIfHelpful(graph, levels, ranks, centers, axis_sizes, effective_options.node_gap);
    }
    applySymmetricCompactionIfHelpful(graph, levels, ranks, centers, axis_sizes, effective_options.node_gap);
    normalizeCenters(centers, axis_sizes);
    applyBackEdgeChannelCenterConstraints(graph, ranks, centers, axis_sizes, cluster_along_budget);
    shiftCentersRightWithinBudget(centers, axis_sizes, defaultClusterAlongShift, cluster_along_budget);
    applyInterClusterSpacingWithBudget(graph, levels, centers, axis_sizes, defaultInterClusterGap, cluster_along_budget);
    if (!graphHasExplicitEdgeWeight(graph)) {
        alignBoundarySingletonsToIncidentSpan(graph, levels, ranks, centers, axis_sizes);
        applyInterClusterSpacingWithBudget(graph, levels, centers, axis_sizes, defaultInterClusterGap, cluster_along_budget);
    }
    applyCrossClusterDiagonalNudges(graph, ranks, centers, axis_sizes, cluster_along_budget);

    var total_along: f64 = 0;
    for (centers, 0..) |center, id| total_along = @max(total_along, center + axis_sizes[id].width / 2.0);

    var rank_heights = try allocator.alloc(f64, levels.len);
    defer allocator.free(rank_heights);
    @memset(rank_heights, effective_options.node_height);
    for (levels, 0..) |level, rank| {
        for (level.items) |id| rank_heights[rank] = @max(rank_heights[rank], axis_sizes[id].height);
    }

    var rank_depths = try allocator.alloc(f64, levels.len);
    errdefer allocator.free(rank_depths);
    const layout_rank_heights = try allocator.dupe(f64, rank_heights);
    errdefer allocator.free(layout_rank_heights);
    var total_depth: f64 = 0;
    if (effective_options.ranksep_equally) {
        var max_rank_height: f64 = 0;
        for (rank_heights) |rank_height| max_rank_height = @max(max_rank_height, rank_height);
        const rank_step = max_rank_height + effective_options.rank_gap;
        for (rank_heights, 0..) |rank_height, rank| {
            const center_depth = @as(f64, @floatFromInt(rank)) * rank_step + max_rank_height / 2.0;
            rank_depths[rank] = center_depth - rank_height / 2.0;
        }
        total_depth = if (rank_heights.len == 0) 0 else (@as(f64, @floatFromInt(rank_heights.len - 1)) * rank_step + max_rank_height);
    } else {
        for (rank_heights, 0..) |rank_height, rank| {
            rank_depths[rank] = total_depth;
            total_depth += rank_height;
            if (rank + 1 < rank_heights.len) total_depth += effective_options.rank_gap;
        }
    }

    for (graph.nodes.items, 0..) |_, id| {
        const rank = ranks[id];
        const depth = rank_depths[rank] + rank_heights[rank] / 2.0;
        const center = axes.orientPoint(centers[id], depth, total_depth, effective_options.margin, effective_options.margin_y);
        nodes[id] = .{ .center = center, .width = sizes[id].width, .height = sizes[id].height };
    }
    @memcpy(layout_ranks, ranks);
    computeClusterLayouts(graph, axes, nodes, cluster_layouts);
    try computeEdgeWaypoints(allocator, graph, axes, nodes, ranks, rank_depths, layout_rank_heights, total_depth, effective_options.margin, effective_options.margin_y, edge_waypoints, &virtual_levels, &final_virtual_positions);
    total_along = @max(total_along, clusterLayoutsAlongExtent(axes, cluster_layouts, effective_options));

    const along_margin = axes.alongMargin(effective_options);
    const depth_margin = axes.depthMargin(effective_options);
    const base_along = total_along + along_margin * 2.0;
    const base_depth = total_depth + depth_margin * 2.0;
    return .{
        .allocator = allocator,
        .rankdir = axes.rankdir,
        .nodes = nodes,
        .clusters = cluster_layouts,
        .edge_waypoints = edge_waypoints,
        .ranks = layout_ranks,
        .rank_depths = rank_depths,
        .rank_heights = layout_rank_heights,
        .margin = effective_options.margin,
        .margin_x = effective_options.margin,
        .margin_y = effective_options.margin_y,
        .width = axes.layoutWidth(base_along, base_depth),
        .height = axes.layoutHeight(base_along, base_depth),
    };
}

pub fn layoutFruchtermanReingold(allocator: std.mem.Allocator, graph: *const Graph, options: ForceLayoutOptions) !Layout {
    const n = graph.nodes.items.len;
    const nodes = try allocator.alloc(NodeLayout, n);
    errdefer allocator.free(nodes);
    const cluster_layouts = try allocator.alloc(ClusterLayout, graph.clusters.items.len);
    errdefer allocator.free(cluster_layouts);
    const edge_waypoints = try allocator.alloc(EdgeWaypoints, graph.edges.items.len);
    errdefer allocator.free(edge_waypoints);
    for (edge_waypoints) |*waypoints| waypoints.* = .{ .points = &.{} };
    errdefer freeEdgeWaypoints(allocator, edge_waypoints);
    const ranks = try allocator.alloc(usize, n);
    errdefer allocator.free(ranks);
    @memset(ranks, 0);
    const rank_depths = try allocator.alloc(f64, if (n == 0) 0 else 1);
    errdefer allocator.free(rank_depths);
    const rank_heights = try allocator.alloc(f64, if (n == 0) 0 else 1);
    errdefer allocator.free(rank_heights);
    if (n > 0) {
        rank_depths[0] = 0;
        rank_heights[0] = 0;
    }

    if (n == 0) {
        return .{
            .allocator = allocator,
            .rankdir = graph.rankdir,
            .nodes = nodes,
            .clusters = cluster_layouts,
            .edge_waypoints = edge_waypoints,
            .ranks = ranks,
            .rank_depths = rank_depths,
            .rank_heights = rank_heights,
            .margin = options.margin,
            .margin_x = options.margin,
            .margin_y = options.margin,
            .width = options.width,
            .height = options.height,
        };
    }

    const sizes = try allocator.alloc(NodeSize, n);
    defer allocator.free(sizes);
    const default_layout_options = LayoutOptions{};
    for (graph.nodes.items, 0..) |node_item, id| sizes[id] = measureNode(node_item, default_layout_options);

    const positions = try allocator.alloc(Point, n);
    defer allocator.free(positions);
    var disp = try allocator.alloc(Point, n);
    defer allocator.free(disp);

    const cx = options.width / 2.0;
    const cy = options.height / 2.0;
    const radius = @max(1.0, @min(options.width, options.height) * 0.35);
    for (positions, 0..) |*pos, id| {
        const angle = 2.0 * std.math.pi * @as(f64, @floatFromInt(id)) / @as(f64, @floatFromInt(@max(n, 1)));
        pos.* = .{
            .x = cx + std.math.cos(angle) * radius,
            .y = cy + std.math.sin(angle) * radius,
        };
    }

    const area = @max(1.0, (options.width - options.margin * 2.0) * (options.height - options.margin * 2.0) * options.area_scale);
    const k = std.math.sqrt(area / @as(f64, @floatFromInt(@max(n, 1))));
    var temperature = @min(options.width, options.height) / 8.0;
    var iter: usize = 0;
    while (iter < options.iterations) : (iter += 1) {
        @memset(disp, .{ .x = 0, .y = 0 });
        for (0..n) |v| {
            var u = v + 1;
            while (u < n) : (u += 1) {
                const delta = Point{ .x = positions[v].x - positions[u].x, .y = positions[v].y - positions[u].y };
                const distance = @max(0.01, std.math.hypot(delta.x, delta.y));
                const force = (k * k) / distance;
                const fx = (delta.x / distance) * force;
                const fy = (delta.y / distance) * force;
                disp[v].x += fx;
                disp[v].y += fy;
                disp[u].x -= fx;
                disp[u].y -= fy;
            }
        }
        for (graph.edges.items) |edge_item| {
            if (edge_item.from >= n or edge_item.to >= n or edge_item.from == edge_item.to) continue;
            const delta = Point{ .x = positions[edge_item.from].x - positions[edge_item.to].x, .y = positions[edge_item.from].y - positions[edge_item.to].y };
            const distance = @max(0.01, std.math.hypot(delta.x, delta.y));
            const force = (distance * distance) / k;
            const fx = (delta.x / distance) * force;
            const fy = (delta.y / distance) * force;
            disp[edge_item.from].x -= fx;
            disp[edge_item.from].y -= fy;
            disp[edge_item.to].x += fx;
            disp[edge_item.to].y += fy;
        }
        for (positions, 0..) |*pos, id| {
            const d = @max(0.01, std.math.hypot(disp[id].x, disp[id].y));
            pos.x += (disp[id].x / d) * @min(d, temperature);
            pos.y += (disp[id].y / d) * @min(d, temperature);
            pos.x = std.math.clamp(pos.x, options.margin + sizes[id].width / 2.0, options.width - options.margin - sizes[id].width / 2.0);
            pos.y = std.math.clamp(pos.y, options.margin + sizes[id].height / 2.0, options.height - options.margin - sizes[id].height / 2.0);
        }
        temperature *= 0.94;
    }

    for (nodes, 0..) |*node, id| {
        node.* = .{ .center = positions[id], .width = sizes[id].width, .height = sizes[id].height };
    }
    computeClusterLayouts(graph, LayoutAxes.init(graph.rankdir), nodes, cluster_layouts);
    return .{
        .allocator = allocator,
        .rankdir = graph.rankdir,
        .nodes = nodes,
        .clusters = cluster_layouts,
        .edge_waypoints = edge_waypoints,
        .ranks = ranks,
        .rank_depths = rank_depths,
        .rank_heights = rank_heights,
        .margin = options.margin,
        .margin_x = options.margin,
        .margin_y = options.margin,
        .width = options.width,
        .height = options.height,
    };
}

const NodeSize = struct {
    width: f64,
    height: f64,
};

const VirtualNode = union(enum) {
    real: NodeId,
    dummy: EdgeId,
};

const VirtualLevels = struct {
    allocator: std.mem.Allocator,
    levels: []std.ArrayList(VirtualNode),

    fn deinit(self: *VirtualLevels) void {
        for (self.levels) |*level| level.deinit(self.allocator);
        self.allocator.free(self.levels);
        self.* = undefined;
    }
};

const VirtualPositions = struct {
    allocator: std.mem.Allocator,
    positions: []std.ArrayList(f64),

    fn deinit(self: *VirtualPositions) void {
        for (self.positions) |*level| level.deinit(self.allocator);
        self.allocator.free(self.positions);
        self.* = undefined;
    }
};

fn virtualNodeKey(node: VirtualNode) usize {
    return switch (node) {
        .real => |id| id,
        .dummy => |edge_id| std.math.maxInt(usize) / 2 + edge_id,
    };
}

fn buildVirtualLevels(allocator: std.mem.Allocator, graph: *const Graph, ranks: []const usize) !VirtualLevels {
    var max_rank: usize = 0;
    for (ranks) |rank| max_rank = @max(max_rank, rank);
    const levels = try allocator.alloc(std.ArrayList(VirtualNode), max_rank + 1);
    errdefer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    errdefer for (levels) |*level| level.deinit(allocator);

    for (ranks, 0..) |rank, node_id| {
        try levels[rank].append(allocator, .{ .real = node_id });
    }

    for (graph.edges.items) |edge_item| {
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        const from_rank = ranks[edge_item.from];
        const to_rank = ranks[edge_item.to];
        if (from_rank + 1 >= to_rank) continue;
        var rank = from_rank + 1;
        while (rank < to_rank) : (rank += 1) {
            try levels[rank].append(allocator, .{ .dummy = edge_item.id });
        }
    }

    return .{ .allocator = allocator, .levels = levels };
}

fn reduceVirtualLevelCrossings(allocator: std.mem.Allocator, graph: *const Graph, virtual_levels: *VirtualLevels, ranks: []const usize, passes: usize) !void {
    if (virtual_levels.levels.len <= 1 or passes == 0) return;

    for (0..passes) |_| {
        var rank: usize = 1;
        while (rank < virtual_levels.levels.len) : (rank += 1) {
            try orderVirtualLevelByMedianGuarded(allocator, graph, virtual_levels, ranks, rank, true);
            try orderVirtualLevelBlocksByMedianGuarded(allocator, graph, virtual_levels, ranks, rank, true);
        }
        rank = virtual_levels.levels.len - 1;
        while (rank > 0) : (rank -= 1) {
            try orderVirtualLevelByMedianGuarded(allocator, graph, virtual_levels, ranks, rank - 1, false);
            try orderVirtualLevelBlocksByMedianGuarded(allocator, graph, virtual_levels, ranks, rank - 1, false);
        }
        refineVirtualAdjacentExchanges(graph, virtual_levels, ranks);
    }
}

const VirtualMedianOrder = struct {
    node: VirtualNode,
    median: f64,
    original: usize,
};

fn orderVirtualLevelByMedian(graph: *const Graph, virtual_levels: *VirtualLevels, ranks: []const usize, rank: usize, use_parents: bool) void {
    if (rank >= virtual_levels.levels.len) return;
    if (use_parents and rank == 0) return;
    if (!use_parents and rank + 1 >= virtual_levels.levels.len) return;
    const level = &virtual_levels.levels[rank];
    if (level.items.len <= 1) return;

    var orders_buf: [128]VirtualMedianOrder = undefined;
    if (level.items.len > orders_buf.len) return;
    const orders = orders_buf[0..level.items.len];

    for (level.items, 0..) |node, original| {
        orders[original] = .{
            .node = node,
            .median = virtualNodeNeighborMedian(graph, virtual_levels, ranks, node, rank, use_parents, original),
            .original = original,
        };
    }

    std.mem.sort(VirtualMedianOrder, orders, {}, lessThanVirtualMedianOrder);
    for (orders, 0..) |order, i| level.items[i] = order.node;
}

fn lessThanVirtualMedianOrder(_: void, a: VirtualMedianOrder, b: VirtualMedianOrder) bool {
    if (a.median == b.median) return a.original < b.original;
    return a.median < b.median;
}

fn orderVirtualLevelByMedianGuarded(allocator: std.mem.Allocator, graph: *const Graph, virtual_levels: *VirtualLevels, ranks: []const usize, rank: usize, use_parents: bool) !void {
    if (rank >= virtual_levels.levels.len) return;
    const level = &virtual_levels.levels[rank];
    if (level.items.len <= 1) return;
    const before = totalVirtualLayerCrossings(graph, virtual_levels, ranks);
    const backup = try allocator.dupe(VirtualNode, level.items);
    defer allocator.free(backup);
    orderVirtualLevelByMedian(graph, virtual_levels, ranks, rank, use_parents);
    const after = totalVirtualLayerCrossings(graph, virtual_levels, ranks);
    if (after > before) @memcpy(level.items, backup);
}

const VirtualBlockOrder = struct {
    key: usize,
    median_sum: f64,
    count: usize,
    first: usize,
};

fn orderVirtualLevelBlocksByMedian(graph: *const Graph, virtual_levels: *VirtualLevels, ranks: []const usize, rank: usize, use_parents: bool) void {
    if (rank >= virtual_levels.levels.len) return;
    if (use_parents and rank == 0) return;
    if (!use_parents and rank + 1 >= virtual_levels.levels.len) return;
    const level = &virtual_levels.levels[rank];
    if (level.items.len <= 1 or level.items.len > 128) return;

    var blocks: [128]VirtualBlockOrder = undefined;
    var node_medians: [128]f64 = undefined;
    var block_count: usize = 0;
    for (level.items, 0..) |node, index| {
        const key = virtualBlockKeyAtRank(graph, ranks, node, rank);
        const median = virtualNodeNeighborMedian(graph, virtual_levels, ranks, node, rank, use_parents, index);
        node_medians[index] = median;
        const block_index = virtualBlockIndex(blocks[0..block_count], key) orelse blk: {
            blocks[block_count] = .{ .key = key, .median_sum = 0, .count = 0, .first = index };
            block_count += 1;
            break :blk block_count - 1;
        };
        blocks[block_index].median_sum += median;
        blocks[block_index].count += 1;
    }
    if (block_count == 0) return;

    std.mem.sort(VirtualBlockOrder, blocks[0..block_count], {}, lessThanVirtualBlockOrder);

    var scratch: [128]VirtualNode = undefined;
    var out: usize = 0;
    for (blocks[0..block_count]) |block| {
        appendVirtualBlockSortedByMedian(level.items, node_medians[0..level.items.len], block.key, graph, ranks, rank, scratch[0..], &out);
    }
    @memcpy(level.items, scratch[0..level.items.len]);
}

fn appendVirtualBlockSortedByMedian(level: []const VirtualNode, medians: []const f64, block_key: usize, graph: *const Graph, ranks: []const usize, rank: usize, scratch: []VirtualNode, out: *usize) void {
    var remaining = true;
    var used: [128]bool = undefined;
    @memset(used[0..level.len], false);
    while (remaining) {
        remaining = false;
        var best: ?usize = null;
        for (level, 0..) |node, index| {
            if (used[index]) continue;
            if (virtualBlockKeyAtRank(graph, ranks, node, rank) != block_key) continue;
            remaining = true;
            if (best == null or medians[index] < medians[best.?] or (medians[index] == medians[best.?] and index < best.?)) {
                best = index;
            }
        }
        const next_index = best orelse break;
        used[next_index] = true;
        scratch[out.*] = level[next_index];
        out.* += 1;
    }
}

fn virtualBlockIndex(blocks: []const VirtualBlockOrder, key: usize) ?usize {
    for (blocks, 0..) |block, index| {
        if (block.key == key) return index;
    }
    return null;
}

fn lessThanVirtualBlockOrder(_: void, a: VirtualBlockOrder, b: VirtualBlockOrder) bool {
    const a_median = a.median_sum / @as(f64, @floatFromInt(a.count));
    const b_median = b.median_sum / @as(f64, @floatFromInt(b.count));
    if (a_median == b_median) return a.first < b.first;
    return a_median < b_median;
}

fn orderVirtualLevelBlocksByMedianGuarded(allocator: std.mem.Allocator, graph: *const Graph, virtual_levels: *VirtualLevels, ranks: []const usize, rank: usize, use_parents: bool) !void {
    if (rank >= virtual_levels.levels.len) return;
    const level = &virtual_levels.levels[rank];
    if (level.items.len <= 1) return;
    const before = totalVirtualLayerCrossings(graph, virtual_levels, ranks);
    const backup = try allocator.dupe(VirtualNode, level.items);
    defer allocator.free(backup);
    orderVirtualLevelBlocksByMedian(graph, virtual_levels, ranks, rank, use_parents);
    const after = totalVirtualLayerCrossings(graph, virtual_levels, ranks);
    if (after > before) @memcpy(level.items, backup);
}

fn virtualBlockKey(graph: *const Graph, node: VirtualNode) usize {
    return virtualBlockKeyAtRank(graph, &.{}, node, 0);
}

fn virtualBlockKeyAtRank(graph: *const Graph, ranks: []const usize, node: VirtualNode, rank: usize) usize {
    const root_base = graph.clusters.items.len + 1;
    return switch (node) {
        .real => |node_id| (clusterIndexContainingNode(graph, node_id) orelse (root_base + node_id)),
        .dummy => |edge_id| blk: {
            if (edge_id >= graph.edges.items.len) break :blk root_base + graph.nodes.items.len + edge_id;
            const edge_item = graph.edges.items[edge_id];
            const from_cluster = clusterIndexContainingNode(graph, edge_item.from);
            const to_cluster = clusterIndexContainingNode(graph, edge_item.to);
            if (from_cluster != null and to_cluster != null and from_cluster.? == to_cluster.?) break :blk from_cluster.?;
            if (ranks.len > 0) {
                if (crossClusterEndpointBlockKey(edge_item, ranks, rank, from_cluster, to_cluster)) |key| break :blk key;
            }
            break :blk root_base + graph.nodes.items.len + edge_id;
        },
    };
}

fn crossClusterEndpointBlockKey(edge_item: Edge, ranks: []const usize, rank: usize, from_cluster: ?usize, to_cluster: ?usize) ?usize {
    if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) return null;
    if (from_cluster == null and to_cluster == null and edge_item.ltail == null and edge_item.lhead == null) return null;
    const from_rank = ranks[edge_item.from];
    const to_rank = ranks[edge_item.to];
    if (from_rank + 1 >= to_rank) return null;
    if (rank <= from_rank or rank >= to_rank) return null;
    if (rank == from_rank + 1) return from_cluster;
    if (rank + 1 == to_rank) return to_cluster;
    return null;
}

fn virtualNodeNeighborMedian(graph: *const Graph, virtual_levels: *const VirtualLevels, ranks: []const usize, node: VirtualNode, rank: usize, use_parents: bool, fallback: usize) f64 {
    var weighted_sum: f64 = 0;
    var total_weight: f64 = 0;
    for (graph.edges.items) |edge_item| {
        const neighbor = virtualAdjacentNode(edge_item, node, ranks, rank, use_parents) orelse continue;
        const adjacent_rank = if (use_parents) rank - 1 else rank + 1;
        const pos = positionInVirtualLevel(virtual_levels.levels[adjacent_rank].items, neighbor) orelse continue;
        const weight = @max(edge_item.weight, 0.1);
        weighted_sum += @as(f64, @floatFromInt(pos)) * weight;
        total_weight += weight;
    }
    if (total_weight == 0) return @floatFromInt(fallback);
    return weighted_sum / total_weight;
}

fn clusterIndexContainingNode(graph: *const Graph, node_id: NodeId) ?usize {
    for (graph.clusters.items, 0..) |cluster, index| {
        if (containsNode(cluster.nodes, node_id)) return index;
    }
    return null;
}

fn positionInVirtualLevel(level: []const VirtualNode, needle: VirtualNode) ?usize {
    for (level, 0..) |node, index| {
        if (std.meta.eql(node, needle)) return index;
    }
    return null;
}

fn refineVirtualAdjacentExchanges(graph: *const Graph, virtual_levels: *VirtualLevels, ranks: []const usize) void {
    if (virtual_levels.levels.len < 2) return;
    for (0..2) |_| {
        var changed = false;
        for (0..virtual_levels.levels.len) |rank| {
            var level = &virtual_levels.levels[rank];
            if (level.items.len < 2 or level.items.len > 64) continue;
            var i: usize = 0;
            while (i + 1 < level.items.len) {
                if (virtualSwapCrossesClusterBlock(graph, ranks, rank, level.items[i], level.items[i + 1])) {
                    i += 1;
                    continue;
                }
                const pair_before = adjacentVirtualPairCrossings(graph, virtual_levels, ranks, rank, i, i + 1);
                const pair_after = adjacentVirtualPairCrossings(graph, virtual_levels, ranks, rank, i + 1, i);
                const before = virtualCrossingScoreAroundLevel(graph, virtual_levels, ranks, rank);
                std.mem.swap(VirtualNode, &level.items[i], &level.items[i + 1]);
                const after = virtualCrossingScoreAroundLevel(graph, virtual_levels, ranks, rank);
                if (after < before or (after == before and pair_after < pair_before)) {
                    changed = true;
                    if (i > 0) {
                        i -= 1;
                    } else {
                        i += 1;
                    }
                } else {
                    std.mem.swap(VirtualNode, &level.items[i], &level.items[i + 1]);
                    i += 1;
                }
            }
        }
        if (!changed) break;
    }
}

fn adjacentVirtualPairCrossings(graph: *const Graph, virtual_levels: *const VirtualLevels, ranks: []const usize, rank: usize, left_index: usize, right_index: usize) usize {
    if (rank >= virtual_levels.levels.len) return 0;
    const level = virtual_levels.levels[rank].items;
    if (left_index >= level.len or right_index >= level.len) return 0;
    const left = level[left_index];
    const right = level[right_index];
    var crossings: usize = 0;
    if (rank > 0) crossings += adjacentVirtualPairCrossingsWithFixedLayer(graph, virtual_levels.levels[rank - 1].items, ranks, rank, left, right, true);
    if (rank + 1 < virtual_levels.levels.len) crossings += adjacentVirtualPairCrossingsWithFixedLayer(graph, virtual_levels.levels[rank + 1].items, ranks, rank, left, right, false);
    return crossings;
}

fn adjacentVirtualPairCrossingsWithFixedLayer(graph: *const Graph, fixed_layer: []const VirtualNode, ranks: []const usize, rank: usize, left: VirtualNode, right: VirtualNode, use_parents: bool) usize {
    var crossings: usize = 0;
    for (fixed_layer, 0..) |left_neighbor, left_pos| {
        if (!virtualNodesAdjacentAcrossLayer(graph, ranks, left, rank, left_neighbor, use_parents)) continue;
        for (fixed_layer, 0..) |right_neighbor, right_pos| {
            if (!virtualNodesAdjacentAcrossLayer(graph, ranks, right, rank, right_neighbor, use_parents)) continue;
            if (left_pos > right_pos) crossings += 1;
        }
    }
    return crossings;
}

fn virtualNodesAdjacentAcrossLayer(graph: *const Graph, ranks: []const usize, node: VirtualNode, rank: usize, neighbor: VirtualNode, use_parents: bool) bool {
    for (graph.edges.items) |edge_item| {
        const adjacent = virtualAdjacentNode(edge_item, node, ranks, rank, use_parents) orelse continue;
        if (std.meta.eql(adjacent, neighbor)) return true;
    }
    return false;
}

fn virtualSwapCrossesClusterBlock(graph: *const Graph, ranks: []const usize, rank: usize, a: VirtualNode, b: VirtualNode) bool {
    const a_key = virtualBlockKeyAtRank(graph, ranks, a, rank);
    const b_key = virtualBlockKeyAtRank(graph, ranks, b, rank);
    if (a_key == b_key) return false;
    return isClusterVirtualBlockKey(graph, a_key) or isClusterVirtualBlockKey(graph, b_key);
}

fn isClusterVirtualBlockKey(graph: *const Graph, key: usize) bool {
    return key < graph.clusters.items.len;
}

fn virtualCrossingScoreAroundLevel(graph: *const Graph, virtual_levels: *const VirtualLevels, ranks: []const usize, rank: usize) usize {
    var score: usize = 0;
    if (rank > 0) score += countVirtualLayerCrossings(graph, virtual_levels, ranks, rank - 1);
    if (rank + 1 < virtual_levels.levels.len) score += countVirtualLayerCrossings(graph, virtual_levels, ranks, rank);
    return score;
}

fn totalVirtualLayerCrossings(graph: *const Graph, virtual_levels: *const VirtualLevels, ranks: []const usize) usize {
    var total: usize = 0;
    if (virtual_levels.levels.len < 2) return 0;
    for (0..virtual_levels.levels.len - 1) |rank| total += countVirtualLayerCrossings(graph, virtual_levels, ranks, rank);
    return total;
}

fn countVirtualLayerCrossings(graph: *const Graph, virtual_levels: *const VirtualLevels, ranks: []const usize, upper_rank: usize) usize {
    if (upper_rank + 1 >= virtual_levels.levels.len) return 0;
    var crossings: usize = 0;
    for (graph.edges.items, 0..) |a, ai| {
        const a_segment = virtualEdgeSegment(a, virtual_levels, ranks, upper_rank) orelse continue;
        for (graph.edges.items[ai + 1 ..]) |b| {
            const b_segment = virtualEdgeSegment(b, virtual_levels, ranks, upper_rank) orelse continue;
            if ((a_segment.upper < b_segment.upper and a_segment.lower > b_segment.lower) or
                (a_segment.upper > b_segment.upper and a_segment.lower < b_segment.lower))
            {
                crossings += 1;
            }
        }
    }
    return crossings;
}

fn virtualEdgeSegment(edge_item: Edge, virtual_levels: *const VirtualLevels, ranks: []const usize, upper_rank: usize) ?LayerSegment {
    if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) return null;
    const from_rank = ranks[edge_item.from];
    const to_rank = ranks[edge_item.to];
    if (from_rank >= to_rank) return null;
    if (upper_rank < from_rank or upper_rank + 1 > to_rank) return null;
    const upper_node: VirtualNode = if (upper_rank == from_rank) .{ .real = edge_item.from } else .{ .dummy = edge_item.id };
    const lower_node: VirtualNode = if (upper_rank + 1 == to_rank) .{ .real = edge_item.to } else .{ .dummy = edge_item.id };
    const upper_pos = positionInVirtualLevel(virtual_levels.levels[upper_rank].items, upper_node) orelse return null;
    const lower_pos = positionInVirtualLevel(virtual_levels.levels[upper_rank + 1].items, lower_node) orelse return null;
    return .{ .upper = @floatFromInt(upper_pos), .lower = @floatFromInt(lower_pos) };
}

fn virtualAdjacentNode(edge_item: Edge, node: VirtualNode, ranks: []const usize, rank: usize, use_parents: bool) ?VirtualNode {
    if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) return null;
    const from_rank = ranks[edge_item.from];
    const to_rank = ranks[edge_item.to];
    if (from_rank >= to_rank) return null;
    switch (node) {
        .real => |node_id| {
            if (use_parents) {
                if (node_id == edge_item.to and rank == to_rank) {
                    return if (from_rank + 1 == to_rank) .{ .real = edge_item.from } else .{ .dummy = edge_item.id };
                }
            } else {
                if (node_id == edge_item.from and rank == from_rank) {
                    return if (from_rank + 1 == to_rank) .{ .real = edge_item.to } else .{ .dummy = edge_item.id };
                }
            }
        },
        .dummy => |edge_id| {
            if (edge_id != edge_item.id) return null;
            if (rank <= from_rank or rank >= to_rank) return null;
            if (use_parents) {
                return if (rank == from_rank + 1) .{ .real = edge_item.from } else .{ .dummy = edge_id };
            }
            return if (rank + 1 == to_rank) .{ .real = edge_item.to } else .{ .dummy = edge_id };
        },
    }
    return null;
}

fn computeVirtualPositions(allocator: std.mem.Allocator, virtual_levels: *const VirtualLevels, graph: *const Graph, sizes: []const NodeSize, gap: f64, real_hints: ?[]const f64) !VirtualPositions {
    const positions = try allocator.alloc(std.ArrayList(f64), virtual_levels.levels.len);
    errdefer allocator.free(positions);
    for (positions) |*level| level.* = .empty;
    errdefer for (positions) |*level| level.deinit(allocator);

    if (real_hints) |hints| {
        try computeVirtualPositionsFromHints(allocator, virtual_levels, graph, sizes, gap, hints, positions);
    } else {
        try computeVirtualPositionsPacked(virtual_levels, graph, sizes, gap, positions, allocator);
    }
    return .{ .allocator = allocator, .positions = positions };
}

fn computeVirtualPositionsPacked(virtual_levels: *const VirtualLevels, graph: *const Graph, sizes: []const NodeSize, gap: f64, positions: []std.ArrayList(f64), allocator: std.mem.Allocator) !void {
    var max_width: f64 = 0;
    for (virtual_levels.levels, 0..) |level, rank| {
        var left: f64 = 0;
        for (level.items) |vnode| {
            const width = virtualNodeWidth(vnode, sizes, graph);
            try positions[rank].append(allocator, left + width / 2.0);
            left += width + gap;
        }
        if (level.items.len > 0) max_width = @max(max_width, left - gap);
    }
    for (virtual_levels.levels, 0..) |level, rank| {
        if (level.items.len == 0) continue;
        const level_width = virtualLevelWidth(level.items, sizes, graph, gap);
        const shift = (max_width - level_width) / 2.0;
        for (positions[rank].items) |*pos| pos.* += shift;
    }
}

fn computeVirtualPositionsFromHints(allocator: std.mem.Allocator, virtual_levels: *const VirtualLevels, graph: *const Graph, sizes: []const NodeSize, gap: f64, hints: []const f64, positions: []std.ArrayList(f64)) !void {
    for (virtual_levels.levels, 0..) |level, rank| {
        for (level.items) |vnode| {
            const pos = switch (vnode) {
                .real => |node_id| if (node_id < hints.len) hints[node_id] else 0,
                .dummy => |edge_id| virtualDummyHint(virtual_levels, graph, hints, edge_id, rank) orelse 0,
            };
            try positions[rank].append(allocator, pos);
        }
    }
    compactVirtualPositions(virtual_levels, graph, sizes, positions, gap);
}

fn compactVirtualPositions(virtual_levels: *const VirtualLevels, graph: *const Graph, sizes: []const NodeSize, positions: []std.ArrayList(f64), gap: f64) void {
    for (virtual_levels.levels, 0..) |level, rank| {
        if (rank >= positions.len or level.items.len == 0) continue;
        var prev_right: f64 = 0;
        for (level.items, 0..) |vnode, index| {
            if (index >= positions[rank].items.len) continue;
            const width = virtualNodeWidth(vnode, sizes, graph);
            const min_center = if (index == 0) width / 2.0 else prev_right + gap + width / 2.0;
            if (positions[rank].items[index] < min_center) positions[rank].items[index] = min_center;
            prev_right = positions[rank].items[index] + width / 2.0;
        }
    }
}

fn applyVirtualRealPositions(virtual_levels: *const VirtualLevels, virtual_positions: *const VirtualPositions, centers: []f64) void {
    for (virtual_levels.levels, 0..) |level, rank| {
        if (rank >= virtual_positions.positions.len) continue;
        for (level.items, 0..) |vnode, index| {
            if (index >= virtual_positions.positions[rank].items.len) continue;
            switch (vnode) {
                .real => |node_id| {
                    if (node_id < centers.len) centers[node_id] = virtual_positions.positions[rank].items[index];
                },
                .dummy => {},
            }
        }
    }
}

fn applyVirtualRealPositionsExceptGroups(graph: *const Graph, virtual_levels: *const VirtualLevels, virtual_positions: *const VirtualPositions, centers: []f64) void {
    for (virtual_levels.levels, 0..) |level, rank| {
        if (rank >= virtual_positions.positions.len) continue;
        for (level.items, 0..) |vnode, index| {
            if (index >= virtual_positions.positions[rank].items.len) continue;
            switch (vnode) {
                .real => |node_id| {
                    if (node_id < centers.len and node_id < graph.nodes.items.len and nodeGroupName(graph.nodes.items[node_id]) == null) {
                        centers[node_id] = virtual_positions.positions[rank].items[index];
                    }
                },
                .dummy => {},
            }
        }
    }
}

fn virtualDummyHint(virtual_levels: *const VirtualLevels, graph: *const Graph, hints: []const f64, edge_id: EdgeId, rank: usize) ?f64 {
    if (edge_id >= graph.edges.items.len) return null;
    const edge_item = graph.edges.items[edge_id];
    if (edge_item.from >= hints.len or edge_item.to >= hints.len) return null;
    const from_rank = virtualRealRank(virtual_levels, edge_item.from) orelse return null;
    const to_rank = virtualRealRank(virtual_levels, edge_item.to) orelse return null;
    if (from_rank + 1 >= to_rank or rank <= from_rank or rank >= to_rank) return null;
    const span = @as(f64, @floatFromInt(to_rank - from_rank));
    const t = @as(f64, @floatFromInt(rank - from_rank)) / span;
    return hints[edge_item.from] + (hints[edge_item.to] - hints[edge_item.from]) * t;
}

fn virtualRealRank(virtual_levels: *const VirtualLevels, node_id: NodeId) ?usize {
    for (virtual_levels.levels, 0..) |level, rank| {
        for (level.items) |vnode| {
            switch (vnode) {
                .real => |id| if (id == node_id) return rank,
                .dummy => {},
            }
        }
    }
    return null;
}

fn virtualNodeWidth(vnode: VirtualNode, sizes: []const NodeSize, graph: *const Graph) f64 {
    _ = graph;
    return switch (vnode) {
        .real => |node_id| if (node_id < sizes.len) sizes[node_id].width else 1.0,
        .dummy => 1.0,
    };
}

fn virtualLevelWidth(level: []const VirtualNode, sizes: []const NodeSize, graph: *const Graph, gap: f64) f64 {
    if (level.len == 0) return 0;
    var width: f64 = 0;
    for (level) |vnode| width += virtualNodeWidth(vnode, sizes, graph);
    width += gap * @as(f64, @floatFromInt(level.len - 1));
    return width;
}

fn virtualPositionsExtent(virtual_levels: *const VirtualLevels, virtual_positions: *const VirtualPositions, sizes: []const NodeSize, graph: *const Graph) f64 {
    var max_right: f64 = 0;
    for (virtual_levels.levels, 0..) |level, rank| {
        if (rank >= virtual_positions.positions.len) continue;
        for (level.items, 0..) |vnode, index| {
            if (index >= virtual_positions.positions[rank].items.len) continue;
            const width = virtualNodeWidth(vnode, sizes, graph);
            max_right = @max(max_right, virtual_positions.positions[rank].items[index] + width / 2.0);
        }
    }
    return max_right;
}

fn extractRealLevelsFromVirtual(allocator: std.mem.Allocator, virtual_levels: *const VirtualLevels) ![]std.ArrayList(NodeId) {
    const levels = try allocator.alloc(std.ArrayList(NodeId), virtual_levels.levels.len);
    errdefer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    errdefer for (levels) |*level| level.deinit(allocator);

    for (virtual_levels.levels, 0..) |virtual_level, rank| {
        for (virtual_level.items) |vnode| {
            switch (vnode) {
                .real => |node_id| try levels[rank].append(allocator, node_id),
                .dummy => {},
            }
        }
    }
    return levels;
}

fn replaceLevelsFromVirtual(allocator: std.mem.Allocator, levels: []std.ArrayList(NodeId), virtual_levels: *const VirtualLevels) !void {
    const real_levels = try extractRealLevelsFromVirtual(allocator, virtual_levels);
    defer allocator.free(real_levels);
    errdefer for (real_levels) |*level| level.deinit(allocator);
    if (real_levels.len != levels.len) {
        for (real_levels) |*level| level.deinit(allocator);
        return error.LevelCountMismatch;
    }
    for (levels, 0..) |*level, index| {
        level.deinit(allocator);
        level.* = real_levels[index];
    }
}

fn syncVirtualRealOrder(virtual_levels: *VirtualLevels, levels: []const std.ArrayList(NodeId)) void {
    for (levels, 0..) |real_level, rank| {
        if (rank >= virtual_levels.levels.len or real_level.items.len == 0) continue;
        var next_real: usize = 0;
        for (virtual_levels.levels[rank].items) |*vnode| {
            switch (vnode.*) {
                .real => {
                    if (next_real < real_level.items.len) {
                        vnode.* = .{ .real = real_level.items[next_real] };
                        next_real += 1;
                    }
                },
                .dummy => {},
            }
        }
    }
}

fn measureNode(node_item: Node, options: LayoutOptions) NodeSize {
    const font_size = parsePositiveAttrFloat(node_item.attrs.items, "fontsize", 14.0);
    const font_scale = font_size / 14.0;
    const line_count = displayLabelLineCount(node_item.label);
    const max_line_len = displayLabelMaxLineLen(node_item.label);
    const margin = nodeMargin(node_item.attrs.items, 0);
    const text_width = @as(f64, @floatFromInt(max_line_len)) * options.label_char_width * font_scale;
    const text_height = @as(f64, @floatFromInt(line_count)) * options.label_line_height * font_scale;
    var width = @max(options.node_width, text_width + options.node_padding_x * 2.0 + margin.x * 2.0);
    var height = @max(options.node_height, text_height + options.node_padding_y * 2.0 + margin.y * 2.0);
    switch (node_item.shape) {
        .point => {
            width = 12;
            height = 12;
        },
        .msquare => {
            const side = @max(@max(36.0, text_width + 8.0 + margin.x * 2.0), text_height + 8.0 + margin.y * 2.0);
            width = side;
            height = side;
        },
        .square => {
            const side = @max(width, height);
            width = side;
            height = side;
        },
        .mcircle => {
            const diameter = @max(@max(36.0, text_width + 8.0 + margin.x * 2.0), text_height + 8.0 + margin.y * 2.0);
            width = diameter;
            height = diameter;
        },
        .circle, .doublecircle => {
            const diameter = @max(width, height);
            width = diameter;
            height = diameter;
        },
        .mdiamond => {
            width = @max(36.0, text_width + options.node_padding_x * 2.75 + margin.x * 2.0);
            height = @max(36.0, text_height + options.node_padding_y * 2.2 + margin.y * 2.0);
        },
        .diamond => {
            width = @max(width, text_width + options.node_padding_x * 3.0);
            height = @max(height, text_height + options.node_padding_y * 2.6);
        },
        .triangle, .invtriangle => {
            width = @max(width, text_width + options.node_padding_x * 3.0);
            height = @max(height, text_height + options.node_padding_y * 2.4);
        },
        .polygon => {
            width = @max(width, text_width + options.node_padding_x * 3.0);
            if (customPolygonFromAttrs(node_item.attrs.items).regular) {
                const side = @max(width, height);
                width = side;
                height = side;
            }
        },
        .parallelogram, .trapezium, .invtrapezium, .house, .invhouse, .pentagon, .hexagon, .septagon, .octagon, .doubleoctagon, .tripleoctagon, .star, .note, .tab, .folder, .box3d, .component => {
            width = @max(width, text_width + options.node_padding_x * 3.0);
        },
        .egg => {
            width = @max(width, text_width + options.node_padding_x * 3.0);
            height = @max(height, text_height + options.node_padding_y * 2.2);
        },
        .cylinder => {
            width = @max(width, text_width + options.node_padding_x * 3.0);
            height = @max(height, text_height + options.node_padding_y * 3.0);
        },
        .plaintext => {
            width = @max(24, text_width + 8);
            height = @max(18, text_height + 6);
        },
        .record, .mrecord => {
            const metrics = recordMetrics(node_item.label);
            width = @max(options.node_width, @as(f64, @floatFromInt(metrics.max_field_len)) * options.label_char_width * font_scale + options.node_padding_x * 2.0);
            height = @max(options.node_height, @as(f64, @floatFromInt(metrics.field_count)) * options.label_line_height * font_scale + options.node_padding_y * 2.0);
        },
        else => {},
    }
    if (htmlTableMetrics(node_item.label)) |table| {
        const table_width = htmlTablePreferredWidth(table, options.label_char_width * font_scale);
        const table_height = htmlTablePreferredHeight(table, options.label_line_height * 1.6 * font_scale);
        if (node_item.shape == .plaintext and htmlTableHasExplicitSize(table)) {
            width = table_width;
            height = table_height;
        } else {
            width = @max(width, table_width);
            height = @max(height, table_height);
        }
    }
    applyNodeSizeAttrs(node_item, &width, &height);
    return .{ .width = width, .height = height };
}

fn applyNodeSizeAttrs(node_item: Node, width: *f64, height: *f64) void {
    const fixed = fixedsizeMode(node_item.attrs.items) == .true;
    if (attrValue(node_item.attrs.items, "width")) |value| {
        const attr_width = parseInchDimension(value) orelse width.*;
        width.* = if (fixed) attr_width else @max(width.*, attr_width);
    }
    if (attrValue(node_item.attrs.items, "height")) |value| {
        const attr_height = parseInchDimension(value) orelse height.*;
        height.* = if (fixed) attr_height else @max(height.*, attr_height);
    }
}

const FixedSizeMode = enum {
    false,
    true,
    shape,
};

fn fixedsizeMode(attrs: []const Attr) FixedSizeMode {
    const value = attrValue(attrs, "fixedsize") orelse return .false;
    if (std.ascii.eqlIgnoreCase(value, "shape")) return .shape;
    return if (parseBool(value) orelse false) .true else .false;
}

fn parseInchDimension(value: []const u8) ?f64 {
    const inches = std.fmt.parseFloat(f64, value) catch return null;
    if (inches <= 0) return null;
    return @max(12.0, inches * 72.0);
}

const NodeMargin = struct {
    x: f64,
    y: f64,
};

fn nodeMargin(attrs: []const Attr, fallback: f64) NodeMargin {
    const value = attrValue(attrs, "margin") orelse return .{ .x = fallback, .y = fallback };
    var parts = std.mem.tokenizeAny(u8, value, ", \t");
    const first = parts.next() orelse return .{ .x = fallback, .y = fallback };
    const x = parseInchDimension(first) orelse fallback;
    const y = if (parts.next()) |second| parseInchDimension(second) orelse x else x;
    return .{ .x = x, .y = y };
}

fn orientSizeForLayout(size: NodeSize, rankdir: RankDir) NodeSize {
    return LayoutAxes.init(rankdir).orientSize(size);
}

fn computeClusterLayouts(graph: *const Graph, axes: LayoutAxes, nodes: []const NodeLayout, clusters: []ClusterLayout) void {
    const pad_x: f64 = 12;
    const pad_y: f64 = 12;
    const label_pad_x: f64 = 6;
    const label_band: f64 = 18;
    const child_gap: f64 = 12;
    var center_buf: [256]f64 = undefined;
    var size_buf: [256]NodeSize = undefined;
    var center_y_buf: [256]f64 = undefined;
    var size_y_buf: [256]NodeSize = undefined;
    const boundary_inputs_available = nodes.len <= center_buf.len;
    if (boundary_inputs_available) {
        for (nodes, 0..) |node, id| {
            center_buf[id] = node.center.x;
            size_buf[id] = .{ .width = node.width, .height = node.height };
            center_y_buf[id] = node.center.y;
            size_y_buf[id] = .{ .width = node.height, .height = node.width };
        }
    }
    for (graph.clusters.items, 0..) |cluster, index| {
        var min_x = std.math.floatMax(f64);
        var min_y = std.math.floatMax(f64);
        var max_x: f64 = 0;
        var max_y: f64 = 0;
        var has_node = false;
        for (cluster.nodes) |node_id| {
            if (node_id >= nodes.len) continue;
            const n = nodes[node_id];
            min_x = @min(min_x, n.center.x - n.width / 2.0);
            min_y = @min(min_y, n.center.y - n.height / 2.0);
            max_x = @max(max_x, n.center.x + n.width / 2.0);
            max_y = @max(max_y, n.center.y + n.height / 2.0);
            has_node = true;
        }
        if (!has_node) {
            clusters[index] = .{ .id = cluster.id, .x = 0, .y = 0, .width = 0, .height = 0 };
            continue;
        }
        const label_font_size = parsePositiveAttrFloat(cluster.attrs.items, "fontsize", 14.0);
        const label_min_width = displayLabelEstimatedWidth(cluster.label, label_font_size) + label_pad_x * 2.0;
        var x = min_x - pad_x;
        var width = (max_x - min_x) + pad_x * 2.0;
        if (boundary_inputs_available) {
            if (solveClusterBoundary(cluster, center_buf[0..nodes.len], size_buf[0..nodes.len], pad_x)) |boundary| {
                x = boundary.left;
                width = boundary.right - boundary.left;
            }
        }
        var y = min_y - pad_y - label_band;
        var height = (max_y - min_y) + pad_y * 2.0 + label_band;
        if (boundary_inputs_available) {
            if (solveClusterBoundary(cluster, center_y_buf[0..nodes.len], size_y_buf[0..nodes.len], pad_y)) |boundary| {
                y = boundary.left - label_band;
                height = boundary.right - boundary.left + label_band;
            }
        }
        if (width < label_min_width) {
            const extra = label_min_width - width;
            x -= extra / 2.0;
            width = label_min_width;
        }
        clusters[index] = .{
            .id = cluster.id,
            .x = @max(0, x),
            .y = @max(0, y),
            .width = width,
            .height = height,
        };
    }

    for (graph.clusters.items, 0..) |cluster, index| {
        const parent_name = cluster.parent_name orelse continue;
        const parent_index = clusterIndexByName(graph, parent_name) orelse continue;
        if (parent_index >= clusters.len or index >= clusters.len) continue;
        const child = clusters[index];
        if (child.width <= 0 or child.height <= 0) continue;
        var parent = &clusters[parent_index];
        if (parent.width <= 0 or parent.height <= 0) {
            parent.* = .{
                .id = graph.clusters.items[parent_index].id,
                .x = @max(0, child.x - child_gap),
                .y = @max(0, child.y - child_gap - label_band),
                .width = child.width + child_gap * 2.0,
                .height = child.height + child_gap * 2.0 + label_band,
            };
            continue;
        }
        const min_x = @min(parent.x, @max(0, child.x - child_gap));
        const min_y = @min(parent.y, @max(0, child.y - child_gap - label_band));
        const max_x = @max(parent.x + parent.width, child.x + child.width + child_gap);
        const max_y = @max(parent.y + parent.height, child.y + child.height + child_gap);
        parent.x = min_x;
        parent.y = min_y;
        parent.width = max_x - min_x;
        parent.height = max_y - min_y;
    }

    expandClusterLayoutsForBackEdges(graph, axes, nodes, clusters);
}

fn expandClusterLayoutsForBackEdges(graph: *const Graph, axes: LayoutAxes, nodes: []const NodeLayout, clusters: []ClusterLayout) void {
    const side_gap: f64 = 28.0;
    for (graph.edges.items) |edge_item| {
        if (edge_item.from >= nodes.len or edge_item.to >= nodes.len) continue;
        const from_cluster = clusterIndexContainingNode(graph, edge_item.from) orelse continue;
        const to_cluster = clusterIndexContainingNode(graph, edge_item.to) orelse continue;
        if (from_cluster != to_cluster or from_cluster >= clusters.len) continue;
        const from = nodes[edge_item.from];
        const to = nodes[edge_item.to];
        if (!edgeRunsBackwardOnRankAxis(axes, from.center, to.center)) continue;
        const cluster_box = &clusters[from_cluster];
        if (cluster_box.width <= 0 or cluster_box.height <= 0) continue;
        const from_along = axes.pointAlong(from.center);
        const to_along = axes.pointAlong(to.center);
        const overlap_width = axes.nodeAlongHalfSize(from) + axes.nodeAlongHalfSize(to);
        const prefer_negative = if (@abs(from_along - to_along) <= overlap_width + 2.0) true else from_along <= to_along;
        const side_along = if (prefer_negative)
            @max(0.0, @min(from_along - axes.nodeAlongHalfSize(from), to_along - axes.nodeAlongHalfSize(to)) - side_gap)
        else
            @max(from_along + axes.nodeAlongHalfSize(from), to_along + axes.nodeAlongHalfSize(to)) + side_gap;
        expandClusterAlongSide(axes, cluster_box, side_along, prefer_negative);
    }
}

fn edgeRunsBackwardOnRankAxis(axes: LayoutAxes, from: Point, to: Point) bool {
    return switch (axes.rankdir) {
        .TB => from.y > to.y,
        .BT => from.y < to.y,
        .LR => from.x > to.x,
        .RL => from.x < to.x,
    };
}

fn expandClusterAlongSide(axes: LayoutAxes, cluster_box: *ClusterLayout, side_along: f64, prefer_negative: bool) void {
    switch (axes.rankdir) {
        .TB, .BT => {
            if (prefer_negative) {
                if (side_along < cluster_box.x) {
                    const old_right = cluster_box.x + cluster_box.width;
                    cluster_box.x = side_along;
                    cluster_box.width = old_right - side_along;
                }
            } else {
                const old_right = cluster_box.x + cluster_box.width;
                if (side_along > old_right) cluster_box.width = side_along - cluster_box.x;
            }
        },
        .LR, .RL => {
            if (prefer_negative) {
                if (side_along < cluster_box.y) {
                    const old_bottom = cluster_box.y + cluster_box.height;
                    cluster_box.y = side_along;
                    cluster_box.height = old_bottom - side_along;
                }
            } else {
                const old_bottom = cluster_box.y + cluster_box.height;
                if (side_along > old_bottom) cluster_box.height = side_along - cluster_box.y;
            }
        },
    }
}

fn clusterLayoutsAlongExtent(axes: LayoutAxes, clusters: []const ClusterLayout, options: LayoutOptions) f64 {
    const margin = axes.alongMargin(options);
    var extent: f64 = 0;
    for (clusters) |cluster_box| {
        if (cluster_box.width <= 0 or cluster_box.height <= 0) continue;
        const screen_extent = switch (axes.rankdir) {
            .TB, .BT => cluster_box.x + cluster_box.width,
            .LR, .RL => cluster_box.y + cluster_box.height,
        };
        extent = @max(extent, @max(0.0, screen_extent - margin));
    }
    return extent;
}

fn clusterIndexByName(graph: *const Graph, name: []const u8) ?usize {
    for (graph.clusters.items, 0..) |cluster, index| {
        if (std.mem.eql(u8, cluster.name, name)) return index;
    }
    return null;
}

fn applyRankConstraints(graph: *const Graph, ranks: []usize) void {
    for (graph.rank_constraints.items) |constraint| {
        if (constraint.kind != .same or constraint.node_ids.len == 0) continue;
        var target_rank: usize = 0;
        for (constraint.node_ids) |id| {
            if (id < ranks.len) target_rank = @max(target_rank, ranks[id]);
        }
        for (constraint.node_ids) |id| {
            if (id < ranks.len) ranks[id] = target_rank;
        }
    }

    for (graph.rank_constraints.items) |constraint| {
        switch (constraint.kind) {
            .min, .source => {
                for (constraint.node_ids) |id| {
                    if (id < ranks.len) ranks[id] = 0;
                }
            },
            else => {},
        }
    }

    var max_rank: usize = 0;
    for (ranks) |rank| max_rank = @max(max_rank, rank);

    for (graph.rank_constraints.items) |constraint| {
        switch (constraint.kind) {
            .max, .sink => {
                for (constraint.node_ids) |id| {
                    if (id < ranks.len) ranks[id] = max_rank;
                }
            },
            else => {},
        }
    }
}

fn rankConstraintsSatisfied(graph: *const Graph, ranks: []const usize) bool {
    var max_rank: usize = 0;
    for (ranks) |rank| max_rank = @max(max_rank, rank);
    for (graph.rank_constraints.items) |constraint| {
        switch (constraint.kind) {
            .same => {
                if (constraint.node_ids.len == 0) continue;
                var target: ?usize = null;
                for (constraint.node_ids) |id| {
                    if (id >= ranks.len) continue;
                    if (target) |rank| {
                        if (ranks[id] != rank) return false;
                    } else {
                        target = ranks[id];
                    }
                }
            },
            .min, .source => {
                for (constraint.node_ids) |id| {
                    if (id < ranks.len and ranks[id] != 0) return false;
                }
            },
            .max, .sink => {
                for (constraint.node_ids) |id| {
                    if (id < ranks.len and ranks[id] != max_rank) return false;
                }
            },
        }
    }
    return true;
}

fn assignRanksForCyclicComponents(graph: *const Graph, ranks: []usize, acyclic_edge: []const bool) void {
    const state = graph.allocator.alloc(u8, ranks.len) catch return;
    defer graph.allocator.free(state);
    @memset(state, 0);
    for (graph.nodes.items, 0..) |_, id| relaxRanksDepthFirst(graph, ranks, state, acyclic_edge, id);
}

fn relaxRanksDepthFirst(graph: *const Graph, ranks: []usize, state: []u8, acyclic_edge: []const bool, node_id: NodeId) void {
    if (node_id >= state.len) return;
    if (state[node_id] == 1) return;
    if (state[node_id] == 2) return;
    state[node_id] = 1;
    for (graph.edges.items) |edge_item| {
        if (edge_item.id < acyclic_edge.len and acyclic_edge[edge_item.id]) continue;
        if (!edge_item.constraint or edge_item.from != node_id) continue;
        if (edge_item.to >= ranks.len or edge_item.to == node_id) continue;
        if (state[edge_item.to] == 1) continue;
        const candidate = ranks[node_id] + @max(edge_item.min_len, 1);
        if (ranks[edge_item.to] < candidate) {
            ranks[edge_item.to] = candidate;
            if (state[edge_item.to] == 2) state[edge_item.to] = 0;
        }
        relaxRanksDepthFirst(graph, ranks, state, acyclic_edge, edge_item.to);
    }
    state[node_id] = 2;
}

fn tightenRanksTowardSinks(graph: *const Graph, ranks: []usize, acyclic_edge: []const bool) void {
    if (ranks.len == 0) return;
    var max_rank: usize = 0;
    for (ranks) |rank| max_rank = @max(max_rank, rank);
    if (max_rank == 0) return;

    for (0..4) |_| {
        var changed = false;
        var rank = max_rank;
        while (true) {
            for (ranks, 0..) |node_rank, node_id| {
                if (node_rank != rank) continue;
                if (rankTighteningPinned(graph, node_id)) continue;
                const target_rank = bestFeasibleRankForNode(graph, ranks, acyclic_edge, node_id) orelse continue;
                if (target_rank > ranks[node_id]) {
                    const current_rank = ranks[node_id];
                    ranks[node_id] = target_rank;
                    if (rankConstraintsSatisfied(graph, ranks)) {
                        changed = true;
                    } else {
                        ranks[node_id] = current_rank;
                    }
                }
            }
            if (rank == 0) break;
            rank -= 1;
        }
        if (!changed) break;
    }
}

const RankBounds = struct {
    min: usize,
    max: usize,
};

fn feasibleRankBoundsForNode(graph: *const Graph, ranks: []const usize, acyclic_edge: []const bool, node_id: NodeId) ?RankBounds {
    if (node_id >= ranks.len) return null;
    var min_rank: usize = 0;
    var max_rank: usize = std.math.maxInt(usize);
    for (graph.edges.items) |edge_item| {
        if (!rankEdgeActive(edge_item, acyclic_edge)) continue;
        const min_len = @max(edge_item.min_len, 1);
        if (edge_item.to == node_id and edge_item.from < ranks.len) {
            min_rank = @max(min_rank, ranks[edge_item.from] + min_len);
        } else if (edge_item.from == node_id and edge_item.to < ranks.len) {
            if (ranks[edge_item.to] < min_len) return null;
            max_rank = @min(max_rank, ranks[edge_item.to] - min_len);
        }
    }
    if (max_rank == std.math.maxInt(usize)) max_rank = ranks[node_id];
    if (min_rank > max_rank) return null;
    return .{ .min = min_rank, .max = max_rank };
}

fn bestFeasibleRankForNode(graph: *const Graph, ranks: []const usize, acyclic_edge: []const bool, node_id: NodeId) ?usize {
    const bounds = feasibleRankBoundsForNode(graph, ranks, acyclic_edge, node_id) orelse return null;
    var best_rank = bounds.min;
    var best_cost = incidentRankSpanCost(graph, ranks, acyclic_edge, node_id, best_rank);
    var candidate = bounds.min + 1;
    while (candidate <= bounds.max) : (candidate += 1) {
        const cost = incidentRankSpanCost(graph, ranks, acyclic_edge, node_id, candidate);
        if (cost < best_cost or (@abs(cost - best_cost) <= 0.0001 and candidate > best_rank)) {
            best_cost = cost;
            best_rank = candidate;
        }
    }
    return best_rank;
}

fn improveRanksByLocalSearch(graph: *const Graph, ranks: []usize, acyclic_edge: []const bool, passes: usize) void {
    if (passes == 0) return;
    for (0..passes) |_| {
        var changed = false;
        for (ranks, 0..) |current_rank, node_id| {
            if (rankTighteningPinned(graph, node_id)) continue;
            const target_rank = bestFeasibleRankForNode(graph, ranks, acyclic_edge, node_id) orelse continue;
            if (target_rank == current_rank) continue;
            const before = rankAssignmentCost(graph, ranks, acyclic_edge);
            ranks[node_id] = target_rank;
            const after = rankAssignmentCost(graph, ranks, acyclic_edge);
            if (after < before and rankAssignmentFeasible(graph, ranks, acyclic_edge) and rankConstraintsSatisfied(graph, ranks)) {
                changed = true;
            } else {
                ranks[node_id] = current_rank;
            }
        }
        if (!changed) break;
    }
}

fn improveRanksByNetworkSimplex(allocator: std.mem.Allocator, graph: *const Graph, ranks: []usize, acyclic_edge: []const bool, max_pivots: usize) !usize {
    if (max_pivots == 0 or ranks.len == 0) return 0;
    const rank_edges = try collectRankEdges(allocator, graph, acyclic_edge);
    defer allocator.free(rank_edges);
    if (rank_edges.len == 0) return 0;

    const merge_backup = try allocator.dupe(usize, ranks);
    defer allocator.free(merge_backup);
    const before_merge_cost = rankEdgesCost(rank_edges, ranks);
    _ = try mergeTightRankComponents(allocator, rank_edges, ranks, ranks.len * 2);
    const after_merge_cost = rankEdgesCost(rank_edges, ranks);
    if (!rankEdgesFeasible(rank_edges, ranks) or
        !rankAssignmentFeasible(graph, ranks, acyclic_edge) or
        !rankConstraintsSatisfied(graph, ranks) or
        after_merge_cost > before_merge_cost)
    {
        @memcpy(ranks, merge_backup);
        return 0;
    }

    var tree = (try buildTightRankTree(allocator, rank_edges, ranks)) orelse return 0;
    defer tree.deinit();

    var improving_pivots: usize = 0;
    var attempts: usize = 0;
    var stall_count: usize = 0;
    while (attempts < max_pivots) {
        const leaving = selectLeavingRankTreeEdge(&tree, rank_edges) orelse break;
        const entering = selectEnteringRankTreeEdge(&tree, rank_edges, ranks, leaving) orelse break;
        const entering_slack = rankEdgeSlack(rank_edges[entering], ranks) orelse break;

        const rank_backup = try allocator.dupe(usize, ranks);
        defer allocator.free(rank_backup);
        const tree_backup = try allocator.dupe(bool, tree.in_tree);
        defer allocator.free(tree_backup);
        const before_cost = rankEdgesCost(rank_edges, ranks);

        const pivoted = try pivotRankTightTree(&tree, rank_edges, ranks, leaving, entering);
        attempts += 1;
        if (!pivoted or !rankEdgesFeasible(rank_edges, ranks) or !rankAssignmentFeasible(graph, ranks, acyclic_edge) or !rankConstraintsSatisfied(graph, ranks)) {
            @memcpy(ranks, rank_backup);
            @memcpy(tree.in_tree, tree_backup);
            try rebuildRankTightTreeParents(&tree, rank_edges);
            break;
        }

        const after_cost = rankEdgesCost(rank_edges, ranks);
        if (after_cost >= before_cost) {
            if (entering_slack == 0 and @abs(after_cost - before_cost) <= 0.0001) {
                stall_count += 1;
                if (stall_count > ranks.len) break;
                continue;
            }
            @memcpy(ranks, rank_backup);
            @memcpy(tree.in_tree, tree_backup);
            try rebuildRankTightTreeParents(&tree, rank_edges);
            break;
        }
        stall_count = 0;
        improving_pivots += 1;
    }
    return improving_pivots;
}

fn incidentRankSpanCost(graph: *const Graph, ranks: []const usize, acyclic_edge: []const bool, node_id: NodeId, candidate_rank: usize) f64 {
    var cost: f64 = 0;
    for (graph.edges.items) |edge_item| {
        if (!rankEdgeActive(edge_item, acyclic_edge)) continue;
        if (edge_item.from == node_id and edge_item.to < ranks.len) {
            cost += rankSpanCost(candidate_rank, ranks[edge_item.to], edge_item.weight);
        } else if (edge_item.to == node_id and edge_item.from < ranks.len) {
            cost += rankSpanCost(ranks[edge_item.from], candidate_rank, edge_item.weight);
        }
    }
    return cost;
}

fn rankAssignmentCost(graph: *const Graph, ranks: []const usize, acyclic_edge: []const bool) f64 {
    var cost: f64 = 0;
    for (graph.edges.items) |edge_item| {
        if (!rankEdgeActive(edge_item, acyclic_edge)) continue;
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        cost += rankSpanCost(ranks[edge_item.from], ranks[edge_item.to], edge_item.weight);
    }
    return cost;
}

fn rankAssignmentFeasible(graph: *const Graph, ranks: []const usize, acyclic_edge: []const bool) bool {
    for (graph.edges.items) |edge_item| {
        if (!rankEdgeActive(edge_item, acyclic_edge)) continue;
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        const min_len = @max(edge_item.min_len, 1);
        if (ranks[edge_item.to] < ranks[edge_item.from] + min_len) return false;
    }
    return true;
}

fn rankEdgeActive(edge_item: Edge, acyclic_edge: []const bool) bool {
    return edge_item.constraint and edge_item.id < acyclic_edge.len and acyclic_edge[edge_item.id];
}

const RankEdge = struct {
    edge_id: EdgeId,
    from: NodeId,
    to: NodeId,
    min_len: usize,
    weight: f64,
};

const RankTightTree = struct {
    allocator: std.mem.Allocator,
    in_tree: []bool,
    parent: []?NodeId,
    parent_edge: []?usize,
    depth: []usize,
    low: []usize,
    lim: []usize,
    root: NodeId = 0,

    fn init(allocator: std.mem.Allocator, node_count: usize, edge_count: usize) !RankTightTree {
        const in_tree = try allocator.alloc(bool, edge_count);
        errdefer allocator.free(in_tree);
        const parent = try allocator.alloc(?NodeId, node_count);
        errdefer allocator.free(parent);
        const parent_edge = try allocator.alloc(?usize, node_count);
        errdefer allocator.free(parent_edge);
        const depth = try allocator.alloc(usize, node_count);
        errdefer allocator.free(depth);
        const low = try allocator.alloc(usize, node_count);
        errdefer allocator.free(low);
        const lim = try allocator.alloc(usize, node_count);
        errdefer allocator.free(lim);

        @memset(in_tree, false);
        @memset(parent, null);
        @memset(parent_edge, null);
        @memset(depth, 0);
        @memset(low, 0);
        @memset(lim, 0);
        return .{
            .allocator = allocator,
            .in_tree = in_tree,
            .parent = parent,
            .parent_edge = parent_edge,
            .depth = depth,
            .low = low,
            .lim = lim,
        };
    }

    fn deinit(self: *RankTightTree) void {
        self.allocator.free(self.in_tree);
        self.allocator.free(self.parent);
        self.allocator.free(self.parent_edge);
        self.allocator.free(self.depth);
        self.allocator.free(self.low);
        self.allocator.free(self.lim);
        self.* = undefined;
    }

    fn inSubtree(self: *const RankTightTree, node: NodeId, subtree_root: NodeId) bool {
        if (node >= self.low.len or subtree_root >= self.low.len) return false;
        return self.low[subtree_root] <= self.low[node] and self.low[node] <= self.lim[subtree_root];
    }
};

fn collectRankEdges(allocator: std.mem.Allocator, graph: *const Graph, acyclic_edge: []const bool) ![]RankEdge {
    var edges = std.ArrayList(RankEdge).empty;
    errdefer edges.deinit(allocator);
    for (graph.edges.items) |edge_item| {
        if (!rankEdgeActive(edge_item, acyclic_edge)) continue;
        try edges.append(allocator, .{
            .edge_id = edge_item.id,
            .from = edge_item.from,
            .to = edge_item.to,
            .min_len = @max(edge_item.min_len, 1),
            .weight = @max(edge_item.weight, 0.1),
        });
    }
    return edges.toOwnedSlice(allocator);
}

fn rankEdgeSlack(edge: RankEdge, ranks: []const usize) ?usize {
    if (edge.from >= ranks.len or edge.to >= ranks.len) return null;
    if (ranks[edge.to] < ranks[edge.from] + edge.min_len) return null;
    return ranks[edge.to] - ranks[edge.from] - edge.min_len;
}

fn rankEdgeTight(edge: RankEdge, ranks: []const usize) bool {
    return (rankEdgeSlack(edge, ranks) orelse return false) == 0;
}

fn countTightRankEdges(edges: []const RankEdge, ranks: []const usize) usize {
    var count: usize = 0;
    for (edges) |edge| {
        if (rankEdgeTight(edge, ranks)) count += 1;
    }
    return count;
}

fn buildTightRankTree(allocator: std.mem.Allocator, edges: []const RankEdge, ranks: []const usize) !?RankTightTree {
    if (ranks.len == 0) return null;
    var tree = try RankTightTree.init(allocator, ranks.len, edges.len);
    errdefer tree.deinit();

    const visited = try allocator.alloc(bool, ranks.len);
    defer allocator.free(visited);
    @memset(visited, false);

    const queue = try allocator.alloc(NodeId, ranks.len);
    defer allocator.free(queue);
    var head: usize = 0;
    var tail: usize = 0;
    visited[tree.root] = true;
    queue[tail] = tree.root;
    tail += 1;

    while (head < tail) : (head += 1) {
        const node_id = queue[head];
        for (edges, 0..) |edge, edge_index| {
            if (tree.in_tree[edge_index]) continue;
            if (!rankEdgeTight(edge, ranks)) continue;
            const neighbor = if (edge.from == node_id)
                edge.to
            else if (edge.to == node_id)
                edge.from
            else
                continue;
            if (neighbor >= visited.len or visited[neighbor]) continue;
            visited[neighbor] = true;
            tree.in_tree[edge_index] = true;
            tree.parent[neighbor] = node_id;
            tree.parent_edge[neighbor] = edge_index;
            tree.depth[neighbor] = tree.depth[node_id] + 1;
            queue[tail] = neighbor;
            tail += 1;
        }
    }

    if (tail != ranks.len) {
        tree.deinit();
        return null;
    }
    try computeTightTreeIntervals(&tree);
    return tree;
}

fn computeTightTreeIntervals(tree: *RankTightTree) !void {
    @memset(tree.low, 0);
    @memset(tree.lim, 0);
    @memset(tree.depth, 0);
    const node_count = tree.parent.len;
    if (node_count == 0) return;

    var child_counts = try tree.allocator.alloc(usize, node_count);
    defer tree.allocator.free(child_counts);
    @memset(child_counts, 0);
    for (tree.parent, 0..) |parent, node_id| {
        _ = node_id;
        if (parent) |parent_id| {
            if (parent_id < child_counts.len) child_counts[parent_id] += 1;
        }
    }

    var child_starts = try tree.allocator.alloc(usize, node_count + 1);
    defer tree.allocator.free(child_starts);
    var total_children: usize = 0;
    for (child_counts, 0..) |count, node_id| {
        child_starts[node_id] = total_children;
        total_children += count;
    }
    child_starts[node_count] = total_children;

    var offsets = try tree.allocator.alloc(usize, node_count);
    defer tree.allocator.free(offsets);
    @memcpy(offsets, child_starts[0..node_count]);

    var children = try tree.allocator.alloc(NodeId, total_children);
    defer tree.allocator.free(children);
    for (tree.parent, 0..) |parent, node_id| {
        if (parent) |parent_id| {
            if (parent_id >= offsets.len) continue;
            children[offsets[parent_id]] = node_id;
            offsets[parent_id] += 1;
        }
    }

    const Frame = struct {
        node: NodeId,
        next_child: usize,
    };
    var stack = try tree.allocator.alloc(Frame, node_count);
    defer tree.allocator.free(stack);
    var stack_len: usize = 0;
    var counter: usize = 1;
    stack[stack_len] = .{ .node = tree.root, .next_child = 0 };
    stack_len += 1;

    while (stack_len > 0) {
        const frame = &stack[stack_len - 1];
        const node_id = frame.node;
        const start = child_starts[node_id];
        const end = child_starts[node_id + 1];
        if (frame.next_child == 0) tree.low[node_id] = counter;
        if (frame.next_child < end - start) {
            const child = children[start + frame.next_child];
            frame.next_child += 1;
            tree.depth[child] = tree.depth[node_id] + 1;
            stack[stack_len] = .{ .node = child, .next_child = 0 };
            stack_len += 1;
            continue;
        }
        tree.lim[node_id] = counter;
        counter += 1;
        stack_len -= 1;
    }
}

fn tightRankEdgeComponentCount(allocator: std.mem.Allocator, edges: []const RankEdge, ranks: []const usize) !usize {
    if (ranks.len == 0) return 0;
    const labels = try allocator.alloc(usize, ranks.len);
    defer allocator.free(labels);
    return labelTightRankEdgeComponents(allocator, edges, ranks, labels);
}

fn labelTightRankEdgeComponents(allocator: std.mem.Allocator, edges: []const RankEdge, ranks: []const usize, labels: []usize) !usize {
    if (labels.len < ranks.len) return error.BufferTooSmall;
    const visited = try allocator.alloc(bool, ranks.len);
    defer allocator.free(visited);
    @memset(visited, false);
    @memset(labels[0..ranks.len], std.math.maxInt(usize));

    var stack = std.ArrayList(NodeId).empty;
    defer stack.deinit(allocator);

    var components: usize = 0;
    for (0..ranks.len) |start| {
        if (visited[start]) continue;
        const component = components;
        components += 1;
        try stack.append(allocator, start);
        visited[start] = true;
        labels[start] = component;
        while (stack.pop()) |node_id| {
            for (edges) |edge| {
                if (!rankEdgeTight(edge, ranks)) continue;
                const neighbor = if (edge.from == node_id)
                    edge.to
                else if (edge.to == node_id)
                    edge.from
                else
                    continue;
                if (neighbor >= visited.len or visited[neighbor]) continue;
                visited[neighbor] = true;
                labels[neighbor] = component;
                try stack.append(allocator, neighbor);
            }
        }
    }
    return components;
}

fn selectEnteringRankEdge(edges: []const RankEdge, ranks: []const usize, component_labels: []const usize) ?usize {
    var best_index: ?usize = null;
    var best_slack: usize = std.math.maxInt(usize);
    var best_weight: f64 = 0;
    for (edges, 0..) |edge, index| {
        if (edge.from >= component_labels.len or edge.to >= component_labels.len) continue;
        if (component_labels[edge.from] == component_labels[edge.to]) continue;
        const slack = rankEdgeSlack(edge, ranks) orelse continue;
        if (slack == 0) continue;
        if (best_index == null or slack < best_slack or (slack == best_slack and edge.weight > best_weight)) {
            best_index = index;
            best_slack = slack;
            best_weight = edge.weight;
        }
    }
    return best_index;
}

fn shiftRankComponent(ranks: []usize, component_labels: []const usize, component: usize, delta: isize) bool {
    if (component_labels.len < ranks.len) return false;
    if (delta < 0) {
        const amount: usize = @intCast(-delta);
        for (ranks, 0..) |rank, node_id| {
            if (component_labels[node_id] == component and rank < amount) return false;
        }
        for (ranks, 0..) |*rank, node_id| {
            if (component_labels[node_id] == component) rank.* -= amount;
        }
        return true;
    }
    const amount: usize = @intCast(delta);
    for (ranks, 0..) |*rank, node_id| {
        if (component_labels[node_id] == component) rank.* += amount;
    }
    return true;
}

fn tightenEnteringEdgeByShiftingHeadComponent(edge: RankEdge, ranks: []usize, component_labels: []const usize) bool {
    if (edge.to >= component_labels.len) return false;
    const slack = rankEdgeSlack(edge, ranks) orelse return false;
    if (slack == 0) return true;
    return shiftRankComponent(ranks, component_labels, component_labels[edge.to], -@as(isize, @intCast(slack)));
}

fn mergeTightRankComponentsOnce(allocator: std.mem.Allocator, edges: []const RankEdge, ranks: []usize) !bool {
    const labels = try allocator.alloc(usize, ranks.len);
    defer allocator.free(labels);
    const component_count = try labelTightRankEdgeComponents(allocator, edges, ranks, labels);
    if (component_count <= 1) return false;
    const entering_index = selectEnteringRankEdge(edges, ranks, labels) orelse return false;

    const backup = try allocator.dupe(usize, ranks);
    defer allocator.free(backup);
    if (!tightenEnteringEdgeByShiftingHeadComponent(edges[entering_index], ranks, labels)) return false;
    if (!rankEdgesFeasible(edges, ranks)) {
        @memcpy(ranks, backup);
        return false;
    }
    return true;
}

fn mergeTightRankComponents(allocator: std.mem.Allocator, edges: []const RankEdge, ranks: []usize, max_merges: usize) !usize {
    var merges: usize = 0;
    while (merges < max_merges) {
        if (!try mergeTightRankComponentsOnce(allocator, edges, ranks)) break;
        merges += 1;
    }
    return merges;
}

fn tightTreeChildForEdge(tree: *const RankTightTree, edge: RankEdge) ?NodeId {
    if (edge.from >= tree.depth.len or edge.to >= tree.depth.len) return null;
    return if (tree.depth[edge.from] > tree.depth[edge.to]) edge.from else edge.to;
}

fn rankTreeEdgeCutValue(tree: *const RankTightTree, edges: []const RankEdge, tree_edge_index: usize) ?f64 {
    if (tree_edge_index >= edges.len or tree_edge_index >= tree.in_tree.len) return null;
    if (!tree.in_tree[tree_edge_index]) return null;
    const tree_edge = edges[tree_edge_index];
    const child = tightTreeChildForEdge(tree, tree_edge) orelse return null;

    var value: f64 = 0;
    for (edges) |edge| {
        if (edge.from >= tree.low.len or edge.to >= tree.low.len) continue;
        const from_in_child = tree.inSubtree(edge.from, child);
        const to_in_child = tree.inSubtree(edge.to, child);
        if (from_in_child == to_in_child) continue;

        if (from_in_child and !to_in_child) {
            value += if (child == tree_edge.to) -edge.weight else edge.weight;
        } else if (!from_in_child and to_in_child) {
            value += if (child == tree_edge.to) edge.weight else -edge.weight;
        }
    }
    return value;
}

fn selectLeavingRankTreeEdge(tree: *const RankTightTree, edges: []const RankEdge) ?usize {
    var best_index: ?usize = null;
    var best_value: f64 = 0;
    for (edges, 0..) |_, edge_index| {
        const value = rankTreeEdgeCutValue(tree, edges, edge_index) orelse continue;
        if (value < best_value) {
            best_value = value;
            best_index = edge_index;
        }
    }
    return best_index;
}

fn enteringEdgeCrossesLeavingCut(tree: *const RankTightTree, edges: []const RankEdge, leaving_index: usize, candidate: RankEdge) bool {
    if (leaving_index >= edges.len) return false;
    if (candidate.from >= tree.low.len or candidate.to >= tree.low.len) return false;
    const leaving = edges[leaving_index];
    const child = tightTreeChildForEdge(tree, leaving) orelse return false;
    const from_in_child = tree.inSubtree(candidate.from, child);
    const to_in_child = tree.inSubtree(candidate.to, child);
    if (from_in_child == to_in_child) return false;

    return if (child == leaving.to)
        from_in_child and !to_in_child
    else
        !from_in_child and to_in_child;
}

fn selectEnteringRankTreeEdge(tree: *const RankTightTree, edges: []const RankEdge, ranks: []const usize, leaving_index: usize) ?usize {
    var best_index: ?usize = null;
    var best_slack: usize = std.math.maxInt(usize);
    var best_weight: f64 = 0;
    for (edges, 0..) |edge, edge_index| {
        if (edge_index < tree.in_tree.len and tree.in_tree[edge_index]) continue;
        if (!enteringEdgeCrossesLeavingCut(tree, edges, leaving_index, edge)) continue;
        const slack = rankEdgeSlack(edge, ranks) orelse continue;
        if (best_index == null or slack < best_slack or (slack == best_slack and edge.weight > best_weight)) {
            best_index = edge_index;
            best_slack = slack;
            best_weight = edge.weight;
        }
    }
    return best_index;
}

fn shiftRankTreeSubtree(tree: *const RankTightTree, ranks: []usize, subtree_root: NodeId, delta: isize) bool {
    if (subtree_root >= tree.low.len or tree.low.len > ranks.len) return false;
    if (delta < 0) {
        const amount: usize = @intCast(-delta);
        for (ranks, 0..) |rank, node_id| {
            if (tree.inSubtree(node_id, subtree_root) and rank < amount) return false;
        }
        for (ranks, 0..) |*rank, node_id| {
            if (tree.inSubtree(node_id, subtree_root)) rank.* -= amount;
        }
        return true;
    }
    const amount: usize = @intCast(delta);
    for (ranks, 0..) |*rank, node_id| {
        if (tree.inSubtree(node_id, subtree_root)) rank.* += amount;
    }
    return true;
}

fn rebuildRankTightTreeParents(tree: *RankTightTree, edges: []const RankEdge) !void {
    const node_count = tree.parent.len;
    if (node_count == 0) return;
    @memset(tree.parent, null);
    @memset(tree.parent_edge, null);
    @memset(tree.depth, 0);

    const visited = try tree.allocator.alloc(bool, node_count);
    defer tree.allocator.free(visited);
    @memset(visited, false);
    const queue = try tree.allocator.alloc(NodeId, node_count);
    defer tree.allocator.free(queue);

    var head: usize = 0;
    var tail: usize = 0;
    visited[tree.root] = true;
    queue[tail] = tree.root;
    tail += 1;
    while (head < tail) : (head += 1) {
        const node_id = queue[head];
        for (edges, 0..) |edge, edge_index| {
            if (edge_index >= tree.in_tree.len or !tree.in_tree[edge_index]) continue;
            const neighbor = if (edge.from == node_id and edge.to < visited.len and !visited[edge.to])
                edge.to
            else if (edge.to == node_id and edge.from < visited.len and !visited[edge.from])
                edge.from
            else
                continue;
            visited[neighbor] = true;
            tree.parent[neighbor] = node_id;
            tree.parent_edge[neighbor] = edge_index;
            tree.depth[neighbor] = tree.depth[node_id] + 1;
            queue[tail] = neighbor;
            tail += 1;
        }
    }
    if (tail != node_count) return error.DisconnectedTightTree;
    try computeTightTreeIntervals(tree);
}

fn pivotRankTightTree(tree: *RankTightTree, edges: []const RankEdge, ranks: []usize, leaving_index: usize, entering_index: usize) !bool {
    if (leaving_index >= edges.len or entering_index >= edges.len) return false;
    if (leaving_index >= tree.in_tree.len or entering_index >= tree.in_tree.len) return false;
    if (!tree.in_tree[leaving_index] or tree.in_tree[entering_index]) return false;
    if (!enteringEdgeCrossesLeavingCut(tree, edges, leaving_index, edges[entering_index])) return false;
    const child = tightTreeChildForEdge(tree, edges[leaving_index]) orelse return false;
    const slack = rankEdgeSlack(edges[entering_index], ranks) orelse return false;
    const delta: isize = if (tree.inSubtree(edges[entering_index].to, child))
        -@as(isize, @intCast(slack))
    else
        @as(isize, @intCast(slack));

    const rank_backup = try tree.allocator.dupe(usize, ranks);
    defer tree.allocator.free(rank_backup);
    const tree_backup = try tree.allocator.dupe(bool, tree.in_tree);
    defer tree.allocator.free(tree_backup);

    if (!shiftRankTreeSubtree(tree, ranks, child, delta)) return false;
    if (!rankEdgesFeasible(edges, ranks)) {
        @memcpy(ranks, rank_backup);
        return false;
    }
    tree.in_tree[leaving_index] = false;
    tree.in_tree[entering_index] = true;
    rebuildRankTightTreeParents(tree, edges) catch |err| {
        @memcpy(ranks, rank_backup);
        @memcpy(tree.in_tree, tree_backup);
        try computeTightTreeIntervals(tree);
        return err;
    };
    return true;
}

fn rankEdgesFeasible(edges: []const RankEdge, ranks: []const usize) bool {
    for (edges) |edge| {
        if (rankEdgeSlack(edge, ranks) == null) return false;
    }
    return true;
}

fn rankEdgesCost(edges: []const RankEdge, ranks: []const usize) f64 {
    var cost: f64 = 0;
    for (edges) |edge| {
        if (edge.from >= ranks.len or edge.to >= ranks.len) continue;
        cost += rankSpanCost(ranks[edge.from], ranks[edge.to], edge.weight);
    }
    return cost;
}

fn rankSpanCost(from_rank: usize, to_rank: usize, weight: f64) f64 {
    const span = if (from_rank > to_rank) from_rank - to_rank else to_rank - from_rank;
    return @as(f64, @floatFromInt(span)) * @max(weight, 0.1);
}

fn rankTighteningPinned(graph: *const Graph, node_id: NodeId) bool {
    for (graph.rank_constraints.items) |constraint| {
        switch (constraint.kind) {
            .same, .min, .source, .max, .sink => {
                if (containsNode(constraint.node_ids, node_id)) return true;
            },
        }
    }
    return false;
}

fn labelLineCount(text: []const u8) usize {
    var count: usize = 1;
    for (text) |c| {
        if (c == '\n') count += 1;
    }
    return count;
}

fn labelMaxLineLen(text: []const u8) usize {
    var current: usize = 0;
    var max_len: usize = 0;
    for (text) |c| {
        if (c == '\n') {
            max_len = @max(max_len, current);
            current = 0;
        } else if (c == '\t') {
            current += 4;
        } else if ((c & 0xc0) != 0x80) {
            current += 1;
        }
    }
    return @max(max_len, current);
}

fn isHtmlLikeLabel(text: []const u8) bool {
    var index: usize = 0;
    while (std.mem.indexOfScalar(u8, text[index..], '<')) |rel| {
        const start = index + rel + 1;
        const close_rel = std.mem.indexOfScalar(u8, text[start..], '>') orelse return false;
        const tag = htmlTagName(text[start .. start + close_rel]);
        if (isKnownHtmlLabelTag(tag)) return true;
        index = start + close_rel + 1;
    }
    return false;
}

fn isKnownHtmlLabelTag(tag: []const u8) bool {
    return std.ascii.eqlIgnoreCase(tag, "br") or
        std.ascii.eqlIgnoreCase(tag, "b") or
        std.ascii.eqlIgnoreCase(tag, "i") or
        std.ascii.eqlIgnoreCase(tag, "u") or
        std.ascii.eqlIgnoreCase(tag, "font") or
        std.ascii.eqlIgnoreCase(tag, "sub") or
        std.ascii.eqlIgnoreCase(tag, "sup") or
        std.ascii.eqlIgnoreCase(tag, "table") or
        std.ascii.eqlIgnoreCase(tag, "tr") or
        std.ascii.eqlIgnoreCase(tag, "td");
}

fn htmlTagName(raw_tag: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, raw_tag, " \t\r\n/");
    var end: usize = 0;
    while (end < trimmed.len and !std.ascii.isWhitespace(trimmed[end]) and trimmed[end] != '/') : (end += 1) {}
    return trimmed[0..end];
}

fn displayLabelLineCount(text: []const u8) usize {
    if (!isHtmlLikeLabel(text)) return labelLineCount(text);
    var count: usize = 1;
    var scanner: HtmlLabelScanner = .{ .text = text };
    while (scanner.next()) |token| {
        if (token == .newline) count += 1;
    }
    return count;
}

fn displayLabelMaxLineLen(text: []const u8) usize {
    if (!isHtmlLikeLabel(text)) return labelMaxLineLen(text);
    var current: usize = 0;
    var max_len: usize = 0;
    var has_text = false;
    var pending_space = false;
    var scanner: HtmlLabelScanner = .{ .text = text };
    while (scanner.next()) |token| {
        switch (token) {
            .newline => {
                max_len = @max(max_len, current);
                current = 0;
                has_text = false;
                pending_space = false;
            },
            .char => |c| {
                if (isHtmlLabelSpace(c)) {
                    if (has_text) pending_space = true;
                    continue;
                }
                if (pending_space) {
                    current += 1;
                    pending_space = false;
                }
                if ((c & 0xc0) != 0x80) current += 1;
                has_text = true;
            },
            .tag_open, .tag_close => {},
        }
    }
    return @max(max_len, current);
}

fn displayLabelEstimatedWidth(text: []const u8, font_size: f64) f64 {
    if (!isHtmlLikeLabel(text)) return labelEstimatedWidth(text, font_size);
    var current: f64 = 0;
    var max_width: f64 = 0;
    var has_text = false;
    var pending_space = false;
    var scanner: HtmlLabelScanner = .{ .text = text };
    while (scanner.next()) |token| {
        switch (token) {
            .newline => {
                max_width = @max(max_width, current);
                current = 0;
                has_text = false;
                pending_space = false;
            },
            .char => |c| {
                if (isHtmlLabelSpace(c)) {
                    if (has_text) pending_space = true;
                    continue;
                }
                if (pending_space) {
                    current += labelCharWidth(' ', font_size);
                    pending_space = false;
                }
                current += labelCharWidth(c, font_size);
                has_text = true;
            },
            .tag_open, .tag_close => {},
        }
    }
    return @max(max_width, current);
}

fn labelEstimatedWidth(text: []const u8, font_size: f64) f64 {
    var current: f64 = 0;
    var max_width: f64 = 0;
    for (text) |c| {
        if (c == '\n') {
            max_width = @max(max_width, current);
            current = 0;
        } else if (c == '\t') {
            current += labelCharWidth(' ', font_size) * 4.0;
        } else if ((c & 0xc0) != 0x80) {
            current += labelCharWidth(c, font_size);
        }
    }
    return @max(max_width, current);
}

fn labelCharWidth(c: u8, font_size: f64) f64 {
    const em = font_size;
    return switch (c) {
        ' ', '.', ',', ':', ';', '!', '|', '\'', '`' => em * 0.25,
        'i', 'j', 'l', 'I', '[', ']', '(', ')', '/', '\\' => em * 0.28,
        'f', 't', 'r' => em * 0.34,
        '0'...'9' => em * 0.50,
        '#', '$', '+', '-', '=' => em * 0.50,
        'm', 'w', 'M', 'W' => em * 0.78,
        else => if (c < 0x80) em * 0.50 else em,
    };
}

fn isHtmlLabelSpace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

const HtmlToken = union(enum) {
    char: u8,
    newline,
    tag_open: []const u8,
    tag_close: []const u8,
};

const HtmlLabelScanner = struct {
    text: []const u8,
    index: usize = 0,

    fn next(self: *HtmlLabelScanner) ?HtmlToken {
        while (self.index < self.text.len) {
            const c = self.text[self.index];
            if (c == '<') {
                const start = self.index + 1;
                const close_rel = std.mem.indexOfScalar(u8, self.text[start..], '>') orelse {
                    self.index += 1;
                    return .{ .char = c };
                };
                const raw_tag = self.text[start .. start + close_rel];
                const tag = htmlTagName(raw_tag);
                const is_close = htmlTagIsClosing(raw_tag);
                self.index = start + close_rel + 1;
                if (std.ascii.eqlIgnoreCase(tag, "br")) return .newline;
                if (htmlStyleTagKind(tag) != .none) {
                    return if (is_close) .{ .tag_close = tag } else .{ .tag_open = raw_tag };
                }
                continue;
            }
            if (c == '&') {
                if (htmlEntity(self, "&amp;")) return .{ .char = '&' };
                if (htmlEntity(self, "&lt;")) return .{ .char = '<' };
                if (htmlEntity(self, "&gt;")) return .{ .char = '>' };
                if (htmlEntity(self, "&quot;")) return .{ .char = '"' };
                if (htmlEntity(self, "&apos;")) return .{ .char = '\'' };
            }
            self.index += 1;
            if (c == '\n') return .newline;
            return .{ .char = c };
        }
        return null;
    }
};

fn htmlTagIsClosing(raw_tag: []const u8) bool {
    const trimmed = trimHtmlTagLeft(raw_tag);
    return trimmed.len > 0 and trimmed[0] == '/';
}

fn trimHtmlTagLeft(raw_tag: []const u8) []const u8 {
    var start: usize = 0;
    while (start < raw_tag.len and isHtmlLabelSpace(raw_tag[start])) : (start += 1) {}
    return raw_tag[start..];
}

const HtmlStyleTag = enum {
    none,
    bold,
    italic,
    underline,
    overline,
    strike,
    subscript,
    superscript,
    font,
};

const HtmlTextStyle = struct {
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    overline: bool = false,
    strike: bool = false,
    baseline_shift: []const u8 = "",
    font_color: ?[]const u8 = null,
    font_face: ?[]const u8 = null,
    font_size: ?[]const u8 = null,
};

fn htmlStyleTagKind(tag: []const u8) HtmlStyleTag {
    if (std.ascii.eqlIgnoreCase(tag, "b")) return .bold;
    if (std.ascii.eqlIgnoreCase(tag, "i")) return .italic;
    if (std.ascii.eqlIgnoreCase(tag, "u")) return .underline;
    if (std.ascii.eqlIgnoreCase(tag, "o")) return .overline;
    if (std.ascii.eqlIgnoreCase(tag, "s")) return .strike;
    if (std.ascii.eqlIgnoreCase(tag, "sub")) return .subscript;
    if (std.ascii.eqlIgnoreCase(tag, "sup")) return .superscript;
    if (std.ascii.eqlIgnoreCase(tag, "font")) return .font;
    return .none;
}

fn applyHtmlOpenStyle(style: *HtmlTextStyle, raw_tag: []const u8) void {
    switch (htmlStyleTagKind(htmlTagName(raw_tag))) {
        .bold => style.bold = true,
        .italic => style.italic = true,
        .underline => style.underline = true,
        .overline => style.overline = true,
        .strike => style.strike = true,
        .subscript => style.baseline_shift = "sub",
        .superscript => style.baseline_shift = "super",
        .font => {
            if (htmlAttrValue(raw_tag, "color")) |value| style.font_color = value;
            if (htmlAttrValue(raw_tag, "face")) |value| style.font_face = value;
            if (htmlAttrValue(raw_tag, "point-size")) |value| style.font_size = value;
        },
        .none => {},
    }
}

fn resetHtmlCloseStyle(style: *HtmlTextStyle, tag: []const u8) void {
    switch (htmlStyleTagKind(tag)) {
        .bold => style.bold = false,
        .italic => style.italic = false,
        .underline => style.underline = false,
        .overline => style.overline = false,
        .strike => style.strike = false,
        .subscript, .superscript => style.baseline_shift = "",
        .font => {
            style.font_color = null;
            style.font_face = null;
            style.font_size = null;
        },
        .none => {},
    }
}

fn htmlStyleActive(style: HtmlTextStyle) bool {
    return style.bold or style.italic or style.underline or style.overline or style.strike or
        style.baseline_shift.len > 0 or style.font_color != null or style.font_face != null or style.font_size != null;
}

fn writeHtmlStyleOpen(writer: *Io.Writer, style: HtmlTextStyle) Io.Writer.Error!bool {
    if (!htmlStyleActive(style)) return false;
    try writer.writeAll("<tspan");
    if (style.bold) try writer.writeAll(" font-weight=\"bold\"");
    if (style.italic) try writer.writeAll(" font-style=\"italic\"");
    if (style.underline or style.overline or style.strike) {
        try writer.writeAll(" text-decoration=\"");
        var wrote = false;
        if (style.underline) {
            try writer.writeAll("underline");
            wrote = true;
        }
        if (style.overline) {
            if (wrote) try writer.writeByte(' ');
            try writer.writeAll("overline");
            wrote = true;
        }
        if (style.strike) {
            if (wrote) try writer.writeByte(' ');
            try writer.writeAll("line-through");
        }
        try writer.writeByte('"');
    }
    if (style.baseline_shift.len > 0) try writer.print(" baseline-shift=\"{s}\"", .{style.baseline_shift});
    if (style.font_color) |value| try writer.print(" fill=\"{s}\"", .{value});
    if (style.font_face) |value| try writer.print(" font-family=\"{s}\"", .{value});
    if (style.font_size) |value| try writer.print(" font-size=\"{s}\"", .{value});
    try writer.writeByte('>');
    return true;
}

fn htmlEntity(scanner: *HtmlLabelScanner, entity: []const u8) bool {
    if (scanner.index + entity.len > scanner.text.len) return false;
    if (!std.mem.eql(u8, scanner.text[scanner.index .. scanner.index + entity.len], entity)) return false;
    scanner.index += entity.len;
    return true;
}

const HtmlTableMetrics = struct {
    rows: usize,
    cols: usize,
    max_cell_len: usize,
    border: f64 = 1.5,
    cell_border: f64 = 1.0,
    cell_padding: f64 = 6.0,
    cell_spacing: f64 = 0.0,
    bg_color: ?[]const u8 = null,
    col_widths: [32]f64 = @splat(0),
    row_heights: [32]f64 = @splat(0),
};

fn htmlTableMetrics(label: []const u8) ?HtmlTableMetrics {
    if (!isHtmlLikeLabel(label)) return null;
    const table_start = findHtmlTag(label, "table", 0) orelse return null;
    const table_open_end = std.mem.indexOfScalar(u8, label[table_start..], '>') orelse return null;
    const table_tag = label[table_start + 1 .. table_start + table_open_end];
    var pos: usize = 0;
    var rows: usize = 0;
    var max_cols: usize = 0;
    var max_cell_len: usize = 1;
    var occupied: [32]usize = @splat(0);
    var col_widths: [32]f64 = @splat(0);
    var row_heights: [32]f64 = @splat(0);
    while (findHtmlTag(label, "tr", pos)) |tr_start| {
        if (rows > 0) {
            for (&occupied) |*remaining| {
                if (remaining.* > 0) remaining.* -= 1;
            }
        }
        const tr_open_end = std.mem.indexOfScalar(u8, label[tr_start..], '>') orelse break;
        const content_start = tr_start + tr_open_end + 1;
        const tr_close = findHtmlCloseTag(label, "tr", content_start) orelse break;
        const row = label[content_start..tr_close];
        var cell_pos: usize = 0;
        var cols: usize = 0;
        while (findHtmlTag(row, "td", cell_pos)) |td_start| {
            cols = nextFreeHtmlColumn(&occupied, cols);
            const td_open_end = std.mem.indexOfScalar(u8, row[td_start..], '>') orelse break;
            const td_tag = row[td_start + 1 .. td_start + td_open_end];
            const cell_start = td_start + td_open_end + 1;
            const td_close = findHtmlCloseTag(row, "td", cell_start) orelse break;
            const cell = row[cell_start..td_close];
            max_cell_len = @max(max_cell_len, displayLabelMaxLineLen(cell));
            const colspan = @max(htmlIntAttr(td_tag, "colspan", 1), 1);
            const rowspan = @max(htmlIntAttr(td_tag, "rowspan", 1), 1);
            applyHtmlCellSizeHints(td_tag, rows, cols, rowspan, colspan, &row_heights, &col_widths);
            var span_i: usize = 0;
            while (span_i < colspan and cols + span_i < occupied.len) : (span_i += 1) {
                occupied[cols + span_i] = @max(occupied[cols + span_i], rowspan);
            }
            cols += colspan;
            cell_pos = td_close + 1;
        }
        if (cols > 0) {
            rows += 1;
            max_cols = @max(max_cols, cols);
        }
        pos = tr_close + 1;
    }
    if (rows == 0 or max_cols == 0) return null;
    return .{
        .rows = rows,
        .cols = max_cols,
        .max_cell_len = max_cell_len,
        .border = @floatFromInt(htmlIntAttr(table_tag, "border", 1)),
        .cell_border = @floatFromInt(htmlIntAttr(table_tag, "cellborder", 1)),
        .cell_padding = @floatFromInt(htmlIntAttr(table_tag, "cellpadding", 6)),
        .cell_spacing = @floatFromInt(htmlIntAttr(table_tag, "cellspacing", 0)),
        .bg_color = htmlAttrValue(table_tag, "bgcolor"),
        .col_widths = col_widths,
        .row_heights = row_heights,
    };
}

fn htmlTablePreferredWidth(metrics: HtmlTableMetrics, fallback_cell_width: f64) f64 {
    var total = metrics.cell_spacing * @as(f64, @floatFromInt(metrics.cols + 1));
    for (metrics.col_widths[0..metrics.cols]) |width| {
        total += if (width > 0) width else @as(f64, @floatFromInt(@max(metrics.max_cell_len, 1))) * fallback_cell_width + metrics.cell_padding * 2.0;
    }
    return @max(1, total);
}

fn htmlTablePreferredHeight(metrics: HtmlTableMetrics, fallback_cell_height: f64) f64 {
    var total = metrics.cell_spacing * @as(f64, @floatFromInt(metrics.rows + 1));
    for (metrics.row_heights[0..metrics.rows]) |height| {
        total += if (height > 0) height else fallback_cell_height + metrics.cell_padding * 2.0;
    }
    return @max(1, total);
}

fn htmlTableHasExplicitSize(metrics: HtmlTableMetrics) bool {
    for (metrics.col_widths[0..metrics.cols]) |width| {
        if (width > 0) return true;
    }
    for (metrics.row_heights[0..metrics.rows]) |height| {
        if (height > 0) return true;
    }
    return false;
}

const HtmlTableGrid = struct {
    x: f64,
    y: f64,
    col_widths: [32]f64,
    row_heights: [32]f64,
    cell_spacing: f64,
};

fn htmlTableGrid(label: []const u8, layout: NodeLayout) ?HtmlTableGrid {
    const metrics = htmlTableMetrics(label) orelse return null;
    const x = layout.center.x - layout.width / 2.0;
    const y = layout.center.y - layout.height / 2.0;
    var col_widths = metrics.col_widths;
    var row_heights = metrics.row_heights;
    const inner_w = @max(1, layout.width - metrics.cell_spacing * @as(f64, @floatFromInt(metrics.cols + 1)));
    const inner_h = @max(1, layout.height - metrics.cell_spacing * @as(f64, @floatFromInt(metrics.rows + 1)));
    distributeHtmlGridSizes(col_widths[0..metrics.cols], inner_w);
    distributeHtmlGridSizes(row_heights[0..metrics.rows], inner_h);
    return .{
        .x = x,
        .y = y,
        .col_widths = col_widths,
        .row_heights = row_heights,
        .cell_spacing = metrics.cell_spacing,
    };
}

fn htmlTableCellRect(label: []const u8, layout: NodeLayout, port: []const u8) ?RectF {
    const grid = htmlTableGrid(label, layout) orelse return null;
    var row_pos: usize = 0;
    var row_index: usize = 0;
    var occupied: [32]usize = @splat(0);
    while (findHtmlTag(label, "tr", row_pos)) |tr_start| : (row_index += 1) {
        if (row_index > 0) {
            for (&occupied) |*remaining| {
                if (remaining.* > 0) remaining.* -= 1;
            }
        }
        const tr_open_end = std.mem.indexOfScalar(u8, label[tr_start..], '>') orelse break;
        const content_start = tr_start + tr_open_end + 1;
        const tr_close = findHtmlCloseTag(label, "tr", content_start) orelse break;
        const row = label[content_start..tr_close];
        var cell_pos: usize = 0;
        var col_index: usize = 0;
        while (findHtmlTag(row, "td", cell_pos)) |td_start| : (col_index += 1) {
            col_index = nextFreeHtmlColumn(&occupied, col_index);
            const td_open_end = std.mem.indexOfScalar(u8, row[td_start..], '>') orelse break;
            const td_tag = row[td_start + 1 .. td_start + td_open_end];
            const cell_start = td_start + td_open_end + 1;
            const td_close = findHtmlCloseTag(row, "td", cell_start) orelse break;
            const colspan = @max(htmlIntAttr(td_tag, "colspan", 1), 1);
            const rowspan = @max(htmlIntAttr(td_tag, "rowspan", 1), 1);
            const rect = htmlGridCellRect(grid, row_index, col_index, rowspan, colspan);
            var span_i: usize = 0;
            while (span_i < colspan and col_index + span_i < occupied.len) : (span_i += 1) {
                occupied[col_index + span_i] = @max(occupied[col_index + span_i], rowspan);
            }
            if (htmlAttrValue(td_tag, "port")) |cell_port| {
                if (std.mem.eql(u8, cell_port, port)) return rect;
            }
            cell_pos = td_close + 1;
            col_index += colspan - 1;
        }
        row_pos = tr_close + 1;
    }
    return null;
}

fn htmlGridCellRect(grid: HtmlTableGrid, row_index: usize, col_index: usize, rowspan: usize, colspan: usize) RectF {
    var x = grid.x + grid.cell_spacing;
    var col: usize = 0;
    while (col < col_index and col < grid.col_widths.len) : (col += 1) {
        x += grid.col_widths[col] + grid.cell_spacing;
    }
    var y = grid.y + grid.cell_spacing;
    var row: usize = 0;
    while (row < row_index and row < grid.row_heights.len) : (row += 1) {
        y += grid.row_heights[row] + grid.cell_spacing;
    }
    var width: f64 = 0;
    var span_col: usize = 0;
    while (span_col < colspan and col_index + span_col < grid.col_widths.len) : (span_col += 1) {
        if (span_col > 0) width += grid.cell_spacing;
        width += grid.col_widths[col_index + span_col];
    }
    var height: f64 = 0;
    var span_row: usize = 0;
    while (span_row < rowspan and row_index + span_row < grid.row_heights.len) : (span_row += 1) {
        if (span_row > 0) height += grid.cell_spacing;
        height += grid.row_heights[row_index + span_row];
    }
    return .{
        .x = x,
        .y = y,
        .width = @max(1, width),
        .height = @max(1, height),
    };
}

fn applyHtmlCellSizeHints(tag: []const u8, row_index: usize, col_index: usize, rowspan: usize, colspan: usize, row_heights: *[32]f64, col_widths: *[32]f64) void {
    if (htmlAttrFloat(tag, "width")) |width| {
        const per_col = width / @as(f64, @floatFromInt(@max(colspan, 1)));
        var i: usize = 0;
        while (i < colspan and col_index + i < col_widths.len) : (i += 1) {
            col_widths[col_index + i] = @max(col_widths[col_index + i], per_col);
        }
    }
    if (htmlAttrFloat(tag, "height")) |height| {
        const per_row = height / @as(f64, @floatFromInt(@max(rowspan, 1)));
        var i: usize = 0;
        while (i < rowspan and row_index + i < row_heights.len) : (i += 1) {
            row_heights[row_index + i] = @max(row_heights[row_index + i], per_row);
        }
    }
}

fn distributeHtmlGridSizes(values: []f64, target_total: f64) void {
    if (values.len == 0) return;
    var used: f64 = 0;
    var flexible: usize = 0;
    for (values) |value| {
        if (value > 0) {
            used += value;
        } else {
            flexible += 1;
        }
    }
    const remaining = @max(0, target_total - used);
    const fallback = if (flexible > 0)
        remaining / @as(f64, @floatFromInt(flexible))
    else if (used < target_total)
        (target_total - used) / @as(f64, @floatFromInt(values.len))
    else
        0;
    for (values) |*value| {
        if (value.* > 0) {
            if (flexible == 0 and fallback > 0) value.* += fallback;
        } else {
            value.* = @max(1, fallback);
        }
    }
}

const HtmlCellSides = struct {
    left: bool = false,
    top: bool = false,
    right: bool = false,
    bottom: bool = false,

    fn any(self: HtmlCellSides) bool {
        return self.left or self.top or self.right or self.bottom;
    }
};

fn htmlCellSides(tag: []const u8) ?HtmlCellSides {
    const value = htmlAttrValue(tag, "sides") orelse return null;
    var result = HtmlCellSides{};
    for (value) |c| {
        switch (std.ascii.toLower(c)) {
            'l' => result.left = true,
            't' => result.top = true,
            'r' => result.right = true,
            'b' => result.bottom = true,
            else => {},
        }
    }
    return if (result.any()) result else null;
}

fn htmlTableOpenTag(label: []const u8) ?[]const u8 {
    const table_start = findHtmlTag(label, "table", 0) orelse return null;
    const table_open_end = std.mem.indexOfScalar(u8, label[table_start..], '>') orelse return null;
    return label[table_start + 1 .. table_start + table_open_end];
}

fn htmlStyleHas(tag: []const u8, needle: []const u8) bool {
    const style = htmlAttrValue(tag, "style") orelse return false;
    var parts = std.mem.tokenizeAny(u8, style, ", ");
    while (parts.next()) |part| {
        if (std.ascii.eqlIgnoreCase(part, needle)) return true;
    }
    return false;
}

fn htmlDashStyle(tag: []const u8) DashStyle {
    if (htmlStyleHas(tag, "dotted")) return .dotted;
    if (htmlStyleHas(tag, "dashed")) return .dashed;
    return .none;
}

fn htmlIntAttr(tag: []const u8, name: []const u8, fallback: usize) usize {
    const value = htmlAttrValue(tag, name) orelse return fallback;
    return std.fmt.parseInt(usize, value, 10) catch fallback;
}

fn htmlAttrFloat(tag: []const u8, name: []const u8) ?f64 {
    const value = htmlAttrValue(tag, name) orelse return null;
    const parsed = std.fmt.parseFloat(f64, value) catch return null;
    return if (parsed > 0) parsed else null;
}

fn nextFreeHtmlColumn(occupied: *const [32]usize, start: usize) usize {
    var index = start;
    while (index < occupied.len and occupied[index] > 0) : (index += 1) {}
    return index;
}

fn htmlAttrValue(tag: []const u8, name: []const u8) ?[]const u8 {
    var index: usize = 0;
    while (index < tag.len) {
        while (index < tag.len and (std.ascii.isWhitespace(tag[index]) or tag[index] == '/')) : (index += 1) {}
        const key_start = index;
        while (index < tag.len and (std.ascii.isAlphanumeric(tag[index]) or tag[index] == '_' or tag[index] == '-')) : (index += 1) {}
        if (index == key_start) {
            index += 1;
            continue;
        }
        const key = tag[key_start..index];
        while (index < tag.len and std.ascii.isWhitespace(tag[index])) : (index += 1) {}
        if (index >= tag.len or tag[index] != '=') continue;
        index += 1;
        while (index < tag.len and std.ascii.isWhitespace(tag[index])) : (index += 1) {}
        if (index >= tag.len) break;
        const value = if (tag[index] == '"' or tag[index] == '\'') blk: {
            const quote = tag[index];
            index += 1;
            const value_start = index;
            while (index < tag.len and tag[index] != quote) : (index += 1) {}
            const result = tag[value_start..index];
            if (index < tag.len) index += 1;
            break :blk result;
        } else blk: {
            const value_start = index;
            while (index < tag.len and !std.ascii.isWhitespace(tag[index]) and tag[index] != '>') : (index += 1) {}
            break :blk tag[value_start..index];
        };
        if (std.ascii.eqlIgnoreCase(key, name)) return value;
    }
    return null;
}

fn findHtmlTag(text: []const u8, tag: []const u8, start: usize) ?usize {
    var index = start;
    while (index < text.len) {
        const rel = std.mem.indexOfScalar(u8, text[index..], '<') orelse return null;
        const open = index + rel;
        if (open + 1 < text.len and text[open + 1] == '/') {
            index = open + 1;
            continue;
        }
        const close_rel = std.mem.indexOfScalar(u8, text[open + 1 ..], '>') orelse return null;
        const name = htmlTagName(text[open + 1 .. open + 1 + close_rel]);
        if (std.ascii.eqlIgnoreCase(name, tag)) return open;
        index = open + 1;
    }
    return null;
}

fn findHtmlCloseTag(text: []const u8, tag: []const u8, start: usize) ?usize {
    var index = start;
    while (index < text.len) {
        const rel = std.mem.indexOf(u8, text[index..], "</") orelse return null;
        const open = index + rel;
        const close_rel = std.mem.indexOfScalar(u8, text[open + 2 ..], '>') orelse return null;
        const name = htmlTagName(text[open + 2 .. open + 2 + close_rel]);
        if (std.ascii.eqlIgnoreCase(name, tag)) return open;
        index = open + 2;
    }
    return null;
}

const RecordMetrics = struct {
    field_count: usize,
    max_field_len: usize,
};

fn recordMetrics(label: []const u8) RecordMetrics {
    var arena = RecordArena{};
    var parser = RecordParser{ .label = label, .arena = &arena };
    const root = parser.parseRecord(.horizontal) orelse return .{ .field_count = 1, .max_field_len = labelMaxLineLen(label) };
    return .{ .field_count = recordLeafCount(root), .max_field_len = recordMaxFieldLen(root) };
}

const RecordOrientation = enum {
    horizontal,
    vertical,

    fn flipped(self: RecordOrientation) RecordOrientation {
        return switch (self) {
            .horizontal => .vertical,
            .vertical => .horizontal,
        };
    }
};

const RecordAst = struct {
    label: []const u8 = "",
    port: ?[]const u8 = null,
    children: []const RecordAst = &.{},
    orientation: RecordOrientation = .horizontal,
    width_units: f64 = 1,
    height_units: f64 = 1,

    fn isLeaf(self: RecordAst) bool {
        return self.children.len == 0;
    }
};

const RecordArena = struct {
    nodes: [96]RecordAst = undefined,
    node_len: usize = 0,
    child_storage: [96]RecordAst = undefined,
    child_len: usize = 0,

    fn createNode(self: *RecordArena, node: RecordAst) ?*RecordAst {
        if (self.node_len >= self.nodes.len) return null;
        self.nodes[self.node_len] = node;
        const ptr = &self.nodes[self.node_len];
        self.node_len += 1;
        return ptr;
    }

    fn copyChildren(self: *RecordArena, children: []const RecordAst) ?[]const RecordAst {
        if (children.len == 0) return &.{};
        if (self.child_len + children.len > self.child_storage.len) return null;
        const start = self.child_len;
        for (children) |child| {
            self.child_storage[self.child_len] = child;
            self.child_len += 1;
        }
        return self.child_storage[start..self.child_len];
    }
};

const RecordParser = struct {
    label: []const u8,
    index: usize = 0,
    arena: *RecordArena,

    fn current(self: *const RecordParser) ?u8 {
        if (self.index >= self.label.len) return null;
        return self.label[self.index];
    }

    fn skipSpaces(self: *RecordParser) void {
        while (self.index < self.label.len and (self.label[self.index] == ' ' or self.label[self.index] == '\t')) self.index += 1;
    }

    fn parseRecord(self: *RecordParser, orientation: RecordOrientation) ?RecordAst {
        var tmp: [32]RecordAst = undefined;
        var count: usize = 0;
        while (self.index < self.label.len) {
            self.skipSpaces();
            if (self.current() == '}') break;
            if (count >= tmp.len) return null;
            tmp[count] = self.parseField(orientation.flipped()) orelse return null;
            count += 1;
            self.skipSpaces();
            if (self.current() == '|') {
                self.index += 1;
                continue;
            }
            break;
        }
        if (count == 0) return .{ .label = "" };
        const children = self.arena.copyChildren(tmp[0..count]) orelse return null;
        var node = RecordAst{ .children = children, .orientation = orientation };
        computeRecordUnits(&node);
        return node;
    }

    fn parseField(self: *RecordParser, nested_orientation: RecordOrientation) ?RecordAst {
        self.skipSpaces();
        if (self.current() == '{') {
            self.index += 1;
            var nested = self.parseRecord(nested_orientation) orelse return null;
            self.skipSpaces();
            if (self.current() == '}') self.index += 1;
            nested.orientation = nested_orientation;
            computeRecordUnits(&nested);
            return nested;
        }

        const start = self.index;
        while (self.index < self.label.len) {
            const c = self.label[self.index];
            if (c == '\\' and self.index + 1 < self.label.len) {
                self.index += 2;
                continue;
            }
            if (c == '|' or c == '}') break;
            self.index += 1;
        }
        const raw = std.mem.trim(u8, self.label[start..self.index], " \t\r\n");
        const parts = splitRecordPort(raw);
        var node = RecordAst{ .label = parts.label, .port = parts.port };
        computeRecordUnits(&node);
        return node;
    }
};

fn computeRecordUnits(node: *RecordAst) void {
    if (node.children.len == 0) {
        node.width_units = @max(1, @as(f64, @floatFromInt(labelMaxLineLen(node.label))));
        node.height_units = @max(1, @as(f64, @floatFromInt(labelLineCount(node.label))));
        return;
    }

    var width: f64 = 0;
    var height: f64 = 0;
    switch (node.orientation) {
        .horizontal => {
            for (node.children) |child| {
                width += child.width_units;
                height = @max(height, child.height_units);
            }
        },
        .vertical => {
            for (node.children) |child| {
                width = @max(width, child.width_units);
                height += child.height_units;
            }
        },
    }
    node.width_units = @max(width, 1);
    node.height_units = @max(height, 1);
}

const RecordLabelParts = struct {
    label: []const u8,
    port: ?[]const u8,
};

fn splitRecordPort(raw: []const u8) RecordLabelParts {
    if (raw.len == 0 or raw[0] != '<') return .{ .label = raw, .port = null };
    const close = std.mem.indexOfScalar(u8, raw, '>') orelse return .{ .label = raw, .port = null };
    const port = raw[1..close];
    const label = std.mem.trim(u8, raw[close + 1 ..], " \t\r\n");
    return .{ .label = label, .port = if (port.len > 0) port else null };
}

fn recordLeafCount(node: RecordAst) usize {
    if (node.children.len == 0) return 1;
    var count: usize = 0;
    for (node.children) |child| count += recordLeafCount(child);
    return count;
}

fn recordMaxFieldLen(node: RecordAst) usize {
    if (node.children.len == 0) return @max(labelMaxLineLen(node.label), 1);
    var max_len: usize = 1;
    for (node.children) |child| max_len = @max(max_len, recordMaxFieldLen(child));
    return max_len;
}

fn reduceLayerCrossings(allocator: std.mem.Allocator, graph: *const Graph, levels: []std.ArrayList(NodeId), ranks: []const usize, passes: usize) !void {
    if (levels.len <= 1 or passes == 0) return;

    const positions = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(positions);
    const median_positions = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(median_positions);

    for (0..passes) |_| {
        var rank: usize = 1;
        while (rank < levels.len) : (rank += 1) {
            buildPositionMap(positions, levels[rank - 1].items);
            try orderLevelByMedianGuarded(allocator, graph, ranks, levels, rank, positions, median_positions, true);
        }

        rank = levels.len - 1;
        while (rank > 0) : (rank -= 1) {
            buildPositionMap(positions, levels[rank].items);
            try orderLevelByMedianGuarded(allocator, graph, ranks, levels, rank - 1, positions, median_positions, false);
        }
    }
}

fn buildPositionMap(positions: []usize, level: []const NodeId) void {
    @memset(positions, std.math.maxInt(usize));
    for (level, 0..) |id, pos| positions[id] = pos;
}

const MedianOrder = struct {
    id: NodeId,
    median: f64,
    original: usize,
};

fn orderLevelByMedian(
    graph: *const Graph,
    ranks: []const usize,
    level: *std.ArrayList(NodeId),
    adjacent_positions: []const usize,
    median_positions: []usize,
    use_parents: bool,
) void {
    if (level.items.len <= 1) return;

    var orders_buf: [128]MedianOrder = undefined;
    if (level.items.len > orders_buf.len) {
        orderLevelByMedianSlow(graph, ranks, level, adjacent_positions, median_positions, use_parents) catch return;
        return;
    }

    const orders = orders_buf[0..level.items.len];
    fillMedianOrders(graph, ranks, level.items, adjacent_positions, median_positions, use_parents, orders);
    std.mem.sort(MedianOrder, orders, {}, lessThanMedianOrder);
    for (orders, 0..) |order, i| level.items[i] = order.id;
}

fn orderLevelByMedianSlow(
    graph: *const Graph,
    ranks: []const usize,
    level: *std.ArrayList(NodeId),
    adjacent_positions: []const usize,
    median_positions: []usize,
    use_parents: bool,
) !void {
    const orders = try graph.allocator.alloc(MedianOrder, level.items.len);
    defer graph.allocator.free(orders);
    fillMedianOrders(graph, ranks, level.items, adjacent_positions, median_positions, use_parents, orders);
    std.mem.sort(MedianOrder, orders, {}, lessThanMedianOrder);
    for (orders, 0..) |order, i| level.items[i] = order.id;
}

fn orderLevelByMedianGuarded(
    allocator: std.mem.Allocator,
    graph: *const Graph,
    ranks: []const usize,
    levels: []std.ArrayList(NodeId),
    rank: usize,
    adjacent_positions: []const usize,
    median_positions: []usize,
    use_parents: bool,
) !void {
    if (rank >= levels.len or levels[rank].items.len <= 1) return;
    const before = totalLayerCrossings(graph, levels, ranks);
    const backup = try allocator.dupe(NodeId, levels[rank].items);
    defer allocator.free(backup);
    orderLevelByMedian(graph, ranks, &levels[rank], adjacent_positions, median_positions, use_parents);
    const after = totalLayerCrossings(graph, levels, ranks);
    if (after > before) @memcpy(levels[rank].items, backup);
}

fn fillMedianOrders(
    graph: *const Graph,
    ranks: []const usize,
    level_nodes: []const NodeId,
    adjacent_positions: []const usize,
    median_positions: []usize,
    use_parents: bool,
    orders: []MedianOrder,
) void {
    for (level_nodes, 0..) |node_id, original| {
        var count: usize = 0;
        for (graph.edges.items) |edge_item| {
            const neighbor = if (use_parents and edge_item.to == node_id and ranks[edge_item.from] < ranks[node_id])
                edge_item.from
            else if (!use_parents and edge_item.from == node_id and ranks[edge_item.to] > ranks[node_id])
                edge_item.to
            else
                continue;

            const pos = adjacent_positions[neighbor];
            if (pos != std.math.maxInt(usize)) {
                const repeat = edgeWeightRepeat(edge_item.weight);
                var i: usize = 0;
                while (i < repeat and count < median_positions.len) : (i += 1) {
                    median_positions[count] = pos;
                    count += 1;
                }
            }
        }

        orders[original] = .{
            .id = node_id,
            .median = medianOfPositions(median_positions[0..count], original),
            .original = original,
        };
    }
}

fn lessThanMedianOrder(_: void, a: MedianOrder, b: MedianOrder) bool {
    if (a.median == b.median) return a.original < b.original;
    return a.median < b.median;
}

fn lessThanUsize(_: void, a: usize, b: usize) bool {
    return a < b;
}

fn medianOfPositions(positions: []usize, fallback: usize) f64 {
    if (positions.len == 0) return @floatFromInt(fallback);
    std.mem.sort(usize, positions, {}, lessThanUsize);
    if (positions.len % 2 == 1) return @floatFromInt(positions[positions.len / 2]);
    const mid = positions.len / 2;
    return (@as(f64, @floatFromInt(positions[mid - 1])) + @as(f64, @floatFromInt(positions[mid]))) / 2.0;
}

fn edgeWeightRepeat(weight: f64) usize {
    if (weight <= 1.0) return 1;
    return @min(12, @max(1, @as(usize, @intFromFloat(@round(weight)))));
}

fn refineAdjacentExchanges(graph: *const Graph, levels: []std.ArrayList(NodeId), ranks: []const usize, passes: usize) void {
    if (levels.len < 2 or passes == 0) return;
    for (0..passes) |_| {
        var changed = false;
        for (0..levels.len) |rank| {
            if (levels[rank].items.len < 2 or levels[rank].items.len > 24) continue;
            var i: usize = 0;
            while (i + 1 < levels[rank].items.len) {
                const pair_before = adjacentPairCrossings(graph, levels, ranks, rank, i, i + 1);
                const pair_after = adjacentPairCrossings(graph, levels, ranks, rank, i + 1, i);
                const before = crossingScoreAroundLevel(graph, levels, ranks, rank);
                std.mem.swap(NodeId, &levels[rank].items[i], &levels[rank].items[i + 1]);
                const after = crossingScoreAroundLevel(graph, levels, ranks, rank);
                if (after < before or (after == before and pair_after < pair_before)) {
                    changed = true;
                    if (i > 0) {
                        i -= 1;
                    } else {
                        i += 1;
                    }
                } else {
                    std.mem.swap(NodeId, &levels[rank].items[i], &levels[rank].items[i + 1]);
                    i += 1;
                }
            }
        }
        if (!changed) break;
    }
}

fn adjacentPairCrossings(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, rank: usize, left_index: usize, right_index: usize) usize {
    if (rank >= levels.len) return 0;
    const level = levels[rank].items;
    if (left_index >= level.len or right_index >= level.len) return 0;
    const left = level[left_index];
    const right = level[right_index];
    var crossings: usize = 0;
    if (rank > 0) crossings += adjacentPairCrossingsWithFixedLayer(graph, levels[rank - 1].items, ranks, left, right, true);
    if (rank + 1 < levels.len) crossings += adjacentPairCrossingsWithFixedLayer(graph, levels[rank + 1].items, ranks, left, right, false);
    return crossings;
}

fn adjacentPairCrossingsWithFixedLayer(graph: *const Graph, fixed_layer: []const NodeId, ranks: []const usize, left: NodeId, right: NodeId, use_parents: bool) usize {
    var crossings: usize = 0;
    for (fixed_layer, 0..) |left_neighbor, left_pos| {
        if (!nodesAdjacentAcrossLayer(graph, ranks, left, left_neighbor, use_parents)) continue;
        for (fixed_layer, 0..) |right_neighbor, right_pos| {
            if (!nodesAdjacentAcrossLayer(graph, ranks, right, right_neighbor, use_parents)) continue;
            if (left_pos > right_pos) crossings += 1;
        }
    }
    return crossings;
}

fn nodesAdjacentAcrossLayer(graph: *const Graph, ranks: []const usize, node_id: NodeId, neighbor_id: NodeId, use_parents: bool) bool {
    if (node_id >= ranks.len or neighbor_id >= ranks.len) return false;
    for (graph.edges.items) |edge_item| {
        if (use_parents) {
            if (edge_item.from == neighbor_id and edge_item.to == node_id and ranks[edge_item.from] + 1 == ranks[edge_item.to]) return true;
        } else {
            if (edge_item.from == node_id and edge_item.to == neighbor_id and ranks[edge_item.from] + 1 == ranks[edge_item.to]) return true;
        }
    }
    return false;
}

fn crossingScoreAroundLevel(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, rank: usize) usize {
    var score: usize = 0;
    if (rank > 0) score += countLayerCrossingsWithDummies(graph, levels, ranks, rank - 1);
    if (rank + 1 < levels.len) score += countLayerCrossingsWithDummies(graph, levels, ranks, rank);
    return score;
}

fn totalLayerCrossings(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize) usize {
    var total: usize = 0;
    if (levels.len < 2) return 0;
    for (0..levels.len - 1) |rank| total += countLayerCrossingsWithDummies(graph, levels, ranks, rank);
    return total;
}

fn countLayerCrossings(graph: *const Graph, upper: []const NodeId, lower: []const NodeId, ranks: []const usize) usize {
    var crossings: usize = 0;
    for (graph.edges.items, 0..) |a, ai| {
        if (!edgeConnectsLayers(a, upper, lower, ranks)) continue;
        const a_up = positionInLayer(upper, a.from) orelse continue;
        const a_down = positionInLayer(lower, a.to) orelse continue;
        for (graph.edges.items[ai + 1 ..]) |b| {
            if (!edgeConnectsLayers(b, upper, lower, ranks)) continue;
            const b_up = positionInLayer(upper, b.from) orelse continue;
            const b_down = positionInLayer(lower, b.to) orelse continue;
            if ((a_up < b_up and a_down > b_down) or (a_up > b_up and a_down < b_down)) crossings += 1;
        }
    }
    return crossings;
}

const LayerSegment = struct {
    upper: f64,
    lower: f64,
};

fn countLayerCrossingsWithDummies(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, upper_rank: usize) usize {
    if (upper_rank + 1 >= levels.len) return 0;
    var crossings: usize = 0;
    for (graph.edges.items, 0..) |a, ai| {
        const a_segment = edgeVirtualSegment(a, levels, ranks, upper_rank) orelse continue;
        for (graph.edges.items[ai + 1 ..]) |b| {
            const b_segment = edgeVirtualSegment(b, levels, ranks, upper_rank) orelse continue;
            if ((a_segment.upper < b_segment.upper and a_segment.lower > b_segment.lower) or
                (a_segment.upper > b_segment.upper and a_segment.lower < b_segment.lower))
            {
                crossings += 1;
            }
        }
    }
    return crossings;
}

fn edgeVirtualSegment(edge_item: Edge, levels: []const std.ArrayList(NodeId), ranks: []const usize, upper_rank: usize) ?LayerSegment {
    if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) return null;
    const from_rank = ranks[edge_item.from];
    const to_rank = ranks[edge_item.to];
    if (from_rank >= to_rank) return null;
    if (upper_rank < from_rank or upper_rank + 1 > to_rank) return null;
    if (from_rank >= levels.len or to_rank >= levels.len) return null;
    const from_pos = positionInLayer(levels[from_rank].items, edge_item.from) orelse return null;
    const to_pos = positionInLayer(levels[to_rank].items, edge_item.to) orelse return null;
    const span = @as(f64, @floatFromInt(to_rank - from_rank));
    const upper_t = @as(f64, @floatFromInt(upper_rank - from_rank)) / span;
    const lower_t = @as(f64, @floatFromInt(upper_rank + 1 - from_rank)) / span;
    const from_f: f64 = @floatFromInt(from_pos);
    const to_f: f64 = @floatFromInt(to_pos);
    return .{
        .upper = from_f + (to_f - from_f) * upper_t,
        .lower = from_f + (to_f - from_f) * lower_t,
    };
}

fn edgeConnectsLayers(edge_item: Edge, upper: []const NodeId, lower: []const NodeId, ranks: []const usize) bool {
    if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) return false;
    if (ranks[edge_item.from] >= ranks[edge_item.to]) return false;
    return containsNode(upper, edge_item.from) and containsNode(lower, edge_item.to);
}

fn positionInLayer(layer: []const NodeId, id: NodeId) ?usize {
    for (layer, 0..) |node_id, index| {
        if (node_id == id) return index;
    }
    return null;
}

fn enforceClusterContiguity(graph: *const Graph, levels: []std.ArrayList(NodeId)) void {
    for (graph.clusters.items) |cluster| {
        for (levels) |*level| {
            if (level.items.len < 3 or level.items.len > 256) continue;
            const first = firstClusterMemberIndex(cluster, level.items) orelse continue;
            var member_count: usize = 0;
            for (level.items) |node_id| {
                if (containsNode(cluster.nodes, node_id)) member_count += 1;
            }
            if (member_count < 2) continue;

            var reordered: [256]NodeId = undefined;
            var out: usize = 0;
            for (level.items[0..first]) |node_id| {
                reordered[out] = node_id;
                out += 1;
            }
            for (level.items[first..]) |node_id| {
                if (containsNode(cluster.nodes, node_id)) {
                    reordered[out] = node_id;
                    out += 1;
                }
            }
            for (level.items[first..]) |node_id| {
                if (!containsNode(cluster.nodes, node_id)) {
                    reordered[out] = node_id;
                    out += 1;
                }
            }
            @memcpy(level.items, reordered[0..level.items.len]);
        }
    }
}

fn firstClusterMemberIndex(cluster: Cluster, nodes: []const NodeId) ?usize {
    for (nodes, 0..) |node_id, index| {
        if (containsNode(cluster.nodes, node_id)) return index;
    }
    return null;
}

const OrderingMode = enum {
    none,
    in,
    out,
};

fn applyOrderingHints(graph: *const Graph, levels: []std.ArrayList(NodeId), ranks: []const usize) void {
    const graph_mode = orderingMode(attrValue(graph.attrs.items, "ordering"));
    for (graph.nodes.items) |node_item| {
        const mode = if (graph_mode != .none) graph_mode else orderingMode(attrValue(node_item.attrs.items, "ordering"));
        switch (mode) {
            .none => {},
            .out => applyNodeOrdering(graph, levels, ranks, node_item.id, true),
            .in => applyNodeOrdering(graph, levels, ranks, node_item.id, false),
        }
    }
}

fn orderingMode(value: ?[]const u8) OrderingMode {
    const text = value orelse return .none;
    if (std.ascii.eqlIgnoreCase(text, "out")) return .out;
    if (std.ascii.eqlIgnoreCase(text, "in")) return .in;
    return .none;
}

fn applyNodeOrdering(graph: *const Graph, levels: []std.ArrayList(NodeId), ranks: []const usize, node_id: NodeId, out_order: bool) void {
    var ordered: [64]NodeId = undefined;
    var count: usize = 0;
    for (graph.edges.items) |edge_item| {
        const neighbor = if (out_order and edge_item.from == node_id)
            edge_item.to
        else if (!out_order and edge_item.to == node_id)
            edge_item.from
        else
            continue;
        if (neighbor >= ranks.len or count >= ordered.len) continue;
        ordered[count] = neighbor;
        count += 1;
    }
    if (count <= 1) return;

    var rank: usize = 0;
    while (rank < levels.len) : (rank += 1) {
        var present: [64]NodeId = undefined;
        var present_count: usize = 0;
        for (ordered[0..count]) |neighbor| {
            if (ranks[neighbor] != rank) continue;
            if (positionInLayer(levels[rank].items, neighbor) == null) continue;
            present[present_count] = neighbor;
            present_count += 1;
        }
        if (present_count <= 1) continue;
        reorderLayerBySequence(levels[rank].items, present[0..present_count]);
    }
}

fn reorderLayerBySequence(level: []NodeId, sequence: []const NodeId) void {
    var insert_at = level.len;
    for (sequence) |id| {
        if (positionInLayer(level, id)) |pos| insert_at = @min(insert_at, pos);
    }
    if (insert_at == level.len) return;
    for (sequence) |id| {
        const current = positionInLayer(level, id) orelse continue;
        moveLevelItem(level, current, insert_at);
        insert_at += 1;
    }
}

const GroupOrder = struct {
    name: []const u8,
    rank_sum: f64 = 0,
    count: usize = 0,
};

fn alignGroupedNodes(graph: *const Graph, levels: []std.ArrayList(NodeId)) void {
    var groups: [64]GroupOrder = undefined;
    var group_count: usize = 0;
    for (levels) |level| {
        for (level.items, 0..) |node_id, index| {
            const group_name = nodeGroupName(graph.nodes.items[node_id]) orelse continue;
            const group_index = groupOrderIndex(groups[0..group_count], group_name) orelse blk: {
                if (group_count >= groups.len) continue;
                groups[group_count] = .{ .name = group_name };
                group_count += 1;
                break :blk group_count - 1;
            };
            groups[group_index].rank_sum += @floatFromInt(index);
            groups[group_index].count += 1;
        }
    }

    for (groups[0..group_count]) |group| {
        if (group.count < 2) continue;
        const target_float = group.rank_sum / @as(f64, @floatFromInt(group.count));
        for (levels) |*level| {
            const current = groupedNodeIndex(graph, level.items, group.name) orelse continue;
            const target = @min(level.items.len - 1, @as(usize, @intFromFloat(@round(target_float))));
            moveLevelItem(level.items, current, target);
        }
    }
}

fn nodeGroupName(node_item: Node) ?[]const u8 {
    const value = attrValue(node_item.attrs.items, "group") orelse return null;
    return if (value.len == 0) null else value;
}

fn groupOrderIndex(groups: []const GroupOrder, name: []const u8) ?usize {
    for (groups, 0..) |group, index| {
        if (std.mem.eql(u8, group.name, name)) return index;
    }
    return null;
}

fn groupedNodeIndex(graph: *const Graph, nodes: []const NodeId, group_name: []const u8) ?usize {
    for (nodes, 0..) |node_id, index| {
        const name = nodeGroupName(graph.nodes.items[node_id]) orelse continue;
        if (std.mem.eql(u8, name, group_name)) return index;
    }
    return null;
}

fn moveLevelItem(nodes: []NodeId, from: usize, to: usize) void {
    if (from == to or nodes.len <= 1) return;
    const id = nodes[from];
    if (from < to) {
        var i = from;
        while (i < to) : (i += 1) nodes[i] = nodes[i + 1];
    } else {
        var i = from;
        while (i > to) : (i -= 1) nodes[i] = nodes[i - 1];
    }
    nodes[to] = id;
}

fn alignGroupedCenters(graph: *const Graph, levels: []const std.ArrayList(NodeId), centers: []f64, sizes: []const NodeSize, gap: f64) void {
    var groups: [64]GroupOrder = undefined;
    var group_count: usize = 0;
    for (graph.nodes.items, 0..) |node_item, id| {
        const group_name = nodeGroupName(node_item) orelse continue;
        const group_index = groupOrderIndex(groups[0..group_count], group_name) orelse blk: {
            if (group_count >= groups.len) continue;
            groups[group_count] = .{ .name = group_name };
            group_count += 1;
            break :blk group_count - 1;
        };
        groups[group_index].rank_sum += centers[id];
        groups[group_index].count += 1;
    }

    for (groups[0..group_count]) |group| {
        if (group.count < 2) continue;
        const target = group.rank_sum / @as(f64, @floatFromInt(group.count));
        for (graph.nodes.items, 0..) |node_item, id| {
            const group_name = nodeGroupName(node_item) orelse continue;
            if (std.mem.eql(u8, group_name, group.name)) centers[id] = target;
        }
    }
    for (levels) |level| compactLevelCenters(level.items, centers, sizes, gap);
}

fn applyInterClusterSpacing(graph: *const Graph, levels: []const std.ArrayList(NodeId), centers: []f64, sizes: []const NodeSize, cluster_gap: f64) void {
    if (cluster_gap <= 0 or graph.clusters.items.len == 0) return;
    const cluster_pad_x: f64 = 12.0;
    for (levels) |level| {
        if (level.items.len <= 1) continue;
        var constraints: [128]CoordConstraint = undefined;
        var constraint_count: usize = 0;
        var i: usize = 1;
        while (i < level.items.len) : (i += 1) {
            const left = level.items[i - 1];
            const right = level.items[i];
            const left_cluster = clusterIndexContainingNode(graph, left);
            const right_cluster = clusterIndexContainingNode(graph, right);
            if (left_cluster == null and right_cluster == null) continue;
            if (left_cluster != null and right_cluster != null and left_cluster.? == right_cluster.?) continue;
            const left_pad = if (left_cluster != null) cluster_pad_x else 0.0;
            const right_pad = if (right_cluster != null) cluster_pad_x else 0.0;
            if (constraint_count >= constraints.len) {
                applyInterClusterSpacingFallback(graph, level.items, centers, sizes, cluster_gap, cluster_pad_x);
                return;
            }
            constraints[constraint_count] = .{
                .left = left,
                .right = right,
                .min_gap = sizes[left].width / 2.0 + left_pad + cluster_gap + right_pad + sizes[right].width / 2.0,
            };
            constraint_count += 1;
        }
        _ = satisfyCoordConstraints(centers, constraints[0..constraint_count]);
    }
}

fn applyInterClusterSpacingFallback(graph: *const Graph, level: []const NodeId, centers: []f64, sizes: []const NodeSize, cluster_gap: f64, cluster_pad_x: f64) void {
    var i: usize = 1;
    while (i < level.len) : (i += 1) {
        const left = level[i - 1];
        const right = level[i];
        const left_cluster = clusterIndexContainingNode(graph, left);
        const right_cluster = clusterIndexContainingNode(graph, right);
        if (left_cluster == null and right_cluster == null) continue;
        if (left_cluster != null and right_cluster != null and left_cluster.? == right_cluster.?) continue;
        const left_pad = if (left_cluster != null) cluster_pad_x else 0.0;
        const right_pad = if (right_cluster != null) cluster_pad_x else 0.0;
        const min_center = centers[left] + sizes[left].width / 2.0 + left_pad + cluster_gap + right_pad + sizes[right].width / 2.0;
        if (centers[right] < min_center) {
            const delta = min_center - centers[right];
            var j = i;
            while (j < level.len) : (j += 1) centers[level[j]] += delta;
        }
    }
}

fn applyInterClusterSpacingWithBudget(graph: *const Graph, levels: []const std.ArrayList(NodeId), centers: []f64, sizes: []const NodeSize, cluster_gap: f64, max_extent: f64) void {
    if (max_extent <= 0) return;
    const before_extent = centersExtent(centers, sizes);
    if (before_extent >= max_extent) return;
    var backup: [256]f64 = undefined;
    if (centers.len > backup.len) return;
    @memcpy(backup[0..centers.len], centers);
    applyInterClusterSpacing(graph, levels, centers, sizes, cluster_gap);
    if (centersExtent(centers, sizes) > max_extent + 0.0001) {
        @memcpy(centers, backup[0..centers.len]);
    }
}

fn centersExtent(centers: []const f64, sizes: []const NodeSize) f64 {
    var extent: f64 = 0;
    for (centers, 0..) |center, id| {
        if (id >= sizes.len) continue;
        extent = @max(extent, center + sizes[id].width / 2.0);
    }
    return extent;
}

fn shiftCentersRightWithinBudget(centers: []f64, sizes: []const NodeSize, desired_shift: f64, max_extent: f64) void {
    if (desired_shift <= 0 or max_extent <= 0) return;
    const extent = centersExtent(centers, sizes);
    if (extent >= max_extent) return;
    const shift = @min(desired_shift, max_extent - extent);
    for (centers) |*center| center.* += shift;
}

fn applyCrossClusterDiagonalNudges(graph: *const Graph, ranks: []const usize, centers: []f64, sizes: []const NodeSize, max_extent: f64) void {
    if (graph.clusters.items.len == 0 or max_extent <= 0) return;
    const full_shift: f64 = 1.0;
    for (graph.edges.items) |edge_item| {
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        if (edge_item.from >= centers.len or edge_item.to >= centers.len) continue;
        if (ranks[edge_item.from] + 1 != ranks[edge_item.to]) continue;
        const from_cluster = clusterIndexContainingNode(graph, edge_item.from) orelse continue;
        const to_cluster = clusterIndexContainingNode(graph, edge_item.to) orelse continue;
        if (from_cluster == to_cluster) continue;
        if (centers[edge_item.from] <= centers[edge_item.to]) continue;

        const available = @max(0.0, max_extent - centersExtent(centers, sizes));
        const shift = @min(full_shift, available);
        if (shift <= 0) return;
        centers[edge_item.from] += shift;
        nudgeSameClusterPredecessors(graph, ranks, centers, edge_item.from, from_cluster, shift * 0.4);
    }
}

fn nudgeSameClusterPredecessors(graph: *const Graph, ranks: []const usize, centers: []f64, node_id: NodeId, cluster_index: usize, shift: f64) void {
    if (node_id >= ranks.len or shift <= 0) return;
    const rank = ranks[node_id];
    for (graph.edges.items) |edge_item| {
        if (edge_item.to != node_id or edge_item.from >= ranks.len or edge_item.from >= centers.len) continue;
        if (ranks[edge_item.from] + 1 != rank) continue;
        if ((clusterIndexContainingNode(graph, edge_item.from) orelse continue) != cluster_index) continue;
        centers[edge_item.from] += shift;
    }
}

fn applyBackEdgeChannelCenterConstraints(graph: *const Graph, ranks: []const usize, centers: []f64, sizes: []const NodeSize, max_extent: f64) void {
    if (graph.clusters.items.len == 0 or max_extent <= 0) return;
    const side_gap: f64 = 28.0;
    const min_clearance: f64 = 31.0;
    var constraints: [64]GroupShiftConstraint = undefined;
    var constraint_count: usize = 0;
    for (graph.edges.items) |edge_item| {
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        if (edge_item.from >= centers.len or edge_item.to >= centers.len) continue;
        if (ranks[edge_item.to] >= ranks[edge_item.from]) continue;
        const from_cluster = clusterIndexContainingNode(graph, edge_item.from) orelse continue;
        const to_cluster = clusterIndexContainingNode(graph, edge_item.to) orelse continue;
        if (from_cluster != to_cluster) continue;
        const from_left = centers[edge_item.from] - sizes[edge_item.from].width / 2.0;
        const to_left = centers[edge_item.to] - sizes[edge_item.to].width / 2.0;
        const overlap_width = sizes[edge_item.from].width / 2.0 + sizes[edge_item.to].width / 2.0;
        const prefer_negative = if (@abs(centers[edge_item.from] - centers[edge_item.to]) <= overlap_width + 2.0) true else centers[edge_item.from] <= centers[edge_item.to];
        if (!prefer_negative) continue;
        const side_along = @max(0.0, @min(from_left, to_left) - side_gap);
        const desired_center = side_along + min_clearance;
        const current_min = @min(centers[edge_item.from], centers[edge_item.to]);
        if (current_min >= desired_center) continue;
        if (constraint_count >= constraints.len) return;
        constraints[constraint_count] = .{
            .nodes = graph.clusters.items[from_cluster].nodes,
            .min_shift = desired_center - current_min,
        };
        constraint_count += 1;
    }
    _ = applyGroupShiftConstraints(centers, constraints[0..constraint_count], max_extent, sizes);
}

const CoordConstraint = struct {
    left: NodeId,
    right: NodeId,
    min_gap: f64,
};

const GroupShiftConstraint = struct {
    nodes: []const NodeId,
    min_shift: f64,
};

const ClusterContainment = struct {
    left: f64,
    right: f64,
};

fn solveClusterBoundary(cluster: Cluster, centers: []const f64, sizes: []const NodeSize, margin: f64) ?ClusterContainment {
    if (cluster.nodes.len == 0) return null;
    if (centers.len + 2 > 256 or cluster.nodes.len * 2 > 512) return null;
    var initial_left = std.math.floatMax(f64);
    for (cluster.nodes) |node_id| {
        if (node_id >= centers.len or node_id >= sizes.len) continue;
        initial_left = @min(initial_left, centers[node_id] - sizes[node_id].width / 2.0 - margin);
    }
    if (initial_left == std.math.floatMax(f64)) return null;
    const boundary_left = centers.len;
    const boundary_right = centers.len + 1;
    var vars_buf: [256]f64 = undefined;
    const vars = vars_buf[0 .. centers.len + 2];
    @memcpy(vars[0..centers.len], centers);
    vars[boundary_left] = initial_left;
    vars[boundary_right] = initial_left;

    var constraints_buf: [512]CoordConstraint = undefined;
    var constraint_count: usize = 0;
    for (cluster.nodes) |node_id| {
        if (node_id >= centers.len or node_id >= sizes.len) continue;
        constraints_buf[constraint_count] = .{
            .left = boundary_left,
            .right = node_id,
            .min_gap = sizes[node_id].width / 2.0 + margin,
        };
        constraint_count += 1;
        constraints_buf[constraint_count] = .{
            .left = node_id,
            .right = boundary_right,
            .min_gap = sizes[node_id].width / 2.0 + margin,
        };
        constraint_count += 1;
    }
    _ = satisfyCoordConstraints(vars, constraints_buf[0..constraint_count]);
    return .{ .left = vars[boundary_left], .right = vars[boundary_right] };
}

fn clusterContainmentEnvelope(cluster: Cluster, centers: []const f64, sizes: []const NodeSize, margin: f64) ?ClusterContainment {
    var left = std.math.floatMax(f64);
    var right: f64 = -std.math.floatMax(f64);
    var found = false;
    for (cluster.nodes) |node_id| {
        if (node_id >= centers.len or node_id >= sizes.len) continue;
        left = @min(left, centers[node_id] - sizes[node_id].width / 2.0 - margin);
        right = @max(right, centers[node_id] + sizes[node_id].width / 2.0 + margin);
        found = true;
    }
    if (!found) return null;
    return .{ .left = left, .right = right };
}

fn satisfyCoordConstraints(centers: []f64, constraints: []const CoordConstraint) bool {
    if (centers.len == 0) return true;
    var changed = false;
    var pass: usize = 0;
    while (pass < centers.len) : (pass += 1) {
        var pass_changed = false;
        for (constraints) |constraint| {
            if (constraint.left >= centers.len or constraint.right >= centers.len) continue;
            const min_right = centers[constraint.left] + constraint.min_gap;
            if (centers[constraint.right] + 0.0001 < min_right) {
                centers[constraint.right] = min_right;
                pass_changed = true;
                changed = true;
            }
        }
        if (!pass_changed) return changed;
    }
    return changed;
}

fn applyGroupShiftConstraints(centers: []f64, constraints: []const GroupShiftConstraint, max_extent: f64, sizes: []const NodeSize) bool {
    if (max_extent <= 0) return false;
    var changed = false;
    for (constraints) |constraint| {
        if (constraint.min_shift <= 0) continue;
        const shift = @min(constraint.min_shift, @max(0.0, max_extent - centersExtent(centers, sizes)));
        if (shift <= 0) continue;
        for (constraint.nodes) |node_id| {
            if (node_id < centers.len) centers[node_id] += shift;
        }
        changed = true;
    }
    return changed;
}

fn packLevelFromLeft(level: []const NodeId, sizes: []const NodeSize, gap: f64, centers: []f64) f64 {
    var left: f64 = 0;
    for (level) |id| {
        centers[id] = left + sizes[id].width / 2.0;
        left += sizes[id].width + gap;
    }
    return if (level.len == 0) 0 else left - gap;
}

fn refineLayerCoordinates(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, sizes: []const NodeSize, centers: []f64, options: LayoutOptions) void {
    if (levels.len <= 1 or options.coordinate_passes == 0) return;

    for (0..options.coordinate_passes) |_| {
        var rank: usize = 1;
        while (rank < levels.len) : (rank += 1) {
            nudgeLevelTowardNeighbors(graph, ranks, levels[rank].items, centers, true);
            compactLevelCenters(levels[rank].items, centers, sizes, options.node_gap);
        }

        rank = levels.len - 1;
        while (rank > 0) : (rank -= 1) {
            nudgeLevelTowardNeighbors(graph, ranks, levels[rank - 1].items, centers, false);
            centerLevelOnNeighborSpans(graph, ranks, levels[rank - 1].items, centers, sizes, false, 0.45);
            compactLevelCenters(levels[rank - 1].items, centers, sizes, options.node_gap);
        }
    }
}

fn centerLevelOnNeighborSpans(graph: *const Graph, ranks: []const usize, level: []const NodeId, centers: []f64, sizes: []const NodeSize, use_parents: bool, blend: f64) void {
    for (level) |node_id| {
        const target = neighborSpanCenter(graph, ranks, centers, sizes, node_id, use_parents) orelse continue;
        centers[node_id] = centers[node_id] + (target - centers[node_id]) * blend;
    }
}

fn alignLevelsToNeighborSpansIfHelpful(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, centers: []f64, sizes: []const NodeSize, gap: f64) void {
    if (levels.len <= 1) return;
    var rank = levels.len;
    while (rank > 0) {
        rank -= 1;
        alignLevelToNeighborSpansIfHelpful(graph, levels[rank].items, ranks, centers, sizes, gap, false);
    }
    rank = 0;
    while (rank < levels.len) : (rank += 1) {
        alignLevelToNeighborSpansIfHelpful(graph, levels[rank].items, ranks, centers, sizes, gap, true);
    }
}

fn alignBoundarySingletonsToIncidentSpan(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, centers: []f64, sizes: []const NodeSize) void {
    if (levels.len <= 1) return;
    for (levels) |level| {
        if (level.items.len != 1) continue;
        const node_id = level.items[0];
        if (clusterIndexContainingNode(graph, node_id) != null) continue;
        const target = incidentSpanCenter(graph, ranks, centers, sizes, node_id) orelse continue;
        centers[node_id] = target;
    }
}

fn graphHasExplicitEdgeWeight(graph: *const Graph) bool {
    for (graph.edge_default_attrs.items) |attr| {
        if (std.ascii.eqlIgnoreCase(attr.name, "weight")) return true;
    }
    for (graph.edges.items) |edge_item| {
        if (attrValue(edge_item.attrs.items, "weight") != null) return true;
    }
    return false;
}

fn alignLevelToNeighborSpansIfHelpful(graph: *const Graph, level: []const NodeId, ranks: []const usize, centers: []f64, sizes: []const NodeSize, gap: f64, use_parents: bool) void {
    if (level.len == 0 or level.len > 128) return;
    const before_stress = coordinateEdgeStress(graph, ranks, centers);
    const before_heavy = heavyEdgeDistancePenalty(graph, ranks, centers);
    const before_extent = levelExtent(level, centers, sizes);
    var backup: [128]f64 = undefined;
    for (level, 0..) |node_id, index| backup[index] = centers[node_id];

    for (level) |node_id| {
        const target = neighborSpanCenter(graph, ranks, centers, sizes, node_id, use_parents) orelse continue;
        centers[node_id] = target;
    }
    compactLevelCenters(level, centers, sizes, gap);

    const after_stress = coordinateEdgeStress(graph, ranks, centers);
    const after_heavy = heavyEdgeDistancePenalty(graph, ranks, centers);
    const after_extent = levelExtent(level, centers, sizes);
    if (after_stress > before_stress + 0.0001 or after_heavy > before_heavy + 0.0001 or after_extent > before_extent + 0.0001) {
        for (level, 0..) |node_id, index| centers[node_id] = backup[index];
    }
}

fn neighborSpanCenter(graph: *const Graph, ranks: []const usize, centers: []const f64, sizes: []const NodeSize, node_id: NodeId, use_parents: bool) ?f64 {
    if (node_id >= ranks.len or node_id >= centers.len or node_id >= sizes.len) return null;
    var min_left = std.math.floatMax(f64);
    var max_right: f64 = -std.math.floatMax(f64);
    var count: usize = 0;
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        const neighbor = if (use_parents and edge_item.to == node_id)
            edge_item.from
        else if (!use_parents and edge_item.from == node_id)
            edge_item.to
        else
            continue;
        if (neighbor >= ranks.len or neighbor >= centers.len or neighbor >= sizes.len) continue;
        const adjacent = if (use_parents)
            ranks[neighbor] + 1 == ranks[node_id]
        else
            ranks[node_id] + 1 == ranks[neighbor];
        if (!adjacent) continue;
        min_left = @min(min_left, centers[neighbor] - sizes[neighbor].width / 2.0);
        max_right = @max(max_right, centers[neighbor] + sizes[neighbor].width / 2.0);
        count += 1;
    }
    if (count == 0) return null;
    return (min_left + max_right) / 2.0;
}

fn incidentSpanCenter(graph: *const Graph, ranks: []const usize, centers: []const f64, sizes: []const NodeSize, node_id: NodeId) ?f64 {
    if (node_id >= ranks.len or node_id >= centers.len or node_id >= sizes.len) return null;
    var min_left = std.math.floatMax(f64);
    var max_right: f64 = -std.math.floatMax(f64);
    var count: usize = 0;
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        const neighbor = if (edge_item.from == node_id)
            edge_item.to
        else if (edge_item.to == node_id)
            edge_item.from
        else
            continue;
        if (neighbor >= ranks.len or neighbor >= centers.len or neighbor >= sizes.len) continue;
        if (ranks[neighbor] == ranks[node_id]) continue;
        min_left = @min(min_left, centers[neighbor] - sizes[neighbor].width / 2.0);
        max_right = @max(max_right, centers[neighbor] + sizes[neighbor].width / 2.0);
        count += 1;
    }
    if (count < 2) return null;
    return (min_left + max_right) / 2.0;
}

fn refineLongEdgeDummyCoordinates(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, centers: []f64, sizes: []const NodeSize, gap: f64) void {
    if (levels.len <= 2) return;
    for (levels, 0..) |level, rank| {
        if (rank == 0 or rank + 1 >= levels.len or level.items.len == 0) continue;
        for (level.items) |node_id| {
            var weighted_sum: f64 = 0;
            var total_weight: f64 = 0;
            for (graph.edges.items) |edge_item| {
                const dummy = longEdgeDummyCenter(edge_item, ranks, centers, rank) orelse continue;
                const influence = 1.0 / (1.0 + @abs(centers[node_id] - dummy));
                const weight = @max(edge_item.weight, 1.0) * influence;
                weighted_sum += dummy * weight;
                total_weight += weight;
            }
            if (total_weight > 0) {
                const target = weighted_sum / total_weight;
                centers[node_id] = centers[node_id] + (target - centers[node_id]) * 0.20;
            }
        }
        compactLevelCenters(level.items, centers, sizes, gap);
    }
}

fn straightenSimpleAdjacentEdges(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, centers: []f64, sizes: []const NodeSize, gap: f64, passes: usize) void {
    if (levels.len <= 1 or passes == 0) return;
    for (0..passes) |_| {
        var rank: usize = 1;
        while (rank < levels.len) : (rank += 1) {
            straightenLevelTowardSimpleNeighbors(graph, ranks, levels[rank].items, centers, true);
            compactLevelCenters(levels[rank].items, centers, sizes, gap);
        }

        rank = levels.len - 1;
        while (rank > 0) : (rank -= 1) {
            straightenLevelTowardSimpleNeighbors(graph, ranks, levels[rank - 1].items, centers, false);
            compactLevelCenters(levels[rank - 1].items, centers, sizes, gap);
        }
    }
}

fn straightenLevelTowardSimpleNeighbors(graph: *const Graph, ranks: []const usize, level: []const NodeId, centers: []f64, use_parents: bool) void {
    for (level) |node_id| {
        const target = simpleAdjacentEdgeTarget(graph, ranks, centers, node_id, use_parents) orelse continue;
        centers[node_id] = centers[node_id] + (target - centers[node_id]) * 0.85;
    }
}

fn simpleAdjacentEdgeTarget(graph: *const Graph, ranks: []const usize, centers: []const f64, node_id: NodeId, use_parents: bool) ?f64 {
    if (node_id >= ranks.len or node_id >= centers.len) return null;
    var target: ?f64 = null;
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        const neighbor = if (use_parents and edge_item.to == node_id)
            edge_item.from
        else if (!use_parents and edge_item.from == node_id)
            edge_item.to
        else
            continue;
        if (neighbor >= ranks.len or neighbor >= centers.len) continue;
        const node_rank = ranks[node_id];
        const neighbor_rank = ranks[neighbor];
        const adjacent = if (use_parents)
            neighbor_rank + 1 == node_rank
        else
            node_rank + 1 == neighbor_rank;
        if (!adjacent) continue;
        if (!nodeHasSingleAdjacentNeighbor(graph, ranks, node_id, use_parents)) continue;
        if (!nodeHasSingleAdjacentNeighbor(graph, ranks, neighbor, !use_parents)) continue;
        if (target != null) return null;
        target = centers[neighbor];
    }
    return target;
}

fn nodeHasSingleAdjacentNeighbor(graph: *const Graph, ranks: []const usize, node_id: NodeId, use_parents: bool) bool {
    if (node_id >= ranks.len) return false;
    var count: usize = 0;
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        if (use_parents) {
            if (edge_item.to != node_id or edge_item.from >= ranks.len) continue;
            if (ranks[edge_item.from] + 1 == ranks[node_id]) count += 1;
        } else {
            if (edge_item.from != node_id or edge_item.to >= ranks.len) continue;
            if (ranks[node_id] + 1 == ranks[edge_item.to]) count += 1;
        }
        if (count > 1) return false;
    }
    return count == 1;
}

fn longEdgeDummyCenter(edge_item: Edge, ranks: []const usize, centers: []const f64, rank: usize) ?f64 {
    if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) return null;
    const from_rank = ranks[edge_item.from];
    const to_rank = ranks[edge_item.to];
    if (from_rank + 1 >= to_rank) return null;
    if (rank <= from_rank or rank >= to_rank) return null;
    const span = @as(f64, @floatFromInt(to_rank - from_rank));
    const t = @as(f64, @floatFromInt(rank - from_rank)) / span;
    return centers[edge_item.from] + (centers[edge_item.to] - centers[edge_item.from]) * t;
}

fn computeEdgeWaypoints(
    allocator: std.mem.Allocator,
    graph: *const Graph,
    axes: LayoutAxes,
    nodes: []const NodeLayout,
    ranks: []const usize,
    rank_depths: []const f64,
    rank_heights: []const f64,
    total_depth: f64,
    margin_x: f64,
    margin_y: f64,
    edge_waypoints: []EdgeWaypoints,
    virtual_levels: *const VirtualLevels,
    virtual_positions: *const VirtualPositions,
) !void {
    for (graph.edges.items) |edge_item| {
        if (edge_item.id >= edge_waypoints.len) continue;
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        const from_rank = ranks[edge_item.from];
        const to_rank = ranks[edge_item.to];
        if (from_rank + 1 >= to_rank) continue;

        const count = to_rank - from_rank - 1;
        const points = try allocator.alloc(EdgeWaypoint, count);
        errdefer allocator.free(points);

        var i: usize = 0;
        var rank = from_rank + 1;
        while (rank < to_rank) : ({
            rank += 1;
            i += 1;
        }) {
            const along = virtualDummyAlong(virtual_levels, virtual_positions, edge_item.id, rank) orelse
                longEdgeDummyAlongFromNodes(nodes, ranks, edge_item, axes.rankdir, rank) orelse
                continue;
            const depth = rankDepthCenterFrom(rank_depths, rank_heights, rank);
            points[i] = .{
                .rank = rank,
                .point = axes.orientPoint(along, depth, total_depth, margin_x, margin_y),
            };
        }
        edge_waypoints[edge_item.id] = .{ .points = points };
    }
}

fn virtualDummyAlong(virtual_levels: *const VirtualLevels, virtual_positions: *const VirtualPositions, edge_id: EdgeId, rank: usize) ?f64 {
    if (rank >= virtual_levels.levels.len or rank >= virtual_positions.positions.len) return null;
    for (virtual_levels.levels[rank].items, 0..) |vnode, index| {
        switch (vnode) {
            .dummy => |dummy_edge| {
                if (dummy_edge == edge_id and index < virtual_positions.positions[rank].items.len) return virtual_positions.positions[rank].items[index];
            },
            .real => {},
        }
    }
    return null;
}

fn longEdgeDummyAlongFromNodes(nodes: []const NodeLayout, ranks: []const usize, edge_item: Edge, rankdir: RankDir, rank: usize) ?f64 {
    if (edge_item.from >= nodes.len or edge_item.to >= nodes.len) return null;
    if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) return null;
    const from_rank = ranks[edge_item.from];
    const to_rank = ranks[edge_item.to];
    if (from_rank + 1 >= to_rank) return null;
    if (rank <= from_rank or rank >= to_rank) return null;
    const span = @as(f64, @floatFromInt(to_rank - from_rank));
    const t = @as(f64, @floatFromInt(rank - from_rank)) / span;
    const from_along = pointAlongAxis(nodes[edge_item.from].center, rankdir);
    const to_along = pointAlongAxis(nodes[edge_item.to].center, rankdir);
    return from_along + (to_along - from_along) * t;
}

fn nudgeLevelTowardNeighbors(graph: *const Graph, ranks: []const usize, level: []const NodeId, centers: []f64, use_parents: bool) void {
    const blend = 0.65;
    for (level) |node_id| {
        var weighted_sum: f64 = 0;
        var total_weight: f64 = 0;
        for (graph.edges.items) |edge_item| {
            const neighbor = if (use_parents and edge_item.to == node_id and ranks[edge_item.from] < ranks[node_id])
                edge_item.from
            else if (!use_parents and edge_item.from == node_id and ranks[edge_item.to] > ranks[node_id])
                edge_item.to
            else
                continue;
            const weight = @max(edge_item.weight, 0.1);
            weighted_sum += centers[neighbor] * weight;
            total_weight += weight;
        }
        if (total_weight > 0) {
            const target = weighted_sum / total_weight;
            centers[node_id] = centers[node_id] + (target - centers[node_id]) * blend;
        }
    }
}

fn compactLevelCenters(level: []const NodeId, centers: []f64, sizes: []const NodeSize, gap: f64) void {
    if (level.len == 0) return;
    compactLevelCentersForward(level, centers, sizes, gap);
}

fn compactLevelCentersSymmetric(level: []const NodeId, centers: []f64, sizes: []const NodeSize, gap: f64) void {
    if (level.len == 0) return;
    var forward: [128]f64 = undefined;
    var backward: [128]f64 = undefined;
    if (level.len > forward.len) {
        compactLevelCentersForward(level, centers, sizes, gap);
        return;
    }

    for (level, 0..) |id, index| {
        forward[index] = centers[id];
        backward[index] = centers[id];
    }
    compactCenterSliceForward(level, sizes, gap, forward[0..level.len]);
    compactCenterSliceBackward(level, sizes, gap, backward[0..level.len], forward[level.len - 1] + sizes[level[level.len - 1]].width / 2.0);
    for (level, 0..) |id, index| {
        centers[id] = (forward[index] + backward[index]) / 2.0;
    }
}

fn compactLevelCentersForward(level: []const NodeId, centers: []f64, sizes: []const NodeSize, gap: f64) void {
    if (level.len == 0) return;
    const first = level[0];
    centers[first] = @max(centers[first], sizes[first].width / 2.0);
    var constraints_buf: [128]CoordConstraint = undefined;
    if (level.len - 1 > constraints_buf.len) {
        var prev = first;
        for (level[1..]) |id| {
            const min_center = centers[prev] + sizes[prev].width / 2.0 + gap + sizes[id].width / 2.0;
            centers[id] = @max(centers[id], min_center);
            prev = id;
        }
        return;
    }
    for (level[1..], 0..) |id, index| {
        const prev = level[index];
        constraints_buf[index] = .{
            .left = prev,
            .right = id,
            .min_gap = sizes[prev].width / 2.0 + gap + sizes[id].width / 2.0,
        };
    }
    _ = satisfyCoordConstraints(centers, constraints_buf[0 .. level.len - 1]);
}

fn compactCenterSliceForward(level: []const NodeId, sizes: []const NodeSize, gap: f64, slice: []f64) void {
    if (slice.len == 0) return;
    slice[0] = @max(slice[0], sizes[level[0]].width / 2.0);
    var index: usize = 1;
    while (index < slice.len) : (index += 1) {
        const prev_id = level[index - 1];
        const id = level[index];
        const min_center = slice[index - 1] + sizes[prev_id].width / 2.0 + gap + sizes[id].width / 2.0;
        slice[index] = @max(slice[index], min_center);
    }
}

fn compactCenterSliceBackward(level: []const NodeId, sizes: []const NodeSize, gap: f64, slice: []f64, right_edge: f64) void {
    if (slice.len == 0) return;
    var index = slice.len - 1;
    slice[index] = @min(slice[index], right_edge - sizes[level[index]].width / 2.0);
    while (index > 0) {
        const next_id = level[index];
        const id = level[index - 1];
        const max_center = slice[index] - sizes[next_id].width / 2.0 - gap - sizes[id].width / 2.0;
        slice[index - 1] = @min(slice[index - 1], max_center);
        index -= 1;
    }
}

fn applySymmetricCompactionIfHelpful(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, centers: []f64, sizes: []const NodeSize, gap: f64) void {
    for (levels) |level| {
        if (level.items.len <= 1 or level.items.len > 128) continue;
        const before_stress = coordinateEdgeStress(graph, ranks, centers);
        const before_extent = levelExtent(level.items, centers, sizes);
        var backup: [128]f64 = undefined;
        for (level.items, 0..) |node_id, index| backup[index] = centers[node_id];

        compactLevelCentersSymmetric(level.items, centers, sizes, gap);
        const after_stress = coordinateEdgeStress(graph, ranks, centers);
        const after_extent = levelExtent(level.items, centers, sizes);
        if (after_stress > before_stress + 0.0001 or after_extent > before_extent + 0.0001) {
            for (level.items, 0..) |node_id, index| centers[node_id] = backup[index];
        }
    }
}

fn levelExtent(level: []const NodeId, centers: []const f64, sizes: []const NodeSize) f64 {
    if (level.len == 0) return 0;
    var min_left = std.math.floatMax(f64);
    var max_right: f64 = -std.math.floatMax(f64);
    for (level) |node_id| {
        if (node_id >= centers.len or node_id >= sizes.len) continue;
        min_left = @min(min_left, centers[node_id] - sizes[node_id].width / 2.0);
        max_right = @max(max_right, centers[node_id] + sizes[node_id].width / 2.0);
    }
    if (min_left == std.math.floatMax(f64)) return 0;
    return max_right - min_left;
}

fn coordinateEdgeStress(graph: *const Graph, ranks: []const usize, centers: []const f64) f64 {
    var stress: f64 = 0;
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        if (edge_item.from >= centers.len or edge_item.to >= centers.len) continue;
        const from_rank = ranks[edge_item.from];
        const to_rank = ranks[edge_item.to];
        if (from_rank >= to_rank) continue;
        const span = @max(to_rank - from_rank, 1);
        const delta = centers[edge_item.to] - centers[edge_item.from];
        stress += @max(edge_item.weight, 0.1) * (delta * delta) / @as(f64, @floatFromInt(span));
    }
    return stress;
}

fn heavyEdgeDistancePenalty(graph: *const Graph, ranks: []const usize, centers: []const f64) f64 {
    var penalty: f64 = 0;
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint or edge_item.weight <= 1.0) continue;
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        if (edge_item.from >= centers.len or edge_item.to >= centers.len) continue;
        if (ranks[edge_item.from] >= ranks[edge_item.to]) continue;
        const delta = @abs(centers[edge_item.to] - centers[edge_item.from]);
        penalty += edge_item.weight * delta;
    }
    return penalty;
}

fn normalizeCenters(centers: []f64, sizes: []const NodeSize) void {
    if (centers.len == 0) return;
    var min_left = std.math.floatMax(f64);
    for (centers, 0..) |center, id| min_left = @min(min_left, center - sizes[id].width / 2.0);
    if (min_left == 0 or min_left == std.math.floatMax(f64)) return;
    for (centers) |*center| center.* -= min_left;
}

fn orientPoint(rankdir: RankDir, along: f64, depth: f64, total_depth: f64, margin_x: f64, margin_y: f64) Point {
    return LayoutAxes.init(rankdir).orientPoint(along, depth, total_depth, margin_x, margin_y);
}

pub const OutputFormat = enum {
    terminal,
    svg,
    png,
    pdf,

    pub fn fromString(value: []const u8) ?OutputFormat {
        if (std.ascii.eqlIgnoreCase(value, "terminal") or std.ascii.eqlIgnoreCase(value, "term") or std.ascii.eqlIgnoreCase(value, "txt")) return .terminal;
        if (std.ascii.eqlIgnoreCase(value, "svg")) return .svg;
        if (std.ascii.eqlIgnoreCase(value, "png")) return .png;
        if (std.ascii.eqlIgnoreCase(value, "pdf")) return .pdf;
        return null;
    }

    pub fn fromPath(path: []const u8) ?OutputFormat {
        const ext = std.fs.path.extension(path);
        if (ext.len == 0) return null;
        return fromString(ext[1..]);
    }
};

pub const RenderOptions = struct {
    svg: SvgOptions = .{},
    terminal: TerminalOptions = .{},
};

pub const RenderError = Io.Writer.Error || std.mem.Allocator.Error || error{UnsupportedFormat};

pub fn render(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, format: OutputFormat, options: RenderOptions) RenderError!void {
    return switch (format) {
        .terminal => renderTerminal(writer, graph, layout, options.terminal),
        .svg => renderSvg(writer, graph, layout, options.svg),
        .png => renderPng(writer, graph, layout),
        .pdf => renderPdf(writer, graph, layout),
    };
}

pub fn renderAlloc(allocator: std.mem.Allocator, graph: *const Graph, layout: *const Layout, format: OutputFormat, options: RenderOptions) ![]u8 {
    var aw = Io.Writer.Allocating.init(allocator);
    errdefer aw.deinit();
    try render(&aw.writer, graph, layout, format, options);
    return aw.toOwnedSlice();
}

pub const TerminalOptions = struct {
    unicode: bool = true,
};

pub fn renderTerminal(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, options: TerminalOptions) Io.Writer.Error!void {
    _ = layout;
    const arrow = if (graph.directed) "->" else "--";
    const branch = if (options.unicode) "├─" else "|-";
    const last = if (options.unicode) "└─" else "`-";
    try writer.print("{s} {s} ({d} nodes, {d} edges)\n", .{ if (graph.directed) "digraph" else "graph", graph.name, graph.nodes.items.len, graph.edges.items.len });
    try writer.writeAll("nodes:\n");
    for (graph.nodes.items, 0..) |node_item, i| {
        try writer.print("  {s} {s} [{s}]\n", .{ if (i + 1 == graph.nodes.items.len) last else branch, node_item.name, node_item.label });
    }
    try writer.writeAll("edges:\n");
    for (graph.edges.items, 0..) |edge_item, i| {
        const from = graph.nodes.items[edge_item.from].name;
        const to = graph.nodes.items[edge_item.to].name;
        try writer.print("  {s} {s} {s} {s}", .{ if (i + 1 == graph.edges.items.len) last else branch, from, arrow, to });
        if (edge_item.label) |label| try writer.print(" [label={s}]", .{label});
        try writer.writeByte('\n');
    }
}

pub const SvgOptions = struct {
    background: []const u8 = "white",
    font_family: []const u8 = default_svg_font_family,
    show_title: bool = true,
};

pub fn renderSvg(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, options: SvgOptions) Io.Writer.Error!void {
    const edge_routing = svgEdgeRoutingMode(graph);
    const concentrate = graphConcentrateEnabled(graph);
    const background = attrValue(graph.attrs.items, "bgcolor") orelse options.background;
    const content_translate = svgGraphContentTranslate(layout);
    const background_left = if (@abs(content_translate) <= 0.0001) 0.0 else -content_translate;
    const background_right = layout.width + background_left;
    try writer.print(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"{d:.0}pt\" height=\"{d:.0}pt\" viewBox=\"0.00 0.00 {d:.2} {d:.2}\">\n",
        .{ layout.width, layout.height, layout.width, layout.height },
    );
    try writer.print("<g id=\"graph0\" class=\"graph\" transform=\"scale(1 1) rotate(0) translate({d:.1} 0)\">\n", .{content_translate});
    try writer.writeAll("<title>");
    try writeXmlEscaped(writer, graph.name);
    try writer.writeAll("</title>\n");
    try writer.print("<polygon fill=\"{s}\" stroke=\"none\" points=\"{d:.1},0 {d:.1},{d:.0} {d:.1},{d:.0} {d:.1},0 {d:.1},0\"/>\n", .{
        background,
        background_left,
        background_left,
        layout.height,
        background_right,
        layout.height,
        background_right,
        background_left,
    });
    if (options.show_title and attrValue(graph.attrs.items, "label") != null) {
        const graph_label = attrValue(graph.attrs.items, "label").?;
        const label_just = attrValue(graph.attrs.items, "labeljust");
        const label_loc = attrValue(graph.attrs.items, "labelloc");
        const text_anchor: []const u8 = if (label_just) |value|
            if (std.ascii.eqlIgnoreCase(value, "r")) "end" else if (std.ascii.eqlIgnoreCase(value, "c")) "middle" else "start"
        else
            "start";
        const title_x = if (std.mem.eql(u8, text_anchor, "end"))
            layout.width - 16.0
        else if (std.mem.eql(u8, text_anchor, "middle"))
            layout.width / 2.0
        else
            16.0;
        const title_y = if (label_loc) |value|
            if (std.ascii.eqlIgnoreCase(value, "b")) layout.height - 16.0 else 24.0
        else
            24.0;
        const title_font = attrValue(graph.attrs.items, "fontname") orelse options.font_family;
        const title_size = parsePositiveAttrFloat(graph.attrs.items, "fontsize", 14.0);
        const title_color = attrValue(graph.attrs.items, "fontcolor") orelse "black";
        try writer.print("<text xml:space=\"preserve\" text-anchor=\"{s}\" x=\"{d:.1}\" y=\"{d:.1}\" font-family=\"{s}\" font-size=\"{d:.2}\"", .{ text_anchor, title_x, title_y, title_font, title_size });
        try writeSvgTextFill(writer, title_color);
        try writer.writeAll(">");
        try writeXmlEscaped(writer, graph_label);
        try writer.writeAll("</text>\n");
    }
    if (svgNeedsMarkerDefs(graph, concentrate)) {
        try writer.writeAll("<defs>\n");
        for (graph.edges.items) |edge_item| {
            if (concentrate and isConcentratedDuplicateEdge(graph, edge_item.id)) continue;
            const visual = resolveEdgeVisual(edge_item);
            if (visual.marker_end != .none and visual.marker_end != .normal) try writeSvgMarkerDef(writer, edge_item.id, "head", visual.marker_end, edgeMarkerColor(edge_item, visual, true), visual.marker_scale);
            if (visual.marker_start != .none and visual.marker_start != .normal) try writeSvgMarkerDef(writer, edge_item.id, "tail", visual.marker_start, edgeMarkerColor(edge_item, visual, false), visual.marker_scale);
        }
        try writer.writeAll("</defs>\n");
    }

    try renderSvgClusters(writer, graph, layout);
    try renderSvgGraphItems(writer, graph, layout, options, edge_routing, concentrate);
    try writer.writeAll("</g>\n</svg>\n");
}

fn renderSvgGraphItems(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, options: SvgOptions, edge_routing: SvgEdgeRouting, concentrate: bool) Io.Writer.Error!void {
    if (graph.nodes.items.len > 512 or graph.edges.items.len > 1024) {
        for (graph.edges.items) |edge_item| try renderSvgEdgeGroup(writer, graph, layout, edge_item, edge_routing, concentrate);
        for (graph.nodes.items) |node_item| try renderSvgNodeGroup(writer, graph, layout, options, node_item);
        return;
    }

    var node_written_buf: [512]bool = undefined;
    var edge_written_buf: [1024]bool = undefined;
    const node_written = node_written_buf[0..graph.nodes.items.len];
    const edge_written = edge_written_buf[0..graph.edges.items.len];
    @memset(node_written, false);
    @memset(edge_written, false);

    for (graph.nodes.items) |node_item| {
        if (!node_written[node_item.id]) {
            try renderSvgNodeGroup(writer, graph, layout, options, node_item);
            node_written[node_item.id] = true;
        }
        var outgoing: [1024]EdgeId = undefined;
        var outgoing_len: usize = 0;
        for (graph.edges.items) |edge_item| {
            if (edge_item.from != node_item.id or edge_item.id >= edge_written.len or edge_written[edge_item.id]) continue;
            outgoing[outgoing_len] = edge_item.id;
            outgoing_len += 1;
        }
        sortEdgesByTarget(graph, outgoing[0..outgoing_len]);
        for (outgoing[0..outgoing_len]) |edge_id| {
            const edge_item = graph.edges.items[edge_id];
            if (edge_item.to < node_written.len and !node_written[edge_item.to]) {
                try renderSvgNodeGroup(writer, graph, layout, options, graph.nodes.items[edge_item.to]);
                node_written[edge_item.to] = true;
            }
            try renderSvgEdgeGroup(writer, graph, layout, edge_item, edge_routing, concentrate);
            edge_written[edge_item.id] = true;
        }
    }

    for (graph.edges.items) |edge_item| {
        if (edge_item.id < edge_written.len and edge_written[edge_item.id]) continue;
        try renderSvgEdgeGroup(writer, graph, layout, edge_item, edge_routing, concentrate);
    }
    for (graph.nodes.items) |node_item| {
        if (node_item.id < node_written.len and node_written[node_item.id]) continue;
        try renderSvgNodeGroup(writer, graph, layout, options, node_item);
    }
}

fn sortEdgesByTarget(graph: *const Graph, edge_ids: []EdgeId) void {
    std.mem.sort(EdgeId, edge_ids, graph, lessThanEdgeTarget);
}

fn lessThanEdgeTarget(graph: *const Graph, a_id: EdgeId, b_id: EdgeId) bool {
    const a = graph.edges.items[a_id];
    const b = graph.edges.items[b_id];
    if (a.to == b.to) return a.id < b.id;
    return a.to < b.to;
}

fn renderSvgEdgeGroup(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, edge_item: Edge, edge_routing: SvgEdgeRouting, concentrate: bool) Io.Writer.Error!void {
    if (concentrate and isConcentratedDuplicateEdge(graph, edge_item.id)) return;
    const visual = resolveEdgeVisual(edge_item);
    if (visual.hidden) return;
    try writeSvgEdgeComment(writer, graph, edge_item);
    try writer.print("<g id=\"edge{d}\" class=\"edge\">\n", .{edge_item.id + 1});
    const edge_wrap = try writeSvgInteractiveOpen(writer, edge_item.attrs.items);
    if (edge_wrap == .none) {
        try writeSvgEdgeTitle(writer, graph, edge_item);
        try writer.writeByte('\n');
    }
    if (edge_item.from == edge_item.to) {
        const route = selfLoopRoute(layout.nodes[edge_item.from]);
        try renderSvgSelfLoopPaths(writer, graph.directed, edge_item, route, visual);
        if (edge_item.label) |label| {
            try renderSvgTextBlock(writer, label, route.label.x, route.label.y, visual.font_size, visual.font_color, visual.font_family, true, true);
        }
        try renderSvgExtraEdgeLabels(writer, edge_item, route, visual);
        try writeSvgInteractiveClose(writer, edge_wrap);
        try writer.writeAll("</g>\n");
        return;
    }

    const offset = parallelEdgeOffset(graph, edge_item.id);
    const route = edgeRouteForEdge(graph, layout, edge_item, layout.rankdir, offset);
    try renderSvgEdgePaths(writer, graph.directed, layout, edge_item, layout.rankdir, offset, route, edge_routing, visual);
    if (edge_item.label) |label| {
        try renderSvgTextBlock(writer, label, route.label.x, route.label.y - 6.0, visual.font_size, visual.font_color, visual.font_family, true, true);
    }
    try renderSvgExtraEdgeLabels(writer, edge_item, route, visual);
    try writeSvgInteractiveClose(writer, edge_wrap);
    try writer.writeAll("</g>\n");
}

fn renderSvgNodeGroup(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, options: SvgOptions, node_item: Node) Io.Writer.Error!void {
    _ = graph;
    var visual = resolveNodeVisual(node_item);
    if (visual.hidden) return;
    const l = layout.nodes[node_item.id];
    try writeSvgComment(writer, node_item.name);
    try writer.print("<g id=\"node{d}\" class=\"node\">\n", .{node_item.id + 1});
    const node_wrap = try writeSvgInteractiveOpen(writer, node_item.attrs.items);
    if (node_wrap == .none) {
        try writeSvgTitle(writer, node_item.name);
        try writer.writeByte('\n');
    }
    var fill_buf: [96]u8 = undefined;
    if (stripedNodeFillEligible(node_item.shape)) {
        if (try renderSvgStripedRectFill(writer, "vex-node-stripes", node_item.id + 1, node_item.attrs.items, nodeRect(l), visual.radius, visual.fill)) {
            visual.fill = "none";
        } else {
            try resolveSvgGradientFill(writer, "vex-node-fill", node_item.id + 1, node_item.attrs.items, nodeRect(l), &visual.fill, &fill_buf);
        }
    } else {
        try resolveSvgGradientFill(writer, "vex-node-fill", node_item.id + 1, node_item.attrs.items, nodeRect(l), &visual.fill, &fill_buf);
    }
    if (htmlTableMetrics(node_item.label) != null) {
        try renderSvgHtmlTableLabel(writer, node_item.label, l, visual);
        try writeSvgInteractiveClose(writer, node_wrap);
        try writer.writeAll("</g>\n");
        return;
    }
    try renderSvgNodeShape(writer, node_item, l, visual, options);
    if (node_item.shape != .record and node_item.shape != .mrecord and node_item.shape != .point) {
        try renderSvgNodeLabel(writer, node_item, l, visual);
    }
    try renderSvgNodeXLabel(writer, node_item, l, visual);
    try writeSvgInteractiveClose(writer, node_wrap);
    try writer.writeAll("</g>\n");
}

fn svgNeedsMarkerDefs(graph: *const Graph, concentrate: bool) bool {
    if (!graph.directed) return false;
    for (graph.edges.items) |edge_item| {
        if (concentrate and isConcentratedDuplicateEdge(graph, edge_item.id)) continue;
        const visual = resolveEdgeVisual(edge_item);
        if (visual.marker_end != .none and visual.marker_end != .normal) return true;
        if (visual.marker_start != .none and visual.marker_start != .normal) return true;
    }
    return false;
}

fn svgGraphContentTranslate(layout: *const Layout) f64 {
    if (layout.clusters.len == 0) return 0;
    var min_x = std.math.floatMax(f64);
    var max_x: f64 = -std.math.floatMax(f64);
    for (layout.clusters) |cluster_box| {
        if (cluster_box.width <= 0 or cluster_box.height <= 0) continue;
        min_x = @min(min_x, cluster_box.x);
        max_x = @max(max_x, cluster_box.x + cluster_box.width);
    }
    if (min_x == std.math.floatMax(f64) or max_x <= min_x) return 0;
    const shift = ((layout.width - max_x) - min_x) / 2.0;
    return if (@abs(shift) < 0.05) 0 else shift;
}

pub fn renderSvgAlloc(allocator: std.mem.Allocator, graph: *const Graph, layout: *const Layout, options: SvgOptions) ![]u8 {
    var aw = Io.Writer.Allocating.init(allocator);
    errdefer aw.deinit();
    try renderSvg(&aw.writer, graph, layout, options);
    return aw.toOwnedSlice();
}

fn writeXmlEscaped(writer: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    for (text) |c| switch (c) {
        '&' => try writer.writeAll("&amp;"),
        '<' => try writer.writeAll("&lt;"),
        '>' => try writer.writeAll("&gt;"),
        '"' => try writer.writeAll("&quot;"),
        0x27 => try writer.writeAll("&apos;"),
        else => try writer.writeByte(c),
    };
}

fn writeSvgCommentEscaped(writer: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    for (text) |c| switch (c) {
        '-' => try writer.writeAll("&#45;"),
        '&' => try writer.writeAll("&amp;"),
        '<' => try writer.writeAll("&lt;"),
        '>' => try writer.writeAll("&gt;"),
        else => try writer.writeByte(c),
    };
}

fn writeSvgComment(writer: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    try writer.writeAll("<!-- ");
    try writeSvgCommentEscaped(writer, text);
    try writer.writeAll(" -->\n");
}

fn writeSvgEdgeComment(writer: *Io.Writer, graph: *const Graph, edge_item: Edge) Io.Writer.Error!void {
    if (edge_item.from >= graph.nodes.items.len or edge_item.to >= graph.nodes.items.len) return;
    try writer.writeAll("<!-- ");
    try writeSvgCommentEscaped(writer, graph.nodes.items[edge_item.from].name);
    try writer.writeAll(if (graph.directed) "&#45;&gt;" else "&#45;&#45;");
    try writeSvgCommentEscaped(writer, graph.nodes.items[edge_item.to].name);
    try writer.writeAll(" -->\n");
}

const SvgInteractiveWrap = enum {
    none,
    anchor,
    group,
};

const ColorSegment = struct {
    color: []const u8,
    fraction: f64,
    has_fraction: bool,
};

const ColorList = struct {
    segments: [8]ColorSegment = undefined,
    len: usize = 0,
};

fn resolveSvgGradientFill(writer: *Io.Writer, id_prefix: []const u8, id: usize, attrs: []const Attr, rect: RectF, fill: *[]const u8, buffer: *[96]u8) Io.Writer.Error!void {
    const style = attrValue(attrs, "style");
    if (!styleHas(style, "filled") and !styleHas(style, "radial")) return;
    const fillcolor = attrValue(attrs, "fillcolor") orelse return;
    const colors = parseColorList(fillcolor) orelse return;
    if (colors.len < 2) return;

    const angle = parseAttrFloat(attrs, "gradientangle", 0.0);
    const url = std.fmt.bufPrint(buffer, "url(#{s}-{d})", .{ id_prefix, id }) catch unreachable;
    if (styleHas(style, "radial")) {
        try writeSvgRadialGradientDef(writer, id_prefix, id, colors.segments[0], colors.segments[1], angle);
    } else {
        try writeSvgLinearGradientDef(writer, id_prefix, id, rect, colors.segments[0], colors.segments[1], angle);
    }
    fill.* = url;
}

fn renderSvgStripedRectFill(writer: *Io.Writer, id_prefix: []const u8, id: usize, attrs: []const Attr, rect: RectF, radius: f64, fallback_fill: []const u8) Io.Writer.Error!bool {
    if (!styleHas(attrValue(attrs, "style"), "striped")) return false;
    const fillcolor = attrValue(attrs, "fillcolor") orelse fallback_fill;
    const colors = parseColorList(fillcolor) orelse return false;
    if (colors.len < 2) return false;

    try writer.print("<g id=\"{s}-{d}\" class=\"striped-fill\">\n", .{ id_prefix, id });
    var cursor = rect.x;
    for (colors.segments[0..colors.len], 0..) |segment, index| {
        if (segment.fraction <= 0) continue;
        const stripe_width = if (index + 1 == colors.len)
            rect.x + rect.width - cursor
        else
            rect.width * segment.fraction;
        if (stripe_width <= 0) continue;
        try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"{d:.1}\" fill=\"{s}\" stroke=\"none\"/>\n", .{
            cursor,
            rect.y,
            stripe_width,
            rect.height,
            radius,
            segment.color,
        });
        cursor += stripe_width;
        if (cursor >= rect.x + rect.width) break;
    }
    try writer.writeAll("</g>\n");
    return true;
}

fn writeSvgLinearGradientDef(writer: *Io.Writer, id_prefix: []const u8, id: usize, rect: RectF, start: ColorSegment, stop: ColorSegment, angle_degrees: f64) Io.Writer.Error!void {
    const line = gradientLine(rect, angle_degrees);
    try writer.print("<defs><linearGradient id=\"{s}-{d}\" gradientUnits=\"userSpaceOnUse\" x1=\"{d:.1}\" y1=\"{d:.1}\" x2=\"{d:.1}\" y2=\"{d:.1}\">\n", .{
        id_prefix,
        id,
        line.start.x,
        line.start.y,
        line.end.x,
        line.end.y,
    });
    try writeSvgGradientStop(writer, gradientStopStartOffset(start, stop), start.color);
    try writeSvgGradientStop(writer, gradientStopEndOffset(start, stop), stop.color);
    try writer.writeAll("</linearGradient></defs>\n");
}

fn writeSvgRadialGradientDef(writer: *Io.Writer, id_prefix: []const u8, id: usize, start: ColorSegment, stop: ColorSegment, angle_degrees: f64) Io.Writer.Error!void {
    const focus = radialGradientFocus(angle_degrees);
    try writer.print("<defs><radialGradient id=\"{s}-{d}\" cx=\"50%\" cy=\"50%\" r=\"75%\" fx=\"{d:.0}%\" fy=\"{d:.0}%\">\n", .{
        id_prefix,
        id,
        focus.x,
        focus.y,
    });
    try writeSvgGradientStop(writer, 0.0, start.color);
    try writeSvgGradientStop(writer, 1.0, stop.color);
    try writer.writeAll("</radialGradient></defs>\n");
}

fn writeSvgGradientStop(writer: *Io.Writer, offset: f64, color: []const u8) Io.Writer.Error!void {
    try writer.print("<stop offset=\"{d:.1}%\" stop-color=\"{s}\"/>\n", .{ std.math.clamp(offset, 0.0, 1.0) * 100.0, color });
}

fn stripedNodeFillEligible(shape: Shape) bool {
    return switch (shape) {
        .box, .square, .msquare, .record, .mrecord => true,
        else => false,
    };
}

fn parseColorList(value: []const u8) ?ColorList {
    if (std.mem.indexOfScalar(u8, value, ':') == null) return null;
    var result = ColorList{};
    var left: f64 = 1.0;
    var splitter = std.mem.splitScalar(u8, value, ':');
    while (splitter.next()) |raw_part| {
        if (result.len >= result.segments.len) break;
        const part = std.mem.trim(u8, raw_part, " \t\r\n");
        if (part.len == 0) continue;
        var color = part;
        var fraction: f64 = 0.0;
        var has_fraction = false;
        if (std.mem.indexOfScalar(u8, part, ';')) |semicolon| {
            color = std.mem.trim(u8, part[0..semicolon], " \t\r\n");
            const fraction_text = std.mem.trim(u8, part[semicolon + 1 ..], " \t\r\n");
            if (fraction_text.len == 0) return null;
            const parsed = std.fmt.parseFloat(f64, fraction_text) catch return null;
            if (parsed < 0) return null;
            fraction = @min(parsed, left);
            left -= fraction;
            has_fraction = true;
        }
        if (color.len == 0) continue;
        result.segments[result.len] = .{ .color = color, .fraction = fraction, .has_fraction = has_fraction };
        result.len += 1;
        if (left <= 0.00001) {
            left = 0;
            break;
        }
    }
    if (result.len < 2) return null;

    if (left > 0) {
        var unspecified: usize = 0;
        for (result.segments[0..result.len]) |segment| {
            if (!segment.has_fraction or segment.fraction <= 0) unspecified += 1;
        }
        if (unspecified > 0) {
            const delta = left / @as(f64, @floatFromInt(unspecified));
            for (result.segments[0..result.len]) |*segment| {
                if (!segment.has_fraction or segment.fraction <= 0) segment.fraction = delta;
            }
        } else {
            result.segments[result.len - 1].fraction += left;
        }
    }

    while (result.len > 0 and result.segments[result.len - 1].fraction <= 0) result.len -= 1;
    return if (result.len >= 2) result else null;
}

const GradientLine = struct {
    start: Point,
    end: Point,
};

fn gradientLine(rect: RectF, angle_degrees: f64) GradientLine {
    const cx = rect.x + rect.width / 2.0;
    const cy = rect.y + rect.height / 2.0;
    const angle = degreesToRadians(angle_degrees);
    const dx = std.math.cos(angle);
    const dy = -std.math.sin(angle);
    const half = @max(rect.width, rect.height);
    return .{
        .start = .{ .x = cx - dx * half, .y = cy - dy * half },
        .end = .{ .x = cx + dx * half, .y = cy + dy * half },
    };
}

fn radialGradientFocus(angle_degrees: f64) Point {
    if (@abs(angle_degrees) <= 0.0001) return .{ .x = 50, .y = 50 };
    const angle = degreesToRadians(angle_degrees);
    return .{
        .x = @round(50.0 * (1.0 + std.math.cos(angle))),
        .y = @round(50.0 * (1.0 - std.math.sin(angle))),
    };
}

fn gradientStopStartOffset(start: ColorSegment, stop: ColorSegment) f64 {
    _ = stop;
    return if (start.has_fraction) @max(0.0, start.fraction - 0.001) else 0.0;
}

fn gradientStopEndOffset(start: ColorSegment, stop: ColorSegment) f64 {
    if (start.has_fraction) return start.fraction;
    if (stop.has_fraction) return 1.0 - stop.fraction;
    return 1.0;
}

fn writeSvgInteractiveOpen(writer: *Io.Writer, attrs: []const Attr) Io.Writer.Error!SvgInteractiveWrap {
    const href = attrValue(attrs, "href") orelse attrValue(attrs, "URL") orelse attrValue(attrs, "url");
    const tooltip = attrValue(attrs, "tooltip") orelse attrValue(attrs, "title");
    if (href == null and tooltip == null) return .none;

    if (href) |target| {
        try writer.writeAll("<a href=\"");
        try writeXmlEscaped(writer, target);
        try writer.writeAll("\">");
        if (tooltip) |tip| try writeSvgTitle(writer, tip);
        return .anchor;
    }

    try writer.writeAll("<g>");
    if (tooltip) |tip| try writeSvgTitle(writer, tip);
    return .group;
}

fn writeSvgTitle(writer: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    try writer.writeAll("<title>");
    try writeXmlEscaped(writer, text);
    try writer.writeAll("</title>");
}

fn writeSvgEdgeTitle(writer: *Io.Writer, graph: *const Graph, edge_item: Edge) Io.Writer.Error!void {
    if (edge_item.from >= graph.nodes.items.len or edge_item.to >= graph.nodes.items.len) return;
    try writer.writeAll("<title>");
    try writeXmlEscaped(writer, graph.nodes.items[edge_item.from].name);
    try writer.writeAll(if (graph.directed) "-&gt;" else "--");
    try writeXmlEscaped(writer, graph.nodes.items[edge_item.to].name);
    try writer.writeAll("</title>");
}

fn writeSvgInteractiveClose(writer: *Io.Writer, wrap: SvgInteractiveWrap) Io.Writer.Error!void {
    switch (wrap) {
        .none => {},
        .anchor => try writer.writeAll("</a>\n"),
        .group => try writer.writeAll("</g>\n"),
    }
}

fn renderSvgExtraEdgeLabels(writer: *Io.Writer, edge_item: Edge, route: EdgeRoute, visual: EdgeVisual) Io.Writer.Error!void {
    const label_font_size = parsePositiveAttrFloat(edge_item.attrs.items, "labelfontsize", visual.font_size);
    const label_font_color = attrValue(edge_item.attrs.items, "labelfontcolor") orelse visual.font_color;
    const label_font_family = attrValue(edge_item.attrs.items, "labelfontname") orelse visual.font_family;
    const label_distance = std.math.clamp(parseAttrFloat(edge_item.attrs.items, "labeldistance", 1.0), 0.0, 16.0);
    const label_angle = parseAttrFloat(edge_item.attrs.items, "labelangle", -25.0);
    if (attrValue(edge_item.attrs.items, "taillabel")) |label| {
        const pos = endpointLabelPosition(route.start, route.label, label_distance, -label_angle, false);
        try renderSvgTextBlock(writer, label, pos.x, pos.y, label_font_size, label_font_color, label_font_family, true, true);
    }
    if (attrValue(edge_item.attrs.items, "headlabel")) |label| {
        const pos = endpointLabelPosition(route.end, route.label, label_distance, label_angle, true);
        try renderSvgTextBlock(writer, label, pos.x, pos.y, label_font_size, label_font_color, label_font_family, true, true);
    }
    if (attrValue(edge_item.attrs.items, "xlabel")) |label| {
        try renderSvgTextBlock(writer, label, route.label.x, route.label.y + 18.0, label_font_size, label_font_color, label_font_family, true, true);
    }
    if (edge_item.label != null and edgeDecorateEnabled(edge_item.attrs.items)) {
        const anchor = lerpPoint(route.start, route.end, 0.5);
        try writeSvgLine(writer, route.label.x, route.label.y - 3.0, anchor.x, anchor.y, .{
            .fill = "none",
            .stroke = visual.stroke,
            .font_color = visual.font_color,
            .font_family = visual.font_family,
            .font_size = visual.font_size,
            .width = @max(1.0, visual.width * 0.75),
            .radius = 0,
            .dash = visual.dash,
            .peripheries = 1,
            .hidden = false,
        });
    }
}

fn renderSvgEdgePaths(writer: *Io.Writer, directed: bool, layout: *const Layout, edge_item: Edge, rankdir: RankDir, base_offset: f64, route: EdgeRoute, routing: SvgEdgeRouting, visual: EdgeVisual) Io.Writer.Error!void {
    if (edgeColorList(edge_item)) |colors| {
        const spacing = @max(4.0, visual.width + 3.0);
        for (colors.segments[0..colors.len], 0..) |segment, index| {
            const color_offset = colorListOffset(colors.len, index, spacing);
            const segment_route = edgeRouteForEdgeWithColorOffset(route, rankdir, color_offset);
            const segment_visual = edgeVisualForSegment(edge_item, visual, segment.color, index, colors.len);
            const path_route = routeForPathMarkers(segment_route, segment_visual);
            try writer.print("<path fill=\"none\" stroke=\"{s}\" d=\"", .{segment.color});
            try writeEdgePath(writer, layout, edge_item, rankdir, base_offset + color_offset, path_route, routing);
            try writer.writeByte('"');
            try writeSvgStrokeWidth(writer, visual.width);
            try writeSvgDash(writer, visual.dash);
            try writeSvgMarkerAttrs(writer, directed, edge_item.id, segment_visual);
            try writer.writeAll("/>\n");
            try writeSvgInlineArrowheads(writer, directed, segment_route, segment_visual);
        }
        return;
    }

    const path_route = routeForPathMarkers(route, visual);
    try writer.print("<path fill=\"none\" stroke=\"{s}\" d=\"", .{visual.stroke});
    try writeEdgePath(writer, layout, edge_item, rankdir, base_offset, path_route, routing);
    try writer.writeByte('"');
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writeSvgMarkerAttrs(writer, directed, edge_item.id, visual);
    try writer.writeAll("/>\n");
    try writeSvgInlineArrowheads(writer, directed, route, visual);
}

fn renderSvgSelfLoopPaths(writer: *Io.Writer, directed: bool, edge_item: Edge, route: EdgeRoute, visual: EdgeVisual) Io.Writer.Error!void {
    if (edgeColorList(edge_item)) |colors| {
        const spacing = @max(4.0, visual.width + 3.0);
        for (colors.segments[0..colors.len], 0..) |segment, index| {
            const color_offset = colorListOffset(colors.len, index, spacing);
            const segment_visual = edgeVisualForSegment(edge_item, visual, segment.color, index, colors.len);
            const shifted = offsetEdgeRoute(route, .TB, color_offset);
            try writeSvgSelfLoopPath(writer, shifted, segment_visual);
            try writeSvgMarkerAttrs(writer, directed, edge_item.id, segment_visual);
            try writer.writeAll("/>\n");
            try writeSvgInlineArrowheads(writer, directed, shifted, segment_visual);
        }
        return;
    }

    try writeSvgSelfLoopPath(writer, route, visual);
    try writeSvgMarkerAttrs(writer, directed, edge_item.id, visual);
    try writer.writeAll("/>\n");
    try writeSvgInlineArrowheads(writer, directed, route, visual);
}

fn writeSvgSelfLoopPath(writer: *Io.Writer, route: EdgeRoute, visual: EdgeVisual) Io.Writer.Error!void {
    try writer.print("<path d=\"M {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        route.start.x,
        route.start.y,
        route.control1.x,
        route.control1.y,
        route.control2.x,
        route.control2.y,
        route.end.x,
        route.end.y,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
}

fn edgeColorList(edge_item: Edge) ?ColorList {
    const color = attrValue(edge_item.attrs.items, "color") orelse edge_item.color;
    return parseColorList(color);
}

fn edgeMarkerColor(edge_item: Edge, visual: EdgeVisual, head: bool) []const u8 {
    const colors = edgeColorList(edge_item) orelse return visual.stroke;
    if (head) return colors.segments[0].color;
    if (colors.len >= 2) return colors.segments[1].color;
    return colors.segments[0].color;
}

fn edgeVisualForSegment(edge_item: Edge, visual: EdgeVisual, color: []const u8, index: usize, color_count: usize) EdgeVisual {
    var result = visual;
    result.stroke = color;
    if (index != 0) result.marker_end = .none;
    if (index != @min(color_count - 1, 1)) result.marker_start = .none;
    if (result.marker_start != .none) result.stroke = edgeMarkerColor(edge_item, visual, false);
    if (result.marker_end != .none) result.stroke = edgeMarkerColor(edge_item, visual, true);
    return result;
}

fn colorListOffset(count: usize, index: usize, spacing: f64) f64 {
    if (count <= 1) return 0;
    return (@as(f64, @floatFromInt(index)) - @as(f64, @floatFromInt(count - 1)) / 2.0) * spacing;
}

fn edgeRouteForEdgeWithColorOffset(route: EdgeRoute, rankdir: RankDir, offset: f64) EdgeRoute {
    return offsetEdgeRoute(route, rankdir, offset);
}

fn offsetEdgeRoute(route: EdgeRoute, rankdir: RankDir, offset: f64) EdgeRoute {
    return .{
        .start = offsetPoint(route.start, rankdir, offset),
        .control1 = offsetPoint(route.control1, rankdir, offset),
        .control2 = offsetPoint(route.control2, rankdir, offset),
        .end = offsetPoint(route.end, rankdir, offset),
        .label = route.label,
    };
}

fn renderSvgNodeLabel(writer: *Io.Writer, node_item: Node, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const margin = nodeMargin(node_item.attrs.items, 0);
    const anchor = nodeLabelAnchor(node_item.attrs.items, layout, margin.x);
    const y = nodeLabelY(node_item.attrs.items, layout, margin.y);
    if (plainSingleLineLabel(node_item.label)) {
        try renderSvgPlainTextBlock(writer, node_item.label, anchor.x, y, visual.font_size, visual.font_color, visual.font_family, anchor.anchor);
        return;
    }
    try renderSvgTextBlockWithAnchor(writer, node_item.label, anchor.x, y, visual.font_size, visual.font_color, visual.font_family, false, false, anchor.anchor);
}

fn renderSvgNodeXLabel(writer: *Io.Writer, node_item: Node, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const label = attrValue(node_item.attrs.items, "xlabel") orelse return;
    const x = layout.center.x + layout.width / 2.0 + 10.0 + @as(f64, @floatFromInt(displayLabelMaxLineLen(label))) * visual.font_size * 0.18;
    const y = layout.center.y - layout.height / 2.0 - visual.font_size * 0.6;
    try renderSvgTextBlock(writer, label, x, y, visual.font_size, visual.font_color, visual.font_family, true, true);
}

const NodeLabelAnchor = struct {
    x: f64,
    anchor: []const u8,
};

fn nodeLabelAnchor(attrs: []const Attr, layout: NodeLayout, margin_x: f64) NodeLabelAnchor {
    const value = attrValue(attrs, "labeljust") orelse return .{ .x = layout.center.x, .anchor = "middle" };
    if (std.ascii.eqlIgnoreCase(value, "l")) {
        return .{ .x = layout.center.x - layout.width / 2.0 + margin_x + 4.0, .anchor = "start" };
    }
    if (std.ascii.eqlIgnoreCase(value, "r")) {
        return .{ .x = layout.center.x + layout.width / 2.0 - margin_x - 4.0, .anchor = "end" };
    }
    return .{ .x = layout.center.x, .anchor = "middle" };
}

fn nodeLabelY(attrs: []const Attr, layout: NodeLayout, margin_y: f64) f64 {
    const value = attrValue(attrs, "labelloc") orelse return layout.center.y;
    if (std.ascii.eqlIgnoreCase(value, "t")) return layout.center.y - layout.height / 2.0 + margin_y + 12.0;
    if (std.ascii.eqlIgnoreCase(value, "b")) return layout.center.y + layout.height / 2.0 - margin_y - 12.0;
    return layout.center.y;
}

fn endpointLabelPosition(endpoint: Point, toward: Point, distance: f64, angle_degrees: f64, head: bool) Point {
    const dx = toward.x - endpoint.x;
    const dy = toward.y - endpoint.y;
    const base = std.math.atan2(dy, dx);
    const side: f64 = if (head) -1.0 else 1.0;
    const angle = base + side * degreesToRadians(angle_degrees);
    const radius = 28.0 * distance;
    return .{
        .x = endpoint.x + std.math.cos(angle) * radius,
        .y = endpoint.y + std.math.sin(angle) * radius,
    };
}

fn edgeDecorateEnabled(attrs: []const Attr) bool {
    const value = attrValue(attrs, "decorate") orelse return false;
    return parseBool(value) orelse false;
}

fn distanceBetween(a: Point, b: Point) f64 {
    return std.math.hypot(a.x - b.x, a.y - b.y);
}

fn lerpPoint(a: Point, b: Point, t: f64) Point {
    return .{
        .x = a.x + (b.x - a.x) * t,
        .y = a.y + (b.y - a.y) * t,
    };
}

fn routeForPathMarkers(route: EdgeRoute, visual: EdgeVisual) EdgeRoute {
    var result = route;
    if (visual.marker_start != .none) {
        result.start = shortenPointToward(route.start, route.control1, 4.2 * visual.marker_scale);
        result.control1 = shortenPointToward(route.control1, route.control2, 2.0 * visual.marker_scale);
    }
    if (visual.marker_end != .none) {
        result.end = shortenPointToward(route.end, route.control2, 4.2 * visual.marker_scale);
        result.control2 = shortenPointToward(route.control2, route.control1, 2.0 * visual.marker_scale);
    }
    return result;
}

fn shortenPointToward(point: Point, toward: Point, amount: f64) Point {
    if (amount <= 0) return point;
    const dx = toward.x - point.x;
    const dy = toward.y - point.y;
    const len = std.math.hypot(dx, dy);
    if (len <= 0.001) return point;
    const shift = @min(amount, len * 0.5);
    return .{
        .x = point.x + dx / len * shift,
        .y = point.y + dy / len * shift,
    };
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

fn pathDataCommandCount(path_data: []const u8, command: u8) usize {
    var count: usize = 0;
    for (path_data) |c| {
        if (c == command) count += 1;
    }
    return count;
}

fn svgPathCommandCount(svg: []const u8, command: u8) usize {
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

fn svgCubicSegmentCount(fragment: []const u8) usize {
    if (svgPathCommandCount(fragment, 'C') == 0) return 0;
    var numbers: [128]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "d", numbers[0..]);
    if (count < 8) return 0;
    return (count - 2) / 6;
}

fn svgNumberAfter(fragment: []const u8, marker: []const u8) ?f64 {
    const start = std.mem.indexOf(u8, fragment, marker) orelse return null;
    const value_start = start + marker.len;
    const value_end_rel = std.mem.indexOfScalar(u8, fragment[value_start..], '"') orelse return null;
    return std.fmt.parseFloat(f64, fragment[value_start .. value_start + value_end_rel]) catch null;
}

fn svgGroupFragmentByTitle(svg: []const u8, title: []const u8) ?[]const u8 {
    var title_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&title_buf, "<title>{s}</title>", .{title}) catch return null;
    const title_pos = std.mem.indexOf(u8, svg, needle) orelse return null;
    const end_rel = std.mem.indexOf(u8, svg[title_pos..], "</g>") orelse return null;
    return svg[title_pos .. title_pos + end_rel];
}

const SvgTranslate = struct {
    x: f64 = 0,
    y: f64 = 0,
};

fn svgGraphvizTranslate(svg: []const u8) SvgTranslate {
    const marker = "translate(";
    var result = SvgTranslate{};
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

fn svgClusterRectWidth(svg: []const u8, title: []const u8) ?f64 {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return null;
    if (svgPolygonBBoxWidth(fragment)) |width| return width;
    return svgNumberAfter(fragment, " width=\"");
}

fn svgClusterRectX(svg: []const u8, title: []const u8) ?f64 {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return null;
    if (svgPolygonBBoxX(fragment)) |x| return x;
    return svgNumberAfter(fragment, " x=\"");
}

fn svgClusterScreenX(svg: []const u8, title: []const u8) ?f64 {
    const x = svgClusterRectX(svg, title) orelse return null;
    return x + svgGraphvizTranslate(svg).x;
}

fn svgPolygonBBoxX(fragment: []const u8) ?f64 {
    var point_numbers: [64]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2) return null;
    var min_x = std.math.floatMax(f64);
    var index: usize = 0;
    while (index + 1 < count) : (index += 2) min_x = @min(min_x, point_numbers[index]);
    return if (min_x == std.math.floatMax(f64)) null else min_x;
}

fn svgPolygonBBoxWidth(fragment: []const u8) ?f64 {
    var point_numbers: [64]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", point_numbers[0..]);
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

fn svgNodeCenterX(svg: []const u8, title: []const u8) ?f64 {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return null;
    if (svgNumberAfter(fragment, " cx=\"")) |cx| return cx;
    if (svgNumberAfter(fragment, " x=\"")) |x| {
        if (svgNumberAfter(fragment, " width=\"")) |width| return x + width / 2.0;
    }
    var point_numbers: [64]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", point_numbers[0..]);
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
    return (min_x + max_x) / 2.0;
}

fn svgNodeScreenCenterX(svg: []const u8, title: []const u8) ?f64 {
    const x = svgNodeCenterX(svg, title) orelse return null;
    return x + svgGraphvizTranslate(svg).x;
}

fn svgNumbersInAttribute(fragment: []const u8, attr_name: []const u8, out: []f64) usize {
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

fn svgPathNumbers(svg: []const u8, title: []const u8, out: []f64) usize {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return 0;
    return svgNumbersInAttribute(fragment, "d", out);
}

fn svgPathStartEnd(svg: []const u8, title: []const u8) ?struct { start: Point, end: Point } {
    var numbers: [64]f64 = undefined;
    const count = svgPathNumbers(svg, title, numbers[0..]);
    if (count < 4 or count % 2 != 0) return null;
    return .{
        .start = .{ .x = numbers[0], .y = numbers[1] },
        .end = .{ .x = numbers[count - 2], .y = numbers[count - 1] },
    };
}

fn renderedEdgePathCount(svg: []const u8) usize {
    return countSubstrings(svg, "class=\"edge\"") - countSubstrings(svg, "class=\"edges\"");
}

fn graphConcentrateEnabled(graph: *const Graph) bool {
    const value = attrValue(graph.attrs.items, "concentrate") orelse return false;
    return parseBool(value) orelse false;
}

fn isConcentratedDuplicateEdge(graph: *const Graph, edge_id: EdgeId) bool {
    const edge_item = graph.edges.items[edge_id];
    for (graph.edges.items[0..edge_id]) |candidate| {
        if (candidate.from == candidate.to or edge_item.from == edge_item.to) continue;
        if (graph.directed) {
            if (candidate.from == edge_item.from and candidate.to == edge_item.to) return true;
        } else {
            const same = candidate.from == edge_item.from and candidate.to == edge_item.to;
            const reverse = candidate.from == edge_item.to and candidate.to == edge_item.from;
            if (same or reverse) return true;
        }
    }
    return false;
}

const EdgeRoute = struct {
    start: Point,
    control1: Point,
    control2: Point,
    end: Point,
    label: Point,
};

const EdgeControls = struct {
    c1: Point,
    c2: Point,
};

const DashStyle = enum {
    none,
    dashed,
    dotted,
};

const MarkerShape = enum {
    none,
    normal,
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

const default_svg_font_family = "Times,serif";

const NodeVisual = struct {
    fill: []const u8,
    stroke: []const u8,
    font_color: []const u8,
    font_family: []const u8,
    font_size: f64,
    width: f64,
    radius: f64,
    dash: DashStyle,
    peripheries: usize,
    hidden: bool,
};

const EdgeVisual = struct {
    stroke: []const u8,
    font_color: []const u8,
    font_family: []const u8,
    font_size: f64,
    width: f64,
    dash: DashStyle,
    marker_start: MarkerShape,
    marker_end: MarkerShape,
    marker_scale: f64,
    hidden: bool,
};

const ClusterVisual = struct {
    fill: []const u8,
    stroke: []const u8,
    font_color: []const u8,
    font_family: []const u8,
    font_size: f64,
    width: f64,
    radius: f64,
    dash: DashStyle,
    fill_opacity: []const u8,
    hidden: bool,
};

fn renderSvgClusters(writer: *Io.Writer, graph: *const Graph, layout: *const Layout) Io.Writer.Error!void {
    if (graph.clusters.items.len == 0) return;
    try renderSvgClusterTree(writer, graph, layout, null);
}

fn renderSvgClusterTree(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, parent_name: ?[]const u8) Io.Writer.Error!void {
    for (graph.clusters.items, 0..) |cluster, index| {
        if (!clusterParentMatches(cluster.parent_name, parent_name)) continue;
        try renderSvgClusterBox(writer, cluster, layout, index);
        try renderSvgClusterTree(writer, graph, layout, cluster.name);
    }
}

fn clusterParentMatches(actual: ?[]const u8, expected: ?[]const u8) bool {
    if (actual == null and expected == null) return true;
    if (actual == null or expected == null) return false;
    return std.mem.eql(u8, actual.?, expected.?);
}

fn renderSvgClusterBox(writer: *Io.Writer, cluster: Cluster, layout: *const Layout, index: usize) Io.Writer.Error!void {
    if (index >= layout.clusters.len) return;
    const box = layout.clusters[index];
    if (box.width <= 0 or box.height <= 0) return;
    var visual = resolveClusterVisual(cluster);
    if (visual.hidden) return;
    try writer.print("<g id=\"clust{d}\" class=\"cluster\">\n", .{index + 1});
    try writeSvgTitle(writer, cluster.name);
    try writer.writeByte('\n');
    const rect = RectF{ .x = box.x, .y = box.y, .width = box.width, .height = box.height };
    if (try renderSvgStripedRectFill(writer, "vex-cluster-stripes", index + 1, cluster.attrs.items, rect, visual.radius, visual.fill)) {
        visual.fill = "none";
    } else {
        var fill_buf: [96]u8 = undefined;
        try resolveSvgGradientFill(writer, "vex-cluster-fill", index + 1, cluster.attrs.items, rect, &visual.fill, &fill_buf);
    }
    if (visual.radius <= 0.001) {
        try writer.print("<polygon fill=\"{s}\" stroke=\"{s}\" points=\"{d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1}\"", .{
            visual.fill,
            visual.stroke,
            box.x,
            box.y,
            box.x + box.width,
            box.y,
            box.x + box.width,
            box.y + box.height,
            box.x,
            box.y + box.height,
            box.x,
            box.y,
        });
        try writeSvgFillOpacity(writer, visual.fill_opacity);
        try writeSvgStrokeWidth(writer, visual.width);
        try writeSvgDash(writer, visual.dash);
        try writer.writeAll("/>\n");
    } else {
        try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"{d:.1}\" fill=\"{s}\" fill-opacity=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
            box.x,
            box.y,
            box.width,
            box.height,
            visual.radius,
            visual.fill,
            visual.fill_opacity,
            visual.stroke,
            visual.width,
        });
        try writeSvgDash(writer, visual.dash);
        try writer.writeAll("/>\n");
    }
    const label_just = attrValue(cluster.attrs.items, "labeljust");
    const label_loc = attrValue(cluster.attrs.items, "labelloc");
    const text_anchor: []const u8 = if (label_just) |value|
        if (std.ascii.eqlIgnoreCase(value, "l")) "start" else if (std.ascii.eqlIgnoreCase(value, "r")) "end" else "middle"
    else
        "middle";
    const label_x = if (std.mem.eql(u8, text_anchor, "start"))
        box.x + 12.0
    else if (std.mem.eql(u8, text_anchor, "end"))
        box.x + box.width - 12.0
    else
        box.x + box.width / 2.0;
    const top_label_offset: f64 = 15.3;
    const label_y = if (label_loc) |value|
        if (std.ascii.eqlIgnoreCase(value, "b")) box.y + box.height - 10.0 else box.y + top_label_offset
    else
        box.y + top_label_offset;
    try writer.print("<text xml:space=\"preserve\" text-anchor=\"{s}\" x=\"{d:.1}\" y=\"{d:.1}\" font-family=\"{s}\" font-size=\"{d:.2}\"", .{
        text_anchor,
        label_x,
        label_y,
        visual.font_family,
        visual.font_size,
    });
    try writeSvgTextFill(writer, visual.font_color);
    try writer.writeAll(">");
    try writeXmlEscaped(writer, cluster.label);
    try writer.writeAll("</text>\n");
    try writer.writeAll("</g>\n");
}

fn writeSvgFillOpacity(writer: *Io.Writer, opacity: []const u8) Io.Writer.Error!void {
    if (std.mem.eql(u8, opacity, "1.0") or std.mem.eql(u8, opacity, "1") or std.mem.eql(u8, opacity, "1.00")) return;
    try writer.print(" fill-opacity=\"{s}\"", .{opacity});
}

fn writeSvgStrokeWidth(writer: *Io.Writer, width: f64) Io.Writer.Error!void {
    if (@abs(width - 1.0) <= 0.0001) return;
    try writer.print(" stroke-width=\"{d:.1}\"", .{width});
}

fn renderSvgHtmlTableLabel(writer: *Io.Writer, label: []const u8, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const metrics = htmlTableMetrics(label) orelse return;
    const grid = htmlTableGrid(label, layout) orelse return;
    const fill = metrics.bg_color orelse visual.fill;
    const table_tag = htmlTableOpenTag(label);
    const table_invisible = if (table_tag) |tag| htmlStyleHas(tag, "invis") or htmlStyleHas(tag, "invisible") else false;
    const table_stroke = if (table_tag) |tag| htmlAttrValue(tag, "color") orelse visual.stroke else visual.stroke;
    const table_dash = if (table_tag) |tag| htmlDashStyle(tag) else .none;

    if (!table_invisible) {
        try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
            grid.x,
            grid.y,
            layout.width,
            layout.height,
            visual.radius,
            fill,
            if (metrics.border > 0) table_stroke else "none",
            metrics.border,
        });
        try writeSvgDash(writer, table_dash);
        try writer.writeAll("/>\n");
    }

    var row_pos: usize = 0;
    var row_index: usize = 0;
    var occupied: [32]usize = @splat(0);
    while (findHtmlTag(label, "tr", row_pos)) |tr_start| : (row_index += 1) {
        if (row_index > 0) {
            for (&occupied) |*remaining| {
                if (remaining.* > 0) remaining.* -= 1;
            }
        }
        const tr_open_end = std.mem.indexOfScalar(u8, label[tr_start..], '>') orelse break;
        const content_start = tr_start + tr_open_end + 1;
        const tr_close = findHtmlCloseTag(label, "tr", content_start) orelse break;
        const row = label[content_start..tr_close];
        var cell_pos: usize = 0;
        var col_index: usize = 0;
        while (findHtmlTag(row, "td", cell_pos)) |td_start| : (col_index += 1) {
            col_index = nextFreeHtmlColumn(&occupied, col_index);
            const td_open_end = std.mem.indexOfScalar(u8, row[td_start..], '>') orelse break;
            const td_tag = row[td_start + 1 .. td_start + td_open_end];
            const cell_start = td_start + td_open_end + 1;
            const td_close = findHtmlCloseTag(row, "td", cell_start) orelse break;
            const colspan = @max(htmlIntAttr(td_tag, "colspan", 1), 1);
            const rowspan = @max(htmlIntAttr(td_tag, "rowspan", 1), 1);
            const cell_rect = htmlGridCellRect(grid, row_index, col_index, rowspan, colspan);
            var span_i: usize = 0;
            while (span_i < colspan and col_index + span_i < occupied.len) : (span_i += 1) {
                occupied[col_index + span_i] = @max(occupied[col_index + span_i], rowspan);
            }
            const cell_border: f64 = @floatFromInt(htmlIntAttr(td_tag, "cellborder", @intFromFloat(metrics.cell_border)));
            const cell_padding: f64 = @floatFromInt(htmlIntAttr(td_tag, "cellpadding", @intFromFloat(metrics.cell_padding)));
            const cell = row[cell_start..td_close];
            const align_attr = htmlAttrValue(td_tag, "align");
            const text_anchor: []const u8 = if (align_attr) |value|
                if (std.ascii.eqlIgnoreCase(value, "left")) "start" else if (std.ascii.eqlIgnoreCase(value, "right")) "end" else "middle"
            else
                "middle";
            const text_x = if (std.mem.eql(u8, text_anchor, "start"))
                cell_rect.x + cell_padding
            else if (std.mem.eql(u8, text_anchor, "end"))
                cell_rect.x + cell_rect.width - cell_padding
            else
                cell_rect.x + cell_rect.width / 2.0;
            const valign_attr = htmlAttrValue(td_tag, "valign");
            const text_y = if (valign_attr) |value|
                if (std.ascii.eqlIgnoreCase(value, "top"))
                    cell_rect.y + cell_padding + visual.font_size * 0.5
                else if (std.ascii.eqlIgnoreCase(value, "bottom"))
                    cell_rect.y + cell_rect.height - cell_padding - visual.font_size * 0.5
                else
                    cell_rect.y + cell_rect.height / 2.0
            else
                cell_rect.y + cell_rect.height / 2.0;
            const cell_invisible = htmlStyleHas(td_tag, "invis") or htmlStyleHas(td_tag, "invisible");
            if (!table_invisible and !cell_invisible) {
                if (htmlAttrValue(td_tag, "bgcolor")) |cell_bg| {
                    try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" fill=\"{s}\" stroke=\"none\"/>\n", .{ cell_rect.x, cell_rect.y, cell_rect.width, cell_rect.height, cell_bg });
                }
                if (cell_border > 0) {
                    const cell_stroke = htmlAttrValue(td_tag, "color") orelse visual.stroke;
                    try renderSvgHtmlCellBorder(writer, cell_rect, htmlCellSides(td_tag), cell_stroke, cell_border, htmlDashStyle(td_tag));
                }
                try renderSvgTextBlockWithAnchor(
                    writer,
                    cell,
                    text_x,
                    text_y,
                    visual.font_size,
                    visual.font_color,
                    visual.font_family,
                    false,
                    true,
                    text_anchor,
                );
            }
            cell_pos = td_close + 1;
            col_index += colspan - 1;
        }
        row_pos = tr_close + 1;
    }
}

fn renderSvgHtmlCellBorder(writer: *Io.Writer, rect: RectF, maybe_sides: ?HtmlCellSides, stroke: []const u8, width: f64, dash: DashStyle) Io.Writer.Error!void {
    const sides = maybe_sides orelse {
        try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
            rect.x,
            rect.y,
            rect.width,
            rect.height,
            stroke,
            width,
        });
        try writeSvgDash(writer, dash);
        try writer.writeAll("/>\n");
        return;
    };

    if (sides.top) try writeSvgBorderLine(writer, rect.x, rect.y, rect.x + rect.width, rect.y, stroke, width, dash);
    if (sides.right) try writeSvgBorderLine(writer, rect.x + rect.width, rect.y, rect.x + rect.width, rect.y + rect.height, stroke, width, dash);
    if (sides.bottom) try writeSvgBorderLine(writer, rect.x, rect.y + rect.height, rect.x + rect.width, rect.y + rect.height, stroke, width, dash);
    if (sides.left) try writeSvgBorderLine(writer, rect.x, rect.y, rect.x, rect.y + rect.height, stroke, width, dash);
}

fn writeSvgBorderLine(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, stroke: []const u8, width: f64, dash: DashStyle) Io.Writer.Error!void {
    try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        x1,
        y1,
        x2,
        y2,
        stroke,
        width,
    });
    try writeSvgDash(writer, dash);
    try writer.writeAll("/>\n");
}

fn renderSvgNodeShape(writer: *Io.Writer, node_item: Node, layout: NodeLayout, visual: NodeVisual, options: SvgOptions) Io.Writer.Error!void {
    const shape_layout = fixedShapeLayout(node_item, layout);
    switch (node_item.shape) {
        .point => {
            try writer.print("<circle cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"/>\n", .{
                shape_layout.center.x,
                shape_layout.center.y,
                @min(shape_layout.width, shape_layout.height) / 2.0,
                visual.stroke,
                visual.stroke,
                visual.width,
            });
        },
        .box, .square, .msquare => {
            var ring: usize = 0;
            while (ring < visual.peripheries) : (ring += 1) {
                const inset = @as(f64, @floatFromInt(ring)) * 5.0;
                const rect = RectF{
                    .x = shape_layout.center.x - shape_layout.width / 2.0 + inset,
                    .y = shape_layout.center.y - shape_layout.height / 2.0 + inset,
                    .width = @max(1, shape_layout.width - inset * 2.0),
                    .height = @max(1, shape_layout.height - inset * 2.0),
                };
                const radius = @max(0, visual.radius - inset / 2.0);
                var ring_visual = visual;
                if (ring > 0) ring_visual.fill = "none";
                if (node_item.shape == .msquare and radius <= 0.001) {
                    try renderSvgRectPolygon(writer, rect, ring_visual);
                } else {
                    try renderSvgBoxShape(writer, rect, ring_visual, radius);
                }
            }
            if (node_item.shape == .msquare) try renderSvgCornerDiagonals(writer, shape_layout, visual);
        },
        .circle, .doublecircle, .mcircle => {
            var ring: usize = 0;
            const ring_count = if (node_item.shape == .doublecircle) @max(visual.peripheries, 2) else visual.peripheries;
            while (ring < ring_count) : (ring += 1) {
                const inset = @as(f64, @floatFromInt(ring)) * 5.0;
                try writer.print("<circle cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
                    shape_layout.center.x,
                    shape_layout.center.y,
                    @max(1, @min(shape_layout.width, shape_layout.height) / 2.0 - inset),
                    if (ring == 0) visual.fill else "none",
                    visual.stroke,
                    visual.width,
                });
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            }
            if (node_item.shape == .mcircle) try renderSvgCircleDiagonals(writer, shape_layout, visual);
        },
        .ellipse => {
            var ring: usize = 0;
            while (ring < visual.peripheries) : (ring += 1) {
                const inset = @as(f64, @floatFromInt(ring)) * 5.0;
                try writer.print("<ellipse fill=\"{s}\" stroke=\"{s}\" cx=\"{d:.1}\" cy=\"{d:.1}\" rx=\"{d:.1}\" ry=\"{d:.1}\"", .{
                    if (ring == 0) visual.fill else "none",
                    visual.stroke,
                    shape_layout.center.x,
                    shape_layout.center.y,
                    @max(1, shape_layout.width / 2.0 - inset),
                    @max(1, shape_layout.height / 2.0 - inset),
                });
                try writeSvgStrokeWidth(writer, visual.width);
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            }
        },
        .egg => try renderSvgEggShape(writer, shape_layout, visual),
        .polygon => try renderSvgCustomPolygon(writer, node_item, shape_layout, visual),
        .diamond => try renderSvgPolygonRings(6, writer, shape_layout, visual, diamondPoints),
        .mdiamond => {
            try renderSvgPolygonRings(6, writer, shape_layout, visual, diamondPoints);
            try renderSvgDiamondDiagonals(writer, shape_layout, visual);
        },
        .triangle => try renderSvgPolygonRings(6, writer, shape_layout, visual, trianglePoints),
        .invtriangle => try renderSvgPolygonRings(6, writer, shape_layout, visual, invTrianglePoints),
        .parallelogram => try renderSvgPolygonRings(6, writer, shape_layout, visual, parallelogramPoints),
        .trapezium => try renderSvgPolygonRings(6, writer, shape_layout, visual, trapeziumPoints),
        .invtrapezium => try renderSvgPolygonRings(6, writer, shape_layout, visual, invTrapeziumPoints),
        .house => try renderSvgPolygonRings(6, writer, shape_layout, visual, housePoints),
        .invhouse => try renderSvgPolygonRings(6, writer, shape_layout, visual, invHousePoints),
        .pentagon => try renderSvgPolygonRings(5, writer, shape_layout, visual, pentagonPoints),
        .hexagon => try renderSvgPolygonRings(6, writer, shape_layout, visual, hexagonPoints),
        .septagon => try renderSvgPolygonRings(7, writer, shape_layout, visual, septagonPoints),
        .octagon => try renderSvgPolygonRings(8, writer, shape_layout, visual, octagonPoints),
        .doubleoctagon, .tripleoctagon => {
            var ring_visual = visual;
            const default_peripheries: usize = if (node_item.shape == .tripleoctagon) 3 else 2;
            ring_visual.peripheries = @max(visual.peripheries, default_peripheries);
            try renderSvgPolygonRings(8, writer, shape_layout, ring_visual, octagonPoints);
        },
        .star => try renderSvgPolygonRings(10, writer, shape_layout, visual, starPoints),
        .note => try renderSvgNoteShape(writer, shape_layout, visual),
        .tab => try renderSvgTabShape(writer, shape_layout, visual),
        .folder => try renderSvgFolderShape(writer, shape_layout, visual),
        .box3d => try renderSvgBox3dShape(writer, shape_layout, visual),
        .component => try renderSvgComponentShape(writer, shape_layout, visual),
        .underline => try renderSvgUnderlineShape(writer, shape_layout, visual),
        .cylinder => try renderSvgCylinderShape(writer, shape_layout, visual),
        .plaintext => {},
        .record => try renderSvgRecordNode(writer, node_item.label, shape_layout, visual, options, false),
        .mrecord => try renderSvgRecordNode(writer, node_item.label, shape_layout, visual, options, true),
    }
}

fn fixedShapeLayout(node_item: Node, layout: NodeLayout) NodeLayout {
    if (fixedsizeMode(node_item.attrs.items) != .shape) return layout;
    const width = if (attrValue(node_item.attrs.items, "width")) |value|
        parseInchDimension(value) orelse layout.width
    else
        layout.width;
    const height = if (attrValue(node_item.attrs.items, "height")) |value|
        parseInchDimension(value) orelse layout.height
    else
        layout.height;
    return .{
        .center = layout.center,
        .width = @min(layout.width, width),
        .height = @min(layout.height, height),
    };
}

fn renderSvgPolygon(writer: *Io.Writer, points: []const Point, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<polygon fill=\"{s}\" stroke=\"{s}\" points=\"", .{ visual.fill, visual.stroke });
    var written: usize = 0;
    for (points) |point| {
        if (point.x < 0 and point.y < 0) continue;
        if (written > 0) try writer.writeByte(' ');
        try writer.print("{d:.1},{d:.1}", .{ point.x, point.y });
        written += 1;
    }
    try writer.writeByte('"');
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn renderSvgPolygonRings(comptime N: usize, writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual, pointsFn: fn (NodeLayout) [N]Point) Io.Writer.Error!void {
    var ring: usize = 0;
    while (ring < visual.peripheries) : (ring += 1) {
        const inset = @as(f64, @floatFromInt(ring)) * 5.0;
        const ring_layout = NodeLayout{
            .center = layout.center,
            .width = @max(1, layout.width - inset * 2.0),
            .height = @max(1, layout.height - inset * 2.0),
        };
        var ring_visual = visual;
        if (ring > 0) ring_visual.fill = "none";
        const points = pointsFn(ring_layout);
        try renderSvgPolygon(writer, &points, ring_visual);
    }
}

const CustomPolygon = struct {
    sides: usize,
    regular: bool,
    orientation_deg: f64,
    skew: f64,
    distortion: f64,
};

fn customPolygonFromAttrs(attrs: []const Attr) CustomPolygon {
    const raw_sides = parseAttrUsize(attrs, "sides", 4);
    const regular = if (attrValue(attrs, "regular")) |value| parseBool(value) orelse false else false;
    return .{
        .sides = std.math.clamp(raw_sides, 3, 32),
        .regular = regular,
        .orientation_deg = parseAttrFloat(attrs, "orientation", 0.0),
        .skew = std.math.clamp(parseAttrFloat(attrs, "skew", 0.0), -4.0, 4.0),
        .distortion = std.math.clamp(parseAttrFloat(attrs, "distortion", 0.0), -4.0, 4.0),
    };
}

fn renderSvgCustomPolygon(writer: *Io.Writer, node_item: Node, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const spec = customPolygonFromAttrs(node_item.attrs.items);
    var ring: usize = 0;
    while (ring < visual.peripheries) : (ring += 1) {
        const inset = @as(f64, @floatFromInt(ring)) * 5.0;
        const ring_layout = NodeLayout{
            .center = layout.center,
            .width = @max(1, layout.width - inset * 2.0),
            .height = @max(1, layout.height - inset * 2.0),
        };
        var points: [32]Point = undefined;
        customPolygonPoints(spec, ring_layout, &points);
        var ring_visual = visual;
        if (ring > 0) ring_visual.fill = "none";
        try renderSvgPolygon(writer, points[0..spec.sides], ring_visual);
    }
}

fn customPolygonPoints(spec: CustomPolygon, layout: NodeLayout, points: *[32]Point) void {
    const width = if (spec.regular) @max(layout.width, layout.height) else layout.width;
    const height = if (spec.regular) @max(layout.width, layout.height) else layout.height;
    const sector = 2.0 * std.math.pi / @as(f64, @floatFromInt(spec.sides));
    const side_len = std.math.sin(sector / 2.0);
    const skew_dist = std.math.hypot(@abs(spec.distortion) + @abs(spec.skew), 1.0);
    const g_distortion = spec.distortion * std.math.sqrt2 / std.math.cos(sector / 2.0);
    const g_skew = spec.skew / 2.0;
    var angle = (sector - std.math.pi) / 2.0;
    var r = Point{ .x = 0.5 * std.math.cos(angle), .y = 0.5 * std.math.sin(angle) };
    angle += (std.math.pi - sector) / 2.0;
    const orientation = degreesToRadians(spec.orientation_deg);

    var max_x: f64 = 0;
    var max_y: f64 = 0;
    var raw: [32]Point = undefined;
    for (0..spec.sides) |i| {
        angle += sector;
        r.x += side_len * std.math.cos(angle);
        r.y += side_len * std.math.sin(angle);

        var p = Point{
            .x = r.x * (skew_dist + r.y * g_distortion) + r.y * g_skew,
            .y = r.y,
        };
        const rotated_angle = orientation + std.math.atan2(p.y, p.x);
        const magnitude = std.math.hypot(p.x, p.y);
        p = .{
            .x = magnitude * std.math.cos(rotated_angle),
            .y = magnitude * std.math.sin(rotated_angle),
        };
        raw[i] = p;
        max_x = @max(max_x, @abs(p.x));
        max_y = @max(max_y, @abs(p.y));
    }

    const scale_x = if (max_x > 0) (width / 2.0) / max_x else 1.0;
    const scale_y = if (max_y > 0) (height / 2.0) / max_y else 1.0;
    for (0..spec.sides) |i| {
        points[i] = .{
            .x = layout.center.x + raw[i].x * scale_x,
            .y = layout.center.y + raw[i].y * scale_y,
        };
    }
}

fn degreesToRadians(degrees: f64) f64 {
    return degrees * std.math.pi / 180.0;
}

fn diamondPoints(layout: NodeLayout) [6]Point {
    const cx = layout.center.x;
    const cy = layout.center.y;
    const hw = layout.width / 2.0;
    const hh = layout.height / 2.0;
    return .{
        .{ .x = cx, .y = cy - hh },
        .{ .x = cx + hw, .y = cy },
        .{ .x = cx, .y = cy + hh },
        .{ .x = cx - hw, .y = cy },
        .{ .x = -1, .y = -1 },
        .{ .x = -1, .y = -1 },
    };
}

fn trianglePoints(layout: NodeLayout) [6]Point {
    const cx = layout.center.x;
    const left = layout.center.x - layout.width / 2.0;
    const right = layout.center.x + layout.width / 2.0;
    const top = layout.center.y - layout.height / 2.0;
    const bottom = layout.center.y + layout.height / 2.0;
    return .{
        .{ .x = cx, .y = top },
        .{ .x = right, .y = bottom },
        .{ .x = left, .y = bottom },
        .{ .x = -1, .y = -1 },
        .{ .x = -1, .y = -1 },
        .{ .x = -1, .y = -1 },
    };
}

fn invTrianglePoints(layout: NodeLayout) [6]Point {
    const cx = layout.center.x;
    const left = layout.center.x - layout.width / 2.0;
    const right = layout.center.x + layout.width / 2.0;
    const top = layout.center.y - layout.height / 2.0;
    const bottom = layout.center.y + layout.height / 2.0;
    return .{
        .{ .x = left, .y = top },
        .{ .x = right, .y = top },
        .{ .x = cx, .y = bottom },
        .{ .x = -1, .y = -1 },
        .{ .x = -1, .y = -1 },
        .{ .x = -1, .y = -1 },
    };
}

fn parallelogramPoints(layout: NodeLayout) [6]Point {
    const left = layout.center.x - layout.width / 2.0;
    const right = layout.center.x + layout.width / 2.0;
    const top = layout.center.y - layout.height / 2.0;
    const bottom = layout.center.y + layout.height / 2.0;
    const skew = @min(layout.width * 0.18, 28);
    return .{
        .{ .x = left + skew, .y = top },
        .{ .x = right, .y = top },
        .{ .x = right - skew, .y = bottom },
        .{ .x = left, .y = bottom },
        .{ .x = -1, .y = -1 },
        .{ .x = -1, .y = -1 },
    };
}

fn trapeziumPoints(layout: NodeLayout) [6]Point {
    const left = layout.center.x - layout.width / 2.0;
    const right = layout.center.x + layout.width / 2.0;
    const top = layout.center.y - layout.height / 2.0;
    const bottom = layout.center.y + layout.height / 2.0;
    const inset = @min(layout.width * 0.18, 28);
    return .{
        .{ .x = left + inset, .y = top },
        .{ .x = right - inset, .y = top },
        .{ .x = right, .y = bottom },
        .{ .x = left, .y = bottom },
        .{ .x = -1, .y = -1 },
        .{ .x = -1, .y = -1 },
    };
}

fn invTrapeziumPoints(layout: NodeLayout) [6]Point {
    const left = layout.center.x - layout.width / 2.0;
    const right = layout.center.x + layout.width / 2.0;
    const top = layout.center.y - layout.height / 2.0;
    const bottom = layout.center.y + layout.height / 2.0;
    const inset = @min(layout.width * 0.18, 28);
    return .{
        .{ .x = left, .y = top },
        .{ .x = right, .y = top },
        .{ .x = right - inset, .y = bottom },
        .{ .x = left + inset, .y = bottom },
        .{ .x = -1, .y = -1 },
        .{ .x = -1, .y = -1 },
    };
}

fn housePoints(layout: NodeLayout) [6]Point {
    const cx = layout.center.x;
    const left = layout.center.x - layout.width / 2.0;
    const right = layout.center.x + layout.width / 2.0;
    const top = layout.center.y - layout.height / 2.0;
    const bottom = layout.center.y + layout.height / 2.0;
    const shoulder = top + layout.height * 0.36;
    return .{
        .{ .x = cx, .y = top },
        .{ .x = right, .y = shoulder },
        .{ .x = right, .y = bottom },
        .{ .x = left, .y = bottom },
        .{ .x = left, .y = shoulder },
        .{ .x = -1, .y = -1 },
    };
}

fn invHousePoints(layout: NodeLayout) [6]Point {
    const cx = layout.center.x;
    const left = layout.center.x - layout.width / 2.0;
    const right = layout.center.x + layout.width / 2.0;
    const top = layout.center.y - layout.height / 2.0;
    const bottom = layout.center.y + layout.height / 2.0;
    const shoulder = bottom - layout.height * 0.36;
    return .{
        .{ .x = left, .y = top },
        .{ .x = right, .y = top },
        .{ .x = right, .y = shoulder },
        .{ .x = cx, .y = bottom },
        .{ .x = left, .y = shoulder },
        .{ .x = -1, .y = -1 },
    };
}

fn pentagonPoints(layout: NodeLayout) [5]Point {
    return regularPolygonPoints(5, layout, -std.math.pi / 2.0);
}

fn hexagonPoints(layout: NodeLayout) [6]Point {
    const left = layout.center.x - layout.width / 2.0;
    const right = layout.center.x + layout.width / 2.0;
    const top = layout.center.y - layout.height / 2.0;
    const bottom = layout.center.y + layout.height / 2.0;
    const inset = @min(layout.width * 0.22, 32);
    const cy = layout.center.y;
    return .{
        .{ .x = left + inset, .y = top },
        .{ .x = right - inset, .y = top },
        .{ .x = right, .y = cy },
        .{ .x = right - inset, .y = bottom },
        .{ .x = left + inset, .y = bottom },
        .{ .x = left, .y = cy },
    };
}

fn septagonPoints(layout: NodeLayout) [7]Point {
    return regularPolygonPoints(7, layout, -std.math.pi / 2.0);
}

fn octagonPoints(layout: NodeLayout) [8]Point {
    const left = layout.center.x - layout.width / 2.0;
    const right = layout.center.x + layout.width / 2.0;
    const top = layout.center.y - layout.height / 2.0;
    const bottom = layout.center.y + layout.height / 2.0;
    const inset = @min(@min(layout.width, layout.height) * 0.28, 24);
    return .{
        .{ .x = left + inset, .y = top },
        .{ .x = right - inset, .y = top },
        .{ .x = right, .y = top + inset },
        .{ .x = right, .y = bottom - inset },
        .{ .x = right - inset, .y = bottom },
        .{ .x = left + inset, .y = bottom },
        .{ .x = left, .y = bottom - inset },
        .{ .x = left, .y = top + inset },
    };
}

fn regularPolygonPoints(comptime N: usize, layout: NodeLayout, rotation: f64) [N]Point {
    const rx = layout.width / 2.0;
    const ry = layout.height / 2.0;
    var points: [N]Point = undefined;
    inline for (0..N) |i| {
        const angle = rotation + @as(f64, @floatFromInt(i)) * 2.0 * std.math.pi / @as(f64, @floatFromInt(N));
        points[i] = .{
            .x = layout.center.x + std.math.cos(angle) * rx,
            .y = layout.center.y + std.math.sin(angle) * ry,
        };
    }
    return points;
}

fn starPoints(layout: NodeLayout) [10]Point {
    const rx = layout.width / 2.0;
    const ry = layout.height / 2.0;
    var points: [10]Point = undefined;
    inline for (0..10) |i| {
        const outer = (i % 2) == 0;
        const scale: f64 = if (outer) 1.0 else 0.42;
        const angle = -std.math.pi / 2.0 + @as(f64, @floatFromInt(i)) * std.math.pi / 5.0;
        points[i] = .{
            .x = layout.center.x + std.math.cos(angle) * rx * scale,
            .y = layout.center.y + std.math.sin(angle) * ry * scale,
        };
    }
    return points;
}

fn renderSvgEggShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    var ring: usize = 0;
    while (ring < visual.peripheries) : (ring += 1) {
        const inset = @as(f64, @floatFromInt(ring)) * 5.0;
        const rx = @max(1, layout.width / 2.0 - inset);
        const ry = @max(1, layout.height / 2.0 - inset);
        const cx = layout.center.x;
        const cy = layout.center.y;
        const top = cy - ry;
        const bottom = cy + ry;
        const upper_rx = rx * 0.78;
        const lower_rx = rx;
        var ring_visual = visual;
        if (ring > 0) ring_visual.fill = "none";
        try writer.print("<path d=\"M {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1} Z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
            cx,
            top,
            cx + upper_rx,
            top,
            cx + lower_rx,
            cy + ry * 0.22,
            cx + lower_rx * 0.72,
            cy + ry * 0.78,
            cx + lower_rx * 0.42,
            bottom,
            cx - lower_rx * 0.42,
            bottom,
            cx - lower_rx * 0.72,
            cy + ry * 0.78,
            cx - lower_rx,
            cy + ry * 0.22,
            cx - upper_rx,
            top,
            cx,
            top,
            ring_visual.fill,
            ring_visual.stroke,
            ring_visual.width,
        });
        try writeSvgDash(writer, ring_visual.dash);
        try writer.writeAll("/>\n");
    }
}

fn renderSvgDiamondDiagonals(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const cx = layout.center.x;
    const cy = layout.center.y;
    const hw = layout.width / 2.0;
    const hh = layout.height / 2.0;
    const inner_x = hw * 0.72;
    const inner_y = hh * 0.72;
    const short_y = hh * 0.28;
    const short_x = hw * 0.28;
    try writeSvgPolylineLine(writer, cx - inner_x, cy - short_y, cx - inner_x, cy + short_y, visual);
    try writeSvgPolylineLine(writer, cx - short_x, cy + inner_y, cx + short_x, cy + inner_y, visual);
    try writeSvgPolylineLine(writer, cx + inner_x, cy + short_y, cx + inner_x, cy - short_y, visual);
    try writeSvgPolylineLine(writer, cx + short_x, cy - inner_y, cx - short_x, cy - inner_y, visual);
}

fn renderSvgCornerDiagonals(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const d = @min(@min(rect.width, rect.height) / 3.0, 18);
    try writeSvgPolylineLine(writer, rect.x, rect.y + d, rect.x + d, rect.y, visual);
    try writeSvgPolylineLine(writer, rect.x + rect.width - d, rect.y, rect.x + rect.width, rect.y + d, visual);
    try writeSvgPolylineLine(writer, rect.x + rect.width, rect.y + rect.height - d, rect.x + rect.width - d, rect.y + rect.height, visual);
    try writeSvgPolylineLine(writer, rect.x + d, rect.y + rect.height, rect.x, rect.y + rect.height - d, visual);
}

fn renderSvgCircleDiagonals(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const r = @min(layout.width, layout.height) / 2.0;
    const d = r * 0.62;
    try writeSvgLine(writer, layout.center.x - d, layout.center.y - d, layout.center.x + d, layout.center.y + d, visual);
    try writeSvgLine(writer, layout.center.x + d, layout.center.y - d, layout.center.x - d, layout.center.y + d, visual);
}

fn renderSvgNoteShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const fold = @min(@min(rect.width, rect.height) * 0.24, 22);
    try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} Z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        rect.x,
        rect.y,
        rect.x + rect.width - fold,
        rect.y,
        rect.x + rect.width,
        rect.y + fold,
        rect.x + rect.width,
        rect.y + rect.height,
        rect.x,
        rect.y + rect.height,
        visual.fill,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
    try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        rect.x + rect.width - fold,
        rect.y,
        rect.x + rect.width - fold,
        rect.y + fold,
        rect.x + rect.width,
        rect.y + fold,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn renderSvgTabShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const tab_w = @min(rect.width * 0.42, 52);
    const tab_h = @min(rect.height * 0.28, 18);
    try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} Z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        rect.x,
        rect.y + tab_h,
        rect.x + tab_w * 0.18,
        rect.y + tab_h,
        rect.x + tab_w * 0.18,
        rect.y,
        rect.x + tab_w,
        rect.y,
        rect.x + tab_w,
        rect.y + tab_h,
        rect.x + rect.width,
        rect.y + tab_h,
        rect.x + rect.width,
        rect.y + rect.height,
        rect.x,
        rect.y + rect.height,
        visual.fill,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
    try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        rect.x + tab_w,
        rect.y + tab_h,
        rect.x + tab_w * 0.18,
        rect.y + tab_h,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn renderSvgFolderShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const tab_w = @min(rect.width * 0.46, 64);
    const tab_h = @min(rect.height * 0.28, 18);
    const slope = @min(tab_h * 0.7, 10);
    try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} Z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        rect.x,
        rect.y + tab_h,
        rect.x + tab_w * 0.28,
        rect.y + tab_h,
        rect.x + tab_w * 0.42,
        rect.y,
        rect.x + tab_w,
        rect.y,
        rect.x + tab_w + slope,
        rect.y + tab_h,
        rect.x + rect.width,
        rect.y + tab_h,
        rect.x + rect.width,
        rect.y + rect.height,
        rect.x,
        rect.y + rect.height,
        visual.fill,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn renderSvgBox3dShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const depth = @min(@min(rect.width, rect.height) * 0.18, 18);
    try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} Z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        rect.x,
        rect.y + depth,
        rect.x + depth,
        rect.y,
        rect.x + rect.width,
        rect.y,
        rect.x + rect.width,
        rect.y + rect.height - depth,
        rect.x + rect.width - depth,
        rect.y + rect.height,
        rect.x,
        rect.y + rect.height,
        visual.fill,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
    try writeSvgLine(writer, rect.x + depth, rect.y, rect.x + depth, rect.y + rect.height - depth, visual);
    try writeSvgLine(writer, rect.x + depth, rect.y + rect.height - depth, rect.x, rect.y + rect.height, visual);
    try writeSvgLine(writer, rect.x + depth, rect.y + rect.height - depth, rect.x + rect.width, rect.y + rect.height - depth, visual);
}

fn renderSvgComponentShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    try renderSvgBoxShape(writer, rect, visual, 0);
    const tab_w = @min(rect.width * 0.22, 24);
    const tab_h = @min(rect.height * 0.18, 14);
    const x = rect.x - tab_w * 0.35;
    const y1 = rect.y + rect.height * 0.25;
    const y2 = rect.y + rect.height * 0.62;
    try renderSvgComponentTab(writer, x, y1, tab_w, tab_h, visual);
    try renderSvgComponentTab(writer, x, y2, tab_w, tab_h, visual);
}

fn renderSvgUnderlineShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    try writeSvgLine(writer, rect.x, rect.y + rect.height, rect.x + rect.width, rect.y + rect.height, visual);
}

fn renderSvgCylinderShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const ry = @min(rect.height * 0.22, 18);
    const left = rect.x;
    const right = rect.x + rect.width;
    const top = rect.y;
    const bottom = rect.y + rect.height;
    try writer.print("<path d=\"M {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1} L {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1} Z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        left,
        top + ry,
        left,
        top,
        right,
        top,
        right,
        top + ry,
        right,
        bottom - ry,
        right,
        bottom,
        left,
        bottom,
        left,
        bottom - ry,
        visual.fill,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
    try writer.print("<path d=\"M {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        left,
        top + ry,
        left,
        top + ry * 2.0,
        right,
        top + ry * 2.0,
        right,
        top + ry,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn renderSvgBoxShape(writer: *Io.Writer, rect: RectF, visual: NodeVisual, radius: f64) Io.Writer.Error!void {
    try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        rect.x,
        rect.y,
        rect.width,
        rect.height,
        radius,
        visual.fill,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn renderSvgRectPolygon(writer: *Io.Writer, rect: RectF, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<polygon fill=\"{s}\" stroke=\"{s}\" points=\"{d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1}\"", .{
        visual.fill,
        visual.stroke,
        rect.x,
        rect.y,
        rect.x + rect.width,
        rect.y,
        rect.x + rect.width,
        rect.y + rect.height,
        rect.x,
        rect.y + rect.height,
        rect.x,
        rect.y,
    });
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn renderSvgComponentTab(writer: *Io.Writer, x: f64, y: f64, width: f64, height: f64, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        x + width,
        y,
        x,
        y,
        x,
        y + height,
        x + width,
        y + height,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn writeSvgLine(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        x1,
        y1,
        x2,
        y2,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn writeSvgPolylineLine(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<polyline fill=\"none\" stroke=\"{s}\" points=\"{d:.1},{d:.1} {d:.1},{d:.1}\"", .{
        visual.stroke,
        x1,
        y1,
        x2,
        y2,
    });
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn nodeRect(layout: NodeLayout) RectF {
    return .{
        .x = layout.center.x - layout.width / 2.0,
        .y = layout.center.y - layout.height / 2.0,
        .width = layout.width,
        .height = layout.height,
    };
}

fn renderSvgRecordNode(writer: *Io.Writer, label: []const u8, layout: NodeLayout, visual: NodeVisual, options: SvgOptions, rounded: bool) Io.Writer.Error!void {
    const x = layout.center.x - layout.width / 2.0;
    const y = layout.center.y - layout.height / 2.0;
    try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
        x,
        y,
        layout.width,
        layout.height,
        if (rounded) 10 else visual.radius,
        visual.fill,
        visual.stroke,
        visual.width,
    });
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");

    var arena = RecordArena{};
    var parser = RecordParser{ .label = label, .arena = &arena };
    const root = parser.parseRecord(.horizontal) orelse return;
    try renderRecordFields(writer, root, .{ .x = x, .y = y, .width = layout.width, .height = layout.height }, visual, options);
}

fn renderRecordFields(writer: *Io.Writer, node: RecordAst, rect: RectF, visual: NodeVisual, options: SvgOptions) Io.Writer.Error!void {
    if (node.children.len == 0) {
        try writer.print("<text xml:space=\"preserve\" text-anchor=\"middle\" x=\"{d:.1}\" y=\"{d:.1}\" font-family=\"{s}\" font-size=\"{d:.2}\"", .{
            rect.x + rect.width / 2.0,
            rect.y + rect.height / 2.0,
            visual.font_family,
            visual.font_size,
        });
        try writeSvgTextFill(writer, visual.font_color);
        try writer.writeAll(" dominant-baseline=\"middle\">");
        try writeXmlEscaped(writer, node.label);
        try writer.writeAll("</text>\n");
        return;
    }

    var cursor: f64 = 0;
    for (node.children, 0..) |child, index| {
        const last = index + 1 == node.children.len;
        const child_rect = switch (node.orientation) {
            .horizontal => blk: {
                const child_w = if (last) rect.width - cursor else rect.width * child.width_units / node.width_units;
                break :blk RectF{ .x = rect.x + cursor, .y = rect.y, .width = child_w, .height = rect.height };
            },
            .vertical => blk: {
                const child_h = if (last) rect.height - cursor else rect.height * child.height_units / node.height_units;
                break :blk RectF{ .x = rect.x, .y = rect.y + cursor, .width = rect.width, .height = child_h };
            },
        };

        if (index > 0) {
            switch (node.orientation) {
                .horizontal => try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"/>\n", .{
                    child_rect.x,
                    rect.y,
                    child_rect.x,
                    rect.y + rect.height,
                    visual.stroke,
                    visual.width,
                }),
                .vertical => try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"/>\n", .{
                    rect.x,
                    child_rect.y,
                    rect.x + rect.width,
                    child_rect.y,
                    visual.stroke,
                    visual.width,
                }),
            }
        }
        try renderRecordFields(writer, child, child_rect, visual, options);
        cursor += switch (node.orientation) {
            .horizontal => child_rect.width,
            .vertical => child_rect.height,
        };
    }
}

fn resolveNodeVisual(node_item: Node) NodeVisual {
    const style = attrValue(node_item.attrs.items, "style");
    const filled = styleHas(style, "filled");
    const invisible = styleHas(style, "invis");
    const rounded = styleHas(style, "rounded");
    const dashed = styleHas(style, "dashed");
    const dotted = styleHas(style, "dotted");
    const bold = styleHas(style, "bold");
    const color_attr = attrValue(node_item.attrs.items, "color");
    const color = color_attr orelse node_item.color;
    const explicit_color = color_attr != null and !(std.ascii.eqlIgnoreCase(color_attr.?, "black") and std.ascii.eqlIgnoreCase(node_item.color, "black"));
    const fill = attrValue(node_item.attrs.items, "fillcolor") orelse if (filled) (if (explicit_color) color else "lightgrey") else "none";
    return .{
        .fill = fill,
        .stroke = color,
        .font_color = attrValue(node_item.attrs.items, "fontcolor") orelse "black",
        .font_family = attrValue(node_item.attrs.items, "fontname") orelse default_svg_font_family,
        .font_size = parsePositiveAttrFloat(node_item.attrs.items, "fontsize", 14.0),
        .width = parseAttrFloat(node_item.attrs.items, "penwidth", if (bold) 2.6 else 1.0),
        .radius = if (rounded) 10 else 0,
        .dash = if (dotted) .dotted else if (dashed) .dashed else .none,
        .peripheries = @max(parseAttrUsize(node_item.attrs.items, "peripheries", 1), 1),
        .hidden = invisible,
    };
}

fn resolveEdgeVisual(edge_item: Edge) EdgeVisual {
    const style = attrValue(edge_item.attrs.items, "style");
    const bold = styleHas(style, "bold");
    const arrowhead = attrValue(edge_item.attrs.items, "arrowhead");
    const arrowtail = attrValue(edge_item.attrs.items, "arrowtail");
    const dir = attrValue(edge_item.attrs.items, "dir");
    const head_enabled = markerEnabledByDir(dir, true);
    const tail_enabled = markerEnabledByDir(dir, false);
    const raw_stroke = attrValue(edge_item.attrs.items, "color") orelse edge_item.color;
    const stroke = if (parseColorList(raw_stroke)) |colors| colors.segments[0].color else raw_stroke;
    return .{
        .stroke = stroke,
        .font_color = attrValue(edge_item.attrs.items, "fontcolor") orelse "black",
        .font_family = attrValue(edge_item.attrs.items, "fontname") orelse default_svg_font_family,
        .font_size = parsePositiveAttrFloat(edge_item.attrs.items, "fontsize", 14.0),
        .width = parseAttrFloat(edge_item.attrs.items, "penwidth", if (bold) 3.0 else 1.0),
        .dash = if (styleHas(style, "dotted")) .dotted else if (styleHas(style, "dashed")) .dashed else .none,
        .marker_start = if (tail_enabled) parseMarkerShape(arrowtail, .normal) else .none,
        .marker_end = if (head_enabled) parseMarkerShape(arrowhead, .normal) else .none,
        .marker_scale = std.math.clamp(parseAttrFloat(edge_item.attrs.items, "arrowsize", 1.0), 0.0, 8.0),
        .hidden = styleHas(style, "invis"),
    };
}

fn resolveClusterVisual(cluster: Cluster) ClusterVisual {
    const style = attrValue(cluster.attrs.items, "style");
    const filled = styleHas(style, "filled");
    const dashed = styleHas(style, "dashed");
    const dotted = styleHas(style, "dotted");
    const rounded = styleHas(style, "rounded");
    const color = attrValue(cluster.attrs.items, "color") orelse "#94a3b8";
    return .{
        .fill = attrValue(cluster.attrs.items, "fillcolor") orelse if (filled) color else "none",
        .stroke = color,
        .font_color = attrValue(cluster.attrs.items, "fontcolor") orelse "black",
        .font_family = attrValue(cluster.attrs.items, "fontname") orelse default_svg_font_family,
        .font_size = parsePositiveAttrFloat(cluster.attrs.items, "fontsize", 14.0),
        .width = parseAttrFloat(cluster.attrs.items, "penwidth", 1.0),
        .radius = if (rounded) 10 else 0,
        .dash = if (dotted) .dotted else if (dashed) .dashed else .none,
        .fill_opacity = if (filled or attrValue(cluster.attrs.items, "fillcolor") != null) "1.0" else "1.0",
        .hidden = styleHas(style, "invis"),
    };
}

fn attrValue(attrs: []const Attr, name: []const u8) ?[]const u8 {
    for (attrs) |attr| {
        if (std.ascii.eqlIgnoreCase(attr.name, name)) return attr.value;
    }
    return null;
}

fn parseAttrFloat(attrs: []const Attr, name: []const u8, fallback: f64) f64 {
    const value = attrValue(attrs, name) orelse return fallback;
    return std.fmt.parseFloat(f64, value) catch fallback;
}

fn parsePositiveAttrFloat(attrs: []const Attr, name: []const u8, fallback: f64) f64 {
    const value = attrValue(attrs, name) orelse return fallback;
    const parsed = std.fmt.parseFloat(f64, value) catch return fallback;
    return if (parsed > 0) parsed else fallback;
}

fn parseAttrUsize(attrs: []const Attr, name: []const u8, fallback: usize) usize {
    const value = attrValue(attrs, name) orelse return fallback;
    return std.fmt.parseInt(usize, value, 10) catch fallback;
}

fn styleHas(style: ?[]const u8, needle: []const u8) bool {
    const value = style orelse return false;
    var parts = std.mem.tokenizeAny(u8, value, ", ");
    while (parts.next()) |part| {
        if (std.ascii.eqlIgnoreCase(part, needle)) return true;
    }
    return false;
}

fn writeSvgDash(writer: *Io.Writer, dash: DashStyle) Io.Writer.Error!void {
    switch (dash) {
        .none => {},
        .dashed => try writer.writeAll(" stroke-dasharray=\"8,5\""),
        .dotted => try writer.writeAll(" stroke-dasharray=\"2,5\""),
    }
}

fn writeSvgMarkerDef(writer: *Io.Writer, edge_id: EdgeId, suffix: []const u8, shape: MarkerShape, color: []const u8, scale: f64) Io.Writer.Error!void {
    if (scale <= 0) return;
    const marker_size = 7.0 * scale;
    try writer.print("<marker id=\"arrow-{d}-{s}\" viewBox=\"0 0 10 10\" refX=\"{d:.1}\" refY=\"5\" markerWidth=\"{d:.2}\" markerHeight=\"{d:.2}\" orient=\"auto", .{ edge_id, suffix, markerRefX(shape), marker_size, marker_size });
    if (std.mem.eql(u8, suffix, "tail")) try writer.writeAll("-start-reverse");
    try writer.writeAll("\">");
    switch (shape) {
        .none => {},
        .normal => try writer.print("<path d=\"M 1.2 1.4 L 9.2 5 L 1.2 8.6 z\" fill=\"{s}\"/>", .{color}),
        .vee => try writer.print("<path d=\"M 1 1 L 9 5 L 1 9\" fill=\"none\" stroke=\"{s}\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>", .{color}),
        .dot => try writer.print("<circle cx=\"5\" cy=\"5\" r=\"4\" fill=\"{s}\"/>", .{color}),
        .odot => try writer.print("<circle cx=\"5\" cy=\"5\" r=\"3.5\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{color}),
        .box => try writer.print("<rect x=\"1.5\" y=\"1.5\" width=\"7\" height=\"7\" fill=\"{s}\"/>", .{color}),
        .obox => try writer.print("<rect x=\"1.5\" y=\"1.5\" width=\"7\" height=\"7\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{color}),
        .diamond => try writer.print("<path d=\"M 5 0.8 L 9.2 5 L 5 9.2 L 0.8 5 z\" fill=\"{s}\"/>", .{color}),
        .odiamond => try writer.print("<path d=\"M 5 0.8 L 9.2 5 L 5 9.2 L 0.8 5 z\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{color}),
        .tee => try writer.print("<path d=\"M 8.5 1 L 8.5 9\" fill=\"none\" stroke=\"{s}\" stroke-width=\"2\" stroke-linecap=\"round\"/>", .{color}),
        .crow => try writer.print("<path d=\"M 9 1 L 1 5 L 9 9 M 1 5 L 9 5\" fill=\"none\" stroke=\"{s}\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>", .{color}),
        .empty => try writer.print("<path d=\"M 0.8 0.8 L 9.2 5 L 0.8 9.2 z\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{color}),
    }
    try writer.writeAll("</marker>\n");
}

fn markerRefX(shape: MarkerShape) f64 {
    return switch (shape) {
        .normal => 9.2,
        else => 9.0,
    };
}

fn writeSvgMarkerAttrs(writer: *Io.Writer, directed: bool, edge_id: EdgeId, visual: EdgeVisual) Io.Writer.Error!void {
    if (!directed) return;
    if (visual.marker_scale <= 0) return;
    if (visual.marker_start != .none and visual.marker_start != .normal) try writer.print(" marker-start=\"url(#arrow-{d}-tail)\"", .{edge_id});
    if (visual.marker_end != .none and visual.marker_end != .normal) try writer.print(" marker-end=\"url(#arrow-{d}-head)\"", .{edge_id});
}

fn writeSvgInlineArrowheads(writer: *Io.Writer, directed: bool, route: EdgeRoute, visual: EdgeVisual) Io.Writer.Error!void {
    if (!directed or visual.marker_scale <= 0) return;
    if (visual.marker_end == .normal) {
        try writeSvgInlineNormalArrow(writer, route.end, route.control2, visual.stroke, visual.marker_scale, false);
    }
    if (visual.marker_start == .normal) {
        try writeSvgInlineNormalArrow(writer, route.start, route.control1, visual.stroke, visual.marker_scale, true);
    }
}

fn writeSvgInlineNormalArrow(writer: *Io.Writer, tip: Point, toward: Point, color: []const u8, scale: f64, reverse: bool) Io.Writer.Error!void {
    var dx = tip.x - toward.x;
    var dy = tip.y - toward.y;
    if (reverse) {
        dx = -dx;
        dy = -dy;
    }
    const len = std.math.hypot(dx, dy);
    if (len <= 0.001) return;
    const ux = dx / len;
    const uy = dy / len;
    const arrow_len = 10.0 * scale;
    const arrow_half = 3.5 * scale;
    const base = Point{ .x = tip.x - ux * arrow_len, .y = tip.y - uy * arrow_len };
    const px = -uy;
    const py = ux;
    const left = Point{ .x = base.x + px * arrow_half, .y = base.y + py * arrow_half };
    const right = Point{ .x = base.x - px * arrow_half, .y = base.y - py * arrow_half };
    try writer.print("<polygon fill=\"{s}\" stroke=\"{s}\" points=\"{d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1}\"/>\n", .{
        color,
        color,
        left.x,
        left.y,
        tip.x,
        tip.y,
        right.x,
        right.y,
        left.x,
        left.y,
    });
}

fn parseMarkerShape(value: ?[]const u8, fallback: MarkerShape) MarkerShape {
    const text = value orelse return fallback;
    if (std.ascii.eqlIgnoreCase(text, "none")) return .none;
    if (std.ascii.eqlIgnoreCase(text, "normal")) return .normal;
    if (std.ascii.eqlIgnoreCase(text, "vee")) return .vee;
    if (std.ascii.eqlIgnoreCase(text, "dot")) return .dot;
    if (std.ascii.eqlIgnoreCase(text, "odot")) return .odot;
    if (std.ascii.eqlIgnoreCase(text, "box")) return .box;
    if (std.ascii.eqlIgnoreCase(text, "obox")) return .obox;
    if (std.ascii.eqlIgnoreCase(text, "diamond")) return .diamond;
    if (std.ascii.eqlIgnoreCase(text, "odiamond")) return .odiamond;
    if (std.ascii.eqlIgnoreCase(text, "tee")) return .tee;
    if (std.ascii.eqlIgnoreCase(text, "crow")) return .crow;
    if (std.ascii.eqlIgnoreCase(text, "empty")) return .empty;
    return fallback;
}

fn markerEnabledByDir(dir: ?[]const u8, head: bool) bool {
    const value = dir orelse return head;
    if (std.ascii.eqlIgnoreCase(value, "none")) return false;
    if (std.ascii.eqlIgnoreCase(value, "both")) return true;
    if (std.ascii.eqlIgnoreCase(value, "back")) return !head;
    if (std.ascii.eqlIgnoreCase(value, "forward")) return head;
    return head;
}

fn parallelEdgeOffset(graph: *const Graph, edge_id: EdgeId) f64 {
    const edge_item = graph.edges.items[edge_id];
    var index: usize = 0;
    var count: usize = 0;
    for (graph.edges.items) |candidate| {
        const same_directed = candidate.from == edge_item.from and candidate.to == edge_item.to;
        const same_undirected = !graph.directed and candidate.from == edge_item.to and candidate.to == edge_item.from;
        if (!same_directed and !same_undirected) continue;
        if (candidate.id == edge_id) index = count;
        count += 1;
    }
    if (count <= 1) return 0;
    return (@as(f64, @floatFromInt(index)) - (@as(f64, @floatFromInt(count - 1)) / 2.0)) * 22.0;
}

const SvgEdgeRouting = enum {
    curved,
    line,
    polyline,
    ortho,
};

fn svgEdgeRoutingMode(graph: *const Graph) SvgEdgeRouting {
    const value = attrValue(graph.attrs.items, "splines") orelse return .curved;
    if (std.ascii.eqlIgnoreCase(value, "false") or std.ascii.eqlIgnoreCase(value, "none") or std.ascii.eqlIgnoreCase(value, "line")) return .line;
    if (std.ascii.eqlIgnoreCase(value, "polyline")) return .polyline;
    if (std.ascii.eqlIgnoreCase(value, "ortho")) return .ortho;
    return .curved;
}

fn writeEdgePath(writer: *Io.Writer, layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64, direct_route: EdgeRoute, routing: SvgEdgeRouting) Io.Writer.Error!void {
    if (routing == .line) {
        try writePathMove(writer, direct_route.start);
        try writePathLine(writer, direct_route.end);
        return;
    }
    if (routing == .ortho) {
        try writeOrthoEdgePath(writer, direct_route.start, direct_route.end, rankdir);
        return;
    }
    if (isBackEdge(layout, edge_item)) {
        try writeBackEdgePath(writer, layout, edge_item, rankdir, offset, direct_route, routing);
        return;
    }

    const waypoint_count = longEdgeWaypointCount(layout, edge_item);
    if (waypoint_count == 1 and routing == .curved) {
        const mid = longEdgeWaypoint(layout, edge_item, rankdir, offset, 0, waypoint_count);
        const first = smoothSegmentControls(direct_route.start, mid, rankdir);
        const second = smoothSegmentControls(mid, direct_route.end, rankdir);
        try writePathMove(writer, direct_route.start);
        try writePathCubic(writer, first.c1, second.c2, direct_route.end);
        return;
    }
    if (waypoint_count == 0) {
        if (routing == .polyline) {
            try writePathMove(writer, direct_route.start);
            try writePathLine(writer, direct_route.end);
            return;
        }
        try writePathMove(writer, direct_route.start);
        try writePathCubic(writer, direct_route.control1, direct_route.control2, direct_route.end);
        return;
    }

    try writePathMove(writer, direct_route.start);
    var current = direct_route.start;
    var i: usize = 0;
    while (i < waypoint_count) : (i += 1) {
        const next = longEdgeWaypoint(layout, edge_item, rankdir, offset, i, waypoint_count);
        if (routing == .polyline) {
            try writePathLine(writer, next);
        } else {
            try writeSmoothSegment(writer, current, next, rankdir);
        }
        current = next;
    }
    if (routing == .polyline) {
        try writePathLine(writer, direct_route.end);
    } else {
        try writeSmoothSegment(writer, current, direct_route.end, rankdir);
    }
}

fn writeOrthoEdgePath(writer: *Io.Writer, start: Point, end: Point, rankdir: RankDir) Io.Writer.Error!void {
    if (rankdir == .LR or rankdir == .RL) {
        const mid_x = (start.x + end.x) / 2.0;
        try writePathMove(writer, start);
        try writePathLine(writer, .{ .x = mid_x, .y = start.y });
        try writePathLine(writer, .{ .x = mid_x, .y = end.y });
        try writePathLine(writer, end);
    } else {
        const mid_y = (start.y + end.y) / 2.0;
        try writePathMove(writer, start);
        try writePathLine(writer, .{ .x = start.x, .y = mid_y });
        try writePathLine(writer, .{ .x = end.x, .y = mid_y });
        try writePathLine(writer, end);
    }
}

fn isBackEdge(layout: *const Layout, edge_item: Edge) bool {
    if (edge_item.from >= layout.ranks.len or edge_item.to >= layout.ranks.len) return false;
    return layout.ranks[edge_item.to] < layout.ranks[edge_item.from];
}

fn writeBackEdgePath(writer: *Io.Writer, layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64, route: EdgeRoute, routing: SvgEdgeRouting) Io.Writer.Error!void {
    const from = layout.nodes[edge_item.from];
    const to = layout.nodes[edge_item.to];
    const side_gap = @max(28.0, layout.margin * 0.55) + @abs(offset);

    if (rankdir == .TB or rankdir == .BT) {
        const prefer_left = backEdgeUsesNegativeSide(layout, edge_item, rankdir);
        const side_x = if (prefer_left)
            @max(layout.margin_x, @min(from.center.x - from.width / 2.0, to.center.x - to.width / 2.0) - side_gap)
        else
            @min(layout.width - layout.margin_x, @max(from.center.x + from.width / 2.0, to.center.x + to.width / 2.0) + side_gap);
        const p1 = Point{ .x = side_x, .y = route.start.y };
        const p2 = Point{ .x = side_x, .y = route.end.y };
        if (routing == .polyline) {
            try writePathMove(writer, route.start);
            try writePathLine(writer, p1);
            try writePathLine(writer, p2);
            try writePathLine(writer, route.end);
        } else {
            const curve = @min(36.0, @abs(route.start.x - side_x) * 0.5 + 12.0);
            const c1x = if (prefer_left)
                @max(side_x, route.start.x - curve)
            else
                @min(side_x, route.start.x + curve);
            const c2x = side_x;
            const c3x = side_x;
            const c4x = if (prefer_left)
                @max(side_x, route.end.x - curve)
            else
                @min(side_x, route.end.x + curve);
            const mid_y = (p1.y + p2.y) / 2.0;
            try writePathMove(writer, route.start);
            try writePathCubic(writer, .{ .x = c1x, .y = route.start.y }, .{ .x = c2x, .y = p1.y }, p1);
            try writePathCubic(writer, .{ .x = side_x, .y = mid_y }, .{ .x = side_x, .y = mid_y }, p2);
            try writePathCubic(writer, .{ .x = c3x, .y = p2.y }, .{ .x = c4x, .y = route.end.y }, route.end);
        }
        return;
    }

    const prefer_top = backEdgeUsesNegativeSide(layout, edge_item, rankdir);
    const side_y = if (prefer_top)
        @max(layout.margin_y, @min(from.center.y - from.height / 2.0, to.center.y - to.height / 2.0) - side_gap)
    else
        @min(layout.height - layout.margin_y, @max(from.center.y + from.height / 2.0, to.center.y + to.height / 2.0) + side_gap);
    const p1 = Point{ .x = route.start.x, .y = side_y };
    const p2 = Point{ .x = route.end.x, .y = side_y };
    if (routing == .polyline) {
        try writePathMove(writer, route.start);
        try writePathLine(writer, p1);
        try writePathLine(writer, p2);
        try writePathLine(writer, route.end);
    } else {
        const curve = @min(36.0, @abs(route.start.y - side_y) * 0.5 + 12.0);
        const c1y = if (prefer_top)
            @max(side_y, route.start.y - curve)
        else
            @min(side_y, route.start.y + curve);
        const c2y = side_y;
        const c3y = side_y;
        const c4y = if (prefer_top)
            @max(side_y, route.end.y - curve)
        else
            @min(side_y, route.end.y + curve);
        const mid_x = (p1.x + p2.x) / 2.0;
        try writePathMove(writer, route.start);
        try writePathCubic(writer, .{ .x = route.start.x, .y = c1y }, .{ .x = p1.x, .y = c2y }, p1);
        try writePathCubic(writer, .{ .x = mid_x, .y = side_y }, .{ .x = mid_x, .y = side_y }, p2);
        try writePathCubic(writer, .{ .x = p2.x, .y = c3y }, .{ .x = route.end.x, .y = c4y }, route.end);
    }
}

fn backEdgeUsesNegativeSide(layout: *const Layout, edge_item: Edge, rankdir: RankDir) bool {
    if (edge_item.from >= layout.nodes.len or edge_item.to >= layout.nodes.len) return true;
    const from = layout.nodes[edge_item.from];
    const to = layout.nodes[edge_item.to];
    const from_along = pointAlongAxis(from.center, rankdir);
    const to_along = pointAlongAxis(to.center, rankdir);
    const overlap_width = nodeAlongHalfSize(from, rankdir) + nodeAlongHalfSize(to, rankdir);
    if (@abs(from_along - to_along) <= overlap_width + 2.0) return true;
    return from_along <= to_along;
}

fn nodeAlongHalfSize(node: NodeLayout, rankdir: RankDir) f64 {
    return switch (rankdir) {
        .TB, .BT => node.width / 2.0,
        .LR, .RL => node.height / 2.0,
    };
}

fn longEdgeWaypointCount(layout: *const Layout, edge_item: Edge) usize {
    if (edge_item.from >= layout.ranks.len or edge_item.to >= layout.ranks.len) return 0;
    const from_rank = layout.ranks[edge_item.from];
    const to_rank = layout.ranks[edge_item.to];
    const distance = if (from_rank > to_rank) from_rank - to_rank else to_rank - from_rank;
    return if (distance > 1) distance - 1 else 0;
}

fn longEdgeWaypoint(layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64, index: usize, count: usize) Point {
    const axes = LayoutAxes.init(rankdir);
    const from_rank = layout.ranks[edge_item.from];
    const to_rank = layout.ranks[edge_item.to];
    const increasing = to_rank > from_rank;
    const rank = if (increasing) from_rank + index + 1 else from_rank - index - 1;
    if (storedEdgeWaypoint(layout, edge_item.id, rank)) |point| {
        const avoided = avoidNodeAtRankForWaypoint(layout, edge_item, rankdir, rank, point);
        if (edgeTouchesMultipleClusters(layout, edge_item) and waypointLeavesEndpointSpan(layout, edge_item, rankdir, avoided)) {
            return fallbackLongEdgeWaypoint(layout, edge_item, rankdir, offset, index, count, rank);
        }
        return axes.offsetPoint(avoided, offset);
    }
    return fallbackLongEdgeWaypoint(layout, edge_item, rankdir, offset, index, count, rank);
}

fn fallbackLongEdgeWaypoint(layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64, index: usize, count: usize, rank: usize) Point {
    const axes = LayoutAxes.init(rankdir);
    const along = longEdgeDummyAlongFromLayout(layout, edge_item, rankdir, rank) orelse interpolatedWaypointAlong(layout, edge_item, rankdir, index, count);
    const depth = rankDepthCenter(layout, rank);
    const point = axes.orientWaypoint(along, depth, layout);
    return axes.offsetPoint(avoidNodeAtRankForWaypoint(layout, edge_item, rankdir, rank, point), offset);
}

fn waypointLeavesEndpointSpan(layout: *const Layout, edge_item: Edge, rankdir: RankDir, waypoint: Point) bool {
    if (edge_item.from >= layout.nodes.len or edge_item.to >= layout.nodes.len) return false;
    const from_along = pointAlongAxis(layout.nodes[edge_item.from].center, rankdir);
    const to_along = pointAlongAxis(layout.nodes[edge_item.to].center, rankdir);
    const min_along = @min(from_along, to_along) - 2.0;
    const max_along = @max(from_along, to_along) + 2.0;
    const along = pointAlongAxis(waypoint, rankdir);
    return along < min_along or along > max_along;
}

fn edgeTouchesMultipleClusters(layout: *const Layout, edge_item: Edge) bool {
    if (edge_item.from >= layout.nodes.len or edge_item.to >= layout.nodes.len) return false;
    var from_cluster: ?usize = null;
    var to_cluster: ?usize = null;
    for (layout.clusters, 0..) |cluster_box, cluster_index| {
        if (pointInsideCluster(layout.nodes[edge_item.from].center, cluster_box)) from_cluster = cluster_index;
        if (pointInsideCluster(layout.nodes[edge_item.to].center, cluster_box)) to_cluster = cluster_index;
    }
    if (from_cluster == null or to_cluster == null) return false;
    return from_cluster.? != to_cluster.?;
}

fn pointInsideCluster(point: Point, cluster_box: ClusterLayout) bool {
    return cluster_box.width > 0 and cluster_box.height > 0 and
        point.x >= cluster_box.x and point.x <= cluster_box.x + cluster_box.width and
        point.y >= cluster_box.y and point.y <= cluster_box.y + cluster_box.height;
}

fn avoidNodeAtRankForWaypoint(layout: *const Layout, edge_item: Edge, rankdir: RankDir, rank: usize, point: Point) Point {
    var result = point;
    const clearance = 12.0;
    for (layout.nodes, 0..) |node, node_id| {
        if (node_id == edge_item.from or node_id == edge_item.to) continue;
        if (node_id >= layout.ranks.len or layout.ranks[node_id] != rank) continue;
        if (!pointInsideNodeWithPadding(result, node, clearance)) continue;
        const push_negative = pointAlongAxis(layout.nodes[edge_item.from].center, rankdir) <= pointAlongAxis(node.center, rankdir);
        result = pushWaypointOutsideNode(result, node, rankdir, clearance, push_negative);
    }
    return result;
}

fn pointInsideNodeWithPadding(point: Point, node: NodeLayout, padding: f64) bool {
    return point.x >= node.center.x - node.width / 2.0 - padding and
        point.x <= node.center.x + node.width / 2.0 + padding and
        point.y >= node.center.y - node.height / 2.0 - padding and
        point.y <= node.center.y + node.height / 2.0 + padding;
}

fn pushWaypointOutsideNode(point: Point, node: NodeLayout, rankdir: RankDir, clearance: f64, push_negative: bool) Point {
    var result = point;
    switch (rankdir) {
        .TB, .BT => {
            result.x = if (push_negative)
                node.center.x - node.width / 2.0 - clearance
            else
                node.center.x + node.width / 2.0 + clearance;
        },
        .LR, .RL => {
            result.y = if (push_negative)
                node.center.y - node.height / 2.0 - clearance
            else
                node.center.y + node.height / 2.0 + clearance;
        },
    }
    return result;
}

fn storedEdgeWaypoint(layout: *const Layout, edge_id: EdgeId, rank: usize) ?Point {
    if (edge_id >= layout.edge_waypoints.len) return null;
    for (layout.edge_waypoints[edge_id].points) |waypoint| {
        if (waypoint.rank == rank) return waypoint.point;
    }
    return null;
}

fn longEdgeDummyAlongFromLayout(layout: *const Layout, edge_item: Edge, rankdir: RankDir, rank: usize) ?f64 {
    if (edge_item.from >= layout.nodes.len or edge_item.to >= layout.nodes.len) return null;
    if (edge_item.from >= layout.ranks.len or edge_item.to >= layout.ranks.len) return null;
    const from_rank = layout.ranks[edge_item.from];
    const to_rank = layout.ranks[edge_item.to];
    if (from_rank + 1 >= to_rank) return null;
    if (rank <= from_rank or rank >= to_rank) return null;
    const span = @as(f64, @floatFromInt(to_rank - from_rank));
    const t = @as(f64, @floatFromInt(rank - from_rank)) / span;
    const axes = LayoutAxes.init(rankdir);
    const from_along = axes.pointAlong(layout.nodes[edge_item.from].center);
    const to_along = axes.pointAlong(layout.nodes[edge_item.to].center);
    return from_along + (to_along - from_along) * t;
}

fn interpolatedWaypointAlong(layout: *const Layout, edge_item: Edge, rankdir: RankDir, index: usize, count: usize) f64 {
    const t = @as(f64, @floatFromInt(index + 1)) / @as(f64, @floatFromInt(count + 1));
    const from_center = layout.nodes[edge_item.from].center;
    const to_center = layout.nodes[edge_item.to].center;
    const axes = LayoutAxes.init(rankdir);
    return axes.pointAlong(from_center) + (axes.pointAlong(to_center) - axes.pointAlong(from_center)) * t;
}

fn pointAlongAxis(point: Point, rankdir: RankDir) f64 {
    return LayoutAxes.init(rankdir).pointAlong(point);
}

fn rankDepthCenter(layout: *const Layout, rank: usize) f64 {
    if (rank >= layout.rank_depths.len or rank >= layout.rank_heights.len) return 0;
    return rankDepthCenterFrom(layout.rank_depths, layout.rank_heights, rank);
}

fn rankDepthCenterFrom(rank_depths: []const f64, rank_heights: []const f64, rank: usize) f64 {
    if (rank >= rank_depths.len or rank >= rank_heights.len) return 0;
    return rank_depths[rank] + rank_heights[rank] / 2.0;
}

fn orientWaypoint(rankdir: RankDir, along_screen: f64, depth: f64, layout: *const Layout) Point {
    return LayoutAxes.init(rankdir).orientWaypoint(along_screen, depth, layout);
}

fn splineCurveAmount(rankdir: RankDir, dx: f64, dy: f64, min_curve: f64, max_curve: f64) f64 {
    const axis_delta = LayoutAxes.init(rankdir).rankAxisDelta(dx, dy);
    if (axis_delta <= 0.001) return 0;
    const preferred = @min(max_curve, axis_delta * 0.45);
    return @min(axis_delta * 0.5, @max(min_curve, preferred));
}

fn writePathMove(writer: *Io.Writer, point: Point) Io.Writer.Error!void {
    try writer.print("M{d:.1},{d:.1}", .{ point.x, point.y });
}

fn writePathLine(writer: *Io.Writer, point: Point) Io.Writer.Error!void {
    try writer.print("L{d:.1},{d:.1}", .{ point.x, point.y });
}

fn writePathCubic(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.print("C{d:.1},{d:.1} {d:.1},{d:.1} {d:.1},{d:.1}", .{ c1.x, c1.y, c2.x, c2.y, end.x, end.y });
}

fn writeSmoothSegment(writer: *Io.Writer, from: Point, to: Point, rankdir: RankDir) Io.Writer.Error!void {
    const controls = smoothSegmentControls(from, to, rankdir);
    try writePathCubic(writer, controls.c1, controls.c2, to);
}

fn smoothSegmentControls(from: Point, to: Point, rankdir: RankDir) EdgeControls {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const curve = splineCurveAmount(rankdir, dx, dy, 18.0, 96.0);
    return diagonalEdgeControls(from, to, rankdir, curve) orelse switch (rankdir) {
        .TB => EdgeControls{
            .c1 = .{ .x = from.x, .y = from.y + curve },
            .c2 = .{ .x = to.x, .y = to.y - curve },
        },
        .BT => EdgeControls{
            .c1 = .{ .x = from.x, .y = from.y - curve },
            .c2 = .{ .x = to.x, .y = to.y + curve },
        },
        .LR => EdgeControls{
            .c1 = .{ .x = from.x + curve, .y = from.y },
            .c2 = .{ .x = to.x - curve, .y = to.y },
        },
        .RL => EdgeControls{
            .c1 = .{ .x = from.x - curve, .y = from.y },
            .c2 = .{ .x = to.x + curve, .y = to.y },
        },
    };
}

fn edgeRoute(from: NodeLayout, to: NodeLayout, rankdir: RankDir, offset: f64) EdgeRoute {
    const start = boundaryPoint(from, to.center, rankdir, true);
    const end = boundaryPoint(to, from.center, rankdir, false);
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const curve = splineCurveAmount(rankdir, dx, dy, 24.0, 160.0);
    const controls: EdgeControls = diagonalEdgeControls(start, end, rankdir, curve) orelse switch (rankdir) {
        .TB => .{
            .c1 = Point{ .x = start.x, .y = start.y + curve },
            .c2 = Point{ .x = end.x, .y = end.y - curve },
        },
        .BT => .{
            .c1 = Point{ .x = start.x, .y = start.y - curve },
            .c2 = Point{ .x = end.x, .y = end.y + curve },
        },
        .LR => .{
            .c1 = Point{ .x = start.x + curve, .y = start.y },
            .c2 = Point{ .x = end.x - curve, .y = end.y },
        },
        .RL => .{
            .c1 = Point{ .x = start.x - curve, .y = start.y },
            .c2 = Point{ .x = end.x + curve, .y = end.y },
        },
    };
    const shifted_start = offsetPoint(start, rankdir, offset);
    const shifted_end = offsetPoint(end, rankdir, offset);
    const c1 = offsetPoint(controls.c1, rankdir, offset);
    const c2 = offsetPoint(controls.c2, rankdir, offset);
    return .{
        .start = shifted_start,
        .control1 = c1,
        .control2 = c2,
        .end = shifted_end,
        .label = cubicPoint(shifted_start, c1, c2, shifted_end, 0.5),
    };
}

fn diagonalEdgeControls(start: Point, end: Point, rankdir: RankDir, curve: f64) ?EdgeControls {
    if (curve <= 0.001) return null;
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const axis_delta = LayoutAxes.init(rankdir).rankAxisDelta(dx, dy);
    const cross_delta = if (rankdir == .LR or rankdir == .RL) @abs(dy) else @abs(dx);
    if (axis_delta <= 0.001 or cross_delta < axis_delta * 0.35) return null;
    return .{
        .c1 = .{ .x = start.x + dx / 3.0, .y = start.y + dy / 3.0 },
        .c2 = .{ .x = start.x + dx * 2.0 / 3.0, .y = start.y + dy * 2.0 / 3.0 },
    };
}

fn edgeRouteForEdge(graph: *const Graph, layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64) EdgeRoute {
    const from = layout.nodes[edge_item.from];
    const to = layout.nodes[edge_item.to];
    const tail_clip = edgeClipEnabled(edge_item.attrs.items, "tailclip");
    const head_clip = edgeClipEnabled(edge_item.attrs.items, "headclip");
    const raw_start = if (tail_clip)
        samePortBoundaryPoint(graph, layout, edge_item, false) orelse htmlTableBoundaryPoint(graph.nodes.items[edge_item.from], from, to.center, edge_item.tail_record_port, edge_item.tail_port) orelse recordBoundaryPoint(graph.nodes.items[edge_item.from], from, to.center, edge_item.tail_record_port, edge_item.tail_port, true) orelse nodePortBoundaryPoint(graph.nodes.items[edge_item.from], from, to.center, edge_item.tail_port, rankdir, true)
    else
        from.center;
    const raw_end = if (head_clip)
        samePortBoundaryPoint(graph, layout, edge_item, true) orelse htmlTableBoundaryPoint(graph.nodes.items[edge_item.to], to, from.center, edge_item.head_record_port, edge_item.head_port) orelse recordBoundaryPoint(graph.nodes.items[edge_item.to], to, from.center, edge_item.head_record_port, edge_item.head_port, false) orelse nodePortBoundaryPoint(graph.nodes.items[edge_item.to], to, from.center, edge_item.head_port, rankdir, false)
    else
        to.center;
    const compound = graphCompoundEnabled(graph);
    const start = if (compound and edge_item.ltail != null)
        clusterBoundaryPoint(graph, layout, edge_item.ltail.?, raw_start, raw_end) orelse raw_start
    else
        raw_start;
    const end = if (compound and edge_item.lhead != null)
        clusterBoundaryPoint(graph, layout, edge_item.lhead.?, raw_end, raw_start) orelse raw_end
    else
        raw_end;
    return edgeRouteFromEndpoints(start, end, rankdir, offset);
}

fn graphCompoundEnabled(graph: *const Graph) bool {
    const value = attrValue(graph.attrs.items, "compound") orelse return false;
    return parseBool(value) orelse false;
}

fn edgeClipEnabled(attrs: []const Attr, name: []const u8) bool {
    const value = attrValue(attrs, name) orelse return true;
    return parseBool(value) orelse true;
}

fn samePortBoundaryPoint(graph: *const Graph, layout: *const Layout, edge_item: Edge, head: bool) ?Point {
    const attr_name = if (head) "samehead" else "sametail";
    const group_name = attrValue(edge_item.attrs.items, attr_name) orelse return null;
    if (group_name.len == 0) return null;
    const anchor_id = if (head) edge_item.to else edge_item.from;
    if (anchor_id >= layout.nodes.len) return null;
    const anchor = layout.nodes[anchor_id];

    var sum = Point{ .x = 0, .y = 0 };
    var count: usize = 0;
    for (graph.edges.items) |candidate| {
        if (candidate.from == candidate.to) continue;
        const candidate_anchor = if (head) candidate.to else candidate.from;
        if (candidate_anchor != anchor_id) continue;
        const candidate_group = attrValue(candidate.attrs.items, attr_name) orelse continue;
        if (!std.mem.eql(u8, candidate_group, group_name)) continue;
        const other_id = if (head) candidate.from else candidate.to;
        if (other_id >= layout.nodes.len) continue;
        const other = layout.nodes[other_id].center;
        const dx = other.x - anchor.center.x;
        const dy = other.y - anchor.center.y;
        const length = std.math.hypot(dx, dy);
        if (length <= 0.001) continue;
        sum.x += dx / length;
        sum.y += dy / length;
        count += 1;
    }
    if (count < 2) return null;
    const toward = Point{
        .x = anchor.center.x + sum.x,
        .y = anchor.center.y + sum.y,
    };
    return boundaryPoint(anchor, toward, layout.rankdir, !head);
}

fn edgeRouteFromEndpoints(start_raw: Point, end_raw: Point, rankdir: RankDir, offset: f64) EdgeRoute {
    const start = start_raw;
    const end = end_raw;
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const curve = splineCurveAmount(rankdir, dx, dy, 24.0, 160.0);
    const controls: EdgeControls = diagonalEdgeControls(start, end, rankdir, curve) orelse switch (rankdir) {
        .TB => .{
            .c1 = Point{ .x = start.x, .y = start.y + curve },
            .c2 = Point{ .x = end.x, .y = end.y - curve },
        },
        .BT => .{
            .c1 = Point{ .x = start.x, .y = start.y - curve },
            .c2 = Point{ .x = end.x, .y = end.y + curve },
        },
        .LR => .{
            .c1 = Point{ .x = start.x + curve, .y = start.y },
            .c2 = Point{ .x = end.x - curve, .y = end.y },
        },
        .RL => .{
            .c1 = Point{ .x = start.x - curve, .y = start.y },
            .c2 = Point{ .x = end.x + curve, .y = end.y },
        },
    };
    const shifted_start = offsetPoint(start, rankdir, offset);
    const shifted_end = offsetPoint(end, rankdir, offset);
    const c1 = offsetPoint(controls.c1, rankdir, offset);
    const c2 = offsetPoint(controls.c2, rankdir, offset);
    return .{
        .start = shifted_start,
        .control1 = c1,
        .control2 = c2,
        .end = shifted_end,
        .label = cubicPoint(shifted_start, c1, c2, shifted_end, 0.5),
    };
}

fn boundaryPoint(node: NodeLayout, toward: Point, rankdir: RankDir, leaving: bool) Point {
    _ = rankdir;
    _ = leaving;
    return pointForPort(.{
        .x = node.center.x - node.width / 2.0,
        .y = node.center.y - node.height / 2.0,
        .width = node.width,
        .height = node.height,
    }, .auto, toward);
}

const RectF = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

fn clusterBoundaryPoint(graph: *const Graph, layout: *const Layout, name: []const u8, from: Point, toward: Point) ?Point {
    const rect = clusterRect(graph, layout, name) orelse return null;
    return intersectRectBoundary(rect, from, toward) orelse pointForPort(rect, .auto, toward);
}

fn clusterRect(graph: *const Graph, layout: *const Layout, name: []const u8) ?RectF {
    for (graph.clusters.items, 0..) |cluster, index| {
        if (!std.mem.eql(u8, cluster.name, name)) continue;
        if (index >= layout.clusters.len) return null;
        const box = layout.clusters[index];
        if (box.width <= 0 or box.height <= 0) return null;
        return .{ .x = box.x, .y = box.y, .width = box.width, .height = box.height };
    }
    return null;
}

fn intersectRectBoundary(rect: RectF, from: Point, toward: Point) ?Point {
    const dx = toward.x - from.x;
    const dy = toward.y - from.y;
    var best_t = std.math.floatMax(f64);
    var result: ?Point = null;

    if (dx != 0) {
        const left_t = (rect.x - from.x) / dx;
        const left_y = from.y + left_t * dy;
        if (left_t >= 0 and left_t <= 1 and left_y >= rect.y and left_y <= rect.y + rect.height and left_t < best_t) {
            best_t = left_t;
            result = .{ .x = rect.x, .y = left_y };
        }
        const right_t = (rect.x + rect.width - from.x) / dx;
        const right_y = from.y + right_t * dy;
        if (right_t >= 0 and right_t <= 1 and right_y >= rect.y and right_y <= rect.y + rect.height and right_t < best_t) {
            best_t = right_t;
            result = .{ .x = rect.x + rect.width, .y = right_y };
        }
    }

    if (dy != 0) {
        const top_t = (rect.y - from.y) / dy;
        const top_x = from.x + top_t * dx;
        if (top_t >= 0 and top_t <= 1 and top_x >= rect.x and top_x <= rect.x + rect.width and top_t < best_t) {
            best_t = top_t;
            result = .{ .x = top_x, .y = rect.y };
        }
        const bottom_t = (rect.y + rect.height - from.y) / dy;
        const bottom_x = from.x + bottom_t * dx;
        if (bottom_t >= 0 and bottom_t <= 1 and bottom_x >= rect.x and bottom_x <= rect.x + rect.width and bottom_t < best_t) {
            result = .{ .x = bottom_x, .y = rect.y + rect.height };
        }
    }

    return result;
}

fn pointOnRectBoundary(rect: RectF, point: Point) bool {
    const eps = 0.01;
    const on_left = @abs(point.x - rect.x) <= eps;
    const on_right = @abs(point.x - (rect.x + rect.width)) <= eps;
    const on_top = @abs(point.y - rect.y) <= eps;
    const on_bottom = @abs(point.y - (rect.y + rect.height)) <= eps;
    const within_x = point.x >= rect.x - eps and point.x <= rect.x + rect.width + eps;
    const within_y = point.y >= rect.y - eps and point.y <= rect.y + rect.height + eps;
    return ((on_left or on_right) and within_y) or ((on_top or on_bottom) and within_x);
}

fn pointInsideRect(rect: RectF, point: Point) bool {
    return point.x >= rect.x and point.x <= rect.x + rect.width and
        point.y >= rect.y and point.y <= rect.y + rect.height;
}

fn pointNearRectBoundary(rect: RectF, point: Point, tolerance: f64) bool {
    return distanceToRectBoundary(rect, point) <= tolerance and
        point.x >= rect.x - tolerance and point.x <= rect.x + rect.width + tolerance and
        point.y >= rect.y - tolerance and point.y <= rect.y + rect.height + tolerance;
}

fn distanceToRectBoundary(rect: RectF, point: Point) f64 {
    const left = @abs(point.x - rect.x);
    const right = @abs(rect.x + rect.width - point.x);
    const top = @abs(point.y - rect.y);
    const bottom = @abs(rect.y + rect.height - point.y);
    return @min(@min(left, right), @min(top, bottom));
}

fn portBoundaryPoint(node: NodeLayout, toward: Point, port: CompassPort, rankdir: RankDir, leaving: bool) Point {
    if (port == .auto) return boundaryPoint(node, toward, rankdir, leaving);
    return pointForPort(.{
        .x = node.center.x - node.width / 2.0,
        .y = node.center.y - node.height / 2.0,
        .width = node.width,
        .height = node.height,
    }, port, toward);
}

fn nodePortBoundaryPoint(node_item: Node, layout: NodeLayout, toward: Point, port: CompassPort, rankdir: RankDir, leaving: bool) Point {
    if (port != .auto) return portBoundaryPoint(layout, toward, port, rankdir, leaving);
    if (shapeUsesEllipseBoundary(node_item.shape)) return ellipseBoundaryPoint(layout, toward);
    return boundaryPoint(layout, toward, rankdir, leaving);
}

fn shapeUsesEllipseBoundary(shape: Shape) bool {
    return switch (shape) {
        .ellipse, .circle, .doublecircle, .mcircle => true,
        else => false,
    };
}

fn ellipseBoundaryPoint(node: NodeLayout, toward: Point) Point {
    const dx = toward.x - node.center.x;
    const dy = toward.y - node.center.y;
    if (@abs(dx) <= 0.0001 and @abs(dy) <= 0.0001) return node.center;
    const rx = @max(node.width / 2.0, 0.0001);
    const ry = @max(node.height / 2.0, 0.0001);
    const scale = 1.0 / std.math.sqrt((dx * dx) / (rx * rx) + (dy * dy) / (ry * ry));
    return .{
        .x = node.center.x + dx * scale,
        .y = node.center.y + dy * scale,
    };
}

fn recordBoundaryPoint(node_item: Node, layout: NodeLayout, toward: Point, record_port: ?[]const u8, port: CompassPort, leaving: bool) ?Point {
    _ = leaving;
    if (record_port == null) return null;
    if (node_item.shape != .record and node_item.shape != .mrecord) return null;
    const rect = recordFieldRect(node_item.label, layout, record_port.?) orelse return null;
    return pointForPort(rect, port, toward);
}

fn pointForPort(rect: RectF, port: CompassPort, toward: Point) Point {
    const cx = rect.x + rect.width / 2.0;
    const cy = rect.y + rect.height / 2.0;
    switch (port) {
        .center => return .{ .x = cx, .y = cy },
        .north => return .{ .x = cx, .y = rect.y },
        .north_east => return .{ .x = rect.x + rect.width, .y = rect.y },
        .east => return .{ .x = rect.x + rect.width, .y = cy },
        .south_east => return .{ .x = rect.x + rect.width, .y = rect.y + rect.height },
        .south => return .{ .x = cx, .y = rect.y + rect.height },
        .south_west => return .{ .x = rect.x, .y = rect.y + rect.height },
        .west => return .{ .x = rect.x, .y = cy },
        .north_west => return .{ .x = rect.x, .y = rect.y },
        .auto => {},
    }
    const dx = toward.x - cx;
    const dy = toward.y - cy;
    if (@abs(dx) > @abs(dy)) {
        return .{ .x = if (dx >= 0) rect.x + rect.width else rect.x, .y = cy };
    }
    return .{ .x = cx, .y = if (dy >= 0) rect.y + rect.height else rect.y };
}

fn recordFieldRect(label: []const u8, layout: NodeLayout, port: []const u8) ?RectF {
    var arena = RecordArena{};
    var parser = RecordParser{ .label = label, .arena = &arena };
    const root = parser.parseRecord(.horizontal) orelse return null;
    return findRecordPortRect(root, port, .{
        .x = layout.center.x - layout.width / 2.0,
        .y = layout.center.y - layout.height / 2.0,
        .width = layout.width,
        .height = layout.height,
    });
}

fn findRecordPortRect(node: RecordAst, port: []const u8, rect: RectF) ?RectF {
    if (node.children.len == 0) {
        if (node.port) |field_port| {
            if (std.mem.eql(u8, field_port, port)) return rect;
        }
        return null;
    }

    var cursor: f64 = 0;
    for (node.children, 0..) |child, index| {
        const last = index + 1 == node.children.len;
        const child_rect = switch (node.orientation) {
            .horizontal => blk: {
                const child_w = if (last) rect.width - cursor else rect.width * child.width_units / node.width_units;
                break :blk RectF{ .x = rect.x + cursor, .y = rect.y, .width = child_w, .height = rect.height };
            },
            .vertical => blk: {
                const child_h = if (last) rect.height - cursor else rect.height * child.height_units / node.height_units;
                break :blk RectF{ .x = rect.x, .y = rect.y + cursor, .width = rect.width, .height = child_h };
            },
        };
        if (findRecordPortRect(child, port, child_rect)) |found| return found;
        cursor += switch (node.orientation) {
            .horizontal => child_rect.width,
            .vertical => child_rect.height,
        };
    }
    return null;
}

fn htmlTableBoundaryPoint(node_item: Node, layout: NodeLayout, toward: Point, record_port: ?[]const u8, compass: CompassPort) ?Point {
    const port = record_port orelse return null;
    const cell_rect = htmlTableCellRect(node_item.label, layout, port) orelse return null;
    return pointForPort(cell_rect, compass, toward);
}

fn offsetPoint(point: Point, rankdir: RankDir, offset: f64) Point {
    return LayoutAxes.init(rankdir).offsetPoint(point, offset);
}

fn selfLoopRoute(node: NodeLayout) EdgeRoute {
    const radius_x = @max(32.0, node.width * 0.35);
    const radius_y = @max(28.0, node.height * 0.55);
    const start = Point{ .x = node.center.x + node.width * 0.28, .y = node.center.y - node.height / 2.0 };
    const end = Point{ .x = node.center.x + node.width / 2.0, .y = node.center.y - node.height * 0.18 };
    const c1 = Point{ .x = start.x + radius_x, .y = start.y - radius_y };
    const c2 = Point{ .x = end.x + radius_x, .y = end.y - radius_y };
    return .{
        .start = start,
        .control1 = c1,
        .control2 = c2,
        .end = end,
        .label = .{ .x = node.center.x + node.width / 2.0 + radius_x * 0.55, .y = node.center.y - node.height / 2.0 - radius_y * 0.6 },
    };
}

fn cubicPoint(p0: Point, p1: Point, p2: Point, p3: Point, t: f64) Point {
    const mt = 1.0 - t;
    const a = mt * mt * mt;
    const b = 3.0 * mt * mt * t;
    const c = 3.0 * mt * t * t;
    const d = t * t * t;
    return .{
        .x = a * p0.x + b * p1.x + c * p2.x + d * p3.x,
        .y = a * p0.y + b * p1.y + c * p2.y + d * p3.y,
    };
}

fn renderSvgTextBlock(writer: *Io.Writer, text: []const u8, x: f64, center_y: f64, font_size: f64, fill: []const u8, font_family: []const u8, label_background: bool, dominant_middle: bool) Io.Writer.Error!void {
    try renderSvgTextBlockWithAnchor(writer, text, x, center_y, font_size, fill, font_family, label_background, dominant_middle, "middle");
}

fn writeSvgTextFill(writer: *Io.Writer, fill: []const u8) Io.Writer.Error!void {
    if (std.ascii.eqlIgnoreCase(fill, "black")) return;
    try writer.print(" fill=\"{s}\"", .{fill});
}

fn plainSingleLineLabel(text: []const u8) bool {
    return std.mem.indexOfScalar(u8, text, '\n') == null and !isHtmlLikeLabel(text);
}

fn renderSvgPlainTextBlock(writer: *Io.Writer, text: []const u8, x: f64, center_y: f64, font_size: f64, fill: []const u8, font_family: []const u8, text_anchor: []const u8) Io.Writer.Error!void {
    const line_height = font_size * 1.25;
    const y = center_y - line_height / 2.0 + line_height * 0.72;
    try writer.print("<text xml:space=\"preserve\" text-anchor=\"{s}\" x=\"{d:.1}\" y=\"{d:.1}\" font-family=\"{s}\" font-size=\"{d:.2}\"", .{ text_anchor, x, y, font_family, font_size });
    try writeSvgTextFill(writer, fill);
    try writer.writeAll(">");
    try writeXmlEscaped(writer, text);
    try writer.writeAll("</text>\n");
}

fn renderSvgTextBlockWithAnchor(writer: *Io.Writer, text: []const u8, x: f64, center_y: f64, font_size: f64, fill: []const u8, font_family: []const u8, label_background: bool, dominant_middle: bool, text_anchor: []const u8) Io.Writer.Error!void {
    const line_count = displayLabelLineCount(text);
    const line_height = font_size * 1.25;
    const block_height = @as(f64, @floatFromInt(line_count)) * line_height;
    const first_y = center_y - block_height / 2.0 + line_height * 0.72;

    if (label_background) {
        const max_len = displayLabelMaxLineLen(text);
        const width = @as(f64, @floatFromInt(max_len)) * font_size * 0.62 + 12.0;
        const height = block_height + 8.0;
        try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"4\" fill=\"#ffffff\" stroke=\"#e2e8f0\" opacity=\"0.92\"/>\n", .{
            x - width / 2.0,
            center_y - height / 2.0,
            width,
            height,
        });
    }

    try writer.print("<text xml:space=\"preserve\" text-anchor=\"{s}\" x=\"{d:.1}\" y=\"{d:.1}\" font-family=\"{s}\" font-size=\"{d:.2}\"", .{ text_anchor, x, first_y, font_family, font_size });
    try writeSvgTextFill(writer, fill);
    if (dominant_middle and line_count == 1) try writer.writeAll(" dominant-baseline=\"middle\"");
    try writer.writeAll(">");
    try writeDisplayLabelTspans(writer, text, x, line_height);
    try writer.writeAll("</text>\n");
}

fn writeDisplayLabelTspans(writer: *Io.Writer, text: []const u8, x: f64, line_height: f64) Io.Writer.Error!void {
    try writer.print("<tspan x=\"{d:.1}\">", .{x});
    if (isHtmlLikeLabel(text)) {
        var scanner: HtmlLabelScanner = .{ .text = text };
        var has_text = false;
        var pending_space = false;
        var style: HtmlTextStyle = .{};
        var style_open = false;
        while (scanner.next()) |token| {
            switch (token) {
                .newline => {
                    if (style_open) {
                        try writer.writeAll("</tspan>");
                        style_open = false;
                    }
                    try writer.print("</tspan><tspan x=\"{d:.1}\" dy=\"{d:.1}\">", .{ x, line_height });
                    has_text = false;
                    pending_space = false;
                },
                .tag_open => |raw_tag| {
                    if (style_open) {
                        try writer.writeAll("</tspan>");
                        style_open = false;
                    }
                    applyHtmlOpenStyle(&style, raw_tag);
                },
                .tag_close => |tag| {
                    if (style_open) {
                        try writer.writeAll("</tspan>");
                        style_open = false;
                    }
                    resetHtmlCloseStyle(&style, tag);
                },
                .char => |c| {
                    if (isHtmlLabelSpace(c)) {
                        if (has_text) pending_space = true;
                        continue;
                    }
                    if (pending_space) {
                        if (!style_open) style_open = try writeHtmlStyleOpen(writer, style);
                        try writer.writeByte(' ');
                        pending_space = false;
                    }
                    if (!style_open) style_open = try writeHtmlStyleOpen(writer, style);
                    try writeXmlEscaped(writer, &.{c});
                    has_text = true;
                },
            }
        }
        if (style_open) try writer.writeAll("</tspan>");
    } else {
        var lines = std.mem.splitScalar(u8, text, '\n');
        var idx: usize = 0;
        while (lines.next()) |line| : (idx += 1) {
            if (idx > 0) try writer.print("</tspan><tspan x=\"{d:.1}\" dy=\"{d:.1}\">", .{ x, line_height });
            try writeXmlEscaped(writer, line);
        }
    }
    try writer.writeAll("</tspan>");
}

pub fn renderPdf(writer: *Io.Writer, graph: *const Graph, layout: *const Layout) (Io.Writer.Error || std.mem.Allocator.Error)!void {
    var content = Io.Writer.Allocating.init(graph.allocator);
    defer content.deinit();

    try content.writer.writeAll("1 w\n");
    for (graph.edges.items) |edge_item| {
        const a = layout.nodes[edge_item.from].center;
        const b = layout.nodes[edge_item.to].center;
        try content.writer.print("0.39 0.45 0.55 RG {d:.1} {d:.1} m {d:.1} {d:.1} l S\n", .{ a.x, pdfY(layout, a.y), b.x, pdfY(layout, b.y) });
        if (edge_item.label) |label| {
            try content.writer.print("BT /F1 10 Tf {d:.1} {d:.1} Td ", .{ (a.x + b.x) / 2.0, pdfY(layout, (a.y + b.y) / 2.0) + 4.0 });
            try writePdfString(&content.writer, label);
            try content.writer.writeAll(" Tj ET\n");
        }
    }

    for (graph.nodes.items) |node_item| {
        const l = layout.nodes[node_item.id];
        const color = parseHexColor(node_item.color) orelse .{ 238, 242, 255, 255 };
        try content.writer.print("{d:.3} {d:.3} {d:.3} rg 0.20 0.25 0.33 RG {d:.1} {d:.1} {d:.1} {d:.1} re B\n", .{
            @as(f64, @floatFromInt(color[0])) / 255.0,
            @as(f64, @floatFromInt(color[1])) / 255.0,
            @as(f64, @floatFromInt(color[2])) / 255.0,
            l.center.x - l.width / 2.0,
            pdfY(layout, l.center.y + l.height / 2.0),
            l.width,
            l.height,
        });
        const text_x = l.center.x - @as(f64, @floatFromInt(node_item.label.len)) * 3.2;
        const text_y = pdfY(layout, l.center.y) - 4.0;
        try content.writer.print("0.06 0.09 0.16 rg BT /F1 12 Tf {d:.1} {d:.1} Td ", .{ text_x, text_y });
        try writePdfString(&content.writer, node_item.label);
        try content.writer.writeAll(" Tj ET\n");
    }

    const stream = try content.toOwnedSlice();
    defer graph.allocator.free(stream);

    var pdf = Io.Writer.Allocating.init(graph.allocator);
    defer pdf.deinit();
    var offsets: [6]usize = @splat(0);

    try pdf.writer.writeAll("%PDF-1.4\n%\xE2\xE3\xCF\xD3\n");
    offsets[1] = pdf.writer.end;
    try pdf.writer.writeAll("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");
    offsets[2] = pdf.writer.end;
    try pdf.writer.writeAll("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n");
    offsets[3] = pdf.writer.end;
    try pdf.writer.print("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {d:.0} {d:.0}] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n", .{ layout.width, layout.height });
    offsets[4] = pdf.writer.end;
    try pdf.writer.writeAll("4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n");
    offsets[5] = pdf.writer.end;
    try pdf.writer.print("5 0 obj\n<< /Length {d} >>\nstream\n", .{stream.len});
    try pdf.writer.writeAll(stream);
    try pdf.writer.writeAll("endstream\nendobj\n");

    const xref_offset = pdf.writer.end;
    try pdf.writer.writeAll("xref\n0 6\n0000000000 65535 f \n");
    for (offsets[1..]) |offset| {
        try writePaddedPdfOffset(&pdf.writer, offset);
        try pdf.writer.writeAll(" 00000 n \n");
    }
    try pdf.writer.print("trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n{d}\n%%EOF\n", .{xref_offset});

    try writer.writeAll(pdf.writer.buffered());
}

fn pdfY(layout: *const Layout, y: f64) f64 {
    return layout.height - y;
}

fn writePdfString(writer: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    try writer.writeByte('(');
    for (text) |c| switch (c) {
        '(', ')', '\\' => {
            try writer.writeByte('\\');
            try writer.writeByte(c);
        },
        '\n' => try writer.writeAll("\\n"),
        '\r' => try writer.writeAll("\\r"),
        '\t' => try writer.writeAll("\\t"),
        else => try writer.writeByte(c),
    };
    try writer.writeByte(')');
}

fn writePaddedPdfOffset(writer: *Io.Writer, offset: usize) Io.Writer.Error!void {
    var digits: [20]u8 = undefined;
    const text = std.fmt.bufPrint(&digits, "{d}", .{offset}) catch unreachable;
    var pad: usize = 10 - @min(@as(usize, 10), text.len);
    while (pad > 0) : (pad -= 1) try writer.writeByte('0');
    if (text.len > 10) {
        try writer.writeAll(text[text.len - 10 ..]);
    } else {
        try writer.writeAll(text);
    }
}

pub fn renderPng(writer: *Io.Writer, graph: *const Graph, layout: *const Layout) (Io.Writer.Error || std.mem.Allocator.Error)!void {
    const width = @max(@as(usize, 1), @as(usize, @intFromFloat(@ceil(layout.width))));
    const height = @max(@as(usize, 1), @as(usize, @intFromFloat(@ceil(layout.height))));
    const pixels = try graph.allocator.alloc(u8, width * height * 4);
    defer graph.allocator.free(pixels);

    rasterize(graph, layout, width, height, pixels);
    try writePng(writer, width, height, pixels);
}

fn rasterize(graph: *const Graph, layout: *const Layout, width: usize, height: usize, pixels: []u8) void {
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const idx = (y * width + x) * 4;
            pixels[idx + 0] = 255;
            pixels[idx + 1] = 255;
            pixels[idx + 2] = 255;
            pixels[idx + 3] = 255;
        }
    }

    for (graph.edges.items) |edge_item| {
        const a = layout.nodes[edge_item.from].center;
        const b = layout.nodes[edge_item.to].center;
        drawLine(pixels, width, height, a.x, a.y, b.x, b.y, .{ 100, 116, 139, 255 });
    }

    for (graph.nodes.items) |node_item| {
        const l = layout.nodes[node_item.id];
        const color = parseHexColor(node_item.color) orelse .{ 238, 242, 255, 255 };
        drawFilledRect(
            pixels,
            width,
            height,
            @intFromFloat(@round(l.center.x - l.width / 2.0)),
            @intFromFloat(@round(l.center.y - l.height / 2.0)),
            @intFromFloat(@round(l.width)),
            @intFromFloat(@round(l.height)),
            color,
        );
        drawRectBorder(
            pixels,
            width,
            height,
            @intFromFloat(@round(l.center.x - l.width / 2.0)),
            @intFromFloat(@round(l.center.y - l.height / 2.0)),
            @intFromFloat(@round(l.width)),
            @intFromFloat(@round(l.height)),
            .{ 51, 65, 85, 255 },
        );
    }
}

const Rgba = [4]u8;

fn parseHexColor(value: []const u8) ?Rgba {
    if (value.len == 0) return null;
    if (value[0] != '#') return namedColor(value);
    if (value.len == 4) {
        const r = std.fmt.parseInt(u8, value[1..2], 16) catch return null;
        const g = std.fmt.parseInt(u8, value[2..3], 16) catch return null;
        const b = std.fmt.parseInt(u8, value[3..4], 16) catch return null;
        return .{ r * 17, g * 17, b * 17, 255 };
    }
    if (value.len != 7) return null;
    return .{
        std.fmt.parseInt(u8, value[1..3], 16) catch return null,
        std.fmt.parseInt(u8, value[3..5], 16) catch return null,
        std.fmt.parseInt(u8, value[5..7], 16) catch return null,
        255,
    };
}

fn namedColor(value: []const u8) ?Rgba {
    if (std.ascii.eqlIgnoreCase(value, "none") or std.ascii.eqlIgnoreCase(value, "transparent")) return .{ 0, 0, 0, 0 };
    if (std.ascii.eqlIgnoreCase(value, "black")) return .{ 0, 0, 0, 255 };
    if (std.ascii.eqlIgnoreCase(value, "white")) return .{ 255, 255, 255, 255 };
    if (std.ascii.eqlIgnoreCase(value, "red")) return .{ 255, 0, 0, 255 };
    if (std.ascii.eqlIgnoreCase(value, "green")) return .{ 0, 128, 0, 255 };
    if (std.ascii.eqlIgnoreCase(value, "blue")) return .{ 0, 0, 255, 255 };
    if (std.ascii.eqlIgnoreCase(value, "yellow")) return .{ 255, 255, 0, 255 };
    if (std.ascii.eqlIgnoreCase(value, "orange")) return .{ 255, 165, 0, 255 };
    if (std.ascii.eqlIgnoreCase(value, "purple")) return .{ 128, 0, 128, 255 };
    if (std.ascii.eqlIgnoreCase(value, "pink")) return .{ 255, 192, 203, 255 };
    if (std.ascii.eqlIgnoreCase(value, "brown")) return .{ 165, 42, 42, 255 };
    if (std.ascii.eqlIgnoreCase(value, "cyan")) return .{ 0, 255, 255, 255 };
    if (std.ascii.eqlIgnoreCase(value, "magenta")) return .{ 255, 0, 255, 255 };
    if (std.ascii.eqlIgnoreCase(value, "gray") or std.ascii.eqlIgnoreCase(value, "grey")) return .{ 128, 128, 128, 255 };
    if (std.ascii.eqlIgnoreCase(value, "lightgray") or std.ascii.eqlIgnoreCase(value, "lightgrey")) return .{ 211, 211, 211, 255 };
    if (std.ascii.eqlIgnoreCase(value, "darkgray") or std.ascii.eqlIgnoreCase(value, "darkgrey")) return .{ 169, 169, 169, 255 };
    if (std.ascii.eqlIgnoreCase(value, "slategray") or std.ascii.eqlIgnoreCase(value, "slategrey")) return .{ 112, 128, 144, 255 };
    if (std.ascii.eqlIgnoreCase(value, "lightblue")) return .{ 173, 216, 230, 255 };
    if (std.ascii.eqlIgnoreCase(value, "lightgreen")) return .{ 144, 238, 144, 255 };
    if (std.ascii.eqlIgnoreCase(value, "gold")) return .{ 255, 215, 0, 255 };
    return null;
}

fn setPixel(pixels: []u8, width: usize, height: usize, x: i64, y: i64, color: Rgba) void {
    if (x < 0 or y < 0) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    if (ux >= width or uy >= height) return;
    const idx = (uy * width + ux) * 4;
    pixels[idx + 0] = color[0];
    pixels[idx + 1] = color[1];
    pixels[idx + 2] = color[2];
    pixels[idx + 3] = color[3];
}

fn drawFilledRect(pixels: []u8, width: usize, height: usize, x: i64, y: i64, w: i64, h: i64, color: Rgba) void {
    var yy: i64 = 0;
    while (yy < h) : (yy += 1) {
        var xx: i64 = 0;
        while (xx < w) : (xx += 1) setPixel(pixels, width, height, x + xx, y + yy, color);
    }
}

fn drawRectBorder(pixels: []u8, width: usize, height: usize, x: i64, y: i64, w: i64, h: i64, color: Rgba) void {
    var xx: i64 = 0;
    while (xx < w) : (xx += 1) {
        setPixel(pixels, width, height, x + xx, y, color);
        setPixel(pixels, width, height, x + xx, y + h - 1, color);
    }
    var yy: i64 = 0;
    while (yy < h) : (yy += 1) {
        setPixel(pixels, width, height, x, y + yy, color);
        setPixel(pixels, width, height, x + w - 1, y + yy, color);
    }
}

fn drawLine(pixels: []u8, width: usize, height: usize, x0f: f64, y0f: f64, x1f: f64, y1f: f64, color: Rgba) void {
    var x0: i64 = @intFromFloat(@round(x0f));
    var y0: i64 = @intFromFloat(@round(y0f));
    const x1: i64 = @intFromFloat(@round(x1f));
    const y1: i64 = @intFromFloat(@round(y1f));
    const dx = absInt(x1 - x0);
    const sx: i64 = if (x0 < x1) 1 else -1;
    const dy = -absInt(y1 - y0);
    const sy: i64 = if (y0 < y1) 1 else -1;
    var err = dx + dy;
    while (true) {
        setPixel(pixels, width, height, x0, y0, color);
        if (x0 == x1 and y0 == y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            x0 += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y0 += sy;
        }
    }
}

fn absInt(v: i64) i64 {
    return if (v < 0) -v else v;
}

fn writePng(writer: *Io.Writer, width: usize, height: usize, rgba: []const u8) (Io.Writer.Error || std.mem.Allocator.Error)!void {
    try writer.writeAll("\x89PNG\r\n\x1a\n");

    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], @intCast(width), .big);
    std.mem.writeInt(u32, ihdr[4..8], @intCast(height), .big);
    ihdr[8] = 8; // bit depth
    ihdr[9] = 6; // RGBA
    ihdr[10] = 0; // deflate
    ihdr[11] = 0; // adaptive filter
    ihdr[12] = 0; // no interlace
    try writePngChunk(writer, "IHDR", &ihdr);

    var idat = Io.Writer.Allocating.init(std.heap.page_allocator);
    defer idat.deinit();
    var zlib = Io.Writer.Allocating.init(std.heap.page_allocator);
    defer zlib.deinit();

    // zlib header for deflate with fastest compression/check bits.
    try zlib.writer.writeAll(&.{ 0x78, 0x01 });

    var adler: u32 = 1;
    var row_start: usize = 0;
    var remaining_rows = height;
    while (remaining_rows > 0) : (remaining_rows -= 1) {
        try idat.writer.writeByte(0); // PNG filter type 0.
        updateAdler(&adler, &.{0});
        const row = rgba[row_start .. row_start + width * 4];
        try idat.writer.writeAll(row);
        updateAdler(&adler, row);
        row_start += width * 4;
    }

    const raw = try idat.toOwnedSlice();
    defer std.heap.page_allocator.free(raw);
    var offset: usize = 0;
    while (offset < raw.len) {
        const block_len = @min(@as(usize, 65535), raw.len - offset);
        const final: u8 = if (offset + block_len == raw.len) 1 else 0;
        try zlib.writer.writeByte(final);
        try zlib.writer.writeInt(u16, @intCast(block_len), .little);
        try zlib.writer.writeInt(u16, ~@as(u16, @intCast(block_len)), .little);
        try zlib.writer.writeAll(raw[offset .. offset + block_len]);
        offset += block_len;
    }
    try zlib.writer.writeInt(u32, adler, .big);

    const compressed = try zlib.toOwnedSlice();
    defer std.heap.page_allocator.free(compressed);
    try writePngChunk(writer, "IDAT", compressed);
    try writePngChunk(writer, "IEND", &.{});
}

fn updateAdler(adler: *u32, bytes: []const u8) void {
    var s1 = adler.* & 0xffff;
    var s2 = (adler.* >> 16) & 0xffff;
    for (bytes) |b| {
        s1 = (s1 + b) % 65521;
        s2 = (s2 + s1) % 65521;
    }
    adler.* = (s2 << 16) | s1;
}

fn writePngChunk(writer: *Io.Writer, tag: []const u8, data: []const u8) Io.Writer.Error!void {
    try writer.writeInt(u32, @intCast(data.len), .big);
    try writer.writeAll(tag);
    try writer.writeAll(data);
    var crc = std.hash.crc.Crc32.init();
    crc.update(tag);
    crc.update(data);
    try writer.writeInt(u32, crc.final(), .big);
}

test "code API builds graph and layered layout" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "api" });
    defer graph.deinit();

    const a = try graph.nodeWith("A", .{ .shape = .box, .label = "Start" });
    const b = try graph.node("B");
    _ = try graph.edge(a, b, .{ .label = "next" });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expectEqual(@as(usize, 2), layout.nodes.len);
    try std.testing.expect(layout.height > 0);
}

test "Fruchterman-Reingold layout places nodes within bounds" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = false, .name = "force" });
    defer graph.deinit();
    _ = try graph.edgeByName("a", "b", .{});
    _ = try graph.edgeByName("b", "c", .{});

    var layout = try layoutFruchtermanReingold(allocator, &graph, .{ .width = 320, .height = 240, .margin = 24, .iterations = 80 });
    defer layout.deinit();
    try std.testing.expectEqual(@as(usize, 3), layout.nodes.len);
    for (layout.nodes) |node| {
        try std.testing.expect(node.center.x >= 24);
        try std.testing.expect(node.center.x <= 296);
        try std.testing.expect(node.center.y >= 24);
        try std.testing.expect(node.center.y <= 216);
    }
}

test "Fruchterman-Reingold layout pulls adjacent nodes closer" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = false, .name = "force" });
    defer graph.deinit();
    _ = try graph.edgeByName("a", "b", .{});
    _ = try graph.node("c");

    var layout = try layoutFruchtermanReingold(allocator, &graph, .{ .width = 360, .height = 260, .margin = 30, .iterations = 100 });
    defer layout.deinit();
    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const ab = distanceBetween(layout.nodes[a].center, layout.nodes[b].center);
    const ac = distanceBetween(layout.nodes[a].center, layout.nodes[c].center);
    const bc = distanceBetween(layout.nodes[b].center, layout.nodes[c].center);
    try std.testing.expect(ab < @max(ac, bc));
}

test "layout algorithm parser accepts Graphviz engine names" {
    try std.testing.expectEqual(LayoutAlgorithm.sugiyama, LayoutAlgorithm.fromString("dot").?);
    try std.testing.expectEqual(LayoutAlgorithm.sugiyama, LayoutAlgorithm.fromString("sugiyama").?);
    try std.testing.expectEqual(LayoutAlgorithm.fruchterman_reingold, LayoutAlgorithm.fromString("neato").?);
    try std.testing.expectEqual(LayoutAlgorithm.fruchterman_reingold, LayoutAlgorithm.fromString("fdp").?);
    try std.testing.expectEqual(LayoutAlgorithm.fruchterman_reingold, LayoutAlgorithm.fromString("fruchterman-reingold").?);
}

test "layoutGraph selects Fruchterman-Reingold from graph layout attr" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\graph G {
        \\  graph [layout=neato];
        \\  a -- b -- c;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutGraph(allocator, &graph, .{ .algorithm = .auto });
    defer layout.deinit();
    const defaults = ForceLayoutOptions{};
    try std.testing.expectEqual(@as(usize, 1), layout.rank_depths.len);
    try std.testing.expectEqual(defaults.width, layout.width);
    try std.testing.expectEqual(defaults.height, layout.height);
}

test "layoutGraph default keeps Sugiyama rankdir as layout input" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator, "digraph G { graph [rankdir=LR]; a -> b -> c; }");
    defer graph.deinit();

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expectEqual(RankDir.LR, layout.rankdir);
    try expectRankDirection(&graph, &layout, .LR);
}

test "layout stores rankdir snapshot for routing after graph mutation" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a -> b [label="ab"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const edge_item = graph.edges.items[0];
    const route_before = edgeRouteForEdge(&graph, &layout, edge_item, layout.rankdir, 0);
    try std.testing.expectEqual(RankDir.LR, layout.rankdir);

    graph.rankdir = .TB;
    const route_after = edgeRouteForEdge(&graph, &layout, edge_item, layout.rankdir, 0);
    try std.testing.expectEqual(route_before.start.x, route_after.start.x);
    try std.testing.expectEqual(route_before.start.y, route_after.start.y);
    try std.testing.expectEqual(route_before.end.x, route_after.end.x);
    try std.testing.expectEqual(route_before.end.y, route_after.end.y);
    try std.testing.expect(route_after.start.x < route_after.end.x);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">ab</tspan>") != null);
}

test "layered layout default margin is compact and overrideable" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator, "digraph G { a -> b; }");
    defer graph.deinit();

    var compact = try layoutLayered(allocator, &graph, .{});
    defer compact.deinit();
    var roomy = try layoutLayered(allocator, &graph, .{ .margin = 40, .margin_y = 40 });
    defer roomy.deinit();

    try std.testing.expectEqual(@as(f64, 16), compact.margin);
    try std.testing.expectEqual(@as(f64, 5.5), compact.margin_y);
    try std.testing.expectEqual(@as(f64, 40), roomy.margin);
    try std.testing.expect(roomy.width > compact.width);
    try std.testing.expect(roomy.height > compact.height);
}

test "DOT parser handles graphviz-like edge chain and attrs" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  node [shape=box color="#eef2ff"];
        \\  A -> B -> C [label="flow", color="#2563eb"];
        \\}
    );
    defer graph.deinit();

    try std.testing.expect(graph.directed);
    try std.testing.expectEqual(RankDir.LR, graph.rankdir);
    try std.testing.expectEqual(@as(usize, 3), graph.nodes.items.len);
    try std.testing.expectEqual(@as(usize, 2), graph.edges.items.len);
    try std.testing.expectEqualStrings("flow", graph.edges.items[0].label.?);
}

test "Mermaid parser handles flowchart direction nodes and labels" {
    const allocator = std.testing.allocator;
    var graph = try parseMermaid(allocator,
        \\flowchart LR
        \\  start([Start]) --> decision{Ready?}
        \\  decision -->|yes| done((Done))
        \\  decision -.->|no| start
    );
    defer graph.deinit();

    try std.testing.expectEqual(RankDir.LR, graph.rankdir);
    try std.testing.expectEqual(@as(usize, 3), graph.edges.items.len);
    const start = graph.node_index.get("start").?;
    const decision = graph.node_index.get("decision").?;
    const done = graph.node_index.get("done").?;
    try std.testing.expectEqual(Shape.box, graph.nodes.items[start].shape);
    try std.testing.expect(std.mem.indexOf(u8, attrValue(graph.nodes.items[start].attrs.items, "style").?, "rounded") != null);
    try std.testing.expectEqual(Shape.diamond, graph.nodes.items[decision].shape);
    try std.testing.expectEqual(Shape.circle, graph.nodes.items[done].shape);
    try std.testing.expectEqualStrings("Start", graph.nodes.items[start].label);
    try std.testing.expectEqualStrings("Ready?", graph.nodes.items[decision].label);
    try std.testing.expectEqualStrings("yes", graph.edges.items[1].label.?);
    try std.testing.expectEqualStrings("no", graph.edges.items[2].label.?);
    try std.testing.expectEqualStrings("dotted", attrValue(graph.edges.items[2].attrs.items, "style").?);
}

test "Mermaid parser handles labels embedded in arrows" {
    const allocator = std.testing.allocator;
    var graph = try parseMermaid(allocator,
        \\flowchart LR
        \\  A -- needs review --> B
        \\  C -- "Some text" --> D
        \\  N01 -.audit.-> N16
        \\  svc.api -.db-sync.-> db.main
    );
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 4), graph.edges.items.len);
    try std.testing.expectEqualStrings("needs review", graph.edges.items[0].label.?);
    try std.testing.expectEqualStrings("Some text", graph.edges.items[1].label.?);
    try std.testing.expectEqualStrings("audit", graph.edges.items[2].label.?);
    try std.testing.expectEqualStrings("db-sync", graph.edges.items[3].label.?);
    try std.testing.expectEqualStrings("dotted", attrValue(graph.edges.items[2].attrs.items, "style").?);
    try std.testing.expectEqualStrings("dotted", attrValue(graph.edges.items[3].attrs.items, "style").?);
    try std.testing.expect(graph.node_index.get(".audit") == null);
    try std.testing.expect(graph.node_index.get(".db-sync") == null);
    try std.testing.expect(graph.node_index.get("svc.api") != null);
    try std.testing.expect(graph.node_index.get("db.main") != null);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "needs review") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Some text") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "db-sync") != null);
}

test "input format auto detects Mermaid flowcharts without breaking DOT graphs" {
    try std.testing.expectEqual(InputFormat.mermaid, detectInputFormat("flowchart TD\nA --> B"));
    try std.testing.expectEqual(InputFormat.mermaid, detectInputFormat("graph LR\nA --> B"));
    try std.testing.expectEqual(InputFormat.dot, detectInputFormat("graph G { a -- b }"));
}

test "Mermaid parser maps flowchart subgraphs to clusters" {
    const allocator = std.testing.allocator;
    var graph = try parseMermaid(allocator,
        \\flowchart TD
        \\  subgraph API[API Layer]
        \\    A[Request] --> B[Handler]
        \\  end
        \\  B --> C[Response]
    );
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 1), graph.clusters.items.len);
    try std.testing.expectEqualStrings("API", graph.clusters.items[0].name);
    try std.testing.expectEqualStrings("API Layer", graph.clusters.items[0].label);
    try std.testing.expectEqual(@as(usize, 2), graph.clusters.items[0].nodes.len);
    try std.testing.expectEqual(@as(usize, 2), graph.edges.items.len);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>API</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "API Layer") != null);
}

test "Mermaid parser applies node style directives" {
    const allocator = std.testing.allocator;
    var graph = try parseMermaid(allocator,
        \\flowchart LR
        \\  A[Alpha] --> B[Beta]
        \\  style B fill:#0f0,stroke:#090,stroke-width:3,color:#111
    );
    defer graph.deinit();

    const b = graph.node_index.get("B").?;
    try std.testing.expectEqualStrings("#0f0", attrValue(graph.nodes.items[b].attrs.items, "fillcolor").?);
    try std.testing.expectEqualStrings("#090", attrValue(graph.nodes.items[b].attrs.items, "color").?);
    try std.testing.expectEqualStrings("3", attrValue(graph.nodes.items[b].attrs.items, "penwidth").?);
    try std.testing.expectEqualStrings("#111", attrValue(graph.nodes.items[b].attrs.items, "fontcolor").?);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#0f0\" stroke=\"#090\" stroke-width=\"3.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#111\"") != null);
}

test "Mermaid parser applies classDef and class directives" {
    const allocator = std.testing.allocator;
    var graph = try parseMermaid(allocator,
        \\flowchart LR
        \\  classDef hot fill:#f00,stroke:#000,color:#fff,stroke-width:2
        \\  A[Alpha] --> B[Beta]
        \\  class A hot
    );
    defer graph.deinit();

    const a = graph.node_index.get("A").?;
    try std.testing.expectEqualStrings("#f00", attrValue(graph.nodes.items[a].attrs.items, "fillcolor").?);
    try std.testing.expectEqualStrings("#000", attrValue(graph.nodes.items[a].attrs.items, "color").?);
    try std.testing.expectEqualStrings("#fff", attrValue(graph.nodes.items[a].attrs.items, "fontcolor").?);
    try std.testing.expectEqualStrings("2", attrValue(graph.nodes.items[a].attrs.items, "penwidth").?);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#f00\" stroke=\"#000\" stroke-width=\"2.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#fff\"") != null);
}

test "Mermaid parser applies inline class directives" {
    const allocator = std.testing.allocator;
    var graph = try parseMermaid(allocator,
        \\flowchart LR
        \\  classDef hot fill:#f00,stroke:#000,color:#fff,stroke-width:2
        \\  A[Alpha]:::hot --> B[Beta]
    );
    defer graph.deinit();

    const a = graph.node_index.get("A").?;
    try std.testing.expectEqualStrings("#f00", attrValue(graph.nodes.items[a].attrs.items, "fillcolor").?);
    try std.testing.expectEqualStrings("#000", attrValue(graph.nodes.items[a].attrs.items, "color").?);
    try std.testing.expectEqualStrings("#fff", attrValue(graph.nodes.items[a].attrs.items, "fontcolor").?);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#f00\" stroke=\"#000\" stroke-width=\"2.0\"") != null);
}

test "Mermaid parser applies linkStyle directives" {
    const allocator = std.testing.allocator;
    var graph = try parseMermaid(allocator,
        \\flowchart LR
        \\  A[Alpha] --> B[Beta]
        \\  B -.-> C[Gamma]
        \\  linkStyle 1 stroke:#ff0,stroke-width:4,stroke-dasharray:5 5,color:#123
    );
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 2), graph.edges.items.len);
    try std.testing.expectEqualStrings("#ff0", graph.edges.items[1].color);
    try std.testing.expectEqualStrings("4", attrValue(graph.edges.items[1].attrs.items, "penwidth").?);
    try std.testing.expectEqualStrings("dashed", attrValue(graph.edges.items[1].attrs.items, "style").?);
    try std.testing.expectEqualStrings("#123", attrValue(graph.edges.items[1].attrs.items, "fontcolor").?);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"#ff0\" d=\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "\" stroke-width=\"4.0\" stroke-dasharray=\"8,5\"") != null);
}

test "SVG renderer emits document" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator, "graph H { a -- b [label=test]; }");
    defer graph.deinit();
    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.startsWith(u8, svg, "<svg"));
    try std.testing.expect(std.mem.indexOf(u8, svg, "test") != null);

    const term = try renderAlloc(allocator, &graph, &layout, .terminal, .{});
    defer allocator.free(term);
    try std.testing.expect(std.mem.indexOf(u8, term, "a -- b") != null);
}

test "SVG geometry parser reads Graphviz-style path and polygon numbers" {
    const fragment =
        \\<path fill="none" stroke="black" d="M63,-287.91C63,-280.62 63,-271.94 63,-263.75"/>
        \\<polygon fill="black" points="66.5,-263.83 63,-253.83 59.5,-263.83 66.5,-263.83"/>
    ;
    var numbers: [16]f64 = undefined;
    const path_count = svgNumbersInAttribute(fragment, "d", numbers[0..]);
    try std.testing.expectEqual(@as(usize, 8), path_count);
    try std.testing.expectEqual(@as(f64, 63), numbers[0]);
    try std.testing.expectEqual(@as(f64, -287.91), numbers[1]);
    try std.testing.expectEqual(@as(f64, -263.75), numbers[7]);

    const point_count = svgNumbersInAttribute(fragment, "points", numbers[0..]);
    try std.testing.expectEqual(@as(usize, 8), point_count);
    try std.testing.expectEqual(@as(f64, 66.5), numbers[0]);
    try std.testing.expectEqual(@as(f64, -263.83), numbers[1]);
}

test "SVG cluster geometry parser handles Graphviz polygon clusters" {
    const svg =
        \\<svg>
        \\<g id="graph0" class="graph" transform="scale(1 1) rotate(0) translate(4 405.01)">
        \\<g id="clust1" class="cluster">
        \\<title>cluster_0</title>
        \\<polygon fill="lightgrey" stroke="lightgrey" points="8,-64.21 8,-357.01 98,-357.01 98,-64.21 8,-64.21"/>
        \\</g>
        \\<g id="node1" class="node">
        \\<title>a0</title>
        \\<ellipse fill="white" stroke="white" cx="63" cy="-306.21" rx="27" ry="18"/>
        \\</g>
        \\</g>
        \\</svg>
    ;

    try std.testing.expectEqual(@as(f64, 8.0), svgClusterRectX(svg, "cluster_0").?);
    try std.testing.expectEqual(@as(f64, 90.0), svgClusterRectWidth(svg, "cluster_0").?);
    try std.testing.expectEqual(@as(f64, 12.0), svgClusterScreenX(svg, "cluster_0").?);
    try std.testing.expectEqual(@as(f64, 67.0), svgNodeScreenCenterX(svg, "a0").?);
}

test "DOT parser supports subgraphs, ports, escaped strings, and HTML-like ids" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\strict digraph Fancy {
        \\  graph [rankdir=BT label=< <B>Fancy</B> Graph >];
        \\  node [shape=box color="#fee2e2"];
        \\  subgraph cluster_left {
        \\    a:out [label="hello\nworld"];
        \\    b;
        \\  }
        \\  { c d } -> subgraph cluster_left { e f } [label="fanout"];
        \\  a:out:e -> b:in:w [label="port edge"];
        \\  -1 [label="<&>"];
        \\}
    );
    defer graph.deinit();

    try std.testing.expect(graph.strict);
    try std.testing.expectEqual(RankDir.BT, graph.rankdir);
    try std.testing.expectEqual(@as(usize, 7), graph.nodes.items.len);
    try std.testing.expectEqual(@as(usize, 5), graph.edges.items.len);
    const a = graph.node_index.get("a").?;
    try std.testing.expectEqualStrings("hello\nworld", graph.nodes.items[a].label);
    try std.testing.expect(graph.attrs.items.len >= 2);
    try std.testing.expectEqualStrings(" <B>Fancy</B> Graph ", graph.attrs.items[1].value);
}

test "layered layout orients rank progression for every rankdir" {
    const allocator = std.testing.allocator;

    var tb = try parseDot(allocator, "digraph G { graph [rankdir=TB]; a -> b -> c; }");
    defer tb.deinit();
    var tb_layout = try layoutLayered(allocator, &tb, .{});
    defer tb_layout.deinit();
    try expectRankDirection(&tb, &tb_layout, .TB);

    var bt = try parseDot(allocator, "digraph G { graph [rankdir=BT]; a -> b -> c; }");
    defer bt.deinit();
    var bt_layout = try layoutLayered(allocator, &bt, .{});
    defer bt_layout.deinit();
    try expectRankDirection(&bt, &bt_layout, .BT);

    var lr = try parseDot(allocator, "digraph G { graph [rankdir=LR]; a -> b -> c; }");
    defer lr.deinit();
    var lr_layout = try layoutLayered(allocator, &lr, .{});
    defer lr_layout.deinit();
    try expectRankDirection(&lr, &lr_layout, .LR);

    var rl = try parseDot(allocator, "digraph G { graph [rankdir=RL]; a -> b -> c; }");
    defer rl.deinit();
    var rl_layout = try layoutLayered(allocator, &rl, .{});
    defer rl_layout.deinit();
    try expectRankDirection(&rl, &rl_layout, .RL);
}

test "layered layout applies separated margins for horizontal rankdirs" {
    const allocator = std.testing.allocator;
    var lr = try parseDot(allocator, "digraph G { graph [rankdir=LR]; a -> b; }");
    defer lr.deinit();

    var layout = try layoutLayered(allocator, &lr, .{ .margin = 40, .margin_y = 8 });
    defer layout.deinit();
    const a = lr.node_index.get("a").?;
    const b = lr.node_index.get("b").?;

    try std.testing.expectEqual(@as(f64, 40), layout.margin_x);
    try std.testing.expectEqual(@as(f64, 8), layout.margin_y);
    try std.testing.expect(layout.nodes[a].center.x >= layout.margin_x + layout.nodes[a].width / 2.0);
    try std.testing.expect(layout.nodes[a].center.y >= layout.margin_y + layout.nodes[a].height / 2.0);
    try std.testing.expect(layout.nodes[b].center.x > layout.nodes[a].center.x);
    try std.testing.expect(layout.height < layout.width);
}

test "layered layout separates clusters along rankdir-aware same-rank axis" {
    const allocator = std.testing.allocator;
    var lr = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  { rank=same; top; bottom; }
        \\  subgraph cluster_top { top; }
        \\  subgraph cluster_bottom { bottom; }
        \\  top -> sink;
        \\  bottom -> sink;
        \\}
    );
    defer lr.deinit();

    var layout = try layoutLayered(allocator, &lr, .{});
    defer layout.deinit();
    const top = lr.node_index.get("top").?;
    const bottom = lr.node_index.get("bottom").?;
    const sink = lr.node_index.get("sink").?;

    try std.testing.expectEqual(RankDir.LR, layout.rankdir);
    try std.testing.expect(@abs(layout.nodes[top].center.x - layout.nodes[bottom].center.x) <= 0.01);
    try std.testing.expect(layout.nodes[sink].center.x > layout.nodes[top].center.x);
    try std.testing.expect(@abs(layout.nodes[bottom].center.y - layout.nodes[top].center.y) >= 80.0);
    try std.testing.expect(layout.height <= defaultClusterAlongExtentBudget);
}

fn expectRankDirection(graph: *const Graph, layout: *const Layout, rankdir: RankDir) !void {
    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    switch (rankdir) {
        .TB => {
            try std.testing.expect(layout.nodes[a].center.y < layout.nodes[b].center.y);
            try std.testing.expect(layout.nodes[b].center.y < layout.nodes[c].center.y);
        },
        .BT => {
            try std.testing.expect(layout.nodes[a].center.y > layout.nodes[b].center.y);
            try std.testing.expect(layout.nodes[b].center.y > layout.nodes[c].center.y);
        },
        .LR => {
            try std.testing.expect(layout.nodes[a].center.x < layout.nodes[b].center.x);
            try std.testing.expect(layout.nodes[b].center.x < layout.nodes[c].center.x);
        },
        .RL => {
            try std.testing.expect(layout.nodes[a].center.x > layout.nodes[b].center.x);
            try std.testing.expect(layout.nodes[b].center.x > layout.nodes[c].center.x);
        },
    }
}

test "render dispatch covers terminal and svg formats" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "dispatch", .rankdir = .LR });
    defer graph.deinit();
    _ = try graph.edgeByName("left", "right", .{ .label = "go", .color = "#16a34a" });
    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const svg = try renderAlloc(allocator, &graph, &layout, .svg, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"#16a34a\" stroke=\"#16a34a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "go") != null);

    try graph.setNodeAttr(graph.node_index.get("left").?, "label", "<&>");
    var escaped_layout = try layoutLayered(allocator, &graph, .{});
    defer escaped_layout.deinit();
    const escaped_svg = try renderAlloc(allocator, &graph, &escaped_layout, .svg, .{});
    defer allocator.free(escaped_svg);
    try std.testing.expect(std.mem.indexOf(u8, escaped_svg, "&lt;&amp;&gt;") != null);

    const term = try renderAlloc(allocator, &graph, &layout, .terminal, .{});
    defer allocator.free(term);
    try std.testing.expect(std.mem.indexOf(u8, term, "left -> right") != null);
}

test "DOT parser handles mainstream node lists, string concat, and boolean attrs" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\graph Mainstream {
        \\  graph [label="hello" + " world"];
        \\  node [shape=box];
        \\  a, b, c [style=filled];
        \\  a, b -- c, d [label="many" + " edges"];
        \\  "quoted id" [tooltip];
        \\  esc [label="left\lright\N quote\" slash\\ keep\x"];
        \\  3.14 -- -2;
        \\}
    );
    defer graph.deinit();

    try std.testing.expect(!graph.directed);
    try std.testing.expectEqual(@as(usize, 8), graph.nodes.items.len);
    try std.testing.expectEqual(@as(usize, 5), graph.edges.items.len);
    try std.testing.expectEqualStrings("hello world", graph.attrs.items[0].value);
    try std.testing.expectEqualStrings("many edges", graph.edges.items[0].label.?);
    const a = graph.node_index.get("a").?;
    var found_default_shape = false;
    for (graph.nodes.items[a].attrs.items) |attr| {
        if (std.mem.eql(u8, attr.name, "shape") and std.mem.eql(u8, attr.value, "box")) found_default_shape = true;
    }
    try std.testing.expect(found_default_shape);
    const quoted = graph.node_index.get("quoted id").?;
    var found_tooltip = false;
    for (graph.nodes.items[quoted].attrs.items) |attr| {
        if (std.mem.eql(u8, attr.name, "tooltip") and std.mem.eql(u8, attr.value, "true")) found_tooltip = true;
    }
    try std.testing.expect(found_tooltip);
    const esc = graph.node_index.get("esc").?;
    try std.testing.expectEqualStrings("left\nrightesc quote\" slash\\ keep\\x", graph.nodes.items[esc].label);
}

test "DOT label escapes expand graph node and edge context" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph Ctx {
        \\  node_a [label="node=\N graph=\G"];
        \\  node_a -> node_b [label="\T|\H|\E|\G"];
        \\}
    );
    defer graph.deinit();

    const node_a = graph.node_index.get("node_a").?;
    try std.testing.expectEqualStrings("node=node_a graph=Ctx", graph.nodes.items[node_a].label);
    try std.testing.expectEqualStrings("node_a|node_b|node_a->node_b|Ctx", graph.edges.items[0].label.?);
}

test "layered layout uses crossing reduction and variable label sizes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  A; B; C; D;
        \\  A -> D;
        \\  B -> C;
        \\  wide [label="a much wider label\nsecond line", shape=box];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const a = graph.node_index.get("A").?;
    const b = graph.node_index.get("B").?;
    const c = graph.node_index.get("C").?;
    const d = graph.node_index.get("D").?;
    try std.testing.expect(layout.nodes[a].center.x < layout.nodes[b].center.x);
    try std.testing.expect(layout.nodes[d].center.x < layout.nodes[c].center.x);

    const wide = graph.node_index.get("wide").?;
    try std.testing.expect(layout.nodes[wide].width > layout.nodes[a].width * 1.5);
    try std.testing.expect(layout.nodes[wide].height > layout.nodes[a].height);
}

test "adjacent exchange reduces residual two-layer crossings" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  A; B; C; D;
        \\  A -> D;
        \\  B -> C;
        \\}
    );
    defer graph.deinit();

    const a = graph.node_index.get("A").?;
    const b = graph.node_index.get("B").?;
    const c = graph.node_index.get("C").?;
    const d = graph.node_index.get("D").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    @memset(ranks, 0);
    ranks[c] = 1;
    ranks[d] = 1;

    var levels = try allocator.alloc(std.ArrayList(NodeId), 2);
    defer allocator.free(levels);
    levels[0] = .empty;
    levels[1] = .empty;
    defer {
        levels[0].deinit(allocator);
        levels[1].deinit(allocator);
    }
    try levels[0].append(allocator, a);
    try levels[0].append(allocator, b);
    try levels[1].append(allocator, c);
    try levels[1].append(allocator, d);

    try std.testing.expectEqual(@as(usize, 1), countLayerCrossings(&graph, levels[0].items, levels[1].items, ranks));
    refineAdjacentExchanges(&graph, levels, ranks, 2);
    try std.testing.expectEqual(@as(usize, 0), countLayerCrossings(&graph, levels[0].items, levels[1].items, ranks));
}

test "adjacent exchange bubbles successful swaps backward in one pass" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const x = try graph.node("x");
    const y = try graph.node("y");
    const z = try graph.node("z");
    _ = try graph.edge(a, x, .{});
    _ = try graph.edge(b, y, .{});
    _ = try graph.edge(c, z, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 0;
    ranks[x] = 1;
    ranks[y] = 1;
    ranks[z] = 1;

    var levels = try allocator.alloc(std.ArrayList(NodeId), 2);
    defer allocator.free(levels);
    levels[0] = .empty;
    levels[1] = .empty;
    defer {
        levels[0].deinit(allocator);
        levels[1].deinit(allocator);
    }

    try levels[0].append(allocator, a);
    try levels[0].append(allocator, b);
    try levels[0].append(allocator, c);
    try levels[1].append(allocator, z);
    try levels[1].append(allocator, y);
    try levels[1].append(allocator, x);

    try std.testing.expectEqual(@as(usize, 3), countLayerCrossings(&graph, levels[0].items, levels[1].items, ranks));
    refineAdjacentExchanges(&graph, levels, ranks, 1);
    try std.testing.expectEqual(@as(usize, 0), countLayerCrossings(&graph, levels[0].items, levels[1].items, ranks));
}

test "guarded median ordering refuses worse total crossings" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const p0 = try graph.node("p0");
    const p1 = try graph.node("p1");
    const x = try graph.node("x");
    const y = try graph.node("y");
    const z = try graph.node("z");
    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    _ = try graph.edge(p0, z, .{});
    _ = try graph.edge(p1, x, .{});
    _ = try graph.edge(x, a, .{});
    _ = try graph.edge(y, b, .{});
    _ = try graph.edge(z, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[p0] = 0;
    ranks[p1] = 0;
    ranks[x] = 1;
    ranks[y] = 1;
    ranks[z] = 1;
    ranks[a] = 2;
    ranks[b] = 2;
    ranks[c] = 2;

    var levels = try allocator.alloc(std.ArrayList(NodeId), 3);
    defer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    defer for (levels) |*level| level.deinit(allocator);

    try levels[0].append(allocator, p0);
    try levels[0].append(allocator, p1);
    try levels[1].append(allocator, x);
    try levels[1].append(allocator, y);
    try levels[1].append(allocator, z);
    try levels[2].append(allocator, a);
    try levels[2].append(allocator, b);
    try levels[2].append(allocator, c);

    const positions = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(positions);
    const median_positions = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(median_positions);

    try std.testing.expectEqual(@as(usize, 1), totalLayerCrossings(&graph, levels, ranks));
    buildPositionMap(positions, levels[0].items);
    orderLevelByMedian(&graph, ranks, &levels[1], positions, median_positions, true);
    try std.testing.expect(totalLayerCrossings(&graph, levels, ranks) > 1);

    levels[1].clearRetainingCapacity();
    try levels[1].append(allocator, x);
    try levels[1].append(allocator, y);
    try levels[1].append(allocator, z);
    buildPositionMap(positions, levels[0].items);
    try orderLevelByMedianGuarded(allocator, &graph, ranks, levels, 1, positions, median_positions, true);
    try std.testing.expectEqual(@as(usize, 1), totalLayerCrossings(&graph, levels, ranks));
    try std.testing.expectEqual(x, levels[1].items[0]);
    try std.testing.expectEqual(y, levels[1].items[1]);
    try std.testing.expectEqual(z, levels[1].items[2]);
}

test "long edges contribute virtual segments to crossing score" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    const e = try graph.node("e");
    _ = try graph.edge(a, e, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;
    ranks[d] = 2;
    ranks[e] = 2;

    var levels = try allocator.alloc(std.ArrayList(NodeId), 3);
    defer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    defer for (levels) |*level| level.deinit(allocator);

    try levels[0].append(allocator, a);
    try levels[0].append(allocator, b);
    try levels[1].append(allocator, c);
    try levels[2].append(allocator, d);
    try levels[2].append(allocator, e);

    try std.testing.expectEqual(@as(usize, 0), countLayerCrossings(&graph, levels[0].items, levels[1].items, ranks));
    try std.testing.expectEqual(@as(usize, 1), countLayerCrossingsWithDummies(&graph, levels, ranks, 0));
}

test "adjacent exchange uses virtual long-edge crossings" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    const e = try graph.node("e");
    const f = try graph.node("f");
    _ = try graph.edge(a, f, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;
    ranks[d] = 1;
    ranks[e] = 2;
    ranks[f] = 2;

    var levels = try allocator.alloc(std.ArrayList(NodeId), 3);
    defer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    defer for (levels) |*level| level.deinit(allocator);

    try levels[0].append(allocator, a);
    try levels[0].append(allocator, b);
    try levels[1].append(allocator, c);
    try levels[1].append(allocator, d);
    try levels[2].append(allocator, e);
    try levels[2].append(allocator, f);

    try std.testing.expectEqual(@as(usize, 1), crossingScoreAroundLevel(&graph, levels, ranks, 1));
    refineAdjacentExchanges(&graph, levels, ranks, 2);
    try std.testing.expectEqual(@as(usize, 0), crossingScoreAroundLevel(&graph, levels, ranks, 1));
}

test "long-edge dummy positions influence coordinate refinement" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    _ = try graph.edge(a, d, .{ .weight = 4 });

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 1;
    ranks[d] = 2;

    var levels = try allocator.alloc(std.ArrayList(NodeId), 3);
    defer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    defer for (levels) |*level| level.deinit(allocator);
    try levels[0].append(allocator, a);
    try levels[1].append(allocator, b);
    try levels[1].append(allocator, c);
    try levels[2].append(allocator, d);

    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    const centers = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(centers);
    centers[a] = 0;
    centers[b] = 120;
    centers[c] = 180;
    centers[d] = 0;
    const before = centers[b];
    refineLongEdgeDummyCoordinates(&graph, levels, ranks, centers, sizes, 10);
    try std.testing.expect(centers[b] < before);
}

test "simple adjacent edge straightening reduces chain wobble" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const side = try graph.node("side");
    _ = try graph.edge(a, b, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 2;
    ranks[side] = 1;

    var levels = try allocator.alloc(std.ArrayList(NodeId), 3);
    defer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    defer for (levels) |*level| level.deinit(allocator);
    try levels[0].append(allocator, a);
    try levels[1].append(allocator, b);
    try levels[1].append(allocator, side);
    try levels[2].append(allocator, c);

    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    const centers = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(centers);
    centers[a] = 10;
    centers[b] = 80;
    centers[side] = 120;
    centers[c] = 10;

    const before = @abs(centers[b] - centers[a]) + @abs(centers[b] - centers[c]);
    straightenSimpleAdjacentEdges(&graph, levels, ranks, centers, sizes, 10, 2);
    const after = @abs(centers[b] - centers[a]) + @abs(centers[b] - centers[c]);
    try std.testing.expect(after < before);
    try std.testing.expect(centers[side] >= centers[b] + sizes[b].width / 2.0 + 10 + sizes[side].width / 2.0);
}

test "coordinate refinement centers nodes on adjacent neighbor spans" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const parent = try graph.node("parent");
    const left = try graph.node("left");
    const right = try graph.node("right");
    _ = try graph.edge(parent, left, .{});
    _ = try graph.edge(parent, right, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[parent] = 0;
    ranks[left] = 1;
    ranks[right] = 1;

    const centers = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(centers);
    centers[parent] = 0;
    centers[left] = 40;
    centers[right] = 160;

    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    sizes[parent] = .{ .width = 20, .height = 20 };
    sizes[left] = .{ .width = 20, .height = 20 };
    sizes[right] = .{ .width = 60, .height = 20 };

    const target = neighborSpanCenter(&graph, ranks, centers, sizes, parent, false) orelse return error.MissingNeighborSpan;
    try std.testing.expectEqual(@as(f64, 110), target);
    centerLevelOnNeighborSpans(&graph, ranks, &.{parent}, centers, sizes, false, 1.0);
    try std.testing.expectEqual(target, centers[parent]);
}

test "guarded span alignment accepts lower-stress layer move" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const p = try graph.node("p");
    const a = try graph.node("a");
    const b = try graph.node("b");
    _ = try graph.edge(p, a, .{ .weight = 4 });
    _ = try graph.edge(p, b, .{ .weight = 4 });

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[p] = 0;
    ranks[a] = 1;
    ranks[b] = 1;

    var centers = [_]f64{ 50, 120, 160 };
    const sizes = [_]NodeSize{
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
    };
    const level = [_]NodeId{ a, b };
    const before = coordinateEdgeStress(&graph, ranks, centers[0..]);
    alignLevelToNeighborSpansIfHelpful(&graph, level[0..], ranks, centers[0..], sizes[0..], 10, true);
    const after = coordinateEdgeStress(&graph, ranks, centers[0..]);
    try std.testing.expect(after < before);
}

test "guarded span alignment rejects wider layer move" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const p0 = try graph.node("p0");
    const p1 = try graph.node("p1");
    const a = try graph.node("a");
    const b = try graph.node("b");
    _ = try graph.edge(p0, a, .{ .weight = 1 });
    _ = try graph.edge(p1, b, .{ .weight = 1 });

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[p0] = 0;
    ranks[p1] = 0;
    ranks[a] = 1;
    ranks[b] = 1;

    var centers = [_]f64{ 0, 200, 40, 70 };
    const sizes = [_]NodeSize{
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
    };
    const level = [_]NodeId{ a, b };
    const before_a = centers[a];
    const before_b = centers[b];
    alignLevelToNeighborSpansIfHelpful(&graph, level[0..], ranks, centers[0..], sizes[0..], 10, true);
    try std.testing.expectEqual(before_a, centers[a]);
    try std.testing.expectEqual(before_b, centers[b]);
}

test "guarded span alignment preserves heavy edge proximity" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const left = try graph.node("left");
    const right = try graph.node("right");
    const child = try graph.node("child");
    _ = try graph.edge(left, child, .{ .weight = 1 });
    _ = try graph.edge(right, child, .{ .weight = 8 });

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[left] = 0;
    ranks[right] = 0;
    ranks[child] = 1;

    var centers = [_]f64{ 40, 100, 92 };
    const sizes = [_]NodeSize{
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
    };
    const level = [_]NodeId{child};
    const before = @abs(centers[child] - centers[right]);
    alignLevelToNeighborSpansIfHelpful(&graph, level[0..], ranks, centers[0..], sizes[0..], 10, true);
    const after = @abs(centers[child] - centers[right]);
    try std.testing.expect(after <= before);
}

test "explicit DOT edge weights gate span alignment in layout" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  edge [weight=2];
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    try std.testing.expect(graphHasExplicitEdgeWeight(&graph));
}

test "level center compaction balances forward and backward pushes" {
    const level = [_]NodeId{ 0, 1, 2 };
    var centers = [_]f64{ 40, 42, 44 };
    const sizes = [_]NodeSize{
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
    };

    compactLevelCentersSymmetric(level[0..], centers[0..], sizes[0..], 10);

    try std.testing.expect(centers[1] - centers[0] >= 30);
    try std.testing.expect(centers[2] - centers[1] >= 30);
    try std.testing.expect(centers[1] < 70);
}

test "coordinate edge stress rewards straighter edges" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    _ = try graph.edge(a, b, .{ .weight = 4 });

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    var centers = [_]f64{ 20, 80 };
    const skewed = coordinateEdgeStress(&graph, ranks, centers[0..]);
    centers[b] = centers[a];
    const straight = coordinateEdgeStress(&graph, ranks, centers[0..]);
    try std.testing.expect(straight < skewed);
}

test "label width estimation uses Times-like character classes" {
    const narrow = displayLabelEstimatedWidth("iiii", 14.0);
    const wide = displayLabelEstimatedWidth("mmmm", 14.0);
    const digits = displayLabelEstimatedWidth("####", 14.0);
    const html = displayLabelEstimatedWidth("<B>ii</B> <I>mm</I>", 14.0);

    try std.testing.expect(narrow < digits);
    try std.testing.expect(digits < wide);
    try std.testing.expect(html > narrow);
    try std.testing.expect(html < wide);
}

test "guarded symmetric compaction rejects wider or higher-stress changes" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const p = try graph.node("p");
    _ = try graph.edge(p, b, .{ .weight = 5 });

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[p] = 0;
    ranks[a] = 1;
    ranks[b] = 1;
    ranks[c] = 1;

    var levels = try allocator.alloc(std.ArrayList(NodeId), 2);
    defer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    defer for (levels) |*level| level.deinit(allocator);
    try levels[0].append(allocator, p);
    try levels[1].append(allocator, a);
    try levels[1].append(allocator, b);
    try levels[1].append(allocator, c);

    var centers = [_]f64{ 40, 40, 70, 100 };
    const sizes = [_]NodeSize{
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
        .{ .width = 20, .height = 10 },
    };
    const before_b = centers[b];
    applySymmetricCompactionIfHelpful(&graph, levels, ranks, centers[0..], sizes[0..], 10);
    try std.testing.expectEqual(before_b, centers[b]);
}

test "virtual levels include dummy nodes for skip-rank edges" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    _ = try graph.edge(a, d, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;
    ranks[d] = 3;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();

    try std.testing.expectEqual(@as(usize, 4), virtual_levels.levels.len);
    try std.testing.expect(virtualLevelContains(virtual_levels.levels[0].items, .{ .real = a }));
    try std.testing.expect(virtualLevelContains(virtual_levels.levels[1].items, .{ .real = c }));
    try std.testing.expect(virtualLevelContains(virtual_levels.levels[1].items, .{ .dummy = 0 }));
    try std.testing.expect(virtualLevelContains(virtual_levels.levels[2].items, .{ .dummy = 0 }));
    try std.testing.expect(virtualLevelContains(virtual_levels.levels[3].items, .{ .real = d }));
}

test "virtual levels can extract real node levels" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    _ = try graph.edge(a, d, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;
    ranks[d] = 3;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();
    const real_levels = try extractRealLevelsFromVirtual(allocator, &virtual_levels);
    defer {
        for (real_levels) |*level| level.deinit(allocator);
        allocator.free(real_levels);
    }

    try std.testing.expectEqual(@as(usize, 4), real_levels.len);
    try std.testing.expectEqual(@as(usize, 2), real_levels[0].items.len);
    try std.testing.expectEqual(a, real_levels[0].items[0]);
    try std.testing.expectEqual(b, real_levels[0].items[1]);
    try std.testing.expectEqual(@as(usize, 1), real_levels[1].items.len);
    try std.testing.expectEqual(c, real_levels[1].items[0]);
    try std.testing.expectEqual(@as(usize, 0), real_levels[2].items.len);
    try std.testing.expectEqual(d, real_levels[3].items[0]);
}

test "virtual level median orders dummy nodes" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    _ = try graph.edge(a, d, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;
    ranks[d] = 2;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();
    try std.testing.expect(virtualLevelContains(virtual_levels.levels[1].items, .{ .dummy = 0 }));

    try reduceVirtualLevelCrossings(allocator, &graph, &virtual_levels, ranks, 2);
    const dummy_pos = positionInVirtualLevel(virtual_levels.levels[1].items, .{ .dummy = 0 }).?;
    const c_pos = positionInVirtualLevel(virtual_levels.levels[1].items, .{ .real = c }).?;
    try std.testing.expect(dummy_pos < c_pos);
}

test "virtual level block ordering keeps cluster members adjacent" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const top_a = try graph.node("top_a");
    const top_b = try graph.node("top_b");
    const a = try graph.node("a");
    const outside = try graph.node("outside");
    const b = try graph.node("b");
    _ = try graph.edge(top_a, a, .{});
    _ = try graph.edge(top_b, b, .{});
    _ = try graph.addCluster("cluster_pair", null, &.{ a, b }, &.{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[top_a] = 0;
    ranks[top_b] = 0;
    ranks[a] = 1;
    ranks[outside] = 1;
    ranks[b] = 1;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();
    virtual_levels.levels[1].items[0] = .{ .real = a };
    virtual_levels.levels[1].items[1] = .{ .real = outside };
    virtual_levels.levels[1].items[2] = .{ .real = b };

    orderVirtualLevelBlocksByMedian(&graph, &virtual_levels, ranks, 1, true);
    const a_pos = positionInVirtualLevel(virtual_levels.levels[1].items, .{ .real = a }).?;
    const b_pos = positionInVirtualLevel(virtual_levels.levels[1].items, .{ .real = b }).?;
    try std.testing.expect(a_pos + 1 == b_pos or b_pos + 1 == a_pos);
}

test "virtual level block ordering sorts members by individual medians" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const top_a = try graph.node("top_a");
    const top_b = try graph.node("top_b");
    const a = try graph.node("a");
    const b = try graph.node("b");
    _ = try graph.edge(top_a, a, .{});
    _ = try graph.edge(top_b, b, .{});
    _ = try graph.addCluster("cluster_pair", null, &.{ a, b }, &.{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[top_a] = 0;
    ranks[top_b] = 0;
    ranks[a] = 1;
    ranks[b] = 1;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();
    virtual_levels.levels[0].items[0] = .{ .real = top_a };
    virtual_levels.levels[0].items[1] = .{ .real = top_b };
    virtual_levels.levels[1].items[0] = .{ .real = b };
    virtual_levels.levels[1].items[1] = .{ .real = a };

    orderVirtualLevelBlocksByMedian(&graph, &virtual_levels, ranks, 1, true);
    try std.testing.expectEqual(a, virtual_levels.levels[1].items[0].real);
    try std.testing.expectEqual(b, virtual_levels.levels[1].items[1].real);
}

test "virtual neighbor medians account for edge weights" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const left = try graph.node("left");
    const mid = try graph.node("mid");
    const right = try graph.node("right");
    const child = try graph.node("child");
    _ = try graph.edge(left, child, .{ .weight = 1 });
    _ = try graph.edge(right, child, .{ .weight = 9 });

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[left] = 0;
    ranks[mid] = 0;
    ranks[right] = 0;
    ranks[child] = 1;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();
    virtual_levels.levels[0].items[0] = .{ .real = left };
    virtual_levels.levels[0].items[1] = .{ .real = mid };
    virtual_levels.levels[0].items[2] = .{ .real = right };
    virtual_levels.levels[1].items[0] = .{ .real = child };

    const median = virtualNodeNeighborMedian(&graph, &virtual_levels, ranks, .{ .real = child }, 1, true, 0);
    try std.testing.expect(median > 1.5);
}

test "virtual block keys leave root nodes as singleton blocks" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const outside = try graph.node("outside");
    _ = try graph.edge(a, b, .{});
    _ = try graph.edge(outside, b, .{});
    _ = try graph.addCluster("cluster_pair", null, &.{ a, b }, &.{});

    try std.testing.expectEqual(virtualBlockKey(&graph, .{ .real = a }), virtualBlockKey(&graph, .{ .real = b }));
    try std.testing.expect(virtualBlockKey(&graph, .{ .real = outside }) != virtualBlockKey(&graph, .{ .real = a }));
    try std.testing.expect(virtualBlockKey(&graph, .{ .dummy = 1 }) != virtualBlockKey(&graph, .{ .real = outside }));
}

test "cross-cluster long-edge dummies attach to nearest endpoint block" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    const edge_id = try graph.edge(a, d, .{ .ltail = "cluster_tail", .lhead = "cluster_head" });
    _ = try graph.addCluster("cluster_tail", null, &.{a}, &.{});
    _ = try graph.addCluster("cluster_head", null, &.{d}, &.{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 2;
    ranks[d] = 3;

    try std.testing.expectEqual(virtualBlockKey(&graph, .{ .real = a }), virtualBlockKeyAtRank(&graph, ranks, .{ .dummy = edge_id }, 1));
    try std.testing.expectEqual(virtualBlockKey(&graph, .{ .real = d }), virtualBlockKeyAtRank(&graph, ranks, .{ .dummy = edge_id }, 2));
}

test "implicit cross-cluster long-edge dummies attach to endpoint blocks" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    const edge_id = try graph.edge(a, d, .{});
    _ = try graph.addCluster("cluster_tail", null, &.{a}, &.{});
    _ = try graph.addCluster("cluster_head", null, &.{d}, &.{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 2;
    ranks[d] = 3;

    try std.testing.expectEqual(virtualBlockKey(&graph, .{ .real = a }), virtualBlockKeyAtRank(&graph, ranks, .{ .dummy = edge_id }, 1));
    try std.testing.expectEqual(virtualBlockKey(&graph, .{ .real = d }), virtualBlockKeyAtRank(&graph, ranks, .{ .dummy = edge_id }, 2));
}

test "virtual adjacent exchange preserves cluster block boundaries" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const top_a = try graph.node("top_a");
    const top_b = try graph.node("top_b");
    const a = try graph.node("a");
    const outside = try graph.node("outside");
    const b = try graph.node("b");
    _ = try graph.edge(top_a, a, .{});
    _ = try graph.edge(top_b, b, .{});
    _ = try graph.addCluster("cluster_pair", null, &.{ a, b }, &.{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[top_a] = 0;
    ranks[top_b] = 0;
    ranks[a] = 1;
    ranks[outside] = 1;
    ranks[b] = 1;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();
    virtual_levels.levels[1].items[0] = .{ .real = a };
    virtual_levels.levels[1].items[1] = .{ .real = b };
    virtual_levels.levels[1].items[2] = .{ .real = outside };

    refineVirtualAdjacentExchanges(&graph, &virtual_levels, ranks);
    const a_pos = positionInVirtualLevel(virtual_levels.levels[1].items, .{ .real = a }).?;
    const b_pos = positionInVirtualLevel(virtual_levels.levels[1].items, .{ .real = b }).?;
    try std.testing.expect(a_pos + 1 == b_pos or b_pos + 1 == a_pos);
}

test "virtual adjacent exchange reduces dummy crossings" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    const e = try graph.node("e");
    const f = try graph.node("f");
    _ = try graph.edge(a, f, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;
    ranks[d] = 1;
    ranks[e] = 2;
    ranks[f] = 2;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();

    try std.testing.expectEqual(@as(usize, 1), virtualCrossingScoreAroundLevel(&graph, &virtual_levels, ranks, 1));
    refineVirtualAdjacentExchanges(&graph, &virtual_levels, ranks);
    try std.testing.expectEqual(@as(usize, 0), virtualCrossingScoreAroundLevel(&graph, &virtual_levels, ranks, 1));
}

test "virtual reducer real-node order can be extracted" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    _ = try graph.edge(a, d, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;
    ranks[d] = 2;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();
    try reduceVirtualLevelCrossings(allocator, &graph, &virtual_levels, ranks, 2);
    const real_levels = try extractRealLevelsFromVirtual(allocator, &virtual_levels);
    defer {
        for (real_levels) |*level| level.deinit(allocator);
        allocator.free(real_levels);
    }
    try std.testing.expectEqual(c, real_levels[1].items[0]);
}

test "virtual levels sync real order without moving dummies" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    _ = try graph.edge(a, d, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;
    ranks[d] = 2;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();

    var real_levels = try allocator.alloc(std.ArrayList(NodeId), 3);
    defer allocator.free(real_levels);
    for (real_levels) |*level| level.* = .empty;
    defer for (real_levels) |*level| level.deinit(allocator);
    try real_levels[0].append(allocator, b);
    try real_levels[0].append(allocator, a);
    try real_levels[1].append(allocator, c);
    try real_levels[2].append(allocator, d);

    syncVirtualRealOrder(&virtual_levels, real_levels);
    try std.testing.expectEqual(b, virtual_levels.levels[0].items[0].real);
    try std.testing.expectEqual(a, virtual_levels.levels[0].items[1].real);
    try std.testing.expect(virtualLevelContains(virtual_levels.levels[1].items, .{ .dummy = 0 }));
}

test "virtual positions expose dummy along coordinates" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    const d = try graph.node("d");
    _ = try graph.edge(a, d, .{});
    _ = try graph.edge(b, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;
    ranks[d] = 2;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();
    try reduceVirtualLevelCrossings(allocator, &graph, &virtual_levels, ranks, 2);

    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    var positions = try computeVirtualPositions(allocator, &virtual_levels, &graph, sizes, 10, null);
    defer positions.deinit();
    const dummy_along = virtualDummyAlong(&virtual_levels, &positions, 0, 1) orelse return error.MissingDummyAlong;
    const dummy_pos = positionInVirtualLevel(virtual_levels.levels[1].items, .{ .dummy = 0 }).?;
    try std.testing.expectEqual(positions.positions[1].items[dummy_pos], dummy_along);
}

test "virtual positions use real node coordinate hints" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    const c = try graph.node("c");
    _ = try graph.edge(a, c, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 2;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();

    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    const hints = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(hints);
    hints[a] = 10;
    hints[b] = 80;
    hints[c] = 110;

    var positions = try computeVirtualPositions(allocator, &virtual_levels, &graph, sizes, 10, hints);
    defer positions.deinit();
    const dummy_pos = positionInVirtualLevel(virtual_levels.levels[1].items, .{ .dummy = 0 }).?;
    try std.testing.expect(positions.positions[1].items[dummy_pos] > 60.0);
    try std.testing.expectEqual(positions.positions[1].items[dummy_pos], virtualDummyAlong(&virtual_levels, &positions, 0, 1).?);
}

test "virtual positions compact overlaps while preserving order" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    _ = try graph.edge(a, b, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();

    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    const hints = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(hints);
    hints[a] = 10;
    hints[b] = 12;

    var positions = try computeVirtualPositions(allocator, &virtual_levels, &graph, sizes, 10, hints);
    defer positions.deinit();
    try std.testing.expectEqual(@as(f64, 10), positions.positions[0].items[0]);
    try std.testing.expectEqual(@as(f64, 40), positions.positions[0].items[1]);
    try std.testing.expect(virtualPositionsExtent(&virtual_levels, &positions, sizes, &graph) >= 50);
}

test "layout root extent follows Graphviz normal-node and cluster bbox model" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_left { a0 -> a1 -> a2 -> a3; }
        \\  subgraph cluster_right { b0 -> b1 -> b2 -> b3; }
        \\  a3 -> a0;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    var node_right: f64 = 0;
    for (layout.nodes) |node| node_right = @max(node_right, node.center.x + node.width / 2.0);
    var cluster_right: f64 = 0;
    for (layout.clusters) |cluster_box| cluster_right = @max(cluster_right, cluster_box.x + cluster_box.width);

    try std.testing.expect(layout.width >= cluster_right);
    try std.testing.expect(layout.width <= @max(node_right, cluster_right) + layout.margin_x + 0.01);
}

test "cluster bbox includes same-cluster back-edge side channel" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_loop { a0 -> a1 -> a2 -> a3; }
        \\  a3 -> a0;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const a0 = graph.node_index.get("a0").?;
    const cluster = layout.clusters[0];

    try std.testing.expect(cluster.x <= 1.0);
    try std.testing.expect(layout.nodes[a0].center.x - cluster.x >= 46.0);
}

test "rankdir LR back-edge channel expands cluster along y axis" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .rankdir = .LR });
    defer graph.deinit();

    const a0 = try graph.node("a0");
    const a3 = try graph.node("a3");
    _ = try graph.edge(a3, a0, .{});
    _ = try graph.addCluster("cluster_loop", null, &.{ a0, a3 }, &.{});

    const nodes = [_]NodeLayout{
        .{ .center = .{ .x = 40, .y = 50 }, .width = 54, .height = 36 },
        .{ .center = .{ .x = 220, .y = 50 }, .width = 54, .height = 36 },
    };
    var clusters = [_]ClusterLayout{.{ .id = 0, .x = 10, .y = 32, .width = 250, .height = 42 }};

    expandClusterLayoutsForBackEdges(&graph, LayoutAxes.init(.LR), nodes[0..], clusters[0..]);

    try std.testing.expect(clusters[0].y < 32.0);
    try std.testing.expect(clusters[0].height > 42.0);
}

test "virtual position compaction honors node gap" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    _ = try graph.edge(a, b, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();

    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    const hints = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(hints);
    hints[a] = 10;
    hints[b] = 12;

    var positions = try computeVirtualPositions(allocator, &virtual_levels, &graph, sizes, 30, hints);
    defer positions.deinit();
    try std.testing.expectEqual(@as(f64, 10), positions.positions[0].items[0]);
    try std.testing.expectEqual(@as(f64, 60), positions.positions[0].items[1]);
}

test "virtual positions can update real node centers" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.node("a");
    const b = try graph.node("b");
    _ = try graph.edge(a, b, .{});

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();

    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    const hints = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(hints);
    hints[a] = 30;
    hints[b] = 90;

    var positions = try computeVirtualPositions(allocator, &virtual_levels, &graph, sizes, 10, hints);
    defer positions.deinit();
    const centers = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(centers);
    @memset(centers, 0);

    applyVirtualRealPositions(&virtual_levels, &positions, centers);
    try std.testing.expectEqual(@as(f64, 30), centers[a]);
    try std.testing.expectEqual(@as(f64, 90), centers[b]);
}

test "virtual real center update preserves grouped nodes" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const grouped = try graph.node("grouped");
    const plain = try graph.node("plain");
    try graph.setNodeAttr(grouped, "group", "main");

    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[grouped] = 0;
    ranks[plain] = 0;

    var virtual_levels = try buildVirtualLevels(allocator, &graph, ranks);
    defer virtual_levels.deinit();
    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };
    const hints = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(hints);
    hints[grouped] = 20;
    hints[plain] = 80;
    var positions = try computeVirtualPositions(allocator, &virtual_levels, &graph, sizes, 10, hints);
    defer positions.deinit();
    const centers = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(centers);
    centers[grouped] = 5;
    centers[plain] = 5;

    applyVirtualRealPositionsExceptGroups(&graph, &virtual_levels, &positions, centers);
    try std.testing.expectEqual(@as(f64, 5), centers[grouped]);
    try std.testing.expectEqual(@as(f64, 80), centers[plain]);
}

fn virtualLevelContains(level: []const VirtualNode, needle: VirtualNode) bool {
    for (level) |node| {
        if (std.meta.eql(node, needle)) return true;
    }
    return false;
}

test "LR layout accounts for oriented long-label extents" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  left [label="short"];
        \\  right [label="very very very wide label"];
        \\  left -> right;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const right = graph.node_index.get("right").?;
    const right_box = layout.nodes[right];
    try std.testing.expect(right_box.center.x + right_box.width / 2.0 <= layout.width);
    try std.testing.expect(right_box.center.y + right_box.height / 2.0 <= layout.height);
}

test "SVG renderer emits curved clipped edges and multiline text spans" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a [label="hello\nworld"];
        \\  b;
        \\  a -> b [label="line1\nline2", color="#2563eb"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(svgPathCommandCount(svg, 'C') != 0);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker id=\"arrow-0-head\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#2563eb\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "dy=\"17.5\"") != null);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const route = edgeRoute(layout.nodes[a], layout.nodes[b], layout.rankdir, 0);
    try std.testing.expect(route.start.x > layout.nodes[a].center.x);
    try std.testing.expect(route.end.x < layout.nodes[b].center.x);
}

test "SVG renderer honors common Graphviz visual attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  node [shape=box];
        \\  a [style="filled,rounded,dashed", color="#1d4ed8", fillcolor="#dbeafe", fontcolor="#1e3a8a", penwidth=3];
        \\  b [style=dotted];
        \\  a -> b [style=dashed, color="#dc2626", fontcolor="#991b1b", penwidth=4, arrowhead=none, label="no arrow"];
        \\  a -> b [style=dotted, label="parallel"];
        \\  a -> a [label="loop"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#dbeafe\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"#1d4ed8\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#1e3a8a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"3.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-dasharray=\"8,5\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-dasharray=\"2,5\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"4.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-0-head)\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "loop") != null);

    const first_offset = parallelEdgeOffset(&graph, 0);
    const second_offset = parallelEdgeOffset(&graph, 1);
    try std.testing.expect(first_offset < 0);
    try std.testing.expect(second_offset > 0);
}

test "SVG renderer honors bold style and node peripheries" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a [shape=circle, peripheries=2, style=bold, color="#1d4ed8"];
        \\  b [shape=box, peripheries=3];
        \\  a -> b [style=bold, label="bold edge"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(countSubstrings(svg, "<circle") >= 2);
    try std.testing.expect(countSubstrings(svg, "<rect") >= 3);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"2.6\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"3.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\"") != null);
}

test "SVG renderer honors Graphviz fillcolor gradients" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  linear [shape=box, style=filled, fillcolor="yellow;0.3:blue", gradientangle=45];
        \\  radial [shape=ellipse, style="filled,radial", fillcolor="white:#2563eb", gradientangle=90];
        \\  linear -> radial;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<linearGradient id=\"vex-node-fill-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "gradientUnits=\"userSpaceOnUse\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "offset=\"29.9%\" stop-color=\"yellow\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "offset=\"30.0%\" stop-color=\"blue\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"url(#vex-node-fill-1)\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<radialGradient id=\"vex-node-fill-2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fx=\"50%\" fy=\"0%\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stop-color=\"white\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"url(#vex-node-fill-2)\"") != null);
}

test "SVG renderer honors Graphviz striped fills on box nodes and clusters" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  node [shape=box];
        \\  a [style=striped, fillcolor="red;0.25:green;0.25:blue"];
        \\  subgraph cluster_stripes {
        \\    style=striped;
        \\    fillcolor="gold;0.4:lightblue";
        \\    b;
        \\  }
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "id=\"vex-node-stripes-1\" class=\"striped-fill\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"red\" stroke=\"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"green\" stroke=\"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"blue\" stroke=\"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "id=\"vex-cluster-stripes-1\" class=\"striped-fill\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"gold\" stroke=\"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"lightblue\" stroke=\"none\"") != null);
}

test "SVG node rendering separates Graphviz color and fillcolor semantics" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  default_node;
        \\  stroked [color="#dc2626"];
        \\  filled_default [style=filled];
        \\  filled [style=filled, color="#16a34a"];
        \\  filled_explicit [color="#1d4ed8", fillcolor="#dbeafe"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\" stroke=\"black\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\" stroke=\"#dc2626\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"lightgrey\" stroke=\"black\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#16a34a\" stroke=\"#16a34a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#dbeafe\" stroke=\"#1d4ed8\"") != null);
}

test "SVG renderer uses Graphviz default pen widths" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\  subgraph cluster_c { c; }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"1.8\"") == null);

    var explicit = try parseDot(allocator,
        \\digraph G {
        \\  node [penwidth=3];
        \\  a -> b [penwidth=4];
        \\  subgraph cluster_c { graph [penwidth=2]; c; }
        \\}
    );
    defer explicit.deinit();
    var explicit_layout = try layoutLayered(allocator, &explicit, .{});
    defer explicit_layout.deinit();
    const explicit_svg = try renderSvgAlloc(allocator, &explicit, &explicit_layout, .{});
    defer allocator.free(explicit_svg);
    try std.testing.expect(std.mem.indexOf(u8, explicit_svg, "stroke-width=\"3.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, explicit_svg, "stroke-width=\"4.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, explicit_svg, "stroke-width=\"2.0\"") != null);
}

test "SVG renderer normalizes simple HTML-like labels without affecting plain angle text" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  html [label=< <B>Title</B><BR/>A &amp; B >, shape=box];
        \\  plain [label="<&>"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, ">Title</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">A &amp; B</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "&lt;B&gt;") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "&lt;&amp;&gt;") != null);
}

test "SVG renderer honors common Graphviz HTML text styles" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  html [shape=box,label=<
        \\    <B>Bold</B> <I>Italic</I> <U>Under</U><BR/>
        \\    <FONT COLOR="#dc2626" FACE="Courier" POINT-SIZE="18">Red</FONT>
        \\    <SUP>sup</SUP><SUB>sub</SUB><S>strike</S><O>over</O>
        \\  >];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "font-weight=\"bold\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Bold</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-style=\"italic\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-decoration=\"underline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#dc2626\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Courier\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"18\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "baseline-shift=\"super\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "baseline-shift=\"sub\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-decoration=\"line-through\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-decoration=\"overline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<B>") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<FONT") == null);
}

test "SVG renderer lays out simple HTML table labels as grids" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  html [shape=plain,label=<
        \\    <TABLE>
        \\      <TR><TD>A</TD><TD>B</TD></TR>
        \\      <TR><TD>C</TD><TD>D</TD></TR>
        \\    </TABLE>
        \\  >];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, ">A</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">D</tspan>") != null);
    try std.testing.expect(countSubstrings(svg, "<rect") >= 5);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<TABLE>") == null);
}

test "SVG renderer honors simple HTML table visual attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  html [shape=plain,label=<
        \\    <TABLE BORDER="2" CELLBORDER="2" CELLSPACING="4" CELLPADDING="9" BGCOLOR="lightgrey" COLOR="#2563eb" STYLE="dashed">
        \\      <TR><TD COLOR="#dc2626" STYLE="dotted">A</TD><TD>B</TD></TR>
        \\    </TABLE>
        \\  >];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"lightgrey\" stroke=\"#2563eb\" stroke-width=\"2.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"#2563eb\" stroke-width=\"2.0\" stroke-dasharray=\"8,5\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"#dc2626\" stroke-width=\"2.0\" stroke-dasharray=\"2,5\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"2.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">A</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">B</tspan>") != null);
}

test "SVG renderer honors HTML table colspan bgcolor and alignment" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  html [shape=plain,label=<
        \\    <TABLE CELLBORDER="1" CELLSPACING="2" CELLPADDING="4">
        \\      <TR><TD COLSPAN="2" BGCOLOR="gold" ALIGN="LEFT">Header</TD></TR>
        \\      <TR><TD>A</TD><TD ALIGN="RIGHT">B</TD></TR>
        \\    </TABLE>
        \\  >];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"gold\" stroke=\"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Header</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-anchor=\"start\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-anchor=\"end\"") != null);
}

test "SVG renderer honors HTML table rowspan cells" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  html [shape=plain,label=<
        \\    <TABLE CELLBORDER="1" CELLSPACING="2">
        \\      <TR><TD ROWSPAN="2" BGCOLOR="lightgrey">Left</TD><TD>Top</TD></TR>
        \\      <TR><TD>Bottom</TD></TR>
        \\    </TABLE>
        \\  >];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"lightgrey\" stroke=\"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Left</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Top</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Bottom</tspan>") != null);
}

test "SVG renderer honors per-cell HTML table padding border and valign" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  html [shape=plain,label=<
        \\    <TABLE CELLBORDER="1" CELLPADDING="4">
        \\      <TR><TD CELLBORDER="0" CELLPADDING="12" VALIGN="TOP">Top</TD><TD VALIGN="BOTTOM">Bottom</TD></TR>
        \\    </TABLE>
        \\  >];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"0.0\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Top</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Bottom</tspan>") != null);
}

test "SVG renderer honors HTML table cell sides attribute" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  html [shape=plain,label=<
        \\    <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="4">
        \\      <TR><TD STYLE="invis">Hidden</TD><TD SIDES="ltr">Top</TD><TD SIDES="b">Bottom</TD></TR>
        \\    </TABLE>
        \\  >];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<rect x=\"") != null);
    try std.testing.expect(countSubstrings(svg, "<path d=\"M ") >= 4);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Hidden") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Top</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Bottom</tspan>") != null);
}

test "SVG renderer honors HTML table cell width height fixedsize hints" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  html [shape=plain,label=<
        \\    <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="0">
        \\      <TR><TD WIDTH="9" HEIGHT="9" FIXEDSIZE="true" PORT="a"></TD><TD WIDTH="18" HEIGHT="9" FIXEDSIZE="true" PORT="b"></TD></TR>
        \\    </TABLE>
        \\  >];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const html = graph.node_index.get("html").?;
    const a = htmlTableCellRect(graph.nodes.items[html].label, layout.nodes[html], "a") orelse return error.MissingHtmlPort;
    const b = htmlTableCellRect(graph.nodes.items[html].label, layout.nodes[html], "b") orelse return error.MissingHtmlPort;

    try std.testing.expect(b.width > a.width);
    try std.testing.expect(@abs(b.width - a.width * 2.0) < 0.01);
    try std.testing.expect(@abs(a.height - 9.0) < 0.01);
    try std.testing.expect(@abs(b.height - 9.0) < 0.01);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "width=\"18.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "height=\"9.0\"") != null);
}

test "HTML table TD PORT routes edge endpoints to cells" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  html [shape=plain,label=<
        \\    <TABLE CELLBORDER="1" CELLSPACING="2" CELLPADDING="4">
        \\      <TR><TD PORT="left">L</TD><TD PORT="right">R</TD></TR>
        \\    </TABLE>
        \\  >];
        \\  target [shape=box];
        \\  html:right:e -> target:w;
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqualStrings("right", graph.edges.items[0].tail_record_port.?);
    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const html = graph.node_index.get("html").?;
    const cell = htmlTableCellRect(graph.nodes.items[html].label, layout.nodes[html], "right") orelse return error.MissingHtmlPort;
    const route = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], layout.rankdir, 0);
    try std.testing.expectEqual(cell.x + cell.width, route.start.x);
    try std.testing.expect(route.start.y >= cell.y);
    try std.testing.expect(route.start.y <= cell.y + cell.height);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">R</tspan>") != null);
}

test "SVG renderer honors graph label and bgcolor attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph InternalName {
        \\  graph [label="Visible Title", bgcolor=lightgrey];
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"lightgrey\" stroke=\"none\" points=\"0.0,0 0.0,") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Visible Title") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">InternalName</text>") == null);
    try std.testing.expect(layout.margin_y >= 26.0);
}

test "SVG renderer keeps graph name as metadata unless graph label is explicit" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"graph0\" class=\"graph\" transform=\"scale(1 1) rotate(0) translate(0.0 0)\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>G</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">G</text>") == null);
}

test "SVG renderer honors graph labelloc and labeljust attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [label="Bottom Right", labelloc=b, labeljust=r];
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "Bottom Right") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-anchor=\"end\"") != null);
    var expected_x_buf: [64]u8 = undefined;
    const expected_x = try std.fmt.bufPrint(&expected_x_buf, "x=\"{d:.1}\"", .{layout.width - 16.0});
    var expected_y_buf: [64]u8 = undefined;
    const expected_y = try std.fmt.bufPrint(&expected_y_buf, "y=\"{d:.1}\"", .{layout.height - 16.0});
    try std.testing.expect(std.mem.indexOf(u8, svg, expected_x) != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, expected_y) != null);
    try std.testing.expect(layout.margin_y >= 26.0);
    const b = graph.node_index.get("b").?;
    try std.testing.expect(layout.nodes[b].center.y + layout.nodes[b].height / 2.0 < layout.height - 16.0);
}

test "SVG renderer honors node xlabel labelloc labeljust and margin attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  top_left [label="Top Left", xlabel="external", shape=box, labelloc=t, labeljust=l, margin="0.5,0.25"];
        \\  bottom_right [label="Bottom Right", shape=box, labelloc=b, labeljust=r];
        \\  plain [label="Top Left", shape=box];
        \\  top_left -> bottom_right;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const top_left = graph.node_index.get("top_left").?;
    const plain = graph.node_index.get("plain").?;
    try std.testing.expect(layout.nodes[top_left].width > layout.nodes[plain].width);
    try std.testing.expect(layout.nodes[top_left].height > layout.nodes[plain].height);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "external") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-anchor=\"start\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-anchor=\"end\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Top Left</text>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Bottom Right</text>") != null);
}

test "SVG renderer emits URL href and tooltip metadata" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a [URL="https://example.com/a", tooltip="Node A"];
        \\  b;
        \\  a -> b [href="https://example.com/e", tooltip="Edge A to B"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/a\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>Node A</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/e\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>Edge A to B</title>") != null);
}

test "SVG renderer emits default Graphviz-like node and edge titles" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>a</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>b</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>a-&gt;b</title>") != null);
}

test "SVG renderer wraps nodes in Graphviz-like groups" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(countSubstrings(svg, "class=\"node\"") >= 2);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"node1\" class=\"node\">\n<title>a</title>") != null);
}

test "SVG renderer wraps edges in Graphviz-like groups" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(countSubstrings(svg, "class=\"edge\"") >= 1);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"edge1\" class=\"edge\">\n<title>a-&gt;b</title>") != null);
}

test "SVG renderer uses Graphviz default font family" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Times,serif\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "ui-sans-serif") == null);
}

test "SVG renderer preserves text spacing like Graphviz" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [label="Graph"];
        \\  subgraph cluster_c { label="Cluster"; c; }
        \\  a -> b [label="edge"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(countSubstrings(svg, "xml:space=\"preserve\"") >= 4);
}

test "SVG renderer uses Graphviz default text color" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [label="Title"];
        \\  subgraph cluster_c { label="Cluster"; c; }
        \\  a -> b [label="edge"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.00\" fill=\"black\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#475569\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#0f172a\"") == null);

    var colored = try parseDot(allocator,
        \\digraph G {
        \\  graph [label="Title", fontcolor="#111111"];
        \\  node [fontcolor="#222222"];
        \\  a -> b [label="edge", fontcolor="#333333"];
        \\}
    );
    defer colored.deinit();
    var colored_layout = try layoutLayered(allocator, &colored, .{});
    defer colored_layout.deinit();
    const colored_svg = try renderSvgAlloc(allocator, &colored, &colored_layout, .{});
    defer allocator.free(colored_svg);
    try std.testing.expect(std.mem.indexOf(u8, colored_svg, "fill=\"#111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, colored_svg, "fill=\"#222222\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, colored_svg, "fill=\"#333333\"") != null);
}

test "SVG renderer uses Graphviz default edge and cluster label sizes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_c { label="Cluster"; c; }
        \\  a -> b [label="edge"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.00\">Cluster") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.00\" fill=\"black\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "dominant-baseline=\"middle\"") != null);
}

test "SVG renderer emits headlabel taillabel and xlabel" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [taillabel="tail", headlabel="head", xlabel="external"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, ">tail</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">head</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">external</tspan>") != null);
}

test "SVG renderer honors edge label font position and decoration attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a -> b [
        \\    label="main",
        \\    taillabel="tail",
        \\    headlabel="head",
        \\    xlabel="external",
        \\    labelfontname="Courier",
        \\    labelfontsize=18,
        \\    labelfontcolor="#7c3aed",
        \\    labeldistance=2.0,
        \\    labelangle=45,
        \\    decorate=true,
        \\    color="#2563eb"
        \\  ];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const edge_item = graph.edges.items[0];
    const route = edgeRouteForEdge(&graph, &layout, edge_item, layout.rankdir, 0);
    const near_tail = endpointLabelPosition(route.start, route.label, 1.0, -45, false);
    const far_tail = endpointLabelPosition(route.start, route.label, 2.0, -45, false);
    try std.testing.expect(distanceBetween(route.start, far_tail) > distanceBetween(route.start, near_tail));

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Courier\" font-size=\"18.00\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#7c3aed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">tail</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">head</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">external</tspan>") != null);
    try std.testing.expect(countSubstrings(svg, "stroke=\"#2563eb\"") >= 2);
}

test "SVG renderer honors DOT fontname and fontsize attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [label="Graph", fontname="Courier", fontsize=18];
        \\  node [fontname="Courier", fontsize=22];
        \\  edge [fontname="Times", fontsize=16];
        \\  subgraph cluster_fonts {
        \\    label="Fonts";
        \\    fontname="Georgia";
        \\    fontsize=20;
        \\    a [label="Big"];
        \\  }
        \\  small [label="Small", fontsize=10];
        \\  a -> b [label="Edge"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Courier\" font-size=\"18.00\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Courier\" font-size=\"22.00\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Times\" font-size=\"16.00\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Georgia\" font-size=\"20.00\"") != null);
    const a = graph.node_index.get("a").?;
    const small = graph.node_index.get("small").?;
    try std.testing.expect(layout.nodes[a].height > layout.nodes[small].height);
}

test "SVG renderer honors common Graphviz arrow marker attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [arrowhead=vee, color="#2563eb"];
        \\  b -> c [dir=both, arrowtail=dot, arrowhead=odot, color="#dc2626"];
        \\  c -> d [dir=back, arrowtail=vee];
        \\  d -> e [dir=none];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "arrow-0-head") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "M 1 1 L 9 5 L 1 9") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-start=\"url(#arrow-1-tail)\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-1-head)\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<circle cx=\"5\" cy=\"5\" r=\"4\" fill=\"#dc2626\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<circle cx=\"5\" cy=\"5\" r=\"3.5\" fill=\"#ffffff\" stroke=\"#dc2626\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-start=\"url(#arrow-2-tail)\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-2-head)\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-start=\"url(#arrow-3-tail)\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-3-head)\"") == null);
}

test "SVG renderer honors Graphviz edge color lists" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a -> b [color="red:blue:green", dir=both, arrowhead=vee, arrowtail=dot, label="multi"];
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqualStrings("red:blue:green", graph.edges.items[0].color);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"red:blue:green\"") == null);
    try std.testing.expect(countSubstrings(svg, "stroke=\"red\" d=\"") >= 1);
    try std.testing.expect(countSubstrings(svg, "stroke=\"blue\" d=\"") >= 1);
    try std.testing.expect(countSubstrings(svg, "stroke=\"green\" d=\"") >= 1);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-0-head)\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-start=\"url(#arrow-0-tail)\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "M 1 1 L 9 5 L 1 9\" fill=\"none\" stroke=\"red\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<circle cx=\"5\" cy=\"5\" r=\"4\" fill=\"blue\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "multi") != null);
}

test "SVG renderer uses Graphviz-like inline normal arrow proportions" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "marker id=\"arrow-0-head\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"black\" stroke=\"black\" points=") != null);
}

test "SVG renderer draws Mdiamond with Graphviz-like internal marks" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  start [shape=Mdiamond];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"none\" stroke=\"black\" points=") != null);
    try std.testing.expect(countSubstrings(svg, "<polyline fill=\"none\" stroke=\"black\" points=") >= 4);
    try std.testing.expect(std.mem.indexOf(u8, svg, " fill=\"none\" stroke=\"black\"") != null);
}

test "SVG renderer draws Msquare with Graphviz-like corner marks" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  end [shape=Msquare];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"none\" stroke=\"black\" points=") != null);
    try std.testing.expect(countSubstrings(svg, "<polyline fill=\"none\" stroke=\"black\" points=") >= 4);
}

test "SVG renderer honors additional Graphviz arrow marker shapes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [arrowhead=box, color="#2563eb"];
        \\  b -> c [arrowhead=obox, color="#dc2626"];
        \\  c -> d [arrowhead=diamond, color="#16a34a"];
        \\  d -> e [arrowhead=odiamond, color="#f59e0b"];
        \\  e -> f [arrowhead=tee, color="#64748b"];
        \\  f -> g [arrowhead=crow, color="#9333ea"];
        \\  g -> h [arrowhead=empty, color="#0f172a"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<rect x=\"1.5\" y=\"1.5\" width=\"7\" height=\"7\" fill=\"#2563eb\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<rect x=\"1.5\" y=\"1.5\" width=\"7\" height=\"7\" fill=\"#ffffff\" stroke=\"#dc2626\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "M 5 0.8 L 9.2 5 L 5 9.2 L 0.8 5 z\" fill=\"#16a34a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "M 5 0.8 L 9.2 5 L 5 9.2 L 0.8 5 z\" fill=\"#ffffff\" stroke=\"#f59e0b\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "M 8.5 1 L 8.5 9") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "M 9 1 L 1 5 L 9 9") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "M 0.8 0.8 L 9.2 5 L 0.8 9.2 z") != null);
}

test "SVG renderer honors arrowsize and edge clipping attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a [shape=box];
        \\  b [shape=box];
        \\  c [shape=box];
        \\  a -> b [arrowsize=2.0, color="#2563eb"];
        \\  a -> c [arrowsize=0, color="#dc2626"];
        \\  b -> c [tailclip=false, headclip=false, color="#16a34a"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"#2563eb\" stroke=\"#2563eb\" points=") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "arrow-0-head") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "arrow-1-head") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-1-head)\"") == null);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const clipped = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], layout.rankdir, 0);
    try std.testing.expect(clipped.start.x > layout.nodes[a].center.x);
    try std.testing.expect(clipped.end.x < layout.nodes[b].center.x);

    const unclipped = edgeRouteForEdge(&graph, &layout, graph.edges.items[2], layout.rankdir, 0);
    try std.testing.expectEqual(layout.nodes[b].center.x, unclipped.start.x);
    try std.testing.expectEqual(layout.nodes[b].center.y, unclipped.start.y);
    try std.testing.expectEqual(layout.nodes[c].center.x, unclipped.end.x);
    try std.testing.expectEqual(layout.nodes[c].center.y, unclipped.end.y);
}

test "SVG renderer honors DOT concentrate graph attribute for duplicate edges" {
    const allocator = std.testing.allocator;
    var concentrated = try parseDot(allocator,
        \\digraph G {
        \\  graph [concentrate=true];
        \\  a -> b [label="first"];
        \\  a -> b [label="second"];
        \\}
    );
    defer concentrated.deinit();
    var concentrated_layout = try layoutLayered(allocator, &concentrated, .{});
    defer concentrated_layout.deinit();
    const concentrated_svg = try renderSvgAlloc(allocator, &concentrated, &concentrated_layout, .{});
    defer allocator.free(concentrated_svg);
    try std.testing.expect(countSubstrings(concentrated_svg, "marker id=\"arrow-") == 0);
    try std.testing.expectEqual(@as(usize, 1), renderedEdgePathCount(concentrated_svg));
    try std.testing.expect(std.mem.indexOf(u8, concentrated_svg, "first") != null);
    try std.testing.expect(std.mem.indexOf(u8, concentrated_svg, "second") == null);

    var normal = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [label="first"];
        \\  a -> b [label="second"];
        \\}
    );
    defer normal.deinit();
    var normal_layout = try layoutLayered(allocator, &normal, .{});
    defer normal_layout.deinit();
    const normal_svg = try renderSvgAlloc(allocator, &normal, &normal_layout, .{});
    defer allocator.free(normal_svg);
    try std.testing.expect(renderedEdgePathCount(normal_svg) >= 2);
    try std.testing.expect(std.mem.indexOf(u8, normal_svg, "second") != null);
}

test "DOT subgraphs scope default node and edge attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_left {
        \\    node [shape=box, color="#fee2e2", fontcolor="#991b1b"];
        \\    edge [color="#dc2626", weight=3, penwidth=4];
        \\    a -> b;
        \\  }
        \\  subgraph cluster_right {
        \\    c -> d;
        \\  }
        \\  e -> f;
        \\}
    );
    defer graph.deinit();

    const a = graph.node_index.get("a").?;
    const c = graph.node_index.get("c").?;
    const e = graph.node_index.get("e").?;
    try std.testing.expectEqual(Shape.box, graph.nodes.items[a].shape);
    try std.testing.expectEqual(Shape.ellipse, graph.nodes.items[c].shape);
    try std.testing.expectEqual(Shape.ellipse, graph.nodes.items[e].shape);

    try std.testing.expectEqualStrings("#fee2e2", graph.nodes.items[a].color);
    try std.testing.expectEqualStrings("black", graph.nodes.items[c].color);
    try std.testing.expectEqualStrings("black", graph.nodes.items[e].color);

    try std.testing.expectEqualStrings("#dc2626", graph.edges.items[0].color);
    try std.testing.expectEqualStrings("black", graph.edges.items[1].color);
    try std.testing.expectEqualStrings("black", graph.edges.items[2].color);
    try std.testing.expectEqual(@as(f64, 3.0), graph.edges.items[0].weight);
    try std.testing.expectEqual(@as(f64, 1.0), graph.edges.items[1].weight);
    try std.testing.expectEqualStrings("4", attrValue(graph.edges.items[0].attrs.items, "penwidth").?);
    try std.testing.expect(attrValue(graph.edges.items[1].attrs.items, "penwidth") == null);
}

test "DOT parser records Graphviz rank subgraph constraints" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=same; b; c; }
        \\  subgraph sources { graph [rank=min]; a; }
        \\  subgraph sinks { rank=sink; z; }
        \\  a -> b -> z;
        \\  a -> c;
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 3), graph.rank_constraints.items.len);
    try std.testing.expectEqual(RankKind.same, graph.rank_constraints.items[0].kind);
    try std.testing.expectEqual(RankKind.min, graph.rank_constraints.items[1].kind);
    try std.testing.expectEqual(RankKind.sink, graph.rank_constraints.items[2].kind);

    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    try std.testing.expect(containsNode(graph.rank_constraints.items[0].node_ids, b));
    try std.testing.expect(containsNode(graph.rank_constraints.items[0].node_ids, c));
}

test "layered layout applies rank same and boundary constraints" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=min; source; }
        \\  { rank=same; review; approve; }
        \\  { rank=sink; archive; }
        \\  source -> review -> archive;
        \\  source -> approve -> archive;
        \\  source -> free;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const source = graph.node_index.get("source").?;
    const review = graph.node_index.get("review").?;
    const approve = graph.node_index.get("approve").?;
    const archive = graph.node_index.get("archive").?;
    const free = graph.node_index.get("free").?;

    try std.testing.expectEqual(layout.nodes[review].center.y, layout.nodes[approve].center.y);
    try std.testing.expect(layout.nodes[source].center.y < layout.nodes[review].center.y);
    try std.testing.expect(layout.nodes[archive].center.y > layout.nodes[review].center.y);
    try std.testing.expect(layout.nodes[source].center.y <= layout.nodes[free].center.y);
}

test "layered layout keeps back edges from expanding ranks" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a0 -> a1 -> a2 -> a3;
        \\  a3 -> a0;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const a0 = graph.node_index.get("a0").?;
    const a1 = graph.node_index.get("a1").?;
    const a2 = graph.node_index.get("a2").?;
    const a3 = graph.node_index.get("a3").?;
    try std.testing.expect(layout.ranks[a0] < layout.ranks[a1]);
    try std.testing.expect(layout.ranks[a1] < layout.ranks[a2]);
    try std.testing.expect(layout.ranks[a2] < layout.ranks[a3]);
    try std.testing.expect(layout.ranks[a3] <= layout.ranks[a0] + 3);
}

test "layered layout tightens avoidable rank slack" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b -> c -> d;
        \\  x -> d;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const x = graph.node_index.get("x").?;
    try std.testing.expectEqual(layout.ranks[c], layout.ranks[x]);
    try std.testing.expectEqual(layout.ranks[x] + 1, layout.ranks[d]);
}

test "rank slack tightening minimizes weighted incident spans" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b -> c -> d;
        \\  y;
        \\  x -> d [weight=10];
        \\  y -> x [weight=1];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const x = graph.node_index.get("x").?;
    const y = graph.node_index.get("y").?;
    try std.testing.expectEqual(layout.ranks[c], layout.ranks[x]);
    try std.testing.expectEqual(layout.ranks[x] + 1, layout.ranks[d]);
    try std.testing.expect(layout.ranks[y] < layout.ranks[x]);
}

test "rank slack tightening propagates through dependent slack nodes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  x;
        \\  y;
        \\  a -> b -> c -> d;
        \\  y -> d;
        \\  x -> y;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const x = graph.node_index.get("x").?;
    const y = graph.node_index.get("y").?;
    const d = graph.node_index.get("d").?;
    try std.testing.expectEqual(layout.ranks[y] + 1, layout.ranks[d]);
    try std.testing.expectEqual(layout.ranks[x] + 1, layout.ranks[y]);
}

test "rank assignment helpers measure feasibility and weighted span cost" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b -> c;
        \\  x -> c [weight=4];
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const x = graph.node_index.get("x").?;
    const loose = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(loose);
    loose[a] = 0;
    loose[b] = 1;
    loose[c] = 2;
    loose[x] = 0;
    const tight = try allocator.dupe(usize, loose);
    defer allocator.free(tight);
    tight[x] = 1;

    try std.testing.expect(rankAssignmentFeasible(&graph, loose, acyclic_edge));
    try std.testing.expect(rankAssignmentFeasible(&graph, tight, acyclic_edge));
    try std.testing.expect(rankAssignmentCost(&graph, tight, acyclic_edge) < rankAssignmentCost(&graph, loose, acyclic_edge));
}

test "rank assignment helpers ignore inactive rank edges" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [constraint=false, weight=10];
        \\  b -> c;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 0;
    ranks[c] = 1;

    try std.testing.expect(!rankEdgeActive(graph.edges.items[0], acyclic_edge));
    try std.testing.expect(rankAssignmentFeasible(&graph, ranks, acyclic_edge));
    try std.testing.expectEqual(@as(f64, 1.0), rankAssignmentCost(&graph, ranks, acyclic_edge));
}

test "rank edge collection returns active weighted minlen edges" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [constraint=false, weight=10];
        \\  b -> c [minlen=3, weight=2.5];
        \\  c -> d;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);
    acyclic_edge[2] = false;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    try std.testing.expectEqual(@as(usize, 1), rank_edges.len);
    try std.testing.expectEqual(@as(EdgeId, 1), rank_edges[0].edge_id);
    try std.testing.expectEqual(@as(usize, 3), rank_edges[0].min_len);
    try std.testing.expectEqual(@as(f64, 2.5), rank_edges[0].weight);
}

test "rank edge helpers compute slack feasibility and cost" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [minlen=2, weight=3];
        \\  b -> c;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 3;
    ranks[c] = 4;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    try std.testing.expect(rankEdgesFeasible(rank_edges, ranks));
    try std.testing.expectEqual(@as(usize, 1), rankEdgeSlack(rank_edges[0], ranks).?);
    try std.testing.expect(!rankEdgeTight(rank_edges[0], ranks));
    try std.testing.expect(rankEdgeTight(rank_edges[1], ranks));
    try std.testing.expectEqual(@as(usize, 1), countTightRankEdges(rank_edges, ranks));
    try std.testing.expectEqual(@as(f64, 10.0), rankEdgesCost(rank_edges, ranks));
    ranks[b] = 1;
    try std.testing.expect(!rankEdgesFeasible(rank_edges, ranks));
}

test "tight rank edge components count connected tight tree pieces" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\  b -> c;
        \\  d;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 2;
    ranks[d] = 0;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    try std.testing.expectEqual(@as(usize, 2), tightRankEdgeComponentCount(allocator, rank_edges, ranks));
    const labels = try allocator.alloc(usize, ranks.len);
    defer allocator.free(labels);
    try std.testing.expectEqual(@as(usize, 2), labelTightRankEdgeComponents(allocator, rank_edges, ranks, labels));
    try std.testing.expectEqual(labels[a], labels[b]);
    try std.testing.expectEqual(labels[b], labels[c]);
    try std.testing.expect(labels[d] != labels[a]);
    ranks[c] = 3;
    try std.testing.expectEqual(@as(usize, 3), tightRankEdgeComponentCount(allocator, rank_edges, ranks));
    try std.testing.expectEqual(@as(usize, 3), labelTightRankEdgeComponents(allocator, rank_edges, ranks, labels));
    try std.testing.expectEqual(labels[a], labels[b]);
    try std.testing.expect(labels[c] != labels[b]);
}

test "select entering rank edge chooses minimum slack then highest weight" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\  c -> d;
        \\  a -> c [weight=1];
        \\  b -> d [weight=5];
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 3;
    ranks[d] = 4;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    const labels = try allocator.alloc(usize, ranks.len);
    defer allocator.free(labels);
    try std.testing.expectEqual(@as(usize, 2), labelTightRankEdgeComponents(allocator, rank_edges, ranks, labels));

    const entering = selectEnteringRankEdge(rank_edges, ranks, labels) orelse return error.MissingEnteringEdge;
    try std.testing.expectEqual(@as(EdgeId, 3), rank_edges[entering].edge_id);
}

test "rank component shifting can tighten an entering edge" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\  c -> d;
        \\  b -> d;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 3;
    ranks[d] = 4;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    const labels = try allocator.alloc(usize, ranks.len);
    defer allocator.free(labels);
    try std.testing.expectEqual(@as(usize, 2), labelTightRankEdgeComponents(allocator, rank_edges, ranks, labels));

    try std.testing.expectEqual(@as(usize, 2), rankEdgeSlack(rank_edges[2], ranks).?);
    try std.testing.expect(tightenEnteringEdgeByShiftingHeadComponent(rank_edges[2], ranks, labels));
    try std.testing.expect(rankEdgeTight(rank_edges[2], ranks));
    try std.testing.expectEqual(@as(usize, 1), ranks[c]);
    try std.testing.expectEqual(@as(usize, 2), ranks[d]);
}

test "single tight component merge reduces component count" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\  c -> d;
        \\  b -> d;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 3;
    ranks[d] = 4;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    try std.testing.expectEqual(@as(usize, 2), tightRankEdgeComponentCount(allocator, rank_edges, ranks));
    try std.testing.expect(try mergeTightRankComponentsOnce(allocator, rank_edges, ranks));
    try std.testing.expect(rankEdgesFeasible(rank_edges, ranks));
    try std.testing.expectEqual(@as(usize, 1), tightRankEdgeComponentCount(allocator, rank_edges, ranks));
}

test "bounded tight component merge can build a connected tight tree" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\  c -> d;
        \\  e -> f;
        \\  b -> d;
        \\  d -> f;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const e = graph.node_index.get("e").?;
    const f = graph.node_index.get("f").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 3;
    ranks[d] = 4;
    ranks[e] = 6;
    ranks[f] = 7;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    try std.testing.expectEqual(@as(usize, 3), tightRankEdgeComponentCount(allocator, rank_edges, ranks));
    try std.testing.expectEqual(@as(usize, 2), try mergeTightRankComponents(allocator, rank_edges, ranks, 4));
    try std.testing.expect(rankEdgesFeasible(rank_edges, ranks));
    try std.testing.expectEqual(@as(usize, 1), tightRankEdgeComponentCount(allocator, rank_edges, ranks));
}

test "rank tight tree records parent depth and subtree intervals" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  root -> left;
        \\  root -> right;
        \\  left -> leaf;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const root = graph.node_index.get("root").?;
    const left = graph.node_index.get("left").?;
    const right = graph.node_index.get("right").?;
    const leaf = graph.node_index.get("leaf").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[root] = 0;
    ranks[left] = 1;
    ranks[right] = 1;
    ranks[leaf] = 2;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    var tree = (try buildTightRankTree(allocator, rank_edges, ranks)) orelse return error.MissingTightTree;
    defer tree.deinit();

    try std.testing.expectEqual(root, tree.root);
    try std.testing.expectEqual(root, tree.parent[left].?);
    try std.testing.expectEqual(root, tree.parent[right].?);
    try std.testing.expectEqual(left, tree.parent[leaf].?);
    try std.testing.expectEqual(@as(usize, 0), tree.depth[root]);
    try std.testing.expectEqual(@as(usize, 1), tree.depth[left]);
    try std.testing.expectEqual(@as(usize, 2), tree.depth[leaf]);
    try std.testing.expect(tree.inSubtree(leaf, left));
    try std.testing.expect(!tree.inSubtree(right, left));
}

test "rank tight tree cut values identify negative leaving edge" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [weight=1];
        \\  a -> c [weight=1];
        \\  b -> d [weight=1];
        \\  c -> d [weight=5];
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 1;
    ranks[d] = 2;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    var tree = (try buildTightRankTree(allocator, rank_edges, ranks)) orelse return error.MissingTightTree;
    defer tree.deinit();

    try std.testing.expect(rankTreeEdgeCutValue(&tree, rank_edges, 1).? < 0);
    const leaving = selectLeavingRankTreeEdge(&tree, rank_edges) orelse return error.MissingLeavingEdge;
    try std.testing.expectEqual(@as(EdgeId, 1), rank_edges[leaving].edge_id);
}

test "rank tight tree selects entering edge across leaving cut" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [weight=1];
        \\  a -> c [weight=1];
        \\  b -> x [weight=1];
        \\  x -> d [weight=1];
        \\  c -> d [weight=5];
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const x = graph.node_index.get("x").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 1;
    ranks[x] = 2;
    ranks[d] = 3;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    var tree = (try buildTightRankTree(allocator, rank_edges, ranks)) orelse return error.MissingTightTree;
    defer tree.deinit();

    const leaving = selectLeavingRankTreeEdge(&tree, rank_edges) orelse return error.MissingLeavingEdge;
    const entering = selectEnteringRankTreeEdge(&tree, rank_edges, ranks, leaving) orelse return error.MissingEnteringEdge;
    try std.testing.expectEqual(@as(EdgeId, 1), rank_edges[leaving].edge_id);
    try std.testing.expectEqual(@as(EdgeId, 4), rank_edges[entering].edge_id);
    try std.testing.expectEqual(@as(usize, 1), rankEdgeSlack(rank_edges[entering], ranks).?);
}

test "rank tight tree pivot tightens entering edge and lowers cost" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [weight=1];
        \\  a -> c [weight=1];
        \\  b -> x [weight=1];
        \\  x -> d [weight=1];
        \\  c -> d [weight=5];
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const x = graph.node_index.get("x").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 1;
    ranks[x] = 2;
    ranks[d] = 3;

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    var tree = (try buildTightRankTree(allocator, rank_edges, ranks)) orelse return error.MissingTightTree;
    defer tree.deinit();

    const before_cost = rankEdgesCost(rank_edges, ranks);
    const leaving = selectLeavingRankTreeEdge(&tree, rank_edges) orelse return error.MissingLeavingEdge;
    const entering = selectEnteringRankTreeEdge(&tree, rank_edges, ranks, leaving) orelse return error.MissingEnteringEdge;
    try std.testing.expect(try pivotRankTightTree(&tree, rank_edges, ranks, leaving, entering));

    try std.testing.expect(rankEdgesFeasible(rank_edges, ranks));
    try std.testing.expect(rankEdgeTight(rank_edges[entering], ranks));
    try std.testing.expect(!tree.in_tree[leaving]);
    try std.testing.expect(tree.in_tree[entering]);
    try std.testing.expect(tree.inSubtree(c, a));
    try std.testing.expect(rankEdgesCost(rank_edges, ranks) < before_cost);
}

test "bounded network simplex rank pass performs improving pivot" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [weight=1];
        \\  a -> c [weight=1];
        \\  b -> x [weight=1];
        \\  x -> d [weight=1];
        \\  c -> d [weight=5];
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const x = graph.node_index.get("x").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 1;
    ranks[x] = 2;
    ranks[d] = 3;

    const before = rankAssignmentCost(&graph, ranks, acyclic_edge);
    try std.testing.expectEqual(@as(usize, 1), try improveRanksByNetworkSimplex(allocator, &graph, ranks, acyclic_edge, 4));
    const after = rankAssignmentCost(&graph, ranks, acyclic_edge);
    try std.testing.expect(rankAssignmentFeasible(&graph, ranks, acyclic_edge));
    try std.testing.expect(after < before);
    try std.testing.expectEqual(@as(usize, 2), ranks[c]);
}

test "bounded network simplex rank pass leaves optimal tight tree unchanged" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b -> c -> d;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 2;
    ranks[d] = 3;
    const before = try allocator.dupe(usize, ranks);
    defer allocator.free(before);

    try std.testing.expectEqual(@as(usize, 0), try improveRanksByNetworkSimplex(allocator, &graph, ranks, acyclic_edge, 4));
    try std.testing.expectEqualSlices(usize, before, ranks);
}

test "bounded network simplex rank pass bounds degenerate zero-slack pivots" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [weight=1];
        \\  a -> c [weight=1];
        \\  b -> d [weight=1];
        \\  c -> d [weight=5];
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 1;
    ranks[d] = 2;
    const before = try allocator.dupe(usize, ranks);
    defer allocator.free(before);

    const rank_edges = try collectRankEdges(allocator, &graph, acyclic_edge);
    defer allocator.free(rank_edges);
    var tree = (try buildTightRankTree(allocator, rank_edges, ranks)) orelse return error.MissingTightTree;
    defer tree.deinit();
    const leaving = selectLeavingRankTreeEdge(&tree, rank_edges) orelse return error.MissingLeavingEdge;
    const entering = selectEnteringRankTreeEdge(&tree, rank_edges, ranks, leaving) orelse return error.MissingEnteringEdge;
    try std.testing.expectEqual(@as(usize, 0), rankEdgeSlack(rank_edges[entering], ranks).?);

    try std.testing.expectEqual(@as(usize, 0), try improveRanksByNetworkSimplex(allocator, &graph, ranks, acyclic_edge, 8));
    try std.testing.expectEqualSlices(usize, before, ranks);
    try std.testing.expect(rankAssignmentFeasible(&graph, ranks, acyclic_edge));
}

test "rank local search preserves explicit same-rank constraints" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=same; x; y; }
        \\  source -> x [weight=1];
        \\  x -> sink [weight=8];
        \\  source -> y -> mid -> sink;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const source = graph.node_index.get("source").?;
    const x = graph.node_index.get("x").?;
    const y = graph.node_index.get("y").?;
    const mid = graph.node_index.get("mid").?;
    const sink = graph.node_index.get("sink").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[source] = 0;
    ranks[x] = 1;
    ranks[y] = 1;
    ranks[mid] = 2;
    ranks[sink] = 3;

    improveRanksByLocalSearch(&graph, ranks, acyclic_edge, 4);
    try std.testing.expect(rankConstraintsSatisfied(&graph, ranks));
    try std.testing.expectEqual(ranks[x], ranks[y]);
}

test "rank sink tightening preserves explicit same-rank constraints" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=same; x; y; }
        \\  source -> x [weight=1];
        \\  x -> sink [weight=8];
        \\  source -> y -> mid -> sink;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const source = graph.node_index.get("source").?;
    const x = graph.node_index.get("x").?;
    const y = graph.node_index.get("y").?;
    const mid = graph.node_index.get("mid").?;
    const sink = graph.node_index.get("sink").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[source] = 0;
    ranks[x] = 1;
    ranks[y] = 1;
    ranks[mid] = 2;
    ranks[sink] = 3;

    tightenRanksTowardSinks(&graph, ranks, acyclic_edge);
    try std.testing.expect(rankConstraintsSatisfied(&graph, ranks));
    try std.testing.expectEqual(ranks[x], ranks[y]);
}

test "layered layout applies bounded network simplex rank improvement" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [weight=1];
        \\  a -> c [weight=1];
        \\  b -> x [weight=1];
        \\  x -> d [weight=1];
        \\  c -> d [weight=5];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const a = graph.node_index.get("a").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    try std.testing.expect(layout.ranks[c] > layout.ranks[a]);
    try std.testing.expectEqual(layout.ranks[d] - 1, layout.ranks[c]);
}

test "layered network simplex preserves explicit same-rank constraints" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=same; c; d; }
        \\  a -> b [weight=1];
        \\  a -> c [weight=1];
        \\  b -> x [weight=1];
        \\  x -> d [weight=1];
        \\  c -> d [weight=5];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    try std.testing.expectEqual(layout.ranks[c], layout.ranks[d]);
}

test "rank local search finds best feasible node rank" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  source -> x [weight=1];
        \\  x -> sink [weight=8];
        \\  source -> a -> b -> sink;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const source = graph.node_index.get("source").?;
    const x = graph.node_index.get("x").?;
    const sink = graph.node_index.get("sink").?;
    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[source] = 0;
    ranks[x] = 1;
    ranks[a] = 1;
    ranks[b] = 2;
    ranks[sink] = 3;

    const bounds = feasibleRankBoundsForNode(&graph, ranks, acyclic_edge, x).?;
    try std.testing.expectEqual(@as(usize, 1), bounds.min);
    try std.testing.expectEqual(@as(usize, 2), bounds.max);
    try std.testing.expectEqual(@as(usize, 2), bestFeasibleRankForNode(&graph, ranks, acyclic_edge, x).?);
}

test "bounded rank local search can move nodes upward when it lowers cost" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  source -> a -> b -> c -> sink;
        \\  source -> x [weight=8];
        \\  x -> sink [weight=1];
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const source = graph.node_index.get("source").?;
    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const sink = graph.node_index.get("sink").?;
    const x = graph.node_index.get("x").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[source] = 0;
    ranks[a] = 1;
    ranks[b] = 2;
    ranks[c] = 3;
    ranks[sink] = 4;
    ranks[x] = 3;

    const before = rankAssignmentCost(&graph, ranks, acyclic_edge);
    improveRanksByLocalSearch(&graph, ranks, acyclic_edge, 4);
    const after = rankAssignmentCost(&graph, ranks, acyclic_edge);
    try std.testing.expect(rankAssignmentFeasible(&graph, ranks, acyclic_edge));
    try std.testing.expect(after < before);
    try std.testing.expectEqual(@as(usize, 1), ranks[x]);
}

test "bounded rank local search rejects equal-cost moves" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  source -> x;
        \\  x -> sink;
        \\  source -> a -> b -> sink;
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const source = graph.node_index.get("source").?;
    const x = graph.node_index.get("x").?;
    const sink = graph.node_index.get("sink").?;
    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[source] = 0;
    ranks[x] = 1;
    ranks[a] = 1;
    ranks[b] = 2;
    ranks[sink] = 3;

    try std.testing.expectEqual(@as(usize, 2), bestFeasibleRankForNode(&graph, ranks, acyclic_edge, x).?);
    improveRanksByLocalSearch(&graph, ranks, acyclic_edge, 4);
    try std.testing.expectEqual(@as(usize, 1), ranks[x]);
}

test "rank slack tightening reduces whole graph weighted span cost" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b -> c -> d;
        \\  x -> d [weight=5];
        \\  y -> x [weight=1];
        \\}
    );
    defer graph.deinit();

    const acyclic_edge = try allocator.alloc(bool, graph.edges.items.len);
    defer allocator.free(acyclic_edge);
    @memset(acyclic_edge, true);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    const x = graph.node_index.get("x").?;
    const y = graph.node_index.get("y").?;
    const ranks = try allocator.alloc(usize, graph.nodes.items.len);
    defer allocator.free(ranks);
    ranks[a] = 0;
    ranks[b] = 1;
    ranks[c] = 2;
    ranks[d] = 3;
    ranks[x] = 0;
    ranks[y] = 0;

    const before = rankAssignmentCost(&graph, ranks, acyclic_edge);
    tightenRanksTowardSinks(&graph, ranks, acyclic_edge);
    const after = rankAssignmentCost(&graph, ranks, acyclic_edge);
    try std.testing.expect(rankAssignmentFeasible(&graph, ranks, acyclic_edge));
    try std.testing.expect(after < before);
    try std.testing.expectEqual(ranks[x] + 1, ranks[d]);
}

test "rank slack tightening preserves explicit boundary ranks" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=min; source; }
        \\  source -> mid -> sink;
        \\  source -> sink;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const source = graph.node_index.get("source").?;
    const mid = graph.node_index.get("mid").?;
    const sink = graph.node_index.get("sink").?;
    try std.testing.expectEqual(@as(usize, 0), layout.ranks[source]);
    try std.testing.expect(layout.ranks[source] < layout.ranks[mid]);
    try std.testing.expect(layout.ranks[mid] < layout.ranks[sink]);
}

test "SVG auto endpoints use side anchors for same-rank edges" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=same; a; b; }
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    try std.testing.expectEqual(layout.nodes[a].center.y, layout.nodes[b].center.y);
    const route = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], layout.rankdir, 0);
    try std.testing.expectEqual(layout.nodes[a].center.x + layout.nodes[a].width / 2.0, route.start.x);
    try std.testing.expectEqual(layout.nodes[b].center.x - layout.nodes[b].width / 2.0, route.end.x);
}

test "SVG auto endpoints clip ellipse nodes by direction" {
    const node = NodeLayout{ .center = .{ .x = 80, .y = 60 }, .width = 60, .height = 40 };
    const toward = Point{ .x = 140, .y = 120 };
    const point = ellipseBoundaryPoint(node, toward);
    const rx = node.width / 2.0;
    const ry = node.height / 2.0;
    const normalized = ((point.x - node.center.x) * (point.x - node.center.x)) / (rx * rx) +
        ((point.y - node.center.y) * (point.y - node.center.y)) / (ry * ry);

    try std.testing.expect(@abs(normalized - 1.0) <= 0.0001);
    try std.testing.expect(point.x > node.center.x);
    try std.testing.expect(point.y > node.center.y);
    try std.testing.expect(point.x < node.center.x + node.width / 2.0);
    try std.testing.expect(point.y < node.center.y + node.height / 2.0);
}

test "layout retains rank metadata for long-edge routing" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b -> c -> d;
        \\  a -> d [label="long"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const a = graph.node_index.get("a").?;
    const d = graph.node_index.get("d").?;
    try std.testing.expectEqual(@as(usize, 0), layout.ranks[a]);
    try std.testing.expectEqual(@as(usize, 3), layout.ranks[d]);
    try std.testing.expectEqual(@as(usize, 4), layout.rank_depths.len);
    try std.testing.expect(longEdgeWaypointCount(&layout, graph.edges.items[3]) == 2);
    try std.testing.expectEqual(@as(usize, 2), layout.edge_waypoints[3].points.len);
    try std.testing.expectEqual(@as(usize, 1), layout.edge_waypoints[3].points[0].rank);
    const waypoint = longEdgeWaypoint(&layout, graph.edges.items[3], layout.rankdir, 0, 0, 2);
    try std.testing.expectEqual(layout.edge_waypoints[3].points[0].point.x, waypoint.x);
    try std.testing.expectEqual(layout.edge_waypoints[3].points[0].point.y, waypoint.y);
}

test "long-edge waypoints use rankdir-aware dummy along axis" {
    const allocator = std.testing.allocator;

    var tb = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=TB];
        \\  a -> b -> c -> d;
        \\  a -> d;
        \\}
    );
    defer tb.deinit();
    var tb_layout = try layoutLayered(allocator, &tb, .{});
    defer tb_layout.deinit();
    const tb_edge = tb.edges.items[3];
    const tb_waypoint = longEdgeWaypoint(&tb_layout, tb_edge, tb_layout.rankdir, 0, 0, 2);
    try std.testing.expectEqual(tb_layout.edge_waypoints[tb_edge.id].points[0].point.x, tb_waypoint.x);
    try std.testing.expectEqual(tb_layout.edge_waypoints[tb_edge.id].points[0].point.y, tb_waypoint.y);

    var lr = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a -> b -> c -> d;
        \\  a -> d;
        \\}
    );
    defer lr.deinit();
    var lr_layout = try layoutLayered(allocator, &lr, .{});
    defer lr_layout.deinit();
    const lr_edge = lr.edges.items[3];
    const lr_waypoint = longEdgeWaypoint(&lr_layout, lr_edge, lr_layout.rankdir, 0, 0, 2);
    try std.testing.expectEqual(lr_layout.edge_waypoints[lr_edge.id].points[0].point.x, lr_waypoint.x);
    try std.testing.expectEqual(lr_layout.edge_waypoints[lr_edge.id].points[0].point.y, lr_waypoint.y);
}

test "long-edge waypoints avoid same-rank node boxes" {
    const allocator = std.testing.allocator;
    var layout = Layout{
        .allocator = allocator,
        .rankdir = .TB,
        .nodes = try allocator.alloc(NodeLayout, 3),
        .clusters = try allocator.alloc(ClusterLayout, 0),
        .edge_waypoints = try allocator.alloc(EdgeWaypoints, 1),
        .ranks = try allocator.alloc(usize, 3),
        .rank_depths = try allocator.alloc(f64, 3),
        .rank_heights = try allocator.alloc(f64, 3),
        .margin = 40,
        .margin_x = 40,
        .margin_y = 40,
        .width = 220,
        .height = 260,
    };
    defer layout.deinit();
    layout.nodes[0] = .{ .center = .{ .x = 80, .y = 60 }, .width = 40, .height = 30 };
    layout.nodes[1] = .{ .center = .{ .x = 80, .y = 130 }, .width = 54, .height = 36 };
    layout.nodes[2] = .{ .center = .{ .x = 80, .y = 200 }, .width = 40, .height = 30 };
    layout.edge_waypoints[0] = .{ .points = try allocator.dupe(EdgeWaypoint, &.{.{ .rank = 1, .point = .{ .x = 80, .y = 130 } }}) };
    layout.ranks[0] = 0;
    layout.ranks[1] = 1;
    layout.ranks[2] = 2;
    layout.rank_depths[0] = 0;
    layout.rank_depths[1] = 70;
    layout.rank_depths[2] = 140;
    layout.rank_heights[0] = 30;
    layout.rank_heights[1] = 36;
    layout.rank_heights[2] = 30;

    const edge_item = Edge{
        .id = 0,
        .from = 0,
        .to = 2,
    };
    const waypoint = longEdgeWaypoint(&layout, edge_item, .TB, 0, 0, 1);
    try std.testing.expect(!pointInsideNodeWithPadding(waypoint, layout.nodes[1], 0));
    try std.testing.expect(waypoint.x < layout.nodes[1].center.x - layout.nodes[1].width / 2.0);
}

test "SVG routes skip-rank edges through intermediate waypoints" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b -> c -> d;
        \\  a -> d [label="long"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    const marker = "long";
    const label_pos = std.mem.indexOf(u8, svg, marker) orelse return error.MissingLongLabel;
    const before_label = svg[0..label_pos];
    const path_start = std.mem.lastIndexOf(u8, before_label, "<path") orelse return error.MissingLongPath;
    const path_end_rel = std.mem.indexOf(u8, svg[path_start..], "/>") orelse return error.MissingLongPathEnd;
    const path = svg[path_start .. path_start + path_end_rel];
    try std.testing.expect(svgCubicSegmentCount(path) >= 3);
}

test "SVG clamps outward long-edge waypoints for forward cluster cross edges" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_0 {
        \\    node [style=filled,color=white];
        \\    a0 -> a1 -> a2 -> a3;
        \\  }
        \\  subgraph cluster_1 {
        \\    node [style=filled];
        \\    b0 -> b1 -> b2 -> b3;
        \\  }
        \\  a1 -> b3 [label="cross"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const edge_item = graph.edges.items[6];
    try std.testing.expect(longEdgeWaypointCount(&layout, edge_item) >= 1);
    const route = edgeRouteForEdge(&graph, &layout, edge_item, layout.rankdir, 0);

    var aw = Io.Writer.Allocating.init(allocator);
    defer aw.deinit();
    try writeEdgePath(&aw.writer, &layout, edge_item, layout.rankdir, 0, route, .curved);
    const path = try aw.toOwnedSlice();
    defer allocator.free(path);
    try std.testing.expect(pathDataCommandCount(path, 'C') == 1);
    try std.testing.expect(std.mem.indexOf(u8, path, "196.5") == null);
}

test "SVG routes multi-rank back edges around the side" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a0 -> a1 -> a2 -> a3;
        \\  a3 -> a0 [label="back"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const route = edgeRouteForEdge(&graph, &layout, graph.edges.items[3], layout.rankdir, 0);
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    const label_pos = std.mem.indexOf(u8, svg, ">back</tspan>") orelse return error.MissingBackLabel;
    const before_label = svg[0..label_pos];
    const path_start = std.mem.lastIndexOf(u8, before_label, "<path") orelse return error.MissingBackPath;
    const path_end_rel = std.mem.indexOf(u8, svg[path_start..], "/>") orelse return error.MissingBackPathEnd;
    const path = svg[path_start .. path_start + path_end_rel];
    try std.testing.expect(isBackEdge(&layout, graph.edges.items[3]));
    try std.testing.expect(svgCubicSegmentCount(path) == 3);
    try std.testing.expect(svgPathCommandCount(path, 'L') == 0);
    try std.testing.expect(svgPathCommandCount(path, 'C') != 0);
    try std.testing.expect(route.start.y > route.end.y);
    var path_numbers: [32]f64 = undefined;
    const count = svgNumbersInAttribute(path, "d", path_numbers[0..]);
    try std.testing.expect(count >= 20);
    const side_x = path_numbers[6];
    try std.testing.expect(path_numbers[2] >= side_x);
    try std.testing.expectEqual(side_x, path_numbers[4]);
    try std.testing.expectEqual(side_x, path_numbers[8]);
    try std.testing.expectEqual(side_x, path_numbers[10]);
    try std.testing.expectEqual(side_x, path_numbers[12]);
    try std.testing.expectEqual(side_x, path_numbers[14]);
}

test "back-edge side channel prefers stable negative side for same column" {
    const allocator = std.testing.allocator;
    var layout = Layout{
        .allocator = allocator,
        .rankdir = .TB,
        .nodes = try allocator.alloc(NodeLayout, 2),
        .clusters = try allocator.alloc(ClusterLayout, 0),
        .edge_waypoints = try allocator.alloc(EdgeWaypoints, 0),
        .ranks = try allocator.alloc(usize, 2),
        .rank_depths = try allocator.alloc(f64, 0),
        .rank_heights = try allocator.alloc(f64, 0),
        .margin = 40,
        .margin_x = 40,
        .margin_y = 40,
        .width = 220,
        .height = 260,
    };
    defer layout.deinit();
    layout.nodes[0] = .{ .center = .{ .x = 70, .y = 180 }, .width = 54, .height = 36 };
    layout.nodes[1] = .{ .center = .{ .x = 68, .y = 60 }, .width = 54, .height = 36 };
    layout.ranks[0] = 3;
    layout.ranks[1] = 0;

    const edge_item = Edge{ .id = 0, .from = 0, .to = 1 };
    try std.testing.expect(backEdgeUsesNegativeSide(&layout, edge_item, .TB));
    layout.nodes[0].center.x = 150;
    try std.testing.expect(!backEdgeUsesNegativeSide(&layout, edge_item, .TB));
}

test "SVG routes rankdir LR and RL back edges around the side" {
    const allocator = std.testing.allocator;

    var lr = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a0 -> a1 -> a2 -> a3;
        \\  a3 -> a0 [label="back"];
        \\}
    );
    defer lr.deinit();
    var lr_layout = try layoutLayered(allocator, &lr, .{});
    defer lr_layout.deinit();
    const lr_route = edgeRouteForEdge(&lr, &lr_layout, lr.edges.items[3], lr.rankdir, 0);
    try std.testing.expect(isBackEdge(&lr_layout, lr.edges.items[3]));
    try std.testing.expect(lr_route.start.x > lr_route.end.x);
    const lr_svg = try renderSvgAlloc(allocator, &lr, &lr_layout, .{});
    defer allocator.free(lr_svg);
    try expectBackEdgeSidePath(lr_svg);

    var rl = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=RL];
        \\  a0 -> a1 -> a2 -> a3;
        \\  a3 -> a0 [label="back"];
        \\}
    );
    defer rl.deinit();
    var rl_layout = try layoutLayered(allocator, &rl, .{});
    defer rl_layout.deinit();
    const rl_route = edgeRouteForEdge(&rl, &rl_layout, rl.edges.items[3], rl.rankdir, 0);
    try std.testing.expect(isBackEdge(&rl_layout, rl.edges.items[3]));
    try std.testing.expect(rl_route.start.x < rl_route.end.x);
    const rl_svg = try renderSvgAlloc(allocator, &rl, &rl_layout, .{});
    defer allocator.free(rl_svg);
    try expectBackEdgeSidePath(rl_svg);
}

fn expectBackEdgeSidePath(svg: []const u8) !void {
    const label_pos = std.mem.indexOf(u8, svg, ">back</tspan>") orelse return error.MissingBackLabel;
    const before_label = svg[0..label_pos];
    const path_start = std.mem.lastIndexOf(u8, before_label, "<path") orelse return error.MissingBackPath;
    const path_end_rel = std.mem.indexOf(u8, svg[path_start..], "/>") orelse return error.MissingBackPathEnd;
    const path = svg[path_start .. path_start + path_end_rel];
    try std.testing.expect(svgCubicSegmentCount(path) == 3);
    try std.testing.expect(svgPathCommandCount(path, 'L') == 0);
}

test "user cluster example stays compact and Graphviz-like" {
    const allocator = std.testing.allocator;
    const graphviz_oracle = @embedFile("testdata/test000.svg");
    var graph = try parseDot(allocator, @embedFile("testdata/test000.dot"));
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expect(layout.width <= 224.0);
    try std.testing.expect(layout.height <= 409.0);
    for (layout.clusters) |cluster_box| try std.testing.expect(cluster_box.height <= 294.0);

    const a0 = graph.node_index.get("a0").?;
    const a1 = graph.node_index.get("a1").?;
    const a2 = graph.node_index.get("a2").?;
    const a3 = graph.node_index.get("a3").?;
    const b0 = graph.node_index.get("b0").?;
    const b1 = graph.node_index.get("b1").?;
    const b2 = graph.node_index.get("b2").?;
    const b3 = graph.node_index.get("b3").?;
    const start = graph.node_index.get("start").?;
    const end = graph.node_index.get("end").?;
    try std.testing.expect(@abs(layout.nodes[a0].center.x - layout.nodes[a1].center.x) <= 1.0);
    try std.testing.expect(@abs(layout.nodes[a1].center.x - layout.nodes[a2].center.x) <= 1.0);
    try std.testing.expect(@abs(layout.nodes[a2].center.x - layout.nodes[a3].center.x) <= 1.0);
    try std.testing.expect(layout.nodes[b1].center.x > layout.nodes[b0].center.x);
    try std.testing.expect(layout.nodes[b2].center.x > layout.nodes[b1].center.x);
    try std.testing.expect(@abs(layout.nodes[b3].center.x - layout.nodes[b0].center.x) <= 1.0);
    try std.testing.expect(layout.nodes[start].center.x > layout.nodes[a0].center.x);
    try std.testing.expect(layout.nodes[start].center.x < layout.nodes[b0].center.x);
    try std.testing.expect(layout.nodes[end].center.x > layout.nodes[a3].center.x);
    try std.testing.expect(layout.nodes[end].center.x < layout.nodes[b3].center.x);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"224pt\" height=\"409pt\" viewBox=\"0.00 0.00 224.00 408.80\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"graph0\" class=\"graph\" transform=\"scale(1 1) rotate(0) translate(8.0 0)\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>G</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"white\" stroke=\"none\" points=\"-8.0,0 -8.0,409 216.0,409 216.0,0 -8.0,0\"/>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g class=\"content\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<rect width=\"100%\" height=\"100%\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<defs>") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g class=\"edges\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g class=\"nodes\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "class=\"clusters\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">G</text>") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">a0</text>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">start</text>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">a0</tspan>") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">start</tspan>") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.00\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.0\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-anchor=\"middle\" x=\"51.0\" y=\"101.1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.00\" fill=\"black\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"clust1\" class=\"cluster\">") != null);
    const cluster_0_group_pos = std.mem.indexOf(u8, svg, "<title>cluster_0</title>") orelse return error.MissingCluster0;
    const cluster_1_group_pos = std.mem.indexOf(u8, svg, "<title>cluster_1</title>") orelse return error.MissingCluster1;
    try std.testing.expect(cluster_0_group_pos < cluster_1_group_pos);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>cluster_0</title>\n<polygon") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<!-- a0 -->") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<!-- a0&#45;&gt;a1 -->") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"edge1\" class=\"edge\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>a0-&gt;a1</title>\n<path fill=\"none\" stroke=\"black\" d=\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"black\" stroke=\"black\" points=\"47.5,141.3 51.0,151.3 54.5,141.3 47.5,141.3\"/>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"node1\" class=\"node\">") != null);
    const node1_group_pos = std.mem.indexOf(u8, svg, "<g id=\"node1\" class=\"node\">") orelse return error.MissingNode1;
    const node2_group_pos = std.mem.indexOf(u8, svg, "<g id=\"node2\" class=\"node\">") orelse return error.MissingNode2;
    const edge1_group_pos = std.mem.indexOf(u8, svg, "<g id=\"edge1\" class=\"edge\">") orelse return error.MissingEdge1;
    const node8_group_pos = std.mem.indexOf(u8, svg, "<g id=\"node8\" class=\"node\">") orelse return error.MissingNode8;
    const edge9_group_pos = std.mem.indexOf(u8, svg, "<g id=\"edge9\" class=\"edge\">") orelse return error.MissingEdge9;
    const edge10_group_pos = std.mem.indexOf(u8, svg, "<g id=\"edge10\" class=\"edge\">") orelse return error.MissingEdge10;
    const edge6_group_pos = std.mem.indexOf(u8, svg, "<g id=\"edge6\" class=\"edge\">") orelse return error.MissingEdge6;
    try std.testing.expect(node1_group_pos < node2_group_pos);
    try std.testing.expect(node2_group_pos < edge1_group_pos);
    try std.testing.expect(node8_group_pos < edge9_group_pos);
    try std.testing.expect(edge10_group_pos < edge6_group_pos);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>a0</title>\n<ellipse fill=\"white\" stroke=\"white\" cx=\"51.0\" cy=\"97.3\" rx=\"27.0\" ry=\"18.0\"/>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Times,serif\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"lightgrey\" stroke=\"lightgrey\" points=\"0.0,49.3 90.0,49.3 90.0,343.3 0.0,343.3 0.0,49.3\"/>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>end</title>\n<polygon fill=\"none\" stroke=\"black\" points=\"91.5,367.3 127.5,367.3 127.5,403.3 91.5,403.3 91.5,367.3\"/>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polyline fill=\"none\" stroke=\"black\" points=\"91.5,379.3 103.5,367.3\"/>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>start</title>\n<polygon fill=\"none\" stroke=\"black\" points=\"109.5,5.5 148.8,24.4 109.5,43.3 70.3,24.4\"/>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "x=\"45.0\" y=\"64.6\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "x=\"168.5\" y=\"64.6\"") != null);
    const svg_cluster_0_w = svgClusterRectWidth(svg, "cluster_0") orelse return error.MissingClusterRect;
    try std.testing.expect(svg_cluster_0_w >= 86.0);
    try std.testing.expect(svg_cluster_0_w <= 90.0);
    try std.testing.expect((svgClusterRectWidth(svg, "cluster_1") orelse return error.MissingClusterRect) <= 80.0);
    try std.testing.expect(@abs(svgClusterScreenX(svg, "cluster_0").? - svgClusterScreenX(graphviz_oracle, "cluster_0").?) <= 4.5);
    try std.testing.expect(@abs(svg_cluster_0_w - svgClusterRectWidth(graphviz_oracle, "cluster_0").?) <= 4.0);
    try std.testing.expect(@abs(svgClusterScreenX(svg, "cluster_1").? - svgClusterScreenX(graphviz_oracle, "cluster_1").?) <= 1.0);
    try std.testing.expect(@abs(svgClusterRectWidth(svg, "cluster_1").? - svgClusterRectWidth(graphviz_oracle, "cluster_1").?) <= 4.0);
    const svg_start_x = svgNodeCenterX(svg, "start") orelse return error.MissingNodeCenter;
    const svg_end_x = svgNodeCenterX(svg, "end") orelse return error.MissingNodeCenter;
    try std.testing.expect(svg_start_x > svgNodeCenterX(svg, "a0").?);
    try std.testing.expect(svg_start_x < svgNodeCenterX(svg, "b0").?);
    try std.testing.expect(svg_end_x > svgNodeCenterX(svg, "a3").?);
    try std.testing.expect(svg_end_x < svgNodeCenterX(svg, "b3").?);
    try std.testing.expect(svg_start_x >= 109.0);
    try std.testing.expect(svg_end_x >= 109.0);
    const svg_a0_x = svgNodeCenterX(svg, "a0") orelse return error.MissingNodeCenter;
    const svg_b0_x = svgNodeCenterX(svg, "b0") orelse return error.MissingNodeCenter;
    try std.testing.expect(svg_a0_x >= 51.0);
    try std.testing.expect(svg_b0_x >= 168.0);
    try std.testing.expect(svg_b0_x - svg_a0_x >= 117.0);
    try std.testing.expect(@abs(svgNodeScreenCenterX(svg, "a0").? - svgNodeScreenCenterX(graphviz_oracle, "a0").?) <= 8.5);
    try std.testing.expect(@abs(svgNodeScreenCenterX(svg, "b0").? - svgNodeScreenCenterX(graphviz_oracle, "b0").?) <= 4.0);
    try std.testing.expect(@abs(svgNodeScreenCenterX(svg, "start").? - svgNodeScreenCenterX(graphviz_oracle, "start").?) <= 2.0);
    try std.testing.expect(@abs(svgNodeScreenCenterX(svg, "end").? - svgNodeScreenCenterX(graphviz_oracle, "end").?) <= 2.0);
    const cluster_0_x = svgClusterRectX(svg, "cluster_0") orelse return error.MissingClusterRect;
    const cluster_0_w = svgClusterRectWidth(svg, "cluster_0") orelse return error.MissingClusterRect;
    const cluster_1_x = svgClusterRectX(svg, "cluster_1") orelse return error.MissingClusterRect;
    try std.testing.expect(cluster_1_x - (cluster_0_x + cluster_0_w) >= 35.0);
    const cross_label = std.mem.indexOf(u8, svg, "<title>a1-&gt;b3</title>") orelse return error.MissingCrossClusterEdge;
    const cross_end = std.mem.indexOf(u8, svg[cross_label..], "</g>") orelse return error.MissingCrossClusterEdge;
    const cross_edge = svg[cross_label .. cross_label + cross_end];
    try std.testing.expect(std.mem.indexOf(u8, cross_edge, "196.5") == null);
    try std.testing.expect(svgCubicSegmentCount(cross_edge) == 1);
    var path_numbers: [32]f64 = undefined;
    const cross_count = svgPathNumbers(svg, "a1-&gt;b3", path_numbers[0..]);
    try std.testing.expect(cross_count >= 8);
    var oracle_path_numbers: [32]f64 = undefined;
    const oracle_cross_count = svgPathNumbers(graphviz_oracle, "a1-&gt;b3", oracle_path_numbers[0..]);
    try std.testing.expect(oracle_cross_count >= 8);
    const svg_translate = svgGraphvizTranslate(svg);
    const oracle_translate = svgGraphvizTranslate(graphviz_oracle);
    try std.testing.expect(@abs((path_numbers[0] + svg_translate.x) - (oracle_path_numbers[0] + oracle_translate.x)) <= 7.5);
    try std.testing.expect(path_numbers[2] < 100.0);
    const diagonal_count = svgPathNumbers(svg, "b2-&gt;a3", path_numbers[0..]);
    try std.testing.expect(diagonal_count >= 8);
    const oracle_diagonal_count = svgPathNumbers(graphviz_oracle, "b2-&gt;a3", oracle_path_numbers[0..]);
    try std.testing.expect(oracle_diagonal_count >= 8);
    try std.testing.expect(@abs((path_numbers[0] + svg_translate.x) - (oracle_path_numbers[0] + oracle_translate.x)) <= 3.0);
    try std.testing.expect(path_numbers[2] > path_numbers[4]);
    try std.testing.expect(path_numbers[4] > path_numbers[6]);
    const back_label = std.mem.indexOf(u8, svg, "<title>a3-&gt;a0</title>") orelse return error.MissingBackEdge;
    const back_end = std.mem.indexOf(u8, svg[back_label..], "</g>") orelse return error.MissingBackEdge;
    const back_edge = svg[back_label .. back_label + back_end];
    try std.testing.expect(svgCubicSegmentCount(back_edge) == 3);
    try std.testing.expect(svgPathCommandCount(back_edge, 'L') == 0);
    var back_numbers: [32]f64 = undefined;
    const back_count = svgNumbersInAttribute(back_edge, "d", back_numbers[0..]);
    try std.testing.expect(back_count >= 20);
    try std.testing.expect(@abs(back_numbers[6] - 16.0) <= 0.1);
}

test "SVG renderer honors DOT splines graph attribute" {
    const allocator = std.testing.allocator;
    var ortho = try parseDot(allocator,
        \\digraph G {
        \\  graph [splines=ortho, rankdir=LR];
        \\  a -> b [label="ortho"];
        \\}
    );
    defer ortho.deinit();
    var ortho_layout = try layoutLayered(allocator, &ortho, .{});
    defer ortho_layout.deinit();
    const ortho_svg = try renderSvgAlloc(allocator, &ortho, &ortho_layout, .{});
    defer allocator.free(ortho_svg);
    try std.testing.expect(svgPathCommandCount(ortho_svg, 'C') == 0);
    try std.testing.expect(svgPathCommandCount(ortho_svg, 'L') >= 3);

    var line = try parseDot(allocator,
        \\digraph G {
        \\  graph [splines=line];
        \\  a -> b [label="line"];
        \\}
    );
    defer line.deinit();
    var line_layout = try layoutLayered(allocator, &line, .{});
    defer line_layout.deinit();
    const line_svg = try renderSvgAlloc(allocator, &line, &line_layout, .{});
    defer allocator.free(line_svg);
    try std.testing.expect(svgPathCommandCount(line_svg, 'C') == 0);
    try std.testing.expect(svgPathCommandCount(line_svg, 'L') >= 1);

    var false_splines = try parseDot(allocator,
        \\digraph G {
        \\  graph [splines=false];
        \\  a -> b [label="false"];
        \\}
    );
    defer false_splines.deinit();
    var false_layout = try layoutLayered(allocator, &false_splines, .{});
    defer false_layout.deinit();
    const false_svg = try renderSvgAlloc(allocator, &false_splines, &false_layout, .{});
    defer allocator.free(false_svg);
    try std.testing.expect(svgPathCommandCount(false_svg, 'C') == 0);
    try std.testing.expect(svgPathCommandCount(false_svg, 'L') >= 1);

    var none = try parseDot(allocator,
        \\digraph G {
        \\  graph [splines=none];
        \\  a -> b [label="none"];
        \\}
    );
    defer none.deinit();
    var none_layout = try layoutLayered(allocator, &none, .{});
    defer none_layout.deinit();
    const none_svg = try renderSvgAlloc(allocator, &none, &none_layout, .{});
    defer allocator.free(none_svg);
    try std.testing.expect(svgPathCommandCount(none_svg, 'C') == 0);
    try std.testing.expect(svgPathCommandCount(none_svg, 'L') >= 1);
}

test "spline controls stay monotonic for short adjacent edges" {
    const from = NodeLayout{ .center = .{ .x = 40, .y = 40 }, .width = 30, .height = 20 };
    const to = NodeLayout{ .center = .{ .x = 40, .y = 90 }, .width = 30, .height = 20 };
    const route = edgeRoute(from, to, .TB, 0);
    try std.testing.expect(route.control1.y <= route.control2.y);
    try std.testing.expect(route.control1.y <= route.end.y);
    try std.testing.expect(route.control2.y >= route.start.y);

    const lr_from = NodeLayout{ .center = .{ .x = 40, .y = 40 }, .width = 30, .height = 20 };
    const lr_to = NodeLayout{ .center = .{ .x = 90, .y = 40 }, .width = 30, .height = 20 };
    const lr_route = edgeRoute(lr_from, lr_to, .LR, 0);
    try std.testing.expect(lr_route.control1.x <= lr_route.control2.x);
    try std.testing.expect(lr_route.control1.x <= lr_route.end.x);
    try std.testing.expect(lr_route.control2.x >= lr_route.start.x);
}

test "spline controls follow diagonal edges" {
    const from = NodeLayout{ .center = .{ .x = 120, .y = 120 }, .width = 30, .height = 20 };
    const to = NodeLayout{ .center = .{ .x = 40, .y = 200 }, .width = 30, .height = 20 };
    const route = edgeRoute(from, to, .TB, 0);

    try std.testing.expect(route.control1.x < route.start.x);
    try std.testing.expect(route.control1.x > route.control2.x);
    try std.testing.expect(route.control2.x > route.end.x);
    try std.testing.expect(route.control1.y < route.control2.y);
}

test "SVG marker path route shortens arrow endpoints" {
    const route = EdgeRoute{
        .start = .{ .x = 0, .y = 0 },
        .control1 = .{ .x = 0, .y = 30 },
        .control2 = .{ .x = 0, .y = 70 },
        .end = .{ .x = 0, .y = 100 },
        .label = .{ .x = 0, .y = 50 },
    };
    const none = routeForPathMarkers(route, .{
        .stroke = "black",
        .font_color = "black",
        .font_family = default_svg_font_family,
        .font_size = 14,
        .width = 1,
        .dash = .none,
        .marker_start = .none,
        .marker_end = .none,
        .marker_scale = 1,
        .hidden = false,
    });
    try std.testing.expectEqual(route.end.y, none.end.y);

    const shortened = routeForPathMarkers(route, .{
        .stroke = "black",
        .font_color = "black",
        .font_family = default_svg_font_family,
        .font_size = 14,
        .width = 1,
        .dash = .none,
        .marker_start = .none,
        .marker_end = .normal,
        .marker_scale = 1,
        .hidden = false,
    });
    try std.testing.expect(shortened.end.y < route.end.y);
    try std.testing.expectEqual(route.label.y, shortened.label.y);
}

test "DOT parser propagates edge constraint and minlen controls" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  edge [constraint=false, minlen=2, weight=3];
        \\  a -> b;
        \\  b -> c [constraint=true, min_len=4, weight=5];
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 2), graph.edges.items.len);
    try std.testing.expect(!graph.edges.items[0].constraint);
    try std.testing.expectEqual(@as(usize, 2), graph.edges.items[0].min_len);
    try std.testing.expectEqual(@as(f64, 3.0), graph.edges.items[0].weight);
    try std.testing.expect(graph.edges.items[1].constraint);
    try std.testing.expectEqual(@as(usize, 4), graph.edges.items[1].min_len);
    try std.testing.expectEqual(@as(f64, 5.0), graph.edges.items[1].weight);
}

test "layered layout respects edge constraint false and minlen" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b [constraint=false];
        \\  a -> c [minlen=3];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    try std.testing.expectEqual(layout.ranks[a], layout.ranks[b]);
    try std.testing.expectEqual(layout.ranks[a] + 3, layout.ranks[c]);
}

test "DOT parser records cluster subgraphs with graph attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_api {
        \\    graph [label="API", color="#2563eb", fillcolor="#dbeafe", style="filled,rounded"];
        \\    a; b;
        \\    a -> b;
        \\  }
        \\  c;
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 1), graph.clusters.items.len);
    const cluster = graph.clusters.items[0];
    try std.testing.expectEqualStrings("cluster_api", cluster.name);
    try std.testing.expectEqualStrings("API", cluster.label);
    try std.testing.expectEqual(@as(usize, 2), cluster.nodes.len);
    try std.testing.expectEqualStrings("#2563eb", attrValue(cluster.attrs.items, "color").?);
    try std.testing.expectEqualStrings("#dbeafe", attrValue(cluster.attrs.items, "fillcolor").?);
}

test "cluster layout boxes contain member nodes and render to SVG" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_api {
        \\    label="API";
        \\    color="#2563eb";
        \\    fillcolor="#dbeafe";
        \\    style="filled,rounded";
        \\    a -> b;
        \\  }
        \\  b -> c;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expectEqual(@as(usize, 1), layout.clusters.len);

    const cluster_box = layout.clusters[0];
    for (graph.clusters.items[0].nodes) |node_id| {
        const n = layout.nodes[node_id];
        try std.testing.expect(cluster_box.x <= n.center.x - n.width / 2.0);
        try std.testing.expect(cluster_box.y <= n.center.y - n.height / 2.0);
        try std.testing.expect(cluster_box.x + cluster_box.width >= n.center.x + n.width / 2.0);
        try std.testing.expect(cluster_box.y + cluster_box.height >= n.center.y + n.height / 2.0);
    }

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "class=\"clusters\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"clust1\" class=\"cluster\">\n<title>cluster_api</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>cluster_api</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "API") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#dbeafe\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"#2563eb\"") != null);
}

test "cluster layout uses compact padding while fitting labels" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_process {
        \\    label="process #1";
        \\    a;
        \\  }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const cluster_box = layout.clusters[0];
    const a = graph.node_index.get("a").?;
    const node = layout.nodes[a];
    try std.testing.expect(cluster_box.width >= node.width + 24.0);
    try std.testing.expect(cluster_box.width <= 96.0);
    try std.testing.expect(cluster_box.height >= node.height + 42.0);
    try std.testing.expect(cluster_box.height <= node.height + 48.0);
}

test "cluster fill follows Graphviz style filled color semantics" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_filled {
        \\    style=filled;
        \\    color=lightgrey;
        \\    a -> b;
        \\  }
        \\  subgraph cluster_outline {
        \\    color=blue;
        \\    c -> d;
        \\  }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"lightgrey\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"lightgrey\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\" stroke=\"blue\"") != null);
}

test "cluster labels honor labelloc and labeljust" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_bottom_left {
        \\    label="Bottom Left";
        \\    labelloc=b;
        \\    labeljust=l;
        \\    a -> b;
        \\  }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "text-anchor=\"start\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Bottom Left") != null);
    const box = layout.clusters[0];
    var expected_buf: [64]u8 = undefined;
    const expected_y = try std.fmt.bufPrint(&expected_buf, "y=\"{d:.1}\"", .{box.y + box.height - 10.0});
    try std.testing.expect(std.mem.indexOf(u8, svg, expected_y) != null);
}

test "nested cluster layout expands parent around child cluster" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_outer {
        \\    label="Outer";
        \\    subgraph cluster_inner {
        \\      label="Inner";
        \\      a -> b;
        \\    }
        \\    c;
        \\  }
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 2), graph.clusters.items.len);
    const inner = graph.clusters.items[0];
    const outer = graph.clusters.items[1];
    try std.testing.expectEqualStrings("cluster_outer", inner.parent_name.?);
    try std.testing.expectEqualStrings("cluster_inner", inner.name);
    try std.testing.expectEqualStrings("cluster_outer", outer.name);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const inner_box = layout.clusters[0];
    const outer_box = layout.clusters[1];
    try std.testing.expect(outer_box.x <= inner_box.x);
    try std.testing.expect(outer_box.y <= inner_box.y);
    try std.testing.expect(outer_box.x + outer_box.width >= inner_box.x + inner_box.width);
    try std.testing.expect(outer_box.y + outer_box.height >= inner_box.y + inner_box.height);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    const outer_pos = std.mem.indexOf(u8, svg, "Outer") orelse return error.MissingOuterCluster;
    const inner_pos = std.mem.indexOf(u8, svg, "Inner") orelse return error.MissingInnerCluster;
    try std.testing.expect(outer_pos < inner_pos);
}

test "cluster members are kept contiguous within a rank" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=same; a; b; c; d; }
        \\  subgraph cluster_pair {
        \\    a; c;
        \\  }
        \\}
    );
    defer graph.deinit();

    var levels = try allocator.alloc(std.ArrayList(NodeId), 1);
    defer allocator.free(levels);
    levels[0] = .empty;
    defer levels[0].deinit(allocator);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const d = graph.node_index.get("d").?;
    try levels[0].append(allocator, a);
    try levels[0].append(allocator, b);
    try levels[0].append(allocator, c);
    try levels[0].append(allocator, d);

    enforceClusterContiguity(&graph, levels);
    try std.testing.expectEqual(a, levels[0].items[0]);
    try std.testing.expectEqual(c, levels[0].items[1]);
}

test "layered layout honors DOT node group alignment hints" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=TB];
        \\  s1 [group=main];
        \\  s2;
        \\  m1 [group=main];
        \\  m2;
        \\  t1 [group=main];
        \\  t2;
        \\  s2 -> m1;
        \\  s1 -> m2;
        \\  m2 -> t1;
        \\  m1 -> t2;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const s1 = graph.node_index.get("s1").?;
    const m1 = graph.node_index.get("m1").?;
    const t1 = graph.node_index.get("t1").?;
    try std.testing.expectEqualStrings("main", attrValue(graph.nodes.items[s1].attrs.items, "group").?);
    const max_delta = @max(
        @abs(layout.nodes[s1].center.x - layout.nodes[m1].center.x),
        @abs(layout.nodes[m1].center.x - layout.nodes[t1].center.x),
    );
    try std.testing.expect(max_delta <= 1.0);
}

test "inter-cluster coordinate spacing separates adjacent cluster columns" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=same; a; b; }
        \\  subgraph cluster_left { a; }
        \\  subgraph cluster_right { b; }
        \\}
    );
    defer graph.deinit();

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    var levels = try allocator.alloc(std.ArrayList(NodeId), 1);
    defer allocator.free(levels);
    levels[0] = .empty;
    defer levels[0].deinit(allocator);
    try levels[0].append(allocator, a);
    try levels[0].append(allocator, b);

    const centers = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(centers);
    centers[a] = 40;
    centers[b] = 80;
    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    applyInterClusterSpacing(&graph, levels, centers, sizes, 15);
    try std.testing.expect(centers[b] - centers[a] >= 59);
}

test "inter-cluster coordinate spacing ignores same-cluster neighbors" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=same; a; b; }
        \\  subgraph cluster_left { a; b; }
        \\}
    );
    defer graph.deinit();

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    var levels = try allocator.alloc(std.ArrayList(NodeId), 1);
    defer allocator.free(levels);
    levels[0] = .empty;
    defer levels[0].deinit(allocator);
    try levels[0].append(allocator, a);
    try levels[0].append(allocator, b);

    const centers = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(centers);
    centers[a] = 40;
    centers[b] = 80;
    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    applyInterClusterSpacing(&graph, levels, centers, sizes, 15);
    try std.testing.expectEqual(@as(f64, 80), centers[b]);
}

test "inter-cluster spacing respects extent budget" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  { rank=same; a; b; }
        \\  subgraph cluster_left { a; }
        \\  subgraph cluster_right { b; }
        \\}
    );
    defer graph.deinit();

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    var levels = try allocator.alloc(std.ArrayList(NodeId), 1);
    defer allocator.free(levels);
    levels[0] = .empty;
    defer levels[0].deinit(allocator);
    try levels[0].append(allocator, a);
    try levels[0].append(allocator, b);

    const centers = try allocator.alloc(f64, graph.nodes.items.len);
    defer allocator.free(centers);
    centers[a] = 40;
    centers[b] = 80;
    const sizes = try allocator.alloc(NodeSize, graph.nodes.items.len);
    defer allocator.free(sizes);
    for (sizes) |*size| size.* = .{ .width = 20, .height = 20 };

    applyInterClusterSpacingWithBudget(&graph, levels, centers, sizes, 30, 90);
    try std.testing.expectEqual(@as(f64, 80), centers[b]);
    applyInterClusterSpacingWithBudget(&graph, levels, centers, sizes, 15, 200);
    try std.testing.expect(centers[b] > 80);
}

test "coordinate constraints propagate minimum gaps" {
    var centers = [_]f64{ 10, 12, 13 };
    const constraints = [_]CoordConstraint{
        .{ .left = 0, .right = 1, .min_gap = 20 },
        .{ .left = 1, .right = 2, .min_gap = 15 },
    };

    try std.testing.expect(satisfyCoordConstraints(centers[0..], constraints[0..]));
    try std.testing.expectEqual(@as(f64, 10), centers[0]);
    try std.testing.expectEqual(@as(f64, 30), centers[1]);
    try std.testing.expectEqual(@as(f64, 45), centers[2]);
    try std.testing.expect(!satisfyCoordConstraints(centers[0..], constraints[0..]));
}

test "group shift constraints move node sets within extent budget" {
    var centers = [_]f64{ 20, 40, 80 };
    const sizes = [_]NodeSize{
        .{ .width = 10, .height = 10 },
        .{ .width = 10, .height = 10 },
        .{ .width = 10, .height = 10 },
    };
    const group = [_]NodeId{ 0, 1 };
    const constraints = [_]GroupShiftConstraint{
        .{ .nodes = group[0..], .min_shift = 12 },
    };

    try std.testing.expect(applyGroupShiftConstraints(centers[0..], constraints[0..], 95, sizes[0..]));
    try std.testing.expectEqual(@as(f64, 30), centers[0]);
    try std.testing.expectEqual(@as(f64, 50), centers[1]);
    try std.testing.expectEqual(@as(f64, 80), centers[2]);
}

test "cluster containment envelope includes Graphviz-style margin" {
    var node_ids = [_]NodeId{ 0, 1 };
    const cluster = Cluster{
        .id = 0,
        .name = "cluster",
        .label = "cluster",
        .nodes = node_ids[0..],
    };
    const centers = [_]f64{ 50, 80 };
    const sizes = [_]NodeSize{
        .{ .width = 20, .height = 10 },
        .{ .width = 30, .height = 10 },
    };

    const envelope = clusterContainmentEnvelope(cluster, centers[0..], sizes[0..], 8.0).?;
    try std.testing.expectEqual(@as(f64, 32), envelope.left);
    try std.testing.expectEqual(@as(f64, 103), envelope.right);
}

test "cluster boundary solver models Graphviz ln rn containment" {
    var node_ids = [_]NodeId{ 0, 1 };
    const cluster = Cluster{
        .id = 0,
        .name = "cluster",
        .label = "cluster",
        .nodes = node_ids[0..],
    };
    const centers = [_]f64{ 50, 80 };
    const sizes = [_]NodeSize{
        .{ .width = 20, .height = 10 },
        .{ .width = 30, .height = 10 },
    };

    const boundary = solveClusterBoundary(cluster, centers[0..], sizes[0..], 8.0).?;
    try std.testing.expect(boundary.left <= centers[0] - sizes[0].width / 2.0 - 8.0);
    try std.testing.expect(boundary.right >= centers[1] + sizes[1].width / 2.0 + 8.0);
    try std.testing.expect(boundary.right - boundary.left >= 71.0);
}

test "center shifting respects extent budget" {
    var centers = [_]f64{ 10, 30 };
    const sizes = [_]NodeSize{
        .{ .width = 10, .height = 10 },
        .{ .width = 10, .height = 10 },
    };

    shiftCentersRightWithinBudget(centers[0..], sizes[0..], 4, 40);
    try std.testing.expectEqual(@as(f64, 14), centers[0]);
    try std.testing.expectEqual(@as(f64, 34), centers[1]);

    shiftCentersRightWithinBudget(centers[0..], sizes[0..], 10, 42);
    try std.testing.expectEqual(@as(f64, 17), centers[0]);
    try std.testing.expectEqual(@as(f64, 37), centers[1]);
}

test "layered layout uses DOT edge weight as a coordinate hint" {
    const allocator = std.testing.allocator;
    var weighted = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=TB];
        \\  left -> child [weight=1];
        \\  right -> child [weight=8];
        \\}
    );
    defer weighted.deinit();
    var balanced = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=TB];
        \\  left -> child [weight=1];
        \\  right -> child [weight=1];
        \\}
    );
    defer balanced.deinit();

    var weighted_layout = try layoutLayered(allocator, &weighted, .{});
    defer weighted_layout.deinit();
    var balanced_layout = try layoutLayered(allocator, &balanced, .{});
    defer balanced_layout.deinit();

    const weighted_child = weighted.node_index.get("child").?;
    const weighted_right = weighted.node_index.get("right").?;
    const balanced_child = balanced.node_index.get("child").?;
    const balanced_right = balanced.node_index.get("right").?;
    const weighted_distance = @abs(weighted_layout.nodes[weighted_child].center.x - weighted_layout.nodes[weighted_right].center.x);
    const balanced_distance = @abs(balanced_layout.nodes[balanced_child].center.x - balanced_layout.nodes[balanced_right].center.x);
    try std.testing.expect(weighted_distance < balanced_distance);
}

test "layered layout honors DOT ordering hints for edge declaration order" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=TB, ordering=out];
        \\  source -> c;
        \\  source -> a;
        \\  source -> b;
        \\  { rank=same; a; b; c; }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    try std.testing.expect(layout.nodes[c].center.x < layout.nodes[a].center.x);
    try std.testing.expect(layout.nodes[a].center.x < layout.nodes[b].center.x);

    var incoming = try parseDot(allocator,
        \\digraph G {
        \\  sink [ordering=in];
        \\  c -> sink;
        \\  a -> sink;
        \\  b -> sink;
        \\  { rank=same; a; b; c; }
        \\}
    );
    defer incoming.deinit();
    var incoming_layout = try layoutLayered(allocator, &incoming, .{});
    defer incoming_layout.deinit();
    const ia = incoming.node_index.get("a").?;
    const ib = incoming.node_index.get("b").?;
    const ic = incoming.node_index.get("c").?;
    try std.testing.expect(incoming_layout.nodes[ic].center.x < incoming_layout.nodes[ia].center.x);
    try std.testing.expect(incoming_layout.nodes[ia].center.x < incoming_layout.nodes[ib].center.x);
}

test "DOT parser and SVG renderer support common Graphviz node shapes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  start [label="Start", shape=triangle];
        \\  decision [label="Valid?", shape=diamond, color="#f59e0b"];
        \\  io [label="Write", shape=parallelogram];
        \\  trap [label="Trap", shape=trapezoid];
        \\  invtrap [label="InvTrap", shape=invtrapezoid];
        \\  done [label="Done", shape=hexagon];
        \\  stop [label="Stop", shape=octagon];
        \\  fail [label="Fail", shape=invtriangle];
        \\  note [label="No box", shape=plaintext];
        \\  start -> decision -> io -> trap -> invtrap -> done -> stop;
        \\  decision -> fail;
        \\  note -> decision [constraint=false];
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(Shape.triangle, graph.nodes.items[graph.node_index.get("start").?].shape);
    try std.testing.expectEqual(Shape.diamond, graph.nodes.items[graph.node_index.get("decision").?].shape);
    try std.testing.expectEqual(Shape.parallelogram, graph.nodes.items[graph.node_index.get("io").?].shape);
    try std.testing.expectEqual(Shape.trapezium, graph.nodes.items[graph.node_index.get("trap").?].shape);
    try std.testing.expectEqual(Shape.invtrapezium, graph.nodes.items[graph.node_index.get("invtrap").?].shape);
    try std.testing.expectEqual(Shape.hexagon, graph.nodes.items[graph.node_index.get("done").?].shape);
    try std.testing.expectEqual(Shape.octagon, graph.nodes.items[graph.node_index.get("stop").?].shape);
    try std.testing.expectEqual(Shape.invtriangle, graph.nodes.items[graph.node_index.get("fail").?].shape);
    try std.testing.expectEqual(Shape.plaintext, graph.nodes.items[graph.node_index.get("note").?].shape);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const note = graph.node_index.get("note").?;
    try std.testing.expect(layout.nodes[note].width < 120);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(countSubstrings(svg, "<polygon") >= 8);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Start") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Valid?") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "InvTrap") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "No box") != null);
}

test "DOT parser and SVG renderer support additional Graphviz polygon node shapes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  sq [label="Square", shape=square];
        \\  oval [label="Oval", shape=oval];
        \\  house [label="House", shape=house];
        \\  invhouse [label="InvHouse", shape=invhouse];
        \\  pent [label="Pent", shape=pentagon];
        \\  sept [label="Sept", shape=septagon];
        \\  two [label="Two", shape=doubleoctagon];
        \\  three [label="Three", shape=tripleoctagon];
        \\  sq -> oval -> house -> invhouse -> pent -> sept -> two -> three;
        \\}
    );
    defer graph.deinit();

    const sq = graph.node_index.get("sq").?;
    const oval = graph.node_index.get("oval").?;
    try std.testing.expectEqual(Shape.square, graph.nodes.items[sq].shape);
    try std.testing.expectEqual(Shape.ellipse, graph.nodes.items[oval].shape);
    try std.testing.expectEqual(Shape.house, graph.nodes.items[graph.node_index.get("house").?].shape);
    try std.testing.expectEqual(Shape.invhouse, graph.nodes.items[graph.node_index.get("invhouse").?].shape);
    try std.testing.expectEqual(Shape.pentagon, graph.nodes.items[graph.node_index.get("pent").?].shape);
    try std.testing.expectEqual(Shape.septagon, graph.nodes.items[graph.node_index.get("sept").?].shape);
    try std.testing.expectEqual(Shape.doubleoctagon, graph.nodes.items[graph.node_index.get("two").?].shape);
    try std.testing.expectEqual(Shape.tripleoctagon, graph.nodes.items[graph.node_index.get("three").?].shape);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expect(@abs(layout.nodes[sq].width - layout.nodes[sq].height) < 0.01);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(countSubstrings(svg, "<polygon") >= 9);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<ellipse") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "InvHouse") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Three") != null);
}

test "DOT parser and SVG renderer support special Graphviz node shapes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  note [label="Note", shape=note, style="filled,dashed"];
        \\  tab [label="Tab", shape=tab];
        \\  folder [label="Folder", shape=folder];
        \\  box3d [label="Box3D", shape=box3d];
        \\  component [label="Component", shape=component];
        \\  underline [label="Underline", shape=underline];
        \\  cylinder [label="Cylinder", shape=cylinder];
        \\  note -> tab -> folder -> box3d -> component -> underline -> cylinder;
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(Shape.note, graph.nodes.items[graph.node_index.get("note").?].shape);
    try std.testing.expectEqual(Shape.tab, graph.nodes.items[graph.node_index.get("tab").?].shape);
    try std.testing.expectEqual(Shape.folder, graph.nodes.items[graph.node_index.get("folder").?].shape);
    try std.testing.expectEqual(Shape.box3d, graph.nodes.items[graph.node_index.get("box3d").?].shape);
    try std.testing.expectEqual(Shape.component, graph.nodes.items[graph.node_index.get("component").?].shape);
    try std.testing.expectEqual(Shape.underline, graph.nodes.items[graph.node_index.get("underline").?].shape);
    try std.testing.expectEqual(Shape.cylinder, graph.nodes.items[graph.node_index.get("cylinder").?].shape);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-dasharray=\"8,5\"") != null);
    try std.testing.expect(countSubstrings(svg, "<path") >= 12);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<rect") != null);
    try std.testing.expect(svgPathCommandCount(svg, 'C') != 0);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Component") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Underline") != null);
}

test "DOT parser and SVG renderer support Graphviz M shapes star and egg" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  egg [label="Egg", shape=egg];
        \\  star [label="Star", shape=star];
        \\  md [label="Mdiamond", shape=Mdiamond];
        \\  ms [label="Msquare", shape=Msquare];
        \\  mc [label="Mcircle", shape=Mcircle];
        \\  egg -> star -> md -> ms -> mc;
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(Shape.egg, graph.nodes.items[graph.node_index.get("egg").?].shape);
    try std.testing.expectEqual(Shape.star, graph.nodes.items[graph.node_index.get("star").?].shape);
    try std.testing.expectEqual(Shape.mdiamond, graph.nodes.items[graph.node_index.get("md").?].shape);
    try std.testing.expectEqual(Shape.msquare, graph.nodes.items[graph.node_index.get("ms").?].shape);
    try std.testing.expectEqual(Shape.mcircle, graph.nodes.items[graph.node_index.get("mc").?].shape);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const ms = graph.node_index.get("ms").?;
    const mc = graph.node_index.get("mc").?;
    try std.testing.expect(@abs(layout.nodes[ms].width - layout.nodes[ms].height) < 0.01);
    try std.testing.expect(@abs(layout.nodes[mc].width - layout.nodes[mc].height) < 0.01);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Egg") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Star") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<circle") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon") != null);
    try std.testing.expect(countSubstrings(svg, "fill=\"none\" stroke=") >= 8);
    try std.testing.expect(svgPathCommandCount(svg, 'C') != 0);
}

test "Graphviz M shapes use compact default sizing" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  start [shape=Mdiamond];
        \\  end [shape=Msquare];
        \\  mc [shape=Mcircle];
        \\  long [shape=Msquare, label="long label"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const end = graph.node_index.get("end").?;
    const badge = graph.node_index.get("mc").?;
    const long = graph.node_index.get("long").?;
    try std.testing.expect(layout.nodes[end].width <= 36.1);
    try std.testing.expect(layout.nodes[badge].width <= 36.1);
    try std.testing.expect(layout.nodes[long].width > layout.nodes[end].width);
}

test "DOT parser and SVG renderer support parameterized Graphviz polygon shape" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  pent [label="five", shape=polygon, sides=5, orientation=18];
        \\  reg [label="regular", shape=polygon, sides=6, regular=true, peripheries=2];
        \\  skewed [label="skewed", shape=polygon, sides=4, skew=0.6, distortion=-0.25];
        \\  pent -> reg -> skewed;
        \\}
    );
    defer graph.deinit();

    const pent = graph.node_index.get("pent").?;
    const reg = graph.node_index.get("reg").?;
    const skewed = graph.node_index.get("skewed").?;
    try std.testing.expectEqual(Shape.polygon, graph.nodes.items[pent].shape);
    try std.testing.expectEqual(Shape.polygon, graph.nodes.items[reg].shape);
    try std.testing.expectEqual(Shape.polygon, graph.nodes.items[skewed].shape);
    try std.testing.expectEqual(@as(usize, 5), customPolygonFromAttrs(graph.nodes.items[pent].attrs.items).sides);
    try std.testing.expect(customPolygonFromAttrs(graph.nodes.items[reg].attrs.items).regular);
    try std.testing.expect(customPolygonFromAttrs(graph.nodes.items[skewed].attrs.items).skew > 0);
    try std.testing.expect(customPolygonFromAttrs(graph.nodes.items[skewed].attrs.items).distortion < 0);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expect(@abs(layout.nodes[reg].width - layout.nodes[reg].height) < 0.01);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(countSubstrings(svg, "<polygon") >= 4);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "five") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "skewed") != null);
}

test "DOT doublecircle shape renders as two circle peripheries" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  accept [shape=doublecircle, label="accept"];
        \\}
    );
    defer graph.deinit();

    const accept = graph.node_index.get("accept").?;
    try std.testing.expectEqual(Shape.doublecircle, graph.nodes.items[accept].shape);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(countSubstrings(svg, "<circle") >= 2);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\"") != null);
}

test "DOT point shape renders as small unlabeled filled point" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  p [shape=point, label="hidden"];
        \\}
    );
    defer graph.deinit();

    const p = graph.node_index.get("p").?;
    try std.testing.expectEqual(Shape.point, graph.nodes.items[p].shape);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expect(layout.nodes[p].width <= 12.0);
    try std.testing.expect(layout.nodes[p].height <= 12.0);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<circle") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "hidden") == null);
}

test "DOT record and Mrecord nodes render field separators" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  node [shape=record];
        \\  entity [label="<id> id|name|email"];
        \\  rounded [shape=Mrecord, label="<port> left|right"];
        \\  entity -> rounded;
        \\}
    );
    defer graph.deinit();

    const entity = graph.node_index.get("entity").?;
    const rounded = graph.node_index.get("rounded").?;
    try std.testing.expectEqual(Shape.record, graph.nodes.items[entity].shape);
    try std.testing.expectEqual(Shape.mrecord, graph.nodes.items[rounded].shape);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expect(layout.nodes[entity].height >= 56);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">id</text>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">name</text>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">email</text>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">port") == null);
    try std.testing.expect(countSubstrings(svg, "<path d=\"M ") >= 2);
    try std.testing.expect(std.mem.indexOf(u8, svg, "rx=\"10.0\"") != null);
}

test "DOT record field ports route edge endpoints to fields" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  customer [shape=Mrecord,label="<id> Customer|<orders> orders[]"];
        \\  order [shape=record,label="<id> Order|total"];
        \\  customer:orders -> order:id;
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 1), graph.edges.items.len);
    try std.testing.expectEqualStrings("orders", graph.edges.items[0].tail_record_port.?);
    try std.testing.expectEqualStrings("id", graph.edges.items[0].head_record_port.?);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const edge_item = graph.edges.items[0];
    const route = edgeRouteForEdge(&graph, &layout, edge_item, layout.rankdir, 0);
    const tail_rect = recordFieldRect(graph.nodes.items[edge_item.from].label, layout.nodes[edge_item.from], "orders").?;
    const head_rect = recordFieldRect(graph.nodes.items[edge_item.to].label, layout.nodes[edge_item.to], "id").?;

    try std.testing.expect(route.start.x >= tail_rect.x);
    try std.testing.expect(route.start.x <= tail_rect.x + tail_rect.width);
    try std.testing.expect(route.start.y >= tail_rect.y);
    try std.testing.expect(route.start.y <= tail_rect.y + tail_rect.height);
    try std.testing.expect(route.end.x >= head_rect.x);
    try std.testing.expect(route.end.x <= head_rect.x + head_rect.width);
    try std.testing.expect(route.end.y >= head_rect.y);
    try std.testing.expect(route.end.y <= head_rect.y + head_rect.height);
}

test "DOT compass ports route edge endpoints to requested sides" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a:e -> b:w;
        \\  customer [shape=Mrecord,label="<id> Customer|<orders> orders[]"];
        \\  order [shape=record,label="<id> Order|total"];
        \\  customer:orders:e -> order:id:w;
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(CompassPort.east, graph.edges.items[0].tail_port);
    try std.testing.expectEqual(CompassPort.west, graph.edges.items[0].head_port);
    try std.testing.expectEqualStrings("orders", graph.edges.items[1].tail_record_port.?);
    try std.testing.expectEqual(CompassPort.east, graph.edges.items[1].tail_port);
    try std.testing.expectEqualStrings("id", graph.edges.items[1].head_record_port.?);
    try std.testing.expectEqual(CompassPort.west, graph.edges.items[1].head_port);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const first = graph.edges.items[0];
    const first_route = edgeRouteForEdge(&graph, &layout, first, layout.rankdir, 0);
    try std.testing.expectEqual(layout.nodes[first.from].center.x + layout.nodes[first.from].width / 2.0, first_route.start.x);
    try std.testing.expectEqual(layout.nodes[first.to].center.x - layout.nodes[first.to].width / 2.0, first_route.end.x);

    const record_edge = graph.edges.items[1];
    const record_route = edgeRouteForEdge(&graph, &layout, record_edge, layout.rankdir, 0);
    const tail_rect = recordFieldRect(graph.nodes.items[record_edge.from].label, layout.nodes[record_edge.from], "orders").?;
    const head_rect = recordFieldRect(graph.nodes.items[record_edge.to].label, layout.nodes[record_edge.to], "id").?;
    try std.testing.expectEqual(tail_rect.x + tail_rect.width, record_route.start.x);
    try std.testing.expectEqual(head_rect.x, record_route.end.x);
}

test "DOT nested record groups alternate field orientation" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  customer [shape=Mrecord,label="<id> Customer|{<name> name|<email> email|<status> status}|<orders> orders[]"];
        \\  order [shape=record,label="<id> Order|total"];
        \\  customer:email:e -> order:id:w;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const customer = graph.node_index.get("customer").?;
    const email_rect = recordFieldRect(graph.nodes.items[customer].label, layout.nodes[customer], "email").?;
    const status_rect = recordFieldRect(graph.nodes.items[customer].label, layout.nodes[customer], "status").?;
    try std.testing.expectEqual(email_rect.x, status_rect.x);
    try std.testing.expect(email_rect.y < status_rect.y);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">email</text>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">status</text>") != null);
    try std.testing.expect(svgPathCommandCount(svg, 'L') >= 4);
}

test "DOT compound edges clip to cluster boundaries" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  compound=true;
        \\  subgraph cluster_left {
        \\    label="Left";
        \\    a -> b;
        \\  }
        \\  subgraph cluster_right {
        \\    label="Right";
        \\    c -> d;
        \\  }
        \\  b -> c [ltail=cluster_left, lhead=cluster_right, label="handoff"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const edge_item = graph.edges.items[2];
    try std.testing.expectEqualStrings("cluster_left", edge_item.ltail.?);
    try std.testing.expectEqualStrings("cluster_right", edge_item.lhead.?);

    const route = edgeRouteForEdge(&graph, &layout, edge_item, layout.rankdir, 0);
    const left = clusterRect(&graph, &layout, "cluster_left").?;
    const right = clusterRect(&graph, &layout, "cluster_right").?;
    try std.testing.expect(pointOnRectBoundary(left, route.start));
    try std.testing.expect(pointOnRectBoundary(right, route.end));

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    const path_points = svgPathStartEnd(svg, "b-&gt;c") orelse return error.MissingCompoundPath;
    try std.testing.expect(pointOnRectBoundary(left, path_points.start));
    try std.testing.expect(pointNearRectBoundary(right, path_points.end, 8.0));
}

test "DOT ltail and lhead are ignored unless graph compound is true" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_left {
        \\    a -> b;
        \\  }
        \\  subgraph cluster_right {
        \\    c -> d;
        \\  }
        \\  b -> c [ltail=cluster_left, lhead=cluster_right];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const edge_item = graph.edges.items[2];
    const route = edgeRouteForEdge(&graph, &layout, edge_item, layout.rankdir, 0);
    const left = clusterRect(&graph, &layout, "cluster_left").?;
    const right = clusterRect(&graph, &layout, "cluster_right").?;
    try std.testing.expect(!pointOnRectBoundary(left, route.start));
    try std.testing.expect(!pointOnRectBoundary(right, route.end));
    try std.testing.expect(!graphCompoundEnabled(&graph));
}

test "DOT samehead and sametail route edges through shared ports" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a -> hub [samehead=h];
        \\  b -> hub [samehead=h];
        \\  hub -> x [sametail=t];
        \\  hub -> y [sametail=t];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const head_a = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], layout.rankdir, 0);
    const head_b = edgeRouteForEdge(&graph, &layout, graph.edges.items[1], layout.rankdir, 0);
    try std.testing.expect(distanceBetween(head_a.end, head_b.end) <= 0.01);

    const tail_x = edgeRouteForEdge(&graph, &layout, graph.edges.items[2], layout.rankdir, 0);
    const tail_y = edgeRouteForEdge(&graph, &layout, graph.edges.items[3], layout.rankdir, 0);
    try std.testing.expect(distanceBetween(tail_x.start, tail_y.start) <= 0.01);
}

test "layout honors DOT ranksep and nodesep graph spacing attributes" {
    const allocator = std.testing.allocator;
    var default_graph = try parseDot(allocator,
        \\digraph G {
        \\  a -> b;
        \\  a -> c;
        \\}
    );
    defer default_graph.deinit();
    var spaced_graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [ranksep=3.0, nodesep=2.0];
        \\  a -> b;
        \\  a -> c;
        \\}
    );
    defer spaced_graph.deinit();

    var default_layout = try layoutLayered(allocator, &default_graph, .{});
    defer default_layout.deinit();
    var spaced_layout = try layoutLayered(allocator, &spaced_graph, .{});
    defer spaced_layout.deinit();

    const default_a = default_graph.node_index.get("a").?;
    const default_b = default_graph.node_index.get("b").?;
    const default_c = default_graph.node_index.get("c").?;
    const spaced_a = spaced_graph.node_index.get("a").?;
    const spaced_b = spaced_graph.node_index.get("b").?;
    const spaced_c = spaced_graph.node_index.get("c").?;

    const default_rank_delta = @abs(default_layout.nodes[default_b].center.y - default_layout.nodes[default_a].center.y);
    const spaced_rank_delta = @abs(spaced_layout.nodes[spaced_b].center.y - spaced_layout.nodes[spaced_a].center.y);
    const default_node_delta = @abs(default_layout.nodes[default_c].center.x - default_layout.nodes[default_b].center.x);
    const spaced_node_delta = @abs(spaced_layout.nodes[spaced_c].center.x - spaced_layout.nodes[spaced_b].center.x);

    try std.testing.expect(spaced_rank_delta > default_rank_delta);
    try std.testing.expect(spaced_node_delta > default_node_delta);
}

test "layout honors DOT ranksep equally center spacing" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [ranksep="1.0 equally"];
        \\  a [label="short"];
        \\  b [label="tall\nnode\nlabel"];
        \\  c [label="short"];
        \\  a -> b -> c;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const ab = @abs(layout.nodes[b].center.y - layout.nodes[a].center.y);
    const bc = @abs(layout.nodes[c].center.y - layout.nodes[b].center.y);
    try std.testing.expect(@abs(ab - bc) < 0.01);
}

test "layout honors DOT node width height and fixedsize attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  min_sized [label="small", width=3.0, height=1.5];
        \\  fixed [label="this label is intentionally much wider than the box", width=1.0, height=0.5, fixedsize=true];
        \\  shape_fixed [label="an even longer label than the fixed circle", shape=circle, width=0.5, height=0.5, fixedsize=shape];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const min_sized = graph.node_index.get("min_sized").?;
    const fixed = graph.node_index.get("fixed").?;
    const shape_fixed = graph.node_index.get("shape_fixed").?;
    try std.testing.expect(layout.nodes[min_sized].width >= 216);
    try std.testing.expect(layout.nodes[min_sized].height >= 108);
    try std.testing.expect(@abs(layout.nodes[fixed].width - 72.0) < 0.01);
    try std.testing.expect(@abs(layout.nodes[fixed].height - 36.0) < 0.01);
    try std.testing.expect(layout.nodes[shape_fixed].width > 72.0);
    try std.testing.expect(layout.nodes[shape_fixed].height >= 36.0);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "an even longer label than the fixed circle") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "r=\"18.0\" fill=\"none\" stroke=\"black\"") != null);
}

test "color parser accepts common DOT named colors" {
    try std.testing.expectEqual(Rgba{ 211, 211, 211, 255 }, parseHexColor("lightgrey").?);
    try std.testing.expectEqual(Rgba{ 128, 128, 128, 255 }, parseHexColor("gray").?);
    try std.testing.expectEqual(Rgba{ 255, 0, 0, 255 }, parseHexColor("red").?);
    try std.testing.expectEqual(Rgba{ 170, 187, 204, 255 }, parseHexColor("#abc").?);
    try std.testing.expectEqual(Rgba{ 0, 0, 0, 0 }, parseHexColor("transparent").?);
}
