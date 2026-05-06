# AGENTS.md

Small Zig CLI scaffold based on `zig init`, currently prints a word and echoes one line of input. No README, no CI, no lint/format config, no external deps.

## Toolchain
- **Zig 0.16.0+ required** (`build.zig.zon` pins `minimum_zig_version = "0.16.0"`).
- Code uses post-Writergate stdlib APIs that do **not** exist in Zig 0.15 or earlier:
  - `pub fn main(init: std.process.Init) !void` — keep this signature.
  - `std.Io.File.Writer.init(.stdout(), io, &buf)` / `std.Io.File.Reader.init(...)` — do not rewrite to `std.io.getStdOut().writer()` or similar pre-0.16 idioms.

## Commands
- `zig build` — builds `zig-out/bin/zig_keyboard_warrior_cli`.
- `zig build run` — run; pass args after `--`, e.g. `zig build run -- foo bar` (`build.zig:114`).
- `zig build test` — runs both test executables in parallel: `mod_tests` for `src/root.zig`, `exe_tests` for `src/main.zig` (`build.zig:121-143`). Tests added to either file are picked up automatically.
- `zig build test --summary all` — see passing tests.
- No `-Dtest-filter` option is wired in. To run a single test, invoke `zig test src/<file>.zig --test-filter "<substring>"` directly, or add the option in `build.zig`.
- `zig fmt src build.zig` — formatter is not wired into `zig build`; run manually.

## Layout
- `src/root.zig` — library module, exposed to consumers as `zig_keyboard_warrior_cli` via `b.addModule(...)` (`build.zig:31`).
- `src/main.zig` — executable root module; imports the library as `@import("zig_keyboard_warrior_cli")` (`build.zig:75-82`).
- `build.zig.zon` `.paths` includes only `build.zig`, `build.zig.zon`, `src`. Adding top-level files (e.g. `LICENSE`, `README.md`) that should be part of the package hash requires updating this list.

## Gotchas
- `src/main.zig:12` intentionally passes `.stdout()` to `std.Io.File.Reader.init`: a `File` object is required by the `init` API and `.stdout()` is the available helper used here. **Do not "fix" it to `.stdin()`.**
- `build.zig.zon` `.fingerprint` is the project's permanent identity. Do not regenerate it (see the in-file comment).
- `.zig-cache/` and `zig-out/` are gitignored; never commit them.
