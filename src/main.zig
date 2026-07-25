const std = @import("std");
const Io = std.Io;
const vex = @import("vex");

const default_max_input_bytes: usize = 64 * 1024 * 1024;

const usage =
    \\vex - DOT-compatible graph visualization prototype
    \\
    \\Usage:
    \\  vex [--input file.dot|-i file.dot] [--output file|-o file]
    \\        [--check|--validate|--validate-all]
    \\        [--max-diagnostics count]
    \\        [--format svg] [--layout dot|sugiyama|neato|fr|fdp|sfdp|twopi|circo|patchwork|osage|nop|nop2]
    \\        [--max-input-bytes count]
    \\        [--layout-iterations count]
    \\        [--layout-work-budget count]
    \\        [--layout-workers count]
    \\        [--crossing-passes count] [--coordinate-passes count]
    \\        [--input-format auto|dot|mermaid]
    \\        [--interactive-all]
    \\        [--interactive-layers] [--interactive-collapse]
    \\        [--interactive-filter] [--interactive-labels]
    \\        [--interactive-focus]
    \\        [--interactive-inspector]
    \\        [--interactive-search]
    \\        [--interactive-viewport]
    \\        [--interactive-minimap]
    \\        [--interactive-stats]
    \\        [--svg-metadata]
    \\  vex --help
    \\
    \\If --input is omitted, DOT is read from stdin. If --output is omitted,
    \\output is written to stdout.
    \\Default input format is auto. Default layout is DOT/Sugiyama and honors
    \\rankdir=TB|BT|LR|RL.
    \\--check parses input and reports graph counts without layout or rendering.
    \\--validate-all reports multiple recoverable DOT errors in one run.
    \\--max-input-bytes caps DOT/Mermaid input reads.
    \\--crossing-passes and --coordinate-passes cap layered layout refinement.
    \\--layout-iterations caps neato stress or force-layout iterations.
    \\--layout-work-budget cancels layout after deterministic work checkpoints.
    \\--layout-workers caps parallel workers for multi-graph input (default: auto).
    \\--interactive-all enables all SVG-native controls and metadata.
    \\--interactive-layers adds an SVG-native toggle panel for graph layers.
    \\--interactive-collapse adds SVG-native subgraph collapse controls.
    \\--interactive-filter adds SVG-native type filter controls.
    \\--interactive-labels adds SVG-native label visibility controls.
    \\--interactive-focus adds SVG-native neighborhood highlighting.
    \\--interactive-inspector adds SVG-native object metadata inspection.
    \\--interactive-search adds an SVG-native search and highlight panel.
    \\--interactive-viewport adds SVG-native pan and zoom controls.
    \\--interactive-minimap adds an SVG-native graph overview panel.
    \\--interactive-stats adds an SVG-native graph statistics panel.
    \\--svg-metadata embeds a machine-readable SVG object index.
    \\
;

pub fn main(init: std.process.Init) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    var input_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var check_only = false;
    var validate_all = false;
    var max_diagnostics: usize = 32;
    var format_arg: ?vex.OutputFormat = null;
    var layout_arg: vex.LayoutAlgorithm = .auto;
    var max_input_bytes: usize = default_max_input_bytes;
    var layout_iterations: ?usize = null;
    var layout_work_budget: ?usize = null;
    var layout_workers: usize = 0;
    var crossing_passes: ?usize = null;
    var coordinate_passes: ?usize = null;
    var input_format: vex.InputFormat = .auto;
    var interactive_all = false;
    var interactive_layers = false;
    var interactive_collapse = false;
    var interactive_filter = false;
    var interactive_labels = false;
    var interactive_focus = false;
    var interactive_inspector = false;
    var interactive_search = false;
    var interactive_viewport = false;
    var interactive_minimap = false;
    var interactive_stats = false;
    var svg_metadata = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            var stderr_buffer: [1024]u8 = undefined;
            var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
            try stderr_file_writer.interface.writeAll(usage);
            try stderr_file_writer.interface.flush();
            return;
        } else if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            i += 1;
            if (i >= args.len) return error.MissingInputPath;
            input_path = args[i];
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            i += 1;
            if (i >= args.len) return error.MissingOutputPath;
            output_path = args[i];
        } else if (std.mem.eql(u8, arg, "--check") or std.mem.eql(u8, arg, "--validate")) {
            check_only = true;
        } else if (std.mem.eql(u8, arg, "--validate-all")) {
            check_only = true;
            validate_all = true;
        } else if (std.mem.eql(u8, arg, "--max-diagnostics")) {
            i += 1;
            if (i >= args.len) return error.MissingMaxDiagnostics;
            max_diagnostics = std.fmt.parseInt(usize, args[i], 10) catch return error.InvalidMaxDiagnostics;
            if (max_diagnostics == 0) return error.InvalidMaxDiagnostics;
        } else if (std.mem.eql(u8, arg, "--format") or std.mem.eql(u8, arg, "-f")) {
            i += 1;
            if (i >= args.len) return error.MissingFormat;
            format_arg = vex.OutputFormat.fromString(args[i]) orelse return error.UnknownFormat;
        } else if (std.mem.eql(u8, arg, "--input-format")) {
            i += 1;
            if (i >= args.len) return error.MissingInputFormat;
            input_format = vex.InputFormat.fromString(args[i]) orelse return error.UnknownInputFormat;
        } else if (std.mem.eql(u8, arg, "--max-input-bytes")) {
            i += 1;
            if (i >= args.len) return error.MissingMaxInputBytes;
            max_input_bytes = std.fmt.parseInt(usize, args[i], 10) catch return error.InvalidMaxInputBytes;
            if (max_input_bytes == 0) return error.InvalidMaxInputBytes;
        } else if (std.mem.eql(u8, arg, "--mermaid")) {
            input_format = .mermaid;
        } else if (std.mem.eql(u8, arg, "--interactive-all")) {
            interactive_all = true;
        } else if (std.mem.eql(u8, arg, "--interactive-layers")) {
            interactive_layers = true;
        } else if (std.mem.eql(u8, arg, "--interactive-collapse")) {
            interactive_collapse = true;
        } else if (std.mem.eql(u8, arg, "--interactive-filter")) {
            interactive_filter = true;
        } else if (std.mem.eql(u8, arg, "--interactive-labels")) {
            interactive_labels = true;
        } else if (std.mem.eql(u8, arg, "--interactive-focus")) {
            interactive_focus = true;
        } else if (std.mem.eql(u8, arg, "--interactive-inspector")) {
            interactive_inspector = true;
        } else if (std.mem.eql(u8, arg, "--interactive-search")) {
            interactive_search = true;
        } else if (std.mem.eql(u8, arg, "--interactive-viewport")) {
            interactive_viewport = true;
        } else if (std.mem.eql(u8, arg, "--interactive-minimap")) {
            interactive_minimap = true;
        } else if (std.mem.eql(u8, arg, "--interactive-stats")) {
            interactive_stats = true;
        } else if (std.mem.eql(u8, arg, "--svg-metadata")) {
            svg_metadata = true;
        } else if (std.mem.eql(u8, arg, "--layout") or std.mem.eql(u8, arg, "-K")) {
            i += 1;
            if (i >= args.len) return error.MissingLayout;
            layout_arg = vex.LayoutAlgorithm.fromString(args[i]) orelse return error.UnknownLayout;
        } else if (std.mem.eql(u8, arg, "--layout-iterations")) {
            i += 1;
            if (i >= args.len) return error.MissingLayoutIterations;
            layout_iterations = std.fmt.parseInt(usize, args[i], 10) catch return error.InvalidLayoutIterations;
            if (layout_iterations.? == 0) return error.InvalidLayoutIterations;
        } else if (std.mem.eql(u8, arg, "--layout-work-budget")) {
            i += 1;
            if (i >= args.len) return error.MissingLayoutWorkBudget;
            layout_work_budget = std.fmt.parseInt(usize, args[i], 10) catch return error.InvalidLayoutWorkBudget;
            if (layout_work_budget.? == 0) return error.InvalidLayoutWorkBudget;
        } else if (std.mem.eql(u8, arg, "--layout-workers")) {
            i += 1;
            if (i >= args.len) return error.MissingLayoutWorkers;
            layout_workers = std.fmt.parseInt(usize, args[i], 10) catch return error.InvalidLayoutWorkers;
            if (layout_workers == 0) return error.InvalidLayoutWorkers;
        } else if (std.mem.eql(u8, arg, "--crossing-passes")) {
            i += 1;
            if (i >= args.len) return error.MissingCrossingPasses;
            crossing_passes = std.fmt.parseInt(usize, args[i], 10) catch return error.InvalidCrossingPasses;
        } else if (std.mem.eql(u8, arg, "--coordinate-passes")) {
            i += 1;
            if (i >= args.len) return error.MissingCoordinatePasses;
            coordinate_passes = std.fmt.parseInt(usize, args[i], 10) catch return error.InvalidCoordinatePasses;
        } else if (std.mem.startsWith(u8, arg, "-K") and arg.len > 2) {
            layout_arg = vex.LayoutAlgorithm.fromString(arg[2..]) orelse return error.UnknownLayout;
        } else if (std.mem.startsWith(u8, arg, "-") and !std.mem.eql(u8, arg, "-")) {
            return error.UnknownOption;
        } else if (input_path == null) {
            input_path = arg;
        } else if (output_path == null) {
            output_path = arg;
        } else {
            return error.TooManyArguments;
        }
    }

    const format = format_arg orelse if (output_path) |path|
        (vex.OutputFormat.fromPath(path) orelse .svg)
    else
        .svg;

    const dot = if (input_path) |path|
        if (std.mem.eql(u8, path, "-"))
            readStdin(allocator, io, max_input_bytes) catch |err| try handleInputReadError(io, err, max_input_bytes)
        else
            Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_input_bytes)) catch |err| try handleInputReadError(io, err, max_input_bytes)
    else blk: {
        break :blk readStdin(allocator, io, max_input_bytes) catch |err| try handleInputReadError(io, err, max_input_bytes);
    };
    defer allocator.free(dot);

    if (validate_all and (if (input_format == .auto) vex.detectInputFormat(dot) else input_format) == .dot) {
        var diagnostics = try vex.parseDotDiagnostics(allocator, dot, max_diagnostics);
        defer diagnostics.deinit();
        if (diagnostics.items.len > 0) {
            try writeParseDiagnostics(io, diagnostics.items);
            std.process.exit(1);
        }
    }

    if (check_only) {
        var stderr_buffer: [2048]u8 = undefined;
        var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
        const CheckContext = struct {
            writer: *Io.Writer,

            fn visit(self: *@This(), graph: *const vex.Graph) !void {
                try writeCheckSummaryWriter(self.writer, graph);
                try self.writer.flush();
            }
        };
        var context = CheckContext{ .writer = &stderr_file_writer.interface };
        var result = try vex.visitInputGraphsDiagnostic(allocator, dot, input_format, &context, CheckContext.visit);
        switch (result) {
            .complete => return,
            .diagnostic => |*diagnostic| {
                defer diagnostic.deinit(allocator);
                try writeParseDiagnosticWriter(&stderr_file_writer.interface, diagnostic.*);
                try stderr_file_writer.interface.flush();
                std.process.exit(1);
            },
        }
    }

    var layered_options = vex.LayoutOptions{};
    if (crossing_passes) |value| layered_options.crossing_passes = value;
    if (coordinate_passes) |value| layered_options.coordinate_passes = value;
    const layout_config = vex.LayoutConfig{
        .algorithm = layout_arg,
        .layered = layered_options,
        .force = if (layout_iterations) |iterations| .{ .iterations = iterations } else .{},
    };
    const render_options = vex.RenderOptions{ .svg = .{ .interactive_all = interactive_all, .interactive_layers = interactive_layers, .interactive_collapse = interactive_collapse, .interactive_filter = interactive_filter, .interactive_labels = interactive_labels, .interactive_focus = interactive_focus, .interactive_inspector = interactive_inspector, .interactive_search = interactive_search, .interactive_viewport = interactive_viewport, .interactive_minimap = interactive_minimap, .interactive_stats = interactive_stats, .metadata = svg_metadata } };
    if (output_path) |path| {
        var file = try Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
        defer file.close(io);
        var buffer: [8192]u8 = undefined;
        var file_writer = file.writer(io, &buffer);
        try layoutAndRenderInput(allocator, io, &file_writer.interface, dot, input_format, format, render_options, layout_config, layout_work_budget, layout_workers);
        try file_writer.interface.flush();
    } else {
        var stdout_buffer: [8192]u8 = undefined;
        var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
        try layoutAndRenderInput(allocator, io, &stdout_file_writer.interface, dot, input_format, format, render_options, layout_config, layout_work_budget, layout_workers);
        try stdout_file_writer.interface.flush();
    }
}

fn layoutAndRenderInput(
    allocator: std.mem.Allocator,
    io: Io,
    writer: *Io.Writer,
    source: []const u8,
    input_format: vex.InputFormat,
    format: vex.OutputFormat,
    render_options: vex.RenderOptions,
    layout_config: vex.LayoutConfig,
    layout_work_budget: ?usize,
    layout_workers: usize,
) !void {
    if (layout_workers == 1) {
        const Context = struct {
            allocator: std.mem.Allocator,
            io: Io,
            writer: *Io.Writer,
            format: vex.OutputFormat,
            render_options: vex.RenderOptions,
            layout_config: vex.LayoutConfig,
            layout_work_budget: ?usize,

            fn visit(self: *@This(), graph: *const vex.Graph) !void {
                var budget = vex.LayoutWorkBudget{ .limit = self.layout_work_budget orelse std.math.maxInt(usize) };
                var config = self.layout_config;
                if (self.layout_work_budget != null) config.control = budget.control();
                var layout = vex.layoutGraph(self.allocator, graph, config) catch |err| {
                    if (err == error.LayoutCanceled) {
                        try writeLayoutCanceled(self.io, &budget);
                        std.process.exit(2);
                    }
                    if (err == error.MissingNodePosition or err == error.InvalidNodePosition) {
                        try writePositionedLayoutError(self.io, err);
                        std.process.exit(2);
                    }
                    return err;
                };
                defer layout.deinit();
                try vex.render(self.writer, &layout, self.format, self.render_options);
                try self.writer.flush();
            }
        };
        var context = Context{
            .allocator = allocator,
            .io = io,
            .writer = writer,
            .format = format,
            .render_options = render_options,
            .layout_config = layout_config,
            .layout_work_budget = layout_work_budget,
        };
        var result = try vex.visitInputGraphsDiagnostic(allocator, source, input_format, &context, Context.visit);
        switch (result) {
            .complete => return,
            .diagnostic => |*diagnostic| {
                defer diagnostic.deinit(allocator);
                try writeParseDiagnostic(io, diagnostic.*);
                std.process.exit(1);
            },
        }
    }

    const parse_result = try vex.parseInputGraphsDiagnostic(allocator, source, input_format);
    var graphs = switch (parse_result) {
        .graphs => |graphs| graphs,
        .diagnostic => |diagnostic_value| {
            var diagnostic = diagnostic_value;
            defer diagnostic.deinit(allocator);
            try writeParseDiagnostic(io, diagnostic);
            std.process.exit(1);
        },
    };
    defer graphs.deinit();
    try layoutAndRenderGraphs(allocator, io, writer, graphs.items, format, render_options, layout_config, layout_work_budget, layout_workers);
}

fn layoutAndRenderGraphs(
    allocator: std.mem.Allocator,
    io: Io,
    writer: *Io.Writer,
    graphs: []vex.Graph,
    format: vex.OutputFormat,
    render_options: vex.RenderOptions,
    layout_config: vex.LayoutConfig,
    layout_work_budget: ?usize,
    layout_workers: usize,
) !void {
    const tasks = try allocator.alloc(vex.ParallelLayoutTask, graphs.len);
    defer allocator.free(tasks);
    const budgets = try allocator.alloc(vex.LayoutWorkBudget, graphs.len);
    defer allocator.free(budgets);
    for (graphs, 0..) |*graph, index| {
        budgets[index] = .{ .limit = layout_work_budget orelse std.math.maxInt(usize) };
        var config = layout_config;
        if (layout_work_budget != null) config.control = budgets[index].control();
        tasks[index] = .{ .allocator = allocator, .graph = graph, .config = config };
    }

    var layouts = try vex.layoutGraphsParallel(allocator, tasks, .{ .max_workers = layout_workers });
    defer layouts.deinit();
    for (layouts.items, 0..) |*item, index| switch (item.*) {
        .failure => |err| {
            if (err == error.LayoutCanceled) {
                try writeLayoutCanceled(io, &budgets[index]);
                std.process.exit(2);
            }
            if (err == error.MissingNodePosition or err == error.InvalidNodePosition) {
                try writePositionedLayoutError(io, err);
                std.process.exit(2);
            }
            return err;
        },
        .layout => |*layout| try vex.render(writer, layout, format, render_options),
    };
}

fn readStdin(allocator: std.mem.Allocator, io: Io, max_input_bytes: usize) ![]u8 {
    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = Io.File.stdin().readerStreaming(io, &stdin_buffer);
    return stdin_reader.interface.allocRemaining(allocator, .limited(max_input_bytes));
}

fn handleInputReadError(io: Io, err: anyerror, max_input_bytes: usize) !noreturn {
    if (err == error.StreamTooLong) {
        var stderr_buffer: [512]u8 = undefined;
        var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
        try stderr_file_writer.interface.print("input exceeds --max-input-bytes limit ({d} bytes)\n", .{max_input_bytes});
        try stderr_file_writer.interface.flush();
        std.process.exit(1);
    }
    return err;
}

fn writeParseDiagnostic(io: Io, diagnostic: vex.ParseDiagnostic) !void {
    var stderr_buffer: [2048]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    const writer = &stderr_file_writer.interface;
    try writeParseDiagnosticWriter(writer, diagnostic);
    try writer.flush();
}

fn writeParseDiagnosticWriter(writer: *Io.Writer, diagnostic: vex.ParseDiagnostic) Io.Writer.Error!void {
    try writer.print("DOT parse error: {s}\n", .{diagnostic.message});
    try writer.print("  at line {d}, column {d}\n", .{ diagnostic.line, diagnostic.column });
    if (diagnostic.source_line.len > 0) {
        try writer.print("{d} | {s}\n", .{ diagnostic.line, diagnostic.source_line });
        try writer.writeAll("  | ");
        var caret_col: usize = 1;
        while (caret_col < diagnostic.column) : (caret_col += 1) try writer.writeByte(' ');
        try writer.writeAll("^\n");
    }
    if (diagnostic.token.len > 0) try writer.print("  token: {s}\n", .{diagnostic.token});
    if (diagnostic.hint.len > 0) try writer.print("  hint: {s}\n", .{diagnostic.hint});
}

fn writeParseDiagnostics(io: Io, diagnostics: []const vex.ParseDiagnostic) !void {
    var stderr_buffer: [8192]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    try writeParseDiagnosticsWriter(&stderr_file_writer.interface, diagnostics);
    try stderr_file_writer.interface.flush();
}

fn writeParseDiagnosticsWriter(writer: *Io.Writer, diagnostics: []const vex.ParseDiagnostic) Io.Writer.Error!void {
    try writer.print("DOT validation found {d} error(s)\n", .{diagnostics.len});
    for (diagnostics, 0..) |diagnostic, index| {
        try writer.print("[{d}] {s} at line {d}, column {d}\n", .{
            index + 1,
            diagnostic.message,
            diagnostic.line,
            diagnostic.column,
        });
        if (diagnostic.source_line.len > 0) {
            try writer.print("{d} | {s}\n", .{ diagnostic.line, diagnostic.source_line });
            try writer.writeAll("  | ");
            var caret_col: usize = 1;
            while (caret_col < diagnostic.column) : (caret_col += 1) try writer.writeByte(' ');
            try writer.writeAll("^\n");
        }
        if (diagnostic.hint.len > 0) try writer.print("    hint: {s}\n", .{diagnostic.hint});
    }
}

fn writeCheckSummary(io: Io, graph: *const vex.Graph) !void {
    var stderr_buffer: [512]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    try writeCheckSummaryWriter(&stderr_file_writer.interface, graph);
    try stderr_file_writer.interface.flush();
}

fn writeLayoutCanceled(io: Io, budget: *const vex.LayoutWorkBudget) !void {
    var stderr_buffer: [512]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    try stderr_file_writer.interface.print(
        "layout canceled: work budget exceeded (limit={d}, observed={d}, checkpoints={d})\n",
        .{ budget.limit, budget.last_work, budget.checkpoints },
    );
    try stderr_file_writer.interface.flush();
}

fn writePositionedLayoutError(io: Io, err: anyerror) !void {
    var stderr_buffer: [512]u8 = undefined;
    var stderr_writer = Io.File.stderr().writer(io, &stderr_buffer);
    const message = switch (err) {
        error.MissingNodePosition => "positioned layout requires a pos attribute for every node",
        error.InvalidNodePosition => "positioned layout found an invalid node pos attribute",
        else => @errorName(err),
    };
    try stderr_writer.interface.print("layout error: {s}\n", .{message});
    try stderr_writer.interface.flush();
}

fn writeCheckSummaryWriter(writer: *Io.Writer, graph: *const vex.Graph) Io.Writer.Error!void {
    try writer.print(
        "input ok: graph={s} directed={s} nodes={d} edges={d} subgraphs={d}\n",
        .{
            graph.name,
            if (graph.directed) "true" else "false",
            graph.nodes.items.len,
            graph.edges.items.len,
            graph.subgraphs.items.len,
        },
    );
}

test "check summary reports graph counts" {
    const allocator = std.testing.allocator;
    var graph = try vex.parseInput(allocator,
        \\digraph Vex {
        \\  A -> B;
        \\  B -> C;
        \\  C -> A;
        \\}
    , .dot);
    defer graph.deinit();

    var aw = Io.Writer.Allocating.init(allocator);
    defer aw.deinit();
    try writeCheckSummaryWriter(&aw.writer, &graph);
    const summary = try aw.toOwnedSlice();
    defer allocator.free(summary);

    try std.testing.expectEqualStrings(
        "input ok: graph=Vex directed=true nodes=3 edges=3 subgraphs=0\n",
        summary,
    );
}

test "graph stream check summaries and SVG output preserve every graph" {
    const allocator = std.testing.allocator;
    var graphs = try vex.parseDotGraphs(allocator,
        \\digraph First { a -> b; }
        \\graph Second { c -- d; }
    );
    defer graphs.deinit();

    var summary_writer = Io.Writer.Allocating.init(allocator);
    defer summary_writer.deinit();
    for (graphs.items) |*graph| try writeCheckSummaryWriter(&summary_writer.writer, graph);
    const summaries = try summary_writer.toOwnedSlice();
    defer allocator.free(summaries);
    try std.testing.expect(std.mem.indexOf(u8, summaries, "graph=First directed=true") != null);
    try std.testing.expect(std.mem.indexOf(u8, summaries, "graph=Second directed=false") != null);

    var serial_writer = Io.Writer.Allocating.init(allocator);
    defer serial_writer.deinit();
    try layoutAndRenderGraphs(
        allocator,
        std.testing.io,
        &serial_writer.writer,
        graphs.items,
        .svg,
        .{},
        .{ .algorithm = .sugiyama },
        null,
        1,
    );
    const serial_svg = try serial_writer.toOwnedSlice();
    defer allocator.free(serial_svg);

    var parallel_writer = Io.Writer.Allocating.init(allocator);
    defer parallel_writer.deinit();
    try layoutAndRenderGraphs(
        allocator,
        std.testing.io,
        &parallel_writer.writer,
        graphs.items,
        .svg,
        .{},
        .{ .algorithm = .sugiyama },
        null,
        4,
    );
    const parallel_svg = try parallel_writer.toOwnedSlice();
    defer allocator.free(parallel_svg);

    try std.testing.expectEqualStrings(serial_svg, parallel_svg);
    try std.testing.expectEqual(@as(usize, 2), countOccurrences(parallel_svg, "<svg "));
    try std.testing.expectEqual(@as(usize, 2), countOccurrences(parallel_svg, "</svg>"));
    const first = std.mem.indexOf(u8, parallel_svg, "<title>First</title>") orelse return error.MissingFirstGraph;
    const second = std.mem.indexOf(u8, parallel_svg, "<title>Second</title>") orelse return error.MissingSecondGraph;
    try std.testing.expect(first < second);
}

test "serial graph stream render visitor matches parallel owned output" {
    const allocator = std.testing.allocator;
    const source =
        \\digraph First { a -> b; }
        \\graph Second { c -- d; }
        \\digraph Third { e -> f; }
    ;
    var serial_writer = Io.Writer.Allocating.init(allocator);
    defer serial_writer.deinit();
    try layoutAndRenderInput(
        allocator,
        std.testing.io,
        &serial_writer.writer,
        source,
        .dot,
        .svg,
        .{},
        .{ .algorithm = .sugiyama },
        null,
        1,
    );
    const serial_svg = try serial_writer.toOwnedSlice();
    defer allocator.free(serial_svg);

    var graphs = try vex.parseDotGraphs(allocator, source);
    defer graphs.deinit();
    var parallel_writer = Io.Writer.Allocating.init(allocator);
    defer parallel_writer.deinit();
    try layoutAndRenderGraphs(
        allocator,
        std.testing.io,
        &parallel_writer.writer,
        graphs.items,
        .svg,
        .{},
        .{ .algorithm = .sugiyama },
        null,
        4,
    );
    const parallel_svg = try parallel_writer.toOwnedSlice();
    defer allocator.free(parallel_svg);
    try std.testing.expectEqualStrings(parallel_svg, serial_svg);
}

test "streaming check output keeps consumed summaries before later diagnostic" {
    const allocator = std.testing.allocator;
    var writer = Io.Writer.Allocating.init(allocator);
    defer writer.deinit();
    const Context = struct {
        writer: *Io.Writer,

        fn visit(self: *@This(), graph: *const vex.Graph) !void {
            try writeCheckSummaryWriter(self.writer, graph);
        }
    };
    var context = Context{ .writer = &writer.writer };
    var result = try vex.visitDotGraphsDiagnostic(
        allocator,
        "digraph First { a -> b; }\ndigraph Broken { c -> ; }",
        &context,
        Context.visit,
    );
    switch (result) {
        .complete => return error.ExpectedGraphStreamDiagnostic,
        .diagnostic => |*diagnostic| {
            defer diagnostic.deinit(allocator);
            try writeParseDiagnosticWriter(&writer.writer, diagnostic.*);
        },
    }
    const output = try writer.toOwnedSlice();
    defer allocator.free(output);
    const summary = std.mem.indexOf(u8, output, "input ok: graph=First") orelse return error.MissingConsumedGraphSummary;
    const diagnostic = std.mem.indexOf(u8, output, "DOT parse error:") orelse return error.MissingLaterGraphDiagnostic;
    try std.testing.expect(summary < diagnostic);
}

fn countOccurrences(haystack: []const u8, needle: []const u8) usize {
    var count: usize = 0;
    var offset: usize = 0;
    while (std.mem.indexOfPos(u8, haystack, offset, needle)) |index| {
        count += 1;
        offset = index + needle.len;
    }
    return count;
}

test "batch diagnostic writer reports every error" {
    const allocator = std.testing.allocator;
    var diagnostics = try vex.parseDotDiagnostics(allocator,
        \\digraph G {
        \\  a -- b;
        \\  c [label=];
        \\}
    , 8);
    defer diagnostics.deinit();

    var aw = Io.Writer.Allocating.init(allocator);
    defer aw.deinit();
    try writeParseDiagnosticsWriter(&aw.writer, diagnostics.items);
    const output = try aw.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "DOT validation found 2 error(s)") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "[1] edge operator does not match graph direction") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "[2] expected DOT identifier") != null);
}
