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

pub const LayoutOptions = struct {
    node_width: f64 = 54,
    node_height: f64 = 36,
    rank_gap: f64 = 36,
    node_gap: f64 = 36,
    margin: f64 = 16,
    margin_y: f64 = 8,
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

fn freeEdgeWaypoints(allocator: std.mem.Allocator, edge_waypoints: []EdgeWaypoints) void {
    for (edge_waypoints) |waypoints| allocator.free(waypoints.points);
}

pub fn layoutLayered(allocator: std.mem.Allocator, graph: *const Graph, options: LayoutOptions) !Layout {
    const effective_options = layoutOptionsWithGraphAttrs(options, graph);
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
    for (sizes, 0..) |size, id| axis_sizes[id] = orientSizeForLayout(size, graph.rankdir);
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
    var final_virtual_positions = try computeVirtualPositions(allocator, &virtual_levels, graph, axis_sizes, effective_options.node_gap, centers);
    defer final_virtual_positions.deinit();
    applyVirtualRealPositionsExceptGroups(graph, &virtual_levels, &final_virtual_positions, centers);
    normalizeCenters(centers, axis_sizes);

    var total_along: f64 = 0;
    for (centers, 0..) |center, id| total_along = @max(total_along, center + axis_sizes[id].width / 2.0);
    total_along = @max(total_along, virtualPositionsExtent(&virtual_levels, &final_virtual_positions, axis_sizes, graph));

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
        const center = orientPoint(graph.rankdir, centers[id], depth, total_depth, effective_options.margin, effective_options.margin_y);
        nodes[id] = .{ .center = center, .width = sizes[id].width, .height = sizes[id].height };
    }
    @memcpy(layout_ranks, ranks);
    computeClusterLayouts(graph, nodes, cluster_layouts);
    try computeEdgeWaypoints(allocator, graph, nodes, ranks, rank_depths, layout_rank_heights, total_depth, effective_options.margin, effective_options.margin_y, edge_waypoints, &virtual_levels, &final_virtual_positions);

    const along_margin = if (graph.rankdir == .LR or graph.rankdir == .RL) effective_options.margin_y else effective_options.margin;
    const depth_margin = if (graph.rankdir == .LR or graph.rankdir == .RL) effective_options.margin else effective_options.margin_y;
    const base_along = total_along + along_margin * 2.0;
    const base_depth = total_depth + depth_margin * 2.0;
    return .{
        .allocator = allocator,
        .nodes = nodes,
        .clusters = cluster_layouts,
        .edge_waypoints = edge_waypoints,
        .ranks = layout_ranks,
        .rank_depths = rank_depths,
        .rank_heights = layout_rank_heights,
        .margin = effective_options.margin,
        .margin_x = effective_options.margin,
        .margin_y = effective_options.margin_y,
        .width = if (graph.rankdir == .LR or graph.rankdir == .RL) base_depth else base_along,
        .height = if (graph.rankdir == .LR or graph.rankdir == .RL) base_along else base_depth,
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
    computeClusterLayouts(graph, nodes, cluster_layouts);
    return .{
        .allocator = allocator,
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
    _ = allocator;

    for (0..passes) |_| {
        var rank: usize = 1;
        while (rank < virtual_levels.levels.len) : (rank += 1) {
            orderVirtualLevelByMedian(graph, virtual_levels, ranks, rank, true);
            orderVirtualLevelBlocksByMedian(graph, virtual_levels, ranks, rank, true);
        }
        rank = virtual_levels.levels.len - 1;
        while (rank > 0) : (rank -= 1) {
            orderVirtualLevelByMedian(graph, virtual_levels, ranks, rank - 1, false);
            orderVirtualLevelBlocksByMedian(graph, virtual_levels, ranks, rank - 1, false);
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
    if (edge_item.ltail == null and edge_item.lhead == null) return null;
    if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) return null;
    if (from_cluster == null and to_cluster == null) return null;
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
            while (i + 1 < level.items.len) : (i += 1) {
                if (virtualSwapCrossesClusterBlock(graph, ranks, rank, level.items[i], level.items[i + 1])) continue;
                const before = virtualCrossingScoreAroundLevel(graph, virtual_levels, ranks, rank);
                std.mem.swap(VirtualNode, &level.items[i], &level.items[i + 1]);
                const after = virtualCrossingScoreAroundLevel(graph, virtual_levels, ranks, rank);
                if (after < before) {
                    changed = true;
                } else {
                    std.mem.swap(VirtualNode, &level.items[i], &level.items[i + 1]);
                }
            }
        }
        if (!changed) break;
    }
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
            width = @max(36.0, text_width + options.node_padding_x * 2.4 + margin.x * 2.0);
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
        width = @max(width, @as(f64, @floatFromInt(table.cols * @max(table.max_cell_len, 1))) * options.label_char_width * font_scale + table.cell_padding * 2.0 * @as(f64, @floatFromInt(table.cols)) + table.cell_spacing * @as(f64, @floatFromInt(table.cols + 1)));
        height = @max(height, @as(f64, @floatFromInt(table.rows)) * options.label_line_height * 1.6 * font_scale + table.cell_padding * 2.0 * @as(f64, @floatFromInt(table.rows)) + table.cell_spacing * @as(f64, @floatFromInt(table.rows + 1)));
    }
    applyNodeSizeAttrs(node_item, &width, &height);
    return .{ .width = width, .height = height };
}

fn applyNodeSizeAttrs(node_item: Node, width: *f64, height: *f64) void {
    const fixed = if (attrValue(node_item.attrs.items, "fixedsize")) |value| parseBool(value) orelse false else false;
    if (attrValue(node_item.attrs.items, "width")) |value| {
        const attr_width = parseInchDimension(value) orelse width.*;
        width.* = if (fixed) attr_width else @max(width.*, attr_width);
    }
    if (attrValue(node_item.attrs.items, "height")) |value| {
        const attr_height = parseInchDimension(value) orelse height.*;
        height.* = if (fixed) attr_height else @max(height.*, attr_height);
    }
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
    return switch (rankdir) {
        .TB, .BT => size,
        .LR, .RL => .{ .width = size.height, .height = size.width },
    };
}

fn computeClusterLayouts(graph: *const Graph, nodes: []const NodeLayout, clusters: []ClusterLayout) void {
    const pad_x: f64 = 12;
    const pad_y: f64 = 12;
    const label_band: f64 = 18;
    const child_gap: f64 = 12;
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
        const label_min_width = @as(f64, @floatFromInt(labelMaxLineLen(cluster.label))) * 8.0 + pad_x * 2.0;
        var x = min_x - pad_x;
        var width = (max_x - min_x) + pad_x * 2.0;
        const height = (max_y - min_y) + pad_y * 2.0 + label_band;
        if (width < label_min_width) {
            const extra = label_min_width - width;
            x -= extra / 2.0;
            width = label_min_width;
        }
        const y = min_y - pad_y - label_band;
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
                    ranks[node_id] = target_rank;
                    changed = true;
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
        if (!edge_item.constraint) continue;
        if (edge_item.id >= acyclic_edge.len or !acyclic_edge[edge_item.id]) continue;
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
            if (after < before and rankAssignmentFeasible(graph, ranks, acyclic_edge)) {
                changed = true;
            } else {
                ranks[node_id] = current_rank;
            }
        }
        if (!changed) break;
    }
}

fn incidentRankSpanCost(graph: *const Graph, ranks: []const usize, acyclic_edge: []const bool, node_id: NodeId, candidate_rank: usize) f64 {
    var cost: f64 = 0;
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        if (edge_item.id >= acyclic_edge.len or !acyclic_edge[edge_item.id]) continue;
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
        if (!edge_item.constraint) continue;
        if (edge_item.id >= acyclic_edge.len or !acyclic_edge[edge_item.id]) continue;
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        cost += rankSpanCost(ranks[edge_item.from], ranks[edge_item.to], edge_item.weight);
    }
    return cost;
}

fn rankAssignmentFeasible(graph: *const Graph, ranks: []const usize, acyclic_edge: []const bool) bool {
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        if (edge_item.id >= acyclic_edge.len or !acyclic_edge[edge_item.id]) continue;
        if (edge_item.from >= ranks.len or edge_item.to >= ranks.len) continue;
        const min_len = @max(edge_item.min_len, 1);
        if (ranks[edge_item.to] < ranks[edge_item.from] + min_len) return false;
    }
    return true;
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
        }
    }
    return @max(max_len, current);
}

fn isHtmlLabelSpace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

const HtmlToken = union(enum) {
    char: u8,
    newline,
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
                const tag = htmlTagName(self.text[start .. start + close_rel]);
                self.index = start + close_rel + 1;
                if (std.ascii.eqlIgnoreCase(tag, "br")) return .newline;
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
    };
}

fn htmlIntAttr(tag: []const u8, name: []const u8, fallback: usize) usize {
    const value = htmlAttrValue(tag, name) orelse return fallback;
    return std.fmt.parseInt(usize, value, 10) catch fallback;
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
            orderLevelByMedian(graph, ranks, &levels[rank], positions, median_positions, true);
        }

        rank = levels.len - 1;
        while (rank > 0) : (rank -= 1) {
            buildPositionMap(positions, levels[rank].items);
            orderLevelByMedian(graph, ranks, &levels[rank - 1], positions, median_positions, false);
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
            while (i + 1 < levels[rank].items.len) : (i += 1) {
                const before = crossingScoreAroundLevel(graph, levels, ranks, rank);
                std.mem.swap(NodeId, &levels[rank].items[i], &levels[rank].items[i + 1]);
                const after = crossingScoreAroundLevel(graph, levels, ranks, rank);
                if (after < before) {
                    changed = true;
                } else {
                    std.mem.swap(NodeId, &levels[rank].items[i], &levels[rank].items[i + 1]);
                }
            }
        }
        if (!changed) break;
    }
}

fn crossingScoreAroundLevel(graph: *const Graph, levels: []const std.ArrayList(NodeId), ranks: []const usize, rank: usize) usize {
    var score: usize = 0;
    if (rank > 0) score += countLayerCrossingsWithDummies(graph, levels, ranks, rank - 1);
    if (rank + 1 < levels.len) score += countLayerCrossingsWithDummies(graph, levels, ranks, rank);
    return score;
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
                longEdgeDummyAlongFromNodes(nodes, ranks, edge_item, graph.rankdir, rank) orelse
                continue;
            const depth = rankDepthCenterFrom(rank_depths, rank_heights, rank);
            points[i] = .{
                .rank = rank,
                .point = orientPoint(graph.rankdir, along, depth, total_depth, margin_x, margin_y),
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
    var prev = level[0];
    centers[prev] = @max(centers[prev], sizes[prev].width / 2.0);
    for (level[1..]) |id| {
        const min_center = centers[prev] + sizes[prev].width / 2.0 + gap + sizes[id].width / 2.0;
        centers[id] = @max(centers[id], min_center);
        prev = id;
    }
}

fn normalizeCenters(centers: []f64, sizes: []const NodeSize) void {
    if (centers.len == 0) return;
    var min_left = std.math.floatMax(f64);
    for (centers, 0..) |center, id| min_left = @min(min_left, center - sizes[id].width / 2.0);
    if (min_left == 0 or min_left == std.math.floatMax(f64)) return;
    for (centers) |*center| center.* -= min_left;
}

fn orientPoint(rankdir: RankDir, along: f64, depth: f64, total_depth: f64, margin_x: f64, margin_y: f64) Point {
    return switch (rankdir) {
        .TB => .{ .x = margin_x + along, .y = margin_y + depth },
        .BT => .{ .x = margin_x + along, .y = total_depth + margin_y * 2.0 - (margin_y + depth) },
        .LR => .{ .x = margin_x + depth, .y = margin_y + along },
        .RL => .{ .x = total_depth + margin_x * 2.0 - (margin_x + depth), .y = margin_y + along },
    };
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
    background: []const u8 = "#ffffff",
    font_family: []const u8 = default_svg_font_family,
    show_title: bool = true,
};

pub fn renderSvg(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, options: SvgOptions) Io.Writer.Error!void {
    const edge_routing = svgEdgeRoutingMode(graph);
    const concentrate = graphConcentrateEnabled(graph);
    const background = attrValue(graph.attrs.items, "bgcolor") orelse options.background;
    try writer.print(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{d:.0}\" height=\"{d:.0}\" viewBox=\"0 0 {d:.0} {d:.0}\">\n",
        .{ layout.width, layout.height, layout.width, layout.height },
    );
    try writer.writeAll("<title>");
    try writeXmlEscaped(writer, graph.name);
    try writer.writeAll("</title>\n");
    try writer.print("<rect width=\"100%\" height=\"100%\" fill=\"{s}\"/>\n", .{background});
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
        try writer.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"{s}\" font-family=\"{s}\" font-size=\"{d:.1}\" fill=\"{s}\">", .{ title_x, title_y, text_anchor, title_font, title_size, title_color });
        try writeXmlEscaped(writer, graph_label);
        try writer.writeAll("</text>\n");
    }
    if (graph.directed) {
        try writer.writeAll("<defs>\n");
        for (graph.edges.items) |edge_item| {
            if (concentrate and isConcentratedDuplicateEdge(graph, edge_item.id)) continue;
            const visual = resolveEdgeVisual(edge_item);
            if (visual.marker_end != .none) try writeSvgMarkerDef(writer, edge_item.id, "head", visual.marker_end, visual.stroke, visual.marker_scale);
            if (visual.marker_start != .none) try writeSvgMarkerDef(writer, edge_item.id, "tail", visual.marker_start, visual.stroke, visual.marker_scale);
        }
        try writer.writeAll("</defs>\n");
    }

    try renderSvgClusters(writer, graph, layout);

    try writer.writeAll("<g class=\"edges\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\">\n");
    for (graph.edges.items) |edge_item| {
        if (concentrate and isConcentratedDuplicateEdge(graph, edge_item.id)) continue;
        const visual = resolveEdgeVisual(edge_item);
        if (visual.hidden) continue;
        const edge_wrap = try writeSvgInteractiveOpen(writer, edge_item.attrs.items);
        if (edge_wrap == .none) try writeSvgEdgeTitle(writer, graph, edge_item);
        if (edge_item.from == edge_item.to) {
            const route = selfLoopRoute(layout.nodes[edge_item.from]);
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
            try writeSvgMarkerAttrs(writer, graph.directed, edge_item.id, visual);
            try writer.writeAll("/>\n");
            if (edge_item.label) |label| {
                try renderSvgTextBlock(writer, label, route.label.x, route.label.y, visual.font_size, visual.font_color, visual.font_family, true, true);
            }
            try renderSvgExtraEdgeLabels(writer, edge_item, route, visual);
            try writeSvgInteractiveClose(writer, edge_wrap);
            continue;
        }

        const offset = parallelEdgeOffset(graph, edge_item.id);
        const route = edgeRouteForEdge(graph, layout, edge_item, graph.rankdir, offset);
        try writer.writeAll("<path d=\"");
        try writeEdgePath(writer, layout, edge_item, graph.rankdir, offset, route, edge_routing);
        try writer.print("\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{ visual.stroke, visual.width });
        try writeSvgDash(writer, visual.dash);
        try writeSvgMarkerAttrs(writer, graph.directed, edge_item.id, visual);
        try writer.writeAll("/>\n");
        if (edge_item.label) |label| {
            try renderSvgTextBlock(writer, label, route.label.x, route.label.y - 6.0, visual.font_size, visual.font_color, visual.font_family, true, true);
        }
        try renderSvgExtraEdgeLabels(writer, edge_item, route, visual);
        try writeSvgInteractiveClose(writer, edge_wrap);
    }
    try writer.writeAll("</g>\n<g class=\"nodes\">\n");

    for (graph.nodes.items) |node_item| {
        const visual = resolveNodeVisual(node_item);
        if (visual.hidden) continue;
        const l = layout.nodes[node_item.id];
        const node_wrap = try writeSvgInteractiveOpen(writer, node_item.attrs.items);
        if (node_wrap == .none) try writeSvgTitle(writer, node_item.name);
        if (htmlTableMetrics(node_item.label) != null) {
            try renderSvgHtmlTableLabel(writer, node_item.label, l, visual);
            try writeSvgInteractiveClose(writer, node_wrap);
            continue;
        }
        try renderSvgNodeShape(writer, node_item, l, visual, options);
        if (node_item.shape != .record and node_item.shape != .mrecord and node_item.shape != .point) {
            try renderSvgNodeLabel(writer, node_item, l, visual);
        }
        try renderSvgNodeXLabel(writer, node_item, l, visual);
        try writeSvgInteractiveClose(writer, node_wrap);
    }
    try writer.writeAll("</g>\n</svg>\n");
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

const SvgInteractiveWrap = enum {
    none,
    anchor,
    group,
};

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

fn renderSvgNodeLabel(writer: *Io.Writer, node_item: Node, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const margin = nodeMargin(node_item.attrs.items, 0);
    const anchor = nodeLabelAnchor(node_item.attrs.items, layout, margin.x);
    const y = nodeLabelY(node_item.attrs.items, layout, margin.y);
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

fn renderedEdgePathCount(svg: []const u8) usize {
    const start = std.mem.indexOf(u8, svg, "<g class=\"edges\"") orelse return 0;
    const end_rel = std.mem.indexOf(u8, svg[start..], "</g>") orelse return 0;
    return countSubstrings(svg[start .. start + end_rel], "<path d=\"M ");
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
    try writer.writeAll("<g class=\"clusters\">\n");
    var index = graph.clusters.items.len;
    while (index > 0) {
        index -= 1;
        try renderSvgClusterBox(writer, graph.clusters.items[index], layout, index);
    }
    try writer.writeAll("</g>\n");
}

fn renderSvgClusterBox(writer: *Io.Writer, cluster: Cluster, layout: *const Layout, index: usize) Io.Writer.Error!void {
    if (index >= layout.clusters.len) return;
    const box = layout.clusters[index];
    if (box.width <= 0 or box.height <= 0) return;
    const visual = resolveClusterVisual(cluster);
    if (visual.hidden) return;
    try writeSvgTitle(writer, cluster.name);
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
    const label_y = if (label_loc) |value|
        if (std.ascii.eqlIgnoreCase(value, "b")) box.y + box.height - 10.0 else box.y + 18.0
    else
        box.y + 18.0;
    try writer.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"{s}\" font-family=\"{s}\" font-size=\"{d:.1}\" fill=\"{s}\">", .{
        label_x,
        label_y,
        text_anchor,
        visual.font_family,
        visual.font_size,
        visual.font_color,
    });
    try writeXmlEscaped(writer, cluster.label);
    try writer.writeAll("</text>\n");
}

fn renderSvgHtmlTableLabel(writer: *Io.Writer, label: []const u8, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const metrics = htmlTableMetrics(label) orelse return;
    const x = layout.center.x - layout.width / 2.0;
    const y = layout.center.y - layout.height / 2.0;
    const total_spacing_x = metrics.cell_spacing * @as(f64, @floatFromInt(metrics.cols + 1));
    const total_spacing_y = metrics.cell_spacing * @as(f64, @floatFromInt(metrics.rows + 1));
    const cell_w = @max(1, (layout.width - total_spacing_x) / @as(f64, @floatFromInt(metrics.cols)));
    const cell_h = @max(1, (layout.height - total_spacing_y) / @as(f64, @floatFromInt(metrics.rows)));
    const fill = metrics.bg_color orelse visual.fill;

    try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"/>\n", .{
        x,
        y,
        layout.width,
        layout.height,
        visual.radius,
        fill,
        if (metrics.border > 0) visual.stroke else "none",
        metrics.border,
    });

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
            const span_f: f64 = @floatFromInt(colspan);
            const row_span_f: f64 = @floatFromInt(rowspan);
            const cell_x = x + metrics.cell_spacing + @as(f64, @floatFromInt(col_index)) * (cell_w + metrics.cell_spacing);
            const cell_y = y + metrics.cell_spacing + @as(f64, @floatFromInt(row_index)) * (cell_h + metrics.cell_spacing);
            const spanned_w = cell_w * span_f + metrics.cell_spacing * @as(f64, @floatFromInt(colspan - 1));
            const spanned_h = cell_h * row_span_f + metrics.cell_spacing * @as(f64, @floatFromInt(rowspan - 1));
            var span_i: usize = 0;
            while (span_i < colspan and col_index + span_i < occupied.len) : (span_i += 1) {
                occupied[col_index + span_i] = @max(occupied[col_index + span_i], rowspan);
            }
            const cell_border: f64 = @floatFromInt(htmlIntAttr(td_tag, "cellborder", @intFromFloat(metrics.cell_border)));
            const cell_padding: f64 = @floatFromInt(htmlIntAttr(td_tag, "cellpadding", @intFromFloat(metrics.cell_padding)));
            if (htmlAttrValue(td_tag, "bgcolor")) |cell_bg| {
                try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" fill=\"{s}\" stroke=\"none\"/>\n", .{ cell_x, cell_y, spanned_w, spanned_h, cell_bg });
            }
            if (cell_border > 0) {
                try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" fill=\"none\" stroke=\"{s}\" stroke-width=\"{d:.1}\"/>\n", .{ cell_x, cell_y, spanned_w, spanned_h, visual.stroke, cell_border });
            }
            const cell = row[cell_start..td_close];
            const align_attr = htmlAttrValue(td_tag, "align");
            const text_anchor: []const u8 = if (align_attr) |value|
                if (std.ascii.eqlIgnoreCase(value, "left")) "start" else if (std.ascii.eqlIgnoreCase(value, "right")) "end" else "middle"
            else
                "middle";
            const text_x = if (std.mem.eql(u8, text_anchor, "start"))
                cell_x + cell_padding
            else if (std.mem.eql(u8, text_anchor, "end"))
                cell_x + spanned_w - cell_padding
            else
                cell_x + spanned_w / 2.0;
            const valign_attr = htmlAttrValue(td_tag, "valign");
            const text_y = if (valign_attr) |value|
                if (std.ascii.eqlIgnoreCase(value, "top"))
                    cell_y + cell_padding + visual.font_size * 0.5
                else if (std.ascii.eqlIgnoreCase(value, "bottom"))
                    cell_y + spanned_h - cell_padding - visual.font_size * 0.5
                else
                    cell_y + spanned_h / 2.0
            else
                cell_y + spanned_h / 2.0;
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
            cell_pos = td_close + 1;
            col_index += colspan - 1;
        }
        row_pos = tr_close + 1;
    }
}

fn renderSvgNodeShape(writer: *Io.Writer, node_item: Node, layout: NodeLayout, visual: NodeVisual, options: SvgOptions) Io.Writer.Error!void {
    switch (node_item.shape) {
        .point => {
            try writer.print("<circle cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"/>\n", .{
                layout.center.x,
                layout.center.y,
                @min(layout.width, layout.height) / 2.0,
                visual.stroke,
                visual.stroke,
                visual.width,
            });
        },
        .box, .square, .msquare => {
            var ring: usize = 0;
            while (ring < visual.peripheries) : (ring += 1) {
                const inset = @as(f64, @floatFromInt(ring)) * 5.0;
                try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
                    layout.center.x - layout.width / 2.0 + inset,
                    layout.center.y - layout.height / 2.0 + inset,
                    @max(1, layout.width - inset * 2.0),
                    @max(1, layout.height - inset * 2.0),
                    @max(0, visual.radius - inset / 2.0),
                    if (ring == 0) visual.fill else "none",
                    visual.stroke,
                    visual.width,
                });
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            }
            if (node_item.shape == .msquare) try renderSvgCornerDiagonals(writer, layout, visual);
        },
        .circle, .doublecircle, .mcircle => {
            var ring: usize = 0;
            const ring_count = if (node_item.shape == .doublecircle) @max(visual.peripheries, 2) else visual.peripheries;
            while (ring < ring_count) : (ring += 1) {
                const inset = @as(f64, @floatFromInt(ring)) * 5.0;
                try writer.print("<circle cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
                    layout.center.x,
                    layout.center.y,
                    @max(1, @min(layout.width, layout.height) / 2.0 - inset),
                    if (ring == 0) visual.fill else "none",
                    visual.stroke,
                    visual.width,
                });
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            }
            if (node_item.shape == .mcircle) try renderSvgCircleDiagonals(writer, layout, visual);
        },
        .ellipse => {
            var ring: usize = 0;
            while (ring < visual.peripheries) : (ring += 1) {
                const inset = @as(f64, @floatFromInt(ring)) * 5.0;
                try writer.print("<ellipse cx=\"{d:.1}\" cy=\"{d:.1}\" rx=\"{d:.1}\" ry=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
                    layout.center.x,
                    layout.center.y,
                    @max(1, layout.width / 2.0 - inset),
                    @max(1, layout.height / 2.0 - inset),
                    if (ring == 0) visual.fill else "none",
                    visual.stroke,
                    visual.width,
                });
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            }
        },
        .egg => try renderSvgEggShape(writer, layout, visual),
        .polygon => try renderSvgCustomPolygon(writer, node_item, layout, visual),
        .diamond => try renderSvgPolygonRings(6, writer, layout, visual, diamondPoints),
        .mdiamond => {
            try renderSvgPolygonRings(6, writer, layout, visual, diamondPoints);
            try renderSvgDiamondDiagonals(writer, layout, visual);
        },
        .triangle => try renderSvgPolygonRings(6, writer, layout, visual, trianglePoints),
        .invtriangle => try renderSvgPolygonRings(6, writer, layout, visual, invTrianglePoints),
        .parallelogram => try renderSvgPolygonRings(6, writer, layout, visual, parallelogramPoints),
        .trapezium => try renderSvgPolygonRings(6, writer, layout, visual, trapeziumPoints),
        .invtrapezium => try renderSvgPolygonRings(6, writer, layout, visual, invTrapeziumPoints),
        .house => try renderSvgPolygonRings(6, writer, layout, visual, housePoints),
        .invhouse => try renderSvgPolygonRings(6, writer, layout, visual, invHousePoints),
        .pentagon => try renderSvgPolygonRings(5, writer, layout, visual, pentagonPoints),
        .hexagon => try renderSvgPolygonRings(6, writer, layout, visual, hexagonPoints),
        .septagon => try renderSvgPolygonRings(7, writer, layout, visual, septagonPoints),
        .octagon => try renderSvgPolygonRings(8, writer, layout, visual, octagonPoints),
        .doubleoctagon, .tripleoctagon => {
            var ring_visual = visual;
            const default_peripheries: usize = if (node_item.shape == .tripleoctagon) 3 else 2;
            ring_visual.peripheries = @max(visual.peripheries, default_peripheries);
            try renderSvgPolygonRings(8, writer, layout, ring_visual, octagonPoints);
        },
        .star => try renderSvgPolygonRings(10, writer, layout, visual, starPoints),
        .note => try renderSvgNoteShape(writer, layout, visual),
        .tab => try renderSvgTabShape(writer, layout, visual),
        .folder => try renderSvgFolderShape(writer, layout, visual),
        .box3d => try renderSvgBox3dShape(writer, layout, visual),
        .component => try renderSvgComponentShape(writer, layout, visual),
        .underline => try renderSvgUnderlineShape(writer, layout, visual),
        .cylinder => try renderSvgCylinderShape(writer, layout, visual),
        .plaintext => {},
        .record => try renderSvgRecordNode(writer, node_item.label, layout, visual, options, false),
        .mrecord => try renderSvgRecordNode(writer, node_item.label, layout, visual, options, true),
    }
}

fn renderSvgPolygon(writer: *Io.Writer, points: []const Point, visual: NodeVisual) Io.Writer.Error!void {
    try writer.writeAll("<polygon points=\"");
    var written: usize = 0;
    for (points) |point| {
        if (point.x < 0 and point.y < 0) continue;
        if (written > 0) try writer.writeByte(' ');
        try writer.print("{d:.1},{d:.1}", .{ point.x, point.y });
        written += 1;
    }
    try writer.print("\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{ visual.fill, visual.stroke, visual.width });
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
    try writeSvgLine(writer, cx - hw * 0.52, cy, cx, cy - hh * 0.52, visual);
    try writeSvgLine(writer, cx, cy - hh * 0.52, cx + hw * 0.52, cy, visual);
    try writeSvgLine(writer, cx + hw * 0.52, cy, cx, cy + hh * 0.52, visual);
    try writeSvgLine(writer, cx, cy + hh * 0.52, cx - hw * 0.52, cy, visual);
}

fn renderSvgCornerDiagonals(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const d = @min(@min(rect.width, rect.height) * 0.22, 18);
    try writeSvgLine(writer, rect.x, rect.y + d, rect.x + d, rect.y, visual);
    try writeSvgLine(writer, rect.x + rect.width - d, rect.y, rect.x + rect.width, rect.y + d, visual);
    try writeSvgLine(writer, rect.x + rect.width, rect.y + rect.height - d, rect.x + rect.width - d, rect.y + rect.height, visual);
    try writeSvgLine(writer, rect.x + d, rect.y + rect.height, rect.x, rect.y + rect.height - d, visual);
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
        try writer.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"{s}\" font-size=\"{d:.1}\" fill=\"{s}\">", .{
            rect.x + rect.width / 2.0,
            rect.y + rect.height / 2.0,
            visual.font_family,
            visual.font_size,
            visual.font_color,
        });
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
    const fill = attrValue(node_item.attrs.items, "fillcolor") orelse if (filled) (if (explicit_color) color else "lightgrey") else "#ffffff";
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
    return .{
        .stroke = attrValue(edge_item.attrs.items, "color") orelse edge_item.color,
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
    const marker_size = 10.0 * scale;
    try writer.print("<marker id=\"arrow-{d}-{s}\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"{d:.2}\" markerHeight=\"{d:.2}\" orient=\"auto", .{ edge_id, suffix, marker_size, marker_size });
    if (std.mem.eql(u8, suffix, "tail")) try writer.writeAll("-start-reverse");
    try writer.writeAll("\">");
    switch (shape) {
        .none => {},
        .normal => try writer.print("<path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"{s}\"/>", .{color}),
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

fn writeSvgMarkerAttrs(writer: *Io.Writer, directed: bool, edge_id: EdgeId, visual: EdgeVisual) Io.Writer.Error!void {
    if (!directed) return;
    if (visual.marker_scale <= 0) return;
    if (visual.marker_start != .none) try writer.print(" marker-start=\"url(#arrow-{d}-tail)\"", .{edge_id});
    if (visual.marker_end != .none) try writer.print(" marker-end=\"url(#arrow-{d}-head)\"", .{edge_id});
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
        try writer.print("M {d:.1} {d:.1} L {d:.1} {d:.1}", .{ direct_route.start.x, direct_route.start.y, direct_route.end.x, direct_route.end.y });
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
    if (waypoint_count == 0) {
        if (routing == .polyline) {
            try writer.print("M {d:.1} {d:.1} L {d:.1} {d:.1}", .{ direct_route.start.x, direct_route.start.y, direct_route.end.x, direct_route.end.y });
            return;
        }
        try writer.print("M {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1}", .{
            direct_route.start.x,
            direct_route.start.y,
            direct_route.control1.x,
            direct_route.control1.y,
            direct_route.control2.x,
            direct_route.control2.y,
            direct_route.end.x,
            direct_route.end.y,
        });
        return;
    }

    try writer.print("M {d:.1} {d:.1}", .{ direct_route.start.x, direct_route.start.y });
    var current = direct_route.start;
    var i: usize = 0;
    while (i < waypoint_count) : (i += 1) {
        const next = longEdgeWaypoint(layout, edge_item, rankdir, offset, i, waypoint_count);
        if (routing == .polyline) {
            try writer.print(" L {d:.1} {d:.1}", .{ next.x, next.y });
        } else {
            try writeSmoothSegment(writer, current, next, rankdir);
        }
        current = next;
    }
    if (routing == .polyline) {
        try writer.print(" L {d:.1} {d:.1}", .{ direct_route.end.x, direct_route.end.y });
    } else {
        try writeSmoothSegment(writer, current, direct_route.end, rankdir);
    }
}

fn writeOrthoEdgePath(writer: *Io.Writer, start: Point, end: Point, rankdir: RankDir) Io.Writer.Error!void {
    if (rankdir == .LR or rankdir == .RL) {
        const mid_x = (start.x + end.x) / 2.0;
        try writer.print("M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1}", .{
            start.x,
            start.y,
            mid_x,
            start.y,
            mid_x,
            end.y,
            end.x,
            end.y,
        });
    } else {
        const mid_y = (start.y + end.y) / 2.0;
        try writer.print("M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1}", .{
            start.x,
            start.y,
            start.x,
            mid_y,
            end.x,
            mid_y,
            end.x,
            end.y,
        });
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
            @max(8.0, @min(from.center.x - from.width / 2.0, to.center.x - to.width / 2.0) - side_gap)
        else
            @min(layout.width - 8.0, @max(from.center.x + from.width / 2.0, to.center.x + to.width / 2.0) + side_gap);
        const p1 = Point{ .x = side_x, .y = route.start.y };
        const p2 = Point{ .x = side_x, .y = route.end.y };
        if (routing == .polyline) {
            try writer.print("M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1}", .{
                route.start.x, route.start.y, p1.x, p1.y, p2.x, p2.y, route.end.x, route.end.y,
            });
        } else {
            const curve = @min(36.0, @abs(route.start.x - side_x) * 0.5 + 12.0);
            const c1x = if (prefer_left) route.start.x - curve else route.start.x + curve;
            const c2x = if (prefer_left) side_x + curve else side_x - curve;
            const c3x = if (prefer_left) side_x + curve else side_x - curve;
            const c4x = if (prefer_left) route.end.x - curve else route.end.x + curve;
            try writer.print("M {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1} L {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1}", .{
                route.start.x, route.start.y,
                c1x,           route.start.y,
                c2x,           p1.y,
                p1.x,          p1.y,
                p2.x,          p2.y,
                c3x,           p2.y,
                c4x,           route.end.y,
                route.end.x,   route.end.y,
            });
        }
        return;
    }

    const prefer_top = backEdgeUsesNegativeSide(layout, edge_item, rankdir);
    const side_y = if (prefer_top)
        @max(8.0, @min(from.center.y - from.height / 2.0, to.center.y - to.height / 2.0) - side_gap)
    else
        @min(layout.height - 8.0, @max(from.center.y + from.height / 2.0, to.center.y + to.height / 2.0) + side_gap);
    const p1 = Point{ .x = route.start.x, .y = side_y };
    const p2 = Point{ .x = route.end.x, .y = side_y };
    if (routing == .polyline) {
        try writer.print("M {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1} L {d:.1} {d:.1}", .{
            route.start.x, route.start.y, p1.x, p1.y, p2.x, p2.y, route.end.x, route.end.y,
        });
    } else {
        const curve = @min(36.0, @abs(route.start.y - side_y) * 0.5 + 12.0);
        const c1y = if (prefer_top) route.start.y - curve else route.start.y + curve;
        const c2y = if (prefer_top) side_y + curve else side_y - curve;
        const c3y = if (prefer_top) side_y + curve else side_y - curve;
        const c4y = if (prefer_top) route.end.y - curve else route.end.y + curve;
        try writer.print("M {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1} L {d:.1} {d:.1} C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1}", .{
            route.start.x, route.start.y,
            route.start.x, c1y,
            p1.x,          c2y,
            p1.x,          p1.y,
            p2.x,          p2.y,
            p2.x,          c3y,
            route.end.x,   c4y,
            route.end.x,   route.end.y,
        });
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
    const from_rank = layout.ranks[edge_item.from];
    const to_rank = layout.ranks[edge_item.to];
    const increasing = to_rank > from_rank;
    const rank = if (increasing) from_rank + index + 1 else from_rank - index - 1;
    if (storedEdgeWaypoint(layout, edge_item.id, rank)) |point| return offsetPoint(avoidNodeAtRankForWaypoint(layout, edge_item, rankdir, rank, point), rankdir, offset);
    const along = longEdgeDummyAlongFromLayout(layout, edge_item, rankdir, rank) orelse interpolatedWaypointAlong(layout, edge_item, rankdir, index, count);
    const depth = rankDepthCenter(layout, rank);
    const point = orientWaypoint(rankdir, along, depth, layout);
    return offsetPoint(avoidNodeAtRankForWaypoint(layout, edge_item, rankdir, rank, point), rankdir, offset);
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
    const from_along = pointAlongAxis(layout.nodes[edge_item.from].center, rankdir);
    const to_along = pointAlongAxis(layout.nodes[edge_item.to].center, rankdir);
    return from_along + (to_along - from_along) * t;
}

fn interpolatedWaypointAlong(layout: *const Layout, edge_item: Edge, rankdir: RankDir, index: usize, count: usize) f64 {
    const t = @as(f64, @floatFromInt(index + 1)) / @as(f64, @floatFromInt(count + 1));
    const from_center = layout.nodes[edge_item.from].center;
    const to_center = layout.nodes[edge_item.to].center;
    return pointAlongAxis(from_center, rankdir) + (pointAlongAxis(to_center, rankdir) - pointAlongAxis(from_center, rankdir)) * t;
}

fn pointAlongAxis(point: Point, rankdir: RankDir) f64 {
    return switch (rankdir) {
        .TB, .BT => point.x,
        .LR, .RL => point.y,
    };
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
    return switch (rankdir) {
        .TB => .{ .x = along_screen, .y = layout.margin_y + depth },
        .BT => .{ .x = along_screen, .y = layout.height - (layout.margin_y + depth) },
        .LR => .{ .x = layout.margin_x + depth, .y = along_screen },
        .RL => .{ .x = layout.width - (layout.margin_x + depth), .y = along_screen },
    };
}

fn splineCurveAmount(rankdir: RankDir, dx: f64, dy: f64, min_curve: f64, max_curve: f64) f64 {
    const axis_delta = if (rankdir == .LR or rankdir == .RL) @abs(dx) else @abs(dy);
    if (axis_delta <= 0.001) return 0;
    const preferred = @min(max_curve, axis_delta * 0.45);
    return @min(axis_delta * 0.5, @max(min_curve, preferred));
}

fn writeSmoothSegment(writer: *Io.Writer, from: Point, to: Point, rankdir: RankDir) Io.Writer.Error!void {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const curve = splineCurveAmount(rankdir, dx, dy, 18.0, 96.0);
    const controls = switch (rankdir) {
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
    try writer.print(" C {d:.1} {d:.1}, {d:.1} {d:.1}, {d:.1} {d:.1}", .{ controls.c1.x, controls.c1.y, controls.c2.x, controls.c2.y, to.x, to.y });
}

fn edgeRoute(from: NodeLayout, to: NodeLayout, rankdir: RankDir, offset: f64) EdgeRoute {
    const start = boundaryPoint(from, to.center, rankdir, true);
    const end = boundaryPoint(to, from.center, rankdir, false);
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const curve = splineCurveAmount(rankdir, dx, dy, 24.0, 160.0);
    const controls: EdgeControls = switch (rankdir) {
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

fn edgeRouteForEdge(graph: *const Graph, layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64) EdgeRoute {
    const from = layout.nodes[edge_item.from];
    const to = layout.nodes[edge_item.to];
    const tail_clip = edgeClipEnabled(edge_item.attrs.items, "tailclip");
    const head_clip = edgeClipEnabled(edge_item.attrs.items, "headclip");
    const raw_start = if (tail_clip)
        samePortBoundaryPoint(graph, layout, edge_item, false) orelse recordBoundaryPoint(graph.nodes.items[edge_item.from], from, to.center, edge_item.tail_record_port, edge_item.tail_port, true) orelse portBoundaryPoint(from, to.center, edge_item.tail_port, rankdir, true)
    else
        from.center;
    const raw_end = if (head_clip)
        samePortBoundaryPoint(graph, layout, edge_item, true) orelse recordBoundaryPoint(graph.nodes.items[edge_item.to], to, from.center, edge_item.head_record_port, edge_item.head_port, false) orelse portBoundaryPoint(to, from.center, edge_item.head_port, rankdir, false)
    else
        to.center;
    const start = if (edge_item.ltail) |cluster_name|
        clusterBoundaryPoint(graph, layout, cluster_name, raw_start, raw_end) orelse raw_start
    else
        raw_start;
    const end = if (edge_item.lhead) |cluster_name|
        clusterBoundaryPoint(graph, layout, cluster_name, raw_end, raw_start) orelse raw_end
    else
        raw_end;
    return edgeRouteFromEndpoints(start, end, rankdir, offset);
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
    return boundaryPoint(anchor, toward, graph.rankdir, !head);
}

fn edgeRouteFromEndpoints(start_raw: Point, end_raw: Point, rankdir: RankDir, offset: f64) EdgeRoute {
    const start = start_raw;
    const end = end_raw;
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const curve = splineCurveAmount(rankdir, dx, dy, 24.0, 160.0);
    const controls: EdgeControls = switch (rankdir) {
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

fn portBoundaryPoint(node: NodeLayout, toward: Point, port: CompassPort, rankdir: RankDir, leaving: bool) Point {
    if (port == .auto) return boundaryPoint(node, toward, rankdir, leaving);
    return pointForPort(.{
        .x = node.center.x - node.width / 2.0,
        .y = node.center.y - node.height / 2.0,
        .width = node.width,
        .height = node.height,
    }, port, toward);
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

fn offsetPoint(point: Point, rankdir: RankDir, offset: f64) Point {
    return switch (rankdir) {
        .TB, .BT => .{ .x = point.x + offset, .y = point.y },
        .LR, .RL => .{ .x = point.x, .y = point.y + offset },
    };
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

    try writer.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"{s}\" font-family=\"{s}\" font-size=\"{d:.1}\" fill=\"{s}\"", .{ x, first_y, text_anchor, font_family, font_size, fill });
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
        while (scanner.next()) |token| {
            switch (token) {
                .newline => {
                    try writer.print("</tspan><tspan x=\"{d:.1}\" dy=\"{d:.1}\">", .{ x, line_height });
                    has_text = false;
                    pending_space = false;
                },
                .char => |c| {
                    if (isHtmlLabelSpace(c)) {
                        if (has_text) pending_space = true;
                        continue;
                    }
                    if (pending_space) {
                        try writer.writeByte(' ');
                        pending_space = false;
                    }
                    try writeXmlEscaped(writer, &.{c});
                    has_text = true;
                },
            }
        }
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
    try expectRankDirection(&graph, &layout, .LR);
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
    try std.testing.expectEqual(@as(f64, 8), compact.margin_y);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end") != null);
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

    try std.testing.expect(std.mem.indexOf(u8, svg, " C ") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker id=\"arrow-0-head\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#2563eb\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "dy=\"17.5\"") != null);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const route = edgeRoute(layout.nodes[a], layout.nodes[b], graph.rankdir, 0);
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

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#ffffff\" stroke=\"black\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#ffffff\" stroke=\"#dc2626\"") != null);
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

    try std.testing.expect(countSubstrings(svg, "stroke-width=\"1.0\"") >= 4);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"1.8\"") == null);
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
        \\    <TABLE BORDER="0" CELLBORDER="2" CELLSPACING="4" CELLPADDING="9" BGCOLOR="lightgrey">
        \\      <TR><TD>A</TD><TD>B</TD></TR>
        \\    </TABLE>
        \\  >];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"lightgrey\" stroke=\"none\" stroke-width=\"0.0\"") != null);
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

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"lightgrey\"") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Top Left</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">Bottom Right</tspan>") != null);
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

    try std.testing.expect(countSubstrings(svg, "fill=\"black\"") >= 4);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#475569\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#0f172a\"") == null);
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

    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.0\" fill=\"black\">Cluster") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.0\" fill=\"black\" dominant-baseline=\"middle\"") != null);
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
    const route = edgeRouteForEdge(&graph, &layout, edge_item, graph.rankdir, 0);
    const near_tail = endpointLabelPosition(route.start, route.label, 1.0, -45, false);
    const far_tail = endpointLabelPosition(route.start, route.label, 2.0, -45, false);
    try std.testing.expect(distanceBetween(route.start, far_tail) > distanceBetween(route.start, near_tail));

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Courier\" font-size=\"18.0\"") != null);
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

    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Courier\" font-size=\"18.0\" fill=\"black\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Courier\" font-size=\"22.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Times\" font-size=\"16.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Georgia\" font-size=\"20.0\"") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "markerWidth=\"20.00\" markerHeight=\"20.00\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "arrow-1-head") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-1-head)\"") == null);

    const a = graph.node_index.get("a").?;
    const b = graph.node_index.get("b").?;
    const c = graph.node_index.get("c").?;
    const clipped = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], graph.rankdir, 0);
    try std.testing.expect(clipped.start.x > layout.nodes[a].center.x);
    try std.testing.expect(clipped.end.x < layout.nodes[b].center.x);

    const unclipped = edgeRouteForEdge(&graph, &layout, graph.edges.items[2], graph.rankdir, 0);
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
    try std.testing.expect(countSubstrings(concentrated_svg, "marker id=\"arrow-") == 1);
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
    const route = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], graph.rankdir, 0);
    try std.testing.expectEqual(layout.nodes[a].center.x + layout.nodes[a].width / 2.0, route.start.x);
    try std.testing.expectEqual(layout.nodes[b].center.x - layout.nodes[b].width / 2.0, route.end.x);
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
    const waypoint = longEdgeWaypoint(&layout, graph.edges.items[3], graph.rankdir, 0, 0, 2);
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
    const tb_waypoint = longEdgeWaypoint(&tb_layout, tb_edge, tb.rankdir, 0, 0, 2);
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
    const lr_waypoint = longEdgeWaypoint(&lr_layout, lr_edge, lr.rankdir, 0, 0, 2);
    try std.testing.expectEqual(lr_layout.edge_waypoints[lr_edge.id].points[0].point.x, lr_waypoint.x);
    try std.testing.expectEqual(lr_layout.edge_waypoints[lr_edge.id].points[0].point.y, lr_waypoint.y);
}

test "long-edge waypoints avoid same-rank node boxes" {
    const allocator = std.testing.allocator;
    var layout = Layout{
        .allocator = allocator,
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
    try std.testing.expect(countSubstrings(path, " C ") >= 3);
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
    const route = edgeRouteForEdge(&graph, &layout, graph.edges.items[3], graph.rankdir, 0);
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    const label_pos = std.mem.indexOf(u8, svg, ">back</tspan>") orelse return error.MissingBackLabel;
    const before_label = svg[0..label_pos];
    const path_start = std.mem.lastIndexOf(u8, before_label, "<path") orelse return error.MissingBackPath;
    const path_end_rel = std.mem.indexOf(u8, svg[path_start..], "/>") orelse return error.MissingBackPathEnd;
    const path = svg[path_start .. path_start + path_end_rel];
    try std.testing.expect(isBackEdge(&layout, graph.edges.items[3]));
    try std.testing.expect(countSubstrings(path, " C ") == 2);
    try std.testing.expect(countSubstrings(path, " L ") == 1);
    try std.testing.expect(std.mem.indexOf(u8, path, " C ") != null);
    try std.testing.expect(route.start.y > route.end.y);
}

test "back-edge side channel prefers stable negative side for same column" {
    const allocator = std.testing.allocator;
    var layout = Layout{
        .allocator = allocator,
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
    try std.testing.expect(countSubstrings(path, " C ") == 2);
    try std.testing.expect(countSubstrings(path, " L ") == 1);
}

test "user cluster example stays compact and Graphviz-like" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_0 {
        \\    style=filled;
        \\    color=lightgrey;
        \\    node [style=filled,color=white];
        \\    a0 -> a1 -> a2 -> a3;
        \\    label = "process #1";
        \\  }
        \\  subgraph cluster_1 {
        \\    node [style=filled];
        \\    b0 -> b1 -> b2 -> b3;
        \\    label = "process #2";
        \\    color=blue
        \\  }
        \\  start -> a0;
        \\  start -> b0;
        \\  a1 -> b3;
        \\  b2 -> a3;
        \\  a3 -> a0;
        \\  a3 -> end;
        \\  b3 -> end;
        \\  start [shape=Mdiamond];
        \\  end [shape=Msquare];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expect(layout.width <= 224.0);
    try std.testing.expect(layout.height <= 430.0);
    for (layout.clusters) |cluster_box| {
        try std.testing.expect(cluster_box.width <= 110.0);
        try std.testing.expect(cluster_box.height <= 300.0);
    }

    const a0 = graph.node_index.get("a0").?;
    const a1 = graph.node_index.get("a1").?;
    const a2 = graph.node_index.get("a2").?;
    const a3 = graph.node_index.get("a3").?;
    const b0 = graph.node_index.get("b0").?;
    const b1 = graph.node_index.get("b1").?;
    const b2 = graph.node_index.get("b2").?;
    const b3 = graph.node_index.get("b3").?;
    try std.testing.expect(@abs(layout.nodes[a0].center.x - layout.nodes[a1].center.x) <= 1.0);
    try std.testing.expect(@abs(layout.nodes[a1].center.x - layout.nodes[a2].center.x) <= 1.0);
    try std.testing.expect(@abs(layout.nodes[a2].center.x - layout.nodes[a3].center.x) <= 1.0);
    try std.testing.expect(@abs(layout.nodes[b0].center.x - layout.nodes[b1].center.x) <= 1.0);
    try std.testing.expect(@abs(layout.nodes[b1].center.x - layout.nodes[b2].center.x) <= 1.0);
    try std.testing.expect(@abs(layout.nodes[b2].center.x - layout.nodes[b3].center.x) <= 1.0);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>G</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">G</text>") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, " L 8.0 ") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, ortho_svg, " C ") == null);
    try std.testing.expect(countSubstrings(ortho_svg, " L ") >= 3);

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
    try std.testing.expect(std.mem.indexOf(u8, line_svg, " C ") == null);
    try std.testing.expect(countSubstrings(line_svg, " L ") >= 1);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "class=\"clusters\"") != null);
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
    try std.testing.expect(cluster_box.width <= 104.0);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\" fill-opacity=\"1.0\" stroke=\"blue\"") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, " C ") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, " C ") != null);
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
    const route = edgeRouteForEdge(&graph, &layout, edge_item, graph.rankdir, 0);
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
    const first_route = edgeRouteForEdge(&graph, &layout, first, graph.rankdir, 0);
    try std.testing.expectEqual(layout.nodes[first.from].center.x + layout.nodes[first.from].width / 2.0, first_route.start.x);
    try std.testing.expectEqual(layout.nodes[first.to].center.x - layout.nodes[first.to].width / 2.0, first_route.end.x);

    const record_edge = graph.edges.items[1];
    const record_route = edgeRouteForEdge(&graph, &layout, record_edge, graph.rankdir, 0);
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
    try std.testing.expect(countSubstrings(svg, " L ") >= 4);
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

    const route = edgeRouteForEdge(&graph, &layout, edge_item, graph.rankdir, 0);
    const left = clusterRect(&graph, &layout, "cluster_left").?;
    const right = clusterRect(&graph, &layout, "cluster_right").?;
    try std.testing.expect(pointOnRectBoundary(left, route.start));
    try std.testing.expect(pointOnRectBoundary(right, route.end));
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

    const head_a = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], graph.rankdir, 0);
    const head_b = edgeRouteForEdge(&graph, &layout, graph.edges.items[1], graph.rankdir, 0);
    try std.testing.expect(distanceBetween(head_a.end, head_b.end) <= 0.01);

    const tail_x = edgeRouteForEdge(&graph, &layout, graph.edges.items[2], graph.rankdir, 0);
    const tail_y = edgeRouteForEdge(&graph, &layout, graph.edges.items[3], graph.rankdir, 0);
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
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const min_sized = graph.node_index.get("min_sized").?;
    const fixed = graph.node_index.get("fixed").?;
    try std.testing.expect(layout.nodes[min_sized].width >= 216);
    try std.testing.expect(layout.nodes[min_sized].height >= 108);
    try std.testing.expect(@abs(layout.nodes[fixed].width - 72.0) < 0.01);
    try std.testing.expect(@abs(layout.nodes[fixed].height - 36.0) < 0.01);
}

test "color parser accepts common DOT named colors" {
    try std.testing.expectEqual(Rgba{ 211, 211, 211, 255 }, parseHexColor("lightgrey").?);
    try std.testing.expectEqual(Rgba{ 128, 128, 128, 255 }, parseHexColor("gray").?);
    try std.testing.expectEqual(Rgba{ 255, 0, 0, 255 }, parseHexColor("red").?);
    try std.testing.expectEqual(Rgba{ 170, 187, 204, 255 }, parseHexColor("#abc").?);
    try std.testing.expectEqual(Rgba{ 0, 0, 0, 0 }, parseHexColor("transparent").?);
}
