const std = @import("std");
const vaxis = @import("vaxis");
const word_bank = @import("./word_bank.zig");

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    mouse: vaxis.Mouse,
    mouse_focus: vaxis.Mouse,
};

const style_fg_red: vaxis.Style = .{ .fg = .{ .rgb = .{ 213, 77, 83 } } };
const style_fg_green: vaxis.Style = .{ .fg = .{ .rgb = .{ 185, 201, 75 } } };
const style_fg_dim: vaxis.Style = .{ .fg = .{ .rgb = .{ 102, 102, 102 } } };

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

    var user_input_buffer: [1024]u8 = undefined;
    @memset(&user_input_buffer, 0); // MUST SET

    while (true) {
        const event = try loop.nextEvent();
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) break;
                if (key.matches(vaxis.Key.escape, .{})) break;

                if (key.matches(vaxis.Key.backspace, .{})) {
                    count = if (count <= 0) 0 else count - 1;
                    user_input_buffer[count] = 0;
                } else if (key.text) |text| {
                    @memcpy(user_input_buffer[count .. count + text.len], text);
                    count += 1;
                }
            },
            .winsize => |winsize| try vx.resize(gpa, writer, winsize),
            else => {},
        }

        const win = vx.window();
        win.clear();

        const word_bank_text = try std.mem.join(gpa, " ", word_bank.word_bank);
        defer gpa.free(word_bank_text);
        var print_buffer: [4]u8 = undefined;
        const count_in_string = try std.fmt.bufPrint(&print_buffer, "{any}", .{count});
        const segment_slice: []const vaxis.Segment = &.{
            .{ .text = word_bank_text, .style = style_fg_green },
            .{ .text = "\n" },
            .{ .text = &user_input_buffer },
            .{ .text = "\n" },
            .{ .text = "count: " },
            .{ .text = count_in_string },
        };
        _ = win.print(segment_slice, .{});

        try vx.render(writer);
    }
}
