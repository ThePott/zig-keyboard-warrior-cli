const TestReader = @This();

const std = @import("std");

const word = "apple";

var count: usize = 0;

fn takeKeystrokeRecursive(writer: *std.Io.Writer, reader: *std.Io.Reader) !void {
    const reader_byte = try reader.takeByte();
    count += 1;
    try writer.print("count: {any}\n", .{count});
    try writer.print("reader byte: {any}\n", .{reader_byte});
    try writer.flush();
}

pub fn testReader(init: std.process.Init) !void {
    const io = init.io;
    var writer_buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &writer_buffer);
    const writer = &stdout.interface;

    var reader_buffer: [1024]u8 = undefined;
    var stdin = std.Io.File.Reader.init(.stdout(), io, &reader_buffer);
    const reader = &stdin.interface;

    try takeKeystrokeRecursive(writer, reader);
}
