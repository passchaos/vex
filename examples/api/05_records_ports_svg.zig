//! Use the API to build record/port-style nodes and write SVG.
//!
//! Run with: zig build run-api-records-ports-svg

const std = @import("std");
const vex = @import("vex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var graph = try vex.Graph.init(allocator, .{ .directed = true, .name = "RecordsPorts", .rankdir = .LR });
    defer graph.deinit();

    const user = try graph.addNode("{<id> id|<name> name|<email> email}", .{
        .shape = .record,
    });
    const order = try graph.addNode("{<id> id|<user_id> user_id|<total> total}", .{
        .shape = .record,
    });
    const payment = try graph.addNode(
        \\<TABLE BORDER="1" CELLBORDER="1" CELLSPACING="0">
        \\  <TR><TD PORT="id"><B>id</B></TD><TD>uuid</TD></TR>
        \\  <TR><TD PORT="order_id">order_id</TD><TD>uuid</TD></TR>
        \\  <TR><TD PORT="status">status</TD><TD><I>enum</I></TD></TR>
        \\</TABLE>
    , .{
        .shape = .plaintext,
    });

    _ = try graph.addEdge(user, order, .{
        .label = "owns",
        .tail_record_port = "id",
        .head_record_port = "user_id",
    });
    _ = try graph.addEdge(order, payment, .{
        .label = "paid by",
        .tail_record_port = "id",
        .head_record_port = "order_id",
        .head_port = .east,
    });

    var result = try vex.layoutGraph(allocator, &graph, .{});
    defer result.deinit();
    try std.Io.Dir.cwd().createDirPath(io, "zig-out/examples");
    var file = try std.Io.Dir.cwd().createFile(io, "zig-out/examples/api_records_ports.svg", .{ .truncate = true });
    defer file.close(io);
    var file_buffer: [8192]u8 = undefined;
    var file_writer = file.writer(io, &file_buffer);
    try vex.render(&file_writer.interface, &result, .svg, .{});
    try file_writer.interface.flush();

    var stdout_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    try stdout.interface.writeAll("wrote zig-out/examples/api_records_ports.svg\n");
    try stdout.interface.flush();
}
