const std = @import("std");
const vaxis = @import("vaxis");
const word_bank = @import("./word-bank.zig");

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    mouse: vaxis.Mouse,
    mouse_focus: vaxis.Mouse,
};

var count: usize = 0;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    var vx = try vaxis.init(io, gpa, init.environ_map, .{});
    var tty = try vaxis.Tty.init(io, &.{});
    const writer = tty.writer();
    defer tty.deinit();
    defer vx.deinit(gpa, writer);

    try vx.enterAltScreen(writer);

    var loop = vaxis.Loop(Event).init(io, &tty, &vx);
    try loop.start(); // MUST NOT DELETE
    defer loop.stop(); // MUST NOT DELETE

    while (true) {
        const event = try loop.nextEvent();
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) break;
                if (key.matches(vaxis.Key.escape, .{})) break;

                count += 1;
            },
            .winsize => |winsize| try vx.resize(gpa, writer, winsize),
            else => {},
        }

        const win = vx.window();
        win.clear();

        // var print_buffer: [4]u8 = undefined;
        // const count_in_string = try std.fmt.bufPrint(&print_buffer, "{any}", .{count});
        // const text_many = [_][]const u8{ "count: ", count_in_string };
        const text = try std.mem.join(gpa, " ", &word_bank.word_bank);
        defer gpa.free(text);
        _ = win.print(&[_]vaxis.Segment{.{ .text = text }}, .{});

        try vx.render(writer);
    }
}
