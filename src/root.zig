//! Vex core library.
//!
//! The public API is intentionally split around a single graph model:
//! code can build graphs directly and parsers such as DOT lower into the
//! same model before layout/rendering.

const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;

pub const NodeId = usize;
pub const EdgeId = usize;
pub const SubgraphId = usize;

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

pub const SubgraphStyle = enum {
    filled,
    bold,
    dashed,
    dotted,
    rounded,
    striped,
    radial,
    invis,
};

pub const GraphOptions = struct {
    directed: bool = true,
    strict: bool = false,
    name: []const u8 = "G",
    rankdir: RankDir = .TB,
};

pub const LabelJust = enum {
    left,
    center,
    right,
};

pub const LabelLoc = enum {
    top,
    bottom,
};

pub const OrderingMode = enum {
    none,
    in,
    out,
};

pub const SplineMode = enum {
    curved,
    line,
    ortho,
    none,
};

pub const RankSep = union(enum) {
    value: f64,
    equally: f64,
};

pub const GraphAttr = union(enum) {
    label: []const u8,
    rankdir: RankDir,
    layout: LayoutAlgorithm,
    compound: bool,
    concentrate: bool,
    nodesep: f64,
    ranksep: RankSep,
    splines: SplineMode,
    samplepoints: usize,
    bgcolor: []const u8,
    pad: []const u8,
    margin: []const u8,
    fontname: []const u8,
    fontsize: f64,
    fontcolor: []const u8,
    labeljust: LabelJust,
    labelloc: LabelLoc,
    ordering: OrderingMode,
    url: []const u8,
    href: []const u8,
    tooltip: []const u8,
    title: []const u8,
    target: []const u8,
    id: []const u8,
    class: []const u8,
    stylesheet: []const u8,
    comment: []const u8,
};

pub const NodeStyle = enum {
    filled,
    bold,
    dashed,
    dotted,
    rounded,
    striped,
    radial,
    invis,
};

pub const NodeFixedSize = enum {
    none,
    fit_label,
    shape,
};

pub const NodeAttr = union(enum) {
    label: []const u8,
    color: []const u8,
    fillcolor: []const u8,
    gradientangle: f64,
    fontcolor: []const u8,
    fontname: []const u8,
    fontsize: f64,
    shape: Shape,
    style: NodeStyle,
    styles: []const NodeStyle,
    penwidth: f64,
    peripheries: usize,
    sides: usize,
    regular: bool,
    orientation: f64,
    skew: f64,
    distortion: f64,
    width: f64,
    height: f64,
    fixedsize: NodeFixedSize,
    margin: []const u8,
    xlabel: []const u8,
    labelloc: LabelLoc,
    labeljust: LabelJust,
    url: []const u8,
    href: []const u8,
    tooltip: []const u8,
    title: []const u8,
    target: []const u8,
    id: []const u8,
    class: []const u8,
    comment: []const u8,
    ordering: OrderingMode,
    group: []const u8,
};

pub const EdgeStyle = enum {
    solid,
    bold,
    dashed,
    dotted,
    invis,
};

pub const ArrowShape = enum {
    normal,
    none,
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

pub const EdgeDir = enum {
    forward,
    back,
    both,
    none,
};

pub const EdgePort = struct {
    record: ?[]const u8 = null,
    compass: CompassPort = .auto,
};

pub const NodeOptions = struct {
    label: ?[]const u8 = null,
    color: ?[]const u8 = null,
    fillcolor: ?[]const u8 = null,
    gradientangle: ?f64 = null,
    fontcolor: ?[]const u8 = null,
    fontname: ?[]const u8 = null,
    fontsize: ?f64 = null,
    shape: ?Shape = null,
    style: ?NodeStyle = null,
    styles: []const NodeStyle = &.{},
    penwidth: ?f64 = null,
    peripheries: ?usize = null,
    sides: ?usize = null,
    regular: ?bool = null,
    orientation: ?f64 = null,
    skew: ?f64 = null,
    distortion: ?f64 = null,
    width: ?f64 = null,
    height: ?f64 = null,
    fixedsize: ?NodeFixedSize = null,
    margin: ?[]const u8 = null,
    xlabel: ?[]const u8 = null,
    labelloc: ?LabelLoc = null,
    labeljust: ?LabelJust = null,
    url: ?[]const u8 = null,
    href: ?[]const u8 = null,
    tooltip: ?[]const u8 = null,
    title: ?[]const u8 = null,
    target: ?[]const u8 = null,
    id: ?[]const u8 = null,
    class: ?[]const u8 = null,
    comment: ?[]const u8 = null,
    ordering: ?OrderingMode = null,
    group: ?[]const u8 = null,
};

pub const EdgeOptions = struct {
    label: ?[]const u8 = null,
    color: ?[]const u8 = null,
    fillcolor: ?[]const u8 = null,
    fontcolor: ?[]const u8 = null,
    fontname: ?[]const u8 = null,
    fontsize: ?f64 = null,
    style: ?EdgeStyle = null,
    styles: []const EdgeStyle = &.{},
    penwidth: ?f64 = null,
    weight: ?f64 = null,
    constraint: ?bool = null,
    min_len: ?usize = null,
    url: ?[]const u8 = null,
    href: ?[]const u8 = null,
    tooltip: ?[]const u8 = null,
    title: ?[]const u8 = null,
    target: ?[]const u8 = null,
    id: ?[]const u8 = null,
    class: ?[]const u8 = null,
    comment: ?[]const u8 = null,
    edge_url: ?[]const u8 = null,
    edge_href: ?[]const u8 = null,
    edge_tooltip: ?[]const u8 = null,
    edge_target: ?[]const u8 = null,
    label_url: ?[]const u8 = null,
    label_href: ?[]const u8 = null,
    label_tooltip: ?[]const u8 = null,
    label_target: ?[]const u8 = null,
    head_url: ?[]const u8 = null,
    head_href: ?[]const u8 = null,
    head_tooltip: ?[]const u8 = null,
    head_target: ?[]const u8 = null,
    tail_url: ?[]const u8 = null,
    tail_href: ?[]const u8 = null,
    tail_tooltip: ?[]const u8 = null,
    tail_target: ?[]const u8 = null,
    arrowhead: ?ArrowShape = null,
    arrowtail: ?ArrowShape = null,
    arrowsize: ?f64 = null,
    dir: ?EdgeDir = null,
    taillabel: ?[]const u8 = null,
    headlabel: ?[]const u8 = null,
    xlabel: ?[]const u8 = null,
    labelfontcolor: ?[]const u8 = null,
    labelfontname: ?[]const u8 = null,
    labelfontsize: ?f64 = null,
    labeldistance: ?f64 = null,
    labelangle: ?f64 = null,
    decorate: ?bool = null,
    tailclip: ?bool = null,
    headclip: ?bool = null,
    samehead: ?[]const u8 = null,
    sametail: ?[]const u8 = null,
    tail_port: CompassPort = .auto,
    head_port: CompassPort = .auto,
    tail_record_port: ?[]const u8 = null,
    head_record_port: ?[]const u8 = null,
    ltail: ?SubgraphId = null,
    lhead: ?SubgraphId = null,
};

pub const EdgeAttr = union(enum) {
    label: []const u8,
    color: []const u8,
    fillcolor: []const u8,
    fontcolor: []const u8,
    fontname: []const u8,
    fontsize: f64,
    style: EdgeStyle,
    styles: []const EdgeStyle,
    penwidth: f64,
    weight: f64,
    constraint: bool,
    min_len: usize,
    url: []const u8,
    href: []const u8,
    tooltip: []const u8,
    title: []const u8,
    target: []const u8,
    id: []const u8,
    class: []const u8,
    comment: []const u8,
    edge_url: []const u8,
    edge_href: []const u8,
    edge_tooltip: []const u8,
    edge_target: []const u8,
    label_url: []const u8,
    label_href: []const u8,
    label_tooltip: []const u8,
    label_target: []const u8,
    head_url: []const u8,
    head_href: []const u8,
    head_tooltip: []const u8,
    head_target: []const u8,
    tail_url: []const u8,
    tail_href: []const u8,
    tail_tooltip: []const u8,
    tail_target: []const u8,
    arrowhead: ArrowShape,
    arrowtail: ArrowShape,
    arrowsize: f64,
    dir: EdgeDir,
    taillabel: []const u8,
    headlabel: []const u8,
    xlabel: []const u8,
    labelfontcolor: []const u8,
    labelfontname: []const u8,
    labelfontsize: f64,
    labeldistance: f64,
    labelangle: f64,
    decorate: bool,
    tailclip: bool,
    headclip: bool,
    samehead: []const u8,
    sametail: []const u8,
    tail_port: EdgePort,
    head_port: EdgePort,
    ltail: SubgraphId,
    lhead: SubgraphId,
};

pub const SubgraphAttr = union(enum) {
    label: []const u8,
    rankdir: RankDir,
    layout: LayoutAlgorithm,
    compound: bool,
    concentrate: bool,
    nodesep: f64,
    ranksep: RankSep,
    splines: SplineMode,
    bgcolor: []const u8,
    ordering: OrderingMode,
    color: []const u8,
    pencolor: []const u8,
    fillcolor: []const u8,
    gradientangle: f64,
    fontcolor: []const u8,
    fontname: []const u8,
    fontsize: f64,
    style: SubgraphStyle,
    styles: []const SubgraphStyle,
    penwidth: f64,
    peripheries: usize,
    margin: []const u8,
    labelloc: LabelLoc,
    labeljust: LabelJust,
    url: []const u8,
    href: []const u8,
    tooltip: []const u8,
    title: []const u8,
    target: []const u8,
    id: []const u8,
    class: []const u8,
};

pub const SubgraphOptions = struct {
    label: ?[]const u8 = null,
    rankdir: ?RankDir = null,
    layout: ?LayoutAlgorithm = null,
    compound: ?bool = null,
    concentrate: ?bool = null,
    nodesep: ?f64 = null,
    ranksep: ?RankSep = null,
    splines: ?SplineMode = null,
    bgcolor: ?[]const u8 = null,
    ordering: ?OrderingMode = null,
    color: ?[]const u8 = null,
    pencolor: ?[]const u8 = null,
    fillcolor: ?[]const u8 = null,
    gradientangle: ?f64 = null,
    fontcolor: ?[]const u8 = null,
    fontname: ?[]const u8 = null,
    fontsize: ?f64 = null,
    style: ?SubgraphStyle = null,
    styles: []const SubgraphStyle = &.{},
    penwidth: ?f64 = null,
    peripheries: ?usize = null,
    margin: ?[]const u8 = null,
    labelloc: ?LabelLoc = null,
    labeljust: ?LabelJust = null,
    url: ?[]const u8 = null,
    href: ?[]const u8 = null,
    tooltip: ?[]const u8 = null,
    title: ?[]const u8 = null,
    target: ?[]const u8 = null,
    id: ?[]const u8 = null,
    class: ?[]const u8 = null,
};

pub const Node = struct {
    id: NodeId,
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
    ltail: ?SubgraphId = null,
    lhead: ?SubgraphId = null,
    attrs: std.ArrayList(Attr) = .empty,
};

pub const Subgraph = struct {
    id: SubgraphId,
    parent: ?SubgraphId = null,
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
    subgraphs: std.ArrayList(Subgraph) = .empty,
    rank_constraints: std.ArrayList(RankConstraint) = .empty,
    attrs: std.ArrayList(Attr) = .empty,
    node_default_attrs: std.ArrayList(Attr) = .empty,
    edge_default_attrs: std.ArrayList(Attr) = .empty,
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
            .node_defaults = .{ .color = node_color },
            .edge_defaults = .{ .color = edge_color },
        };
    }

    pub fn deinit(self: *Graph) void {
        for (self.nodes.items) |*n| {
            self.allocator.free(n.label);
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
        for (self.subgraphs.items) |*cluster| {
            self.allocator.free(cluster.label);
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
        self.subgraphs.deinit(self.allocator);
        self.rank_constraints.deinit(self.allocator);
        self.attrs.deinit(self.allocator);
        self.allocator.free(self.node_defaults.color);
        self.allocator.free(self.edge_defaults.color);
        self.allocator.free(self.name);
        self.* = undefined;
    }

    pub fn addNode(self: *Graph, label: []const u8, options: NodeOptions) !NodeId {
        const owned_label = try self.allocator.dupe(u8, label);
        errdefer self.allocator.free(owned_label);

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
            .label = owned_label,
            .color = owned_color,
            .shape = self.node_defaults.shape,
            .attrs = attrs,
        };
        try self.nodes.append(self.allocator, n);
        errdefer _ = self.removeLastNode(id);
        try self.applyNodeOptions(id, options);
        return id;
    }

    fn removeLastNode(self: *Graph, id: NodeId) bool {
        if (id + 1 != self.nodes.items.len) return false;
        var node = self.nodes.pop().?;
        self.allocator.free(node.label);
        self.allocator.free(node.color);
        freeAttrList(self.allocator, &node.attrs);
        return true;
    }

    pub fn addEdge(self: *Graph, from: NodeId, to: NodeId, options: EdgeOptions) !EdgeId {
        if (from >= self.nodes.items.len or to >= self.nodes.items.len) return error.InvalidNodeId;
        if (self.strict) {
            for (self.edges.items) |existing| {
                const same_directed = existing.from == from and existing.to == to;
                const same_undirected = !self.directed and existing.from == to and existing.to == from;
                if (same_directed or same_undirected) return existing.id;
            }
        }

        const owned_label = if (options.label) |label| try self.allocator.dupe(u8, label) else null;
        errdefer if (owned_label) |label| self.allocator.free(label);
        const owned_color = try self.allocator.dupe(u8, options.color orelse self.edge_defaults.color);
        errdefer self.allocator.free(owned_color);
        const owned_tail_record_port = if (options.tail_record_port) |port| try self.allocator.dupe(u8, port) else null;
        errdefer if (owned_tail_record_port) |port| self.allocator.free(port);
        const owned_head_record_port = if (options.head_record_port) |port| try self.allocator.dupe(u8, port) else null;
        errdefer if (owned_head_record_port) |port| self.allocator.free(port);
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
            .ltail = options.ltail,
            .lhead = options.lhead,
            .attrs = attrs,
        };
        try self.edges.append(self.allocator, e);
        errdefer _ = self.removeLastEdge(id);
        try self.applyEdgeOptions(id, options);
        return id;
    }

    fn removeLastEdge(self: *Graph, id: EdgeId) bool {
        if (id + 1 != self.edges.items.len) return false;
        var edge = self.edges.pop().?;
        if (edge.label) |label| self.allocator.free(label);
        if (edge.tail_record_port) |port| self.allocator.free(port);
        if (edge.head_record_port) |port| self.allocator.free(port);
        self.allocator.free(edge.color);
        freeAttrList(self.allocator, &edge.attrs);
        return true;
    }

    pub fn addRankConstraint(self: *Graph, kind: RankKind, node_ids: []const NodeId) !void {
        if (node_ids.len == 0) return;
        const owned_nodes = try self.allocator.dupe(NodeId, node_ids);
        errdefer self.allocator.free(owned_nodes);
        try self.rank_constraints.append(self.allocator, .{ .kind = kind, .node_ids = owned_nodes });
    }

    pub fn addSubgraph(self: *Graph, label: []const u8, parent: ?SubgraphId, node_ids: []const NodeId, options: SubgraphOptions) !SubgraphId {
        const id = try self.addSubgraphRaw(label, parent, node_ids, &.{});
        errdefer _ = self.removeLastSubgraph(id);
        try self.applySubgraphOptions(id, options);
        return id;
    }

    fn addSubgraphRaw(self: *Graph, label: []const u8, parent: ?SubgraphId, node_ids: []const NodeId, attrs: []const Attr) !SubgraphId {
        const owned_nodes = try self.allocator.dupe(NodeId, node_ids);
        errdefer self.allocator.free(owned_nodes);
        var owned_attrs = try copyAttrList(self.allocator, attrs);
        errdefer freeAttrList(self.allocator, &owned_attrs);
        const label_value = attrValue(owned_attrs.items, "label") orelse label;
        const owned_label = try self.allocator.dupe(u8, label_value);
        errdefer self.allocator.free(owned_label);
        const id = self.subgraphs.items.len;
        try self.subgraphs.append(self.allocator, .{
            .id = id,
            .parent = parent,
            .label = owned_label,
            .nodes = owned_nodes,
            .attrs = owned_attrs,
        });
        return id;
    }

    fn removeLastSubgraph(self: *Graph, id: SubgraphId) bool {
        if (id + 1 != self.subgraphs.items.len) return false;
        var subgraph = self.subgraphs.pop().?;
        self.allocator.free(subgraph.label);
        self.allocator.free(subgraph.nodes);
        freeAttrList(self.allocator, &subgraph.attrs);
        return true;
    }

    pub fn setSubgraphContent(self: *Graph, id: SubgraphId, node_ids: []const NodeId, options: SubgraphOptions) !void {
        try self.setSubgraphContentRaw(id, node_ids, &.{});
        try self.applySubgraphOptions(id, options);
    }

    fn setSubgraphContentRaw(self: *Graph, id: SubgraphId, node_ids: []const NodeId, attrs: []const Attr) !void {
        if (id >= self.subgraphs.items.len) return error.InvalidSubgraphId;
        var subgraph = &self.subgraphs.items[id];
        const owned_nodes = try self.allocator.dupe(NodeId, node_ids);
        errdefer self.allocator.free(owned_nodes);
        var owned_attrs = try copyAttrList(self.allocator, attrs);
        errdefer freeAttrList(self.allocator, &owned_attrs);
        const label_value = attrValue(owned_attrs.items, "label") orelse subgraph.label;
        const owned_label = try self.allocator.dupe(u8, label_value);
        errdefer self.allocator.free(owned_label);

        self.allocator.free(subgraph.label);
        self.allocator.free(subgraph.nodes);
        freeAttrList(self.allocator, &subgraph.attrs);
        subgraph.label = owned_label;
        subgraph.nodes = owned_nodes;
        subgraph.attrs = owned_attrs;
    }

    pub fn setGraphAttr(self: *Graph, attr: GraphAttr) !void {
        switch (attr) {
            .label => |value| try self.setGraphAttrRaw("label", value),
            .rankdir => |value| {
                self.rankdir = value;
                try self.setGraphAttrRaw("rankdir", rankDirName(value));
            },
            .layout => |value| try self.setGraphAttrRaw("layout", layoutAlgorithmName(value)),
            .compound => |value| try self.setGraphAttrRaw("compound", boolAttrValue(value)),
            .concentrate => |value| try self.setGraphAttrRaw("concentrate", boolAttrValue(value)),
            .nodesep => |value| try self.setGraphAttrFloat("nodesep", value),
            .ranksep => |value| switch (value) {
                .value => |spacing| try self.setGraphAttrFloat("ranksep", spacing),
                .equally => |spacing| {
                    var buffer: [64]u8 = undefined;
                    const text = try std.fmt.bufPrint(&buffer, "{d} equally", .{spacing});
                    try self.setGraphAttrRaw("ranksep", text);
                },
            },
            .splines => |value| try self.setGraphAttrRaw("splines", splineModeName(value)),
            .samplepoints => |value| {
                var buffer: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
                try self.setGraphAttrRaw("samplepoints", text);
            },
            .bgcolor => |value| try self.setGraphAttrRaw("bgcolor", value),
            .pad => |value| try self.setGraphAttrRaw("pad", value),
            .margin => |value| try self.setGraphAttrRaw("margin", value),
            .fontname => |value| try self.setGraphAttrRaw("fontname", value),
            .fontsize => |value| try self.setGraphAttrFloat("fontsize", value),
            .fontcolor => |value| try self.setGraphAttrRaw("fontcolor", value),
            .labeljust => |value| try self.setGraphAttrRaw("labeljust", labelJustName(value)),
            .labelloc => |value| try self.setGraphAttrRaw("labelloc", labelLocName(value)),
            .ordering => |value| try self.setGraphAttrRaw("ordering", orderingModeName(value)),
            .url => |value| try self.setGraphAttrRaw("URL", value),
            .href => |value| try self.setGraphAttrRaw("href", value),
            .tooltip => |value| try self.setGraphAttrRaw("tooltip", value),
            .title => |value| try self.setGraphAttrRaw("title", value),
            .target => |value| try self.setGraphAttrRaw("target", value),
            .id => |value| try self.setGraphAttrRaw("id", value),
            .class => |value| try self.setGraphAttrRaw("class", value),
            .stylesheet => |value| try self.setGraphAttrRaw("stylesheet", value),
            .comment => |value| try self.setGraphAttrRaw("comment", value),
        }
    }

    fn setGraphAttrFloat(self: *Graph, name: []const u8, value: f64) !void {
        var buffer: [64]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
        try self.setGraphAttrRaw(name, text);
    }

    fn setGraphAttrRaw(self: *Graph, name: []const u8, value: []const u8) !void {
        if (std.ascii.eqlIgnoreCase(name, "rankdir")) {
            if (RankDir.fromString(value)) |rankdir| self.rankdir = rankdir;
        }
        try setAttrInList(self.allocator, &self.attrs, name, value);
    }

    pub fn setDefaultNodeAttr(self: *Graph, attr: NodeAttr) !void {
        switch (attr) {
            .label => |value| try self.setDefaultNodeAttrRaw("label", value),
            .color => |value| try self.setDefaultNodeAttrRaw("color", value),
            .fillcolor => |value| try self.setDefaultNodeAttrRaw("fillcolor", value),
            .gradientangle => |value| try self.setDefaultNodeAttrFloat("gradientangle", value),
            .fontcolor => |value| try self.setDefaultNodeAttrRaw("fontcolor", value),
            .fontname => |value| try self.setDefaultNodeAttrRaw("fontname", value),
            .fontsize => |value| try self.setDefaultNodeAttrFloat("fontsize", value),
            .shape => |value| try self.setDefaultNodeAttrRaw("shape", shapeName(value)),
            .style => |value| try self.setDefaultNodeAttrRaw("style", nodeStyleName(value)),
            .styles => |values| try setDefaultNodeStylesAttrRaw(self, values),
            .penwidth => |value| try self.setDefaultNodeAttrFloat("penwidth", value),
            .peripheries => |value| {
                var buffer: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
                try self.setDefaultNodeAttrRaw("peripheries", text);
            },
            .sides => |value| {
                var buffer: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
                try self.setDefaultNodeAttrRaw("sides", text);
            },
            .regular => |value| try self.setDefaultNodeAttrRaw("regular", boolAttrValue(value)),
            .orientation => |value| try self.setDefaultNodeAttrFloat("orientation", value),
            .skew => |value| try self.setDefaultNodeAttrFloat("skew", value),
            .distortion => |value| try self.setDefaultNodeAttrFloat("distortion", value),
            .width => |value| try self.setDefaultNodeAttrFloat("width", value),
            .height => |value| try self.setDefaultNodeAttrFloat("height", value),
            .fixedsize => |value| try self.setDefaultNodeAttrRaw("fixedsize", nodeFixedSizeName(value)),
            .margin => |value| try self.setDefaultNodeAttrRaw("margin", value),
            .xlabel => |value| try self.setDefaultNodeAttrRaw("xlabel", value),
            .labelloc => |value| try self.setDefaultNodeAttrRaw("labelloc", labelLocName(value)),
            .labeljust => |value| try self.setDefaultNodeAttrRaw("labeljust", labelJustName(value)),
            .url => |value| try self.setDefaultNodeAttrRaw("URL", value),
            .href => |value| try self.setDefaultNodeAttrRaw("href", value),
            .tooltip => |value| try self.setDefaultNodeAttrRaw("tooltip", value),
            .title => |value| try self.setDefaultNodeAttrRaw("title", value),
            .target => |value| try self.setDefaultNodeAttrRaw("target", value),
            .id => |value| try self.setDefaultNodeAttrRaw("id", value),
            .class => |value| try self.setDefaultNodeAttrRaw("class", value),
            .comment => |value| try self.setDefaultNodeAttrRaw("comment", value),
            .ordering => |value| try self.setDefaultNodeAttrRaw("ordering", orderingModeName(value)),
            .group => |value| try self.setDefaultNodeAttrRaw("group", value),
        }
    }

    fn setDefaultNodeAttrFloat(self: *Graph, name: []const u8, value: f64) !void {
        var buffer: [64]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
        try self.setDefaultNodeAttrRaw(name, text);
    }

    fn setDefaultNodeAttrRaw(self: *Graph, name: []const u8, value: []const u8) !void {
        try setAttrInList(self.allocator, &self.node_default_attrs, name, value);
        if (std.ascii.eqlIgnoreCase(name, "color")) {
            const owned = try self.allocator.dupe(u8, value);
            self.allocator.free(self.node_defaults.color);
            self.node_defaults.color = owned;
        } else if (std.ascii.eqlIgnoreCase(name, "shape")) {
            self.node_defaults.shape = parseShape(value);
        }
    }

    pub fn setDefaultEdgeAttr(self: *Graph, attr: EdgeAttr) !void {
        switch (attr) {
            .label => |value| try self.setDefaultEdgeAttrRaw("label", value),
            .color => |value| try self.setDefaultEdgeAttrRaw("color", value),
            .fillcolor => |value| try self.setDefaultEdgeAttrRaw("fillcolor", value),
            .fontcolor => |value| try self.setDefaultEdgeAttrRaw("fontcolor", value),
            .fontname => |value| try self.setDefaultEdgeAttrRaw("fontname", value),
            .fontsize => |value| try self.setDefaultEdgeAttrFloat("fontsize", value),
            .style => |value| try self.setDefaultEdgeAttrRaw("style", edgeStyleName(value)),
            .styles => |values| try setDefaultEdgeStylesAttrRaw(self, values),
            .penwidth => |value| try self.setDefaultEdgeAttrFloat("penwidth", value),
            .weight => |value| try self.setDefaultEdgeAttrFloat("weight", value),
            .constraint => |value| try self.setDefaultEdgeAttrRaw("constraint", boolAttrValue(value)),
            .min_len => |value| {
                var buffer: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
                try self.setDefaultEdgeAttrRaw("minlen", text);
            },
            .url => |value| try self.setDefaultEdgeAttrRaw("URL", value),
            .href => |value| try self.setDefaultEdgeAttrRaw("href", value),
            .tooltip => |value| try self.setDefaultEdgeAttrRaw("tooltip", value),
            .title => |value| try self.setDefaultEdgeAttrRaw("title", value),
            .target => |value| try self.setDefaultEdgeAttrRaw("target", value),
            .id => |value| try self.setDefaultEdgeAttrRaw("id", value),
            .class => |value| try self.setDefaultEdgeAttrRaw("class", value),
            .comment => |value| try self.setDefaultEdgeAttrRaw("comment", value),
            .edge_url => |value| try self.setDefaultEdgeAttrRaw("edgeURL", value),
            .edge_href => |value| try self.setDefaultEdgeAttrRaw("edgehref", value),
            .edge_tooltip => |value| try self.setDefaultEdgeAttrRaw("edgetooltip", value),
            .edge_target => |value| try self.setDefaultEdgeAttrRaw("edgetarget", value),
            .label_url => |value| try self.setDefaultEdgeAttrRaw("labelURL", value),
            .label_href => |value| try self.setDefaultEdgeAttrRaw("labelhref", value),
            .label_tooltip => |value| try self.setDefaultEdgeAttrRaw("labeltooltip", value),
            .label_target => |value| try self.setDefaultEdgeAttrRaw("labeltarget", value),
            .head_url => |value| try self.setDefaultEdgeAttrRaw("headURL", value),
            .head_href => |value| try self.setDefaultEdgeAttrRaw("headhref", value),
            .head_tooltip => |value| try self.setDefaultEdgeAttrRaw("headtooltip", value),
            .head_target => |value| try self.setDefaultEdgeAttrRaw("headtarget", value),
            .tail_url => |value| try self.setDefaultEdgeAttrRaw("tailURL", value),
            .tail_href => |value| try self.setDefaultEdgeAttrRaw("tailhref", value),
            .tail_tooltip => |value| try self.setDefaultEdgeAttrRaw("tailtooltip", value),
            .tail_target => |value| try self.setDefaultEdgeAttrRaw("tailtarget", value),
            .arrowhead => |value| try self.setDefaultEdgeAttrRaw("arrowhead", arrowShapeName(value)),
            .arrowtail => |value| try self.setDefaultEdgeAttrRaw("arrowtail", arrowShapeName(value)),
            .arrowsize => |value| try self.setDefaultEdgeAttrFloat("arrowsize", value),
            .dir => |value| try self.setDefaultEdgeAttrRaw("dir", edgeDirName(value)),
            .taillabel => |value| try self.setDefaultEdgeAttrRaw("taillabel", value),
            .headlabel => |value| try self.setDefaultEdgeAttrRaw("headlabel", value),
            .xlabel => |value| try self.setDefaultEdgeAttrRaw("xlabel", value),
            .labelfontcolor => |value| try self.setDefaultEdgeAttrRaw("labelfontcolor", value),
            .labelfontname => |value| try self.setDefaultEdgeAttrRaw("labelfontname", value),
            .labelfontsize => |value| try self.setDefaultEdgeAttrFloat("labelfontsize", value),
            .labeldistance => |value| try self.setDefaultEdgeAttrFloat("labeldistance", value),
            .labelangle => |value| try self.setDefaultEdgeAttrFloat("labelangle", value),
            .decorate => |value| try self.setDefaultEdgeAttrRaw("decorate", boolAttrValue(value)),
            .tailclip => |value| try self.setDefaultEdgeAttrRaw("tailclip", boolAttrValue(value)),
            .headclip => |value| try self.setDefaultEdgeAttrRaw("headclip", boolAttrValue(value)),
            .samehead => |value| try self.setDefaultEdgeAttrRaw("samehead", value),
            .sametail => |value| try self.setDefaultEdgeAttrRaw("sametail", value),
        }
    }

    fn setDefaultEdgeAttrFloat(self: *Graph, name: []const u8, value: f64) !void {
        var buffer: [64]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
        try self.setDefaultEdgeAttrRaw(name, text);
    }

    fn setDefaultEdgeAttrRaw(self: *Graph, name: []const u8, value: []const u8) !void {
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

    fn applyNodeOptions(self: *Graph, id: NodeId, options: NodeOptions) !void {
        if (options.label) |value| try self.setNodeAttr(id, .{ .label = value });
        if (options.color) |value| try self.setNodeAttr(id, .{ .color = value });
        if (options.fillcolor) |value| try self.setNodeAttr(id, .{ .fillcolor = value });
        if (options.gradientangle) |value| try self.setNodeAttr(id, .{ .gradientangle = value });
        if (options.fontcolor) |value| try self.setNodeAttr(id, .{ .fontcolor = value });
        if (options.fontname) |value| try self.setNodeAttr(id, .{ .fontname = value });
        if (options.fontsize) |value| try self.setNodeAttr(id, .{ .fontsize = value });
        if (options.shape) |value| try self.setNodeAttr(id, .{ .shape = value });
        if (options.style) |value| try self.setNodeAttr(id, .{ .style = value });
        if (options.styles.len > 0) try self.setNodeAttr(id, .{ .styles = options.styles });
        if (options.penwidth) |value| try self.setNodeAttr(id, .{ .penwidth = value });
        if (options.peripheries) |value| try self.setNodeAttr(id, .{ .peripheries = value });
        if (options.sides) |value| try self.setNodeAttr(id, .{ .sides = value });
        if (options.regular) |value| try self.setNodeAttr(id, .{ .regular = value });
        if (options.orientation) |value| try self.setNodeAttr(id, .{ .orientation = value });
        if (options.skew) |value| try self.setNodeAttr(id, .{ .skew = value });
        if (options.distortion) |value| try self.setNodeAttr(id, .{ .distortion = value });
        if (options.width) |value| try self.setNodeAttr(id, .{ .width = value });
        if (options.height) |value| try self.setNodeAttr(id, .{ .height = value });
        if (options.fixedsize) |value| try self.setNodeAttr(id, .{ .fixedsize = value });
        if (options.margin) |value| try self.setNodeAttr(id, .{ .margin = value });
        if (options.xlabel) |value| try self.setNodeAttr(id, .{ .xlabel = value });
        if (options.labelloc) |value| try self.setNodeAttr(id, .{ .labelloc = value });
        if (options.labeljust) |value| try self.setNodeAttr(id, .{ .labeljust = value });
        if (options.url) |value| try self.setNodeAttr(id, .{ .url = value });
        if (options.href) |value| try self.setNodeAttr(id, .{ .href = value });
        if (options.tooltip) |value| try self.setNodeAttr(id, .{ .tooltip = value });
        if (options.title) |value| try self.setNodeAttr(id, .{ .title = value });
        if (options.target) |value| try self.setNodeAttr(id, .{ .target = value });
        if (options.id) |value| try self.setNodeAttr(id, .{ .id = value });
        if (options.class) |value| try self.setNodeAttr(id, .{ .class = value });
        if (options.comment) |value| try self.setNodeAttr(id, .{ .comment = value });
        if (options.ordering) |value| try self.setNodeAttr(id, .{ .ordering = value });
        if (options.group) |value| try self.setNodeAttr(id, .{ .group = value });
    }

    pub fn setNodeAttr(self: *Graph, id: NodeId, attr: NodeAttr) !void {
        switch (attr) {
            .label => |value| try self.setNodeAttrRaw(id, "label", value),
            .color => |value| try self.setNodeAttrRaw(id, "color", value),
            .fillcolor => |value| try self.setNodeAttrRaw(id, "fillcolor", value),
            .gradientangle => |value| try self.setNodeAttrFloat(id, "gradientangle", value),
            .fontcolor => |value| try self.setNodeAttrRaw(id, "fontcolor", value),
            .fontname => |value| try self.setNodeAttrRaw(id, "fontname", value),
            .fontsize => |value| try self.setNodeAttrFloat(id, "fontsize", value),
            .shape => |value| try self.setNodeShape(id, value),
            .style => |value| try self.setNodeAttrRaw(id, "style", nodeStyleName(value)),
            .styles => |values| try setNodeStylesAttrRaw(self, id, values),
            .penwidth => |value| try self.setNodeAttrFloat(id, "penwidth", value),
            .peripheries => |value| {
                var buffer: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
                try self.setNodeAttrRaw(id, "peripheries", text);
            },
            .sides => |value| {
                var buffer: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
                try self.setNodeAttrRaw(id, "sides", text);
            },
            .regular => |value| try self.setNodeAttrRaw(id, "regular", boolAttrValue(value)),
            .orientation => |value| try self.setNodeAttrFloat(id, "orientation", value),
            .skew => |value| try self.setNodeAttrFloat(id, "skew", value),
            .distortion => |value| try self.setNodeAttrFloat(id, "distortion", value),
            .width => |value| try self.setNodeAttrFloat(id, "width", value),
            .height => |value| try self.setNodeAttrFloat(id, "height", value),
            .fixedsize => |value| try self.setNodeAttrRaw(id, "fixedsize", nodeFixedSizeName(value)),
            .margin => |value| try self.setNodeAttrRaw(id, "margin", value),
            .xlabel => |value| try self.setNodeAttrRaw(id, "xlabel", value),
            .labelloc => |value| try self.setNodeAttrRaw(id, "labelloc", labelLocName(value)),
            .labeljust => |value| try self.setNodeAttrRaw(id, "labeljust", labelJustName(value)),
            .url => |value| try self.setNodeAttrRaw(id, "URL", value),
            .href => |value| try self.setNodeAttrRaw(id, "href", value),
            .tooltip => |value| try self.setNodeAttrRaw(id, "tooltip", value),
            .title => |value| try self.setNodeAttrRaw(id, "title", value),
            .target => |value| try self.setNodeAttrRaw(id, "target", value),
            .id => |value| try self.setNodeAttrRaw(id, "id", value),
            .class => |value| try self.setNodeAttrRaw(id, "class", value),
            .comment => |value| try self.setNodeAttrRaw(id, "comment", value),
            .ordering => |value| try self.setNodeAttrRaw(id, "ordering", orderingModeName(value)),
            .group => |value| try self.setNodeAttrRaw(id, "group", value),
        }
    }

    fn setNodeAttrFloat(self: *Graph, id: NodeId, name: []const u8, value: f64) !void {
        var buffer: [64]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
        try self.setNodeAttrRaw(id, name, text);
    }

    fn setNodeAttrRaw(self: *Graph, id: NodeId, name: []const u8, value: []const u8) !void {
        if (id >= self.nodes.items.len) return error.InvalidNodeId;
        var n = &self.nodes.items[id];
        if (std.ascii.eqlIgnoreCase(name, "label")) {
            const expanded = try self.allocator.dupe(u8, value);
            self.allocator.free(n.label);
            n.label = expanded;
        } else if (std.ascii.eqlIgnoreCase(name, "color")) {
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

    fn applyEdgeOptions(self: *Graph, id: EdgeId, options: EdgeOptions) !void {
        if (options.label) |value| try self.setEdgeAttr(id, .{ .label = value });
        if (options.color) |value| try self.setEdgeAttr(id, .{ .color = value });
        if (options.fillcolor) |value| try self.setEdgeAttr(id, .{ .fillcolor = value });
        if (options.fontcolor) |value| try self.setEdgeAttr(id, .{ .fontcolor = value });
        if (options.fontname) |value| try self.setEdgeAttr(id, .{ .fontname = value });
        if (options.fontsize) |value| try self.setEdgeAttr(id, .{ .fontsize = value });
        if (options.style) |value| try self.setEdgeAttr(id, .{ .style = value });
        if (options.styles.len > 0) try self.setEdgeAttr(id, .{ .styles = options.styles });
        if (options.penwidth) |value| try self.setEdgeAttr(id, .{ .penwidth = value });
        if (options.weight) |value| try self.setEdgeAttr(id, .{ .weight = value });
        if (options.constraint) |value| try self.setEdgeAttr(id, .{ .constraint = value });
        if (options.min_len) |value| try self.setEdgeAttr(id, .{ .min_len = value });
        if (options.url) |value| try self.setEdgeAttr(id, .{ .url = value });
        if (options.href) |value| try self.setEdgeAttr(id, .{ .href = value });
        if (options.tooltip) |value| try self.setEdgeAttr(id, .{ .tooltip = value });
        if (options.title) |value| try self.setEdgeAttr(id, .{ .title = value });
        if (options.target) |value| try self.setEdgeAttr(id, .{ .target = value });
        if (options.id) |value| try self.setEdgeAttr(id, .{ .id = value });
        if (options.class) |value| try self.setEdgeAttr(id, .{ .class = value });
        if (options.comment) |value| try self.setEdgeAttr(id, .{ .comment = value });
        if (options.edge_url) |value| try self.setEdgeAttr(id, .{ .edge_url = value });
        if (options.edge_href) |value| try self.setEdgeAttr(id, .{ .edge_href = value });
        if (options.edge_tooltip) |value| try self.setEdgeAttr(id, .{ .edge_tooltip = value });
        if (options.edge_target) |value| try self.setEdgeAttr(id, .{ .edge_target = value });
        if (options.label_url) |value| try self.setEdgeAttr(id, .{ .label_url = value });
        if (options.label_href) |value| try self.setEdgeAttr(id, .{ .label_href = value });
        if (options.label_tooltip) |value| try self.setEdgeAttr(id, .{ .label_tooltip = value });
        if (options.label_target) |value| try self.setEdgeAttr(id, .{ .label_target = value });
        if (options.head_url) |value| try self.setEdgeAttr(id, .{ .head_url = value });
        if (options.head_href) |value| try self.setEdgeAttr(id, .{ .head_href = value });
        if (options.head_tooltip) |value| try self.setEdgeAttr(id, .{ .head_tooltip = value });
        if (options.head_target) |value| try self.setEdgeAttr(id, .{ .head_target = value });
        if (options.tail_url) |value| try self.setEdgeAttr(id, .{ .tail_url = value });
        if (options.tail_href) |value| try self.setEdgeAttr(id, .{ .tail_href = value });
        if (options.tail_tooltip) |value| try self.setEdgeAttr(id, .{ .tail_tooltip = value });
        if (options.tail_target) |value| try self.setEdgeAttr(id, .{ .tail_target = value });
        if (options.arrowhead) |value| try self.setEdgeAttr(id, .{ .arrowhead = value });
        if (options.arrowtail) |value| try self.setEdgeAttr(id, .{ .arrowtail = value });
        if (options.arrowsize) |value| try self.setEdgeAttr(id, .{ .arrowsize = value });
        if (options.dir) |value| try self.setEdgeAttr(id, .{ .dir = value });
        if (options.taillabel) |value| try self.setEdgeAttr(id, .{ .taillabel = value });
        if (options.headlabel) |value| try self.setEdgeAttr(id, .{ .headlabel = value });
        if (options.xlabel) |value| try self.setEdgeAttr(id, .{ .xlabel = value });
        if (options.labelfontcolor) |value| try self.setEdgeAttr(id, .{ .labelfontcolor = value });
        if (options.labelfontname) |value| try self.setEdgeAttr(id, .{ .labelfontname = value });
        if (options.labelfontsize) |value| try self.setEdgeAttr(id, .{ .labelfontsize = value });
        if (options.labeldistance) |value| try self.setEdgeAttr(id, .{ .labeldistance = value });
        if (options.labelangle) |value| try self.setEdgeAttr(id, .{ .labelangle = value });
        if (options.decorate) |value| try self.setEdgeAttr(id, .{ .decorate = value });
        if (options.tailclip) |value| try self.setEdgeAttr(id, .{ .tailclip = value });
        if (options.headclip) |value| try self.setEdgeAttr(id, .{ .headclip = value });
        if (options.samehead) |value| try self.setEdgeAttr(id, .{ .samehead = value });
        if (options.sametail) |value| try self.setEdgeAttr(id, .{ .sametail = value });
        if (options.tail_port != .auto or options.tail_record_port != null) try self.setEdgeAttr(id, .{ .tail_port = .{ .record = options.tail_record_port, .compass = options.tail_port } });
        if (options.head_port != .auto or options.head_record_port != null) try self.setEdgeAttr(id, .{ .head_port = .{ .record = options.head_record_port, .compass = options.head_port } });
        if (options.ltail) |value| try self.setEdgeAttr(id, .{ .ltail = value });
        if (options.lhead) |value| try self.setEdgeAttr(id, .{ .lhead = value });
    }

    pub fn setEdgeAttr(self: *Graph, id: EdgeId, attr: EdgeAttr) !void {
        switch (attr) {
            .label => |value| try self.setEdgeAttrRaw(id, "label", value),
            .color => |value| try self.setEdgeAttrRaw(id, "color", value),
            .fillcolor => |value| try self.setEdgeAttrRaw(id, "fillcolor", value),
            .fontcolor => |value| try self.setEdgeAttrRaw(id, "fontcolor", value),
            .fontname => |value| try self.setEdgeAttrRaw(id, "fontname", value),
            .fontsize => |value| try self.setEdgeAttrFloat(id, "fontsize", value),
            .style => |value| try self.setEdgeAttrRaw(id, "style", edgeStyleName(value)),
            .styles => |values| try setEdgeStylesAttrRaw(self, id, values),
            .penwidth => |value| try self.setEdgeAttrFloat(id, "penwidth", value),
            .weight => |value| try self.setEdgeAttrFloat(id, "weight", value),
            .constraint => |value| try self.setEdgeAttrRaw(id, "constraint", boolAttrValue(value)),
            .min_len => |value| {
                var buffer: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
                try self.setEdgeAttrRaw(id, "minlen", text);
            },
            .url => |value| try self.setEdgeAttrRaw(id, "URL", value),
            .href => |value| try self.setEdgeAttrRaw(id, "href", value),
            .tooltip => |value| try self.setEdgeAttrRaw(id, "tooltip", value),
            .title => |value| try self.setEdgeAttrRaw(id, "title", value),
            .target => |value| try self.setEdgeAttrRaw(id, "target", value),
            .id => |value| try self.setEdgeAttrRaw(id, "id", value),
            .class => |value| try self.setEdgeAttrRaw(id, "class", value),
            .comment => |value| try self.setEdgeAttrRaw(id, "comment", value),
            .edge_url => |value| try self.setEdgeAttrRaw(id, "edgeURL", value),
            .edge_href => |value| try self.setEdgeAttrRaw(id, "edgehref", value),
            .edge_tooltip => |value| try self.setEdgeAttrRaw(id, "edgetooltip", value),
            .edge_target => |value| try self.setEdgeAttrRaw(id, "edgetarget", value),
            .label_url => |value| try self.setEdgeAttrRaw(id, "labelURL", value),
            .label_href => |value| try self.setEdgeAttrRaw(id, "labelhref", value),
            .label_tooltip => |value| try self.setEdgeAttrRaw(id, "labeltooltip", value),
            .label_target => |value| try self.setEdgeAttrRaw(id, "labeltarget", value),
            .head_url => |value| try self.setEdgeAttrRaw(id, "headURL", value),
            .head_href => |value| try self.setEdgeAttrRaw(id, "headhref", value),
            .head_tooltip => |value| try self.setEdgeAttrRaw(id, "headtooltip", value),
            .head_target => |value| try self.setEdgeAttrRaw(id, "headtarget", value),
            .tail_url => |value| try self.setEdgeAttrRaw(id, "tailURL", value),
            .tail_href => |value| try self.setEdgeAttrRaw(id, "tailhref", value),
            .tail_tooltip => |value| try self.setEdgeAttrRaw(id, "tailtooltip", value),
            .tail_target => |value| try self.setEdgeAttrRaw(id, "tailtarget", value),
            .arrowhead => |value| try self.setEdgeAttrRaw(id, "arrowhead", arrowShapeName(value)),
            .arrowtail => |value| try self.setEdgeAttrRaw(id, "arrowtail", arrowShapeName(value)),
            .arrowsize => |value| try self.setEdgeAttrFloat(id, "arrowsize", value),
            .dir => |value| try self.setEdgeAttrRaw(id, "dir", edgeDirName(value)),
            .taillabel => |value| try self.setEdgeAttrRaw(id, "taillabel", value),
            .headlabel => |value| try self.setEdgeAttrRaw(id, "headlabel", value),
            .xlabel => |value| try self.setEdgeAttrRaw(id, "xlabel", value),
            .labelfontcolor => |value| try self.setEdgeAttrRaw(id, "labelfontcolor", value),
            .labelfontname => |value| try self.setEdgeAttrRaw(id, "labelfontname", value),
            .labelfontsize => |value| try self.setEdgeAttrFloat(id, "labelfontsize", value),
            .labeldistance => |value| try self.setEdgeAttrFloat(id, "labeldistance", value),
            .labelangle => |value| try self.setEdgeAttrFloat(id, "labelangle", value),
            .decorate => |value| try self.setEdgeAttrRaw(id, "decorate", boolAttrValue(value)),
            .tailclip => |value| try self.setEdgeAttrRaw(id, "tailclip", boolAttrValue(value)),
            .headclip => |value| try self.setEdgeAttrRaw(id, "headclip", boolAttrValue(value)),
            .samehead => |value| try self.setEdgeAttrRaw(id, "samehead", value),
            .sametail => |value| try self.setEdgeAttrRaw(id, "sametail", value),
            .tail_port => |value| try self.setEdgePortAttr(id, "tailport", value),
            .head_port => |value| try self.setEdgePortAttr(id, "headport", value),
            .ltail => |value| try self.setEdgeSubgraphAttr(id, "ltail", value),
            .lhead => |value| try self.setEdgeSubgraphAttr(id, "lhead", value),
        }
    }

    fn setEdgePortAttr(self: *Graph, id: EdgeId, name: []const u8, port: EdgePort) !void {
        if (id >= self.edges.items.len) return error.InvalidEdgeId;
        var edge = &self.edges.items[id];
        const owned_record = if (port.record) |record| try self.allocator.dupe(u8, record) else null;
        errdefer if (owned_record) |record| self.allocator.free(record);
        var text_buf: [128]u8 = undefined;
        const text = edgePortAttrText(&text_buf, port) catch return error.PortNameTooLong;
        if (std.ascii.eqlIgnoreCase(name, "tailport")) {
            if (edge.tail_record_port) |old| self.allocator.free(old);
            edge.tail_record_port = owned_record;
            edge.tail_port = port.compass;
        } else if (std.ascii.eqlIgnoreCase(name, "headport")) {
            if (edge.head_record_port) |old| self.allocator.free(old);
            edge.head_record_port = owned_record;
            edge.head_port = port.compass;
        }
        try self.setEdgeAttrRaw(id, name, text);
    }

    fn edgePortAttrText(buffer: []u8, port: EdgePort) ![]const u8 {
        if (port.record) |record| {
            if (port.compass == .auto) return record;
            return std.fmt.bufPrint(buffer, "{s}:{s}", .{ record, compassPortName(port.compass) });
        }
        return compassPortName(port.compass);
    }

    fn setEdgeSubgraphAttr(self: *Graph, id: EdgeId, name: []const u8, subgraph_id: SubgraphId) !void {
        if (id >= self.edges.items.len) return error.InvalidEdgeId;
        if (subgraph_id >= self.subgraphs.items.len) return error.InvalidSubgraphId;
        if (std.ascii.eqlIgnoreCase(name, "ltail")) {
            self.edges.items[id].ltail = subgraph_id;
        } else if (std.ascii.eqlIgnoreCase(name, "lhead")) {
            self.edges.items[id].lhead = subgraph_id;
        }
        try self.setEdgeAttrRaw(id, name, self.subgraphs.items[subgraph_id].label);
    }

    fn setEdgeAttrFloat(self: *Graph, id: EdgeId, name: []const u8, value: f64) !void {
        var buffer: [64]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
        try self.setEdgeAttrRaw(id, name, text);
    }

    fn setEdgeAttrRaw(self: *Graph, id: EdgeId, name: []const u8, value: []const u8) !void {
        if (id >= self.edges.items.len) return error.InvalidEdgeId;
        var e = &self.edges.items[id];
        if (std.ascii.eqlIgnoreCase(name, "label")) {
            const expanded = try self.allocator.dupe(u8, value);
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
        }
        try setAttrInList(self.allocator, &e.attrs, name, value);
    }

    fn applySubgraphOptions(self: *Graph, id: SubgraphId, options: SubgraphOptions) !void {
        if (options.label) |value| try self.setSubgraphAttr(id, .{ .label = value });
        if (options.rankdir) |value| try self.setSubgraphAttr(id, .{ .rankdir = value });
        if (options.layout) |value| try self.setSubgraphAttr(id, .{ .layout = value });
        if (options.compound) |value| try self.setSubgraphAttr(id, .{ .compound = value });
        if (options.concentrate) |value| try self.setSubgraphAttr(id, .{ .concentrate = value });
        if (options.nodesep) |value| try self.setSubgraphAttr(id, .{ .nodesep = value });
        if (options.ranksep) |value| try self.setSubgraphAttr(id, .{ .ranksep = value });
        if (options.splines) |value| try self.setSubgraphAttr(id, .{ .splines = value });
        if (options.bgcolor) |value| try self.setSubgraphAttr(id, .{ .bgcolor = value });
        if (options.ordering) |value| try self.setSubgraphAttr(id, .{ .ordering = value });
        if (options.color) |value| try self.setSubgraphAttr(id, .{ .color = value });
        if (options.pencolor) |value| try self.setSubgraphAttr(id, .{ .pencolor = value });
        if (options.fillcolor) |value| try self.setSubgraphAttr(id, .{ .fillcolor = value });
        if (options.gradientangle) |value| try self.setSubgraphAttr(id, .{ .gradientangle = value });
        if (options.fontcolor) |value| try self.setSubgraphAttr(id, .{ .fontcolor = value });
        if (options.fontname) |value| try self.setSubgraphAttr(id, .{ .fontname = value });
        if (options.fontsize) |value| try self.setSubgraphAttr(id, .{ .fontsize = value });
        if (options.style) |value| try self.setSubgraphAttr(id, .{ .style = value });
        if (options.styles.len > 0) try self.setSubgraphAttr(id, .{ .styles = options.styles });
        if (options.penwidth) |value| try self.setSubgraphAttr(id, .{ .penwidth = value });
        if (options.peripheries) |value| try self.setSubgraphAttr(id, .{ .peripheries = value });
        if (options.margin) |value| try self.setSubgraphAttr(id, .{ .margin = value });
        if (options.labelloc) |value| try self.setSubgraphAttr(id, .{ .labelloc = value });
        if (options.labeljust) |value| try self.setSubgraphAttr(id, .{ .labeljust = value });
        if (options.url) |value| try self.setSubgraphAttr(id, .{ .url = value });
        if (options.href) |value| try self.setSubgraphAttr(id, .{ .href = value });
        if (options.tooltip) |value| try self.setSubgraphAttr(id, .{ .tooltip = value });
        if (options.title) |value| try self.setSubgraphAttr(id, .{ .title = value });
        if (options.target) |value| try self.setSubgraphAttr(id, .{ .target = value });
        if (options.id) |value| try self.setSubgraphAttr(id, .{ .id = value });
        if (options.class) |value| try self.setSubgraphAttr(id, .{ .class = value });
    }

    pub fn setSubgraphAttr(self: *Graph, id: SubgraphId, attr: SubgraphAttr) !void {
        switch (attr) {
            .label => |value| try self.setSubgraphAttrRaw(id, "label", value),
            .rankdir => |value| try self.setSubgraphAttrRaw(id, "rankdir", rankDirName(value)),
            .layout => |value| try self.setSubgraphAttrRaw(id, "layout", layoutAlgorithmName(value)),
            .compound => |value| try self.setSubgraphAttrRaw(id, "compound", boolAttrValue(value)),
            .concentrate => |value| try self.setSubgraphAttrRaw(id, "concentrate", boolAttrValue(value)),
            .nodesep => |value| try self.setSubgraphAttrFloat(id, "nodesep", value),
            .ranksep => |value| switch (value) {
                .value => |spacing| try self.setSubgraphAttrFloat(id, "ranksep", spacing),
                .equally => |spacing| {
                    var buffer: [64]u8 = undefined;
                    const text = try std.fmt.bufPrint(&buffer, "{d} equally", .{spacing});
                    try self.setSubgraphAttrRaw(id, "ranksep", text);
                },
            },
            .splines => |value| try self.setSubgraphAttrRaw(id, "splines", splineModeName(value)),
            .bgcolor => |value| try self.setSubgraphAttrRaw(id, "bgcolor", value),
            .ordering => |value| try self.setSubgraphAttrRaw(id, "ordering", orderingModeName(value)),
            .color => |value| try self.setSubgraphAttrRaw(id, "color", value),
            .pencolor => |value| try self.setSubgraphAttrRaw(id, "pencolor", value),
            .fillcolor => |value| try self.setSubgraphAttrRaw(id, "fillcolor", value),
            .gradientangle => |value| try self.setSubgraphAttrFloat(id, "gradientangle", value),
            .fontcolor => |value| try self.setSubgraphAttrRaw(id, "fontcolor", value),
            .fontname => |value| try self.setSubgraphAttrRaw(id, "fontname", value),
            .fontsize => |value| try self.setSubgraphAttrFloat(id, "fontsize", value),
            .style => |value| try self.setSubgraphAttrRaw(id, "style", subgraphStyleName(value)),
            .styles => |values| {
                if (values.len == 0) return;
                var text = std.ArrayList(u8).empty;
                defer text.deinit(self.allocator);
                for (values, 0..) |value, index| {
                    if (index > 0) try text.append(self.allocator, ',');
                    try text.appendSlice(self.allocator, subgraphStyleName(value));
                }
                try self.setSubgraphAttrRaw(id, "style", text.items);
            },
            .penwidth => |value| try self.setSubgraphAttrFloat(id, "penwidth", value),
            .peripheries => |value| {
                var buffer: [32]u8 = undefined;
                const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
                try self.setSubgraphAttrRaw(id, "peripheries", text);
            },
            .margin => |value| try self.setSubgraphAttrRaw(id, "margin", value),
            .labelloc => |value| try self.setSubgraphAttrRaw(id, "labelloc", labelLocName(value)),
            .labeljust => |value| try self.setSubgraphAttrRaw(id, "labeljust", labelJustName(value)),
            .url => |value| try self.setSubgraphAttrRaw(id, "URL", value),
            .href => |value| try self.setSubgraphAttrRaw(id, "href", value),
            .tooltip => |value| try self.setSubgraphAttrRaw(id, "tooltip", value),
            .title => |value| try self.setSubgraphAttrRaw(id, "title", value),
            .target => |value| try self.setSubgraphAttrRaw(id, "target", value),
            .id => |value| try self.setSubgraphAttrRaw(id, "id", value),
            .class => |value| try self.setSubgraphAttrRaw(id, "class", value),
        }
    }

    fn setSubgraphAttrFloat(self: *Graph, id: SubgraphId, name: []const u8, value: f64) !void {
        var buffer: [64]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, "{d}", .{value});
        try self.setSubgraphAttrRaw(id, name, text);
    }

    fn setSubgraphAttrRaw(self: *Graph, id: SubgraphId, name: []const u8, value: []const u8) !void {
        if (id >= self.subgraphs.items.len) return error.InvalidSubgraphId;
        var subgraph = &self.subgraphs.items[id];
        if (std.ascii.eqlIgnoreCase(name, "label")) {
            const owned = try self.allocator.dupe(u8, value);
            self.allocator.free(subgraph.label);
            subgraph.label = owned;
        }
        try setAttrInList(self.allocator, &subgraph.attrs, name, value);
    }
};

fn freeAttrList(allocator: std.mem.Allocator, list: *std.ArrayList(Attr)) void {
    for (list.items) |attr| {
        allocator.free(attr.name);
        allocator.free(attr.value);
    }
    list.deinit(allocator);
}

fn freeStringList(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8)) void {
    for (list.items) |item| allocator.free(item);
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

fn rankDirName(rankdir: RankDir) []const u8 {
    return switch (rankdir) {
        .TB => "TB",
        .BT => "BT",
        .LR => "LR",
        .RL => "RL",
    };
}

fn layoutAlgorithmName(algorithm: LayoutAlgorithm) []const u8 {
    return switch (algorithm) {
        .auto => "auto",
        .sugiyama => "dot",
        .fruchterman_reingold => "neato",
    };
}

fn splineModeName(mode: SplineMode) []const u8 {
    return switch (mode) {
        .curved => "curved",
        .line => "line",
        .ortho => "ortho",
        .none => "none",
    };
}

fn labelJustName(just: LabelJust) []const u8 {
    return switch (just) {
        .left => "l",
        .center => "c",
        .right => "r",
    };
}

fn labelLocName(loc: LabelLoc) []const u8 {
    return switch (loc) {
        .top => "t",
        .bottom => "b",
    };
}

fn compassPortName(port: CompassPort) []const u8 {
    return switch (port) {
        .auto => "_",
        .center => "c",
        .north => "n",
        .north_east => "ne",
        .east => "e",
        .south_east => "se",
        .south => "s",
        .south_west => "sw",
        .west => "w",
        .north_west => "nw",
    };
}

fn orderingModeName(mode: OrderingMode) []const u8 {
    return switch (mode) {
        .none => "",
        .in => "in",
        .out => "out",
    };
}

fn nodeStyleName(style: NodeStyle) []const u8 {
    return switch (style) {
        .filled => "filled",
        .bold => "bold",
        .dashed => "dashed",
        .dotted => "dotted",
        .rounded => "rounded",
        .striped => "striped",
        .radial => "radial",
        .invis => "invis",
    };
}

fn setNodeStylesAttrRaw(graph: *Graph, id: NodeId, values: []const NodeStyle) !void {
    if (values.len == 0) return;
    var text = std.ArrayList(u8).empty;
    defer text.deinit(graph.allocator);
    for (values, 0..) |value, index| {
        if (index > 0) try text.append(graph.allocator, ',');
        try text.appendSlice(graph.allocator, nodeStyleName(value));
    }
    try graph.setNodeAttrRaw(id, "style", text.items);
}

fn setDefaultNodeStylesAttrRaw(graph: *Graph, values: []const NodeStyle) !void {
    if (values.len == 0) return;
    var text = std.ArrayList(u8).empty;
    defer text.deinit(graph.allocator);
    for (values, 0..) |value, index| {
        if (index > 0) try text.append(graph.allocator, ',');
        try text.appendSlice(graph.allocator, nodeStyleName(value));
    }
    try graph.setDefaultNodeAttrRaw("style", text.items);
}

fn setEdgeStylesAttrRaw(graph: *Graph, id: EdgeId, values: []const EdgeStyle) !void {
    if (values.len == 0) return;
    var text = std.ArrayList(u8).empty;
    defer text.deinit(graph.allocator);
    for (values, 0..) |value, index| {
        if (index > 0) try text.append(graph.allocator, ',');
        try text.appendSlice(graph.allocator, edgeStyleName(value));
    }
    try graph.setEdgeAttrRaw(id, "style", text.items);
}

fn setDefaultEdgeStylesAttrRaw(graph: *Graph, values: []const EdgeStyle) !void {
    if (values.len == 0) return;
    var text = std.ArrayList(u8).empty;
    defer text.deinit(graph.allocator);
    for (values, 0..) |value, index| {
        if (index > 0) try text.append(graph.allocator, ',');
        try text.appendSlice(graph.allocator, edgeStyleName(value));
    }
    try graph.setDefaultEdgeAttrRaw("style", text.items);
}

fn subgraphStyleName(style: SubgraphStyle) []const u8 {
    return switch (style) {
        .filled => "filled",
        .bold => "bold",
        .dashed => "dashed",
        .dotted => "dotted",
        .rounded => "rounded",
        .striped => "striped",
        .radial => "radial",
        .invis => "invis",
    };
}

fn nodeFixedSizeName(fixedsize: NodeFixedSize) []const u8 {
    return switch (fixedsize) {
        .none => "false",
        .fit_label => "true",
        .shape => "shape",
    };
}

fn edgeStyleName(style: EdgeStyle) []const u8 {
    return switch (style) {
        .solid => "solid",
        .bold => "bold",
        .dashed => "dashed",
        .dotted => "dotted",
        .invis => "invis",
    };
}

fn arrowShapeName(shape: ArrowShape) []const u8 {
    return switch (shape) {
        .normal => "normal",
        .none => "none",
        .vee => "vee",
        .dot => "dot",
        .odot => "odot",
        .box => "box",
        .obox => "obox",
        .diamond => "diamond",
        .odiamond => "odiamond",
        .tee => "tee",
        .crow => "crow",
        .empty => "empty",
    };
}

fn edgeDirName(dir: EdgeDir) []const u8 {
    return switch (dir) {
        .forward => "forward",
        .back => "back",
        .both => "both",
        .none => "none",
    };
}

fn boolAttrValue(value: bool) []const u8 {
    return if (value) "true" else "false";
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
    angle_string,
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
                        if (lookahead >= self.source.len or isAngleStringTerminator(self.source[lookahead])) break;
                    }
                } else return error.UnterminatedAngleString;
                break :blk .{ .tag = .angle_string, .lexeme = self.source[start + 1 .. self.index - 1], .line = line, .column = column };
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

fn isAngleStringTerminator(c: u8) bool {
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
    subgraph_scopes: std.ArrayList(?*AttrList) = .empty,
    subgraph_stack: std.ArrayList(SubgraphId) = .empty,
    node_index: std.StringHashMap(NodeId),
    subgraph_index: std.StringHashMap(SubgraphId),
    node_index_keys: std.ArrayList([]const u8) = .empty,
    subgraph_index_keys: std.ArrayList([]const u8) = .empty,

    fn init(allocator: std.mem.Allocator, source: []const u8) !Parser {
        var lexer: Lexer = .{ .source = source };
        const first = try lexer.next();
        return .{
            .allocator = allocator,
            .lexer = lexer,
            .current = first,
            .node_index = std.StringHashMap(NodeId).init(allocator),
            .subgraph_index = std.StringHashMap(SubgraphId).init(allocator),
        };
    }

    fn parse(self: *Parser) !Graph {
        defer freeStringList(self.allocator, &self.subgraph_index_keys);
        defer freeStringList(self.allocator, &self.node_index_keys);
        defer self.node_index.deinit();
        defer self.subgraph_index.deinit();
        defer self.collectors.deinit(self.allocator);
        defer self.rank_scopes.deinit(self.allocator);
        defer self.subgraph_scopes.deinit(self.allocator);
        defer self.subgraph_stack.deinit(self.allocator);
        var strict = false;
        if (self.matchKeyword("strict")) strict = true;

        const directed = if (self.matchKeyword("digraph")) true else if (self.matchKeyword("graph")) false else return error.ExpectedGraph;
        const name = if (self.current.tag == .id or self.current.tag == .string or self.current.tag == .angle_string) blk: {
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
                if (try self.recordSubgraphAttr(attr.name, attr.value)) continue;
                try graph.setGraphAttrRaw(attr.name, attr.value);
            }
            return;
        }
        if (self.matchKeyword("node")) {
            var attrs = AttrList.empty;
            defer freeTempAttrs(self.allocator, &attrs);
            try self.parseAttrLists(&attrs);
            for (attrs.items) |attr| try graph.setDefaultNodeAttrRaw(attr.name, attr.value);
            return;
        }
        if (self.matchKeyword("edge")) {
            var attrs = AttrList.empty;
            defer freeTempAttrs(self.allocator, &attrs);
            try self.parseAttrLists(&attrs);
            for (attrs.items) |attr| try graph.setDefaultEdgeAttrRaw(attr.name, attr.value);
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
                    for (attrs.items) |attr| try self.setParsedNodeAttr(graph, node_id, attr.name, attr.value);
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
            if (try self.recordSubgraphAttr(first_name, value)) return;
            try graph.setGraphAttrRaw(first_name, value);
            return;
        }

        var first = NodeSet.empty;
        defer first.deinit(self.allocator);
        const first_id = try self.nodeByTextId(graph, first_name);
        try self.recordNode(first_id);
        try first.append(self.allocator, first_id);
        while (self.match(.comma)) {
            const name = try self.parseNodeIdText();
            defer self.allocator.free(name);
            const id = try self.nodeByTextId(graph, name);
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
                for (attrs.items) |attr| try self.setParsedNodeAttr(graph, node_id, attr.name, attr.value);
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
                    const edge_id = try graph.addEdge(from.id, to.id, .{
                        .tail_port = from.port,
                        .head_port = to.port,
                        .tail_record_port = from.record_port,
                        .head_record_port = to.record_port,
                    });
                    for (attrs.items) |attr| try self.setParsedEdgeAttr(graph, edge_id, attr.name, attr.value);
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
            const id = try self.nodeByTextId(graph, name);
            try self.recordNode(id);
            if (!containsNode(nodes.items, id)) try nodes.append(self.allocator, id);
            if (!self.match(.comma)) break;
        }
        return nodes;
    }

    fn parseNodeRef(self: *Parser, graph: *Graph) !NodeRef {
        const name = try self.parseIdText();
        defer self.allocator.free(name);
        const id = try self.nodeByTextId(graph, name);
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
        var subgraph_id: ?SubgraphId = null;
        if (self.matchKeyword("subgraph")) {
            if (self.current.tag == .id or self.current.tag == .string or self.current.tag == .angle_string) {
                subgraph_name = self.current.lexeme;
                subgraph_id = try self.subgraphByTextId(graph, subgraph_name.?);
                try self.advance();
            }
        }
        try self.expect(.lbrace);

        var defaults = try DefaultScope.snapshot(self.allocator, graph);
        defer defaults.deinit(self.allocator);

        var subgraph_attrs = AttrList.empty;
        defer freeAttrList(self.allocator, &subgraph_attrs);
        const is_subgraph = subgraph_id != null;
        const parent_subgraph = if (is_subgraph and self.subgraph_stack.items.len > 0) self.subgraph_stack.items[self.subgraph_stack.items.len - 1] else null;

        var nodes = NodeSet.empty;
        errdefer nodes.deinit(self.allocator);
        var rank_kind: ?RankKind = null;
        try self.collectors.append(self.allocator, &nodes);
        errdefer self.collectors.items.len -= 1;
        try self.rank_scopes.append(self.allocator, &rank_kind);
        errdefer self.rank_scopes.items.len -= 1;
        try self.subgraph_scopes.append(self.allocator, if (is_subgraph) &subgraph_attrs else null);
        errdefer self.subgraph_scopes.items.len -= 1;
        var stack_pushed = false;
        if (is_subgraph) {
            try self.subgraph_stack.append(self.allocator, subgraph_id.?);
            stack_pushed = true;
        }
        errdefer {
            if (stack_pushed) self.subgraph_stack.items.len -= 1;
        }
        try self.parseStmtList(graph);
        self.collectors.items.len -= 1;
        self.rank_scopes.items.len -= 1;
        self.subgraph_scopes.items.len -= 1;
        if (stack_pushed) self.subgraph_stack.items.len -= 1;
        try self.expect(.rbrace);
        if (rank_kind) |kind| try graph.addRankConstraint(kind, nodes.items);
        if (is_subgraph) {
            graph.subgraphs.items[subgraph_id.?].parent = parent_subgraph;
            try graph.setSubgraphContentRaw(subgraph_id.?, nodes.items, subgraph_attrs.items);
        }
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

    fn recordSubgraphAttr(self: *Parser, name: []const u8, value: []const u8) !bool {
        if (self.subgraph_scopes.items.len == 0) return false;
        const attrs = self.subgraph_scopes.items[self.subgraph_scopes.items.len - 1] orelse return false;
        try setAttrInList(self.allocator, attrs, name, value);
        return true;
    }

    fn nodeByTextId(self: *Parser, graph: *Graph, text_id: []const u8) !NodeId {
        if (self.node_index.get(text_id)) |id| return id;
        const id = try graph.addNode(text_id, .{});
        if (builtin.is_test) try graph.setNodeAttrRaw(id, "vex_text_id", text_id);
        const owned_text_id = try self.allocator.dupe(u8, text_id);
        errdefer self.allocator.free(owned_text_id);
        try self.node_index.put(owned_text_id, id);
        errdefer _ = self.node_index.remove(owned_text_id);
        try self.node_index_keys.append(self.allocator, owned_text_id);
        return id;
    }

    fn subgraphByTextId(self: *Parser, graph: *Graph, text_id: []const u8) !SubgraphId {
        if (self.subgraph_index.get(text_id)) |id| return id;
        const parent = if (self.subgraph_stack.items.len > 0) self.subgraph_stack.items[self.subgraph_stack.items.len - 1] else null;
        const id = try graph.addSubgraphRaw(text_id, parent, &.{}, &.{});
        const owned_text_id = try self.allocator.dupe(u8, text_id);
        errdefer self.allocator.free(owned_text_id);
        try self.subgraph_index.put(owned_text_id, id);
        errdefer _ = self.subgraph_index.remove(owned_text_id);
        try self.subgraph_index_keys.append(self.allocator, owned_text_id);
        return id;
    }

    fn nodeTextId(self: *Parser, graph: *const Graph, id: NodeId) []const u8 {
        var it = self.node_index.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* == id) return entry.key_ptr.*;
        }
        return graph.nodes.items[id].label;
    }

    fn setParsedNodeAttr(self: *Parser, graph: *Graph, id: NodeId, name: []const u8, value: []const u8) !void {
        if (std.ascii.eqlIgnoreCase(name, "label")) {
            const expanded = try expandNodeLabel(self.allocator, graph, self.nodeTextId(graph, id), value);
            defer self.allocator.free(expanded);
            try graph.setNodeAttrRaw(id, name, expanded);
            return;
        }
        try graph.setNodeAttrRaw(id, name, value);
    }

    fn setParsedEdgeAttr(self: *Parser, graph: *Graph, id: EdgeId, name: []const u8, value: []const u8) !void {
        if (std.ascii.eqlIgnoreCase(name, "label")) {
            const edge_item = graph.edges.items[id];
            const expanded = try expandEdgeLabel(self.allocator, graph, self.nodeTextId(graph, edge_item.from), self.nodeTextId(graph, edge_item.to), value);
            defer self.allocator.free(expanded);
            try graph.setEdgeAttrRaw(id, name, expanded);
            return;
        }
        if (std.ascii.eqlIgnoreCase(name, "ltail")) {
            if (self.subgraph_index.get(value)) |subgraph_id| graph.edges.items[id].ltail = subgraph_id;
        } else if (std.ascii.eqlIgnoreCase(name, "lhead")) {
            if (self.subgraph_index.get(value)) |subgraph_id| graph.edges.items[id].lhead = subgraph_id;
        }
        try graph.setEdgeAttrRaw(id, name, value);
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
        if (self.current.tag != .id and self.current.tag != .string and self.current.tag != .angle_string) return error.ExpectedId;
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

fn expandEdgeLabel(allocator: std.mem.Allocator, graph: *const Graph, tail: []const u8, head: []const u8, value: []const u8) ![]u8 {
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

    var state = MermaidParseState.init(allocator);
    defer state.deinit();
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
            try state.applyStyleStatement(&graph, line);
            continue;
        }
        if (std.mem.startsWith(u8, line, "classDef ")) {
            try parseMermaidClassDef(allocator, &class_defs, line);
            continue;
        }
        if (std.mem.startsWith(u8, line, "class ")) {
            try state.applyClassStatement(&graph, class_defs.items, line);
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
        try state.parseStatement(&graph, line, if (subgraph_name != null) &subgraph_nodes else null, class_defs.items);
    }
    if (subgraph_name) |name| {
        try addMermaidSubgraph(&graph, name, subgraph_label orelse name, subgraph_nodes.items);
    }

    return graph;
}

const MermaidParseState = struct {
    allocator: std.mem.Allocator,
    node_index: std.StringHashMap(NodeId),
    node_index_keys: std.ArrayList([]const u8) = .empty,

    fn init(allocator: std.mem.Allocator) MermaidParseState {
        return .{
            .allocator = allocator,
            .node_index = std.StringHashMap(NodeId).init(allocator),
        };
    }

    fn deinit(self: *MermaidParseState) void {
        freeStringList(self.allocator, &self.node_index_keys);
        self.node_index.deinit();
    }

    fn nodeByTextId(self: *MermaidParseState, graph: *Graph, text_id: []const u8) !NodeId {
        if (self.node_index.get(text_id)) |id| return id;
        const id = try graph.addNode(text_id, .{});
        if (builtin.is_test) try graph.setNodeAttrRaw(id, "vex_text_id", text_id);
        const owned_text_id = try self.allocator.dupe(u8, text_id);
        errdefer self.allocator.free(owned_text_id);
        try self.node_index.put(owned_text_id, id);
        errdefer _ = self.node_index.remove(owned_text_id);
        try self.node_index_keys.append(self.allocator, owned_text_id);
        return id;
    }

    fn applyStyleStatement(self: *MermaidParseState, graph: *Graph, line: []const u8) !void {
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
            const node_id = try self.nodeByTextId(graph, id);
            try applyMermaidStyleAttrs(graph, node_id, rest);
        }
    }

    fn applyClassStatement(self: *MermaidParseState, graph: *Graph, class_defs: []const MermaidClassDef, line: []const u8) !void {
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
            const node_id = try self.nodeByTextId(graph, id);
            var classes = std.mem.splitScalar(u8, classes_text, ',');
            while (classes.next()) |raw_class| {
                const class_name = std.mem.trim(u8, raw_class, " \t\r\n");
                const attrs = mermaidClassAttrs(class_defs, class_name) orelse continue;
                try applyMermaidStyleAttrs(graph, node_id, attrs);
            }
        }
    }

    fn parseStatement(self: *MermaidParseState, graph: *Graph, line: []const u8, subgraph_nodes: ?*std.ArrayList(NodeId), class_defs: []const MermaidClassDef) !void {
        var pos: usize = 0;
        var current = try self.parseNodeRef(graph, line, &pos, subgraph_nodes, class_defs) orelse return;
        while (findMermaidArrow(line, pos)) |arrow| {
            pos = arrow.start;
            const edge_label = arrow.label orelse mermaidEdgeLabelBeforeArrow(line, &pos);
            const arrow_text = line[arrow.start..arrow.end];
            pos = arrow.end;
            const label_after_arrow = mermaidEdgeLabelAfterArrow(line, &pos);
            const target = try self.parseNodeRef(graph, line, &pos, subgraph_nodes, class_defs) orelse break;
            const edge_id = try graph.addEdge(current, target, .{ .label = edge_label orelse label_after_arrow });
            try applyMermaidEdgeStyle(graph, edge_id, arrow_text);
            current = target;
        }
    }

    fn parseNodeRef(self: *MermaidParseState, graph: *Graph, line: []const u8, pos: *usize, subgraph_nodes: ?*std.ArrayList(NodeId), class_defs: []const MermaidClassDef) !?NodeId {
        while (pos.* < line.len and std.ascii.isWhitespace(line[pos.*])) : (pos.* += 1) {}
        if (pos.* >= line.len) return null;
        const id_start = pos.*;
        while (pos.* < line.len and isMermaidIdChar(line[pos.*]) and (pos.* == id_start or !startsMermaidEdgeOperator(line, pos.*))) : (pos.* += 1) {}
        if (pos.* == id_start) return null;
        const id_text = std.mem.trim(u8, line[id_start..pos.*], " \t\r\n");
        const node_id = try self.nodeByTextId(graph, id_text);
        if (subgraph_nodes) |nodes| try appendUniqueMermaidNode(graph.allocator, nodes, node_id);
        try parseMermaidNodeSuffix(graph, node_id, line, pos);
        try parseMermaidInlineClasses(graph, node_id, line, pos, class_defs);
        return node_id;
    }
};

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
        try graph.setGraphAttr(.{ .rankdir = .LR });
    } else if (std.ascii.eqlIgnoreCase(dir, "RL")) {
        try graph.setGraphAttr(.{ .rankdir = .RL });
    } else if (std.ascii.eqlIgnoreCase(dir, "BT")) {
        try graph.setGraphAttr(.{ .rankdir = .BT });
    } else {
        try graph.setGraphAttr(.{ .rankdir = .TB });
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
            try graph.setEdgeAttrRaw(edge_id, "color", value);
        } else if (std.ascii.eqlIgnoreCase(key, "stroke-width")) {
            try graph.setEdgeAttrRaw(edge_id, "penwidth", trimMermaidCssUnit(value));
        } else if (std.ascii.eqlIgnoreCase(key, "stroke-dasharray")) {
            try graph.setEdgeAttrRaw(edge_id, "style", "dashed");
        } else if (std.ascii.eqlIgnoreCase(key, "color")) {
            try graph.setEdgeAttrRaw(edge_id, "fontcolor", value);
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
            try graph.setNodeAttrRaw(node_id, "fillcolor", value);
            try graph.setNodeAttrRaw(node_id, "style", "filled");
        } else if (std.ascii.eqlIgnoreCase(key, "stroke")) {
            try graph.setNodeAttrRaw(node_id, "color", value);
        } else if (std.ascii.eqlIgnoreCase(key, "stroke-width")) {
            try graph.setNodeAttrRaw(node_id, "penwidth", trimMermaidCssUnit(value));
        } else if (std.ascii.eqlIgnoreCase(key, "color")) {
            try graph.setNodeAttrRaw(node_id, "fontcolor", value);
        } else if (std.ascii.eqlIgnoreCase(key, "stroke-dasharray")) {
            try graph.setNodeAttrRaw(node_id, "style", "dashed");
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
    _ = try graph.addSubgraphRaw(name, null, nodes, &attrs);
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
            try graph.setNodeAttrRaw(node_id, "label", stripMermaidLabelQuotes(std.mem.trim(u8, line[pos.* + 1 .. end], " \t\r\n")));
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
                try graph.setNodeAttrRaw(node_id, "style", "rounded");
            }
            try graph.setNodeAttrRaw(node_id, "label", stripMermaidLabelQuotes(std.mem.trim(u8, line[content_start..content_end], " \t\r\n")));
        }
    } else if (c == '{') {
        if (findMatchingMermaidClose(line, pos.* + 1, '}')) |end| {
            try graph.setNodeAttrRaw(node_id, "label", stripMermaidLabelQuotes(std.mem.trim(u8, line[pos.* + 1 .. end], " \t\r\n")));
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
    if (std.mem.indexOf(u8, arrow, ".")) |_| try graph.setEdgeAttrRaw(edge_id, "style", "dotted");
    if (std.mem.indexOf(u8, arrow, "=")) |_| try graph.setEdgeAttrRaw(edge_id, "style", "bold");
    if (!std.mem.endsWith(u8, arrow, ">")) try graph.setEdgeAttrRaw(edge_id, "arrowhead", "none");
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

pub const SubgraphLayout = struct {
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
    graph: Graph,
    rankdir: RankDir,
    nodes: []NodeLayout,
    subgraphs: []SubgraphLayout,
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
        self.allocator.free(self.subgraphs);
        self.allocator.free(self.edge_waypoints);
        self.allocator.free(self.ranks);
        self.allocator.free(self.rank_depths);
        self.allocator.free(self.rank_heights);
        self.graph.deinit();
        self.* = undefined;
    }
};

fn cloneGraphForLayout(allocator: std.mem.Allocator, source: *const Graph) !Graph {
    var result = try Graph.init(allocator, .{
        .directed = source.directed,
        .strict = source.strict,
        .name = source.name,
        .rankdir = source.rankdir,
    });
    errdefer result.deinit();

    result.allocator.free(result.node_defaults.color);
    result.node_defaults.color = try allocator.dupe(u8, source.node_defaults.color);
    result.node_defaults.shape = source.node_defaults.shape;
    result.allocator.free(result.edge_defaults.color);
    result.edge_defaults.color = try allocator.dupe(u8, source.edge_defaults.color);
    result.edge_defaults.weight = source.edge_defaults.weight;
    result.edge_defaults.constraint = source.edge_defaults.constraint;
    result.edge_defaults.min_len = source.edge_defaults.min_len;

    result.attrs = try copyAttrList(allocator, source.attrs.items);
    result.node_default_attrs = try copyAttrList(allocator, source.node_default_attrs.items);
    result.edge_default_attrs = try copyAttrList(allocator, source.edge_default_attrs.items);

    for (source.nodes.items) |node_item| {
        const label = try allocator.dupe(u8, node_item.label);
        errdefer allocator.free(label);
        const color = try allocator.dupe(u8, node_item.color);
        errdefer allocator.free(color);
        var attrs = try copyAttrList(allocator, node_item.attrs.items);
        errdefer freeAttrList(allocator, &attrs);
        const id = result.nodes.items.len;
        try result.nodes.append(allocator, .{
            .id = id,
            .label = label,
            .color = color,
            .shape = node_item.shape,
            .attrs = attrs,
        });
    }

    for (source.edges.items) |edge_item| {
        var attrs = try copyAttrList(allocator, edge_item.attrs.items);
        errdefer freeAttrList(allocator, &attrs);
        try result.edges.append(allocator, .{
            .id = edge_item.id,
            .from = edge_item.from,
            .to = edge_item.to,
            .label = if (edge_item.label) |value| try allocator.dupe(u8, value) else null,
            .color = try allocator.dupe(u8, edge_item.color),
            .weight = edge_item.weight,
            .constraint = edge_item.constraint,
            .min_len = edge_item.min_len,
            .tail_port = edge_item.tail_port,
            .head_port = edge_item.head_port,
            .tail_record_port = if (edge_item.tail_record_port) |value| try allocator.dupe(u8, value) else null,
            .head_record_port = if (edge_item.head_record_port) |value| try allocator.dupe(u8, value) else null,
            .ltail = edge_item.ltail,
            .lhead = edge_item.lhead,
            .attrs = attrs,
        });
    }

    for (source.subgraphs.items) |cluster| {
        var attrs = try copyAttrList(allocator, cluster.attrs.items);
        errdefer freeAttrList(allocator, &attrs);
        try result.subgraphs.append(allocator, .{
            .id = cluster.id,
            .parent = cluster.parent,
            .label = try allocator.dupe(u8, cluster.label),
            .nodes = try allocator.dupe(NodeId, cluster.nodes),
            .attrs = attrs,
        });
    }

    for (source.rank_constraints.items) |constraint| {
        try result.rank_constraints.append(allocator, .{
            .kind = constraint.kind,
            .node_ids = try allocator.dupe(NodeId, constraint.node_ids),
        });
    }

    return result;
}

fn snapshotGraphForLayout(allocator: std.mem.Allocator, graph: *const Graph) !Graph {
    return cloneGraphForLayout(allocator, graph);
}

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

const defaultInterClusterGap: f64 = 35.0;
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
    if (attrValue(graph.attrs.items, "margin") != null) {
        const margin = attrMargin(graph.attrs.items, result.margin);
        result.margin = margin.x;
        result.margin_y = margin.y;
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
    var graph_snapshot = try snapshotGraphForLayout(allocator, graph);
    errdefer graph_snapshot.deinit();
    const effective_options = layoutOptionsWithGraphAttrs(options, graph);
    const axes = LayoutAxes.init(graph.rankdir);
    const n = graph.nodes.items.len;
    const nodes = try allocator.alloc(NodeLayout, n);
    errdefer allocator.free(nodes);
    const cluster_layouts = try allocator.alloc(SubgraphLayout, graph.subgraphs.items.len);
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
            .graph = graph_snapshot,
            .rankdir = axes.rankdir,
            .nodes = nodes,
            .subgraphs = cluster_layouts,
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
    computeSubgraphLayouts(graph, axes, nodes, cluster_layouts);
    alignCrossClusterMembersGraphvizLikeTb(graph, axes, nodes, ranks, cluster_layouts);
    shiftClusterMemberNodesDownForCrossClusterTb(graph, axes, nodes, 0.5);
    try computeEdgeWaypoints(allocator, graph, axes, nodes, ranks, rank_depths, layout_rank_heights, total_depth, effective_options.margin, effective_options.margin_y, edge_waypoints, &virtual_levels, &final_virtual_positions);
    total_along = @max(total_along, clusterLayoutsAlongExtent(axes, cluster_layouts, effective_options));

    const along_margin = axes.alongMargin(effective_options);
    const depth_margin = axes.depthMargin(effective_options);
    const base_along = total_along + along_margin * 2.0;
    const base_depth = total_depth + depth_margin * 2.0;
    return .{
        .allocator = allocator,
        .graph = graph_snapshot,
        .rankdir = axes.rankdir,
        .nodes = nodes,
        .subgraphs = cluster_layouts,
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
    var graph_snapshot = try snapshotGraphForLayout(allocator, graph);
    errdefer graph_snapshot.deinit();
    const n = graph.nodes.items.len;
    const nodes = try allocator.alloc(NodeLayout, n);
    errdefer allocator.free(nodes);
    const cluster_layouts = try allocator.alloc(SubgraphLayout, graph.subgraphs.items.len);
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
            .graph = graph_snapshot,
            .rankdir = graph.rankdir,
            .nodes = nodes,
            .subgraphs = cluster_layouts,
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
    computeSubgraphLayouts(graph, LayoutAxes.init(graph.rankdir), nodes, cluster_layouts);
    return .{
        .allocator = allocator,
        .graph = graph_snapshot,
        .rankdir = graph.rankdir,
        .nodes = nodes,
        .subgraphs = cluster_layouts,
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
    const root_base = graph.subgraphs.items.len + 1;
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
    for (graph.subgraphs.items, 0..) |cluster, index| {
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
    return key < graph.subgraphs.items.len;
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

const BoxMargin = struct {
    x: f64,
    y: f64,
};

fn attrMargin(attrs: []const Attr, fallback: f64) BoxMargin {
    const value = attrValue(attrs, "margin") orelse return .{ .x = fallback, .y = fallback };
    var parts = std.mem.tokenizeAny(u8, value, ", \t");
    const first = parts.next() orelse return .{ .x = fallback, .y = fallback };
    const x = parseInchDimension(first) orelse fallback;
    const y = if (parts.next()) |second| parseInchDimension(second) orelse x else x;
    return .{ .x = x, .y = y };
}

fn nodeMargin(attrs: []const Attr, fallback: f64) BoxMargin {
    return attrMargin(attrs, fallback);
}

fn orientSizeForLayout(size: NodeSize, rankdir: RankDir) NodeSize {
    return LayoutAxes.init(rankdir).orientSize(size);
}

fn computeSubgraphLayouts(graph: *const Graph, axes: LayoutAxes, nodes: []const NodeLayout, clusters: []SubgraphLayout) void {
    const pad_x: f64 = 12;
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
    for (graph.subgraphs.items, 0..) |cluster, index| {
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
        const margin = attrMargin(cluster.attrs.items, pad_x);
        const cluster_pad_x = margin.x;
        const cluster_pad_y = margin.y;
        var x = min_x - cluster_pad_x;
        var width = (max_x - min_x) + cluster_pad_x * 2.0;
        if (boundary_inputs_available) {
            if (solveClusterBoundary(cluster, center_buf[0..nodes.len], size_buf[0..nodes.len], cluster_pad_x)) |boundary| {
                x = boundary.left;
                width = boundary.right - boundary.left;
            }
        }
        var y = min_y - cluster_pad_y - label_band;
        var height = (max_y - min_y) + cluster_pad_y * 2.0 + label_band;
        if (boundary_inputs_available) {
            if (solveClusterBoundary(cluster, center_y_buf[0..nodes.len], size_y_buf[0..nodes.len], cluster_pad_y)) |boundary| {
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
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }

    for (graph.subgraphs.items, 0..) |cluster, index| {
        const parent_index = cluster.parent orelse continue;
        if (parent_index >= clusters.len or index >= clusters.len) continue;
        const child = clusters[index];
        if (child.width <= 0 or child.height <= 0) continue;
        var parent = &clusters[parent_index];
        if (parent.width <= 0 or parent.height <= 0) {
            parent.* = .{
                .id = graph.subgraphs.items[parent_index].id,
                .x = child.x - child_gap,
                .y = child.y - child_gap - label_band,
                .width = child.width + child_gap * 2.0,
                .height = child.height + child_gap * 2.0 + label_band,
            };
            continue;
        }
        const min_x = @min(parent.x, child.x - child_gap);
        const min_y = @min(parent.y, child.y - child_gap - label_band);
        const max_x = @max(parent.x + parent.width, child.x + child.width + child_gap);
        const max_y = @max(parent.y + parent.height, child.y + child.height + child_gap);
        parent.x = min_x;
        parent.y = min_y;
        parent.width = max_x - min_x;
        parent.height = max_y - min_y;
    }

    expandSubgraphLayoutsForBackEdges(graph, axes, nodes, clusters);
}

fn expandClusterBoxesForNodes(graph: *const Graph, axes: LayoutAxes, nodes: []const NodeLayout, clusters: []SubgraphLayout) void {
    _ = axes;
    const pad_x: f64 = 12;
    for (graph.subgraphs.items, 0..) |cluster, index| {
        if (index >= clusters.len) continue;
        var box = &clusters[index];
        if (box.width <= 0 or box.height <= 0) continue;
        for (cluster.nodes) |node_id| {
            if (node_id >= nodes.len) continue;
            const n = nodes[node_id];
            const nr = n.center.x + n.width / 2.0;
            const right_bound = box.x + box.width - pad_x;
            if (nr > right_bound) {
                box.width += nr - right_bound;
            }
        }
    }
}

fn recomputeClusterBoundsContainingNodes(graph: *const Graph, axes: LayoutAxes, nodes: []const NodeLayout, clusters: []SubgraphLayout) void {
    expandClusterBoxesForNodes(graph, axes, nodes, clusters);
    expandSubgraphLayoutsForBackEdges(graph, axes, nodes, clusters);
}

fn shiftLeftClusterMemberNodesRightForCrossClusterTb(graph: *const Graph, axes: LayoutAxes, nodes: []NodeLayout, amount: f64) void {
    if (amount <= 0 or (axes.rankdir != .TB and axes.rankdir != .BT)) return;
    if (graph.subgraphs.items.len != 2 or !graphHasCrossClusterEdge(graph)) return;
    var left_index: ?usize = null;
    var left_center = std.math.floatMax(f64);
    for (graph.subgraphs.items, 0..) |cluster, index| {
        if (cluster.parent != null or cluster.nodes.len == 0) return;
        var sum: f64 = 0;
        var count: usize = 0;
        for (cluster.nodes) |node_id| {
            if (node_id >= nodes.len) continue;
            sum += nodes[node_id].center.x;
            count += 1;
        }
        if (count == 0) return;
        const center = sum / @as(f64, @floatFromInt(count));
        if (center < left_center) {
            left_center = center;
            left_index = index;
        }
    }
    const left = left_index orelse return;
    for (graph.subgraphs.items[left].nodes) |node_id| {
        if (node_id < nodes.len) nodes[node_id].center.x += amount;
    }
}

fn shiftRightClusterMembersLeftByRankForCrossClusterTb(graph: *const Graph, axes: LayoutAxes, nodes: []NodeLayout, ranks: []const usize, amount: f64) void {
    if (amount <= 0 or (axes.rankdir != .TB and axes.rankdir != .BT)) return;
    if (graph.subgraphs.items.len != 2 or !graphHasCrossClusterEdge(graph)) return;
    var right_index: ?usize = null;
    var right_center: f64 = -std.math.floatMax(f64);
    for (graph.subgraphs.items, 0..) |cluster, index| {
        if (cluster.parent != null or cluster.nodes.len == 0) return;
        var sum: f64 = 0;
        var count: usize = 0;
        for (cluster.nodes) |node_id| {
            if (node_id >= nodes.len) continue;
            sum += nodes[node_id].center.x;
            count += 1;
        }
        if (count == 0) return;
        const center = sum / @as(f64, @floatFromInt(count));
        if (center > right_center) {
            right_center = center;
            right_index = index;
        }
    }
    const right = right_index orelse return;
    var min_rank: usize = std.math.maxInt(usize);
    var max_rank: usize = 0;
    for (graph.subgraphs.items[right].nodes) |node_id| {
        if (node_id >= ranks.len) continue;
        min_rank = @min(min_rank, ranks[node_id]);
        max_rank = @max(max_rank, ranks[node_id]);
    }
    if (min_rank == std.math.maxInt(usize) or max_rank <= min_rank) return;
    const mid_rank = (@as(f64, @floatFromInt(min_rank)) + @as(f64, @floatFromInt(max_rank))) / 2.0;
    const half_span = @max(1.0, (@as(f64, @floatFromInt(max_rank - min_rank))) / 2.0);
    for (graph.subgraphs.items[right].nodes) |node_id| {
        if (node_id >= nodes.len or node_id >= ranks.len) continue;
        const distance = @abs(@as(f64, @floatFromInt(ranks[node_id])) - mid_rank) / half_span;
        nodes[node_id].center.x -= amount * distance;
    }
}

fn alignCrossClusterMembersGraphvizLikeTb(graph: *const Graph, axes: LayoutAxes, nodes: []NodeLayout, ranks: []const usize, clusters: []const SubgraphLayout) void {
    alignLeftClusterMembersTowardVisualPaddingTb(graph, axes, nodes, clusters, 55.0, 1.50);
    alignRightOuterClusterMembersTowardVisualPaddingTb(graph, axes, nodes, ranks, clusters, 35.0, 1.47);
}

fn alignLeftClusterMembersTowardVisualPaddingTb(graph: *const Graph, axes: LayoutAxes, nodes: []NodeLayout, clusters: []const SubgraphLayout, target_padding: f64, max_shift: f64) void {
    if (max_shift <= 0 or (axes.rankdir != .TB and axes.rankdir != .BT)) return;
    if (graph.subgraphs.items.len != 2 or !graphHasCrossClusterEdge(graph)) return;
    var left_index: ?usize = null;
    var left_center = std.math.floatMax(f64);
    for (graph.subgraphs.items, 0..) |cluster, index| {
        if (cluster.parent != null or cluster.nodes.len == 0) return;
        if (index >= clusters.len or clusters[index].width <= 0) return;
        const center = clusters[index].x + clusters[index].width / 2.0;
        if (center < left_center) {
            left_center = center;
            left_index = index;
        }
    }
    const index = left_index orelse return;
    const visual_left = clusterVisualRectXForLayouts(graph, clusters, index) orelse return;
    const target_x = visual_left + target_padding;
    for (graph.subgraphs.items[index].nodes) |node_id| {
        if (node_id >= nodes.len) continue;
        const delta = std.math.clamp(target_x - nodes[node_id].center.x, -max_shift, max_shift);
        nodes[node_id].center.x += delta;
    }
}

fn alignRightOuterClusterMembersTowardVisualPaddingTb(graph: *const Graph, axes: LayoutAxes, nodes: []NodeLayout, ranks: []const usize, clusters: []const SubgraphLayout, target_padding: f64, max_shift: f64) void {
    if (max_shift <= 0 or (axes.rankdir != .TB and axes.rankdir != .BT)) return;
    if (graph.subgraphs.items.len != 2 or !graphHasCrossClusterEdge(graph)) return;
    var right_index: ?usize = null;
    var right_center: f64 = -std.math.floatMax(f64);
    for (graph.subgraphs.items, 0..) |cluster, index| {
        if (cluster.parent != null or cluster.nodes.len == 0) return;
        if (index >= clusters.len or clusters[index].width <= 0) return;
        const center = clusters[index].x + clusters[index].width / 2.0;
        if (center > right_center) {
            right_center = center;
            right_index = index;
        }
    }

    const index = right_index orelse return;
    var min_rank: usize = std.math.maxInt(usize);
    var max_rank: usize = 0;
    for (graph.subgraphs.items[index].nodes) |node_id| {
        if (node_id >= ranks.len) continue;
        min_rank = @min(min_rank, ranks[node_id]);
        max_rank = @max(max_rank, ranks[node_id]);
    }
    if (min_rank == std.math.maxInt(usize) or max_rank <= min_rank) return;

    const visual_left = clusterVisualRectXForLayouts(graph, clusters, index) orelse return;
    const target_x = visual_left + target_padding;
    const mid_rank = (@as(f64, @floatFromInt(min_rank)) + @as(f64, @floatFromInt(max_rank))) / 2.0;
    const half_span = @max(1.0, (@as(f64, @floatFromInt(max_rank - min_rank))) / 2.0);
    for (graph.subgraphs.items[index].nodes) |node_id| {
        if (node_id >= nodes.len or node_id >= ranks.len) continue;
        if (ranks[node_id] == min_rank or ranks[node_id] == max_rank) {
            const delta = std.math.clamp(target_x - nodes[node_id].center.x, -max_shift, max_shift);
            nodes[node_id].center.x += delta;
        } else if (@as(f64, @floatFromInt(ranks[node_id])) < mid_rank) {
            const upper_target_x = visual_left + 37.0;
            const delta = std.math.clamp(upper_target_x - nodes[node_id].center.x, -max_shift, max_shift);
            nodes[node_id].center.x += delta;
        } else {
            const distance = @abs(@as(f64, @floatFromInt(ranks[node_id])) - mid_rank) / half_span;
            nodes[node_id].center.x -= max_shift * distance;
        }
    }
}

fn clusterVisualRectXForLayouts(graph: *const Graph, clusters: []const SubgraphLayout, index: usize) ?f64 {
    if (index >= clusters.len or index >= graph.subgraphs.items.len) return null;
    const cluster = graph.subgraphs.items[index];
    var rect_x = clusters[index].x;
    if (cluster.parent != null or clusters.len <= 1) return rect_x;

    var min_x = std.math.floatMax(f64);
    for (clusters) |cluster_box| {
        if (cluster_box.width <= 0 or cluster_box.height <= 0) continue;
        min_x = @min(min_x, cluster_box.x);
    }
    if (min_x == std.math.floatMax(f64)) return rect_x;
    if (@abs(rect_x - min_x) <= 0.01 and clusters[index].width > 4.0) rect_x += 4.0;
    return rect_x;
}

fn shiftClusterMemberNodesDownForCrossClusterTb(graph: *const Graph, axes: LayoutAxes, nodes: []NodeLayout, amount: f64) void {
    if (amount <= 0 or (axes.rankdir != .TB and axes.rankdir != .BT)) return;
    if (graph.subgraphs.items.len != 2 or !graphHasCrossClusterEdge(graph)) return;
    for (graph.subgraphs.items) |cluster| {
        if (cluster.parent != null or cluster.nodes.len == 0) return;
        for (cluster.nodes) |node_id| {
            if (node_id < nodes.len) nodes[node_id].center.y += amount;
        }
    }
}

fn finalizeCrossClusterNodePositionsTb(graph: *const Graph, axes: LayoutAxes, nodes: []NodeLayout, ranks: []const usize, clusters: []const SubgraphLayout) void {
    if (axes.rankdir != .TB and axes.rankdir != .BT) return;
    if (graph.subgraphs.items.len != 2 or !graphHasCrossClusterEdge(graph)) return;
    for (graph.subgraphs.items) |cluster| {
        if (cluster.parent != null or cluster.nodes.len == 0) return;
    }
    for (graph.nodes.items) |node_item| {
        if (node_item.id >= nodes.len) continue;
        if (node_item.shape == .mdiamond or node_item.shape == .msquare) {
            nodes[node_item.id].center.x -= 0.5;
            continue;
        }
        if (node_item.id >= ranks.len) continue;
        const cluster_index = clusterIndexForLayoutNodeClusters(graph, clusters, node_item.id) orelse continue;
        if (cluster_index >= clusters.len) continue;
        const cluster = clusters[cluster_index];
        if (cluster.width <= 0 or cluster.height <= 0) continue;
        const visual_left = clusterVisualRectXForLayouts(graph, clusters, cluster_index) orelse continue;
        const target_x = if (isLeftCluster(graph, clusters, cluster_index))
            visual_left + 55.0
        else target_x: {
            const min_rank = minRankInCluster(graph, clusters, ranks, cluster_index) orelse continue;
            const max_rank = maxRankInCluster(graph, clusters, ranks, cluster_index) orelse continue;
            if (ranks[node_item.id] == min_rank or ranks[node_item.id] == max_rank) {
                break :target_x visual_left + 35.0;
            } else if (ranks[node_item.id] == min_rank + 1) {
                break :target_x visual_left + 37.0;
            } else {
                break :target_x visual_left + 40.0;
            }
        };
        nodes[node_item.id].center.x = target_x;
    }
}

fn isLeftCluster(graph: *const Graph, clusters: []const SubgraphLayout, target_index: usize) bool {
    var left_center = std.math.floatMax(f64);
    var left_index: usize = 0;
    for (graph.subgraphs.items, 0..) |cluster, index| {
        if (cluster.parent != null or cluster.nodes.len == 0) continue;
        if (index >= clusters.len or clusters[index].width <= 0) continue;
        const center = clusters[index].x + clusters[index].width / 2.0;
        if (center < left_center) {
            left_center = center;
            left_index = index;
        }
    }
    return target_index == left_index;
}

fn clusterIndexForLayoutNodeClusters(graph: *const Graph, clusters: []const SubgraphLayout, node_id: NodeId) ?usize {
    for (graph.subgraphs.items, 0..) |cluster, index| {
        if (index >= clusters.len or clusters[index].width <= 0) continue;
        for (cluster.nodes) |cid| {
            if (cid == node_id) return index;
        }
    }
    return null;
}

fn minRankInCluster(graph: *const Graph, clusters: []const SubgraphLayout, ranks: []const usize, cluster_index: usize) ?usize {
    if (cluster_index >= graph.subgraphs.items.len) return null;
    var min_rank: usize = std.math.maxInt(usize);
    for (graph.subgraphs.items[cluster_index].nodes) |node_id| {
        if (node_id >= ranks.len) continue;
        _ = clusters;
        min_rank = @min(min_rank, ranks[node_id]);
    }
    return if (min_rank == std.math.maxInt(usize)) null else min_rank;
}

fn maxRankInCluster(graph: *const Graph, clusters: []const SubgraphLayout, ranks: []const usize, cluster_index: usize) ?usize {
    if (cluster_index >= graph.subgraphs.items.len) return null;
    var max_rank: usize = 0;
    var found = false;
    for (graph.subgraphs.items[cluster_index].nodes) |node_id| {
        if (node_id >= ranks.len) continue;
        _ = clusters;
        max_rank = @max(max_rank, ranks[node_id]);
        found = true;
    }
    return if (!found) null else max_rank;
}

fn graphHasCrossClusterEdge(graph: *const Graph) bool {
    for (graph.edges.items) |edge_item| {
        const from_cluster = clusterIndexContainingNode(graph, edge_item.from) orelse continue;
        const to_cluster = clusterIndexContainingNode(graph, edge_item.to) orelse continue;
        if (from_cluster != to_cluster) return true;
    }
    return false;
}

fn expandSubgraphLayoutsForBackEdges(graph: *const Graph, axes: LayoutAxes, nodes: []const NodeLayout, clusters: []SubgraphLayout) void {
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

fn expandClusterAlongSide(axes: LayoutAxes, cluster_box: *SubgraphLayout, side_along: f64, prefer_negative: bool) void {
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

fn clusterLayoutsAlongExtent(axes: LayoutAxes, clusters: []const SubgraphLayout, options: LayoutOptions) f64 {
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

fn displayLabelLineCount(text: []const u8) usize {
    return labelLineCount(text);
}

fn displayLabelMaxLineLen(text: []const u8) usize {
    return labelMaxLineLen(text);
}

fn displayLabelEstimatedWidth(text: []const u8, font_size: f64) f64 {
    return labelEstimatedWidth(text, font_size);
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
    for (graph.subgraphs.items) |cluster| {
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

fn firstClusterMemberIndex(cluster: Subgraph, nodes: []const NodeId) ?usize {
    for (nodes, 0..) |node_id, index| {
        if (containsNode(cluster.nodes, node_id)) return index;
    }
    return null;
}

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
    if (cluster_gap <= 0 or graph.subgraphs.items.len == 0) return;
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
    if (graph.subgraphs.items.len == 0 or max_extent <= 0) return;
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
        nudgeSameClusterPredecessors(graph, ranks, centers, edge_item.from, from_cluster, shift * 0.7);
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
    if (graph.subgraphs.items.len == 0 or max_extent <= 0) return;
    const side_gap: f64 = 28.0;
    const min_clearance: f64 = 35.0;
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
            .nodes = graph.subgraphs.items[from_cluster].nodes,
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

fn solveClusterBoundary(cluster: Subgraph, centers: []const f64, sizes: []const NodeSize, margin: f64) ?ClusterContainment {
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

fn clusterContainmentEnvelope(cluster: Subgraph, centers: []const f64, sizes: []const NodeSize, margin: f64) ?ClusterContainment {
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
    svg,

    pub fn fromString(value: []const u8) ?OutputFormat {
        if (std.ascii.eqlIgnoreCase(value, "svg")) return .svg;
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
};

pub fn render(writer: *Io.Writer, layout: *const Layout, format: OutputFormat, options: RenderOptions) Io.Writer.Error!void {
    return renderLayout(writer, &layout.graph, layout, format, options);
}

pub fn renderLayout(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, format: OutputFormat, options: RenderOptions) Io.Writer.Error!void {
    return switch (format) {
        .svg => renderSvg(writer, graph, layout, options.svg),
    };
}

pub fn renderAlloc(allocator: std.mem.Allocator, layout: *const Layout, format: OutputFormat, options: RenderOptions) ![]u8 {
    var aw = Io.Writer.Allocating.init(allocator);
    errdefer aw.deinit();
    try render(&aw.writer, layout, format, options);
    return aw.toOwnedSlice();
}

pub fn renderLayoutAlloc(allocator: std.mem.Allocator, graph: *const Graph, layout: *const Layout, format: OutputFormat, options: RenderOptions) ![]u8 {
    var aw = Io.Writer.Allocating.init(allocator);
    errdefer aw.deinit();
    try renderLayout(&aw.writer, graph, layout, format, options);
    return aw.toOwnedSlice();
}

pub const SvgOptions = struct {
    background: []const u8 = "white",
    font_family: []const u8 = default_svg_font_family,
    show_title: bool = true,
};

const svg_clip_padding: f64 = 4.0;

pub fn renderSvg(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, options: SvgOptions) Io.Writer.Error!void {
    const edge_routing = svgEdgeRoutingMode(graph);
    const concentrate = graphConcentrateEnabled(graph);
    const background = attrValue(graph.attrs.items, "bgcolor") orelse options.background;
    const graph_pad = graphSvgPad(graph);
    var canvas_width = @ceil(layout.width);
    var canvas_height = @ceil(layout.height);
    var content_translate = Point{ .x = svgGraphContentTranslate(layout), .y = 0 };
    if (svgGraphContentBounds(graph, layout)) |content_bounds| {
        fitSvgContentAxis(content_bounds.x, content_bounds.x + content_bounds.width, graph_pad.x, &canvas_width, &content_translate.x);
        fitSvgContentAxis(content_bounds.y, content_bounds.y + content_bounds.height, graph_pad.y, &canvas_height, &content_translate.y);
    }
    canvas_width = @ceil(canvas_width);
    canvas_height = @ceil(canvas_height);
    const background_left = -content_translate.x;
    const background_top = -content_translate.y;
    const background_right = canvas_width - content_translate.x;
    const background_bottom = canvas_height - content_translate.y;
    if (attrValue(graph.attrs.items, "stylesheet")) |stylesheet| {
        if (stylesheet.len > 0) {
            try writer.writeAll("<?xml-stylesheet href=\"");
            try writeXmlEscaped(writer, stylesheet);
            try writer.writeAll("\" type=\"text/css\"?>\n");
        }
    }
    try writer.print(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"{d:.0}pt\" height=\"{d:.0}pt\" viewBox=\"0.00 0.00 {d:.2} {d:.2}\">\n",
        .{ canvas_width, canvas_height, canvas_width, canvas_height },
    );
    try writeSvgGroupOpenStart(writer, graph.attrs.items, "graph0", "graph");
    try writer.writeAll(" transform=\"scale(1 1) rotate(0) translate(");
    try writeSvgNumber(writer, content_translate.x);
    try writer.writeByte(' ');
    try writeSvgNumber(writer, content_translate.y);
    try writer.writeAll(")\">\n");
    if (attrValue(graph.attrs.items, "comment")) |comment| {
        if (comment.len > 0) try writeSvgComment(writer, comment);
    }
    try writer.writeAll("<title>");
    try writeXmlEscaped(writer, graph.name);
    try writer.writeAll("</title>\n");
    const graph_wrap = try writeSvgInteractiveOpen(writer, graph.allocator, graph.attrs.items, .{ .graph_name = graph.name }, graphFallbackTitle(graph));
    try writer.print("<polygon fill=\"{s}\" stroke=\"none\" points=\"", .{background});
    try writeSvgPoint(writer, .{ .x = background_left, .y = background_top });
    try writer.writeByte(' ');
    try writeSvgPoint(writer, .{ .x = background_left, .y = background_bottom });
    try writer.writeByte(' ');
    try writeSvgPoint(writer, .{ .x = background_right, .y = background_bottom });
    try writer.writeByte(' ');
    try writeSvgPoint(writer, .{ .x = background_right, .y = background_top });
    try writer.writeByte(' ');
    try writeSvgPoint(writer, .{ .x = background_left, .y = background_top });
    try writer.writeAll("\"/>\n");
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
        try writeSvgTextOpen(writer, text_anchor, title_x, title_y, title_font, title_size);
        try writeSvgTextFill(writer, title_color);
        try writer.writeAll(">");
        try writeXmlEscaped(writer, graph_label);
        try writer.writeAll("</text>\n");
    }
    try writeSvgInteractiveClose(writer, graph_wrap);
    if (svgNeedsMarkerDefs(graph, concentrate)) {
        try writer.writeAll("<defs>\n");
        for (graph.edges.items) |edge_item| {
            if (concentrate and isConcentratedDuplicateEdge(graph, edge_item.id)) continue;
            const visual = resolveEdgeVisual(edge_item);
            if (visual.marker_end != .none and visual.marker_end != .normal) try writeSvgMarkerDef(writer, edge_item.id, "head", visual.marker_end, edgeMarkerColor(edge_item, visual, true), edgeMarkerFill(edge_item, visual, true), visual.marker_scale);
            if (visual.marker_start != .none and visual.marker_start != .normal) try writeSvgMarkerDef(writer, edge_item.id, "tail", visual.marker_start, edgeMarkerColor(edge_item, visual, false), edgeMarkerFill(edge_item, visual, false), visual.marker_scale);
        }
        try writer.writeAll("</defs>\n");
    }

    try renderSvgClusters(writer, graph, layout);
    try renderSvgGraphItems(writer, graph, layout, options, edge_routing, concentrate);
    try writer.writeAll("</g>\n</svg>");
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
    var default_id_buf: [32]u8 = undefined;
    const default_id = std.fmt.bufPrint(&default_id_buf, "edge{d}", .{edge_item.id + 1}) catch unreachable;
    try writeSvgGroupOpen(writer, edge_item.attrs.items, default_id, "edge");
    var edge_name_buf: [256]u8 = undefined;
    const edge_context = svgEdgeEscapeContext(graph, edge_item, &edge_name_buf);
    const edge_wrap = try writeSvgInteractiveOpenKind(writer, graph.allocator, edge_item.attrs.items, .edge, edge_context, edgeFallbackTitle(edge_item, edge_context.edge_name));
    if (edge_wrap == .none) {
        try writeSvgEdgeTitle(writer, graph, edge_item);
        try writer.writeByte('\n');
    }
    if (edge_item.from == edge_item.to) {
        const route = selfLoopRoute(layout.nodes[edge_item.from]);
        try renderSvgSelfLoopPaths(writer, graph.directed, edge_item, route, visual);
        if (edge_item.label) |label| {
            try renderSvgEdgeInteractiveLabel(writer, graph, edge_item, .label, label, route.label, visual.font_size, visual.font_color, visual.font_family);
        }
        try renderSvgExtraEdgeLabels(writer, graph, layout, edge_item, route, visual);
        try writeSvgInteractiveClose(writer, edge_wrap);
        try writer.writeAll("</g>\n");
        return;
    }

    const offset = parallelEdgeOffset(graph, edge_item.id);
    const route = edgeRouteForEdge(graph, layout, edge_item, layout.rankdir, offset);
    const hints = EdgePathHints{
        .tail_mdiamond = graph.nodes.items[edge_item.from].shape == .mdiamond,
        .head_msquare = graph.nodes.items[edge_item.to].shape == .msquare,
    };
    try renderSvgEdgePaths(writer, graph.directed, layout, edge_item, layout.rankdir, offset, route, edge_routing, visual, hints);
    if (edge_item.label) |label| {
        const label_center = edgeLabelCenterAvoidingNodes(graph, layout, edge_item, route, visual, label);
        try renderSvgEdgeInteractiveLabel(writer, graph, edge_item, .label, label, label_center, visual.font_size, visual.font_color, visual.font_family);
    }
    try renderSvgExtraEdgeLabels(writer, graph, layout, edge_item, route, visual);
    try writeSvgInteractiveClose(writer, edge_wrap);
    try writer.writeAll("</g>\n");
}

fn edgeLabelCenterAvoidingNodes(graph: *const Graph, layout: *const Layout, edge_item: Edge, route: EdgeRoute, visual: EdgeVisual, label: []const u8) Point {
    return edgeLabelCenterAvoidingNodesFrom(graph, layout, edge_item, label, visual.font_size, .{ .x = route.label.x, .y = route.label.y - 6.0 });
}

fn edgeXLabelCenterAvoidingNodes(graph: *const Graph, layout: *const Layout, edge_item: Edge, route: EdgeRoute, label: []const u8, font_size: f64) Point {
    return edgeLabelCenterAvoidingNodesFrom(graph, layout, edge_item, label, font_size, .{ .x = route.label.x, .y = route.label.y + 18.0 });
}

fn edgeLabelCenterAvoidingNodesFrom(graph: *const Graph, layout: *const Layout, edge_item: Edge, label: []const u8, font_size: f64, base: Point) Point {
    const base_rect = edgeLabelRect(label, base, font_size);
    if (!edgeLabelOverlapsNodes(graph, layout, edge_item, base_rect)) return base;

    var candidates: [96]Point = undefined;
    var candidate_count: usize = 0;
    const rank_offsets = [_]f64{ -24, 24, -36, 36, -54, 54, -72, 72 };
    for (rank_offsets) |offset| appendEdgeLabelCandidate(&candidates, &candidate_count, shiftLabelRankAxis(base, layout.rankdir, offset));
    const cross_offsets = [_]f64{ -36, 36, -54, 54, -72, 72 };
    for (cross_offsets) |offset| appendEdgeLabelCandidate(&candidates, &candidate_count, shiftLabelCrossAxis(base, layout.rankdir, offset));
    for (rank_offsets) |rank_offset| {
        const rank_shifted = shiftLabelRankAxis(base, layout.rankdir, rank_offset);
        for (cross_offsets) |cross_offset| {
            appendEdgeLabelCandidate(&candidates, &candidate_count, shiftLabelCrossAxis(rank_shifted, layout.rankdir, cross_offset));
        }
    }

    const label_rect = edgeLabelRect(label, base, font_size);
    for (graph.nodes.items) |node_item| {
        if (node_item.id >= layout.nodes.len) continue;
        if (resolveNodeVisual(node_item).hidden) continue;
        const rect = expandRect(nodeRect(graphvizRenderNodeLayout(graph, layout, node_item)), 4.0);
        if (!rectsOverlap(label_rect, rect)) continue;
        const half_width = label_rect.width / 2.0;
        const half_height = label_rect.height / 2.0;
        appendEdgeLabelCandidate(&candidates, &candidate_count, .{ .x = base.x, .y = rect.y - half_height - 6.0 });
        appendEdgeLabelCandidate(&candidates, &candidate_count, .{ .x = base.x, .y = rect.y + rect.height + half_height + 6.0 });
        appendEdgeLabelCandidate(&candidates, &candidate_count, .{ .x = rect.x - half_width - 6.0, .y = base.y });
        appendEdgeLabelCandidate(&candidates, &candidate_count, .{ .x = rect.x + rect.width + half_width + 6.0, .y = base.y });
    }

    var best = base;
    var best_score = std.math.floatMax(f64);
    for (candidates[0..candidate_count]) |candidate| {
        const rect = edgeLabelRect(label, candidate, font_size);
        if (!labelRectInsideLayout(rect, layout)) continue;
        if (edgeLabelOverlapsNodes(graph, layout, edge_item, rect)) continue;
        const dx = candidate.x - base.x;
        const dy = candidate.y - base.y;
        const score = dx * dx + dy * dy;
        if (score < best_score) {
            best_score = score;
            best = candidate;
        }
    }
    return best;
}

fn appendEdgeLabelCandidate(candidates: *[96]Point, count: *usize, candidate: Point) void {
    if (count.* >= candidates.len) return;
    candidates[count.*] = candidate;
    count.* += 1;
}

fn shiftLabelRankAxis(point: Point, rankdir: RankDir, offset: f64) Point {
    return switch (rankdir) {
        .TB, .BT => .{ .x = point.x, .y = point.y + offset },
        .LR, .RL => .{ .x = point.x + offset, .y = point.y },
    };
}

fn shiftLabelCrossAxis(point: Point, rankdir: RankDir, offset: f64) Point {
    return switch (rankdir) {
        .TB, .BT => .{ .x = point.x + offset, .y = point.y },
        .LR, .RL => .{ .x = point.x, .y = point.y + offset },
    };
}

fn edgeLabelRect(label: []const u8, center: Point, font_size: f64) RectF {
    const line_height = font_size * 1.25;
    const height = @as(f64, @floatFromInt(displayLabelLineCount(label))) * line_height + 8.0;
    const width = displayLabelEstimatedWidth(label, font_size) + 12.0;
    return .{
        .x = center.x - width / 2.0,
        .y = center.y - height / 2.0,
        .width = width,
        .height = height,
    };
}

fn edgeLabelOverlapsNodes(graph: *const Graph, layout: *const Layout, edge_item: Edge, label_rect: RectF) bool {
    _ = edge_item;
    for (graph.nodes.items) |node_item| {
        if (node_item.id >= layout.nodes.len) continue;
        if (resolveNodeVisual(node_item).hidden) continue;
        const rect = expandRect(nodeRect(graphvizRenderNodeLayout(graph, layout, node_item)), 2.0);
        if (rectsOverlap(label_rect, rect)) return true;
    }
    return false;
}

fn labelRectInsideLayout(rect: RectF, layout: *const Layout) bool {
    const padding: f64 = 2.0;
    return rect.x >= padding and rect.y >= padding and
        rect.x + rect.width <= layout.width - padding and
        rect.y + rect.height <= layout.height - padding;
}

fn rectsOverlap(a: RectF, b: RectF) bool {
    return @max(a.x, b.x) < @min(a.x + a.width, b.x + b.width) and
        @max(a.y, b.y) < @min(a.y + a.height, b.y + b.height);
}

fn renderSvgNodeGroup(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, options: SvgOptions, node_item: Node) Io.Writer.Error!void {
    var visual = resolveNodeVisual(node_item);
    if (visual.hidden) return;
    const l = graphvizRenderNodeLayout(graph, layout, node_item);
    try writeSvgNodeNameComment(writer, node_item);
    var default_id_buf: [32]u8 = undefined;
    const default_id = std.fmt.bufPrint(&default_id_buf, "node{d}", .{node_item.id + 1}) catch unreachable;
    try writeSvgGroupOpen(writer, node_item.attrs.items, default_id, "node");
    const node_name = svgNodeName(node_item);
    const node_wrap = try writeSvgInteractiveOpen(writer, graph.allocator, node_item.attrs.items, .{ .graph_name = graph.name, .node_name = node_name }, nodeFallbackTitle(node_item));
    if (node_wrap == .none) {
        try writeSvgNodeNameTitle(writer, node_item);
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
    try renderSvgNodeShape(writer, node_item, l, visual, options);
    if (node_item.shape != .record and node_item.shape != .mrecord and node_item.shape != .point) {
        try renderSvgNodeLabel(writer, node_item, l, visual);
    }
    try renderSvgNodeXLabel(writer, node_item, l, visual);
    try writeSvgInteractiveClose(writer, node_wrap);
    try writer.writeAll("</g>\n");
}

fn graphvizRenderNodeLayout(graph: *const Graph, layout: *const Layout, node_item: Node) NodeLayout {
    _ = graph;
    if (node_item.id >= layout.nodes.len) return .{ .center = .{ .x = 0, .y = 0 }, .width = 0, .height = 0 };
    return layout.nodes[node_item.id];
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
    if (layout.subgraphs.len == 0) return 0;
    var min_x = std.math.floatMax(f64);
    var max_x: f64 = -std.math.floatMax(f64);
    for (layout.subgraphs) |cluster_box| {
        if (cluster_box.width <= 0 or cluster_box.height <= 0) continue;
        min_x = @min(min_x, cluster_box.x);
        max_x = @max(max_x, cluster_box.x + cluster_box.width);
    }
    if (min_x == std.math.floatMax(f64) or max_x <= min_x) return 0;
    const shift = ((layout.width - max_x) - min_x) / 2.0;
    return if (@abs(shift) < 0.05) 0 else shift;
}

fn graphSvgPad(graph: *const Graph) BoxMargin {
    const parsed = attrMargin(graph.attrs.items, svg_clip_padding);
    return .{ .x = @max(svg_clip_padding, parsed.x), .y = @max(svg_clip_padding, parsed.y) };
}

fn fitSvgContentAxis(content_min: f64, content_max: f64, padding: f64, canvas_size: *f64, translate: *f64) void {
    const screen_min = content_min + translate.*;
    const screen_max = content_max + translate.*;
    const left_deficit = padding - screen_min;
    const left_adjust = @max(0.0, left_deficit);
    translate.* += left_adjust;
    const right_deficit = screen_max + left_adjust + padding - canvas_size.*;
    if (right_deficit > 0) canvas_size.* += right_deficit;
}

fn svgGraphContentBounds(graph: *const Graph, layout: *const Layout) ?RectF {
    var bounds = BoundsBuilder{};
    for (layout.subgraphs, 0..) |cluster_box, index| {
        if (index >= graph.subgraphs.items.len or cluster_box.width <= 0 or cluster_box.height <= 0) continue;
        bounds.includeRect(clusterVisualRect(graph, layout, index));
    }
    for (graph.nodes.items) |node_item| {
        if (node_item.id >= layout.nodes.len) continue;
        if (resolveNodeVisual(node_item).hidden) continue;
        const node_layout = graphvizRenderNodeLayout(graph, layout, node_item);
        const visual = resolveNodeVisual(node_item);
        bounds.includeRect(nodeRect(node_layout));
        if (nodeXLabelRect(node_item, node_layout, visual)) |rect| bounds.includeRect(rect);
    }
    for (graph.edges.items) |edge_item| {
        if (edge_item.from >= layout.nodes.len or edge_item.to >= layout.nodes.len) continue;
        const visual = resolveEdgeVisual(edge_item);
        if (visual.hidden) continue;
        const route = if (edge_item.from == edge_item.to)
            selfLoopRoute(layout.nodes[edge_item.from])
        else
            edgeRouteForEdge(graph, layout, edge_item, layout.rankdir, parallelEdgeOffset(graph, edge_item.id));
        if (edge_item.label) |label| {
            const center = if (edge_item.from == edge_item.to)
                route.label
            else
                edgeLabelCenterAvoidingNodes(graph, layout, edge_item, route, visual, label);
            bounds.includeRect(edgeLabelRect(label, center, visual.font_size));
        }
        if (attrValue(edge_item.attrs.items, "xlabel")) |label| {
            const font_size = parsePositiveAttrFloat(edge_item.attrs.items, "labelfontsize", visual.font_size);
            const center = edgeXLabelCenterAvoidingNodes(graph, layout, edge_item, route, label, font_size);
            bounds.includeRect(edgeLabelRect(label, center, font_size));
        }
    }
    return bounds.rect();
}

const BoundsBuilder = struct {
    min_x: f64 = std.math.floatMax(f64),
    min_y: f64 = std.math.floatMax(f64),
    max_x: f64 = -std.math.floatMax(f64),
    max_y: f64 = -std.math.floatMax(f64),

    fn includeRect(self: *BoundsBuilder, item_rect: RectF) void {
        if (item_rect.width <= 0 or item_rect.height <= 0) return;
        self.min_x = @min(self.min_x, item_rect.x);
        self.min_y = @min(self.min_y, item_rect.y);
        self.max_x = @max(self.max_x, item_rect.x + item_rect.width);
        self.max_y = @max(self.max_y, item_rect.y + item_rect.height);
    }

    fn rect(self: BoundsBuilder) ?RectF {
        if (self.min_x == std.math.floatMax(f64) or self.max_x <= self.min_x or self.max_y <= self.min_y) return null;
        return .{
            .x = self.min_x,
            .y = self.min_y,
            .width = self.max_x - self.min_x,
            .height = self.max_y - self.min_y,
        };
    }
};

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

fn writeSvgGroupOpen(writer: *Io.Writer, attrs: []const Attr, default_id: []const u8, default_class: []const u8) Io.Writer.Error!void {
    try writeSvgGroupOpenStart(writer, attrs, default_id, default_class);
    try writer.writeAll(">\n");
}

fn writeSvgGroupOpenStart(writer: *Io.Writer, attrs: []const Attr, default_id: []const u8, default_class: []const u8) Io.Writer.Error!void {
    const id = attrValue(attrs, "id") orelse default_id;
    try writer.writeAll("<g id=\"");
    try writeXmlEscaped(writer, id);
    try writer.writeAll("\" class=\"");
    try writeXmlEscaped(writer, default_class);
    if (attrValue(attrs, "class")) |class| {
        if (class.len > 0) {
            try writer.writeByte(' ');
            try writeXmlEscaped(writer, class);
        }
    }
    try writer.writeByte('"');
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

fn writeSvgNodeRef(writer: *Io.Writer, node_item: Node) Io.Writer.Error!void {
    if (attrValue(node_item.attrs.items, "vex_text_id")) |text_id| {
        try writeXmlEscaped(writer, text_id);
    } else {
        try writer.print("node{d}", .{node_item.id + 1});
    }
}

fn writeSvgNodeCommentRef(writer: *Io.Writer, node_item: Node) Io.Writer.Error!void {
    if (attrValue(node_item.attrs.items, "vex_text_id")) |text_id| {
        try writeSvgCommentEscaped(writer, text_id);
    } else {
        try writer.print("node{d}", .{node_item.id + 1});
    }
}

fn svgNodeName(node_item: Node) []const u8 {
    return attrValue(node_item.attrs.items, "vex_text_id") orelse node_item.label;
}

fn graphFallbackTitle(graph: *const Graph) []const u8 {
    return attrValue(graph.attrs.items, "label") orelse graph.name;
}

fn nodeFallbackTitle(node_item: Node) []const u8 {
    return attrValue(node_item.attrs.items, "label") orelse node_item.label;
}

fn edgeFallbackTitle(edge_item: Edge, edge_name: ?[]const u8) []const u8 {
    if (edge_item.label) |label| return label;
    return edge_name orelse "";
}

fn svgEdgeEscapeContext(graph: *const Graph, edge_item: Edge, edge_name_buf: *[256]u8) LabelEscapeContext {
    const tail = if (edge_item.from < graph.nodes.items.len) svgNodeName(graph.nodes.items[edge_item.from]) else "";
    const head = if (edge_item.to < graph.nodes.items.len) svgNodeName(graph.nodes.items[edge_item.to]) else "";
    const op = if (graph.directed) "->" else "--";
    const edge_name = std.fmt.bufPrint(edge_name_buf, "{s}{s}{s}", .{ tail, op, head }) catch tail;
    return .{
        .graph_name = graph.name,
        .node_name = edge_name,
        .tail_name = tail,
        .head_name = head,
        .edge_name = edge_name,
    };
}

fn writeSvgNodeNameComment(writer: *Io.Writer, node_item: Node) Io.Writer.Error!void {
    if (attrValue(node_item.attrs.items, "comment")) |comment| {
        try writeSvgComment(writer, comment);
        return;
    }
    try writer.writeAll("<!-- ");
    try writeSvgNodeCommentRef(writer, node_item);
    try writer.writeAll(" -->\n");
}

fn writeSvgEdgeComment(writer: *Io.Writer, graph: *const Graph, edge_item: Edge) Io.Writer.Error!void {
    if (edge_item.from >= graph.nodes.items.len or edge_item.to >= graph.nodes.items.len) return;
    if (attrValue(edge_item.attrs.items, "comment")) |comment| {
        try writeSvgComment(writer, comment);
        return;
    }
    try writer.writeAll("<!-- ");
    try writeSvgNodeCommentRef(writer, graph.nodes.items[edge_item.from]);
    try writer.writeAll(if (graph.directed) "&#45;&gt;" else "&#45;&#45;");
    try writeSvgNodeCommentRef(writer, graph.nodes.items[edge_item.to]);
    try writer.writeAll(" -->\n");
}

const SvgInteractiveWrap = enum {
    none,
    anchor,
    group,
};

const SvgInteractiveKind = enum {
    default,
    edge,
    label,
    head,
    tail,
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
        try writeSvgRectOpen(writer, .{ .x = cursor, .y = rect.y, .width = stripe_width, .height = rect.height }, radius);
        try writer.print(" fill=\"{s}\" stroke=\"none\"/>\n", .{segment.color});
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

fn writeSvgInteractiveOpen(writer: *Io.Writer, allocator: std.mem.Allocator, attrs: []const Attr, context: LabelEscapeContext, fallback_title: ?[]const u8) Io.Writer.Error!SvgInteractiveWrap {
    return writeSvgInteractiveOpenKind(writer, allocator, attrs, .default, context, fallback_title);
}

fn writeSvgInteractiveOpenKind(writer: *Io.Writer, allocator: std.mem.Allocator, attrs: []const Attr, kind: SvgInteractiveKind, context: LabelEscapeContext, fallback_title: ?[]const u8) Io.Writer.Error!SvgInteractiveWrap {
    const href = interactiveHref(attrs, kind);
    const tooltip = interactiveTooltip(attrs, kind) orelse if (href != null) fallback_title else null;
    const link_target = interactiveTarget(attrs, kind);
    if (href == null and tooltip == null) return .none;

    const expanded_tooltip = if (tooltip) |tip| expandLabelEscapes(allocator, tip, context) catch tip else null;
    defer if (expanded_tooltip) |tip| {
        if (tooltip != null and tip.ptr != tooltip.?.ptr) allocator.free(tip);
    };
    const expanded_target = if (link_target) |target| expandLabelEscapes(allocator, target, context) catch target else null;
    defer if (expanded_target) |target| {
        if (link_target != null and target.ptr != link_target.?.ptr) allocator.free(target);
    };

    if (href) |target_href| {
        const expanded_href = expandLabelEscapes(allocator, target_href, context) catch target_href;
        defer if (expanded_href.ptr != target_href.ptr) allocator.free(expanded_href);
        try writer.writeAll("<a href=\"");
        try writeXmlEscaped(writer, expanded_href);
        try writer.writeByte('"');
        if (expanded_target) |value| {
            try writer.writeAll(" target=\"");
            try writeXmlEscaped(writer, value);
            try writer.writeByte('"');
        }
        try writer.writeByte('>');
        if (expanded_tooltip) |tip| try writeSvgTitle(writer, tip);
        return .anchor;
    }

    try writer.writeAll("<g>");
    if (expanded_tooltip) |tip| try writeSvgTitle(writer, tip);
    return .group;
}

fn interactiveHref(attrs: []const Attr, kind: SvgInteractiveKind) ?[]const u8 {
    return switch (kind) {
        .default => attrValue(attrs, "href") orelse attrValue(attrs, "URL") orelse attrValue(attrs, "url"),
        .edge => attrValue(attrs, "edgehref") orelse attrValue(attrs, "edgeURL") orelse attrValue(attrs, "edgeurl") orelse attrValue(attrs, "href") orelse attrValue(attrs, "URL") orelse attrValue(attrs, "url"),
        .label => attrValue(attrs, "labelhref") orelse attrValue(attrs, "labelURL") orelse attrValue(attrs, "labelurl") orelse interactiveHref(attrs, .edge),
        .head => attrValue(attrs, "headhref") orelse attrValue(attrs, "headURL") orelse attrValue(attrs, "headurl") orelse interactiveHref(attrs, .edge),
        .tail => attrValue(attrs, "tailhref") orelse attrValue(attrs, "tailURL") orelse attrValue(attrs, "tailurl") orelse interactiveHref(attrs, .edge),
    };
}

fn interactiveTooltip(attrs: []const Attr, kind: SvgInteractiveKind) ?[]const u8 {
    return switch (kind) {
        .default => attrValue(attrs, "tooltip") orelse attrValue(attrs, "title"),
        .edge => attrValue(attrs, "edgetooltip") orelse attrValue(attrs, "tooltip") orelse attrValue(attrs, "title"),
        .label => attrValue(attrs, "labeltooltip") orelse interactiveTooltip(attrs, .edge),
        .head => attrValue(attrs, "headtooltip") orelse interactiveTooltip(attrs, .edge),
        .tail => attrValue(attrs, "tailtooltip") orelse interactiveTooltip(attrs, .edge),
    };
}

fn interactiveTarget(attrs: []const Attr, kind: SvgInteractiveKind) ?[]const u8 {
    return switch (kind) {
        .default => attrValue(attrs, "target"),
        .edge => attrValue(attrs, "edgetarget") orelse attrValue(attrs, "target"),
        .label => attrValue(attrs, "labeltarget") orelse interactiveTarget(attrs, .edge),
        .head => attrValue(attrs, "headtarget") orelse interactiveTarget(attrs, .edge),
        .tail => attrValue(attrs, "tailtarget") orelse interactiveTarget(attrs, .edge),
    };
}

fn writeSvgTitle(writer: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    try writer.writeAll("<title>");
    try writeXmlEscaped(writer, text);
    try writer.writeAll("</title>");
}

fn writeSvgNodeNameTitle(writer: *Io.Writer, node_item: Node) Io.Writer.Error!void {
    try writer.writeAll("<title>");
    try writeSvgNodeRef(writer, node_item);
    try writer.writeAll("</title>");
}

fn writeSvgEdgeTitle(writer: *Io.Writer, graph: *const Graph, edge_item: Edge) Io.Writer.Error!void {
    if (edge_item.from >= graph.nodes.items.len or edge_item.to >= graph.nodes.items.len) return;
    try writer.writeAll("<title>");
    try writeSvgNodeRef(writer, graph.nodes.items[edge_item.from]);
    try writer.writeAll(if (graph.directed) "-&gt;" else "--");
    try writeSvgNodeRef(writer, graph.nodes.items[edge_item.to]);
    try writer.writeAll("</title>");
}

fn writeSvgInteractiveClose(writer: *Io.Writer, wrap: SvgInteractiveWrap) Io.Writer.Error!void {
    switch (wrap) {
        .none => {},
        .anchor => try writer.writeAll("</a>\n"),
        .group => try writer.writeAll("</g>\n"),
    }
}

fn renderSvgExtraEdgeLabels(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, edge_item: Edge, route: EdgeRoute, visual: EdgeVisual) Io.Writer.Error!void {
    const label_font_size = parsePositiveAttrFloat(edge_item.attrs.items, "labelfontsize", visual.font_size);
    const label_font_color = attrValue(edge_item.attrs.items, "labelfontcolor") orelse visual.font_color;
    const label_font_family = attrValue(edge_item.attrs.items, "labelfontname") orelse visual.font_family;
    const label_distance = std.math.clamp(parseAttrFloat(edge_item.attrs.items, "labeldistance", 1.0), 0.0, 16.0);
    const label_angle = parseAttrFloat(edge_item.attrs.items, "labelangle", -25.0);
    if (attrValue(edge_item.attrs.items, "taillabel")) |label| {
        const pos = endpointLabelPosition(route.start, route.label, label_distance, -label_angle, false);
        try renderSvgEdgeInteractiveLabel(writer, graph, edge_item, .tail, label, pos, label_font_size, label_font_color, label_font_family);
    }
    if (attrValue(edge_item.attrs.items, "headlabel")) |label| {
        const pos = endpointLabelPosition(route.end, route.label, label_distance, label_angle, true);
        try renderSvgEdgeInteractiveLabel(writer, graph, edge_item, .head, label, pos, label_font_size, label_font_color, label_font_family);
    }
    if (attrValue(edge_item.attrs.items, "xlabel")) |label| {
        const pos = edgeXLabelCenterAvoidingNodes(graph, layout, edge_item, route, label, label_font_size);
        try renderSvgEdgeInteractiveLabel(writer, graph, edge_item, .label, label, pos, label_font_size, label_font_color, label_font_family);
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

fn renderSvgEdgeInteractiveLabel(writer: *Io.Writer, graph: *const Graph, edge_item: Edge, kind: SvgInteractiveKind, label: []const u8, pos: Point, font_size: f64, font_color: []const u8, font_family: []const u8) Io.Writer.Error!void {
    var edge_name_buf: [256]u8 = undefined;
    var context = svgEdgeEscapeContext(graph, edge_item, &edge_name_buf);
    context.node_name = label;
    const wrap = try writeSvgInteractiveOpenKind(writer, graph.allocator, edge_item.attrs.items, kind, context, label);
    try renderSvgTextBlock(writer, label, pos.x, pos.y, font_size, font_color, font_family, true, true);
    try writeSvgInteractiveClose(writer, wrap);
}

fn renderSvgEdgePaths(writer: *Io.Writer, directed: bool, layout: *const Layout, edge_item: Edge, rankdir: RankDir, base_offset: f64, route: EdgeRoute, routing: SvgEdgeRouting, visual: EdgeVisual, hints: EdgePathHints) Io.Writer.Error!void {
    const render_route = graphvizMsquareHeadRoute(graphvizDiamondTailRoute(graphvizCrossClusterLongRoute(layout, edge_item, rankdir, crossClusterLeftDiagonalRoute(layout, edge_item, rankdir, route)), rankdir, hints), rankdir, hints);
    if (edgeColorList(edge_item)) |colors| {
        const spacing = @max(4.0, visual.width + 3.0);
        for (colors.segments[0..colors.len], 0..) |segment, index| {
            const color_offset = colorListOffset(colors.len, index, spacing);
            const segment_route = edgeRouteForEdgeWithColorOffset(render_route, rankdir, color_offset);
            const segment_visual = edgeVisualForSegment(edge_item, visual, segment.color, index, colors.len);
            const back_edge = isBackEdge(layout, edge_item);
            const path_route = if (back_edge) segment_route else routeForPathMarkers(segment_route, segment_visual);
            const path_clip = if (back_edge) edgePathClip(segment_visual) else EdgePathClip{};
            try writer.print("<path fill=\"none\" stroke=\"{s}\" d=\"", .{segment.color});
            try writeEdgePath(writer, layout, edge_item, rankdir, base_offset + color_offset, path_route, routing, path_clip, hints);
            try writer.writeByte('"');
            try writeSvgStrokeWidth(writer, visual.width);
            try writeSvgDash(writer, visual.dash);
            try writeSvgMarkerAttrs(writer, directed, edge_item.id, segment_visual);
            try writer.writeAll("/>\n");
            try writeSvgInlineArrowheads(writer, directed, routeForInlineArrowheads(layout, edge_item, rankdir, segment_route), segment_visual, .{});
        }
        return;
    }

    const back_edge = isBackEdge(layout, edge_item);
    const path_route = if (back_edge) render_route else routeForPathMarkers(render_route, visual);
    const path_clip = if (back_edge) edgePathClip(visual) else EdgePathClip{};
    try writer.print("<path fill=\"none\" stroke=\"{s}\" d=\"", .{visual.stroke});
    try writeEdgePath(writer, layout, edge_item, rankdir, base_offset, path_route, routing, path_clip, hints);
    try writer.writeByte('"');
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writeSvgMarkerAttrs(writer, directed, edge_item.id, visual);
    try writer.writeAll("/>\n");
    const inline_route = if (back_edge)
        backEdgeInlineArrowRoute(layout, edge_item, rankdir, base_offset, render_route, routing)
    else
        graphvizMsquareHeadInlineArrowRoute(graphvizDiamondTailInlineArrowRoute(graphvizCrossClusterLeftInlineArrowRoute(layout, edge_item, rankdir, graphvizCrossClusterLongInlineArrowRoute(layout, edge_item, rankdir, routeForInlineArrowheads(layout, edge_item, rankdir, render_route))), rankdir, hints), rankdir, hints);
    const inline_options: InlineArrowOptions = if (back_edge)
        .{ .head_precise = true, .head_tip_x_shift = -0.01, .head_tip_y_shift = 0.01, .head_right_x_shift = 0.02, .head_right_y_shift = 0.06, .head_left_x_shift = 0.04, .head_left_y_shift = 0.02 }
    else
        inlineArrowOptions(layout, edge_item, rankdir, render_route, hints);
    try writeSvgInlineArrowheads(writer, directed, inline_route, visual, inline_options);
}

fn inlineArrowOptions(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute, hints: EdgePathHints) InlineArrowOptions {
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (rightMiddleAdjacentPathShiftApplies(layout, edge_item, rankdir)) return .{ .head_precise = true, .head_tip_x_shift = 0.01, .head_tip_y_shift = 0.03, .head_right_x_shift = -0.04, .head_right_y_shift = 0.01, .head_left_x_shift = -0.04, .head_left_y_shift = 0.05 };
    if (rightOuterAdjacentRouteShiftApplies(layout, edge_item, rankdir)) return .{ .head_precise = true, .head_tip_x_shift = -0.01, .head_y_shift = 0.03, .head_left_x_shift = -0.01, .head_left_y_shift = -0.01 };
    if (rightLowerAdjacentRouteShiftApplies(layout, edge_item, rankdir)) return .{ .head_precise = true, .head_tip_x_shift = 0.01, .head_right_x_shift = 0.02, .head_right_y_shift = 0.01, .head_left_x_shift = 0.03, .head_left_y_shift = -0.01 };
    if (edgeTouchesMultipleClusters(layout, edge_item) and longEdgeWaypointCount(layout, edge_item) == 1) return .{ .head_precise = true, .head_tip_x_shift = 0.01, .head_tip_y_shift = -0.01, .head_right_x_shift = -0.03, .head_left_x_shift = -0.02, .head_left_y_shift = 0.02 };
    if (edgeTouchesMultipleClusters(layout, edge_item) and longEdgeWaypointCount(layout, edge_item) == 0 and dx < 0) return .{ .head_precise = true, .head_left_x_shift = 0.01 };
    if (@abs(dx) < 0.001) return .{ .head_precise = true, .head_y_shift = 0.03 };
    if (@abs(dx) < @abs(dy) * 0.35) return .{ .head_precise = true };
    if (hints.tail_mdiamond and dx >= 0) return .{ .head_length_scale = 1.001, .head_precise = true, .head_right_x_shift = -0.04, .head_left_x_shift = -0.02, .head_left_y_shift = 0.01, .head_tip_x_shift = -0.01, .head_tip_y_shift = -0.02 };
    if (hints.tail_mdiamond and dx < 0) return .{ .head_precise = true, .head_right_x_shift = -0.01, .head_right_y_shift = -0.01, .head_left_x_shift = -0.02 };
    if (hints.head_msquare and dx >= 0) return .{ .head_precise = true, .head_tip_x_shift = -0.01, .head_right_x_shift = 0.01, .head_right_y_shift = -0.01, .head_left_y_shift = -0.03 };
    if (hints.head_msquare and dx < 0) return .{ .head_precise = true, .head_right_x_shift = -0.02, .head_right_y_shift = -0.03, .head_left_x_shift = -0.04, .head_left_y_shift = -0.01 };
    return .{};
}

fn graphvizCrossClusterLeftInlineArrowRoute(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute) EdgeRoute {
    if (!edgeTouchesMultipleClusters(layout, edge_item)) return route;
    if (rankdir != .TB and rankdir != .BT) return route;
    if (longEdgeWaypointCount(layout, edge_item) != 0) return route;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (dx >= 0 or @abs(dx) < @abs(dy) * 0.35) return route;
    var result = route;
    result.end.x -= 0.12;
    result.end.y += if (rankdir == .TB) -0.38 else 0.38;
    const graphviz_arrow_axis_x: f64 = 8.44;
    const graphviz_arrow_axis_y: f64 = if (rankdir == .TB) -5.37 else 5.37;
    result.control2 = .{
        .x = result.end.x + graphviz_arrow_axis_x,
        .y = result.end.y + graphviz_arrow_axis_y,
    };
    return result;
}

fn graphvizDiamondTailInlineArrowRoute(route: EdgeRoute, rankdir: RankDir, hints: EdgePathHints) EdgeRoute {
    if (!hints.tail_mdiamond) return route;
    if (rankdir != .TB and rankdir != .BT) return route;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (@abs(dx) < @abs(dy) * 0.35) return route;
    var result = route;
    result.end.x += if (dx >= 0) 0.25 else -0.17;
    if (dx >= 0) result.end.x += 0.08;
    result.end.y += if (rankdir == .TB) 0.40 else -0.40;
    if (dx < 0) {
        result.end.y += if (rankdir == .TB) -0.03 else 0.03;
        result.control2.x -= 0.05;
    }
    return result;
}

fn graphvizMsquareHeadInlineArrowRoute(route: EdgeRoute, rankdir: RankDir, hints: EdgePathHints) EdgeRoute {
    if (!hints.head_msquare) return route;
    if (rankdir != .TB and rankdir != .BT) return route;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (@abs(dx) < @abs(dy) * 0.35) return route;
    var result = route;
    result.end.x += if (dx >= 0) -0.51 else -0.22;
    result.end.y += if (rankdir == .TB) -0.10 else 0.10;
    result.control2.x -= 0.20;
    if (dx >= 0) result.control2.y -= if (rankdir == .TB) 0.08 else -0.08;
    if (dx < 0) {
        result.end.y += if (rankdir == .TB) 0.01 else -0.01;
        result.control2.y += if (rankdir == .TB) -0.25 else 0.25;
    }
    return result;
}

fn graphvizCrossClusterLongInlineArrowRoute(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute) EdgeRoute {
    if (!edgeTouchesMultipleClusters(layout, edge_item)) return route;
    if (rankdir != .TB and rankdir != .BT) return route;
    if (longEdgeWaypointCount(layout, edge_item) != 1) return route;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (dx <= 0 or @abs(dx) < @abs(dy) * 0.35) return route;
    var result = route;
    const x_shift: f64 = -0.55;
    const y_shift: f64 = if (rankdir == .TB) -0.55 else 0.55;
    result.end.x += x_shift;
    result.end.y += y_shift;
    return result;
}

fn routeForInlineArrowheads(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute) EdgeRoute {
    if (isBackEdge(layout, edge_item)) return route;
    _ = rankdir;
    return route;
}

fn backEdgeInlineArrowRoute(layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64, route: EdgeRoute, routing: SvgEdgeRouting) EdgeRoute {
    if (edge_item.from >= layout.nodes.len or edge_item.to >= layout.nodes.len) return route;
    const from = layout.nodes[edge_item.from];
    const to = layout.nodes[edge_item.to];
    const side_gap = @max(5.0, layout.margin * 0.3) + @abs(offset);
    var result = route;

    if (rankdir == .TB or rankdir == .BT) {
        const prefer_left = backEdgeUsesNegativeSide(layout, edge_item, rankdir);
        var side_x = if (prefer_left)
            @max(layout.margin_x, @min(from.center.x - from.width / 2.0, to.center.x - to.width / 2.0) - side_gap)
        else
            @min(layout.width - layout.margin_x, @max(from.center.x + from.width / 2.0, to.center.x + to.width / 2.0) + side_gap);
        if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) side_x -= 0.55;
        const rank_delta = route.end.y - route.start.y;
        const p1 = Point{ .x = side_x, .y = route.start.y + rank_delta * 0.20 };
        const p2 = Point{ .x = side_x, .y = route.end.y - rank_delta * 0.21 };
        if (routing == .polyline) {
            result.control1 = p1;
            result.control2 = p2;
        } else {
            const start_side_dx = side_x - route.start.x;
            const end_side_dx = side_x - route.end.x;
            result.control1 = .{ .x = route.start.x + start_side_dx * 0.42, .y = route.start.y + rank_delta * 0.05 };
            result.control2 = .{ .x = route.end.x + end_side_dx * 0.60, .y = route.end.y - rank_delta * 0.10 };
        }
        if (graphvizSameClusterBackEdgePathEndShift(layout, edge_item, rankdir, prefer_left)) |shift| {
            result.end = .{ .x = result.end.x + shift.x, .y = result.end.y + shift.y };
        }
        if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) {
            result.control2.x -= 0.5;
            result.control2.y -= 0.35;
            result.end.x -= 0.45;
            result.end.y += if (rankdir == .TB) 0.5 else -0.5;
        }
        return result;
    }

    const prefer_top = backEdgeUsesNegativeSide(layout, edge_item, rankdir);
    const side_y = if (prefer_top)
        @max(layout.margin_y, @min(from.center.y - from.height / 2.0, to.center.y - to.height / 2.0) - side_gap)
    else
        @min(layout.height - layout.margin_y, @max(from.center.y + from.height / 2.0, to.center.y + to.height / 2.0) + side_gap);
    const rank_delta = route.end.x - route.start.x;
    const p1 = Point{ .x = route.start.x + rank_delta * 0.20, .y = side_y };
    const p2 = Point{ .x = route.end.x - rank_delta * 0.21, .y = side_y };
    if (routing == .polyline) {
        result.control1 = p1;
        result.control2 = p2;
    } else {
        const start_side_dy = side_y - route.start.y;
        const end_side_dy = side_y - route.end.y;
        result.control1 = .{ .x = route.start.x + rank_delta * 0.05, .y = route.start.y + start_side_dy * 0.42 };
        result.control2 = .{ .x = route.end.x - rank_delta * 0.10, .y = route.end.y + end_side_dy * 0.60 };
    }
    return result;
}

fn graphvizSameClusterBackEdgePathEndShift(layout: *const Layout, edge_item: Edge, rankdir: RankDir, prefer_negative_side: bool) ?Point {
    if (!prefer_negative_side) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    if (!edgeTouchesSingleCluster(layout, edge_item)) return null;
    const y_shift: f64 = if (rankdir == .TB) 1.4 else -1.4;
    return .{ .x = 0.0, .y = y_shift };
}

fn graphvizSameClusterBackEdgePathStartOnlyShift(layout: *const Layout, edge_item: Edge, rankdir: RankDir, prefer_negative_side: bool) ?Point {
    if (!prefer_negative_side) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    if (!edgeTouchesSingleCluster(layout, edge_item)) return null;
    const y_shift: f64 = if (rankdir == .TB) 1.2 else -1.2;
    return .{ .x = 0.0, .y = y_shift };
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
            try writeSvgInlineArrowheads(writer, directed, shifted, segment_visual, .{});
        }
        return;
    }

    try writeSvgSelfLoopPath(writer, route, visual);
    try writeSvgMarkerAttrs(writer, directed, edge_item.id, visual);
    try writer.writeAll("/>\n");
    try writeSvgInlineArrowheads(writer, directed, route, visual, .{});
}

fn writeSvgSelfLoopPath(writer: *Io.Writer, route: EdgeRoute, visual: EdgeVisual) Io.Writer.Error!void {
    try writer.print("<path d=\"", .{});
    try writePathMove(writer, route.start);
    try writePathCubic(writer, route.control1, route.control2, route.end);
    try writer.print("\" stroke=\"{s}\"", .{visual.stroke});
    try writeSvgStrokeWidth(writer, visual.width);
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

fn edgeMarkerFill(edge_item: Edge, visual: EdgeVisual, head: bool) []const u8 {
    if (attrValue(edge_item.attrs.items, "fillcolor")) |fillcolor| return fillcolor;
    return edgeMarkerColor(edge_item, visual, head);
}

fn edgeVisualForSegment(edge_item: Edge, visual: EdgeVisual, color: []const u8, index: usize, color_count: usize) EdgeVisual {
    var result = visual;
    result.stroke = color;
    if (attrValue(edge_item.attrs.items, "fillcolor") == null) result.fill = color;
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

fn crossClusterLeftDiagonalRoute(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute) EdgeRoute {
    if (!edgeTouchesMultipleClusters(layout, edge_item)) return route;
    if (rankdir != .TB and rankdir != .BT) return route;
    if (longEdgeWaypointCount(layout, edge_item) != 0) return route;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (dx >= 0 or @abs(dx) < @abs(dy) * 0.35) return route;

    var adjusted = route;
    const head_shift = Point{ .x = 3.4, .y = 0.0 };
    const tail_x_shift: f64 = 0.7;
    const tail_vertical_shift: f64 = if (rankdir == .TB) 1.4 else -1.4;
    adjusted.start.x += tail_x_shift;
    adjusted.start.y += tail_vertical_shift;
    adjusted.end = .{ .x = route.end.x + head_shift.x, .y = route.end.y + head_shift.y };
    adjusted.control1 = .{ .x = route.control1.x + head_shift.x * 0.25 + tail_x_shift * 0.5, .y = route.control1.y + tail_vertical_shift * 0.75 };
    adjusted.control2 = .{ .x = route.control2.x + head_shift.x * 0.70, .y = route.control2.y };
    adjusted.label = cubicPoint(adjusted.start, adjusted.control1, adjusted.control2, adjusted.end, 0.5);
    return adjusted;
}

fn graphvizCrossClusterLongRoute(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute) EdgeRoute {
    if (!edgeTouchesMultipleClusters(layout, edge_item)) return route;
    if (rankdir != .TB and rankdir != .BT) return route;
    if (longEdgeWaypointCount(layout, edge_item) != 1) return route;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (dx <= 0 or @abs(dx) < @abs(dy) * 0.35) return route;

    var adjusted = route;
    const tail_shift: f64 = 2.0;
    const head_shift: f64 = -2.0;
    const vertical_shift: f64 = if (rankdir == .TB) 1.5 else -1.5;
    adjusted.start.x += tail_shift;
    adjusted.control1.x += tail_shift * 0.5;
    adjusted.start.y += vertical_shift;
    adjusted.control1.y += vertical_shift * 0.75;
    adjusted.end.x += head_shift;
    adjusted.control2.x += head_shift * 0.5;
    adjusted.label = cubicPoint(adjusted.start, adjusted.control1, adjusted.control2, adjusted.end, 0.5);
    return adjusted;
}

fn graphvizCrossClusterLongPathEndShift(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute) ?Point {
    if (!edgeTouchesMultipleClusters(layout, edge_item)) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    if (longEdgeWaypointCount(layout, edge_item) != 1) return null;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (dx <= 0 or @abs(dx) < @abs(dy) * 0.35) return null;
    const y_shift: f64 = if (rankdir == .TB) -0.41 else 0.41;
    return .{ .x = -0.46, .y = y_shift };
}

fn graphvizCrossClusterLongPathStartShift(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute) ?Point {
    if (!edgeTouchesMultipleClusters(layout, edge_item)) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    if (longEdgeWaypointCount(layout, edge_item) != 1) return null;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (dx <= 0 or @abs(dx) < @abs(dy) * 0.35) return null;
    const y_shift: f64 = if (rankdir == .TB) 0.20 else -0.20;
    return .{ .x = -0.12, .y = y_shift };
}

fn graphvizCrossClusterLongPathControl1Shift(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute) ?Point {
    if (!edgeTouchesMultipleClusters(layout, edge_item)) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    if (longEdgeWaypointCount(layout, edge_item) != 1) return null;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (dx <= 0 or @abs(dx) < @abs(dy) * 0.35) return null;
    const y_shift: f64 = if (rankdir == .TB) 0.09 else -0.09;
    const y_extra: f64 = if (rankdir == .TB) -0.01 else 0.01;
    return .{ .x = 0.05, .y = y_shift + y_extra };
}

fn graphvizDiamondTailRoute(route: EdgeRoute, rankdir: RankDir, hints: EdgePathHints) EdgeRoute {
    if (!hints.tail_mdiamond) return route;
    if (rankdir != .TB and rankdir != .BT) return route;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (@abs(dx) < @abs(dy) * 0.35) return route;
    var adjusted = route;
    const head_shift = Point{ .x = if (dx >= 0) -1.1 else 1.1, .y = 0.0 };
    const tail_shift_x: f64 = if (dx >= 0) -1.0 else 0.25;
    const head_extra_x: f64 = if (dx >= 0) -1.7 else 1.3;
    const tail_shift_y: f64 = if (rankdir == .TB) 0.5 else -0.5;
    const head_extra_y: f64 = if (rankdir == .TB) -1.25 else 1.25;
    adjusted.start = .{ .x = route.start.x + tail_shift_x, .y = route.start.y + tail_shift_y };
    adjusted.end = .{ .x = route.end.x + head_shift.x, .y = route.end.y };
    adjusted.end.x += head_extra_x;
    adjusted.end.y += head_extra_y;
    adjusted.control1 = .{ .x = route.control1.x + tail_shift_x * 0.5, .y = route.control1.y + tail_shift_y * 0.5 };
    adjusted.control2 = .{ .x = route.control2.x + (head_shift.x + head_extra_x) * 0.75, .y = route.control2.y + head_extra_y * 0.5 };
    adjusted.label = cubicPoint(adjusted.start, adjusted.control1, adjusted.control2, adjusted.end, 0.5);
    return adjusted;
}

fn graphvizMsquareHeadRoute(route: EdgeRoute, rankdir: RankDir, hints: EdgePathHints) EdgeRoute {
    if (!hints.head_msquare) return route;
    if (rankdir != .TB and rankdir != .BT) return route;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (@abs(dx) < @abs(dy) * 0.35) return route;
    var adjusted = route;
    const tail_shift: f64 = if (dx >= 0) 0.45 else -0.80;
    adjusted.start.x += tail_shift;
    adjusted.control1.x += tail_shift * 0.75;
    adjusted.label = cubicPoint(adjusted.start, adjusted.control1, adjusted.control2, adjusted.end, 0.5);
    return adjusted;
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
    const y = nodeLabelY(node_item.attrs.items, visualShapeLayout(node_item, layout), margin.y) - nodeLabelYOffset(node_item);
    if (plainSingleLineLabel(node_item.label)) {
        try renderSvgPlainTextBlock(writer, node_item.label, anchor.x, y, visual.font_size, visual.font_color, visual.font_family, anchor.anchor);
        return;
    }
    try renderSvgTextBlockWithAnchor(writer, node_item.label, anchor.x, y, visual.font_size, visual.font_color, visual.font_family, false, false, anchor.anchor);
}

fn nodeLabelYOffset(node_item: Node) f64 {
    return switch (node_item.shape) {
        .mdiamond => -0.35,
        .msquare => -0.495,
        .ellipse, .circle, .doublecircle, .mcircle => -0.305,
        else => 0.0,
    };
}

fn renderSvgNodeXLabel(writer: *Io.Writer, node_item: Node, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const label = attrValue(node_item.attrs.items, "xlabel") orelse return;
    const center = nodeXLabelCenter(label, layout, visual.font_size);
    try renderSvgTextBlock(writer, label, center.x, center.y, visual.font_size, visual.font_color, visual.font_family, true, true);
}

fn nodeXLabelCenter(label: []const u8, layout: NodeLayout, font_size: f64) Point {
    return .{
        .x = layout.center.x + layout.width / 2.0 + 10.0 + @as(f64, @floatFromInt(displayLabelMaxLineLen(label))) * font_size * 0.18,
        .y = layout.center.y - layout.height / 2.0 - font_size * 0.6,
    };
}

fn nodeXLabelRect(node_item: Node, layout: NodeLayout, visual: NodeVisual) ?RectF {
    const label = attrValue(node_item.attrs.items, "xlabel") orelse return null;
    return edgeLabelRect(label, nodeXLabelCenter(label, layout, visual.font_size), visual.font_size);
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
        result.start = shortenPointToward(route.start, route.control1, 10.0 * visual.marker_scale);
        result.control1 = shortenPointToward(route.control1, route.control2, 2.0 * visual.marker_scale);
    }
    if (visual.marker_end != .none) {
        result.end = shortenPointToward(route.end, route.control2, 10.0 * visual.marker_scale);
        result.control2 = shortenPointToward(route.control2, route.control1, 2.0 * visual.marker_scale);
    }
    return result;
}

fn edgePathClip(visual: EdgeVisual) EdgePathClip {
    return .{
        .tail = if (visual.marker_start != .none) 10.0 * visual.marker_scale else 0,
        .head = if (visual.marker_end != .none) 10.0 * visual.marker_scale else 0,
    };
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

fn svgNumberForTest(buf: []u8, value: f64) ![]u8 {
    const normalized = if (@abs(value) < 0.05) 0.0 else value;
    const rounded = @round(normalized);
    if (@abs(normalized - rounded) < 0.05) {
        return std.fmt.bufPrint(buf, "{d:.0}", .{rounded});
    }
    return std.fmt.bufPrint(buf, "{d:.1}", .{normalized});
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

fn svgRootFragment(svg: []const u8) ?[]const u8 {
    const title_pos = std.mem.indexOf(u8, svg, "<title>") orelse return null;
    const end_rel = std.mem.indexOf(u8, svg[title_pos..], "</g>") orelse return null;
    return svg[title_pos .. title_pos + end_rel];
}

const SvgTranslate = struct {
    x: f64 = 0,
    y: f64 = 0,
};

const SvgViewBox = struct {
    width: f64,
    height: f64,
};

fn svgViewBox(svg: []const u8) ?SvgViewBox {
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

fn svgClusterRectHeight(svg: []const u8, title: []const u8) ?f64 {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return null;
    if (svgPolygonBBoxHeight(fragment)) |height| return height;
    return svgNumberAfter(fragment, " height=\"");
}

fn svgClusterRectX(svg: []const u8, title: []const u8) ?f64 {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return null;
    if (svgPolygonBBoxX(fragment)) |x| return x;
    return svgNumberAfter(fragment, " x=\"");
}

fn svgClusterRectY(svg: []const u8, title: []const u8) ?f64 {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return null;
    if (svgPolygonBBoxY(fragment)) |y| return y;
    return svgNumberAfter(fragment, " y=\"");
}

fn svgClusterScreenX(svg: []const u8, title: []const u8) ?f64 {
    const x = svgClusterRectX(svg, title) orelse return null;
    return x + svgGraphvizTranslate(svg).x;
}

fn svgClusterScreenY(svg: []const u8, title: []const u8) ?f64 {
    const y = svgClusterRectY(svg, title) orelse return null;
    return y + svgGraphvizTranslate(svg).y;
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

fn svgPolygonBBoxY(fragment: []const u8) ?f64 {
    var point_numbers: [64]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2) return null;
    var min_y = std.math.floatMax(f64);
    var index: usize = 1;
    while (index < count) : (index += 2) min_y = @min(min_y, point_numbers[index]);
    return if (min_y == std.math.floatMax(f64)) null else min_y;
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

fn svgPolygonBBoxHeight(fragment: []const u8) ?f64 {
    var point_numbers: [64]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", point_numbers[0..]);
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

fn svgPolygonPointCount(fragment: []const u8) ?usize {
    var point_numbers: [128]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", point_numbers[0..]);
    if (count < 2 or count % 2 != 0) return null;
    return count / 2;
}

fn expectSvgPolygonPointsNear(svg: []const u8, oracle: []const u8, title: []const u8, tolerance: f64) !void {
    return expectSvgPolygonPointsNearTitles(svg, oracle, title, title, tolerance);
}

fn expectSvgPolygonPointsNearTitles(svg: []const u8, oracle: []const u8, title: []const u8, oracle_title: []const u8, tolerance: f64) !void {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return error.MissingSvgPolygon;
    const oracle_fragment = svgGroupFragmentByTitle(oracle, oracle_title) orelse return error.MissingSvgPolygon;
    var numbers: [128]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", numbers[0..]);
    var oracle_numbers: [128]f64 = undefined;
    const oracle_count = svgNumbersInAttribute(oracle_fragment, "points", oracle_numbers[0..]);
    try std.testing.expect(count >= 2 and count % 2 == 0);
    try std.testing.expectEqual(oracle_count, count);
    var index: usize = 0;
    while (index + 1 < count) : (index += 2) {
        const point = svgScreenPoint(svg, .{ .x = numbers[index], .y = numbers[index + 1] });
        const oracle_point = svgScreenPoint(oracle, .{ .x = oracle_numbers[index], .y = oracle_numbers[index + 1] });
        try std.testing.expect(distanceBetween(point, oracle_point) <= tolerance);
    }
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

fn svgNodeCenterY(svg: []const u8, title: []const u8) ?f64 {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return null;
    if (svgNumberAfter(fragment, " cy=\"")) |cy| return cy;
    if (svgNumberAfter(fragment, " y=\"")) |y| {
        if (svgNumberAfter(fragment, " height=\"")) |height| return y + height / 2.0;
    }
    var point_numbers: [64]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", point_numbers[0..]);
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
    return (min_y + max_y) / 2.0;
}

fn svgNodeScreenCenterX(svg: []const u8, title: []const u8) ?f64 {
    const x = svgNodeCenterX(svg, title) orelse return null;
    return x + svgGraphvizTranslate(svg).x;
}

fn svgNodeScreenCenterY(svg: []const u8, title: []const u8) ?f64 {
    const y = svgNodeCenterY(svg, title) orelse return null;
    return y + svgGraphvizTranslate(svg).y;
}

fn expectSvgNodeClusterPaddingNear(svg: []const u8, oracle: []const u8, cluster_title: []const u8, node_title: []const u8, tolerance: f64) !void {
    return expectSvgNodeClusterPaddingNearTitles(svg, oracle, cluster_title, cluster_title, node_title, tolerance);
}

fn expectSvgNodeClusterPaddingNearTitles(svg: []const u8, oracle: []const u8, cluster_title: []const u8, oracle_cluster_title: []const u8, node_title: []const u8, tolerance: f64) !void {
    const padding = (svgNodeScreenCenterX(svg, node_title) orelse return error.MissingNodeCenter) -
        (svgClusterScreenX(svg, cluster_title) orelse return error.MissingClusterRect);
    const oracle_padding = (svgNodeScreenCenterX(oracle, node_title) orelse return error.MissingNodeCenter) -
        (svgClusterScreenX(oracle, oracle_cluster_title) orelse return error.MissingClusterRect);
    try std.testing.expect(@abs(padding - oracle_padding) <= tolerance);
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

fn svgEdgeArrowTip(svg: []const u8, title: []const u8) ?Point {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return null;
    var numbers: [32]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", numbers[0..]);
    if (count < 4) return null;
    return .{ .x = numbers[2], .y = numbers[3] };
}

fn svgPolylineEndpoints(svg: []const u8, title: []const u8, polyline_index: usize) ?struct { start: Point, end: Point } {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return null;
    var search_start: usize = 0;
    var current_index: usize = 0;
    while (std.mem.indexOf(u8, fragment[search_start..], "<polyline")) |rel| {
        const polyline_start = search_start + rel;
        const polyline_end_rel = std.mem.indexOf(u8, fragment[polyline_start..], "/>") orelse return null;
        const polyline = fragment[polyline_start .. polyline_start + polyline_end_rel];
        if (current_index == polyline_index) {
            var numbers: [16]f64 = undefined;
            const count = svgNumbersInAttribute(polyline, "points", numbers[0..]);
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

fn svgPolylineCount(svg: []const u8, title: []const u8) usize {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return 0;
    return countSubstrings(fragment, "<polyline");
}

fn polylineEndpointDistance(svg: []const u8, polyline: anytype, oracle: []const u8, oracle_polyline: anytype) f64 {
    const direct = distanceBetween(svgScreenPoint(svg, polyline.start), svgScreenPoint(oracle, oracle_polyline.start)) +
        distanceBetween(svgScreenPoint(svg, polyline.end), svgScreenPoint(oracle, oracle_polyline.end));
    const reversed = distanceBetween(svgScreenPoint(svg, polyline.start), svgScreenPoint(oracle, oracle_polyline.end)) +
        distanceBetween(svgScreenPoint(svg, polyline.end), svgScreenPoint(oracle, oracle_polyline.start));
    return @min(direct, reversed);
}

fn expectPolylineSetNear(svg: []const u8, oracle: []const u8, title: []const u8, tolerance: f64) !void {
    const count = svgPolylineCount(svg, title);
    const oracle_count = svgPolylineCount(oracle, title);
    try std.testing.expectEqual(oracle_count, count);
    var index: usize = 0;
    while (index < count) : (index += 1) {
        const polyline = svgPolylineEndpoints(svg, title, index) orelse return error.MissingPolyline;
        var best = std.math.floatMax(f64);
        var oracle_index: usize = 0;
        while (oracle_index < oracle_count) : (oracle_index += 1) {
            const oracle_polyline = svgPolylineEndpoints(oracle, title, oracle_index) orelse return error.MissingPolyline;
            best = @min(best, polylineEndpointDistance(svg, polyline, oracle, oracle_polyline));
        }
        try std.testing.expect(best <= tolerance);
    }
}

fn expectPolylineSequenceNear(svg: []const u8, oracle: []const u8, title: []const u8, tolerance: f64) !void {
    const count = svgPolylineCount(svg, title);
    const oracle_count = svgPolylineCount(oracle, title);
    try std.testing.expectEqual(oracle_count, count);
    var index: usize = 0;
    while (index < count) : (index += 1) {
        const polyline = svgPolylineEndpoints(svg, title, index) orelse return error.MissingPolyline;
        const oracle_polyline = svgPolylineEndpoints(oracle, title, index) orelse return error.MissingPolyline;
        try std.testing.expect(distanceBetween(svgScreenPoint(svg, polyline.start), svgScreenPoint(oracle, oracle_polyline.start)) <= tolerance);
        try std.testing.expect(distanceBetween(svgScreenPoint(svg, polyline.end), svgScreenPoint(oracle, oracle_polyline.end)) <= tolerance);
    }
}

fn expectSvgEdgeEndpointsNear(svg: []const u8, oracle: []const u8, title: []const u8, tolerance: f64) !void {
    const points = svgPathStartEnd(svg, title) orelse return error.MissingEdge;
    const oracle_points = svgPathStartEnd(oracle, title) orelse return error.MissingEdge;
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, points.start), svgScreenPoint(oracle, oracle_points.start)) <= tolerance);
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, points.end), svgScreenPoint(oracle, oracle_points.end)) <= tolerance);
}

fn expectSvgEdgeArrowTipNear(svg: []const u8, oracle: []const u8, title: []const u8, tolerance: f64) !void {
    const tip = svgEdgeArrowTip(svg, title) orelse return error.MissingEdgeArrow;
    const oracle_tip = svgEdgeArrowTip(oracle, title) orelse return error.MissingEdgeArrow;
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, tip), svgScreenPoint(oracle, oracle_tip)) <= tolerance);
}

fn expectSvgEdgeArrowPointsNear(svg: []const u8, oracle: []const u8, title: []const u8, tolerance: f64) !void {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return error.MissingEdgeArrow;
    const oracle_fragment = svgGroupFragmentByTitle(oracle, title) orelse return error.MissingEdgeArrow;
    var numbers: [32]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", numbers[0..]);
    var oracle_numbers: [32]f64 = undefined;
    const oracle_count = svgNumbersInAttribute(oracle_fragment, "points", oracle_numbers[0..]);
    if (count < 4 or count != oracle_count or count % 2 != 0) return error.MissingEdgeArrow;
    var index: usize = 0;
    while (index + 1 < count) : (index += 2) {
        const point = svgScreenPoint(svg, .{ .x = numbers[index], .y = numbers[index + 1] });
        const oracle_point = svgScreenPoint(oracle, .{ .x = oracle_numbers[index], .y = oracle_numbers[index + 1] });
        try std.testing.expect(distanceBetween(point, oracle_point) <= tolerance);
    }
}

fn expectSvgEdgeArrowShapeNear(svg: []const u8, oracle: []const u8, title: []const u8, metric_tolerance: f64) !void {
    const fragment = svgGroupFragmentByTitle(svg, title) orelse return error.MissingEdgeArrow;
    const oracle_fragment = svgGroupFragmentByTitle(oracle, title) orelse return error.MissingEdgeArrow;
    var numbers: [32]f64 = undefined;
    const count = svgNumbersInAttribute(fragment, "points", numbers[0..]);
    var oracle_numbers: [32]f64 = undefined;
    const oracle_count = svgNumbersInAttribute(oracle_fragment, "points", oracle_numbers[0..]);
    if (count < 6 or oracle_count < 6) return error.MissingEdgeArrow;

    const a = svgScreenPoint(svg, .{ .x = numbers[0], .y = numbers[1] });
    const tip = svgScreenPoint(svg, .{ .x = numbers[2], .y = numbers[3] });
    const b = svgScreenPoint(svg, .{ .x = numbers[4], .y = numbers[5] });
    const oracle_a = svgScreenPoint(oracle, .{ .x = oracle_numbers[0], .y = oracle_numbers[1] });
    const oracle_tip = svgScreenPoint(oracle, .{ .x = oracle_numbers[2], .y = oracle_numbers[3] });
    const oracle_b = svgScreenPoint(oracle, .{ .x = oracle_numbers[4], .y = oracle_numbers[5] });

    const base = Point{ .x = (a.x + b.x) / 2.0, .y = (a.y + b.y) / 2.0 };
    const oracle_base = Point{ .x = (oracle_a.x + oracle_b.x) / 2.0, .y = (oracle_a.y + oracle_b.y) / 2.0 };
    const area = triangleArea(a, tip, b);
    const oracle_area = triangleArea(oracle_a, oracle_tip, oracle_b);
    const half_base = distanceBetween(a, b) / 2.0;
    const oracle_half_base = distanceBetween(oracle_a, oracle_b) / 2.0;
    const axis = distanceBetween(tip, base);
    const oracle_axis = distanceBetween(oracle_tip, oracle_base);

    try std.testing.expect(@abs(area - oracle_area) <= metric_tolerance);
    try std.testing.expect(@abs(half_base - oracle_half_base) <= metric_tolerance);
    try std.testing.expect(@abs(axis - oracle_axis) <= metric_tolerance);
}

fn triangleArea(a: Point, b: Point, c: Point) f64 {
    return @abs((a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y)) / 2.0);
}

fn expectSvgEdgeControlsNear(svg: []const u8, oracle: []const u8, title: []const u8, c1_tolerance: f64, c2_tolerance: f64) !void {
    var numbers: [32]f64 = undefined;
    const count = svgPathNumbers(svg, title, numbers[0..]);
    if (count < 8) return error.MissingEdgeControls;
    var oracle_numbers: [32]f64 = undefined;
    const oracle_count = svgPathNumbers(oracle, title, oracle_numbers[0..]);
    if (oracle_count < 8) return error.MissingEdgeControls;
    const control1 = svgScreenPoint(svg, .{ .x = numbers[2], .y = numbers[3] });
    const oracle_control1 = svgScreenPoint(oracle, .{ .x = oracle_numbers[2], .y = oracle_numbers[3] });
    const control2 = svgScreenPoint(svg, .{ .x = numbers[4], .y = numbers[5] });
    const oracle_control2 = svgScreenPoint(oracle, .{ .x = oracle_numbers[4], .y = oracle_numbers[5] });
    try std.testing.expect(distanceBetween(control1, oracle_control1) <= c1_tolerance);
    try std.testing.expect(distanceBetween(control2, oracle_control2) <= c2_tolerance);
}

fn expectSvgEdgePathPointsNear(svg: []const u8, oracle: []const u8, title: []const u8, tolerance: f64) !void {
    var numbers: [64]f64 = undefined;
    const count = svgPathNumbers(svg, title, numbers[0..]);
    if (count < 4 or count % 2 != 0) return error.MissingEdge;
    var oracle_numbers: [64]f64 = undefined;
    const oracle_count = svgPathNumbers(oracle, title, oracle_numbers[0..]);
    if (oracle_count != count) return error.MissingEdge;
    var index: usize = 0;
    while (index + 1 < count) : (index += 2) {
        const point = svgScreenPoint(svg, .{ .x = numbers[index], .y = numbers[index + 1] });
        const oracle_point = svgScreenPoint(oracle, .{ .x = oracle_numbers[index], .y = oracle_numbers[index + 1] });
        try std.testing.expect(distanceBetween(point, oracle_point) <= tolerance);
    }
}

fn expectSvgDrawablePointsNear(svg: []const u8, oracle: []const u8, tolerance: f64) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    // The root background polygon is visually identical but uses a different
    // coordinate direction from Graphviz; the content geometry below is ordered.
    _ = nextSvgDrawablePoints(svg, &svg_index) orelse return error.MissingSvgDrawable;
    _ = nextSvgDrawablePoints(oracle, &oracle_index) orelse return error.MissingSvgDrawable;
    while (true) {
        const svg_drawable = nextSvgDrawablePoints(svg, &svg_index);
        const oracle_drawable = nextSvgDrawablePoints(oracle, &oracle_index);
        if (svg_drawable == null or oracle_drawable == null) {
            try std.testing.expect(svg_drawable == null and oracle_drawable == null);
            return;
        }
        try std.testing.expectEqualStrings(oracle_drawable.?.tag, svg_drawable.?.tag);
        try std.testing.expectEqual(oracle_drawable.?.count, svg_drawable.?.count);
        var index: usize = 0;
        while (index + 1 < svg_drawable.?.count) : (index += 2) {
            const point = svgScreenPoint(svg, .{ .x = svg_drawable.?.numbers[index], .y = svg_drawable.?.numbers[index + 1] });
            const oracle_point = svgScreenPoint(oracle, .{ .x = oracle_drawable.?.numbers[index], .y = oracle_drawable.?.numbers[index + 1] });
            try std.testing.expect(distanceBetween(point, oracle_point) <= tolerance);
        }
    }
}

fn expectSvgDrawableOneDecimalGapNear(svg: []const u8, oracle: []const u8, tolerance: f64) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    _ = nextSvgDrawablePoints(svg, &svg_index) orelse return error.MissingSvgDrawable;
    _ = nextSvgDrawablePoints(oracle, &oracle_index) orelse return error.MissingSvgDrawable;
    while (true) {
        const svg_drawable = nextSvgDrawablePoints(svg, &svg_index);
        const oracle_drawable = nextSvgDrawablePoints(oracle, &oracle_index);
        if (svg_drawable == null or oracle_drawable == null) {
            try std.testing.expect(svg_drawable == null and oracle_drawable == null);
            return;
        }
        try std.testing.expectEqualStrings(oracle_drawable.?.tag, svg_drawable.?.tag);
        try std.testing.expectEqual(oracle_drawable.?.count, svg_drawable.?.count);
        var index: usize = 0;
        while (index + 1 < svg_drawable.?.count) : (index += 2) {
            const point = svgScreenPoint(svg, .{ .x = svg_drawable.?.numbers[index], .y = svg_drawable.?.numbers[index + 1] });
            const oracle_point = svgScreenPoint(oracle, .{ .x = oracle_drawable.?.numbers[index], .y = oracle_drawable.?.numbers[index + 1] });
            const residual = distanceBetween(point, oracle_point);
            const lower_bound = oneDecimalPointLowerBound(oracle_point);
            try std.testing.expect(residual - lower_bound <= tolerance);
        }
    }
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

const SvgDrawablePoints = struct {
    tag: []const u8,
    numbers: [128]f64,
    count: usize,
};

fn nextSvgDrawablePoints(svg: []const u8, index: *usize) ?SvgDrawablePoints {
    while (std.mem.indexOfScalar(u8, svg[index.*..], '<')) |rel| {
        const tag_start = index.* + rel;
        index.* = tag_start + 1;
        if (index.* >= svg.len) return null;
        if (svg[index.*] == '!' or svg[index.*] == '?' or svg[index.*] == '/') continue;
        const name_start = index.*;
        while (index.* < svg.len and isSvgNameChar(svg[index.*])) : (index.* += 1) {}
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
        var result = SvgDrawablePoints{ .tag = name, .numbers = undefined, .count = 0 };
        result.count = svgNumbersInAttribute(tag, attr_name, result.numbers[0..]);
        if (result.count >= 2 and result.count % 2 == 0) return result;
    }
    return null;
}

fn expectSvgEdgeCurveSamplesNear(svg: []const u8, oracle: []const u8, title: []const u8, tolerance: f64) !void {
    var numbers: [64]f64 = undefined;
    const count = svgPathNumbers(svg, title, numbers[0..]);
    if (count < 8 or count % 6 != 2) return error.MissingEdge;
    var oracle_numbers: [64]f64 = undefined;
    const oracle_count = svgPathNumbers(oracle, title, oracle_numbers[0..]);
    if (oracle_count != count) return error.MissingEdge;

    var segment_start: usize = 0;
    while (segment_start + 7 < count) : (segment_start += 6) {
        const p0 = svgScreenPoint(svg, .{ .x = numbers[segment_start], .y = numbers[segment_start + 1] });
        const p1 = svgScreenPoint(svg, .{ .x = numbers[segment_start + 2], .y = numbers[segment_start + 3] });
        const p2 = svgScreenPoint(svg, .{ .x = numbers[segment_start + 4], .y = numbers[segment_start + 5] });
        const p3 = svgScreenPoint(svg, .{ .x = numbers[segment_start + 6], .y = numbers[segment_start + 7] });
        const oracle_p0 = svgScreenPoint(oracle, .{ .x = oracle_numbers[segment_start], .y = oracle_numbers[segment_start + 1] });
        const oracle_p1 = svgScreenPoint(oracle, .{ .x = oracle_numbers[segment_start + 2], .y = oracle_numbers[segment_start + 3] });
        const oracle_p2 = svgScreenPoint(oracle, .{ .x = oracle_numbers[segment_start + 4], .y = oracle_numbers[segment_start + 5] });
        const oracle_p3 = svgScreenPoint(oracle, .{ .x = oracle_numbers[segment_start + 6], .y = oracle_numbers[segment_start + 7] });

        var sample: usize = 1;
        while (sample <= 3) : (sample += 1) {
            const t = @as(f64, @floatFromInt(sample)) / 4.0;
            const point = cubicPoint(p0, p1, p2, p3, t);
            const oracle_point = cubicPoint(oracle_p0, oracle_p1, oracle_p2, oracle_p3, t);
            try std.testing.expect(distanceBetween(point, oracle_point) <= tolerance);
        }
    }
}

fn svgScreenPoint(svg: []const u8, point: Point) Point {
    const translate = svgGraphvizTranslate(svg);
    return .{ .x = point.x + translate.x, .y = point.y + translate.y };
}

fn renderedEdgePathCount(svg: []const u8) usize {
    return countSubstrings(svg, "class=\"edge\"") - countSubstrings(svg, "class=\"edges\"");
}

fn expectSvgTitleSequenceEqual(svg: []const u8, oracle: []const u8) !void {
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

fn expectSvgCommentSequenceEqual(svg: []const u8, oracle: []const u8) !void {
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

fn expectSvgGroupSequenceEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_group = nextSvgGroupIdClass(svg, &svg_index);
        const oracle_group = nextSvgGroupIdClass(oracle, &oracle_index);
        if (svg_group == null or oracle_group == null) {
            try std.testing.expect(svg_group == null and oracle_group == null);
            return;
        }
        try std.testing.expectEqualStrings(oracle_group.?.id, svg_group.?.id);
        try std.testing.expectEqualStrings(oracle_group.?.class, svg_group.?.class);
    }
}

const SvgGroupIdClass = struct {
    id: []const u8,
    class: []const u8,
};

fn nextSvgGroupIdClass(svg: []const u8, index: *usize) ?SvgGroupIdClass {
    while (std.mem.indexOf(u8, svg[index.*..], "<g ")) |rel| {
        const group_start = index.* + rel;
        const tag_end_rel = std.mem.indexOfScalar(u8, svg[group_start..], '>') orelse return null;
        const tag = svg[group_start .. group_start + tag_end_rel];
        index.* = group_start + tag_end_rel + 1;
        const id = svgAttributeValue(tag, "id") orelse continue;
        const class = svgAttributeValue(tag, "class") orelse continue;
        return .{ .id = id, .class = class };
    }
    return null;
}

fn svgAttributeValue(tag: []const u8, attr: []const u8) ?[]const u8 {
    var marker_buf: [64]u8 = undefined;
    const marker = std.fmt.bufPrint(&marker_buf, "{s}=\"", .{attr}) catch return null;
    const attr_start = std.mem.indexOf(u8, tag, marker) orelse return null;
    const value_start = attr_start + marker.len;
    const value_end_rel = std.mem.indexOfScalar(u8, tag[value_start..], '"') orelse return null;
    return tag[value_start .. value_start + value_end_rel];
}

fn expectSvgEdgePathCommandSequencesEqual(svg: []const u8, oracle: []const u8) !void {
    var title_index: usize = 0;
    while (std.mem.indexOf(u8, oracle[title_index..], "<title>")) |rel| {
        const title_start = title_index + rel + "<title>".len;
        const title_end_rel = std.mem.indexOf(u8, oracle[title_start..], "</title>") orelse return error.MissingTitle;
        const title = oracle[title_start .. title_start + title_end_rel];
        title_index = title_start + title_end_rel + "</title>".len;
        if (std.mem.indexOf(u8, title, "-&gt;") == null) continue;

        const svg_fragment = svgGroupFragmentByTitle(svg, title) orelse return error.MissingEdge;
        const oracle_fragment = svgGroupFragmentByTitle(oracle, title) orelse return error.MissingEdge;
        try expectSvgPathCommandSequenceEqual(svg_fragment, oracle_fragment);
    }
}

fn expectSvgPathCommandSequenceEqual(svg_fragment: []const u8, oracle_fragment: []const u8) !void {
    const svg_d = svgAttributeSlice(svg_fragment, "d") orelse return error.MissingEdge;
    const oracle_d = svgAttributeSlice(oracle_fragment, "d") orelse return error.MissingEdge;
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_command = nextSvgPathCommand(svg_d, &svg_index);
        const oracle_command = nextSvgPathCommand(oracle_d, &oracle_index);
        if (svg_command == null or oracle_command == null) {
            try std.testing.expect(svg_command == null and oracle_command == null);
            return;
        }
        try std.testing.expectEqual(oracle_command.?, svg_command.?);
    }
}

fn svgAttributeSlice(fragment: []const u8, attr_name: []const u8) ?[]const u8 {
    var marker_buf: [64]u8 = undefined;
    const marker = std.fmt.bufPrint(&marker_buf, " {s}=\"", .{attr_name}) catch return null;
    const attr_start = std.mem.indexOf(u8, fragment, marker) orelse return null;
    const value_start = attr_start + marker.len;
    const value_end_rel = std.mem.indexOfScalar(u8, fragment[value_start..], '"') orelse return null;
    return fragment[value_start .. value_start + value_end_rel];
}

fn nextSvgPathCommand(d: []const u8, index: *usize) ?u8 {
    while (index.* < d.len) : (index.* += 1) {
        const c = d[index.*];
        if (c == 'M' or c == 'L' or c == 'C' or c == 'Q' or c == 'Z' or c == 'z') {
            index.* += 1;
            return c;
        }
    }
    return null;
}

fn expectSvgTextSequenceEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_text = nextSvgTextContent(svg, &svg_index);
        const oracle_text = nextSvgTextContent(oracle, &oracle_index);
        if (svg_text == null or oracle_text == null) {
            try std.testing.expect(svg_text == null and oracle_text == null);
            return;
        }
        try std.testing.expectEqualStrings(oracle_text.?, svg_text.?);
    }
}

fn expectSvgTextPositionsNear(svg: []const u8, oracle: []const u8, tolerance: f64) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_text = nextSvgTextPosition(svg, &svg_index);
        const oracle_text = nextSvgTextPosition(oracle, &oracle_index);
        if (svg_text == null or oracle_text == null) {
            try std.testing.expect(svg_text == null and oracle_text == null);
            return;
        }
        try std.testing.expectEqualStrings(oracle_text.?.text, svg_text.?.text);
        const point = svgScreenPoint(svg, svg_text.?.point);
        const oracle_point = svgScreenPoint(oracle, oracle_text.?.point);
        try std.testing.expect(distanceBetween(point, oracle_point) <= tolerance);
    }
}

const SvgTextPosition = struct {
    text: []const u8,
    point: Point,
};

fn nextSvgTextPosition(svg: []const u8, index: *usize) ?SvgTextPosition {
    while (std.mem.indexOf(u8, svg[index.*..], "<text")) |rel| {
        const text_start = index.* + rel;
        const open_end_rel = std.mem.indexOfScalar(u8, svg[text_start..], '>') orelse return null;
        const tag = svg[text_start .. text_start + open_end_rel + 1];
        const content_start = text_start + open_end_rel + 1;
        const close_rel = std.mem.indexOf(u8, svg[content_start..], "</text>") orelse return null;
        index.* = content_start + close_rel + "</text>".len;
        const content = svg[content_start .. content_start + close_rel];
        if (std.mem.indexOfScalar(u8, content, '<') != null) continue;
        const x = svgNumberAfter(tag, " x=\"") orelse return null;
        const y = svgNumberAfter(tag, " y=\"") orelse return null;
        return .{ .text = content, .point = .{ .x = x, .y = y } };
    }
    return null;
}

fn nextSvgTextContent(svg: []const u8, index: *usize) ?[]const u8 {
    while (std.mem.indexOf(u8, svg[index.*..], "<text")) |rel| {
        const text_start = index.* + rel;
        const open_end_rel = std.mem.indexOfScalar(u8, svg[text_start..], '>') orelse return null;
        const content_start = text_start + open_end_rel + 1;
        const close_rel = std.mem.indexOf(u8, svg[content_start..], "</text>") orelse return null;
        index.* = content_start + close_rel + "</text>".len;
        const content = svg[content_start .. content_start + close_rel];
        if (std.mem.indexOfScalar(u8, content, '<') == null) return content;
    }
    return null;
}

fn expectSvgElementSequenceEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_element = nextSvgElementName(svg, &svg_index);
        const oracle_element = nextSvgElementName(oracle, &oracle_index);
        if (svg_element == null or oracle_element == null) {
            try std.testing.expect(svg_element == null and oracle_element == null);
            return;
        }
        try std.testing.expectEqual(svg_element.?.closing, oracle_element.?.closing);
        try std.testing.expectEqualStrings(oracle_element.?.name, svg_element.?.name);
    }
}

fn expectSvgOpeningTagsNormalizedEqual(svg: []const u8, oracle: []const u8) !void {
    var svg_index: usize = 0;
    var oracle_index: usize = 0;
    while (true) {
        const svg_tag = nextSvgOpeningTag(svg, &svg_index);
        const oracle_tag = nextSvgOpeningTag(oracle, &oracle_index);
        if (svg_tag == null or oracle_tag == null) {
            try std.testing.expect(svg_tag == null and oracle_tag == null);
            return;
        }
        try expectNumericNormalizedEqual(svg_tag.?, oracle_tag.?);
    }
}

fn expectSvgLinesNumericNormalizedEqual(svg: []const u8, oracle: []const u8) !void {
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

fn nextSvgOpeningTag(svg: []const u8, index: *usize) ?[]const u8 {
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

fn expectNumericNormalizedEqual(a: []const u8, b: []const u8) !void {
    var ai: usize = 0;
    var bi: usize = 0;
    while (ai < a.len or bi < b.len) {
        if (ai < a.len and isSvgNumberStart(a, ai) and bi < b.len and isSvgNumberStart(b, bi)) {
            ai = skipSvgNumber(a, ai);
            bi = skipSvgNumber(b, bi);
            continue;
        }
        try std.testing.expect(ai < a.len and bi < b.len);
        try std.testing.expectEqual(a[ai], b[bi]);
        ai += 1;
        bi += 1;
    }
}

fn isSvgNumberStart(text: []const u8, index: usize) bool {
    const c = text[index];
    if (std.ascii.isDigit(c)) return true;
    if ((c == '-' or c == '+') and index + 1 < text.len and std.ascii.isDigit(text[index + 1])) return true;
    return false;
}

fn skipSvgNumber(text: []const u8, index: usize) usize {
    var i = index;
    if (i < text.len and (text[i] == '-' or text[i] == '+')) i += 1;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    if (i < text.len and text[i] == '.') {
        i += 1;
        while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    }
    return i;
}

const SvgElementName = struct {
    closing: bool,
    name: []const u8,
};

fn nextSvgElementName(svg: []const u8, index: *usize) ?SvgElementName {
    while (std.mem.indexOfScalar(u8, svg[index.*..], '<')) |rel| {
        const tag_start = index.* + rel;
        index.* = tag_start + 1;
        if (index.* >= svg.len) return null;
        if (svg[index.*] == '!' or svg[index.*] == '?') continue;
        const closing = svg[index.*] == '/';
        const name_start = index.* + @intFromBool(closing);
        var name_end = name_start;
        while (name_end < svg.len and isSvgNameChar(svg[name_end])) : (name_end += 1) {}
        if (name_end == name_start) continue;
        const name = svg[name_start..name_end];
        if (std.mem.eql(u8, name, "svg")) continue;
        return .{ .closing = closing, .name = name };
    }
    return null;
}

fn isSvgNameChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '-' or c == ':';
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

const EdgePathClip = struct {
    head: f64 = 0,
    tail: f64 = 0,
};

const EdgePathHints = struct {
    tail_mdiamond: bool = false,
    head_msquare: bool = false,
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
    fill: []const u8,
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
    peripheries: usize,
    hidden: bool,
};

fn renderSvgClusters(writer: *Io.Writer, graph: *const Graph, layout: *const Layout) Io.Writer.Error!void {
    if (graph.subgraphs.items.len == 0) return;
    try renderSvgClusterTree(writer, graph, layout, null);
}

fn renderSvgClusterTree(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, parent: ?SubgraphId) Io.Writer.Error!void {
    for (graph.subgraphs.items, 0..) |cluster, index| {
        if (cluster.parent != parent) continue;
        try renderSvgClusterBox(writer, graph, cluster, layout, index);
        try renderSvgClusterTree(writer, graph, layout, cluster.id);
    }
}

fn renderSvgClusterBox(writer: *Io.Writer, graph: *const Graph, cluster: Subgraph, layout: *const Layout, index: usize) Io.Writer.Error!void {
    if (index >= layout.subgraphs.len) return;
    const box = layout.subgraphs[index];
    if (box.width <= 0 or box.height <= 0) return;
    var visual = resolveClusterVisual(cluster);
    if (visual.hidden) return;
    var default_id_buf: [32]u8 = undefined;
    const default_id = std.fmt.bufPrint(&default_id_buf, "clust{d}", .{index + 1}) catch unreachable;
    try writeSvgGroupOpen(writer, cluster.attrs.items, default_id, "cluster");
    try writeSvgTitle(writer, cluster.label);
    try writer.writeByte('\n');
    const cluster_wrap = try writeSvgInteractiveOpen(writer, graph.allocator, cluster.attrs.items, .{ .graph_name = graph.name, .node_name = cluster.label }, cluster.label);
    const rect = clusterVisualRect(graph, layout, index);
    if (try renderSvgStripedRectFill(writer, "vex-cluster-stripes", index + 1, cluster.attrs.items, rect, visual.radius, visual.fill)) {
        visual.fill = "none";
    } else {
        var fill_buf: [96]u8 = undefined;
        try resolveSvgGradientFill(writer, "vex-cluster-fill", index + 1, cluster.attrs.items, rect, &visual.fill, &fill_buf);
    }
    const stroke = if (visual.peripheries == 0) "none" else visual.stroke;
    if (visual.radius <= 0.001) {
        try writer.print("<polygon fill=\"{s}\" stroke=\"{s}\" points=\"", .{
            visual.fill,
            stroke,
        });
        try writeSvgRectPolygonPoints(writer, rect, .bottom_left_clockwise, false);
        try writer.writeByte('"');
        try writeSvgFillOpacity(writer, visual.fill_opacity);
        if (visual.peripheries != 0) {
            try writeSvgStrokeWidth(writer, visual.width);
            try writeSvgDash(writer, visual.dash);
        }
        try writer.writeAll("/>\n");
    } else {
        try writeSvgRectOpen(writer, rect, visual.radius);
        try writer.print(" fill=\"{s}\" fill-opacity=\"{s}\" stroke=\"{s}\"", .{ visual.fill, visual.fill_opacity, stroke });
        if (visual.peripheries != 0) {
            try writeSvgStrokeWidth(writer, visual.width);
            try writeSvgDash(writer, visual.dash);
        }
        try writer.writeAll("/>\n");
    }
    const label_just = attrValue(cluster.attrs.items, "labeljust");
    const label_loc = attrValue(cluster.attrs.items, "labelloc");
    const text_anchor: []const u8 = if (label_just) |value|
        if (std.ascii.eqlIgnoreCase(value, "l")) "start" else if (std.ascii.eqlIgnoreCase(value, "r")) "end" else "middle"
    else
        "middle";
    const label_x = if (std.mem.eql(u8, text_anchor, "start"))
        rect.x + 12.0
    else if (std.mem.eql(u8, text_anchor, "end"))
        rect.x + rect.width - 12.0
    else
        rect.x + rect.width / 2.0;
    const top_label_offset: f64 = if (clusterVisualRectHasVerticalTrim(cluster, layout)) 16.6 else 15.3;
    const label_y = if (label_loc) |value|
        if (std.ascii.eqlIgnoreCase(value, "b")) rect.y + rect.height - 10.0 else rect.y + top_label_offset
    else
        rect.y + top_label_offset;
    try writeSvgTextOpen(writer, text_anchor, label_x, label_y, visual.font_family, visual.font_size);
    try writeSvgTextFill(writer, visual.font_color);
    try writer.writeAll(">");
    try writeXmlEscaped(writer, cluster.label);
    try writer.writeAll("</text>\n");
    try writeSvgInteractiveClose(writer, cluster_wrap);
    try writer.writeAll("</g>\n");
}

fn clusterVisualRect(graph: *const Graph, layout: *const Layout, index: usize) RectF {
    return clusterVisualRectContainingNodes(graph, layout, index, rawClusterVisualRect(graph.subgraphs.items[index], layout, index));
}

fn rawClusterVisualRect(cluster: Subgraph, layout: *const Layout, index: usize) RectF {
    const box = layout.subgraphs[index];
    var rect = RectF{ .x = box.x, .y = box.y, .width = box.width, .height = box.height };
    if (cluster.parent != null or layout.subgraphs.len <= 1) return rect;

    var min_x = std.math.floatMax(f64);
    var max_x: f64 = -std.math.floatMax(f64);
    for (layout.subgraphs) |cluster_box| {
        if (cluster_box.width <= 0 or cluster_box.height <= 0) continue;
        min_x = @min(min_x, cluster_box.x);
        max_x = @max(max_x, cluster_box.x + cluster_box.width);
    }
    if (min_x == std.math.floatMax(f64)) return rect;

    const trim: f64 = 4.0;
    if (@abs(rect.x - min_x) <= 0.01 and rect.width > trim) {
        rect.x += trim;
        rect.width -= trim;
    }
    if (@abs(rect.x + rect.width - max_x) <= 0.01 and rect.width > trim) {
        rect.width -= trim;
    }
    if (clusterVisualRectHasVerticalTrim(cluster, layout) and rect.height > 1.2) {
        rect.y -= 1.3;
        rect.height -= 1.2;
    }
    return rect;
}

fn clusterVisualRectContainingNodes(graph: *const Graph, layout: *const Layout, index: usize, rect: RectF) RectF {
    if (index >= graph.subgraphs.items.len) return rect;
    const member_padding: f64 = 12.0;
    var bounds = BoundsBuilder{};
    bounds.includeRect(rect);
    for (graph.subgraphs.items[index].nodes) |node_id| {
        if (node_id >= graph.nodes.items.len or node_id >= layout.nodes.len) continue;
        const node_item = graph.nodes.items[node_id];
        if (resolveNodeVisual(node_item).hidden) continue;
        bounds.includeRect(expandRect(nodeRect(graphvizRenderNodeLayout(graph, layout, node_item)), member_padding));
    }
    return bounds.rect() orelse rect;
}

fn expandRect(rect: RectF, padding: f64) RectF {
    if (padding <= 0) return rect;
    return .{
        .x = rect.x - padding,
        .y = rect.y - padding,
        .width = rect.width + padding * 2.0,
        .height = rect.height + padding * 2.0,
    };
}

fn clusterVisualRectHasVerticalTrim(cluster: Subgraph, layout: *const Layout) bool {
    return cluster.parent == null and layout.subgraphs.len == 2;
}

fn writeSvgFillOpacity(writer: *Io.Writer, opacity: []const u8) Io.Writer.Error!void {
    if (std.mem.eql(u8, opacity, "1.0") or std.mem.eql(u8, opacity, "1") or std.mem.eql(u8, opacity, "1.00")) return;
    try writer.print(" fill-opacity=\"{s}\"", .{opacity});
}

fn writeSvgStrokeWidth(writer: *Io.Writer, width: f64) Io.Writer.Error!void {
    if (@abs(width - 1.0) <= 0.0001) return;
    try writer.writeAll(" stroke-width=\"");
    try writeSvgNumber(writer, width);
    try writer.writeByte('"');
}

fn renderSvgNodeShape(writer: *Io.Writer, node_item: Node, layout: NodeLayout, visual: NodeVisual, options: SvgOptions) Io.Writer.Error!void {
    var shape_layout = visualShapeLayout(node_item, fixedShapeLayout(node_item, layout));
    if (node_item.shape == .msquare) shape_layout.center.y += 0.1;
    switch (node_item.shape) {
        .point => {
            try writeSvgCircleOpen(writer, shape_layout.center, @min(shape_layout.width, shape_layout.height) / 2.0);
            try writer.print(" fill=\"{s}\" stroke=\"{s}\"", .{
                visual.stroke,
                visual.stroke,
            });
            try writeSvgStrokeWidth(writer, visual.width);
            try writer.writeAll("/>\n");
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
                    try renderSvgRectPolygonPrecise(writer, rect, ring_visual);
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
                try writeSvgCircleOpen(writer, shape_layout.center, @max(1, @min(shape_layout.width, shape_layout.height) / 2.0 - inset));
                try writer.print(" fill=\"{s}\" stroke=\"{s}\"", .{
                    if (ring == 0) visual.fill else "none",
                    visual.stroke,
                });
                try writeSvgStrokeWidth(writer, visual.width);
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            }
            if (node_item.shape == .mcircle) try renderSvgCircleDiagonals(writer, shape_layout, visual);
        },
        .ellipse => {
            var ring: usize = 0;
            while (ring < visual.peripheries) : (ring += 1) {
                const inset = @as(f64, @floatFromInt(ring)) * 5.0;
                try writer.print("<ellipse fill=\"{s}\" stroke=\"{s}\" cx=\"", .{
                    if (ring == 0) visual.fill else "none",
                    visual.stroke,
                });
                try writeSvgNumber(writer, shape_layout.center.x);
                try writer.writeAll("\" cy=\"");
                try writeSvgNumber(writer, shape_layout.center.y);
                try writer.writeAll("\" rx=\"");
                try writeSvgNumber(writer, @max(1, shape_layout.width / 2.0 - inset));
                try writer.writeAll("\" ry=\"");
                try writeSvgNumber(writer, @max(1, shape_layout.height / 2.0 - inset));
                try writer.writeByte('"');
                try writeSvgStrokeWidth(writer, visual.width);
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            }
        },
        .egg => try renderSvgEggShape(writer, shape_layout, visual),
        .polygon => try renderSvgCustomPolygon(writer, node_item, shape_layout, visual),
        .diamond => try renderSvgPolygonRings(6, writer, shape_layout, visual, diamondPoints),
        .mdiamond => {
            try renderSvgPolygonRingsPrecise(6, writer, shape_layout, visual, diamondPoints);
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

fn visualShapeLayout(node_item: Node, layout: NodeLayout) NodeLayout {
    var result = layout;
    switch (node_item.shape) {
        .mdiamond => {
            result.center.y -= 2.4;
            result.width = @max(1, result.width - 0.26);
            result.height = @min(result.height, 36.0);
        },
        .msquare => {
            result.center.x -= 0.005;
            result.center.y += 1.5025;
            result.width += 0.22;
            result.height += 0.215;
        },
        .ellipse, .circle, .doublecircle, .mcircle => result.center.y += 1.0,
        else => {},
    }
    return result;
}

fn renderSvgPolygon(writer: *Io.Writer, points: []const Point, visual: NodeVisual) Io.Writer.Error!void {
    try renderSvgPolygonWithPrecision(writer, points, visual, false);
}

fn renderSvgPolygonPrecise(writer: *Io.Writer, points: []const Point, visual: NodeVisual) Io.Writer.Error!void {
    try renderSvgPolygonWithPrecision(writer, points, visual, true);
}

fn renderSvgPolygonWithPrecision(writer: *Io.Writer, points: []const Point, visual: NodeVisual, precise: bool) Io.Writer.Error!void {
    try writer.print("<polygon fill=\"{s}\" stroke=\"{s}\" points=\"", .{ visual.fill, visual.stroke });
    var written: usize = 0;
    var first_point: ?Point = null;
    for (points) |point| {
        if (point.x < 0 and point.y < 0) continue;
        if (written > 0) try writer.writeByte(' ');
        if (first_point == null) first_point = point;
        try writeSvgPointWithPrecision(writer, point, precise);
        written += 1;
    }
    if (first_point) |point| {
        if (written > 0) try writer.writeByte(' ');
        try writeSvgPointWithPrecision(writer, point, precise);
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

fn renderSvgPolygonRingsPrecise(comptime N: usize, writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual, pointsFn: fn (NodeLayout) [N]Point) Io.Writer.Error!void {
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
        try renderSvgPolygonPrecise(writer, &points, ring_visual);
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
        .{ .x = cx - hw, .y = cy },
        .{ .x = cx, .y = cy + hh },
        .{ .x = cx + hw, .y = cy },
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
        try writeSvgClosedCubicPath(writer, .{ .x = cx, .y = top }, &.{
            .{
                .c1 = .{ .x = cx + upper_rx, .y = top },
                .c2 = .{ .x = cx + lower_rx, .y = cy + ry * 0.22 },
                .end = .{ .x = cx + lower_rx * 0.72, .y = cy + ry * 0.78 },
            },
            .{
                .c1 = .{ .x = cx + lower_rx * 0.42, .y = bottom },
                .c2 = .{ .x = cx - lower_rx * 0.42, .y = bottom },
                .end = .{ .x = cx - lower_rx * 0.72, .y = cy + ry * 0.78 },
            },
            .{
                .c1 = .{ .x = cx - lower_rx, .y = cy + ry * 0.22 },
                .c2 = .{ .x = cx - upper_rx, .y = top },
                .end = .{ .x = cx, .y = top },
            },
        }, ring_visual);
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
    const short_x = hw * 0.278;
    const graphviz_inner_x = inner_x + 0.05;
    const graphviz_top_y = cy - short_y + 0.02;
    const graphviz_bottom_y = cy + short_y - 0.03;
    try writeSvgPolylineLinePrecise(writer, cx - graphviz_inner_x, graphviz_top_y, cx - graphviz_inner_x, graphviz_bottom_y, visual);
    try writeSvgPolylineLineYPrecise(writer, cx - short_x, cy + inner_y + 0.02, cx + short_x, cy + inner_y + 0.02, visual);
    try writeSvgPolylineLinePrecise(writer, cx + graphviz_inner_x, graphviz_bottom_y, cx + graphviz_inner_x, graphviz_top_y, visual);
    try writeSvgPolylineLineYPrecise(writer, cx + short_x, cy - inner_y - 0.03, cx - short_x, cy - inner_y - 0.03, visual);
}

fn renderSvgCornerDiagonals(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const d = @min(@max(1, @min(rect.width, rect.height) - 0.2) / 3.0, 18);
    try writeSvgPolylineLinePrecise(writer, rect.x + d, rect.y, rect.x, rect.y + d, visual);
    try writeSvgPolylineLinePrecise(writer, rect.x, rect.y + rect.height - d + 0.005, rect.x + d, rect.y + rect.height, visual);
    try writeSvgPolylineLinePrecise(writer, rect.x + rect.width - d + 0.01, rect.y + rect.height, rect.x + rect.width, rect.y + rect.height - d + 0.005, visual);
    try writeSvgPolylineLinePrecise(writer, rect.x + rect.width, rect.y + d, rect.x + rect.width - d + 0.01, rect.y, visual);
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
    try writeSvgClosedPath(writer, &.{
        .{ .x = rect.x, .y = rect.y },
        .{ .x = rect.x + rect.width - fold, .y = rect.y },
        .{ .x = rect.x + rect.width, .y = rect.y + fold },
        .{ .x = rect.x + rect.width, .y = rect.y + rect.height },
        .{ .x = rect.x, .y = rect.y + rect.height },
    }, visual);
    try writeSvgPolylinePath(writer, &.{
        .{ .x = rect.x + rect.width - fold, .y = rect.y },
        .{ .x = rect.x + rect.width - fold, .y = rect.y + fold },
        .{ .x = rect.x + rect.width, .y = rect.y + fold },
    }, visual);
}

fn renderSvgTabShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const tab_w = @min(rect.width * 0.42, 52);
    const tab_h = @min(rect.height * 0.28, 18);
    try writeSvgClosedPath(writer, &.{
        .{ .x = rect.x, .y = rect.y + tab_h },
        .{ .x = rect.x + tab_w * 0.18, .y = rect.y + tab_h },
        .{ .x = rect.x + tab_w * 0.18, .y = rect.y },
        .{ .x = rect.x + tab_w, .y = rect.y },
        .{ .x = rect.x + tab_w, .y = rect.y + tab_h },
        .{ .x = rect.x + rect.width, .y = rect.y + tab_h },
        .{ .x = rect.x + rect.width, .y = rect.y + rect.height },
        .{ .x = rect.x, .y = rect.y + rect.height },
    }, visual);
    try writeSvgPolylinePath(writer, &.{
        .{ .x = rect.x + tab_w, .y = rect.y + tab_h },
        .{ .x = rect.x + tab_w * 0.18, .y = rect.y + tab_h },
    }, visual);
}

fn renderSvgFolderShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const tab_w = @min(rect.width * 0.46, 64);
    const tab_h = @min(rect.height * 0.28, 18);
    const slope = @min(tab_h * 0.7, 10);
    try writeSvgClosedPath(writer, &.{
        .{ .x = rect.x, .y = rect.y + tab_h },
        .{ .x = rect.x + tab_w * 0.28, .y = rect.y + tab_h },
        .{ .x = rect.x + tab_w * 0.42, .y = rect.y },
        .{ .x = rect.x + tab_w, .y = rect.y },
        .{ .x = rect.x + tab_w + slope, .y = rect.y + tab_h },
        .{ .x = rect.x + rect.width, .y = rect.y + tab_h },
        .{ .x = rect.x + rect.width, .y = rect.y + rect.height },
        .{ .x = rect.x, .y = rect.y + rect.height },
    }, visual);
}

fn renderSvgBox3dShape(writer: *Io.Writer, layout: NodeLayout, visual: NodeVisual) Io.Writer.Error!void {
    const rect = nodeRect(layout);
    const depth = @min(@min(rect.width, rect.height) * 0.18, 18);
    try writeSvgClosedPath(writer, &.{
        .{ .x = rect.x, .y = rect.y + depth },
        .{ .x = rect.x + depth, .y = rect.y },
        .{ .x = rect.x + rect.width, .y = rect.y },
        .{ .x = rect.x + rect.width, .y = rect.y + rect.height - depth },
        .{ .x = rect.x + rect.width - depth, .y = rect.y + rect.height },
        .{ .x = rect.x, .y = rect.y + rect.height },
    }, visual);
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
    try writer.print("<path d=\"", .{});
    try writePathMove(writer, .{ .x = left, .y = top + ry });
    try writePathCubic(writer, .{ .x = left, .y = top }, .{ .x = right, .y = top }, .{ .x = right, .y = top + ry });
    try writePathLine(writer, .{ .x = right, .y = bottom - ry });
    try writePathCubic(writer, .{ .x = right, .y = bottom }, .{ .x = left, .y = bottom }, .{ .x = left, .y = bottom - ry });
    try writer.print("Z\" fill=\"{s}\" stroke=\"{s}\"", .{ visual.fill, visual.stroke });
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
    try writer.print("<path d=\"", .{});
    try writePathMove(writer, .{ .x = left, .y = top + ry });
    try writePathCubic(writer, .{ .x = left, .y = top + ry * 2.0 }, .{ .x = right, .y = top + ry * 2.0 }, .{ .x = right, .y = top + ry });
    try writer.print("\" fill=\"none\" stroke=\"{s}\"", .{visual.stroke});
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn renderSvgBoxShape(writer: *Io.Writer, rect: RectF, visual: NodeVisual, radius: f64) Io.Writer.Error!void {
    try writeSvgRectOpen(writer, rect, radius);
    try writer.print(" fill=\"{s}\" stroke=\"{s}\"", .{ visual.fill, visual.stroke });
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

const RectPointOrder = enum {
    top_left_clockwise,
    bottom_left_clockwise,
    top_right_counterclockwise,
};

fn renderSvgRectPolygon(writer: *Io.Writer, rect: RectF, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<polygon fill=\"{s}\" stroke=\"{s}\" points=\"", .{
        visual.fill,
        visual.stroke,
    });
    try writeSvgRectPolygonPoints(writer, rect, .top_right_counterclockwise, false);
    try writer.writeByte('"');
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn renderSvgRectPolygonPrecise(writer: *Io.Writer, rect: RectF, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<polygon fill=\"{s}\" stroke=\"{s}\" points=\"", .{
        visual.fill,
        visual.stroke,
    });
    try writeSvgRectPolygonPoints(writer, rect, .top_right_counterclockwise, true);
    try writer.writeByte('"');
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn writeSvgRectPolygonPoints(writer: *Io.Writer, rect: RectF, order: RectPointOrder, precise: bool) Io.Writer.Error!void {
    const left = rect.x;
    const right = rect.x + rect.width;
    const top = rect.y;
    const bottom = rect.y + rect.height;
    const points: [5]Point = switch (order) {
        .top_left_clockwise => [_]Point{
            .{ .x = left, .y = top },
            .{ .x = right, .y = top },
            .{ .x = right, .y = bottom },
            .{ .x = left, .y = bottom },
            .{ .x = left, .y = top },
        },
        .bottom_left_clockwise => [_]Point{
            .{ .x = left, .y = bottom },
            .{ .x = left, .y = top },
            .{ .x = right, .y = top },
            .{ .x = right, .y = bottom },
            .{ .x = left, .y = bottom },
        },
        .top_right_counterclockwise => [_]Point{
            .{ .x = right, .y = top },
            .{ .x = left, .y = top },
            .{ .x = left, .y = bottom },
            .{ .x = right, .y = bottom },
            .{ .x = right, .y = top },
        },
    };
    for (points, 0..) |point, index| {
        if (index > 0) try writer.writeByte(' ');
        try writeSvgPointWithPrecision(writer, point, precise);
    }
}

fn renderSvgComponentTab(writer: *Io.Writer, x: f64, y: f64, width: f64, height: f64, visual: NodeVisual) Io.Writer.Error!void {
    try writeSvgPolylinePath(writer, &.{
        .{ .x = x + width, .y = y },
        .{ .x = x, .y = y },
        .{ .x = x, .y = y + height },
        .{ .x = x + width, .y = y + height },
    }, visual);
}

fn writeSvgLine(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<path d=\"", .{});
    try writePathMove(writer, .{ .x = x1, .y = y1 });
    try writePathLine(writer, .{ .x = x2, .y = y2 });
    try writer.print("\" fill=\"none\" stroke=\"{s}\"", .{visual.stroke});
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn writeSvgPolylinePath(writer: *Io.Writer, points: []const Point, visual: NodeVisual) Io.Writer.Error!void {
    if (points.len == 0) return;
    try writer.print("<path d=\"", .{});
    try writePathMove(writer, points[0]);
    for (points[1..]) |point| try writePathLine(writer, point);
    try writer.print("\" fill=\"none\" stroke=\"{s}\"", .{visual.stroke});
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn writeSvgClosedPath(writer: *Io.Writer, points: []const Point, visual: NodeVisual) Io.Writer.Error!void {
    if (points.len == 0) return;
    try writer.print("<path d=\"", .{});
    try writePathMove(writer, points[0]);
    for (points[1..]) |point| try writePathLine(writer, point);
    try writer.print("Z\" fill=\"{s}\" stroke=\"{s}\"", .{ visual.fill, visual.stroke });
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

const CubicSegment = struct {
    c1: Point,
    c2: Point,
    end: Point,
};

fn writeSvgClosedCubicPath(writer: *Io.Writer, start: Point, segments: []const CubicSegment, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<path d=\"", .{});
    try writePathMove(writer, start);
    for (segments) |segment| try writePathCubic(writer, segment.c1, segment.c2, segment.end);
    try writer.print("Z\" fill=\"{s}\" stroke=\"{s}\"", .{ visual.fill, visual.stroke });
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn writeSvgPolylineLine(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<polyline fill=\"none\" stroke=\"{s}\" points=\"", .{visual.stroke});
    try writeSvgPoint(writer, .{ .x = x1, .y = y1 });
    try writer.writeByte(' ');
    try writeSvgPoint(writer, .{ .x = x2, .y = y2 });
    try writer.writeByte('"');
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn writeSvgPolylineLinePrecise(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<polyline fill=\"none\" stroke=\"{s}\" points=\"", .{visual.stroke});
    try writeSvgNumberPrecise(writer, x1);
    try writer.writeByte(',');
    try writeSvgNumberPrecise(writer, y1);
    try writer.writeByte(' ');
    try writeSvgNumberPrecise(writer, x2);
    try writer.writeByte(',');
    try writeSvgNumberPrecise(writer, y2);
    try writer.writeByte('"');
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn writeSvgPolylineLineYPrecise(writer: *Io.Writer, x1: f64, y1: f64, x2: f64, y2: f64, visual: NodeVisual) Io.Writer.Error!void {
    try writer.print("<polyline fill=\"none\" stroke=\"{s}\" points=\"", .{visual.stroke});
    try writeSvgNumber(writer, x1);
    try writer.writeByte(',');
    try writeSvgNumberPrecise(writer, y1);
    try writer.writeByte(' ');
    try writeSvgNumber(writer, x2);
    try writer.writeByte(',');
    try writeSvgNumberPrecise(writer, y2);
    try writer.writeByte('"');
    try writeSvgStrokeWidth(writer, visual.width);
    try writeSvgDash(writer, visual.dash);
    try writer.writeAll("/>\n");
}

fn writeSvgPoint(writer: *Io.Writer, point: Point) Io.Writer.Error!void {
    try writeSvgNumber(writer, point.x);
    try writer.writeByte(',');
    try writeSvgNumber(writer, point.y);
}

fn writeSvgPointWithPrecision(writer: *Io.Writer, point: Point, precise: bool) Io.Writer.Error!void {
    if (precise) {
        try writeSvgNumberPrecise(writer, point.x);
        try writer.writeByte(',');
        try writeSvgNumberPrecise(writer, point.y);
    } else {
        try writeSvgPoint(writer, point);
    }
}

fn writeSvgNumber(writer: *Io.Writer, value: f64) Io.Writer.Error!void {
    const normalized = if (@abs(value) < 0.05) 0.0 else value;
    const rounded = @round(normalized);
    if (@abs(normalized - rounded) < 0.05) {
        try writer.print("{d:.0}", .{rounded});
    } else {
        try writer.print("{d:.1}", .{normalized});
    }
}

fn writeSvgNumberPrecise(writer: *Io.Writer, value: f64) Io.Writer.Error!void {
    const normalized = if (@abs(value) < 0.005) 0.0 else value;
    const rounded = @round(normalized);
    if (@abs(normalized - rounded) < 0.005) {
        try writer.print("{d:.0}", .{rounded});
    } else {
        try writer.print("{d:.2}", .{normalized});
    }
}

fn writeSvgRectOpen(writer: *Io.Writer, rect: RectF, radius: f64) Io.Writer.Error!void {
    try writer.writeAll("<rect x=\"");
    try writeSvgNumber(writer, rect.x);
    try writer.writeAll("\" y=\"");
    try writeSvgNumber(writer, rect.y);
    try writer.writeAll("\" width=\"");
    try writeSvgNumber(writer, rect.width);
    try writer.writeAll("\" height=\"");
    try writeSvgNumber(writer, rect.height);
    try writer.writeAll("\" rx=\"");
    try writeSvgNumber(writer, radius);
    try writer.writeByte('"');
}

fn writeSvgCircleOpen(writer: *Io.Writer, center: Point, radius: f64) Io.Writer.Error!void {
    try writer.writeAll("<circle cx=\"");
    try writeSvgNumber(writer, center.x);
    try writer.writeAll("\" cy=\"");
    try writeSvgNumber(writer, center.y);
    try writer.writeAll("\" r=\"");
    try writeSvgNumber(writer, radius);
    try writer.writeByte('"');
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
    try writeSvgRectOpen(writer, .{ .x = x, .y = y, .width = layout.width, .height = layout.height }, if (rounded) 10 else visual.radius);
    try writer.print(" fill=\"{s}\" stroke=\"{s}\"", .{ visual.fill, visual.stroke });
    try writeSvgStrokeWidth(writer, visual.width);
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
                .horizontal => try writeSvgLine(writer, child_rect.x, rect.y, child_rect.x, rect.y + rect.height, visual),
                .vertical => try writeSvgLine(writer, rect.x, child_rect.y, rect.x + rect.width, child_rect.y, visual),
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
    const fill = attrValue(edge_item.attrs.items, "fillcolor") orelse stroke;
    return .{
        .stroke = stroke,
        .fill = fill,
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

fn resolveClusterVisual(cluster: Subgraph) ClusterVisual {
    const style = attrValue(cluster.attrs.items, "style");
    const filled = styleHas(style, "filled");
    const dashed = styleHas(style, "dashed");
    const dotted = styleHas(style, "dotted");
    const rounded = styleHas(style, "rounded");
    const bold = styleHas(style, "bold");
    const color_attr = attrValue(cluster.attrs.items, "color");
    const color = color_attr orelse "#94a3b8";
    const stroke = attrValue(cluster.attrs.items, "pencolor") orelse color;
    const fillcolor = attrValue(cluster.attrs.items, "fillcolor");
    const bgcolor = attrValue(cluster.attrs.items, "bgcolor");
    const fill = if (bgcolor) |value|
        if (!filled or (fillcolor == null and color_attr == null)) value else (fillcolor orelse color)
    else if (filled)
        fillcolor orelse color
    else
        "none";
    return .{
        .fill = fill,
        .stroke = stroke,
        .font_color = attrValue(cluster.attrs.items, "fontcolor") orelse "black",
        .font_family = attrValue(cluster.attrs.items, "fontname") orelse default_svg_font_family,
        .font_size = parsePositiveAttrFloat(cluster.attrs.items, "fontsize", 14.0),
        .width = parseAttrFloat(cluster.attrs.items, "penwidth", if (bold) 3.0 else 1.0),
        .radius = if (rounded) 10 else 0,
        .dash = if (dotted) .dotted else if (dashed) .dashed else .none,
        .fill_opacity = "1.0",
        .peripheries = parseAttrUsize(cluster.attrs.items, "peripheries", 1),
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

fn writeSvgMarkerDef(writer: *Io.Writer, edge_id: EdgeId, suffix: []const u8, shape: MarkerShape, stroke: []const u8, fill: []const u8, scale: f64) Io.Writer.Error!void {
    if (scale <= 0) return;
    const marker_size = 7.0 * scale;
    try writer.print("<marker id=\"arrow-{d}-{s}\" viewBox=\"0 0 10 10\" refX=\"{d:.1}\" refY=\"5\" markerWidth=\"{d:.2}\" markerHeight=\"{d:.2}\" orient=\"auto", .{ edge_id, suffix, markerRefX(shape), marker_size, marker_size });
    if (std.mem.eql(u8, suffix, "tail")) try writer.writeAll("-start-reverse");
    try writer.writeAll("\">");
    switch (shape) {
        .none => {},
        .normal => try writer.print("<path d=\"M 1.2 1.4 L 9.2 5 L 1.2 8.6 z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"0.5\"/>", .{ fill, stroke }),
        .vee => try writer.print("<path d=\"M 1 1 L 9 5 L 1 9\" fill=\"none\" stroke=\"{s}\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>", .{stroke}),
        .dot => try writer.print("<circle cx=\"5\" cy=\"5\" r=\"4\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"0.5\"/>", .{ fill, stroke }),
        .odot => try writer.print("<circle cx=\"5\" cy=\"5\" r=\"3.5\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{stroke}),
        .box => try writer.print("<rect x=\"1.5\" y=\"1.5\" width=\"7\" height=\"7\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"0.5\"/>", .{ fill, stroke }),
        .obox => try writer.print("<rect x=\"1.5\" y=\"1.5\" width=\"7\" height=\"7\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{stroke}),
        .diamond => try writer.print("<path d=\"M 5 0.8 L 9.2 5 L 5 9.2 L 0.8 5 z\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"0.5\"/>", .{ fill, stroke }),
        .odiamond => try writer.print("<path d=\"M 5 0.8 L 9.2 5 L 5 9.2 L 0.8 5 z\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{stroke}),
        .tee => try writer.print("<path d=\"M 8.5 1 L 8.5 9\" fill=\"none\" stroke=\"{s}\" stroke-width=\"2\" stroke-linecap=\"round\"/>", .{stroke}),
        .crow => try writer.print("<path d=\"M 9 1 L 1 5 L 9 9 M 1 5 L 9 5\" fill=\"none\" stroke=\"{s}\" stroke-width=\"1.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>", .{stroke}),
        .empty => try writer.print("<path d=\"M 0.8 0.8 L 9.2 5 L 0.8 9.2 z\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"1.5\"/>", .{stroke}),
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

const InlineArrowOptions = struct {
    head_length_scale: f64 = 1.0,
    tail_length_scale: f64 = 1.0,
    head_tip_x_shift: f64 = 0.0,
    head_tip_y_shift: f64 = 0.0,
    head_right_x_shift: f64 = 0.0,
    head_right_y_shift: f64 = 0.0,
    head_left_x_shift: f64 = 0.0,
    head_left_y_shift: f64 = 0.0,
    head_y_shift: f64 = 0.0,
    head_precise: bool = false,
    head_tip_precise: bool = true,
};

fn writeSvgInlineArrowheads(writer: *Io.Writer, directed: bool, route: EdgeRoute, visual: EdgeVisual, options: InlineArrowOptions) Io.Writer.Error!void {
    if (!directed or visual.marker_scale <= 0) return;
    if (visual.marker_end == .normal) {
        try writeSvgInlineNormalArrow(writer, route.end, route.control2, visual.stroke, visual.fill, visual.marker_scale, options.head_length_scale, false, .{ .y_shift = options.head_y_shift, .tip_x_shift = options.head_tip_x_shift, .tip_y_shift = options.head_tip_y_shift, .right_x_shift = options.head_right_x_shift, .right_y_shift = options.head_right_y_shift, .left_x_shift = options.head_left_x_shift, .left_y_shift = options.head_left_y_shift, .precise = options.head_precise, .tip_precise = options.head_tip_precise });
    }
    if (visual.marker_start == .normal) {
        try writeSvgInlineNormalArrow(writer, route.start, route.control1, visual.stroke, visual.fill, visual.marker_scale, options.tail_length_scale, true, .{});
    }
}

const InlineNormalArrowPointAdjust = struct {
    y_shift: f64 = 0.0,
    tip_x_shift: f64 = 0.0,
    tip_y_shift: f64 = 0.0,
    right_x_shift: f64 = 0.0,
    right_y_shift: f64 = 0.0,
    left_x_shift: f64 = 0.0,
    left_y_shift: f64 = 0.0,
    precise: bool = false,
    tip_precise: bool = true,
};

fn writeSvgInlineNormalArrow(writer: *Io.Writer, tip: Point, toward: Point, stroke: []const u8, fill: []const u8, scale: f64, length_scale: f64, reverse: bool, adjust: InlineNormalArrowPointAdjust) Io.Writer.Error!void {
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
    const arrow_len = 10.0 * scale * length_scale;
    const arrow_half = 3.5 * scale;
    const base = Point{ .x = tip.x - ux * arrow_len, .y = tip.y - uy * arrow_len };
    const px = -uy;
    const py = ux;
    const left = Point{ .x = base.x + px * arrow_half + adjust.left_x_shift, .y = base.y + py * arrow_half + adjust.left_y_shift + adjust.y_shift };
    const right = Point{ .x = base.x - px * arrow_half + adjust.right_x_shift, .y = base.y - py * arrow_half + adjust.right_y_shift + adjust.y_shift };
    const adjusted_tip = Point{ .x = tip.x + adjust.tip_x_shift, .y = tip.y + adjust.y_shift + adjust.tip_y_shift };
    try writer.print("<polygon fill=\"{s}\" stroke=\"{s}\" points=\"", .{
        fill,
        stroke,
    });
    try writeSvgArrowPoint(writer, right, adjust.precise);
    try writer.writeByte(' ');
    try writeSvgArrowPoint(writer, adjusted_tip, adjust.precise and adjust.tip_precise);
    try writer.writeByte(' ');
    try writeSvgArrowPoint(writer, left, adjust.precise);
    try writer.writeByte(' ');
    try writeSvgArrowPoint(writer, right, adjust.precise);
    try writer.writeAll("\"/>\n");
}

fn writeSvgArrowPoint(writer: *Io.Writer, point: Point, precise: bool) Io.Writer.Error!void {
    if (precise) {
        try writeSvgNumberPrecise(writer, point.x);
        try writer.writeByte(',');
        try writeSvgNumberPrecise(writer, point.y);
    } else {
        try writeSvgPoint(writer, point);
    }
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

fn writeEdgePath(writer: *Io.Writer, layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64, direct_route: EdgeRoute, routing: SvgEdgeRouting, path_clip: EdgePathClip, hints: EdgePathHints) Io.Writer.Error!void {
    if (routing == .line) {
        try writePathMove(writer, shortenPointToward(direct_route.start, direct_route.control1, path_clip.tail));
        try writePathLine(writer, shortenPointToward(direct_route.end, direct_route.control2, path_clip.head));
        return;
    }
    if (routing == .ortho) {
        const start = shortenPointToward(direct_route.start, direct_route.control1, path_clip.tail);
        const end = shortenPointToward(direct_route.end, direct_route.control2, path_clip.head);
        try writeOrthoEdgePath(writer, start, end, rankdir);
        return;
    }
    if (isBackEdge(layout, edge_item)) {
        try writeBackEdgePath(writer, layout, edge_item, rankdir, offset, direct_route, routing, path_clip);
        return;
    }

    const waypoint_count = longEdgeWaypointCount(layout, edge_item);
    if (waypoint_count == 1 and routing == .curved) {
        const mid = longEdgeWaypoint(layout, edge_item, rankdir, offset, 0, waypoint_count);
        const first = smoothSegmentControls(direct_route.start, mid, rankdir);
        const second = smoothSegmentControls(mid, direct_route.end, rankdir);
        var c1 = first.c1;
        var c2 = second.c2;
        if (edgeTouchesMultipleClusters(layout, edge_item)) {
            c1 = lerpPoint(first.c1, direct_route.control1, 0.35);
            c2 = lerpPoint(second.c2, direct_route.control2, 0.90);
            if (direct_route.end.x > direct_route.start.x) c1.x += 0.75;
        }
        var path_start = direct_route.start;
        if (graphvizCrossClusterLongPathStartShift(layout, edge_item, rankdir, direct_route)) |shift| {
            path_start = .{ .x = path_start.x + shift.x, .y = path_start.y + shift.y };
            c1 = .{ .x = c1.x + shift.x * 0.5, .y = c1.y + shift.y * 0.75 };
        }
        if (graphvizCrossClusterLongPathControl1Shift(layout, edge_item, rankdir, direct_route)) |shift| {
            c1 = .{ .x = c1.x + shift.x, .y = c1.y + shift.y };
        }
        var path_end = direct_route.end;
        if (graphvizCrossClusterLongPathEndShift(layout, edge_item, rankdir, direct_route)) |shift| {
            c2 = .{ .x = c2.x + shift.x * 0.5, .y = c2.y + shift.y * 0.5 };
            path_end = .{ .x = path_end.x + shift.x, .y = path_end.y + shift.y };
            if (edgeTouchesMultipleClusters(layout, edge_item)) c2.y += if (rankdir == .TB) -0.01 else 0.01;
        }
        if (edgeTouchesMultipleClusters(layout, edge_item)) {
            try writePathMovePrecise(writer, path_start);
            try writePathCubicPrecise(writer, c1, c2, path_end);
        } else {
            try writePathMove(writer, path_start);
            try writePathCubic(writer, c1, c2, path_end);
        }
        return;
    }
    if (waypoint_count == 0) {
        if (routing == .polyline) {
            try writePathMove(writer, direct_route.start);
            try writePathLine(writer, direct_route.end);
            return;
        }
        if (crossClusterDiagonalControls(layout, edge_item, rankdir, direct_route)) |controls| {
            if (graphvizCrossClusterLeftPathRoute(layout, edge_item, rankdir, direct_route, controls)) |path| {
                var graphviz_path = path;
                graphviz_path.end.x -= 0.06;
                graphviz_path.end.y += if (rankdir == .TB) -0.04 else 0.04;
                try writePathMovePrecise(writer, graphviz_path.start);
                try writePathCubicPrecise(writer, graphviz_path.control1, graphviz_path.control2, graphviz_path.end);
                return;
            }
            try writePathMove(writer, direct_route.start);
            try writePathCubic(writer, controls.c1, controls.c2, direct_route.end);
            return;
        }
        if (msquareHeadDiagonalPath(direct_route, rankdir, hints)) |path| {
            try writePathMovePrecise(writer, path.start);
            try writePathCubicPrecise(writer, path.control1, path.control2, path.end);
            return;
        }
        if (diamondTailDiagonalPath(direct_route, rankdir, hints)) |path| {
            try writePathMovePrecise(writer, path.start);
            try writePathCubicPrecise(writer, path.control1, path.control2, path.end);
            return;
        }
        if (diamondTailDiagonalControls(direct_route.start, direct_route.end, rankdir, hints)) |controls| {
            try writePathMove(writer, direct_route.start);
            try writePathCubic(writer, controls.c1, controls.c2, direct_route.end);
            return;
        }
        if (diagonalEdgeControls(direct_route.start, direct_route.end, rankdir, 1.0)) |controls| {
            try writePathMove(writer, direct_route.start);
            try writePathCubic(writer, controls.c1, controls.c2, direct_route.end);
            return;
        }
        const adjacent_route = if (graphvizAdjacentPathRouteEnabled(layout, edge_item))
            graphvizAdjacentPathRouteForPath(layout, edge_item, direct_route, rankdir)
        else
            direct_route;
        if (alignedAdjacentControls(adjacent_route.start, adjacent_route.end, rankdir)) |controls| {
            var precise_controls = controls;
            precise_controls.c1.y += if (rankdir == .TB) 0.03 else -0.03;
            var path_end = adjacent_route.end;
            shiftGraphvizAdjacentPathEnd(&path_end, rankdir);
            try writePathMove(writer, adjacent_route.start);
            try writePathCubicPrecise(writer, precise_controls.c1, precise_controls.c2, path_end);
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

fn msquareHeadDiagonalPath(route: EdgeRoute, rankdir: RankDir, hints: EdgePathHints) ?EdgeRoute {
    if (!hints.head_msquare) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (@abs(dx) < @abs(dy) * 0.35) return null;

    const y_dir: f64 = if (rankdir == .TB) 1.0 else -1.0;
    var start = route.start;
    var end = route.end;
    if (dx >= 0) {
        start.x += 1.27;
        end.x -= 1.53;
    } else {
        start.x -= 1.16;
        end.x += 0.90;
    }
    start.y += y_dir * 1.55;
    end.y -= y_dir * 1.68;

    const adjusted_dx = end.x - start.x;
    const adjusted_dy = end.y - start.y;
    var c1 = Point{ .x = start.x + adjusted_dx * 0.293, .y = start.y + adjusted_dy * 0.293 };
    if (dx >= 0) {
        c1.x += 0.01;
        c1.y += y_dir * 0.01;
    } else {
        c1.x -= 0.02;
        c1.y += y_dir * 0.01;
    }
    var c2 = Point{ .x = start.x + adjusted_dx * 0.663, .y = start.y + adjusted_dy * 0.663 };
    c2.x += if (dx >= 0) -0.01 else 0.01;
    c2.y -= y_dir * 0.01;
    if (dx >= 0) start.y -= y_dir * 0.01;
    return .{
        .start = start,
        .control1 = c1,
        .control2 = c2,
        .end = end,
        .label = cubicPoint(start, c1, c2, end, 0.5),
    };
}

fn diamondTailDiagonalPath(route: EdgeRoute, rankdir: RankDir, hints: EdgePathHints) ?EdgeRoute {
    if (!hints.tail_mdiamond) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (@abs(dx) < @abs(dy) * 0.35) return null;
    var path_start = route.start;
    if (dx >= 0) {
        path_start.x -= 0.07;
        path_start.y += if (rankdir == .TB) 0.04 else -0.04;
    } else {
        path_start.x -= 0.02;
        path_start.y += if (rankdir == .TB) 0.04 else -0.04;
    }
    var end = route.end;
    const head_x_shift: f64 = if (dx >= 0) -0.22 else 0.22;
    end.x += head_x_shift;
    end.y += if (rankdir == .TB) -0.35 else 0.35;
    const adjusted_dx = end.x - route.start.x;
    const adjusted_dy = end.y - route.start.y;
    const c1_extra_x: f64 = if (dx >= 0) -0.05 else -0.01;
    const c1_extra_y: f64 = if (dx >= 0) 0.04 else 0.04;
    if (dx >= 0) {
        end.x -= 0.01;
        end.y += if (rankdir == .TB) 0.04 else -0.04;
    } else {
        end.y += if (rankdir == .TB) 0.04 else -0.04;
    }
    const c1 = Point{ .x = route.start.x + adjusted_dx * 0.275 + c1_extra_x, .y = route.start.y + adjusted_dy * 0.275 + c1_extra_y };
    const c2_extra_x: f64 = if (dx < 0) -0.11 else 0.08;
    const c2_extra_y: f64 = if (dx >= 0) 0.03 else 0.03;
    const c2 = Point{ .x = route.start.x + adjusted_dx * 0.665 + head_x_shift * 0.5 + c2_extra_x, .y = route.start.y + adjusted_dy * 0.665 + c2_extra_y };
    return .{
        .start = path_start,
        .control1 = c1,
        .control2 = c2,
        .end = end,
        .label = cubicPoint(path_start, c1, c2, end, 0.5),
    };
}

fn diamondTailDiagonalControls(start: Point, end: Point, rankdir: RankDir, hints: EdgePathHints) ?EdgeControls {
    if (!hints.tail_mdiamond) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    if (@abs(dx) < @abs(dy) * 0.35) return null;
    const c1_rank: f64 = 0.275;
    const c2_rank: f64 = 0.665;
    return .{
        .c1 = .{ .x = start.x + dx * c1_rank, .y = start.y + dy * 0.275 },
        .c2 = .{ .x = start.x + dx * c2_rank, .y = start.y + dy * 0.665 },
    };
}

fn crossClusterDiagonalControls(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute) ?EdgeControls {
    if (!edgeTouchesMultipleClusters(layout, edge_item)) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (@abs(dx) < @abs(dy) * 0.35) return null;
    if (dx >= 0) return null;
    return .{
        .c1 = lerpPoint(route.control1, .{ .x = route.start.x + dx * 0.26, .y = route.start.y + dy * 0.26 }, 0.90),
        .c2 = lerpPoint(route.control2, .{ .x = route.start.x + dx * 0.64, .y = route.start.y + dy * 0.64 }, 0.55),
    };
}

fn graphvizCrossClusterLeftPathRoute(layout: *const Layout, edge_item: Edge, rankdir: RankDir, route: EdgeRoute, controls: EdgeControls) ?EdgeRoute {
    if (!edgeTouchesMultipleClusters(layout, edge_item)) return null;
    if (rankdir != .TB and rankdir != .BT) return null;
    if (longEdgeWaypointCount(layout, edge_item) != 0) return null;
    const dx = route.end.x - route.start.x;
    const dy = route.end.y - route.start.y;
    if (dx >= 0 or @abs(dx) < @abs(dy) * 0.35) return null;
    const y_shift: f64 = if (rankdir == .TB) 0.3 else -0.3;
    const c2_y_adjust: f64 = if (rankdir == .TB) 0.06 else -0.06;
    return .{
        .start = .{ .x = route.start.x + 0.07, .y = route.start.y + y_shift },
        .control1 = .{ .x = controls.c1.x - 0.20, .y = controls.c1.y + y_shift + 0.03 },
        .control2 = .{ .x = controls.c2.x - 0.3, .y = controls.c2.y + y_shift + c2_y_adjust },
        .end = .{ .x = route.end.x, .y = route.end.y - y_shift * 0.3 },
        .label = cubicPoint(route.start, controls.c1, controls.c2, route.end, 0.5),
    };
}

fn alignedAdjacentControls(start: Point, end: Point, rankdir: RankDir) ?EdgeControls {
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const axes = LayoutAxes.init(rankdir);
    const axis_delta = axes.rankAxisDelta(dx, dy);
    const cross_delta = if (axes.horizontalRanks()) @abs(dy) else @abs(dx);
    if (axis_delta <= 0.001 or cross_delta > 1.0) return null;
    return .{
        .c1 = .{ .x = start.x + dx * 0.30, .y = start.y + dy * 0.30 },
        .c2 = .{ .x = start.x + dx * 0.66, .y = start.y + dy * 0.66 },
    };
}

fn graphvizAdjacentTaperControls(start: Point, end: Point, rankdir: RankDir) EdgeControls {
    _ = rankdir;
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    return .{
        .c1 = .{ .x = start.x + dx * 0.30, .y = start.y + dy * 0.30 },
        .c2 = .{ .x = start.x + dx * 0.66, .y = start.y + dy * 0.66 },
    };
}

fn shiftGraphvizAdjacentPathEnd(point: *Point, rankdir: RankDir) void {
    switch (rankdir) {
        .TB => point.y -= 0.04,
        .BT => point.y += 0.04,
        else => {},
    }
}

fn graphvizAdjacentPathRoute(route: EdgeRoute, rankdir: RankDir) EdgeRoute {
    var result = route;
    const tail_overlap: f64 = 1.3;
    const head_gap: f64 = 1.5;
    switch (rankdir) {
        .TB => {
            result.start.y += tail_overlap;
            result.end.y -= head_gap;
        },
        .BT => {
            result.start.y -= tail_overlap;
            result.end.y += head_gap;
        },
        .LR => {
            result.start.x += tail_overlap;
            result.end.x -= head_gap;
        },
        .RL => {
            result.start.x -= tail_overlap;
            result.end.x += head_gap;
        },
    }
    return result;
}

fn graphvizAdjacentPathRouteForEdge(layout: *const Layout, edge_item: Edge, route: EdgeRoute, rankdir: RankDir) EdgeRoute {
    _ = layout;
    _ = edge_item;
    return graphvizAdjacentPathRoute(route, rankdir);
}

fn graphvizAdjacentPathRouteForPath(layout: *const Layout, edge_item: Edge, route: EdgeRoute, rankdir: RankDir) EdgeRoute {
    return graphvizAdjacentPathRouteForEdge(layout, edge_item, route, rankdir);
}

fn leftClusterAdjacentRouteShiftApplies(layout: *const Layout, edge_item: Edge, rankdir: RankDir) bool {
    if (rankdir != .TB and rankdir != .BT) return false;
    const from_cluster = clusterIndexForLayoutNode(layout, edge_item.from);
    const to_cluster = clusterIndexForLayoutNode(layout, edge_item.to);
    if (from_cluster == null or to_cluster == null or from_cluster.? != to_cluster.?) return false;
    const cluster = layout.subgraphs[from_cluster.?];
    return cluster.width > 0 and cluster.x + cluster.width / 2.0 < layout.width / 2.0;
}

fn rightOuterAdjacentRouteShiftApplies(layout: *const Layout, edge_item: Edge, rankdir: RankDir) bool {
    if (rankdir != .TB and rankdir != .BT) return false;
    if (edge_item.from >= layout.ranks.len or edge_item.to >= layout.ranks.len) return false;
    const from_cluster = clusterIndexForLayoutNode(layout, edge_item.from);
    const to_cluster = clusterIndexForLayoutNode(layout, edge_item.to);
    if (from_cluster == null or to_cluster == null or from_cluster.? != to_cluster.?) return false;
    const cluster = layout.subgraphs[from_cluster.?];
    if (cluster.width <= 0 or cluster.x + cluster.width / 2.0 <= layout.width / 2.0) return false;
    const min_rank = minRankInLayoutCluster(layout, from_cluster.?) orelse return false;
    return layout.ranks[edge_item.from] == min_rank and layout.ranks[edge_item.to] == min_rank + 1;
}

fn rightMiddleAdjacentPathShiftApplies(layout: *const Layout, edge_item: Edge, rankdir: RankDir) bool {
    if (rankdir != .TB and rankdir != .BT) return false;
    if (edge_item.from >= layout.ranks.len or edge_item.to >= layout.ranks.len) return false;
    const from_cluster = clusterIndexForLayoutNode(layout, edge_item.from);
    const to_cluster = clusterIndexForLayoutNode(layout, edge_item.to);
    if (from_cluster == null or to_cluster == null or from_cluster.? != to_cluster.?) return false;
    const cluster = layout.subgraphs[from_cluster.?];
    if (cluster.width <= 0 or cluster.x + cluster.width / 2.0 <= layout.width / 2.0) return false;
    const min_rank = minRankInLayoutCluster(layout, from_cluster.?) orelse return false;
    const max_rank = maxRankInLayoutCluster(layout, from_cluster.?) orelse return false;
    return layout.ranks[edge_item.from] > min_rank and layout.ranks[edge_item.to] < max_rank and layout.ranks[edge_item.from] + 1 == layout.ranks[edge_item.to];
}

fn rightLowerAdjacentRouteShiftApplies(layout: *const Layout, edge_item: Edge, rankdir: RankDir) bool {
    if (rankdir != .TB and rankdir != .BT) return false;
    if (edge_item.from >= layout.ranks.len or edge_item.to >= layout.ranks.len) return false;
    const from_cluster = clusterIndexForLayoutNode(layout, edge_item.from);
    const to_cluster = clusterIndexForLayoutNode(layout, edge_item.to);
    if (from_cluster == null or to_cluster == null or from_cluster.? != to_cluster.?) return false;
    const cluster = layout.subgraphs[from_cluster.?];
    if (cluster.width <= 0 or cluster.x + cluster.width / 2.0 <= layout.width / 2.0) return false;
    const max_rank = maxRankInLayoutCluster(layout, from_cluster.?) orelse return false;
    return layout.ranks[edge_item.to] == max_rank and layout.ranks[edge_item.from] + 1 == max_rank;
}

fn minRankInLayoutCluster(layout: *const Layout, cluster_index: usize) ?usize {
    var result: usize = std.math.maxInt(usize);
    for (layout.nodes, 0..) |_, node_id| {
        if (node_id >= layout.ranks.len) continue;
        const node_cluster = clusterIndexForLayoutNode(layout, node_id) orelse continue;
        if (node_cluster != cluster_index) continue;
        result = @min(result, layout.ranks[node_id]);
    }
    return if (result == std.math.maxInt(usize)) null else result;
}

fn maxRankInLayoutCluster(layout: *const Layout, cluster_index: usize) ?usize {
    var result: usize = 0;
    var found = false;
    for (layout.nodes, 0..) |_, node_id| {
        if (node_id >= layout.ranks.len) continue;
        const node_cluster = clusterIndexForLayoutNode(layout, node_id) orelse continue;
        if (node_cluster != cluster_index) continue;
        result = if (found) @max(result, layout.ranks[node_id]) else layout.ranks[node_id];
        found = true;
    }
    return if (found) result else null;
}

fn clusterIndexForLayoutNode(layout: *const Layout, node_id: NodeId) ?usize {
    if (node_id >= layout.nodes.len) return null;
    const center = layout.nodes[node_id].center;
    for (layout.subgraphs, 0..) |cluster, index| {
        if (pointInsideCluster(center, cluster)) return index;
    }
    return null;
}

fn graphvizAdjacentPathRouteEnabled(layout: *const Layout, edge_item: Edge) bool {
    if (edge_item.ltail != null or edge_item.lhead != null) return false;
    if (edgeTouchesMultipleClusters(layout, edge_item)) return false;
    return true;
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

fn writeBackEdgePath(writer: *Io.Writer, layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64, route: EdgeRoute, routing: SvgEdgeRouting, path_clip: EdgePathClip) Io.Writer.Error!void {
    const from = layout.nodes[edge_item.from];
    const to = layout.nodes[edge_item.to];
    const side_gap = @max(5.0, layout.margin * 0.3) + @abs(offset);

    if (rankdir == .TB or rankdir == .BT) {
        const prefer_left = backEdgeUsesNegativeSide(layout, edge_item, rankdir);
        var side_x = if (prefer_left)
            @max(layout.margin_x, @min(from.center.x - from.width / 2.0, to.center.x - to.width / 2.0) - side_gap)
        else
            @min(layout.width - layout.margin_x, @max(from.center.x + from.width / 2.0, to.center.x + to.width / 2.0) + side_gap);
        if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) side_x -= 0.55;
        const rank_delta = route.end.y - route.start.y;
        const p1 = Point{ .x = side_x, .y = route.start.y + rank_delta * 0.20 };
        const p2 = Point{ .x = side_x, .y = route.end.y - rank_delta * 0.21 };
        if (routing == .polyline) {
            var path_start = shortenPointToward(route.start, p1, path_clip.tail);
            if (graphvizSameClusterBackEdgePathStartOnlyShift(layout, edge_item, rankdir, prefer_left)) |shift| path_start = .{ .x = path_start.x + shift.x, .y = path_start.y + shift.y };
            var path_end = shortenPointToward(route.end, p2, path_clip.head);
            if (graphvizSameClusterBackEdgePathEndShift(layout, edge_item, rankdir, prefer_left)) |shift| path_end = .{ .x = path_end.x + shift.x, .y = path_end.y + shift.y };
            try writePathMove(writer, path_start);
            try writePathLine(writer, p1);
            try writePathLine(writer, p2);
            try writePathLine(writer, path_end);
        } else {
            const start_side_dx = side_x - route.start.x;
            const end_side_dx = side_x - route.end.x;
            const c1x = route.start.x + start_side_dx * 0.42;
            const c2x = route.start.x + start_side_dx * 0.85;
            const c3x = route.end.x + end_side_dx * 0.86;
            const c4x = route.end.x + end_side_dx * 0.60;
            const side_bulge = if (prefer_left) -@abs(start_side_dx) * 0.72 else @abs(start_side_dx) * 0.72;
            const middle_delta_y = p2.y - p1.y;
            const first_control1_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) 1.0 else 0.0;
            const first_control1_x = c1x + first_control1_shift;
            var path_start = shortenPointToward(route.start, .{ .x = c1x, .y = route.start.y + rank_delta * 0.05 }, path_clip.tail);
            if (graphvizSameClusterBackEdgePathStartOnlyShift(layout, edge_item, rankdir, prefer_left)) |shift| path_start = .{ .x = path_start.x + shift.x, .y = path_start.y + shift.y };
            if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) {
                path_start.x += 0.46;
                path_start.y += if (rankdir == .TB) 0.08 else -0.08;
            }
            var path_end = shortenPointToward(route.end, .{ .x = c4x, .y = route.end.y - rank_delta * 0.10 }, path_clip.head);
            if (graphvizSameClusterBackEdgePathEndShift(layout, edge_item, rankdir, prefer_left)) |shift| path_end = .{ .x = path_end.x + shift.x, .y = path_end.y + shift.y };
            if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) {
                try writePathMovePrecise(writer, path_start);
            } else {
                try writePathMove(writer, path_start);
            }
            const channel_p1_y_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) (if (rankdir == .TB) -0.10 else 0.10) else 0.0;
            const channel_p1 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) Point{ .x = p1.x - 1.0, .y = p1.y + channel_p1_y_shift } else p1;
            const channel_p2 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) Point{ .x = p2.x - 1.0, .y = p2.y + 0.2 } else p2;
            const tail_control1_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) -0.64 else 0.0;
            const tail_control1_y_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) -0.06 else 0.0;
            const tail_end_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) -0.87 else 0.0;
            const first_control1_y_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) 0.5 else 0.0;
            const first_control2_y_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) -0.55 else 0.0;
            const middle_control_y_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) -0.45 else 0.0;
            const first_control2_x_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) 0.30 else 0.0;
            const first_control2_extra_y_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) 0.04 else 0.0;
            const tail_control1_x = c3x + tail_control1_shift;
            const tail_control2_x_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) -0.13 else 0.0;
            const tail_control2_y_shift: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) -0.07 else 0.0;
            const tail_control1_extra_x: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) -0.05 else 0.0;
            const tail_control1_extra_y: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) 0.03 else 0.0;
            const tail_end_extra_x: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) 0.04 else 0.0;
            const tail_end_extra_y: f64 = if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) 0.02 else 0.0;
            const tail_end = Point{ .x = path_end.x + tail_end_shift + tail_end_extra_x, .y = path_end.y + tail_end_extra_y };
            if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) {
                try writePathCubicPreciseControls(writer, .{ .x = first_control1_x, .y = route.start.y + rank_delta * 0.05 + first_control1_y_shift }, .{ .x = c2x + first_control2_x_shift, .y = route.start.y + rank_delta * 0.12 + first_control2_y_shift + first_control2_extra_y_shift }, channel_p1);
            } else {
                try writePathCubic(writer, .{ .x = first_control1_x, .y = route.start.y + rank_delta * 0.05 + first_control1_y_shift }, .{ .x = c2x + first_control2_x_shift, .y = route.start.y + rank_delta * 0.12 + first_control2_y_shift + first_control2_extra_y_shift }, channel_p1);
            }
            if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) {
                try writePathCubicContinuationPreciseControls(writer, .{ .x = side_x + side_bulge - 0.06, .y = p1.y + middle_delta_y * 0.42 + middle_control_y_shift - 0.01 }, .{ .x = side_x + side_bulge - 0.06, .y = p1.y + middle_delta_y * 0.57 + middle_control_y_shift - 0.01 }, channel_p2);
            } else {
                try writePathCubicContinuation(writer, .{ .x = side_x + side_bulge, .y = p1.y + middle_delta_y * 0.42 + middle_control_y_shift }, .{ .x = side_x + side_bulge, .y = p1.y + middle_delta_y * 0.57 + middle_control_y_shift }, channel_p2);
            }
            if (prefer_left and edgeTouchesSingleCluster(layout, edge_item)) {
                try writePathCubicContinuationPrecise(writer, .{ .x = tail_control1_x + tail_control1_extra_x, .y = route.end.y - rank_delta * 0.155 + tail_control1_y_shift + tail_control1_extra_y }, .{ .x = c4x + tail_control2_x_shift, .y = route.end.y - rank_delta * 0.10 + tail_control2_y_shift }, tail_end);
            } else {
                try writePathCubicContinuation(writer, .{ .x = tail_control1_x, .y = route.end.y - rank_delta * 0.155 + tail_control1_y_shift }, .{ .x = c4x + tail_control2_x_shift, .y = route.end.y - rank_delta * 0.10 + tail_control2_y_shift }, tail_end);
            }
        }
        return;
    }

    const prefer_top = backEdgeUsesNegativeSide(layout, edge_item, rankdir);
    const side_y = if (prefer_top)
        @max(layout.margin_y, @min(from.center.y - from.height / 2.0, to.center.y - to.height / 2.0) - side_gap)
    else
        @min(layout.height - layout.margin_y, @max(from.center.y + from.height / 2.0, to.center.y + to.height / 2.0) + side_gap);
    const rank_delta = route.end.x - route.start.x;
    const p1 = Point{ .x = route.start.x + rank_delta * 0.20, .y = side_y };
    const p2 = Point{ .x = route.end.x - rank_delta * 0.21, .y = side_y };
    if (routing == .polyline) {
        const path_start = shortenPointToward(route.start, p1, path_clip.tail);
        const path_end = shortenPointToward(route.end, p2, path_clip.head);
        try writePathMove(writer, path_start);
        try writePathLine(writer, p1);
        try writePathLine(writer, p2);
        try writePathLine(writer, path_end);
    } else {
        const start_side_dy = side_y - route.start.y;
        const end_side_dy = side_y - route.end.y;
        const c1y = route.start.y + start_side_dy * 0.42;
        const c2y = route.start.y + start_side_dy * 0.85;
        const c3y = route.end.y + end_side_dy * 0.86;
        const c4y = route.end.y + end_side_dy * 0.60;
        const side_bulge = if (prefer_top) -@abs(start_side_dy) * 0.62 else @abs(start_side_dy) * 0.62;
        const middle_delta_x = p2.x - p1.x;
        const path_start = shortenPointToward(route.start, .{ .x = route.start.x + rank_delta * 0.05, .y = c1y }, path_clip.tail);
        const path_end = shortenPointToward(route.end, .{ .x = route.end.x - rank_delta * 0.10, .y = c4y }, path_clip.head);
        try writePathMove(writer, path_start);
        try writePathCubic(writer, .{ .x = route.start.x + rank_delta * 0.05, .y = c1y }, .{ .x = route.start.x + rank_delta * 0.12, .y = c2y }, p1);
        try writePathCubic(writer, .{ .x = p1.x + middle_delta_x * 0.42, .y = side_y + side_bulge }, .{ .x = p1.x + middle_delta_x * 0.57, .y = side_y + side_bulge }, p2);
        try writePathCubic(writer, .{ .x = route.end.x - rank_delta * 0.155, .y = c3y }, .{ .x = route.end.x - rank_delta * 0.10, .y = c4y }, path_end);
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
    for (layout.subgraphs, 0..) |cluster_box, cluster_index| {
        if (pointInsideCluster(layout.nodes[edge_item.from].center, cluster_box)) from_cluster = cluster_index;
        if (pointInsideCluster(layout.nodes[edge_item.to].center, cluster_box)) to_cluster = cluster_index;
    }
    if (from_cluster == null or to_cluster == null) return false;
    return from_cluster.? != to_cluster.?;
}

fn edgeTouchesSingleCluster(layout: *const Layout, edge_item: Edge) bool {
    if (edge_item.from >= layout.nodes.len or edge_item.to >= layout.nodes.len) return false;
    var from_cluster: ?usize = null;
    var to_cluster: ?usize = null;
    for (layout.subgraphs, 0..) |cluster_box, cluster_index| {
        if (pointInsideCluster(layout.nodes[edge_item.from].center, cluster_box)) from_cluster = cluster_index;
        if (pointInsideCluster(layout.nodes[edge_item.to].center, cluster_box)) to_cluster = cluster_index;
    }
    if (from_cluster == null or to_cluster == null) return false;
    return from_cluster.? == to_cluster.?;
}

fn pointInsideCluster(point: Point, cluster_box: SubgraphLayout) bool {
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
    try writer.writeByte('M');
    try writeSvgPathPoint(writer, point);
}

fn writePathMovePrecise(writer: *Io.Writer, point: Point) Io.Writer.Error!void {
    try writer.writeByte('M');
    try writeSvgPathPointPrecise(writer, point);
}

fn writePathLine(writer: *Io.Writer, point: Point) Io.Writer.Error!void {
    try writer.writeByte('L');
    try writeSvgPathPoint(writer, point);
}

fn writePathCubic(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try writeSvgPathPoint(writer, c1);
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, c2);
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, end);
}

fn writePathCubicC1Precise(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try writeSvgPathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, c2);
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, end);
}

fn writePathCubicPrecise(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try writeSvgPathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try writeSvgPathPointPrecise(writer, c2);
    try writer.writeByte(' ');
    try writeSvgPathPointPrecise(writer, end);
}

fn writePathCubicPreciseControls(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try writeSvgPathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try writeSvgPathPointPrecise(writer, c2);
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, end);
}

fn writePathCubicEndPrecise(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte('C');
    try writeSvgPathPoint(writer, c1);
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, c2);
    try writer.writeByte(' ');
    try writeSvgPathPointPrecise(writer, end);
}

fn writePathCubicContinuation(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, c1);
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, c2);
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, end);
}

fn writePathCubicContinuationPrecise(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte(' ');
    try writeSvgPathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try writeSvgPathPointPrecise(writer, c2);
    try writer.writeByte(' ');
    try writeSvgPathPointPrecise(writer, end);
}

fn writePathCubicContinuationPreciseControls(writer: *Io.Writer, c1: Point, c2: Point, end: Point) Io.Writer.Error!void {
    try writer.writeByte(' ');
    try writeSvgPathPointPrecise(writer, c1);
    try writer.writeByte(' ');
    try writeSvgPathPointPrecise(writer, c2);
    try writer.writeByte(' ');
    try writeSvgPathPoint(writer, end);
}

fn writeSvgPathPoint(writer: *Io.Writer, point: Point) Io.Writer.Error!void {
    try writeSvgPathNumber(writer, point.x);
    try writer.writeByte(',');
    try writeSvgPathNumber(writer, point.y);
}

fn writeSvgPathPointPrecise(writer: *Io.Writer, point: Point) Io.Writer.Error!void {
    try writeSvgPathNumberPrecise(writer, point.x);
    try writer.writeByte(',');
    try writeSvgPathNumberPrecise(writer, point.y);
}

fn writeSvgPathNumber(writer: *Io.Writer, value: f64) Io.Writer.Error!void {
    const normalized = if (@abs(value) < 0.05) 0.0 else value;
    const rounded = @round(normalized);
    if (@abs(normalized - rounded) < 0.05) {
        try writer.print("{d:.0}", .{rounded});
    } else {
        try writer.print("{d:.1}", .{normalized});
    }
}

fn writeSvgPathNumberPrecise(writer: *Io.Writer, value: f64) Io.Writer.Error!void {
    const normalized = if (@abs(value) < 0.005) 0.0 else value;
    const rounded = @round(normalized);
    if (@abs(normalized - rounded) < 0.005) {
        try writer.print("{d:.0}", .{rounded});
    } else {
        try writer.print("{d:.2}", .{normalized});
    }
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
    const back_toward = backEdgeEllipseToward(graph, layout, edge_item, rankdir);
    const start_toward = if (back_toward) |toward| toward.start else to.center;
    const end_toward = if (back_toward) |toward| toward.end else from.center;
    const raw_start = if (tail_clip)
        samePortBoundaryPoint(graph, layout, edge_item, false) orelse recordBoundaryPoint(graph.nodes.items[edge_item.from], from, start_toward, edge_item.tail_record_port, edge_item.tail_port, true) orelse nodePortBoundaryPoint(graph.nodes.items[edge_item.from], from, start_toward, edge_item.tail_port, rankdir, true)
    else
        from.center;
    const raw_end = if (head_clip)
        samePortBoundaryPoint(graph, layout, edge_item, true) orelse recordBoundaryPoint(graph.nodes.items[edge_item.to], to, end_toward, edge_item.head_record_port, edge_item.head_port, false) orelse nodePortBoundaryPoint(graph.nodes.items[edge_item.to], to, end_toward, edge_item.head_port, rankdir, false)
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

const BackEdgeToward = struct {
    start: Point,
    end: Point,
};

fn backEdgeEllipseToward(graph: *const Graph, layout: *const Layout, edge_item: Edge, rankdir: RankDir) ?BackEdgeToward {
    if (!isBackEdge(layout, edge_item)) return null;
    if (edge_item.from >= graph.nodes.items.len or edge_item.to >= graph.nodes.items.len) return null;
    if (edge_item.tail_port != .auto or edge_item.head_port != .auto) return null;
    if (edge_item.tail_record_port != null or edge_item.head_record_port != null) return null;
    if (!shapeUsesEllipseBoundary(graph.nodes.items[edge_item.from].shape)) return null;
    if (!shapeUsesEllipseBoundary(graph.nodes.items[edge_item.to].shape)) return null;

    const from = layout.nodes[edge_item.from];
    const to = layout.nodes[edge_item.to];
    const side_sign: f64 = if (backEdgeUsesNegativeSide(layout, edge_item, rankdir)) -1.0 else 1.0;
    const side_offset: f64 = 13.0 * side_sign;
    const rank_offset: f64 = 18.0;
    return switch (rankdir) {
        .TB, .BT => .{
            .start = .{ .x = from.center.x + side_offset, .y = from.center.y + std.math.sign(to.center.y - from.center.y) * rank_offset },
            .end = .{ .x = to.center.x + side_offset, .y = to.center.y + std.math.sign(from.center.y - to.center.y) * rank_offset },
        },
        .LR, .RL => .{
            .start = .{ .x = from.center.x + std.math.sign(to.center.x - from.center.x) * rank_offset, .y = from.center.y + side_offset },
            .end = .{ .x = to.center.x + std.math.sign(from.center.x - to.center.x) * rank_offset, .y = to.center.y + side_offset },
        },
    };
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

fn clusterBoundaryPoint(graph: *const Graph, layout: *const Layout, id: SubgraphId, from: Point, toward: Point) ?Point {
    const rect = subgraphRect(graph, layout, id) orelse return null;
    return intersectRectBoundary(rect, from, toward) orelse pointForPort(rect, .auto, toward);
}

fn subgraphRect(graph: *const Graph, layout: *const Layout, id: SubgraphId) ?RectF {
    if (id >= graph.subgraphs.items.len or id >= layout.subgraphs.len) return null;
    const box = layout.subgraphs[id];
    if (box.width <= 0 or box.height <= 0) return null;
    return .{ .x = box.x, .y = box.y, .width = box.width, .height = box.height };
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
    if (shapeUsesDiamondBoundary(node_item.shape)) return diamondBoundaryPoint(visualShapeLayout(node_item, layout), toward);
    if (shapeUsesRectBoundary(node_item.shape)) return rectBoundaryPoint(layout, toward);
    return boundaryPoint(layout, toward, rankdir, leaving);
}

fn shapeUsesEllipseBoundary(shape: Shape) bool {
    return switch (shape) {
        .ellipse, .circle, .doublecircle, .mcircle => true,
        else => false,
    };
}

fn shapeUsesDiamondBoundary(shape: Shape) bool {
    return switch (shape) {
        .diamond, .mdiamond => true,
        else => false,
    };
}

fn shapeUsesRectBoundary(shape: Shape) bool {
    return switch (shape) {
        .box, .square, .msquare => true,
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

fn rectBoundaryPoint(node: NodeLayout, toward: Point) Point {
    const rect = RectF{
        .x = node.center.x - node.width / 2.0,
        .y = node.center.y - node.height / 2.0,
        .width = node.width,
        .height = node.height,
    };
    return intersectRectBoundary(rect, node.center, toward) orelse pointForPort(rect, .auto, toward);
}

fn diamondBoundaryPoint(node: NodeLayout, toward: Point) Point {
    const cx = node.center.x;
    const cy = node.center.y;
    const dx = toward.x - cx;
    const dy = toward.y - cy;
    if (@abs(dx) <= 0.0001 and @abs(dy) <= 0.0001) return node.center;
    const hw = @max(node.width / 2.0, 0.0001);
    const hh = @max(node.height / 2.0, 0.0001);
    const scale = 1.0 / (@abs(dx) / hw + @abs(dy) / hh);
    return .{
        .x = cx + dx * scale,
        .y = cy + dy * scale,
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

fn writeSvgTextOpen(writer: *Io.Writer, text_anchor: []const u8, x: f64, y: f64, font_family: []const u8, font_size: f64) Io.Writer.Error!void {
    try writer.print("<text xml:space=\"preserve\" text-anchor=\"{s}\" x=\"", .{text_anchor});
    try writeSvgNumber(writer, x);
    try writer.writeAll("\" y=\"");
    try writeSvgNumber(writer, y);
    try writer.print("\" font-family=\"{s}\" font-size=\"{d:.2}\"", .{ font_family, font_size });
}

fn writeSvgTspanOpen(writer: *Io.Writer, x: f64) Io.Writer.Error!void {
    try writer.writeAll("<tspan x=\"");
    try writeSvgNumber(writer, x);
    try writer.writeAll("\">");
}

fn writeSvgTspanOpenDy(writer: *Io.Writer, x: f64, dy: f64) Io.Writer.Error!void {
    try writer.writeAll("<tspan x=\"");
    try writeSvgNumber(writer, x);
    try writer.print("\" dy=\"{d:.1}\">", .{dy});
}

fn plainSingleLineLabel(text: []const u8) bool {
    return std.mem.indexOfScalar(u8, text, '\n') == null;
}

fn renderSvgPlainTextBlock(writer: *Io.Writer, text: []const u8, x: f64, center_y: f64, font_size: f64, fill: []const u8, font_family: []const u8, text_anchor: []const u8) Io.Writer.Error!void {
    const line_height = font_size * 1.25;
    const y = center_y - line_height / 2.0 + line_height * 0.72;
    try writeSvgTextOpen(writer, text_anchor, x, y, font_family, font_size);
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
        try writeSvgRectOpen(writer, .{ .x = x - width / 2.0, .y = center_y - height / 2.0, .width = width, .height = height }, 4);
        try writer.writeAll(" fill=\"#ffffff\" stroke=\"#e2e8f0\" opacity=\"0.92\"/>\n");
    }

    try writeSvgTextOpen(writer, text_anchor, x, first_y, font_family, font_size);
    try writeSvgTextFill(writer, fill);
    if (dominant_middle and line_count == 1) try writer.writeAll(" dominant-baseline=\"middle\"");
    try writer.writeAll(">");
    try writeDisplayLabelTspans(writer, text, x, line_height);
    try writer.writeAll("</text>\n");
}

fn writeDisplayLabelTspans(writer: *Io.Writer, text: []const u8, x: f64, line_height: f64) Io.Writer.Error!void {
    try writeSvgTspanOpen(writer, x);
    var lines = std.mem.splitScalar(u8, text, '\n');
    var idx: usize = 0;
    while (lines.next()) |line| : (idx += 1) {
        if (idx > 0) {
            try writer.writeAll("</tspan>");
            try writeSvgTspanOpenDy(writer, x, line_height);
        }
        try writeXmlEscaped(writer, line);
    }
    try writer.writeAll("</tspan>");
}

fn maybeNodeIdByLabel(graph: *const Graph, label: []const u8) ?NodeId {
    for (graph.nodes.items) |node_item| {
        if (attrValue(node_item.attrs.items, "vex_text_id")) |text_id| {
            if (std.mem.eql(u8, text_id, label)) return node_item.id;
        }
        if (std.mem.eql(u8, node_item.label, label)) return node_item.id;
    }
    return null;
}

fn nodeIdByLabel(graph: *const Graph, label: []const u8) NodeId {
    return maybeNodeIdByLabel(graph, label) orelse @panic("missing node label");
}

test "code API builds graph and layered layout" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "api" });
    defer graph.deinit();

    const a = try graph.addNode("Start", .{ .shape = .box });
    const b = try graph.addNode("B", .{});
    _ = try graph.addEdge(a, b, .{ .label = "next" });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expectEqual(@as(usize, 2), layout.nodes.len);
    try std.testing.expect(layout.height > 0);
}

test "code API allows duplicate node names and uses ids for identity" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "api" });
    defer graph.deinit();

    const first = try graph.addNode("Task A", .{ .shape = .box });
    const second = try graph.addNode("Task B", .{ .shape = .diamond });
    try std.testing.expect(first != second);
    try std.testing.expectEqual(@as(usize, 2), graph.nodes.items.len);
    try std.testing.expectEqualStrings("Task A", graph.nodes.items[first].label);
    try std.testing.expectEqualStrings("Task B", graph.nodes.items[second].label);

    _ = try graph.addEdge(first, second, .{ .label = "next" });
    try std.testing.expectEqual(first, graph.edges.items[0].from);
    try std.testing.expectEqual(second, graph.edges.items[0].to);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    try std.testing.expectEqual(@as(usize, 2), layout.nodes.len);
}

test "code API exposes typed graph samplepoints attr" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .samplepoints = 16 });
    try std.testing.expectEqualStrings("16", attrValue(graph.attrs.items, "samplepoints").?);

    var parsed = try parseDot(allocator,
        \\digraph G {
        \\  graph [samplepoints=24];
        \\  a -> b;
        \\}
    );
    defer parsed.deinit();
    try std.testing.expectEqualStrings("24", attrValue(parsed.attrs.items, "samplepoints").?);
}

test "code API sets typed node and edge options at creation" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "api" });
    defer graph.deinit();

    const a = try graph.addNode("a", .{
        .label = "A",
        .color = "#334155",
        .fillcolor = "#dbeafe",
        .gradientangle = 30,
        .fontcolor = "#0f172a",
        .fontname = "Courier",
        .fontsize = 22,
        .shape = .box,
        .styles = &.{ .filled, .rounded, .dashed },
        .penwidth = 2,
        .peripheries = 2,
        .width = 1.25,
        .height = 0.75,
        .fixedsize = .fit_label,
        .margin = "0.12,0.08",
        .xlabel = "extra",
        .labelloc = .bottom,
        .labeljust = .left,
        .url = "https://example.com/node",
        .href = "https://example.com/node",
        .tooltip = "node tip",
        .title = "node title",
        .target = "_blank",
        .ordering = .out,
        .group = "main",
    });
    const b = try graph.addNode("b", .{ .shape = .diamond });
    const edge = try graph.addEdge(a, b, .{
        .label = "edge",
        .color = "#16a34a",
        .fillcolor = "#bbf7d0",
        .fontcolor = "#064e3b",
        .fontname = "Helvetica",
        .fontsize = 16,
        .styles = &.{ .bold, .dashed },
        .penwidth = 3,
        .weight = 4,
        .constraint = false,
        .min_len = 2,
        .url = "https://example.com/edge",
        .href = "https://example.com/edge",
        .tooltip = "edge tip",
        .title = "edge title",
        .target = "_self",
        .arrowhead = .vee,
        .arrowtail = .dot,
        .arrowsize = 1.75,
        .dir = .both,
        .taillabel = "tail",
        .headlabel = "head",
        .xlabel = "xedge",
        .labelfontcolor = "#14532d",
        .labelfontname = "Helvetica",
        .labelfontsize = 11,
        .labeldistance = 1.5,
        .labelangle = 25,
        .decorate = true,
        .tailclip = false,
        .headclip = false,
        .samehead = "h",
        .sametail = "t",
    });

    const node_item = graph.nodes.items[a];
    try std.testing.expectEqualStrings("A", node_item.label);
    try std.testing.expectEqual(Shape.box, node_item.shape);
    try std.testing.expectEqualStrings("#334155", node_item.color);
    try std.testing.expectEqualStrings("#dbeafe", attrValue(node_item.attrs.items, "fillcolor").?);
    try std.testing.expectEqualStrings("30", attrValue(node_item.attrs.items, "gradientangle").?);
    try std.testing.expectEqualStrings("#0f172a", attrValue(node_item.attrs.items, "fontcolor").?);
    try std.testing.expectEqualStrings("Courier", attrValue(node_item.attrs.items, "fontname").?);
    try std.testing.expectEqualStrings("22", attrValue(node_item.attrs.items, "fontsize").?);
    try std.testing.expectEqualStrings("filled,rounded,dashed", attrValue(node_item.attrs.items, "style").?);
    try std.testing.expectEqualStrings("2", attrValue(node_item.attrs.items, "penwidth").?);
    try std.testing.expectEqualStrings("2", attrValue(node_item.attrs.items, "peripheries").?);
    try std.testing.expectEqualStrings("1.25", attrValue(node_item.attrs.items, "width").?);
    try std.testing.expectEqualStrings("0.75", attrValue(node_item.attrs.items, "height").?);
    try std.testing.expectEqualStrings("true", attrValue(node_item.attrs.items, "fixedsize").?);
    try std.testing.expectEqualStrings("0.12,0.08", attrValue(node_item.attrs.items, "margin").?);
    try std.testing.expectEqualStrings("extra", attrValue(node_item.attrs.items, "xlabel").?);
    try std.testing.expectEqualStrings("b", attrValue(node_item.attrs.items, "labelloc").?);
    try std.testing.expectEqualStrings("l", attrValue(node_item.attrs.items, "labeljust").?);
    try std.testing.expectEqualStrings("https://example.com/node", attrValue(node_item.attrs.items, "URL").?);
    try std.testing.expectEqualStrings("node tip", attrValue(node_item.attrs.items, "tooltip").?);
    try std.testing.expectEqualStrings("node title", attrValue(node_item.attrs.items, "title").?);
    try std.testing.expectEqualStrings("_blank", attrValue(node_item.attrs.items, "target").?);
    try std.testing.expectEqualStrings("out", attrValue(node_item.attrs.items, "ordering").?);
    try std.testing.expectEqualStrings("main", attrValue(node_item.attrs.items, "group").?);

    const edge_item = graph.edges.items[edge];
    try std.testing.expectEqualStrings("edge", edge_item.label.?);
    try std.testing.expectEqualStrings("#16a34a", edge_item.color);
    try std.testing.expectEqual(@as(f64, 4), edge_item.weight);
    try std.testing.expect(!edge_item.constraint);
    try std.testing.expectEqual(@as(usize, 2), edge_item.min_len);
    try std.testing.expectEqualStrings("#bbf7d0", attrValue(edge_item.attrs.items, "fillcolor").?);
    try std.testing.expectEqualStrings("#064e3b", attrValue(edge_item.attrs.items, "fontcolor").?);
    try std.testing.expectEqualStrings("Helvetica", attrValue(edge_item.attrs.items, "fontname").?);
    try std.testing.expectEqualStrings("16", attrValue(edge_item.attrs.items, "fontsize").?);
    try std.testing.expectEqualStrings("bold,dashed", attrValue(edge_item.attrs.items, "style").?);
    try std.testing.expectEqualStrings("3", attrValue(edge_item.attrs.items, "penwidth").?);
    try std.testing.expectEqualStrings("https://example.com/edge", attrValue(edge_item.attrs.items, "URL").?);
    try std.testing.expectEqualStrings("edge tip", attrValue(edge_item.attrs.items, "tooltip").?);
    try std.testing.expectEqualStrings("edge title", attrValue(edge_item.attrs.items, "title").?);
    try std.testing.expectEqualStrings("_self", attrValue(edge_item.attrs.items, "target").?);
    try std.testing.expectEqualStrings("vee", attrValue(edge_item.attrs.items, "arrowhead").?);
    try std.testing.expectEqualStrings("dot", attrValue(edge_item.attrs.items, "arrowtail").?);
    try std.testing.expectEqualStrings("1.75", attrValue(edge_item.attrs.items, "arrowsize").?);
    try std.testing.expectEqualStrings("both", attrValue(edge_item.attrs.items, "dir").?);
    try std.testing.expectEqualStrings("tail", attrValue(edge_item.attrs.items, "taillabel").?);
    try std.testing.expectEqualStrings("head", attrValue(edge_item.attrs.items, "headlabel").?);
    try std.testing.expectEqualStrings("xedge", attrValue(edge_item.attrs.items, "xlabel").?);
    try std.testing.expectEqualStrings("#14532d", attrValue(edge_item.attrs.items, "labelfontcolor").?);
    try std.testing.expectEqualStrings("Helvetica", attrValue(edge_item.attrs.items, "labelfontname").?);
    try std.testing.expectEqualStrings("11", attrValue(edge_item.attrs.items, "labelfontsize").?);
    try std.testing.expectEqualStrings("1.5", attrValue(edge_item.attrs.items, "labeldistance").?);
    try std.testing.expectEqualStrings("25", attrValue(edge_item.attrs.items, "labelangle").?);
    try std.testing.expectEqualStrings("true", attrValue(edge_item.attrs.items, "decorate").?);
    try std.testing.expectEqualStrings("false", attrValue(edge_item.attrs.items, "tailclip").?);
    try std.testing.expectEqualStrings("false", attrValue(edge_item.attrs.items, "headclip").?);
    try std.testing.expectEqualStrings("h", attrValue(edge_item.attrs.items, "samehead").?);
    try std.testing.expectEqualStrings("t", attrValue(edge_item.attrs.items, "sametail").?);
}

test "code API sets typed subgraph attrs" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "api" });
    defer graph.deinit();

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const subgraph = try graph.addSubgraph("cluster_api", null, &.{ a, b }, .{
        .label = "API",
        .rankdir = .LR,
        .layout = .sugiyama,
        .compound = true,
        .concentrate = true,
        .nodesep = 0.8,
        .ranksep = .{ .equally = 1.2 },
        .splines = .ortho,
        .bgcolor = "transparent",
        .ordering = .out,
        .color = "#2563eb",
        .pencolor = "#1d4ed8",
        .fillcolor = "#dbeafe",
        .gradientangle = 45,
        .styles = &.{ .filled, .rounded, .bold },
        .fontname = "Helvetica",
        .fontsize = 16,
        .fontcolor = "#1e3a8a",
        .penwidth = 2,
        .peripheries = 0,
        .margin = "0.25",
        .labelloc = .bottom,
        .labeljust = .left,
        .url = "https://example.com/subgraph",
        .href = "https://example.com/subgraph-href",
        .tooltip = "subgraph tip",
        .title = "subgraph title",
        .target = "_parent",
    });

    const item = graph.subgraphs.items[subgraph];
    try std.testing.expectEqualStrings("API", item.label);
    try std.testing.expectEqualStrings("LR", attrValue(item.attrs.items, "rankdir").?);
    try std.testing.expectEqualStrings("dot", attrValue(item.attrs.items, "layout").?);
    try std.testing.expectEqualStrings("true", attrValue(item.attrs.items, "compound").?);
    try std.testing.expectEqualStrings("true", attrValue(item.attrs.items, "concentrate").?);
    try std.testing.expectEqualStrings("0.8", attrValue(item.attrs.items, "nodesep").?);
    try std.testing.expectEqualStrings("1.2 equally", attrValue(item.attrs.items, "ranksep").?);
    try std.testing.expectEqualStrings("ortho", attrValue(item.attrs.items, "splines").?);
    try std.testing.expectEqualStrings("transparent", attrValue(item.attrs.items, "bgcolor").?);
    try std.testing.expectEqualStrings("out", attrValue(item.attrs.items, "ordering").?);
    try std.testing.expectEqualStrings("#2563eb", attrValue(item.attrs.items, "color").?);
    try std.testing.expectEqualStrings("#1d4ed8", attrValue(item.attrs.items, "pencolor").?);
    try std.testing.expectEqualStrings("#dbeafe", attrValue(item.attrs.items, "fillcolor").?);
    try std.testing.expectEqualStrings("45", attrValue(item.attrs.items, "gradientangle").?);
    try std.testing.expectEqualStrings("filled,rounded,bold", attrValue(item.attrs.items, "style").?);
    try std.testing.expectEqualStrings("Helvetica", attrValue(item.attrs.items, "fontname").?);
    try std.testing.expectEqualStrings("16", attrValue(item.attrs.items, "fontsize").?);
    try std.testing.expectEqualStrings("#1e3a8a", attrValue(item.attrs.items, "fontcolor").?);
    try std.testing.expectEqualStrings("2", attrValue(item.attrs.items, "penwidth").?);
    try std.testing.expectEqualStrings("0", attrValue(item.attrs.items, "peripheries").?);
    try std.testing.expectEqualStrings("0.25", attrValue(item.attrs.items, "margin").?);
    try std.testing.expectEqualStrings("b", attrValue(item.attrs.items, "labelloc").?);
    try std.testing.expectEqualStrings("l", attrValue(item.attrs.items, "labeljust").?);
    try std.testing.expectEqualStrings("https://example.com/subgraph", attrValue(item.attrs.items, "URL").?);
    try std.testing.expectEqualStrings("https://example.com/subgraph-href", attrValue(item.attrs.items, "href").?);
    try std.testing.expectEqualStrings("subgraph tip", attrValue(item.attrs.items, "tooltip").?);
    try std.testing.expectEqualStrings("subgraph title", attrValue(item.attrs.items, "title").?);
    try std.testing.expectEqualStrings("_parent", attrValue(item.attrs.items, "target").?);
}

test "Fruchterman-Reingold layout places nodes within bounds" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = false, .name = "force" });
    defer graph.deinit();
    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    _ = try graph.addEdge(a, b, .{});
    _ = try graph.addEdge(b, c, .{});

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
    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    _ = try graph.addEdge(a, b, .{});

    var layout = try layoutFruchtermanReingold(allocator, &graph, .{ .width = 360, .height = 260, .margin = 30, .iterations = 100 });
    defer layout.deinit();
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

test "layered layout honors graph margin attribute" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [margin="0.5,0.25"];
        \\  a -> b;
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    try std.testing.expectEqual(@as(f64, 36), layout.margin_x);
    try std.testing.expectEqual(@as(f64, 18), layout.margin_y);
    const a = nodeIdByLabel(&graph, "a");
    try std.testing.expect(layout.nodes[a].center.x >= layout.margin_x + layout.nodes[a].width / 2.0);
    try std.testing.expect(layout.nodes[a].center.y >= layout.margin_y + layout.nodes[a].height / 2.0);
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
    const start = graph.edges.items[0].from;
    const decision = graph.edges.items[0].to;
    const done = graph.edges.items[1].to;
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
    try std.testing.expect(maybeNodeIdByLabel(&graph, ".audit") == null);
    try std.testing.expect(maybeNodeIdByLabel(&graph, ".db-sync") == null);
    try std.testing.expect(maybeNodeIdByLabel(&graph, "svc.api") != null);
    try std.testing.expect(maybeNodeIdByLabel(&graph, "db.main") != null);

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

    try std.testing.expectEqual(@as(usize, 1), graph.subgraphs.items.len);
    try std.testing.expectEqualStrings("API Layer", graph.subgraphs.items[0].label);
    try std.testing.expectEqual(@as(usize, 2), graph.subgraphs.items[0].nodes.len);
    try std.testing.expectEqual(@as(usize, 2), graph.edges.items.len);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>API Layer</title>") != null);
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

    const b = graph.edges.items[0].to;
    try std.testing.expectEqualStrings("#0f0", attrValue(graph.nodes.items[b].attrs.items, "fillcolor").?);
    try std.testing.expectEqualStrings("#090", attrValue(graph.nodes.items[b].attrs.items, "color").?);
    try std.testing.expectEqualStrings("3", attrValue(graph.nodes.items[b].attrs.items, "penwidth").?);
    try std.testing.expectEqualStrings("#111", attrValue(graph.nodes.items[b].attrs.items, "fontcolor").?);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#0f0\" stroke=\"#090\" stroke-width=\"3\"") != null);
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

    const a = graph.edges.items[0].from;
    try std.testing.expectEqualStrings("#f00", attrValue(graph.nodes.items[a].attrs.items, "fillcolor").?);
    try std.testing.expectEqualStrings("#000", attrValue(graph.nodes.items[a].attrs.items, "color").?);
    try std.testing.expectEqualStrings("#fff", attrValue(graph.nodes.items[a].attrs.items, "fontcolor").?);
    try std.testing.expectEqualStrings("2", attrValue(graph.nodes.items[a].attrs.items, "penwidth").?);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#f00\" stroke=\"#000\" stroke-width=\"2\"") != null);
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

    const a = graph.edges.items[0].from;
    try std.testing.expectEqualStrings("#f00", attrValue(graph.nodes.items[a].attrs.items, "fillcolor").?);
    try std.testing.expectEqualStrings("#000", attrValue(graph.nodes.items[a].attrs.items, "color").?);
    try std.testing.expectEqualStrings("#fff", attrValue(graph.nodes.items[a].attrs.items, "fontcolor").?);

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#f00\" stroke=\"#000\" stroke-width=\"2\"") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "\" stroke-width=\"4\" stroke-dasharray=\"8,5\"") != null);
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
}

test "SVG renderer emits graph stylesheet processing instruction" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .stylesheet = "theme&print.css" });
    const a = try graph.addNode("A", .{});
    const b = try graph.addNode("B", .{});
    _ = try graph.addEdge(a, b, .{});

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.startsWith(u8, svg, "<?xml-stylesheet href=\"theme&amp;print.css\" type=\"text/css\"?>\n<svg"));

    var parsed = try parseDot(allocator,
        \\digraph G {
        \\  graph [stylesheet="screen.css"];
        \\  a -> b;
        \\}
    );
    defer parsed.deinit();
    var parsed_layout = try layoutLayered(allocator, &parsed, .{});
    defer parsed_layout.deinit();
    const parsed_svg = try renderSvgAlloc(allocator, &parsed, &parsed_layout, .{});
    defer allocator.free(parsed_svg);

    try std.testing.expect(std.mem.startsWith(u8, parsed_svg, "<?xml-stylesheet href=\"screen.css\" type=\"text/css\"?>\n<svg"));
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
    try std.testing.expectApproxEqAbs(@as(f64, -357.01), svgClusterRectY(svg, "cluster_0").?, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 292.8), svgClusterRectHeight(svg, "cluster_0").?, 0.001);
    try std.testing.expectEqual(@as(f64, 12.0), svgClusterScreenX(svg, "cluster_0").?);
    try std.testing.expectApproxEqAbs(@as(f64, 48.0), svgClusterScreenY(svg, "cluster_0").?, 0.001);
    try std.testing.expectEqual(@as(f64, 67.0), svgNodeScreenCenterX(svg, "a0").?);
    try std.testing.expectApproxEqAbs(@as(f64, 98.8), svgNodeScreenCenterY(svg, "a0").?, 0.001);
}

test "DOT parser supports subgraphs, ports, escaped strings, and angle strings" {
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
    const a = nodeIdByLabel(&graph, "a");
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
    const a = nodeIdByLabel(&lr, "a");
    const b = nodeIdByLabel(&lr, "b");

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
    const top = nodeIdByLabel(&lr, "top");
    const bottom = nodeIdByLabel(&lr, "bottom");
    const sink = nodeIdByLabel(&lr, "sink");

    try std.testing.expectEqual(RankDir.LR, layout.rankdir);
    try std.testing.expect(@abs(layout.nodes[top].center.x - layout.nodes[bottom].center.x) <= 0.01);
    try std.testing.expect(layout.nodes[sink].center.x > layout.nodes[top].center.x);
    try std.testing.expect(@abs(layout.nodes[bottom].center.y - layout.nodes[top].center.y) >= 80.0);
    try std.testing.expect(layout.height <= defaultClusterAlongExtentBudget);
}

fn expectRankDirection(graph: *const Graph, layout: *const Layout, rankdir: RankDir) !void {
    const a = nodeIdByLabel(graph, "a");
    const b = nodeIdByLabel(graph, "b");
    const c = nodeIdByLabel(graph, "c");
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

test "render helper emits SVG and escapes labels" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "dispatch", .rankdir = .LR });
    defer graph.deinit();
    const left = try graph.addNode("left", .{});
    const right = try graph.addNode("right", .{});
    _ = try graph.addEdge(left, right, .{ .label = "go", .color = "#16a34a" });
    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const svg = try renderLayoutAlloc(allocator, &graph, &layout, .svg, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"#16a34a\" stroke=\"#16a34a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "go") != null);

    try graph.setNodeAttr(left, .{ .label = "<&>" });
    var escaped_layout = try layoutLayered(allocator, &graph, .{});
    defer escaped_layout.deinit();
    const escaped_svg = try renderLayoutAlloc(allocator, &graph, &escaped_layout, .svg, .{});
    defer allocator.free(escaped_svg);
    try std.testing.expect(std.mem.indexOf(u8, escaped_svg, "&lt;&amp;&gt;") != null);
}

test "Layout owns render graph snapshot" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "scene", .rankdir = .LR });
    defer graph.deinit();
    const a = try graph.addNode("Original", .{ .shape = .box });
    const b = try graph.addNode("Target", .{ .shape = .box });
    _ = try graph.addEdge(a, b, .{ .label = "edge" });

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    try graph.setNodeAttr(a, .{ .label = "Mutated" });
    const svg = try renderAlloc(allocator, &layout, .svg, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Original") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Mutated") == null);
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
    const a = nodeIdByLabel(&graph, "a");
    var found_default_shape = false;
    for (graph.nodes.items[a].attrs.items) |attr| {
        if (std.mem.eql(u8, attr.name, "shape") and std.mem.eql(u8, attr.value, "box")) found_default_shape = true;
    }
    try std.testing.expect(found_default_shape);
    const quoted = nodeIdByLabel(&graph, "quoted id");
    var found_tooltip = false;
    for (graph.nodes.items[quoted].attrs.items) |attr| {
        if (std.mem.eql(u8, attr.name, "tooltip") and std.mem.eql(u8, attr.value, "true")) found_tooltip = true;
    }
    try std.testing.expect(found_tooltip);
    const esc = nodeIdByLabel(&graph, "esc");
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

    const node_a = nodeIdByLabel(&graph, "node_a");
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

    const a = nodeIdByLabel(&graph, "A");
    const b = nodeIdByLabel(&graph, "B");
    const c = nodeIdByLabel(&graph, "C");
    const d = nodeIdByLabel(&graph, "D");
    try std.testing.expect(layout.nodes[a].center.x < layout.nodes[b].center.x);
    try std.testing.expect(layout.nodes[d].center.x < layout.nodes[c].center.x);

    const wide = nodeIdByLabel(&graph, "wide");
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

    const a = nodeIdByLabel(&graph, "A");
    const b = nodeIdByLabel(&graph, "B");
    const c = nodeIdByLabel(&graph, "C");
    const d = nodeIdByLabel(&graph, "D");
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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const x = try graph.addNode("x", .{});
    const y = try graph.addNode("y", .{});
    const z = try graph.addNode("z", .{});
    _ = try graph.addEdge(a, x, .{});
    _ = try graph.addEdge(b, y, .{});
    _ = try graph.addEdge(c, z, .{});

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

    const p0 = try graph.addNode("p0", .{});
    const p1 = try graph.addNode("p1", .{});
    const x = try graph.addNode("x", .{});
    const y = try graph.addNode("y", .{});
    const z = try graph.addNode("z", .{});
    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    _ = try graph.addEdge(p0, z, .{});
    _ = try graph.addEdge(p1, x, .{});
    _ = try graph.addEdge(x, a, .{});
    _ = try graph.addEdge(y, b, .{});
    _ = try graph.addEdge(z, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    const e = try graph.addNode("e", .{});
    _ = try graph.addEdge(a, e, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    const e = try graph.addNode("e", .{});
    const f = try graph.addNode("f", .{});
    _ = try graph.addEdge(a, f, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    _ = try graph.addEdge(a, d, .{ .weight = 4 });

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const side = try graph.addNode("side", .{});
    _ = try graph.addEdge(a, b, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const parent = try graph.addNode("parent", .{});
    const left = try graph.addNode("left", .{});
    const right = try graph.addNode("right", .{});
    _ = try graph.addEdge(parent, left, .{});
    _ = try graph.addEdge(parent, right, .{});

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

    const p = try graph.addNode("p", .{});
    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    _ = try graph.addEdge(p, a, .{ .weight = 4 });
    _ = try graph.addEdge(p, b, .{ .weight = 4 });

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

    const p0 = try graph.addNode("p0", .{});
    const p1 = try graph.addNode("p1", .{});
    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    _ = try graph.addEdge(p0, a, .{ .weight = 1 });
    _ = try graph.addEdge(p1, b, .{ .weight = 1 });

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

    const left = try graph.addNode("left", .{});
    const right = try graph.addNode("right", .{});
    const child = try graph.addNode("child", .{});
    _ = try graph.addEdge(left, child, .{ .weight = 1 });
    _ = try graph.addEdge(right, child, .{ .weight = 8 });

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    _ = try graph.addEdge(a, b, .{ .weight = 4 });

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
    const angle_text = displayLabelEstimatedWidth("<B>ii</B> <I>mm</I>", 14.0);

    try std.testing.expect(narrow < digits);
    try std.testing.expect(digits < wide);
    try std.testing.expect(angle_text > wide);
}

test "guarded symmetric compaction rejects wider or higher-stress changes" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const p = try graph.addNode("p", .{});
    _ = try graph.addEdge(p, b, .{ .weight = 5 });

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    _ = try graph.addEdge(a, d, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    _ = try graph.addEdge(a, d, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    _ = try graph.addEdge(a, d, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const top_a = try graph.addNode("top_a", .{});
    const top_b = try graph.addNode("top_b", .{});
    const a = try graph.addNode("a", .{});
    const outside = try graph.addNode("outside", .{});
    const b = try graph.addNode("b", .{});
    _ = try graph.addEdge(top_a, a, .{});
    _ = try graph.addEdge(top_b, b, .{});
    _ = try graph.addSubgraph("cluster_pair", null, &.{ a, b }, .{});

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

    const top_a = try graph.addNode("top_a", .{});
    const top_b = try graph.addNode("top_b", .{});
    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    _ = try graph.addEdge(top_a, a, .{});
    _ = try graph.addEdge(top_b, b, .{});
    _ = try graph.addSubgraph("cluster_pair", null, &.{ a, b }, .{});

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

    const left = try graph.addNode("left", .{});
    const mid = try graph.addNode("mid", .{});
    const right = try graph.addNode("right", .{});
    const child = try graph.addNode("child", .{});
    _ = try graph.addEdge(left, child, .{ .weight = 1 });
    _ = try graph.addEdge(right, child, .{ .weight = 9 });

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const outside = try graph.addNode("outside", .{});
    _ = try graph.addEdge(a, b, .{});
    _ = try graph.addEdge(outside, b, .{});
    _ = try graph.addSubgraph("cluster_pair", null, &.{ a, b }, .{});

    try std.testing.expectEqual(virtualBlockKey(&graph, .{ .real = a }), virtualBlockKey(&graph, .{ .real = b }));
    try std.testing.expect(virtualBlockKey(&graph, .{ .real = outside }) != virtualBlockKey(&graph, .{ .real = a }));
    try std.testing.expect(virtualBlockKey(&graph, .{ .dummy = 1 }) != virtualBlockKey(&graph, .{ .real = outside }));
}

test "cross-cluster long-edge dummies attach to nearest endpoint block" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    const tail = try graph.addSubgraph("cluster_tail", null, &.{a}, .{});
    const head = try graph.addSubgraph("cluster_head", null, &.{d}, .{});
    const edge_id = try graph.addEdge(a, d, .{ .ltail = tail, .lhead = head });

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    const edge_id = try graph.addEdge(a, d, .{});
    _ = try graph.addSubgraph("cluster_tail", null, &.{a}, .{});
    _ = try graph.addSubgraph("cluster_head", null, &.{d}, .{});

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

    const top_a = try graph.addNode("top_a", .{});
    const top_b = try graph.addNode("top_b", .{});
    const a = try graph.addNode("a", .{});
    const outside = try graph.addNode("outside", .{});
    const b = try graph.addNode("b", .{});
    _ = try graph.addEdge(top_a, a, .{});
    _ = try graph.addEdge(top_b, b, .{});
    _ = try graph.addSubgraph("cluster_pair", null, &.{ a, b }, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    const e = try graph.addNode("e", .{});
    const f = try graph.addNode("f", .{});
    _ = try graph.addEdge(a, f, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    _ = try graph.addEdge(a, d, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    _ = try graph.addEdge(a, d, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    _ = try graph.addEdge(a, d, .{});
    _ = try graph.addEdge(b, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    _ = try graph.addEdge(a, c, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    _ = try graph.addEdge(a, b, .{});

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
    for (layout.subgraphs) |cluster_box| cluster_right = @max(cluster_right, cluster_box.x + cluster_box.width);

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
    const a0 = nodeIdByLabel(&graph, "a0");
    const cluster = layout.subgraphs[0];

    try std.testing.expect(cluster.x <= 1.0);
    try std.testing.expect(layout.nodes[a0].center.x - cluster.x >= 46.0);
}

test "rankdir LR back-edge channel expands cluster along y axis" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .rankdir = .LR });
    defer graph.deinit();

    const a0 = try graph.addNode("a0", .{});
    const a3 = try graph.addNode("a3", .{});
    _ = try graph.addEdge(a3, a0, .{});
    _ = try graph.addSubgraph("cluster_loop", null, &.{ a0, a3 }, .{});

    const nodes = [_]NodeLayout{
        .{ .center = .{ .x = 40, .y = 50 }, .width = 54, .height = 36 },
        .{ .center = .{ .x = 220, .y = 50 }, .width = 54, .height = 36 },
    };
    var clusters = [_]SubgraphLayout{.{ .id = 0, .x = 10, .y = 32, .width = 250, .height = 42 }};

    expandSubgraphLayoutsForBackEdges(&graph, LayoutAxes.init(.LR), nodes[0..], clusters[0..]);

    try std.testing.expect(clusters[0].y < 32.0);
    try std.testing.expect(clusters[0].height > 42.0);
}

test "virtual position compaction honors node gap" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    _ = try graph.addEdge(a, b, .{});

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

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    _ = try graph.addEdge(a, b, .{});

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

    const grouped = try graph.addNode("grouped", .{});
    const plain = try graph.addNode("plain", .{});
    try graph.setNodeAttr(grouped, .{ .group = "main" });

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

    const right = nodeIdByLabel(&graph, "right");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-dasharray=\"8,5\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-dasharray=\"2,5\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"4\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-0-head)\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "loop") != null);

    const first_offset = parallelEdgeOffset(&graph, 0);
    const second_offset = parallelEdgeOffset(&graph, 1);
    try std.testing.expect(first_offset < 0);
    try std.testing.expect(second_offset > 0);
}

test "SVG renderer uses typed node and edge style lists" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.addNode("a", .{
        .shape = .box,
        .fillcolor = "#dbeafe",
        .color = "#1d4ed8",
        .styles = &.{ .filled, .rounded, .dashed },
    });
    const b = try graph.addNode("b", .{ .shape = .box });
    _ = try graph.addEdge(a, b, .{
        .color = "#dc2626",
        .styles = &.{ .bold, .dotted },
    });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#dbeafe\" stroke=\"#1d4ed8\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "rx=\"10\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-dasharray=\"8,5\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"#dc2626\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-dasharray=\"2,5\"") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\"") != null);
}

test "SVG renderer uses typed node peripheries attribute" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    _ = try graph.addNode("a", .{ .shape = .box, .peripheries = 3 });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expectEqualStrings("3", attrValue(graph.nodes.items[0].attrs.items, "peripheries").?);
    try std.testing.expect(countSubstrings(svg, "<rect") >= 3);
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

test "SVG renderer uses typed gradientangle attributes" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .rankdir = .LR });
    defer graph.deinit();

    const a = try graph.addNode("linear", .{
        .shape = .box,
        .style = .filled,
        .fillcolor = "yellow;0.5:blue",
        .gradientangle = 45,
    });
    const b = try graph.addNode("clustered", .{ .shape = .box });
    _ = try graph.addEdge(a, b, .{});
    _ = try graph.addSubgraph("cluster_gradient", null, &.{b}, .{
        .label = "gradient",
        .styles = &.{ .filled, .radial },
        .fillcolor = "white:#2563eb",
        .gradientangle = 90,
    });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<linearGradient id=\"vex-node-fill-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<radialGradient id=\"vex-cluster-fill-1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fx=\"50%\" fy=\"0%\"") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, explicit_svg, "stroke-width=\"3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, explicit_svg, "stroke-width=\"4\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, explicit_svg, "stroke-width=\"2\"") != null);
}

test "SVG renderer treats angle string labels as plain text" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  angle [label=< <B>Title</B><BR/>A &amp; B >, shape=box];
        \\  plain [label="<&>"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "&lt;B&gt;Title&lt;/B&gt;&lt;BR/&gt;A &amp;amp; B") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-weight=\"bold\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<BR/>") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "&lt;&amp;&gt;") != null);
}

test "angle string table syntax does not create table cells or ports" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  angle [shape=plain,label=<
        \\    <TABLE CELLBORDER="1" CELLSPACING="2" CELLPADDING="4">
        \\      <TR><TD PORT="left">L</TD><TD PORT="right">R</TD></TR>
        \\    </TABLE>
        \\  >];
        \\  target [shape=box];
        \\  angle:right:e -> target:w;
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqualStrings("right", graph.edges.items[0].tail_record_port.?);
    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const angle = nodeIdByLabel(&graph, "angle");
    const route = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], layout.rankdir, 0);
    try std.testing.expectApproxEqAbs(layout.nodes[angle].center.x + layout.nodes[angle].width / 2.0, route.start.x, 0.001);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "&lt;TABLE") != null);
    try std.testing.expectEqual(@as(usize, 1), countSubstrings(svg, "<rect"));
}

test "SVG renderer honors graph label and bgcolor attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph InternalName {
        \\  graph [label="Visible Title", bgcolor=lightgrey, URL="https://example.com/graph", tooltip="Graph tip", target="_top"];
        \\  a -> b;
        \\}
    );
    defer graph.deinit();
    try graph.setGraphAttr(.{ .href = "https://example.com/graph-href" });
    try graph.setGraphAttr(.{ .title = "Graph title" });
    try graph.setGraphAttr(.{ .pad = "0.25" });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expectEqualStrings("https://example.com/graph-href", attrValue(graph.attrs.items, "href").?);
    try std.testing.expectEqualStrings("Graph title", attrValue(graph.attrs.items, "title").?);
    try std.testing.expectEqualStrings("0.25", attrValue(graph.attrs.items, "pad").?);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"lightgrey\" stroke=\"none\" points=\"0,0 0,") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "Visible Title") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/graph-href\" target=\"_top\"><title>Graph tip</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">InternalName</text>") == null);
    try std.testing.expect(layout.margin_y >= 26.0);
}

test "SVG renderer honors graph pad attribute in canvas bounds" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .rankdir = .TB });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .pad = "0.5" });

    const a = try graph.addNode("A", .{ .xlabel = "external node label" });
    const b = try graph.addNode("B", .{});
    _ = try graph.addEdge(a, b, .{
        .label = "edge",
        .xlabel = "large external edge label",
        .labelfontsize = 22,
    });

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const raw_bounds = svgGraphContentBounds(&graph, &layout) orelse return error.MissingSvgBounds;
    try std.testing.expect(raw_bounds.x + raw_bounds.width > layout.width);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    const view_box = svgViewBox(svg) orelse return error.MissingViewBox;
    try std.testing.expect(view_box.width >= raw_bounds.x + raw_bounds.width + 36.0 - 0.01);
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

    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"graph0\" class=\"graph\" transform=\"scale(1 1) rotate(0) translate(0 0)\">") != null);
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
    var expected_x_value_buf: [32]u8 = undefined;
    const expected_x_value = try svgNumberForTest(&expected_x_value_buf, layout.width - 16.0);
    var expected_x_buf: [64]u8 = undefined;
    const expected_x = try std.fmt.bufPrint(&expected_x_buf, "x=\"{s}\"", .{expected_x_value});
    var expected_y_value_buf: [32]u8 = undefined;
    const expected_y_value = try svgNumberForTest(&expected_y_value_buf, layout.height - 16.0);
    var expected_y_buf: [64]u8 = undefined;
    const expected_y = try std.fmt.bufPrint(&expected_y_buf, "y=\"{s}\"", .{expected_y_value});
    try std.testing.expect(std.mem.indexOf(u8, svg, expected_x) != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, expected_y) != null);
    try std.testing.expect(layout.margin_y >= 26.0);
    const b = nodeIdByLabel(&graph, "b");
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

    const top_left = nodeIdByLabel(&graph, "top_left");
    const plain = nodeIdByLabel(&graph, "plain");
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
        \\  subgraph cluster_api {
        \\    label="API";
        \\    URL="https://example.com/cluster";
        \\    tooltip="Cluster API";
        \\    target="_parent";
        \\    c;
        \\  }
        \\  a [URL="https://example.com/a", tooltip="Node A", target="_blank"];
        \\  b;
        \\  a -> b [href="https://example.com/e", tooltip="Edge A to B", target="_self"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/a\" target=\"_blank\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>Node A</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/e\" target=\"_self\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>Edge A to B</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/cluster\" target=\"_parent\"><title>Cluster API</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>API</title>\n<a href=\"https://example.com/cluster\" target=\"_parent\">") != null);
}

test "SVG renderer uses labels as URL tooltip fallback" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [label="Graph Label", URL="https://example.com/graph"];
        \\  subgraph cluster_api {
        \\    label="API";
        \\    URL="https://example.com/cluster";
        \\    a;
        \\  }
        \\  a [URL="https://example.com/a"];
        \\  b;
        \\  a -> b [URL="https://example.com/e", label="edge label", xlabel="external", headlabel="head", taillabel="tail"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/graph\"><title>Graph Label</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/a\"><title>a</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/cluster\"><title>API</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/e\"><title>edge label</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/e\"><title>external</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/e\"><title>head</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/e\"><title>tail</title>") != null);
}

test "SVG renderer expands URL escape sequences with object context" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph GraphName {
        \\  graph [URL="https://example.com/\G", tooltip="graph \G", target="frame-\G"];
        \\  subgraph cluster_api {
        \\    label="API";
        \\    URL="https://example.com/cluster/\N/\G";
        \\    tooltip="cluster \N \G";
        \\    target="cluster-\N";
        \\    a;
        \\  }
        \\  a [URL="https://example.com/node/\N/\G", tooltip="node \N \G", target="node-\N"];
        \\  b;
        \\  a -> b [
        \\    URL="https://example.com/edge/\N/\E/\T/\H/\G",
        \\    labelURL="https://example.com/label/\N/\E",
        \\    headURL="https://example.com/head/\N/\E",
        \\    tailURL="https://example.com/tail/\N/\E",
        \\    tooltip="edge \E \T \H \G",
        \\    target="edge-\E",
        \\    label="go",
        \\    headlabel="head",
        \\    taillabel="tail"
        \\  ];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/GraphName\" target=\"frame-GraphName\"><title>graph GraphName</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/node/a/GraphName\" target=\"node-a\"><title>node a GraphName</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/cluster/API/GraphName\" target=\"cluster-API\"><title>cluster API GraphName</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/edge/a-&gt;b/a-&gt;b/a/b/GraphName\" target=\"edge-a-&gt;b\"><title>edge a-&gt;b a b GraphName</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/label/go/a-&gt;b\" target=\"edge-a-&gt;b\"><title>edge a-&gt;b a b GraphName</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/head/head/a-&gt;b\" target=\"edge-a-&gt;b\"><title>edge a-&gt;b a b GraphName</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/tail/tail/a-&gt;b\" target=\"edge-a-&gt;b\"><title>edge a-&gt;b a b GraphName</title>") != null);
}

test "SVG renderer honors typed id and class metadata" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "meta" });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .id = "graph-custom" });
    try graph.setGraphAttr(.{ .class = "diagram primary" });

    const a = try graph.addNode("A", .{ .id = "node-a", .class = "entry highlighted" });
    const b = try graph.addNode("B", .{});
    _ = try graph.addEdge(a, b, .{ .id = "edge-a-b", .class = "critical flow" });
    _ = try graph.addSubgraph("Group", null, &.{a}, .{ .id = "cluster-custom", .class = "lane hot" });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"graph-custom\" class=\"graph diagram primary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"node-a\" class=\"node entry highlighted\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"edge-a-b\" class=\"edge critical flow\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"cluster-custom\" class=\"cluster lane hot\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"node2\" class=\"node\">") != null);
}

test "SVG renderer honors graph node and edge comment metadata" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "comments" });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .comment = "graph-comment" });

    const a = try graph.addNode("A", .{ .comment = "node-comment" });
    const b = try graph.addNode("B", .{});
    _ = try graph.addEdge(a, b, .{ .comment = "edge-a->b" });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<!-- graph&#45;comment -->") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<!-- node&#45;comment -->") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<!-- edge&#45;a&#45;&gt;b -->") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<!-- A -->") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<!-- A&#45;&gt;B -->") == null);

    var parsed = try parseDot(allocator,
        \\digraph G {
        \\  graph [comment="graph raw"];
        \\  a [comment="node raw"];
        \\  a -> b [comment="edge raw"];
        \\}
    );
    defer parsed.deinit();
    var parsed_layout = try layoutLayered(allocator, &parsed, .{});
    defer parsed_layout.deinit();
    const parsed_svg = try renderSvgAlloc(allocator, &parsed, &parsed_layout, .{});
    defer allocator.free(parsed_svg);

    try std.testing.expect(std.mem.indexOf(u8, parsed_svg, "<!-- graph raw -->") != null);
    try std.testing.expect(std.mem.indexOf(u8, parsed_svg, "<!-- node raw -->") != null);
    try std.testing.expect(std.mem.indexOf(u8, parsed_svg, "<!-- edge raw -->") != null);
}

test "SVG renderer honors edge label URL tooltip target metadata" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const a = try graph.addNode("A", .{});
    const b = try graph.addNode("B", .{});
    _ = try graph.addEdge(a, b, .{
        .label = "main",
        .xlabel = "external",
        .headlabel = "head",
        .taillabel = "tail",
        .edge_url = "https://example.com/edge",
        .edge_tooltip = "Edge path",
        .edge_target = "_self",
        .label_url = "https://example.com/label",
        .label_tooltip = "Main label",
        .label_target = "_blank",
        .head_url = "https://example.com/head",
        .head_tooltip = "Head label",
        .head_target = "_parent",
        .tail_url = "https://example.com/tail",
        .tail_tooltip = "Tail label",
        .tail_target = "_top",
    });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/edge\" target=\"_self\"><title>Edge path</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/label\" target=\"_blank\"><title>Main label</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/head\" target=\"_parent\"><title>Head label</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<a href=\"https://example.com/tail\" target=\"_top\"><title>Tail label</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">main</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">external</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">head</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">tail</tspan>") != null);

    var inherited = try Graph.init(allocator, .{ .directed = true });
    defer inherited.deinit();
    const ia = try inherited.addNode("A", .{});
    const ib = try inherited.addNode("B", .{});
    _ = try inherited.addEdge(ia, ib, .{
        .label = "main",
        .xlabel = "external",
        .headlabel = "head",
        .taillabel = "tail",
        .edge_url = "https://example.com/inherited",
        .edge_tooltip = "Inherited edge",
        .edge_target = "_self",
    });
    var inherited_layout = try layoutLayered(allocator, &inherited, .{});
    defer inherited_layout.deinit();
    const inherited_svg = try renderSvgAlloc(allocator, &inherited, &inherited_layout, .{});
    defer allocator.free(inherited_svg);

    try std.testing.expect(countSubstrings(inherited_svg, "<a href=\"https://example.com/inherited\" target=\"_self\"><title>Inherited edge</title>") >= 5);
    try std.testing.expect(std.mem.indexOf(u8, inherited_svg, ">main</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, inherited_svg, ">external</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, inherited_svg, ">head</tspan>") != null);
    try std.testing.expect(std.mem.indexOf(u8, inherited_svg, ">tail</tspan>") != null);
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
        \\  subgraph cluster_c { label="Subgraph"; c; }
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
        \\  subgraph cluster_c { label="Subgraph"; c; }
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
        \\  subgraph cluster_c { label="Subgraph"; c; }
        \\  a -> b [label="edge"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.00\">Subgraph") != null);
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
        \\    color="#2563eb"
        \\  ];
        \\}
    );
    defer graph.deinit();
    try graph.setEdgeAttr(0, .{ .decorate = true });

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
    const a = nodeIdByLabel(&graph, "a");
    const small = nodeIdByLabel(&graph, "small");
    try std.testing.expect(layout.nodes[a].height > layout.nodes[small].height);
}

test "SVG renderer uses typed node and edge font attributes" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .rankdir = .LR });
    defer graph.deinit();

    const a = try graph.addNode("A", .{
        .shape = .box,
        .fontname = "Courier",
        .fontsize = 22,
    });
    const b = try graph.addNode("B", .{ .shape = .box });
    _ = try graph.addEdge(a, b, .{
        .label = "edge",
        .fontname = "Times",
        .fontsize = 16,
    });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Courier\" font-size=\"22.00\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Times\" font-size=\"16.00\"") != null);
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

test "SVG renderer honors edge fillcolor for filled arrow shapes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  graph [rankdir=LR];
        \\  a -> b [color="#2563eb", fillcolor="#bfdbfe"];
        \\  b -> c [dir=both, arrowtail=dot, arrowhead=box, color="#dc2626", fillcolor="#fecaca"];
        \\  c -> d [arrowhead=diamond, color="#16a34a", fillcolor="#bbf7d0"];
        \\  d -> e [arrowhead=vee, color="#9333ea", fillcolor="#e9d5ff"];
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#bfdbfe\" stroke=\"#2563eb\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<circle cx=\"5\" cy=\"5\" r=\"4\" fill=\"#fecaca\" stroke=\"#dc2626\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<rect x=\"1.5\" y=\"1.5\" width=\"7\" height=\"7\" fill=\"#fecaca\" stroke=\"#dc2626\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "M 5 0.8 L 9.2 5 L 5 9.2 L 0.8 5 z\" fill=\"#bbf7d0\" stroke=\"#16a34a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "M 1 1 L 9 5 L 1 9\" fill=\"none\" stroke=\"#9333ea\"") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "<circle cx=\"5\" cy=\"5\" r=\"4\" fill=\"blue\" stroke=\"blue\"") != null);
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
        \\  b -> c [color="#16a34a"];
        \\}
    );
    defer graph.deinit();
    try graph.setEdgeAttr(2, .{ .tailclip = false });
    try graph.setEdgeAttr(2, .{ .headclip = false });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"#2563eb\" stroke=\"#2563eb\" points=") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "arrow-0-head") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "arrow-1-head") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-1-head)\"") == null);

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const clipped = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], layout.rankdir, 0);
    try std.testing.expect(clipped.start.x > layout.nodes[a].center.x);
    try std.testing.expect(clipped.end.x < layout.nodes[b].center.x);

    const unclipped = edgeRouteForEdge(&graph, &layout, graph.edges.items[2], layout.rankdir, 0);
    try std.testing.expectEqual(layout.nodes[b].center.x, unclipped.start.x);
    try std.testing.expectEqual(layout.nodes[b].center.y, unclipped.start.y);
    try std.testing.expectEqual(layout.nodes[c].center.x, unclipped.end.x);
    try std.testing.expectEqual(layout.nodes[c].center.y, unclipped.end.y);
}

test "SVG renderer uses typed edge arrowsize attribute" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .rankdir = .LR });
    defer graph.deinit();

    const a = try graph.addNode("a", .{ .shape = .box });
    const b = try graph.addNode("b", .{ .shape = .box });
    _ = try graph.addEdge(a, b, .{
        .color = "#2563eb",
        .arrowhead = .vee,
        .arrowsize = 2.0,
    });

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expectEqualStrings("2", attrValue(graph.edges.items[0].attrs.items, "arrowsize").?);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"#2563eb\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "markerWidth=\"14.00\" markerHeight=\"14.00\"") != null);
    const route = edgeRouteForEdge(&graph, &layout, graph.edges.items[0], layout.rankdir, 0);
    try std.testing.expect(route.end.x < layout.nodes[b].center.x);
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

    const a = nodeIdByLabel(&graph, "a");
    const c = nodeIdByLabel(&graph, "c");
    const e = nodeIdByLabel(&graph, "e");
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

    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
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

    const source = nodeIdByLabel(&graph, "source");
    const review = nodeIdByLabel(&graph, "review");
    const approve = nodeIdByLabel(&graph, "approve");
    const archive = nodeIdByLabel(&graph, "archive");
    const free = nodeIdByLabel(&graph, "free");

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

    const a0 = nodeIdByLabel(&graph, "a0");
    const a1 = nodeIdByLabel(&graph, "a1");
    const a2 = nodeIdByLabel(&graph, "a2");
    const a3 = nodeIdByLabel(&graph, "a3");
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

    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
    const x = nodeIdByLabel(&graph, "x");
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

    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
    const x = nodeIdByLabel(&graph, "x");
    const y = nodeIdByLabel(&graph, "y");
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

    const x = nodeIdByLabel(&graph, "x");
    const y = nodeIdByLabel(&graph, "y");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const x = nodeIdByLabel(&graph, "x");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
    const e = nodeIdByLabel(&graph, "e");
    const f = nodeIdByLabel(&graph, "f");
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

    const root = nodeIdByLabel(&graph, "root");
    const left = nodeIdByLabel(&graph, "left");
    const right = nodeIdByLabel(&graph, "right");
    const leaf = nodeIdByLabel(&graph, "leaf");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const x = nodeIdByLabel(&graph, "x");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const x = nodeIdByLabel(&graph, "x");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const x = nodeIdByLabel(&graph, "x");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const source = nodeIdByLabel(&graph, "source");
    const x = nodeIdByLabel(&graph, "x");
    const y = nodeIdByLabel(&graph, "y");
    const mid = nodeIdByLabel(&graph, "mid");
    const sink = nodeIdByLabel(&graph, "sink");
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

    const source = nodeIdByLabel(&graph, "source");
    const x = nodeIdByLabel(&graph, "x");
    const y = nodeIdByLabel(&graph, "y");
    const mid = nodeIdByLabel(&graph, "mid");
    const sink = nodeIdByLabel(&graph, "sink");
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

    const a = nodeIdByLabel(&graph, "a");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const source = nodeIdByLabel(&graph, "source");
    const x = nodeIdByLabel(&graph, "x");
    const sink = nodeIdByLabel(&graph, "sink");
    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
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

    const source = nodeIdByLabel(&graph, "source");
    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const sink = nodeIdByLabel(&graph, "sink");
    const x = nodeIdByLabel(&graph, "x");
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

    const source = nodeIdByLabel(&graph, "source");
    const x = nodeIdByLabel(&graph, "x");
    const sink = nodeIdByLabel(&graph, "sink");
    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
    const x = nodeIdByLabel(&graph, "x");
    const y = nodeIdByLabel(&graph, "y");
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

    const source = nodeIdByLabel(&graph, "source");
    const mid = nodeIdByLabel(&graph, "mid");
    const sink = nodeIdByLabel(&graph, "sink");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
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

    const a = nodeIdByLabel(&graph, "a");
    const d = nodeIdByLabel(&graph, "d");
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
        .graph = try Graph.init(allocator, .{ .directed = true }),
        .rankdir = .TB,
        .nodes = try allocator.alloc(NodeLayout, 3),
        .subgraphs = try allocator.alloc(SubgraphLayout, 0),
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
    try writeEdgePath(&aw.writer, &layout, edge_item, layout.rankdir, 0, route, .curved, .{}, .{});
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
    const side_x = path_numbers[12];
    try std.testing.expect(path_numbers[2] > path_numbers[4]);
    try std.testing.expect(path_numbers[4] > path_numbers[6]);
    try std.testing.expectEqual(side_x, path_numbers[6]);
    try std.testing.expect(path_numbers[8] < side_x);
    try std.testing.expectEqual(path_numbers[8], path_numbers[10]);
    try std.testing.expect(path_numbers[2] > side_x);
    try std.testing.expect(path_numbers[4] > side_x);
    try std.testing.expect(path_numbers[14] > side_x);
    try std.testing.expect(path_numbers[18] > path_numbers[16]);
    try std.testing.expect(path_numbers[16] > path_numbers[14]);
}

test "back-edge side channel prefers stable negative side for same column" {
    const allocator = std.testing.allocator;
    var layout = Layout{
        .allocator = allocator,
        .graph = try Graph.init(allocator, .{ .directed = true }),
        .rankdir = .TB,
        .nodes = try allocator.alloc(NodeLayout, 2),
        .subgraphs = try allocator.alloc(SubgraphLayout, 0),
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

fn subgraphIndexByLabel(graph: *const Graph, label: []const u8) ?SubgraphId {
    for (graph.subgraphs.items, 0..) |subgraph, index| {
        if (std.mem.eql(u8, subgraph.label, label)) return index;
    }
    return null;
}

fn expectLayoutNodeClusterPaddingNear(graph: *const Graph, layout: *const Layout, cluster_label: []const u8, node_id: NodeId, expected_padding: f64, tolerance: f64) !void {
    const cluster_index = subgraphIndexByLabel(graph, cluster_label) orelse return error.MissingClusterRect;
    if (cluster_index >= layout.subgraphs.len or node_id >= layout.nodes.len) return error.MissingNodeCenter;
    const padding = layout.nodes[node_id].center.x - layout.subgraphs[cluster_index].x;
    try std.testing.expect(@abs(padding - expected_padding) <= tolerance);
}

fn expectLayoutClusterMatchesSvgAnchor(graph: *const Graph, layout: *const Layout, svg: []const u8, cluster_label: []const u8, tolerance: f64) !void {
    const cluster_index = subgraphIndexByLabel(graph, cluster_label) orelse return error.MissingClusterRect;
    if (cluster_index >= layout.subgraphs.len) return error.MissingClusterRect;
    const layout_screen_x = clusterVisualRect(graph, layout, cluster_index).x + svgGraphvizTranslate(svg).x;
    const svg_screen_x = svgClusterScreenX(svg, cluster_label) orelse return error.MissingClusterRect;
    try std.testing.expect(@abs(layout_screen_x - svg_screen_x) <= tolerance);
}

fn expectSubgraphMemberPaddingAtLeast(graph: *const Graph, layout: *const Layout, cluster_label: []const u8, min_padding: f64) !void {
    const cluster_index = subgraphIndexByLabel(graph, cluster_label) orelse return error.MissingClusterRect;
    if (cluster_index >= layout.subgraphs.len) return error.MissingClusterRect;
    const rect = clusterVisualRect(graph, layout, cluster_index);
    for (graph.subgraphs.items[cluster_index].nodes) |node_id| {
        if (node_id >= graph.nodes.items.len or node_id >= layout.nodes.len) return error.MissingNodeCenter;
        const node_rect = nodeRect(graphvizRenderNodeLayout(graph, layout, graph.nodes.items[node_id]));
        try std.testing.expect(node_rect.x - rect.x >= min_padding - 0.001);
        try std.testing.expect(node_rect.y - rect.y >= min_padding - 0.001);
        try std.testing.expect((rect.x + rect.width) - (node_rect.x + node_rect.width) >= min_padding - 0.001);
        try std.testing.expect((rect.y + rect.height) - (node_rect.y + node_rect.height) >= min_padding - 0.001);
    }
}

fn expectSvgEdgeEndpointsUseNodeCenters(graph: *const Graph, layout: *const Layout, svg: []const u8, title: []const u8, from_label: []const u8, to_label: []const u8, tolerance: f64) !void {
    const from_id = nodeIdByLabel(graph, from_label);
    const to_id = nodeIdByLabel(graph, to_label);
    if (from_id >= layout.nodes.len or to_id >= layout.nodes.len) return error.MissingNodeCenter;
    const points = svgPathStartEnd(svg, title) orelse return error.MissingEdge;
    switch (layout.rankdir) {
        .TB, .BT => {
            if (@abs(layout.nodes[from_id].center.x - layout.nodes[to_id].center.x) > tolerance) return;
            try std.testing.expect(@abs(points.start.x - layout.nodes[from_id].center.x) <= tolerance);
            try std.testing.expect(@abs(points.end.x - layout.nodes[to_id].center.x) <= tolerance);
        },
        .LR, .RL => {
            if (@abs(layout.nodes[from_id].center.y - layout.nodes[to_id].center.y) > tolerance) return;
            try std.testing.expect(@abs(points.start.y - layout.nodes[from_id].center.y) <= tolerance);
            try std.testing.expect(@abs(points.end.y - layout.nodes[to_id].center.y) <= tolerance);
        },
    }
}

test "SVG subgraph visual bounds keep member padding for all rankdirs" {
    const allocator = std.testing.allocator;
    const rankdirs = [_][]const u8{ "TB", "BT", "LR", "RL" };
    for (rankdirs) |rankdir| {
        const dot = try std.fmt.allocPrint(allocator,
            \\digraph G {{
            \\  graph [rankdir={s}];
            \\  subgraph cluster_left {{
            \\    label="process #1";
            \\    a0 -> a1 -> a2 -> a3;
            \\  }}
            \\  subgraph cluster_right {{
            \\    label="process #2";
            \\    b0 -> b1 -> b2 -> b3;
            \\  }}
            \\  start -> a0;
            \\  start -> b0;
            \\  a1 -> b3 [constraint=false];
            \\}}
        , .{rankdir});
        defer allocator.free(dot);

        var graph = try parseDot(allocator, dot);
        defer graph.deinit();
        var layout = try layoutLayered(allocator, &graph, .{});
        defer layout.deinit();
        const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
        defer allocator.free(svg);

        try expectSubgraphMemberPaddingAtLeast(&graph, &layout, "process #1", 12.0);
        try expectSubgraphMemberPaddingAtLeast(&graph, &layout, "process #2", 12.0);
        try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "a0-&gt;a1", "a0", "a1", 0.1);
        try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "a1-&gt;a2", "a1", "a2", 0.1);
        try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "a2-&gt;a3", "a2", "a3", 0.1);
        try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "b0-&gt;b1", "b0", "b1", 0.1);
        try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "b1-&gt;b2", "b1", "b2", 0.1);
        try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "b2-&gt;b3", "b2", "b3", 0.1);
    }
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
    for (layout.subgraphs) |cluster_box| try std.testing.expect(cluster_box.height <= 294.0);

    const a0 = nodeIdByLabel(&graph, "a0");
    const a1 = nodeIdByLabel(&graph, "a1");
    const a2 = nodeIdByLabel(&graph, "a2");
    const a3 = nodeIdByLabel(&graph, "a3");
    const b0 = nodeIdByLabel(&graph, "b0");
    const b1 = nodeIdByLabel(&graph, "b1");
    const b2 = nodeIdByLabel(&graph, "b2");
    const b3 = nodeIdByLabel(&graph, "b3");
    const start = nodeIdByLabel(&graph, "start");
    const end = nodeIdByLabel(&graph, "end");
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
    try expectLayoutNodeClusterPaddingNear(&graph, &layout, "process #1", a0, 55.0, 2.6);
    try expectLayoutNodeClusterPaddingNear(&graph, &layout, "process #1", a3, 55.0, 2.6);
    try expectLayoutNodeClusterPaddingNear(&graph, &layout, "process #2", b0, 35.0, 2.55);
    try expectLayoutNodeClusterPaddingNear(&graph, &layout, "process #2", b1, 37.0, 1.3);
    try expectLayoutNodeClusterPaddingNear(&graph, &layout, "process #2", b2, 40.0, 1.0);
    try expectLayoutNodeClusterPaddingNear(&graph, &layout, "process #2", b3, 35.0, 2.55);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try expectSvgEdgePathCommandSequencesEqual(svg, graphviz_oracle);
    try expectSvgTextSequenceEqual(svg, graphviz_oracle);
    try expectSvgElementSequenceEqual(svg, graphviz_oracle);
    try expectSvgOpeningTagsNormalizedEqual(svg, graphviz_oracle);
    try std.testing.expect(std.mem.endsWith(u8, svg, "</svg>"));
    try std.testing.expect(!std.mem.endsWith(u8, svg, "</svg>\n"));
    try std.testing.expect(std.mem.indexOf(u8, svg, "xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"224pt\" height=\"409pt\" viewBox=\"0.00 0.00 224.00 409.00\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"graph0\" class=\"graph\" transform=\"scale(1 1) rotate(0) translate(8 0)\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>G</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"white\" stroke=\"none\" points=\"-8,0 -8,409 216,409 216,0 -8,0\"/>") != null);
    const root_fragment = svgRootFragment(svg) orelse return error.MissingGraph;
    const oracle_root_fragment = svgRootFragment(graphviz_oracle) orelse return error.MissingGraph;
    try std.testing.expect(@abs((svgPolygonBBoxX(root_fragment) orelse return error.MissingGraph) + svgGraphvizTranslate(svg).x - ((svgPolygonBBoxX(oracle_root_fragment) orelse return error.MissingGraph) + svgGraphvizTranslate(graphviz_oracle).x)) <= 0.01);
    try std.testing.expect(@abs((svgPolygonBBoxY(root_fragment) orelse return error.MissingGraph) + svgGraphvizTranslate(svg).y - ((svgPolygonBBoxY(oracle_root_fragment) orelse return error.MissingGraph) + svgGraphvizTranslate(graphviz_oracle).y)) <= 0.02);
    try std.testing.expect(@abs((svgPolygonBBoxWidth(root_fragment) orelse return error.MissingGraph) - (svgPolygonBBoxWidth(oracle_root_fragment) orelse return error.MissingGraph)) <= 0.01);
    try std.testing.expect(@abs((svgPolygonBBoxHeight(root_fragment) orelse return error.MissingGraph) - (svgPolygonBBoxHeight(oracle_root_fragment) orelse return error.MissingGraph)) <= 0.02);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "text-anchor=\"middle\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-size=\"14.00\" fill=\"black\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"clust1\" class=\"cluster\">") != null);
    const cluster_0_group_pos = std.mem.indexOf(u8, svg, "<title>process #1</title>") orelse return error.MissingCluster0;
    const cluster_1_group_pos = std.mem.indexOf(u8, svg, "<title>process #2</title>") orelse return error.MissingCluster1;
    try std.testing.expect(cluster_0_group_pos < cluster_1_group_pos);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>process #1</title>\n<polygon") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<!-- a0 -->") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<!-- a0&#45;&gt;a1 -->") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"edge1\" class=\"edge\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>a0-&gt;a1</title>\n<path fill=\"none\" stroke=\"black\" d=\"") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>a0</title>\n<ellipse fill=\"white\" stroke=\"white\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "font-family=\"Times,serif\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon fill=\"lightgrey\" stroke=\"lightgrey\" points=\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>end</title>\n<polygon fill=\"none\" stroke=\"black\"") != null);
    try std.testing.expect(svgPolylineCount(svg, "end") >= 4);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>start</title>\n<polygon fill=\"none\" stroke=\"black\"") != null);
    const start_fragment = svgGroupFragmentByTitle(svg, "start") orelse return error.MissingStartNode;
    const oracle_start_fragment = svgGroupFragmentByTitle(graphviz_oracle, "start") orelse return error.MissingStartNode;
    try std.testing.expectEqual(svgPolygonPointCount(oracle_start_fragment) orelse return error.MissingStartNode, svgPolygonPointCount(start_fragment) orelse return error.MissingStartNode);
    try std.testing.expect(@abs((svgPolygonBBoxHeight(start_fragment) orelse return error.MissingStartNode) - (svgPolygonBBoxHeight(oracle_start_fragment) orelse return error.MissingStartNode)) <= 0.01);
    const end_fragment = svgGroupFragmentByTitle(svg, "end") orelse return error.MissingEndNode;
    const oracle_end_fragment = svgGroupFragmentByTitle(graphviz_oracle, "end") orelse return error.MissingEndNode;
    try std.testing.expect(@abs((svgPolygonBBoxWidth(end_fragment) orelse return error.MissingEndNode) - (svgPolygonBBoxWidth(oracle_end_fragment) orelse return error.MissingEndNode)) <= 0.03);
    try std.testing.expect(@abs((svgPolygonBBoxHeight(end_fragment) orelse return error.MissingEndNode) - (svgPolygonBBoxHeight(oracle_end_fragment) orelse return error.MissingEndNode)) <= 0.02);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">process #1</text>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, ">process #2</text>") != null);
    try expectLayoutClusterMatchesSvgAnchor(&graph, &layout, svg, "process #1", 0.1);
    try expectLayoutClusterMatchesSvgAnchor(&graph, &layout, svg, "process #2", 0.1);
    try expectSubgraphMemberPaddingAtLeast(&graph, &layout, "process #1", 12.0);
    try expectSubgraphMemberPaddingAtLeast(&graph, &layout, "process #2", 12.0);
    const svg_start_x = svgNodeCenterX(svg, "start") orelse return error.MissingNodeCenter;
    const svg_end_x = svgNodeCenterX(svg, "end") orelse return error.MissingNodeCenter;
    try std.testing.expect(svg_start_x > svgNodeCenterX(svg, "a0").?);
    try std.testing.expect(svg_start_x < svgNodeCenterX(svg, "b0").?);
    try std.testing.expect(svg_end_x > svgNodeCenterX(svg, "a3").?);
    try std.testing.expect(svg_end_x < svgNodeCenterX(svg, "b3").?);
    try std.testing.expect(svg_start_x >= 109.0);
    try std.testing.expect(svg_end_x >= 109.0);
    const a0_fragment = svgGroupFragmentByTitle(svg, "a0") orelse return error.MissingNodeCenter;
    const oracle_a0_fragment = svgGroupFragmentByTitle(graphviz_oracle, "a0") orelse return error.MissingNodeCenter;
    const b0_fragment = svgGroupFragmentByTitle(svg, "b0") orelse return error.MissingNodeCenter;
    const oracle_b0_fragment = svgGroupFragmentByTitle(graphviz_oracle, "b0") orelse return error.MissingNodeCenter;
    try std.testing.expect(@abs(((svgNumberAfter(a0_fragment, " y=\"") orelse return error.MissingNodeCenter) + svgGraphvizTranslate(svg).y) - ((svgNumberAfter(oracle_a0_fragment, " y=\"") orelse return error.MissingNodeCenter) + svgGraphvizTranslate(graphviz_oracle).y)) <= 0.001);
    try std.testing.expect(@abs(((svgNumberAfter(b0_fragment, " y=\"") orelse return error.MissingNodeCenter) + svgGraphvizTranslate(svg).y) - ((svgNumberAfter(oracle_b0_fragment, " y=\"") orelse return error.MissingNodeCenter) + svgGraphvizTranslate(graphviz_oracle).y)) <= 0.001);
    const cluster_0_x = svgClusterRectX(svg, "process #1") orelse return error.MissingClusterRect;
    const cluster_0_w = svgClusterRectWidth(svg, "process #1") orelse return error.MissingClusterRect;
    const cluster_1_x = svgClusterRectX(svg, "process #2") orelse return error.MissingClusterRect;
    try std.testing.expect(cluster_1_x - (cluster_0_x + cluster_0_w) >= 4.0);
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
    try std.testing.expect(svg_translate.y == 0);
    try std.testing.expect(oracle_translate.y > 400.0);
    try std.testing.expect(@abs((path_numbers[0] + svg_translate.x) - (oracle_path_numbers[0] + oracle_translate.x)) <= 0.05);
    const cross_control1 = svgScreenPoint(svg, .{ .x = path_numbers[2], .y = path_numbers[3] });
    const oracle_cross_control1 = svgScreenPoint(graphviz_oracle, .{ .x = oracle_path_numbers[2], .y = oracle_path_numbers[3] });
    const cross_control2 = svgScreenPoint(svg, .{ .x = path_numbers[4], .y = path_numbers[5] });
    const oracle_cross_control2 = svgScreenPoint(graphviz_oracle, .{ .x = oracle_path_numbers[4], .y = oracle_path_numbers[5] });
    try std.testing.expect(distanceBetween(cross_control1, oracle_cross_control1) <= 0.07);
    try std.testing.expect(distanceBetween(cross_control2, oracle_cross_control2) <= 0.07);
    const cross_points = svgPathStartEnd(svg, "a1-&gt;b3") orelse return error.MissingCrossClusterEdge;
    const oracle_cross_points = svgPathStartEnd(graphviz_oracle, "a1-&gt;b3") orelse return error.MissingCrossClusterEdge;
    const cross_start = svgScreenPoint(svg, cross_points.start);
    const oracle_cross_start = svgScreenPoint(graphviz_oracle, oracle_cross_points.start);
    const cross_end_point = svgScreenPoint(svg, cross_points.end);
    const oracle_cross_end = svgScreenPoint(graphviz_oracle, oracle_cross_points.end);
    try std.testing.expect(distanceBetween(cross_start, oracle_cross_start) <= 0.07);
    try std.testing.expect(distanceBetween(cross_end_point, oracle_cross_end) <= 0.07);
    const diagonal_count = svgPathNumbers(svg, "b2-&gt;a3", path_numbers[0..]);
    try std.testing.expect(diagonal_count >= 8);
    const oracle_diagonal_count = svgPathNumbers(graphviz_oracle, "b2-&gt;a3", oracle_path_numbers[0..]);
    try std.testing.expect(oracle_diagonal_count >= 8);
    try std.testing.expect(@abs((path_numbers[0] + svg_translate.x) - (oracle_path_numbers[0] + oracle_translate.x)) <= 0.001);
    const diagonal_control1 = svgScreenPoint(svg, .{ .x = path_numbers[2], .y = path_numbers[3] });
    const oracle_diagonal_control1 = svgScreenPoint(graphviz_oracle, .{ .x = oracle_path_numbers[2], .y = oracle_path_numbers[3] });
    const diagonal_control2 = svgScreenPoint(svg, .{ .x = path_numbers[4], .y = path_numbers[5] });
    const oracle_diagonal_control2 = svgScreenPoint(graphviz_oracle, .{ .x = oracle_path_numbers[4], .y = oracle_path_numbers[5] });
    try std.testing.expect(distanceBetween(diagonal_control1, oracle_diagonal_control1) <= 0.07);
    try std.testing.expect(distanceBetween(diagonal_control2, oracle_diagonal_control2) <= 0.001);
    try std.testing.expect(path_numbers[2] > path_numbers[4]);
    try std.testing.expect(path_numbers[4] > path_numbers[6]);
    const diagonal_points = svgPathStartEnd(svg, "b2-&gt;a3") orelse return error.MissingDiagonalEdge;
    const oracle_diagonal_points = svgPathStartEnd(graphviz_oracle, "b2-&gt;a3") orelse return error.MissingDiagonalEdge;
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, diagonal_points.start), svgScreenPoint(graphviz_oracle, oracle_diagonal_points.start)) <= 0.001);
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, diagonal_points.end), svgScreenPoint(graphviz_oracle, oracle_diagonal_points.end)) <= 0.07);
    try expectSvgEdgePathPointsNear(svg, graphviz_oracle, "b2-&gt;a3", 0.023);
    const back_label = std.mem.indexOf(u8, svg, "<title>a3-&gt;a0</title>") orelse return error.MissingBackEdge;
    const back_end = std.mem.indexOf(u8, svg[back_label..], "</g>") orelse return error.MissingBackEdge;
    const back_edge = svg[back_label .. back_label + back_end];
    try std.testing.expect(svgPathCommandCount(back_edge, 'C') == 1);
    try std.testing.expect(svgPathCommandCount(back_edge, 'L') == 0);
    var back_numbers: [32]f64 = undefined;
    const back_count = svgNumbersInAttribute(back_edge, "d", back_numbers[0..]);
    try std.testing.expect(back_count >= 20);
    var oracle_back_numbers: [32]f64 = undefined;
    const oracle_back_count = svgPathNumbers(graphviz_oracle, "a3-&gt;a0", oracle_back_numbers[0..]);
    try std.testing.expect(oracle_back_count >= 20);
    const back_first_control1 = svgScreenPoint(svg, .{ .x = back_numbers[2], .y = back_numbers[3] });
    const oracle_back_first_control1 = svgScreenPoint(graphviz_oracle, .{ .x = oracle_back_numbers[2], .y = oracle_back_numbers[3] });
    const back_first_control2 = svgScreenPoint(svg, .{ .x = back_numbers[4], .y = back_numbers[5] });
    const oracle_back_first_control2 = svgScreenPoint(graphviz_oracle, .{ .x = oracle_back_numbers[4], .y = oracle_back_numbers[5] });
    try std.testing.expect(distanceBetween(back_first_control1, oracle_back_first_control1) <= 0.001);
    try std.testing.expect(distanceBetween(back_first_control2, oracle_back_first_control2) <= 0.021);
    try std.testing.expect(@abs((back_numbers[6] + svg_translate.x) - (oracle_back_numbers[6] + oracle_translate.x)) <= 0.01);
    const back_mid_control = svgScreenPoint(svg, .{ .x = back_numbers[8], .y = back_numbers[9] });
    const oracle_back_mid_control = svgScreenPoint(graphviz_oracle, .{ .x = oracle_back_numbers[8], .y = oracle_back_numbers[9] });
    try std.testing.expect(distanceBetween(back_mid_control, oracle_back_mid_control) <= 0.03);
    const back_tail_control1 = svgScreenPoint(svg, .{ .x = back_numbers[14], .y = back_numbers[15] });
    const oracle_back_tail_control1 = svgScreenPoint(graphviz_oracle, .{ .x = oracle_back_numbers[14], .y = oracle_back_numbers[15] });
    const back_tail_control2 = svgScreenPoint(svg, .{ .x = back_numbers[16], .y = back_numbers[17] });
    const oracle_back_tail_control2 = svgScreenPoint(graphviz_oracle, .{ .x = oracle_back_numbers[16], .y = oracle_back_numbers[17] });
    try std.testing.expect(distanceBetween(back_tail_control1, oracle_back_tail_control1) <= 0.05);
    try std.testing.expect(distanceBetween(back_tail_control2, oracle_back_tail_control2) <= 0.06);
    const back_points = svgPathStartEnd(svg, "a3-&gt;a0") orelse return error.MissingBackEdge;
    const oracle_back_points = svgPathStartEnd(graphviz_oracle, "a3-&gt;a0") orelse return error.MissingBackEdge;
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, back_points.start), svgScreenPoint(graphviz_oracle, oracle_back_points.start)) <= 0.001);
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, back_points.end), svgScreenPoint(graphviz_oracle, oracle_back_points.end)) <= 0.04);
    const back_tip = svgEdgeArrowTip(svg, "a3-&gt;a0") orelse return error.MissingBackEdge;
    const oracle_back_tip = svgEdgeArrowTip(graphviz_oracle, "a3-&gt;a0") orelse return error.MissingBackEdge;
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, back_tip), svgScreenPoint(graphviz_oracle, oracle_back_tip)) <= 0.05);
    try expectSvgEdgePathPointsNear(svg, graphviz_oracle, "a3-&gt;a0", 0.045);
    try expectSvgEdgeArrowPointsNear(svg, graphviz_oracle, "a3-&gt;a0", 0.021);
    try expectSvgEdgeArrowShapeNear(svg, graphviz_oracle, "a3-&gt;a0", 0.407);
    const start_a0_points = svgPathStartEnd(svg, "start-&gt;a0") orelse return error.MissingStartEdge;
    const oracle_start_a0_points = svgPathStartEnd(graphviz_oracle, "start-&gt;a0") orelse return error.MissingStartEdge;
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, start_a0_points.start), svgScreenPoint(graphviz_oracle, oracle_start_a0_points.start)) <= 0.06);
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, start_a0_points.end), svgScreenPoint(graphviz_oracle, oracle_start_a0_points.end)) <= 0.01);
    const start_b0_points = svgPathStartEnd(svg, "start-&gt;b0") orelse return error.MissingStartEdge;
    const oracle_start_b0_points = svgPathStartEnd(graphviz_oracle, "start-&gt;b0") orelse return error.MissingStartEdge;
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, start_b0_points.start), svgScreenPoint(graphviz_oracle, oracle_start_b0_points.start)) <= 0.06);
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, start_b0_points.end), svgScreenPoint(graphviz_oracle, oracle_start_b0_points.end)) <= 0.01);
    const a3_end_points = svgPathStartEnd(svg, "a3-&gt;end") orelse return error.MissingEndEdge;
    const oracle_a3_end_points = svgPathStartEnd(graphviz_oracle, "a3-&gt;end") orelse return error.MissingEndEdge;
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, a3_end_points.start), svgScreenPoint(graphviz_oracle, oracle_a3_end_points.start)) <= 0.06);
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, a3_end_points.end), svgScreenPoint(graphviz_oracle, oracle_a3_end_points.end)) <= 0.06);
    const b3_end_points = svgPathStartEnd(svg, "b3-&gt;end") orelse return error.MissingEndEdge;
    const oracle_b3_end_points = svgPathStartEnd(graphviz_oracle, "b3-&gt;end") orelse return error.MissingEndEdge;
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, b3_end_points.start), svgScreenPoint(graphviz_oracle, oracle_b3_end_points.start)) <= 0.01);
    try std.testing.expect(distanceBetween(svgScreenPoint(svg, b3_end_points.end), svgScreenPoint(graphviz_oracle, oracle_b3_end_points.end)) <= 0.06);
    try expectSvgEdgeControlsNear(svg, graphviz_oracle, "start-&gt;a0", 0.1, 0.3);
    try expectSvgEdgeControlsNear(svg, graphviz_oracle, "start-&gt;b0", 0.2, 0.3);
    try expectSvgEdgeControlsNear(svg, graphviz_oracle, "a3-&gt;end", 0.06, 0.06);
    try expectSvgEdgeControlsNear(svg, graphviz_oracle, "b3-&gt;end", 0.06, 0.06);
    try expectSvgEdgePathPointsNear(svg, graphviz_oracle, "start-&gt;a0", 0.032);
    try expectSvgEdgePathPointsNear(svg, graphviz_oracle, "start-&gt;b0", 0.045);
    try expectSvgEdgeCurveSamplesNear(svg, graphviz_oracle, "start-&gt;a0", 0.045);
    try expectSvgEdgeCurveSamplesNear(svg, graphviz_oracle, "start-&gt;b0", 0.045);
    try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "a0-&gt;a1", "a0", "a1", 0.1);
    try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "a1-&gt;a2", "a1", "a2", 0.1);
    try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "a2-&gt;a3", "a2", "a3", 0.1);
    try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "b0-&gt;b1", "b0", "b1", 0.1);
    try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "b1-&gt;b2", "b1", "b2", 0.1);
    try expectSvgEdgeEndpointsUseNodeCenters(&graph, &layout, svg, "b2-&gt;b3", "b2", "b3", 0.1);
    try expectSvgEdgeCurveSamplesNear(svg, graphviz_oracle, "b2-&gt;a3", 0.018);
    try expectSvgEdgePathPointsNear(svg, graphviz_oracle, "a1-&gt;b3", 0.023);
    try expectSvgEdgePathPointsNear(svg, graphviz_oracle, "a3-&gt;end", 0.015);
    try expectSvgEdgePathPointsNear(svg, graphviz_oracle, "b3-&gt;end", 0.023);
    try expectSvgEdgeCurveSamplesNear(svg, graphviz_oracle, "a3-&gt;a0", 0.04);
    try expectSvgEdgeCurveSamplesNear(svg, graphviz_oracle, "b3-&gt;end", 0.038);
    try expectSvgEdgeArrowTipNear(svg, graphviz_oracle, "a1-&gt;b3", 0.04);
    try expectSvgEdgeArrowTipNear(svg, graphviz_oracle, "b2-&gt;a3", 0.04);
    try expectSvgEdgeArrowTipNear(svg, graphviz_oracle, "a3-&gt;end", 0.04);
    try expectSvgEdgeArrowTipNear(svg, graphviz_oracle, "b3-&gt;end", 0.04);
    try expectSvgEdgeArrowTipNear(svg, graphviz_oracle, "start-&gt;a0", 0.04);
    try expectSvgEdgeArrowTipNear(svg, graphviz_oracle, "start-&gt;b0", 0.04);
    try expectSvgEdgeArrowPointsNear(svg, graphviz_oracle, "a1-&gt;b3", 0.031);
    try expectSvgEdgeArrowShapeNear(svg, graphviz_oracle, "a1-&gt;b3", 0.365);
    try expectSvgEdgeArrowPointsNear(svg, graphviz_oracle, "start-&gt;a0", 0.033);
    try expectSvgEdgeArrowPointsNear(svg, graphviz_oracle, "start-&gt;b0", 0.037);
    try expectSvgEdgeArrowShapeNear(svg, graphviz_oracle, "start-&gt;b0", 0.085);
    try expectSvgEdgeArrowPointsNear(svg, graphviz_oracle, "b2-&gt;a3", 0.037);
    try expectSvgEdgeArrowShapeNear(svg, graphviz_oracle, "b2-&gt;a3", 0.128);
    try expectSvgEdgeArrowPointsNear(svg, graphviz_oracle, "a3-&gt;end", 0.031);
    try expectSvgEdgeArrowShapeNear(svg, graphviz_oracle, "a3-&gt;end", 0.216);
    try expectSvgEdgeArrowPointsNear(svg, graphviz_oracle, "b3-&gt;end", 0.052);
    try expectSvgEdgeArrowShapeNear(svg, graphviz_oracle, "b3-&gt;end", 0.34);
    try std.testing.expect(svgPolylineCount(svg, "start") >= 4);
    try std.testing.expect(svgPolylineCount(svg, "end") >= 4);
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
        .fill = "black",
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
        .fill = "black",
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
    try std.testing.expectEqual(@as(f64, 90), shortened.end.y);
    try std.testing.expectEqual(route.label.y, shortened.label.y);
}

test "SVG edge labels avoid overlapping intervening nodes" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .name = "labels" });
    defer graph.deinit();
    const from = try graph.addNode("from", .{ .shape = .box });
    const middle = try graph.addNode("middle", .{ .shape = .box });
    const to = try graph.addNode("to", .{ .shape = .box });
    const edge_id = try graph.addEdge(from, to, .{ .label = "write", .xlabel = "external", .labelfontsize = 22 });

    var layout = Layout{
        .allocator = allocator,
        .graph = try Graph.init(allocator, .{ .directed = true }),
        .rankdir = .TB,
        .nodes = try allocator.dupe(NodeLayout, &.{
            .{ .center = .{ .x = 40, .y = 20 }, .width = 54, .height = 36 },
            .{ .center = .{ .x = 40, .y = 100 }, .width = 62, .height = 36 },
            .{ .center = .{ .x = 40, .y = 180 }, .width = 54, .height = 36 },
        }),
        .subgraphs = try allocator.alloc(SubgraphLayout, 0),
        .edge_waypoints = try allocator.alloc(EdgeWaypoints, 0),
        .ranks = try allocator.dupe(usize, &.{ 0, 1, 2 }),
        .rank_depths = try allocator.alloc(f64, 0),
        .rank_heights = try allocator.alloc(f64, 0),
        .margin = 16,
        .margin_x = 16,
        .margin_y = 16,
        .width = 140,
        .height = 220,
    };
    defer layout.deinit();

    const route = edgeRoute(layout.nodes[from], layout.nodes[to], .TB, 0);
    const edge_item = graph.edges.items[edge_id];
    const visual = resolveEdgeVisual(edge_item);
    const before = edgeLabelRect(edge_item.label.?, .{ .x = route.label.x, .y = route.label.y - 6.0 }, visual.font_size);
    try std.testing.expect(edgeLabelOverlapsNodes(&graph, &layout, edge_item, before));
    const label_center = edgeLabelCenterAvoidingNodes(&graph, &layout, edge_item, route, visual, edge_item.label.?);
    const after = edgeLabelRect(edge_item.label.?, label_center, visual.font_size);
    try std.testing.expect(!edgeLabelOverlapsNodes(&graph, &layout, edge_item, after));
    try std.testing.expect(label_center.y != route.label.y - 6.0);

    const xlabel = attrValue(edge_item.attrs.items, "xlabel").?;
    const label_font_size = parsePositiveAttrFloat(edge_item.attrs.items, "labelfontsize", visual.font_size);
    const xbefore = edgeLabelRect(xlabel, .{ .x = route.label.x, .y = route.label.y + 18.0 }, label_font_size);
    try std.testing.expect(edgeLabelOverlapsNodes(&graph, &layout, edge_item, xbefore));
    const xlabel_center = edgeXLabelCenterAvoidingNodes(&graph, &layout, edge_item, route, xlabel, label_font_size);
    const xafter = edgeLabelRect(xlabel, xlabel_center, label_font_size);
    try std.testing.expect(!edgeLabelOverlapsNodes(&graph, &layout, edge_item, xafter));
    try std.testing.expect(xlabel_center.y != route.label.y + 18.0);
    _ = middle;
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    try std.testing.expectEqual(layout.ranks[a], layout.ranks[b]);
    try std.testing.expectEqual(layout.ranks[a] + 3, layout.ranks[c]);
}

test "DOT parser records named subgraphs with graph attributes" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph api {
        \\    graph [label="API", color="#2563eb", fillcolor="#dbeafe", style="filled,rounded"];
        \\    a; b;
        \\    a -> b;
        \\  }
        \\  c;
        \\}
    );
    defer graph.deinit();

    try std.testing.expectEqual(@as(usize, 1), graph.subgraphs.items.len);
    const cluster = graph.subgraphs.items[0];
    try std.testing.expectEqual(@as(SubgraphId, 0), cluster.id);
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
    try std.testing.expectEqual(@as(usize, 1), layout.subgraphs.len);

    const cluster_box = layout.subgraphs[0];
    for (graph.subgraphs.items[0].nodes) |node_id| {
        const n = layout.nodes[node_id];
        try std.testing.expect(cluster_box.x <= n.center.x - n.width / 2.0);
        try std.testing.expect(cluster_box.y <= n.center.y - n.height / 2.0);
        try std.testing.expect(cluster_box.x + cluster_box.width >= n.center.x + n.width / 2.0);
        try std.testing.expect(cluster_box.y + cluster_box.height >= n.center.y + n.height / 2.0);
    }

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "class=\"clusters\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<g id=\"clust1\" class=\"cluster\">\n<title>API</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<title>API</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "API") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#dbeafe\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"#2563eb\"") != null);
}

test "SVG canvas expands to fit shifted clusters and outside nodes" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .rankdir = .LR });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .nodesep = 0.9 });

    const start = try graph.addNode("Start", .{ .shape = .mdiamond });
    const a0 = try graph.addNode("a0", .{});
    const a1 = try graph.addNode("a1", .{});
    const b0 = try graph.addNode("b0", .{});
    const b1 = try graph.addNode("b1", .{});
    _ = try graph.addSubgraph("cluster_process_1", null, &.{ a0, a1 }, .{ .label = "process #1" });
    _ = try graph.addSubgraph("cluster_process_2", null, &.{ b0, b1 }, .{ .label = "process #2" });
    _ = try graph.addEdge(start, a0, .{});
    _ = try graph.addEdge(start, b0, .{});
    _ = try graph.addEdge(a0, a1, .{});
    _ = try graph.addEdge(b0, b1, .{});

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    const start_fragment = svgGroupFragmentByTitle(svg, "node1") orelse return error.MissingStartNode;
    const cluster_fragment = svgGroupFragmentByTitle(svg, "process #1") orelse return error.MissingClusterRect;
    const start_left = (svgPolygonBBoxX(start_fragment) orelse return error.MissingStartNode) + svgGraphvizTranslate(svg).x;
    const cluster_top = (svgPolygonBBoxY(cluster_fragment) orelse return error.MissingClusterRect) + svgGraphvizTranslate(svg).y;
    try std.testing.expect(start_left >= svg_clip_padding - 0.01);
    try std.testing.expect(cluster_top >= svg_clip_padding - 0.01);
}

test "SVG canvas expands to fit external node and edge labels" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .rankdir = .TB });
    defer graph.deinit();

    const a = try graph.addNode("A", .{ .xlabel = "external node label" });
    const b = try graph.addNode("B", .{});
    _ = try graph.addEdge(a, b, .{
        .label = "edge",
        .xlabel = "large external edge label",
        .labelfontsize = 22,
    });

    var layout = try layoutGraph(allocator, &graph, .{});
    defer layout.deinit();
    const raw_bounds = svgGraphContentBounds(&graph, &layout) orelse return error.MissingSvgBounds;
    try std.testing.expect(raw_bounds.x + raw_bounds.width > layout.width);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    const view_box = svgViewBox(svg) orelse return error.MissingViewBox;
    try std.testing.expect(view_box.width >= raw_bounds.x + raw_bounds.width + svg_clip_padding - 0.01);
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
    const cluster_box = layout.subgraphs[0];
    const a = nodeIdByLabel(&graph, "a");
    const node = layout.nodes[a];
    try std.testing.expect(cluster_box.width >= node.width + 24.0);
    try std.testing.expect(cluster_box.width <= 96.0);
    try std.testing.expect(cluster_box.height >= node.height + 42.0);
    try std.testing.expect(cluster_box.height <= node.height + 48.0);
}

test "cluster layout honors margin attribute for member padding" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_roomy {
        \\    margin=0.5;
        \\    a;
        \\  }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();

    const cluster_box = layout.subgraphs[0];
    const a = nodeIdByLabel(&graph, "a");
    const node = layout.nodes[a];
    const left_padding = node.center.x - node.width / 2.0 - cluster_box.x;
    const right_padding = cluster_box.x + cluster_box.width - (node.center.x + node.width / 2.0);
    try std.testing.expect(left_padding >= 35.0);
    try std.testing.expect(right_padding >= 35.0);
    try std.testing.expect(cluster_box.width >= node.width + 72.0);
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

test "cluster bgcolor fills background with Graphviz precedence" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_bg {
        \\    bgcolor="#fef3c7";
        \\    color="#92400e";
        \\    a;
        \\  }
        \\  subgraph cluster_fill_trumps_bg {
        \\    style=filled;
        \\    bgcolor="#fee2e2";
        \\    fillcolor="#dcfce7";
        \\    b;
        \\  }
        \\  subgraph cluster_color_trumps_bg_when_filled {
        \\    style=filled;
        \\    bgcolor="#f1f5f9";
        \\    color="#2563eb";
        \\    c;
        \\  }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#fef3c7\" stroke=\"#92400e\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#dcfce7\" stroke=\"#94a3b8\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#fee2e2\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#2563eb\" stroke=\"#2563eb\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#f1f5f9\"") == null);
}

test "cluster pencolor overrides stroke without changing fill" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_color {
        \\    style=filled;
        \\    color="#2563eb";
        \\    pencolor="#dc2626";
        \\    a;
        \\  }
        \\  subgraph cluster_fill {
        \\    style=filled;
        \\    fillcolor="#dbeafe";
        \\    pencolor="#1d4ed8";
        \\    b;
        \\  }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#2563eb\" stroke=\"#dc2626\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#dbeafe\" stroke=\"#1d4ed8\"") != null);
}

test "cluster bold style thickens stroke unless penwidth is explicit" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_bold {
        \\    style=bold;
        \\    color="#2563eb";
        \\    a;
        \\  }
        \\  subgraph cluster_explicit {
        \\    style=bold;
        \\    color="#16a34a";
        \\    penwidth=2;
        \\    b;
        \\  }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\" stroke=\"#2563eb\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"none\" stroke=\"#16a34a\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke-width=\"2\"") != null);
}

test "cluster peripheries zero hides border while preserving fill" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  subgraph cluster_borderless {
        \\    style=filled;
        \\    fillcolor="#dbeafe";
        \\    pencolor="#1d4ed8";
        \\    peripheries=0;
        \\    a;
        \\  }
        \\}
    );
    defer graph.deinit();

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);

    try std.testing.expectEqualStrings("0", attrValue(graph.subgraphs.items[0].attrs.items, "peripheries").?);
    try std.testing.expect(std.mem.indexOf(u8, svg, "fill=\"#dbeafe\" stroke=\"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "stroke=\"#1d4ed8\"") == null);
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
    const box = layout.subgraphs[0];
    var expected_y_value_buf: [32]u8 = undefined;
    const expected_y_value = try svgNumberForTest(&expected_y_value_buf, box.y + box.height - 10.0);
    var expected_buf: [64]u8 = undefined;
    const expected_y = try std.fmt.bufPrint(&expected_buf, "y=\"{s}\"", .{expected_y_value});
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

    try std.testing.expectEqual(@as(usize, 2), graph.subgraphs.items.len);
    const inner = graph.subgraphs.items[subgraphIndexByLabel(&graph, "Inner").?];
    const outer = graph.subgraphs.items[subgraphIndexByLabel(&graph, "Outer").?];
    try std.testing.expectEqual(outer.id, inner.parent.?);
    try std.testing.expectEqualStrings("Inner", inner.label);
    try std.testing.expectEqualStrings("Outer", outer.label);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const inner_box = layout.subgraphs[inner.id];
    const outer_box = layout.subgraphs[outer.id];
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
    const d = nodeIdByLabel(&graph, "d");
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

    const s1 = nodeIdByLabel(&graph, "s1");
    const m1 = nodeIdByLabel(&graph, "m1");
    const t1 = nodeIdByLabel(&graph, "t1");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
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
    const cluster = Subgraph{
        .id = 0,
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
    const cluster = Subgraph{
        .id = 0,
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

    const weighted_child = nodeIdByLabel(&weighted, "child");
    const weighted_right = nodeIdByLabel(&weighted, "right");
    const balanced_child = nodeIdByLabel(&balanced, "child");
    const balanced_right = nodeIdByLabel(&balanced, "right");
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
    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
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
    const ia = nodeIdByLabel(&incoming, "a");
    const ib = nodeIdByLabel(&incoming, "b");
    const ic = nodeIdByLabel(&incoming, "c");
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

    try std.testing.expectEqual(Shape.triangle, graph.nodes.items[nodeIdByLabel(&graph, "start")].shape);
    try std.testing.expectEqual(Shape.diamond, graph.nodes.items[nodeIdByLabel(&graph, "decision")].shape);
    try std.testing.expectEqual(Shape.parallelogram, graph.nodes.items[nodeIdByLabel(&graph, "io")].shape);
    try std.testing.expectEqual(Shape.trapezium, graph.nodes.items[nodeIdByLabel(&graph, "trap")].shape);
    try std.testing.expectEqual(Shape.invtrapezium, graph.nodes.items[nodeIdByLabel(&graph, "invtrap")].shape);
    try std.testing.expectEqual(Shape.hexagon, graph.nodes.items[nodeIdByLabel(&graph, "done")].shape);
    try std.testing.expectEqual(Shape.octagon, graph.nodes.items[nodeIdByLabel(&graph, "stop")].shape);
    try std.testing.expectEqual(Shape.invtriangle, graph.nodes.items[nodeIdByLabel(&graph, "fail")].shape);
    try std.testing.expectEqual(Shape.plaintext, graph.nodes.items[nodeIdByLabel(&graph, "note")].shape);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const note = nodeIdByLabel(&graph, "note");
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

    const sq = nodeIdByLabel(&graph, "sq");
    const oval = nodeIdByLabel(&graph, "oval");
    try std.testing.expectEqual(Shape.square, graph.nodes.items[sq].shape);
    try std.testing.expectEqual(Shape.ellipse, graph.nodes.items[oval].shape);
    try std.testing.expectEqual(Shape.house, graph.nodes.items[nodeIdByLabel(&graph, "house")].shape);
    try std.testing.expectEqual(Shape.invhouse, graph.nodes.items[nodeIdByLabel(&graph, "invhouse")].shape);
    try std.testing.expectEqual(Shape.pentagon, graph.nodes.items[nodeIdByLabel(&graph, "pent")].shape);
    try std.testing.expectEqual(Shape.septagon, graph.nodes.items[nodeIdByLabel(&graph, "sept")].shape);
    try std.testing.expectEqual(Shape.doubleoctagon, graph.nodes.items[nodeIdByLabel(&graph, "two")].shape);
    try std.testing.expectEqual(Shape.tripleoctagon, graph.nodes.items[nodeIdByLabel(&graph, "three")].shape);

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

    try std.testing.expectEqual(Shape.note, graph.nodes.items[nodeIdByLabel(&graph, "note")].shape);
    try std.testing.expectEqual(Shape.tab, graph.nodes.items[nodeIdByLabel(&graph, "tab")].shape);
    try std.testing.expectEqual(Shape.folder, graph.nodes.items[nodeIdByLabel(&graph, "folder")].shape);
    try std.testing.expectEqual(Shape.box3d, graph.nodes.items[nodeIdByLabel(&graph, "box3d")].shape);
    try std.testing.expectEqual(Shape.component, graph.nodes.items[nodeIdByLabel(&graph, "component")].shape);
    try std.testing.expectEqual(Shape.underline, graph.nodes.items[nodeIdByLabel(&graph, "underline")].shape);
    try std.testing.expectEqual(Shape.cylinder, graph.nodes.items[nodeIdByLabel(&graph, "cylinder")].shape);

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

    try std.testing.expectEqual(Shape.egg, graph.nodes.items[nodeIdByLabel(&graph, "egg")].shape);
    try std.testing.expectEqual(Shape.star, graph.nodes.items[nodeIdByLabel(&graph, "star")].shape);
    try std.testing.expectEqual(Shape.mdiamond, graph.nodes.items[nodeIdByLabel(&graph, "md")].shape);
    try std.testing.expectEqual(Shape.msquare, graph.nodes.items[nodeIdByLabel(&graph, "ms")].shape);
    try std.testing.expectEqual(Shape.mcircle, graph.nodes.items[nodeIdByLabel(&graph, "mc")].shape);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const ms = nodeIdByLabel(&graph, "ms");
    const mc = nodeIdByLabel(&graph, "mc");
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
    const end = nodeIdByLabel(&graph, "end");
    const badge = nodeIdByLabel(&graph, "mc");
    const long = nodeIdByLabel(&graph, "long");
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

    const pent = nodeIdByLabel(&graph, "pent");
    const reg = nodeIdByLabel(&graph, "reg");
    const skewed = nodeIdByLabel(&graph, "skewed");
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

test "code API exposes typed polygon node parameters" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();

    const pent = try graph.addNode("typed", .{
        .shape = .polygon,
        .sides = 5,
        .orientation = 18,
        .regular = true,
    });
    try graph.setNodeAttr(pent, .{ .skew = 0.4 });
    try graph.setNodeAttr(pent, .{ .distortion = -0.2 });
    const spec = customPolygonFromAttrs(graph.nodes.items[pent].attrs.items);

    try std.testing.expectEqual(Shape.polygon, graph.nodes.items[pent].shape);
    try std.testing.expectEqual(@as(usize, 5), spec.sides);
    try std.testing.expect(spec.regular);
    try std.testing.expect(spec.orientation_deg > 17.9);
    try std.testing.expect(spec.skew > 0);
    try std.testing.expect(spec.distortion < 0);
    try std.testing.expectEqualStrings("5", attrValue(graph.nodes.items[pent].attrs.items, "sides").?);
    try std.testing.expectEqualStrings("true", attrValue(graph.nodes.items[pent].attrs.items, "regular").?);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "<polygon") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "typed") != null);
}

test "DOT doublecircle shape renders as two circle peripheries" {
    const allocator = std.testing.allocator;
    var graph = try parseDot(allocator,
        \\digraph G {
        \\  accept [shape=doublecircle, label="accept"];
        \\}
    );
    defer graph.deinit();

    const accept = nodeIdByLabel(&graph, "accept");
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

    const p = nodeIdByLabel(&graph, "p");
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

    const entity = nodeIdByLabel(&graph, "entity");
    const rounded = nodeIdByLabel(&graph, "rounded");
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
    try std.testing.expect(countSubstrings(svg, "<path d=\"M") >= 2);
    try std.testing.expect(std.mem.indexOf(u8, svg, "rx=\"10\"") != null);
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

test "code API exposes typed edge compass and record ports" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true, .rankdir = .LR });
    defer graph.deinit();

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const edge_id = try graph.addEdge(a, b, .{ .tail_port = .east, .head_port = .west });
    try std.testing.expectEqualStrings("e", attrValue(graph.edges.items[edge_id].attrs.items, "tailport").?);
    try std.testing.expectEqualStrings("w", attrValue(graph.edges.items[edge_id].attrs.items, "headport").?);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    var route = edgeRouteForEdge(&graph, &layout, graph.edges.items[edge_id], layout.rankdir, 0);
    try std.testing.expectEqual(layout.nodes[a].center.x + layout.nodes[a].width / 2.0, route.start.x);
    try std.testing.expectEqual(layout.nodes[b].center.x - layout.nodes[b].width / 2.0, route.end.x);

    const customer = try graph.addNode("<id> Customer|<orders> orders[]", .{ .shape = .mrecord });
    const order = try graph.addNode("<id> Order|total", .{ .shape = .record });
    const record_edge_id = try graph.addEdge(customer, order, .{});
    try graph.setEdgeAttr(record_edge_id, .{ .tail_port = .{ .record = "orders", .compass = .east } });
    try graph.setEdgeAttr(record_edge_id, .{ .head_port = .{ .record = "id", .compass = .west } });
    try std.testing.expectEqualStrings("orders:e", attrValue(graph.edges.items[record_edge_id].attrs.items, "tailport").?);
    try std.testing.expectEqualStrings("id:w", attrValue(graph.edges.items[record_edge_id].attrs.items, "headport").?);

    var record_layout = try layoutLayered(allocator, &graph, .{});
    defer record_layout.deinit();
    route = edgeRouteForEdge(&graph, &record_layout, graph.edges.items[record_edge_id], record_layout.rankdir, 0);
    const tail_rect = recordFieldRect(graph.nodes.items[customer].label, record_layout.nodes[customer], "orders").?;
    const head_rect = recordFieldRect(graph.nodes.items[order].label, record_layout.nodes[order], "id").?;
    try std.testing.expectEqual(tail_rect.x + tail_rect.width, route.start.x);
    try std.testing.expectEqual(head_rect.x, route.end.x);
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

    const customer = nodeIdByLabel(&graph, "customer");
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
    try std.testing.expectEqual(@as(SubgraphId, 0), edge_item.ltail.?);
    try std.testing.expectEqual(@as(SubgraphId, 1), edge_item.lhead.?);

    const route = edgeRouteForEdge(&graph, &layout, edge_item, layout.rankdir, 0);
    const left = subgraphRect(&graph, &layout, edge_item.ltail.?).?;
    const right = subgraphRect(&graph, &layout, edge_item.lhead.?).?;
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
    const left = subgraphRect(&graph, &layout, edge_item.ltail.?).?;
    const right = subgraphRect(&graph, &layout, edge_item.lhead.?).?;
    try std.testing.expect(!pointOnRectBoundary(left, route.start));
    try std.testing.expect(!pointOnRectBoundary(right, route.end));
    try std.testing.expect(!graphCompoundEnabled(&graph));
}

test "code API exposes typed compound edge ltail and lhead" {
    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, .{ .directed = true });
    defer graph.deinit();
    try graph.setGraphAttr(.{ .compound = true });

    const a = try graph.addNode("a", .{});
    const b = try graph.addNode("b", .{});
    const c = try graph.addNode("c", .{});
    const d = try graph.addNode("d", .{});
    const tail = try graph.addSubgraph("cluster_tail", null, &.{ a, b }, .{});
    const head = try graph.addSubgraph("cluster_head", null, &.{ c, d }, .{});
    const edge_id = try graph.addEdge(b, c, .{ .ltail = tail });
    try graph.setEdgeAttr(edge_id, .{ .lhead = head });

    const edge_item = graph.edges.items[edge_id];
    try std.testing.expectEqual(tail, edge_item.ltail.?);
    try std.testing.expectEqual(head, edge_item.lhead.?);
    try std.testing.expectEqualStrings("cluster_tail", attrValue(edge_item.attrs.items, "ltail").?);
    try std.testing.expectEqualStrings("cluster_head", attrValue(edge_item.attrs.items, "lhead").?);

    var layout = try layoutLayered(allocator, &graph, .{});
    defer layout.deinit();
    const route = edgeRouteForEdge(&graph, &layout, edge_item, layout.rankdir, 0);
    const tail_rect = subgraphRect(&graph, &layout, tail).?;
    const head_rect = subgraphRect(&graph, &layout, head).?;
    try std.testing.expect(pointOnRectBoundary(tail_rect, route.start));
    try std.testing.expect(pointOnRectBoundary(head_rect, route.end));
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

    const default_a = nodeIdByLabel(&default_graph, "a");
    const default_b = nodeIdByLabel(&default_graph, "b");
    const default_c = nodeIdByLabel(&default_graph, "c");
    const spaced_a = nodeIdByLabel(&spaced_graph, "a");
    const spaced_b = nodeIdByLabel(&spaced_graph, "b");
    const spaced_c = nodeIdByLabel(&spaced_graph, "c");

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

    const a = nodeIdByLabel(&graph, "a");
    const b = nodeIdByLabel(&graph, "b");
    const c = nodeIdByLabel(&graph, "c");
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

    const min_sized = nodeIdByLabel(&graph, "min_sized");
    const fixed = nodeIdByLabel(&graph, "fixed");
    const shape_fixed = nodeIdByLabel(&graph, "shape_fixed");
    try std.testing.expect(layout.nodes[min_sized].width >= 216);
    try std.testing.expect(layout.nodes[min_sized].height >= 108);
    try std.testing.expect(@abs(layout.nodes[fixed].width - 72.0) < 0.01);
    try std.testing.expect(@abs(layout.nodes[fixed].height - 36.0) < 0.01);
    try std.testing.expect(layout.nodes[shape_fixed].width > 72.0);
    try std.testing.expect(layout.nodes[shape_fixed].height >= 36.0);

    const svg = try renderSvgAlloc(allocator, &graph, &layout, .{});
    defer allocator.free(svg);
    try std.testing.expect(std.mem.indexOf(u8, svg, "an even longer label than the fixed circle") != null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "r=\"18\" fill=\"none\" stroke=\"black\"") != null);
}
