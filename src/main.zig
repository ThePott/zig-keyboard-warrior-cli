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

pub fn checkIsSameStyle(style_1: vaxis.Style, style_2: vaxis.Style) bool {
    const rgb_1 = style_1.fg.rgb;
    const rgb_2 = style_2.fg.rgb;
    for (0..3) |index| {
        if (rgb_1[index] != rgb_2[index]) return false;
    }
    return true;
}

var typed: usize = 0;
var count: usize = 0;
var correct_count: usize = 0;

const Statistic = struct {
    original: usize,
    typed: usize,
    wrong: usize,
};

const CompareBankAndInputReturn = struct {
    segment_array: []vaxis.Segment,
    statistic: Statistic,
};

fn mustFreeCompareBankAndInput(allocator: std.mem.Allocator, word_bank_text: []u8, user_input_buffer: []u8) ![]vaxis.Segment {
    var actual_input_length: usize = 0;
    while (user_input_buffer[actual_input_length] != 0) : (actual_input_length += 1) {}

    const array_length = std.mem.max(usize, &.{ actual_input_length, word_bank_text.len });
    var result = try allocator.alloc(vaxis.Segment, array_length);
    for (0..array_length) |index| {
        if (index >= word_bank_text.len) {
            result[index] = .{ .text = user_input_buffer[index .. index + 1], .style = style_fg_red };
        } else if (user_input_buffer[index] == 0) {
            result[index] = .{ .text = word_bank_text[index .. index + 1], .style = style_fg_dim };
        } else if (word_bank_text[index] == user_input_buffer[index]) {
            result[index] = .{ .text = user_input_buffer[index .. index + 1], .style = style_fg_green };
        } else {
            result[index] = .{ .text = user_input_buffer[index .. index + 1], .style = style_fg_red };
        }
    }
    return result;
}

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
    //
    const word_bank_text = try std.mem.join(gpa, " ", word_bank.word_bank);
    defer gpa.free(word_bank_text);

    while (true) {
        const event = try loop.nextEvent();
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) break;
                if (key.matches(vaxis.Key.escape, .{})) break;

                typed += 1;

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

        var print_buffer: [4]u8 = undefined;
        const count_in_string = try std.fmt.bufPrint(&print_buffer, "{any}", .{count});

        const must_free_stylized_word_bank_segment_slice = try mustFreeCompareBankAndInput(gpa, word_bank_text, &user_input_buffer);
        defer gpa.free(must_free_stylized_word_bank_segment_slice);

        correct_count = 0; // NOTE: reset counter
        for (must_free_stylized_word_bank_segment_slice) |segment| {
            const is_same_style = checkIsSameStyle(segment.style, style_fg_green);
            if (!is_same_style) continue;
            correct_count += 1;
        }

        var correct_count_print_buffer: [4]u8 = undefined;
        const correct_count_in_string = try std.fmt.bufPrint(&correct_count_print_buffer, "{any}", .{correct_count});

        var typed_print_buffer: [4]u8 = undefined;
        const typed_in_string = try std.fmt.bufPrint(&typed_print_buffer, "{any}", .{typed});

        const latter_segment_slice: []const vaxis.Segment = &.{
            .{ .text = "\n" },
            .{ .text = &user_input_buffer },
            .{ .text = "\ncount: " },
            .{ .text = count_in_string },
            .{ .text = "\ncorrect count: " },
            .{ .text = correct_count_in_string },
            .{ .text = "\ntyped in string: " },
            .{ .text = typed_in_string },
        };
        const segment_slice = try std.mem.concat(
            gpa,
            vaxis.Segment,
            &.{ must_free_stylized_word_bank_segment_slice, latter_segment_slice },
        );
        defer gpa.free(segment_slice);
        _ = win.print(segment_slice, .{});

        try vx.render(writer);
    }
}
