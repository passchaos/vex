const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    const ztex_dep = b.dependency("ztex", .{
        .target = target,
        .optimize = optimize,
    });
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Zig modules are the preferred way of making Zig code available to consumers.
    // addModule defines a module that we intend to make available for importing
    // to our consumers. We must give it a name because a Zig package can expose
    // multiple modules and consumers will need to be able to specify which
    // module they want to access.
    const mod = b.addModule("vex", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
    });
    mod.addImport("ztex", ztex_dep.module("ztex"));

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "vex",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                // Here "vex" is the name you will use in your source code to
                // import this module (e.g. `@import("vex")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{ .name = "vex", .module = mod },
            },
        }),
    });

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    const parse_scale = b.addExecutable(.{
        .name = "vex-parse-scale",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/parse_scale.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vex", .module = mod },
            },
        }),
    });
    const run_parse_scale = b.addRunArtifact(parse_scale);
    const parse_scale_step = b.step("test-parse-scale", "Run chain and structured DOT parser scale gates");
    parse_scale_step.dependOn(&run_parse_scale.step);

    const layout_render_scale = b.addExecutable(.{
        .name = "vex-layout-render-scale",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/layout_render_scale.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vex", .module = mod },
            },
        }),
    });
    const run_layout_render_scale = b.addRunArtifact(layout_render_scale);
    const layout_render_scale_step = b.step("test-layout-render-scale", "Run all native layout/SVG scale gates");
    layout_render_scale_step.dependOn(&run_layout_render_scale.step);

    const layered_tall_scale = b.addExecutable(.{
        .name = "vex-layered-tall-scale",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/layered_tall_scale.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vex", .module = mod },
            },
        }),
    });
    const run_layered_tall_scale = b.addRunArtifact(layered_tall_scale);
    const layered_tall_scale_step = b.step("test-layered-tall-scale", "Run tall narrow layered crossing scale gate");
    layered_tall_scale_step.dependOn(&run_layered_tall_scale.step);

    const waypoint_scale = b.addExecutable(.{
        .name = "vex-waypoint-scale",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/waypoint_scale.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vex", .module = mod },
            },
        }),
    });
    const run_waypoint_scale = b.addRunArtifact(waypoint_scale);
    const waypoint_scale_step = b.step("test-waypoint-scale", "Run high-minlen waypoint layout/SVG scale gate");
    waypoint_scale_step.dependOn(&run_waypoint_scale.step);

    const parallel_layout_scale = b.addExecutable(.{
        .name = "vex-parallel-layout-scale",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/parallel_layout_scale.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vex", .module = mod },
            },
        }),
    });
    const run_parallel_layout_scale = b.addRunArtifact(parallel_layout_scale);
    const parallel_layout_scale_step = b.step("test-parallel-layout-scale", "Run parallel multi-graph layout scale gate");
    parallel_layout_scale_step.dependOn(&run_parallel_layout_scale.step);

    const corpus_audit_vex = b.addExecutable(.{
        .name = "vex-corpus-audit",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "vex", .module = mod },
            },
        }),
    });
    const graphviz_root = b.option([]const u8, "graphviz-root", "Graphviz source checkout for audit-dot-corpus") orelse "";
    const run_dot_corpus_audit = b.addSystemCommand(&.{
        "python3",
        "tools/dot_corpus_audit.py",
        graphviz_root,
        "--vex",
    });
    run_dot_corpus_audit.addArtifactArg(corpus_audit_vex);
    const dot_corpus_audit_step = b.step("audit-dot-corpus", "Audit the local Graphviz DOT corpus (requires -Dgraphviz-root=...)");
    dot_corpus_audit_step.dependOn(&run_dot_corpus_audit.step);

    const run_cluster_corpus_audit = b.addSystemCommand(&.{
        "python3",
        "tools/dot_corpus_audit.py",
        graphviz_root,
        "--vex",
    });
    run_cluster_corpus_audit.addArtifactArg(corpus_audit_vex);
    run_cluster_corpus_audit.addArgs(&.{ "--render-clusters", "--max-bytes", "262144" });
    const cluster_corpus_audit_step = b.step("audit-cluster-corpus", "Audit Graphviz cluster layout/SVG corpus (requires -Dgraphviz-root=...)");
    cluster_corpus_audit_step.dependOn(&run_cluster_corpus_audit.step);

    const run_svg_corpus_audit = b.addSystemCommand(&.{
        "python3",
        "tools/dot_corpus_audit.py",
        graphviz_root,
        "--vex",
    });
    run_svg_corpus_audit.addArtifactArg(corpus_audit_vex);
    run_svg_corpus_audit.addArgs(&.{ "--render-all", "--max-bytes", "262144" });
    const svg_corpus_audit_step = b.step("audit-svg-corpus", "Audit full non-HTML Graphviz SVG corpus (requires -Dgraphviz-root=...)");
    svg_corpus_audit_step.dependOn(&run_svg_corpus_audit.step);

    const run_large_svg_corpus_audit = b.addSystemCommand(&.{
        "python3",
        "tools/dot_corpus_audit.py",
        graphviz_root,
        "--vex",
    });
    run_large_svg_corpus_audit.addArtifactArg(corpus_audit_vex);
    run_large_svg_corpus_audit.addArgs(&.{ "--render-large", "--timeout", "8" });
    const large_svg_corpus_audit_step = b.step("audit-large-svg-corpus", "Audit large non-HTML Graphviz SVG corpus (requires -Dgraphviz-root=...)");
    large_svg_corpus_audit_step.dependOn(&run_large_svg_corpus_audit.step);

    const run_layout_quality_audit = b.addSystemCommand(&.{
        "python3",
        "tools/layout_quality_audit.py",
        graphviz_root,
        "--vex",
    });
    run_layout_quality_audit.addArtifactArg(corpus_audit_vex);
    const layout_quality_audit_step = b.step("audit-layout-quality", "Compare Vex and Graphviz invariant layout quality (requires -Dgraphviz-root=...)");
    layout_quality_audit_step.dependOn(&run_layout_quality_audit.step);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const api_examples = [_]struct {
        step_name: []const u8,
        exe_name: []const u8,
        source: []const u8,
        desc: []const u8,
    }{
        .{
            .step_name = "run-api-basic-svg",
            .exe_name = "api-basic-svg",
            .source = "examples/api/01_basic_svg.zig",
            .desc = "Run API example: basic SVG renderer",
        },
        .{
            .step_name = "run-api-undirected-svg",
            .exe_name = "api-undirected-svg",
            .source = "examples/api/02_undirected_svg.zig",
            .desc = "Run API example: undirected SVG renderer",
        },
        .{
            .step_name = "run-api-clusters-compound",
            .exe_name = "api-clusters-compound",
            .source = "examples/api/03_clusters_compound.zig",
            .desc = "Run API example: clusters and compound edges",
        },
        .{
            .step_name = "run-api-svg-output",
            .exe_name = "api-svg-output",
            .source = "examples/api/04_svg_output.zig",
            .desc = "Run API example: SVG output dispatch",
        },
        .{
            .step_name = "run-api-records-ports-svg",
            .exe_name = "api-records-ports-svg",
            .source = "examples/api/05_records_ports_svg.zig",
            .desc = "Run API example: records, ports, and SVG output",
        },
        .{
            .step_name = "run-api-shapes-styles-svg",
            .exe_name = "api-shapes-styles-svg",
            .source = "examples/api/06_shapes_styles_svg.zig",
            .desc = "Run API example: shapes, styles, and SVG output",
        },
        .{
            .step_name = "run-api-force-layout-svg",
            .exe_name = "api-force-layout-svg",
            .source = "examples/api/07_force_layout_svg.zig",
            .desc = "Run API example: layered cyclic SVG layout",
        },
        .{
            .step_name = "run-api-incremental-layout-svg",
            .exe_name = "api-incremental-layout-svg",
            .source = "examples/api/08_incremental_layout_svg.zig",
            .desc = "Run API example: incremental stable SVG layout",
        },
        .{
            .step_name = "run-api-fdp-layout-svg",
            .exe_name = "api-fdp-layout-svg",
            .source = "examples/api/09_fdp_layout_svg.zig",
            .desc = "Run API example: clustered fdp SVG layout",
        },
        .{
            .step_name = "run-api-sfdp-layout-svg",
            .exe_name = "api-sfdp-layout-svg",
            .source = "examples/api/10_sfdp_layout_svg.zig",
            .desc = "Run API example: multilevel sfdp SVG layout",
        },
        .{
            .step_name = "run-api-twopi-layout-svg",
            .exe_name = "api-twopi-layout-svg",
            .source = "examples/api/11_twopi_layout_svg.zig",
            .desc = "Run API example: rooted twopi SVG layout",
        },
        .{
            .step_name = "run-api-circo-layout-svg",
            .exe_name = "api-circo-layout-svg",
            .source = "examples/api/12_circo_layout_svg.zig",
            .desc = "Run API example: block-tree circo SVG layout",
        },
        .{
            .step_name = "run-api-patchwork-layout-svg",
            .exe_name = "api-patchwork-layout-svg",
            .source = "examples/api/13_patchwork_layout_svg.zig",
            .desc = "Run API example: hierarchical patchwork SVG layout",
        },
        .{
            .step_name = "run-api-osage-layout-svg",
            .exe_name = "api-osage-layout-svg",
            .source = "examples/api/14_osage_layout_svg.zig",
            .desc = "Run API example: nested osage array packing",
        },
        .{
            .step_name = "run-api-positioned-layout-svg",
            .exe_name = "api-positioned-layout-svg",
            .source = "examples/api/15_positioned_layout_svg.zig",
            .desc = "Run API example: nop2 positioned nodes and edge spline",
        },
        .{
            .step_name = "run-api-math-labels-svg",
            .exe_name = "api-math-labels-svg",
            .source = "examples/api/16_math_labels_svg.zig",
            .desc = "Run API example: ztex math labels in SVG",
        },
    };

    for (api_examples) |example| {
        const example_exe = b.addExecutable(.{
            .name = example.exe_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.source),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "vex", .module = mod },
                },
            }),
        });
        const example_run = b.addRunArtifact(example_exe);
        const example_step = b.step(example.step_name, example.desc);
        example_step.dependOn(&example_run.step);
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_parse_scale.step);
    test_step.dependOn(&run_layout_render_scale.step);
    test_step.dependOn(&run_layered_tall_scale.step);
    test_step.dependOn(&run_waypoint_scale.step);
    test_step.dependOn(&run_parallel_layout_scale.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.
}
