const std = @import("std");
const Io = std.Io;
const vex = @import("vex");

const default_max_input_bytes: usize = 64 * 1024 * 1024;

const usage =
    \\vex - DOT-compatible graph visualization prototype
    \\
    \\Usage:
    \\  vex [--input file.dot|-i file.dot] [--output file|-o file]
    \\        [--check|--validate]
    \\        [--format svg] [--layout dot|sugiyama|neato|fr|fdp|sfdp|twopi]
    \\        [--max-input-bytes count]
    \\        [--layout-iterations count]
    \\        [--layout-work-budget count]
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
    \\--max-input-bytes caps DOT/Mermaid input reads.
    \\--crossing-passes and --coordinate-passes cap layered layout refinement.
    \\--layout-iterations caps neato stress or force-layout iterations.
    \\--layout-work-budget cancels layout after deterministic work checkpoints.
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
    var format_arg: ?vex.OutputFormat = null;
    var layout_arg: vex.LayoutAlgorithm = .auto;
    var max_input_bytes: usize = default_max_input_bytes;
    var layout_iterations: ?usize = null;
    var layout_work_budget: ?usize = null;
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

    const parse_result = try vex.parseInputDiagnostic(allocator, dot, input_format);
    var graph = switch (parse_result) {
        .graph => |graph| graph,
        .diagnostic => |diagnostic_value| {
            var diagnostic = diagnostic_value;
            defer diagnostic.deinit(allocator);
            try writeParseDiagnostic(io, diagnostic);
            std.process.exit(1);
        },
    };
    defer graph.deinit();

    if (check_only) {
        try writeCheckSummary(io, &graph);
        return;
    }

    var layered_options = vex.LayoutOptions{};
    if (crossing_passes) |value| layered_options.crossing_passes = value;
    if (coordinate_passes) |value| layered_options.coordinate_passes = value;
    var work_budget = vex.LayoutWorkBudget{ .limit = layout_work_budget orelse std.math.maxInt(usize) };
    const layout_config = vex.LayoutConfig{
        .algorithm = layout_arg,
        .layered = layered_options,
        .force = if (layout_iterations) |iterations| .{ .iterations = iterations } else .{},
        .control = if (layout_work_budget != null) work_budget.control() else .{},
    };
    var layout = vex.layoutGraph(allocator, &graph, layout_config) catch |err| {
        if (err == error.LayoutCanceled) {
            try writeLayoutCanceled(io, &work_budget);
            std.process.exit(2);
        }
        return err;
    };
    defer layout.deinit();
    const render_options = vex.RenderOptions{ .svg = .{ .interactive_all = interactive_all, .interactive_layers = interactive_layers, .interactive_collapse = interactive_collapse, .interactive_filter = interactive_filter, .interactive_labels = interactive_labels, .interactive_focus = interactive_focus, .interactive_inspector = interactive_inspector, .interactive_search = interactive_search, .interactive_viewport = interactive_viewport, .interactive_minimap = interactive_minimap, .interactive_stats = interactive_stats, .metadata = svg_metadata } };
    if (output_path) |path| {
        var file = try Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
        defer file.close(io);
        var buffer: [8192]u8 = undefined;
        var file_writer = file.writer(io, &buffer);
        try vex.render(&file_writer.interface, &layout, format, render_options);
        try file_writer.interface.flush();
    } else {
        var stdout_buffer: [8192]u8 = undefined;
        var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
        try vex.render(&stdout_file_writer.interface, &layout, format, render_options);
        try stdout_file_writer.interface.flush();
    }
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
    try writer.flush();
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
