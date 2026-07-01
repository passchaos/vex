//! Topos core library.
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

pub const Attr = struct {
    name: []const u8,
    value: []const u8,
};

pub const EdgeOptions = struct {
    label: ?[]const u8 = null,
    color: ?[]const u8 = null,
    weight: ?f64 = null,
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
    attrs: std.ArrayList(Attr) = .empty,
};

const NodeDefaults = struct {
    color: []const u8 = "#f8fafc",
    shape: Shape = .ellipse,
};

const EdgeDefaults = struct {
    color: []const u8 = "#6b7280",
    weight: f64 = 1.0,
};

pub const Graph = struct {
    allocator: std.mem.Allocator,
    directed: bool,
    strict: bool,
    name: []const u8,
    rankdir: RankDir,
    nodes: std.ArrayList(Node) = .empty,
    edges: std.ArrayList(Edge) = .empty,
    attrs: std.ArrayList(Attr) = .empty,
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
        self.nodes.deinit(self.allocator);
        self.edges.deinit(self.allocator);
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

        var attrs = std.ArrayList(Attr).empty;
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

        var attrs = std.ArrayList(Attr).empty;
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

    pub fn setGraphAttr(self: *Graph, name: []const u8, value: []const u8) !void {
        if (std.ascii.eqlIgnoreCase(name, "rankdir")) {
            if (RankDir.fromString(value)) |rankdir| self.rankdir = rankdir;
        }
        try setAttrInList(self.allocator, &self.attrs, name, value);
    }

    pub fn setDefaultNodeAttr(self: *Graph, name: []const u8, value: []const u8) !void {
        if (std.ascii.eqlIgnoreCase(name, "color") or std.ascii.eqlIgnoreCase(name, "fillcolor")) {
            const owned = try self.allocator.dupe(u8, value);
            self.allocator.free(self.node_defaults.color);
            self.node_defaults.color = owned;
        } else if (std.ascii.eqlIgnoreCase(name, "shape")) {
            self.node_defaults.shape = parseShape(value);
        }
    }

    pub fn setDefaultEdgeAttr(self: *Graph, name: []const u8, value: []const u8) !void {
        if (std.ascii.eqlIgnoreCase(name, "color")) {
            const owned = try self.allocator.dupe(u8, value);
            self.allocator.free(self.edge_defaults.color);
            self.edge_defaults.color = owned;
        } else if (std.ascii.eqlIgnoreCase(name, "weight")) {
            self.edge_defaults.weight = std.fmt.parseFloat(f64, value) catch self.edge_defaults.weight;
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
        }
        try setAttrInList(self.allocator, &e.attrs, name, value);
    }
};

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
            '<' => blk: {
                var depth: usize = 1;
                while (self.index < self.source.len) {
                    const ch = self.advance();
                    if (ch == '<') depth += 1;
                    if (ch == '>') {
                        depth -= 1;
                        if (depth == 0) break;
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
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '.' or c == '-';
}

const AttrList = std.ArrayList(Attr);
const NodeSet = std.ArrayList(NodeId);

fn containsNode(nodes: []const NodeId, id: NodeId) bool {
    for (nodes) |existing| if (existing == id) return true;
    return false;
}

const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    current: Token,
    collectors: std.ArrayList(*NodeSet) = .empty,

    fn init(allocator: std.mem.Allocator, source: []const u8) !Parser {
        var lexer: Lexer = .{ .source = source };
        const first = try lexer.next();
        return .{ .allocator = allocator, .lexer = lexer, .current = first };
    }

    fn parse(self: *Parser) !Graph {
        defer self.collectors.deinit(self.allocator);
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
            for (attrs.items) |attr| try graph.setGraphAttr(attr.name, attr.value);
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
            var first = try self.parseSubgraph(graph);
            defer first.deinit(self.allocator);
            if (self.current.tag == .arrow or self.current.tag == .dashdash) {
                try self.parseEdgeTail(graph, &first);
            }
            return;
        }

        const first_name = try self.parseNodeIdText();
        defer self.allocator.free(first_name);

        if (self.match(.equal)) {
            const value = try self.parseIdText();
            defer self.allocator.free(value);
            try graph.setGraphAttr(first_name, value);
            return;
        }

        const first_id = try graph.node(first_name);
        try self.recordNode(first_id);
        var first = NodeSet.empty;
        defer first.deinit(self.allocator);
        try first.append(self.allocator, first_id);

        if (self.current.tag == .arrow or self.current.tag == .dashdash) {
            try self.parseEdgeTail(graph, &first);
        } else {
            var attrs = AttrList.empty;
            defer freeTempAttrs(self.allocator, &attrs);
            try self.parseAttrLists(&attrs);
            for (attrs.items) |attr| try graph.setNodeAttr(first_id, attr.name, attr.value);
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
        const name = try self.parseNodeIdText();
        defer self.allocator.free(name);
        const id = try graph.node(name);
        try self.recordNode(id);
        var nodes = NodeSet.empty;
        errdefer nodes.deinit(self.allocator);
        try nodes.append(self.allocator, id);
        return nodes;
    }

    fn parseSubgraph(self: *Parser, graph: *Graph) anyerror!NodeSet {
        if (self.matchKeyword("subgraph")) {
            if (self.current.tag == .id or self.current.tag == .string or self.current.tag == .html) try self.advance();
        }
        try self.expect(.lbrace);

        var nodes = NodeSet.empty;
        errdefer nodes.deinit(self.allocator);
        try self.collectors.append(self.allocator, &nodes);
        errdefer self.collectors.items.len -= 1;
        try self.parseStmtList(graph);
        self.collectors.items.len -= 1;
        try self.expect(.rbrace);
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

    fn parseAttrLists(self: *Parser, attrs: *AttrList) !void {
        while (self.match(.lbracket)) {
            while (self.current.tag != .rbracket and self.current.tag != .eof) {
                if (self.current.tag == .comma or self.current.tag == .semicolon) {
                    try self.advance();
                    continue;
                }
                const name = try self.parseIdText();
                errdefer self.allocator.free(name);
                try self.expect(.equal);
                const value = try self.parseIdText();
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
        const value = if (self.current.tag == .string)
            try dupeDotString(self.allocator, self.current.lexeme)
        else
            try self.allocator.dupe(u8, self.current.lexeme);
        try self.advance();
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
            'n' => try out.append(allocator, '\n'),
            'r' => try out.append(allocator, '\r'),
            't' => try out.append(allocator, '\t'),
            '\n' => {},
            else => try out.append(allocator, escaped),
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
    width: f64,
    height: f64,

    pub fn deinit(self: *Layout) void {
        self.allocator.free(self.nodes);
        self.* = undefined;
    }
};

pub const LayoutOptions = struct {
    node_width: f64 = 120,
    node_height: f64 = 56,
    rank_gap: f64 = 110,
    node_gap: f64 = 56,
    margin: f64 = 40,
};

pub fn layoutLayered(allocator: std.mem.Allocator, graph: *const Graph, options: LayoutOptions) !Layout {
    const n = graph.nodes.items.len;
    const ranks = try allocator.alloc(usize, n);
    defer allocator.free(ranks);
    @memset(ranks, 0);

    var indegree = try allocator.alloc(usize, n);
    defer allocator.free(indegree);
    @memset(indegree, 0);

    for (graph.edges.items) |edge_item| {
        if (edge_item.to < n) indegree[edge_item.to] += 1;
    }

    var queue = std.ArrayList(NodeId).empty;
    defer queue.deinit(allocator);
    for (indegree, 0..) |degree, id| if (degree == 0) try queue.append(allocator, id);

    var head: usize = 0;
    while (head < queue.items.len) : (head += 1) {
        const u = queue.items[head];
        for (graph.edges.items) |edge_item| {
            if (edge_item.from != u) continue;
            if (ranks[edge_item.to] < ranks[u] + 1) ranks[edge_item.to] = ranks[u] + 1;
            if (indegree[edge_item.to] > 0) {
                indegree[edge_item.to] -= 1;
                if (indegree[edge_item.to] == 0) try queue.append(allocator, edge_item.to);
            }
        }
    }

    // Cycles leave some nodes unvisited. Keep them deterministic and close to
    // their predecessors rather than failing layout for non-DAG input.
    for (graph.edges.items) |edge_item| {
        if (ranks[edge_item.to] <= ranks[edge_item.from] and edge_item.to != edge_item.from) {
            ranks[edge_item.to] = ranks[edge_item.from] + 1;
        }
    }

    var max_rank: usize = 0;
    for (ranks) |rank| max_rank = @max(max_rank, rank);

    var rank_counts = try allocator.alloc(usize, max_rank + 1);
    defer allocator.free(rank_counts);
    @memset(rank_counts, 0);
    for (ranks) |rank| rank_counts[rank] += 1;

    var rank_offsets = try allocator.alloc(usize, max_rank + 1);
    defer allocator.free(rank_offsets);
    @memset(rank_offsets, 0);

    const nodes = try allocator.alloc(NodeLayout, n);
    errdefer allocator.free(nodes);

    var max_width: f64 = 0;
    for (rank_counts) |count| {
        const count_f: f64 = @floatFromInt(count);
        const rank_width = if (count == 0) 0 else count_f * options.node_width + (count_f - 1) * options.node_gap;
        max_width = @max(max_width, rank_width);
    }

    const depth_f: f64 = @floatFromInt(max_rank + 1);
    const total_depth = depth_f * options.node_height + (depth_f - 1) * options.rank_gap;

    for (graph.nodes.items, 0..) |_, id| {
        const rank = ranks[id];
        const slot = rank_offsets[rank];
        rank_offsets[rank] += 1;
        const count_f: f64 = @floatFromInt(rank_counts[rank]);
        const rank_width = count_f * options.node_width + (count_f - 1) * options.node_gap;
        const slot_f: f64 = @floatFromInt(slot);
        const along = options.margin + (max_width - rank_width) / 2.0 + options.node_width / 2.0 + slot_f * (options.node_width + options.node_gap);
        const depth = options.margin + options.node_height / 2.0 + @as(f64, @floatFromInt(rank)) * (options.node_height + options.rank_gap);
        const center = orientPoint(graph.rankdir, along, depth, max_width, total_depth, options.margin);
        nodes[id] = .{ .center = center, .width = options.node_width, .height = options.node_height };
    }

    const base_width = max_width + options.margin * 2.0;
    const base_height = total_depth + options.margin * 2.0;
    return .{
        .allocator = allocator,
        .nodes = nodes,
        .width = if (graph.rankdir == .LR or graph.rankdir == .RL) base_height else base_width,
        .height = if (graph.rankdir == .LR or graph.rankdir == .RL) base_width else base_height,
    };
}

fn orientPoint(rankdir: RankDir, along: f64, depth: f64, max_width: f64, total_depth: f64, margin: f64) Point {
    _ = max_width;
    const base_height = total_depth + margin * 2.0;
    return switch (rankdir) {
        .TB => .{ .x = along, .y = depth },
        .BT => .{ .x = along, .y = base_height - depth },
        .LR => .{ .x = depth, .y = along },
        .RL => .{ .x = base_height - depth, .y = along },
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
        try writer.writeAll("<defs><marker id=\"arrow\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto-start-reverse\"><path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"#64748b\"/></marker></defs>\n");
    }

    try writer.writeAll("<g class=\"edges\" fill=\"none\" stroke-linecap=\"round\">\n");
    for (graph.edges.items) |edge_item| {
        const a = layout.nodes[edge_item.from].center;
        const b = layout.nodes[edge_item.to].center;
        try writer.print("<path d=\"M {d:.1} {d:.1} L {d:.1} {d:.1}\" stroke=\"{s}\" stroke-width=\"1.8\"", .{ a.x, a.y, b.x, b.y, edge_item.color });
        if (graph.directed) try writer.writeAll(" marker-end=\"url(#arrow)\"");
        try writer.writeAll("/>\n");
        if (edge_item.label) |label| {
            try writer.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\" font-family=\"{s}\" font-size=\"12\" fill=\"#475569\">", .{ (a.x + b.x) / 2.0, (a.y + b.y) / 2.0 - 6.0, options.font_family });
            try writeXmlEscaped(writer, label);
            try writer.writeAll("</text>\n");
        }
    }
    try writer.writeAll("</g>\n<g class=\"nodes\">\n");

    for (graph.nodes.items) |node_item| {
        const l = layout.nodes[node_item.id];
        switch (node_item.shape) {
            .box => try writer.print("<rect x=\"{d:.1}\" y=\"{d:.1}\" width=\"{d:.1}\" height=\"{d:.1}\" rx=\"10\" fill=\"{s}\" stroke=\"#334155\" stroke-width=\"1.5\"/>\n", .{ l.center.x - l.width / 2.0, l.center.y - l.height / 2.0, l.width, l.height, node_item.color }),
            .circle => try writer.print("<circle cx=\"{d:.1}\" cy=\"{d:.1}\" r=\"{d:.1}\" fill=\"{s}\" stroke=\"#334155\" stroke-width=\"1.5\"/>\n", .{ l.center.x, l.center.y, @min(l.width, l.height) / 2.0, node_item.color }),
            .ellipse => try writer.print("<ellipse cx=\"{d:.1}\" cy=\"{d:.1}\" rx=\"{d:.1}\" ry=\"{d:.1}\" fill=\"{s}\" stroke=\"#334155\" stroke-width=\"1.5\"/>\n", .{ l.center.x, l.center.y, l.width / 2.0, l.height / 2.0, node_item.color }),
        }
        try writer.print("<text x=\"{d:.1}\" y=\"{d:.1}\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"{s}\" font-size=\"14\" fill=\"#0f172a\">", .{ l.center.x, l.center.y, options.font_family });
        try writeXmlEscaped(writer, node_item.label);
        try writer.writeAll("</text>\n");
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
        \\  graph [rankdir=BT label=<Fancy Graph>];
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
