const std = @import("std");
const vaxis = @import("vaxis");

const test_reader = @import("./test-reader/index.zig");

pub fn main(init: std.process.Init) !void {
    try test_reader.testReader(init);
}
