const std = @import("std");

const word = "apple";

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var writer_buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), io, &writer_buffer);
    const writer = &stdout.interface;

    var reader_buffer: [1024]u8 = undefined;
    var stdin = std.Io.File.Reader.init(.stdout(), io, &reader_buffer);
    const reader = &stdin.interface;

    try writer.print("word: {any}\n", .{word});
    try writer.print("word: {s}\n", .{word});
    try writer.flush();

    const user_input = try reader.takeDelimiter('\n');
    if (user_input) |resolved_user_input| {
        try writer.print("user input: {any}\n", .{resolved_user_input});
        try writer.print("user input: {s}\n", .{resolved_user_input});
        try writer.flush();
    }
}
