# Answer: Setup vaxis for MVP

## Initialization

```zig
const std = @import("std");
const vaxis = @import("vaxis");

pub fn main(init: std.process.Init) !void {
    // Get resources from init
    const io = init.io;
    const alloc = init.allocator;
    const env_map = try init.environ.map(io);

    // Init vaxis
    var vx = try vaxis.init(io, alloc, &env_map, .{});

    // Init TTY (opens /dev/tty, sets raw mode, installs SIGWINCH handler)
    var tty = try vaxis.Tty.init(io, &.{});
    defer tty.deinit();

    // Enter alternate screen (clears screen, hides cursor)
    try vx.enterAltScreen(tty.writer());

    // Query terminal capabilities (blocks ~1s for DA1 response)
    try vx.queryTerminal(tty.writer(), .fromSeconds(1));

    // Resize to current terminal size
    const winsize = try tty.getWinsize();
    try vx.resize(alloc, tty.writer(), winsize);

    // Get full-screen window
    const win = vx.window();

    // Event loop (spawns background thread to read tty)
    const Event = union(enum) {
        key_press: vaxis.Key,
        winsize: vaxis.Winsize,
    };
    var loop: vaxis.Loop(Event) = .init(io, &tty, &vx);
    try loop.start();
    defer loop.stop();

    try loop.installResizeHandler();
}
```

## Display Word in Dim Color

```zig
const word = "apple";

// Dim gray color
const dim_style = vaxis.Style{
    .fg = vaxis.Color.index(8),  // bright black = dim gray
};

// Print word at (0, 0)
_ = win.print(&.{
    .{ .text = word, .style = dim_style }
}, .{});
```

## Capture Keystrokes

```zig
// Blocking event read
const event = try loop.nextEvent();

switch (event) {
    .key_press => |key| {
        // key.codepoint - unicode codepoint
        // key.text - optional &str of the key text
        // key.mods - modifier flags (shift, ctrl, etc)

        // Check for specific key
        if (key.codepoint == vaxis.Key.enter) {
            // user pressed Enter
        }
    },
    .winsize => |ws| {
        try vx.resize(alloc, tty.writer(), .{ .rows = ws.rows, .cols = ws.cols });
    },
}
```

## Change Character Colors by Correctness

```zig
const correct_color = vaxis.Style{ .fg = vaxis.Color.index(2) };  // green
const incorrect_color = vaxis.Style{ .fg = vaxis.Color.index(1) }; // red

var current_index: usize = 0;
const word = "apple";

while (true) {
    const event = try loop.nextEvent();

    switch (event) {
        .key_press => |key| {
            // Check exit condition
            if (key.codepoint == vaxis.Key.escape) break;

            // Handle printable chars only
            if (key.codepoint >= 32 and key.codepoint < 127) {
                const expected = word[current_index];
                const typed_char = std.ascii.toUpper(@intCast(key.codepoint));

                // Build segments with per-character colors
                var segments: [5]vaxis.Segment = undefined;
                for (word, 0..) |c, i| {
                    if (i < current_index) {
                        // already typed - green
                        segments[i] = .{ .text = word[i..i+1], .style = correct_color };
                    } else if (i == current_index) {
                        // current position
                        if (typed_char == expected) {
                            segments[i] = .{ .text = word[i..i+1], .style = correct_color };
                            current_index += 1;
                        } else {
                            segments[i] = .{ .text = word[i..i+1], .style = incorrect_color };
                        }
                    } else {
                        // not yet typed - dim
                        segments[i] = .{ .text = word[i..i+1], .style = dim_style };
                    }
                }

                // Render
                _ = win.print(&segments, .{});
                try vx.render(tty.writer());
            }
        },
        .winsize => |ws| {
            try vx.resize(alloc, tty.writer(), .{ .rows = ws.rows, .cols = ws.cols });
        },
        else => {},
    }
}
```

## Render Frame

```zig
try vx.render(tty.writer());
```

## Minimal Complete Example

```zig
const std = @import("std");
const vaxis = @import("vaxis");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.allocator;
    const env_map = try init.environ.map(io);

    var vx = try vaxis.init(io, alloc, &env_map, .{});
    var tty = try vaxis.Tty.init(io, &.{});
    defer tty.deinit();

    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), .fromSeconds(1));

    const winsize = try tty.getWinsize();
    try vx.resize(alloc, tty.writer(), winsize);

    const win = vx.window();

    const Event = union(enum) { key_press: vaxis.Key, winsize: vaxis.Winsize };
    var loop: vaxis.Loop(Event) = .init(io, &tty, &vx);
    try loop.start();
    defer loop.stop();
    try loop.installResizeHandler();

    const word = "apple";
    var index: usize = 0;

    const dim = vaxis.Style{ .fg = .index(8) };
    const green = vaxis.Style{ .fg = .index(2) };
    const red = vaxis.Style{ .fg = .index(1) };

    while (true) {
        const event = try loop.nextEvent();
        switch (event) {
            .key_press => |key| {
                if (key.codepoint == vaxis.Key.escape) break;
                if (index >= word.len) break;

                const expected = word[index];
                const typed = std.ascii.toUpper(@intCast(key.codepoint));

                var segments: [5]vaxis.Segment = undefined;
                for (word, 0..) |c, i| {
                    if (i < index) {
                        segments[i] = .{ .text = word[i..i+1], .style = green };
                    } else if (i == index) {
                        segments[i] = .{ .text = word[i..i+1], .style = if (typed == expected) green else red };
                        if (typed == expected) index += 1;
                    } else {
                        segments[i] = .{ .text = word[i..i+1], .style = dim };
                    }
                }

                _ = win.print(&segments, .{});
                try vx.render(tty.writer());
            },
            .winsize => |ws| {
                try vx.resize(alloc, tty.writer(), .{ .rows = ws.rows, .cols = ws.cols });
            },
            else => {},
        }
    }
}
```

## Key Points

- vaxis dependency already wired in `build.zig:24-27` and imported in `src/main.zig:2`
- `vaxis.init()` needs `io`, `allocator`, `environ_map`, `Options`
- `Tty.init()` opens `/dev/tty` directly - works in terminal, not in pipe/redirect
- `Loop` spawns background thread for non-blocking input
- Always call `vx.render()` after modifying screen cells
- Use `.index(n)` for 0-15 ANSI colors, `.rgb([r,g,b])` for truecolor
- Vaxis stores terminal capabilities in `vx.caps` after `queryTerminal()`