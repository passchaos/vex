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
    box,
    circle,
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

pub const EdgeOptions = struct {
    label: ?[]const u8 = null,
    color: ?[]const u8 = null,
    weight: ?f64 = null,
    constraint: ?bool = null,
    min_len: ?usize = null,
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
    color: []const u8 = "#6b7280",
    weight: f64 = 1.0,
    constraint: bool = true,
    min_len: usize = 1,
    attrs: std.ArrayList(Attr) = .empty,
};

const NodeDefaults = struct {
    color: []const u8 = "#f8fafc",
    shape: Shape = .ellipse,
};

const EdgeDefaults = struct {
    color: []const u8 = "#6b7280",
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
        const node_color = try allocator.dupe(u8, "#f8fafc");
        errdefer allocator.free(node_color);
        const edge_color = try allocator.dupe(u8, "#6b7280");
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
        for (self.rank_constraints.items) |constraint| {
            self.allocator.free(constraint.node_ids);
        }
        freeAttrList(self.allocator, &self.node_default_attrs);
        freeAttrList(self.allocator, &self.edge_default_attrs);
        self.nodes.deinit(self.allocator);
        self.edges.deinit(self.allocator);
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

        const owned_label = if (options.label) |label| try self.allocator.dupe(u8, label) else null;
        errdefer if (owned_label) |label| self.allocator.free(label);
        const owned_color = try self.allocator.dupe(u8, options.color orelse self.edge_defaults.color);
        errdefer self.allocator.free(owned_color);

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
            if (n.label.ptr != n.name.ptr) self.allocator.free(n.label);
            n.label = try self.allocator.dupe(u8, value);
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
            if (e.label) |label| self.allocator.free(label);
            e.label = try self.allocator.dupe(u8, value);
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
    if (std.ascii.eqlIgnoreCase(value, "circle")) return .circle;
    return .ellipse;
}

fn shapeName(shape: Shape) []const u8 {
    return switch (shape) {
        .ellipse => "ellipse",
        .box => "box",
        .circle => "circle",
    };
}

fn parseBool(value: []const u8) ?bool {
    if (std.ascii.eqlIgnoreCase(value, "true") or std.mem.eql(u8, value, "1")) return true;
    if (std.ascii.eqlIgnoreCase(value, "false") or std.mem.eql(u8, value, "0")) return false;
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

fn containsNode(nodes: []const NodeId, id: NodeId) bool {
    for (nodes) |existing| if (existing == id) return true;
    return false;
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

    fn init(allocator: std.mem.Allocator, source: []const u8) !Parser {
        var lexer: Lexer = .{ .source = source };
        const first = try lexer.next();
        return .{ .allocator = allocator, .lexer = lexer, .current = first };
    }

    fn parse(self: *Parser) !Graph {
        defer self.collectors.deinit(self.allocator);
        defer self.rank_scopes.deinit(self.allocator);
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

        const first_name = try self.parseNodeIdText();
        defer self.allocator.free(first_name);

        if (self.match(.equal)) {
            const value = try self.parseIdText();
            defer self.allocator.free(value);
            if (try self.recordRankAttr(first_name, value)) return;
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
            try self.parseEdgeTail(graph, &first);
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
        var operands = std.ArrayList(NodeSet).empty;
        defer {
            for (operands.items) |*operand| operand.deinit(self.allocator);
            operands.deinit(self.allocator);
        }
        try operands.append(self.allocator, first.*);
        first.* = .empty;

        while (self.current.tag == .arrow or self.current.tag == .dashdash) {
            const op = self.current.tag;
            try self.advance();
            if (graph.directed and op != .arrow) return error.EdgeOpMismatch;
            if (!graph.directed and op != .dashdash) return error.EdgeOpMismatch;
            try operands.append(self.allocator, try self.parseOperand(graph));
        }

        var attrs = AttrList.empty;
        defer freeTempAttrs(self.allocator, &attrs);
        try self.parseAttrLists(&attrs);

        var i: usize = 0;
        while (i + 1 < operands.items.len) : (i += 1) {
            for (operands.items[i].items) |from| {
                for (operands.items[i + 1].items) |to| {
                    const edge_id = try graph.edge(from, to, .{});
                    for (attrs.items) |attr| try graph.setEdgeAttr(edge_id, attr.name, attr.value);
                }
            }
        }
    }

    fn parseOperand(self: *Parser, graph: *Graph) anyerror!NodeSet {
        if (self.isSubgraphStart()) return self.parseSubgraph(graph);
        return self.parseNodeList(graph);
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

    fn parseSubgraph(self: *Parser, graph: *Graph) anyerror!NodeSet {
        if (self.matchKeyword("subgraph")) {
            if (self.current.tag == .id or self.current.tag == .string or self.current.tag == .html) try self.advance();
        }
        try self.expect(.lbrace);

        var defaults = try DefaultScope.snapshot(self.allocator, graph);
        defer defaults.deinit(self.allocator);

        var nodes = NodeSet.empty;
        errdefer nodes.deinit(self.allocator);
        var rank_kind: ?RankKind = null;
        try self.collectors.append(self.allocator, &nodes);
        errdefer self.collectors.items.len -= 1;
        try self.rank_scopes.append(self.allocator, &rank_kind);
        errdefer self.rank_scopes.items.len -= 1;
        try self.parseStmtList(graph);
        self.collectors.items.len -= 1;
        self.rank_scopes.items.len -= 1;
        try self.expect(.rbrace);
        if (rank_kind) |kind| try graph.addRankConstraint(kind, nodes.items);
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

pub const Layout = struct {
    allocator: std.mem.Allocator,
    nodes: []NodeLayout,
    ranks: []usize,
    rank_depths: []f64,
    rank_heights: []f64,
    margin: f64,
    width: f64,
    height: f64,

    pub fn deinit(self: *Layout) void {
        self.allocator.free(self.nodes);
        self.allocator.free(self.ranks);
        self.allocator.free(self.rank_depths);
        self.allocator.free(self.rank_heights);
        self.* = undefined;
    }
};

pub const LayoutOptions = struct {
    node_width: f64 = 120,
    node_height: f64 = 56,
    rank_gap: f64 = 110,
    node_gap: f64 = 56,
    margin: f64 = 40,
    label_char_width: f64 = 8,
    label_line_height: f64 = 18,
    node_padding_x: f64 = 28,
    node_padding_y: f64 = 16,
    crossing_passes: usize = 8,
    coordinate_passes: usize = 4,
};

pub fn layoutLayered(allocator: std.mem.Allocator, graph: *const Graph, options: LayoutOptions) !Layout {
    const n = graph.nodes.items.len;
    const nodes = try allocator.alloc(NodeLayout, n);
    errdefer allocator.free(nodes);
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
            .ranks = layout_ranks,
            .rank_depths = empty_rank_depths,
            .rank_heights = empty_rank_heights,
            .margin = options.margin,
            .width = options.margin * 2.0,
            .height = options.margin * 2.0,
        };
    }

    const ranks = try allocator.alloc(usize, n);
    defer allocator.free(ranks);
    @memset(ranks, 0);

    var indegree = try allocator.alloc(usize, n);
    defer allocator.free(indegree);
    @memset(indegree, 0);

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
            if (indegree[edge_item.to] > 0) {
                indegree[edge_item.to] -= 1;
                if (indegree[edge_item.to] == 0) try queue.append(allocator, edge_item.to);
            }
        }
    }

    // Cycles leave some nodes unvisited. Keep them deterministic and close to
    // their predecessors rather than failing layout for non-DAG input.
    for (graph.edges.items) |edge_item| {
        if (!edge_item.constraint) continue;
        if (ranks[edge_item.to] <= ranks[edge_item.from] and edge_item.to != edge_item.from) {
            ranks[edge_item.to] = ranks[edge_item.from] + @max(edge_item.min_len, 1);
        }
    }

    applyRankConstraints(graph, ranks);

    var max_rank: usize = 0;
    for (ranks) |rank| max_rank = @max(max_rank, rank);

    var levels = try allocator.alloc(std.ArrayList(NodeId), max_rank + 1);
    defer allocator.free(levels);
    for (levels) |*level| level.* = .empty;
    defer for (levels) |*level| level.deinit(allocator);

    for (ranks, 0..) |rank, id| try levels[rank].append(allocator, id);
    try reduceLayerCrossings(allocator, graph, levels, ranks, options.crossing_passes);

    const sizes = try allocator.alloc(NodeSize, n);
    defer allocator.free(sizes);
    for (graph.nodes.items, 0..) |node_item, id| sizes[id] = measureNode(node_item, options);

    const axis_sizes = try allocator.alloc(NodeSize, n);
    defer allocator.free(axis_sizes);
    for (sizes, 0..) |size, id| axis_sizes[id] = orientSizeForLayout(size, graph.rankdir);

    const centers = try allocator.alloc(f64, n);
    defer allocator.free(centers);
    @memset(centers, 0);

    var rank_widths = try allocator.alloc(f64, levels.len);
    defer allocator.free(rank_widths);
    var max_width: f64 = 0;
    for (levels, 0..) |level, rank| {
        rank_widths[rank] = packLevelFromLeft(level.items, axis_sizes, options.node_gap, centers);
        max_width = @max(max_width, rank_widths[rank]);
    }

    for (levels, 0..) |level, rank| {
        const shift = (max_width - rank_widths[rank]) / 2.0;
        for (level.items) |id| centers[id] += shift;
    }

    refineLayerCoordinates(graph, levels, ranks, axis_sizes, centers, options);
    normalizeCenters(centers, axis_sizes);

    var total_along: f64 = 0;
    for (centers, 0..) |center, id| total_along = @max(total_along, center + axis_sizes[id].width / 2.0);

    var rank_heights = try allocator.alloc(f64, levels.len);
    defer allocator.free(rank_heights);
    @memset(rank_heights, options.node_height);
    for (levels, 0..) |level, rank| {
        for (level.items) |id| rank_heights[rank] = @max(rank_heights[rank], axis_sizes[id].height);
    }

    var rank_depths = try allocator.alloc(f64, levels.len);
    errdefer allocator.free(rank_depths);
    const layout_rank_heights = try allocator.dupe(f64, rank_heights);
    errdefer allocator.free(layout_rank_heights);
    var total_depth: f64 = 0;
    for (rank_heights, 0..) |rank_height, rank| {
        rank_depths[rank] = total_depth;
        total_depth += rank_height;
        if (rank + 1 < rank_heights.len) total_depth += options.rank_gap;
    }

    for (graph.nodes.items, 0..) |_, id| {
        const rank = ranks[id];
        const depth = rank_depths[rank] + rank_heights[rank] / 2.0;
        const center = orientPoint(graph.rankdir, centers[id], depth, total_depth, options.margin);
        nodes[id] = .{ .center = center, .width = sizes[id].width, .height = sizes[id].height };
    }
    @memcpy(layout_ranks, ranks);

    const base_width = total_along + options.margin * 2.0;
    const base_height = total_depth + options.margin * 2.0;
    return .{
        .allocator = allocator,
        .nodes = nodes,
        .ranks = layout_ranks,
        .rank_depths = rank_depths,
        .rank_heights = layout_rank_heights,
        .margin = options.margin,
        .width = if (graph.rankdir == .LR or graph.rankdir == .RL) base_height else base_width,
        .height = if (graph.rankdir == .LR or graph.rankdir == .RL) base_width else base_height,
    };
}

const NodeSize = struct {
    width: f64,
    height: f64,
};

fn measureNode(node_item: Node, options: LayoutOptions) NodeSize {
    const line_count = labelLineCount(node_item.label);
    const max_line_len = labelMaxLineLen(node_item.label);
    const text_width = @as(f64, @floatFromInt(max_line_len)) * options.label_char_width;
    const text_height = @as(f64, @floatFromInt(line_count)) * options.label_line_height;
    var width = @max(options.node_width, text_width + options.node_padding_x * 2.0);
    var height = @max(options.node_height, text_height + options.node_padding_y * 2.0);
    if (node_item.shape == .circle) {
        const diameter = @max(width, height);
        width = diameter;
        height = diameter;
    }
    return .{ .width = width, .height = height };
}

fn orientSizeForLayout(size: NodeSize, rankdir: RankDir) NodeSize {
    return switch (rankdir) {
        .TB, .BT => size,
        .LR, .RL => .{ .width = size.height, .height = size.width },
    };
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
                median_positions[count] = pos;
                count += 1;
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
            compactLevelCenters(levels[rank - 1].items, centers, sizes, options.node_gap);
        }
    }
}

fn nudgeLevelTowardNeighbors(graph: *const Graph, ranks: []const usize, level: []const NodeId, centers: []f64, use_parents: bool) void {
    const blend = 0.65;
    for (level) |node_id| {
        var sum: f64 = 0;
        var count: usize = 0;
        for (graph.edges.items) |edge_item| {
            const neighbor = if (use_parents and edge_item.to == node_id and ranks[edge_item.from] < ranks[node_id])
                edge_item.from
            else if (!use_parents and edge_item.from == node_id and ranks[edge_item.to] > ranks[node_id])
                edge_item.to
            else
                continue;
            sum += centers[neighbor];
            count += 1;
        }
        if (count > 0) {
            const target = sum / @as(f64, @floatFromInt(count));
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

fn orientPoint(rankdir: RankDir, along: f64, depth: f64, total_depth: f64, margin: f64) Point {
    const base_height = total_depth + margin * 2.0;
    return switch (rankdir) {
        .TB => .{ .x = margin + along, .y = margin + depth },
        .BT => .{ .x = margin + along, .y = base_height - (margin + depth) },
        .LR => .{ .x = margin + depth, .y = margin + along },
        .RL => .{ .x = base_height - (margin + depth), .y = margin + along },
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
    font_family: []const u8 = "Inter, ui-sans-serif, system-ui, sans-serif",
    show_title: bool = true,
};

pub fn renderSvg(writer: *Io.Writer, graph: *const Graph, layout: *const Layout, options: SvgOptions) Io.Writer.Error!void {
    try writer.print(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{d:.0}\" height=\"{d:.0}\" viewBox=\"0 0 {d:.0} {d:.0}\">\n",
        .{ layout.width, layout.height, layout.width, layout.height },
    );
    try writer.print("<rect width=\"100%\" height=\"100%\" fill=\"{s}\"/>\n", .{options.background});
    if (options.show_title) {
        try writer.print("<text x=\"16\" y=\"24\" font-family=\"{s}\" font-size=\"14\" fill=\"#475569\">", .{options.font_family});
        try writeXmlEscaped(writer, graph.name);
        try writer.writeAll("</text>\n");
    }
    if (graph.directed) {
        try writer.writeAll("<defs>\n");
        for (graph.edges.items) |edge_item| {
            const visual = resolveEdgeVisual(edge_item);
            try writer.print("<marker id=\"arrow-{d}\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto\"><path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"{s}\"/></marker>\n", .{ edge_item.id, visual.stroke });
        }
        try writer.writeAll("</defs>\n");
    }

    try writer.writeAll("<g class=\"edges\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\">\n");
    for (graph.edges.items) |edge_item| {
        const visual = resolveEdgeVisual(edge_item);
        if (visual.hidden) continue;
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
            if (graph.directed and visual.marker_end) try writer.print(" marker-end=\"url(#arrow-{d})\"", .{edge_item.id});
            try writer.writeAll("/>\n");
            if (edge_item.label) |label| {
                try renderSvgTextBlock(writer, label, route.label.x, route.label.y, 12, visual.font_color, options.font_family, true, true);
            }
            continue;
        }

        const offset = parallelEdgeOffset(graph, edge_item.id);
        const route = edgeRoute(layout.nodes[edge_item.from], layout.nodes[edge_item.to], graph.rankdir, offset);
        try writer.writeAll("<path d=\"");
        try writeEdgePath(writer, layout, edge_item, graph.rankdir, offset, route);
        try writer.print("\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{ visual.stroke, visual.width });
        try writeSvgDash(writer, visual.dash);
        if (graph.directed and visual.marker_end) try writer.print(" marker-end=\"url(#arrow-{d})\"", .{edge_item.id});
        try writer.writeAll("/>\n");
        if (edge_item.label) |label| {
            try renderSvgTextBlock(writer, label, route.label.x, route.label.y - 6.0, 12, visual.font_color, options.font_family, true, true);
        }
    }
    try writer.writeAll("</g>\n<g class=\"nodes\">\n");

    for (graph.nodes.items) |node_item| {
        const visual = resolveNodeVisual(node_item);
        if (visual.hidden) continue;
        const l = layout.nodes[node_item.id];
        switch (node_item.shape) {
            .box => {
                try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{
                    l.center.x - l.width / 2.0,
                    l.center.y - l.height / 2.0,
                    l.width,
                    l.height,
                    visual.radius,
                    visual.fill,
                    visual.stroke,
                    visual.width,
                });
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            },
            .circle => {
                try writer.print("<circle cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{ l.center.x, l.center.y, @min(l.width, l.height) / 2.0, visual.fill, visual.stroke, visual.width });
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            },
            .ellipse => {
                try writer.print("<ellipse cx=\"{d:.1}\" cy=\"{d:.1}\" rx=\"{d:.1}\" ry=\"{d:.1}\" fill=\"{s}\" stroke=\"{s}\" stroke-width=\"{d:.1}\"", .{ l.center.x, l.center.y, l.width / 2.0, l.height / 2.0, visual.fill, visual.stroke, visual.width });
                try writeSvgDash(writer, visual.dash);
                try writer.writeAll("/>\n");
            },
        }
        try renderSvgTextBlock(writer, node_item.label, l.center.x, l.center.y, 14, visual.font_color, options.font_family, false, false);
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

const NodeVisual = struct {
    fill: []const u8,
    stroke: []const u8,
    font_color: []const u8,
    width: f64,
    radius: f64,
    dash: DashStyle,
    hidden: bool,
};

const EdgeVisual = struct {
    stroke: []const u8,
    font_color: []const u8,
    width: f64,
    dash: DashStyle,
    marker_end: bool,
    hidden: bool,
};

fn resolveNodeVisual(node_item: Node) NodeVisual {
    const style = attrValue(node_item.attrs.items, "style");
    const filled = styleHas(style, "filled");
    const invisible = styleHas(style, "invis");
    const rounded = styleHas(style, "rounded");
    const dashed = styleHas(style, "dashed");
    const dotted = styleHas(style, "dotted");
    const fill = attrValue(node_item.attrs.items, "fillcolor") orelse if (filled) node_item.color else "#f8fafc";
    return .{
        .fill = fill,
        .stroke = attrValue(node_item.attrs.items, "color") orelse "#334155",
        .font_color = attrValue(node_item.attrs.items, "fontcolor") orelse "#0f172a",
        .width = parseAttrFloat(node_item.attrs.items, "penwidth", 1.5),
        .radius = if (rounded) 10 else 0,
        .dash = if (dotted) .dotted else if (dashed) .dashed else .none,
        .hidden = invisible,
    };
}

fn resolveEdgeVisual(edge_item: Edge) EdgeVisual {
    const style = attrValue(edge_item.attrs.items, "style");
    const arrowhead = attrValue(edge_item.attrs.items, "arrowhead");
    return .{
        .stroke = attrValue(edge_item.attrs.items, "color") orelse edge_item.color,
        .font_color = attrValue(edge_item.attrs.items, "fontcolor") orelse "#475569",
        .width = parseAttrFloat(edge_item.attrs.items, "penwidth", 1.8),
        .dash = if (styleHas(style, "dotted")) .dotted else if (styleHas(style, "dashed")) .dashed else .none,
        .marker_end = arrowhead == null or !std.ascii.eqlIgnoreCase(arrowhead.?, "none"),
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

fn writeEdgePath(writer: *Io.Writer, layout: *const Layout, edge_item: Edge, rankdir: RankDir, offset: f64, direct_route: EdgeRoute) Io.Writer.Error!void {
    const waypoint_count = longEdgeWaypointCount(layout, edge_item);
    if (waypoint_count == 0) {
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
        try writeSmoothSegment(writer, current, next, rankdir);
        current = next;
    }
    try writeSmoothSegment(writer, current, direct_route.end, rankdir);
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
    const t = @as(f64, @floatFromInt(index + 1)) / @as(f64, @floatFromInt(count + 1));
    const from_center = layout.nodes[edge_item.from].center;
    const to_center = layout.nodes[edge_item.to].center;
    const along = if (rankdir == .TB or rankdir == .BT)
        from_center.x + (to_center.x - from_center.x) * t
    else
        from_center.y + (to_center.y - from_center.y) * t;
    const depth = rankDepthCenter(layout, rank);
    return offsetPoint(orientWaypoint(rankdir, along, depth, layout), rankdir, offset);
}

fn rankDepthCenter(layout: *const Layout, rank: usize) f64 {
    if (rank >= layout.rank_depths.len or rank >= layout.rank_heights.len) return 0;
    return layout.rank_depths[rank] + layout.rank_heights[rank] / 2.0;
}

fn orientWaypoint(rankdir: RankDir, along_screen: f64, depth: f64, layout: *const Layout) Point {
    return switch (rankdir) {
        .TB => .{ .x = along_screen, .y = layout.margin + depth },
        .BT => .{ .x = along_screen, .y = layout.height - (layout.margin + depth) },
        .LR => .{ .x = layout.margin + depth, .y = along_screen },
        .RL => .{ .x = layout.width - (layout.margin + depth), .y = along_screen },
    };
}

fn writeSmoothSegment(writer: *Io.Writer, from: Point, to: Point, rankdir: RankDir) Io.Writer.Error!void {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const curve = @max(18.0, @min(96.0, if (rankdir == .LR or rankdir == .RL) @abs(dx) * 0.5 else @abs(dy) * 0.5));
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
    const curve = @max(24.0, @min(160.0, if (rankdir == .LR or rankdir == .RL) @abs(dx) * 0.45 else @abs(dy) * 0.45));
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
    _ = toward;
    return switch (rankdir) {
        .TB => .{ .x = node.center.x, .y = node.center.y + (if (leaving) node.height / 2.0 else -node.height / 2.0) },
        .BT => .{ .x = node.center.x, .y = node.center.y + (if (leaving) -node.height / 2.0 else node.height / 2.0) },
        .LR => .{ .x = node.center.x + (if (leaving) node.width / 2.0 else -node.width / 2.0), .y = node.center.y },
        .RL => .{ .x = node.center.x + (if (leaving) -node.width / 2.0 else node.width / 2.0), .y = node.center.y },
    };
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

fn renderSvgTextBlock(writer: *Io.Writer, text: []const u8, x: f64, center_y: f64, font_size: usize, fill: []const u8, font_family: []const u8, label_background: bool, dominant_middle: bool) Io.Writer.Error!void {
    const line_count = labelLineCount(text);
    const line_height = @as(f64, @floatFromInt(font_size)) * 1.25;
    const block_height = @as(f64, @floatFromInt(line_count)) * line_height;
    const first_y = center_y - block_height / 2.0 + line_height * 0.72;

    if (label_background) {
        const max_len = labelMaxLineLen(text);
        const width = @as(f64, @floatFromInt(max_len * font_size)) * 0.62 + 12.0;
        const height = block_height + 8.0;
        try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"4\" fill=\"#ffffff\" stroke=\"#e2e8f0\" opacity=\"0.92\"/>\n", .{
            x - width / 2.0,
            center_y - height / 2.0,
            width,
            height,
        });
    }

    try writer.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\" font-family=\"{s}\" font-size=\"{d}\" fill=\"{s}\"", .{ x, first_y, font_family, font_size, fill });
    if (dominant_middle and line_count == 1) try writer.writeAll(" dominant-baseline=\"middle\"");
    try writer.writeAll(">");
    var lines = std.mem.splitScalar(u8, text, '\n');
    var idx: usize = 0;
    while (lines.next()) |line| : (idx += 1) {
        if (idx == 0) {
            try writer.writeAll("<tspan x=\"");
            try writer.print("{d:.1}", .{x});
            try writer.writeAll("\">");
        } else {
            try writer.print("<tspan x=\"{d:.1}\" dy=\"{d:.1}\">", .{ x, line_height });
        }
        try writeXmlEscaped(writer, line);
        try writer.writeAll("</tspan>");
    }
    try writer.writeAll("</text>\n");
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
    if (value.len != 7 or value[0] != '#') return null;
    return .{
        std.fmt.parseInt(u8, value[1..3], 16) catch return null,
        std.fmt.parseInt(u8, value[3..5], 16) catch return null,
        std.fmt.parseInt(u8, value[5..7], 16) catch return null,
        255,
    };
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
    try std.testing.expectEqualStrings("left\nright\\N quote\" slash\\ keep\\x", graph.nodes.items[esc].label);
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
    try std.testing.expect(layout.nodes[wide].width > 180);
    try std.testing.expect(layout.nodes[wide].height > 56);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker id=\"arrow-0\"") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, svg, "marker-end=\"url(#arrow-0)\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, svg, "loop") != null);

    const first_offset = parallelEdgeOffset(&graph, 0);
    const second_offset = parallelEdgeOffset(&graph, 1);
    try std.testing.expect(first_offset < 0);
    try std.testing.expect(second_offset > 0);
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
    try std.testing.expectEqualStrings("#f8fafc", graph.nodes.items[c].color);
    try std.testing.expectEqualStrings("#f8fafc", graph.nodes.items[e].color);

    try std.testing.expectEqualStrings("#dc2626", graph.edges.items[0].color);
    try std.testing.expectEqualStrings("#6b7280", graph.edges.items[1].color);
    try std.testing.expectEqualStrings("#6b7280", graph.edges.items[2].color);
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
