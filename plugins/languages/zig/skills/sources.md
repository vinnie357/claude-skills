# Zig Plugin Sources

This file documents the sources used to create the zig plugin skills.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there.

## Update History

### 2026-08-04 — claude-skills-204 content-verification pass

Claim-by-claim pass over all seven zig skills, verified against the locally
installed Zig **0.16.0** toolchain (`zig version` → `0.16.0`) by compiling the
documented snippets, plus https://ziglang.org/download/index.json,
https://ziglang.org/download/0.16.0/release-notes.html, and the GitHub tags API.
Zig 0.15.2 is also installed and was used to confirm the `BEFORE` snippets.

Freshness: index.json still lists 0.16.0 (2026-04-13) as the newest non-master
release. Release dates for 0.14.0 / 0.14.1 / 0.15.1 / 0.15.2 / 0.16.0 all match
`version-history.md`.

**Six corrections were required.** The earlier draft of this entry claimed "no
content corrections were needed"; that was a spot-check reported as a full pass
and is retracted.

- `troubleshooting/references/troubleshooting.md` — `std.heap.DebugAllocator(.{}).init(std.heap.page_allocator)` called `init` as a function. At 0.16.0 `init` is a constant (`pub const init: Self = .{};`, `lib/std/heap/debug_allocator.zig:175`), so the snippet did not compile. It also contradicted `allocators/references/allocators.md`, which had the correct form. Rewritten to `var debug_alloc: std.heap.DebugAllocator(.{}) = .init;`.
- `zig/references/migration-0.16.md` — "`std.c.arc4random_buf` is only available on BSDs and Darwin" was refuted by its own citation: `lib/std/c.zig:10347` is a `switch (native_os)` whose `.linux` arm covers Android and glibc ≥ 2.36. Replaced with a compile-probed target table; also corrected "link error" to compile error (`error: type 'void' not a function`).
- `troubleshooting/references/troubleshooting.md` — the 0.15→0.16 table listed "`@cImport` deprecation warnings" as an observed error. `@cImport` compiles silently at 0.16.0; the deprecation exists only in the release notes. Row reworded to say no diagnostic fires.
- `troubleshooting/references/troubleshooting.md` — "`std.process.Child` → `std.process.spawn(io, ...)`" read as a removal. `Child` still exists at 0.16.0 as the handle type `spawn` returns; only `Child.run`/`Child.init` moved to free functions. Reworded.
- `zig/references/version-history.md` — `fmt.bufPrintZ` was listed under "Renamed". It is still present at 0.16.0, marked `/// Deprecated in favor of bufPrintSentinel`. Split from the genuine renames (`fmt.Formatter`, `fs.File.Mode`, both gone).
- `language/references/language.md` — the `defer` example opened a file with `std.fs.cwd()`, which does not exist at 0.16.0. Rewritten against `std.Io.Dir.cwd().openFile(io, ...)` / `file.close(io)`, with the pre-0.16 form kept as a note.

**Confirmed unchanged.** All seven `lib/std/...` source-line citations resolve to
the cited line at 0.16.0: `Io/Reader.zig:152` (`Reader.fixed`),
`array_list.zig:591` (`empty`), `std.zig:41` (`StringArrayHashMapUnmanaged`),
`c.zig:10347` (`arc4random_buf`), `Io.zig:2468` (`random`),
`process.zig:496` (`run` signature, verbatim match),
`heap/debug_allocator.zig:175` (`init`). The `allocators.md` and `testing.md`
snippets compile and pass as `zig test`; every `AFTER` snippet in
`migration-0.16.md` §1–§6 compiles; `build.md`'s `build.zig` + `build.zig.zon`
build, test, and run end to end, and `--watch`, `-fincremental`, `--time-report`,
`-Doptimize`, `-Dtarget` are all present in `zig build --help`. `@Type` removal
and its eight replacement builtins, the `@floor`/`@ceil`/`@round`/`@trunc`
integer result-location conversion, `@intFromFloat` deprecation, and the
"returning address of expired local variable" error all match the 0.16.0 release
notes. Every removal claimed for 0.16 (`std.heap.ThreadSafeAllocator`,
`SegmentedList`, `Io.GenericWriter`/`AnyWriter`/`null_writer`,
`Io.CountingReader`, `fs.getAppDataDir`, `std.once`, `BoundedArray`,
`RingBuffer`, `fifo`, all `std.Thread` sync primitives, `std.io`) was confirmed
absent, and every claimed addition (`fmt.Alt`, `bufPrintSentinel`,
`Io.File.Permissions`, `captureCurrentStackTrace`, `Io.Timestamp`,
`process.Init`, `Io.Group`, `testing.io`, `Io.Threaded.init_single_threaded`)
present.

**Citation anchoring.** The `lib/std/...` citations resolve against a local
`zig 0.16.0` install, not against a git tag: ziglang's newest GitHub tag is
`0.15.2` and no `0.16.0` tag exists (confirmed 404 via the GitHub API), because
the project moved to Codeberg. Re-verify by installing 0.16.0 and reading the
cited paths, or via Codeberg — not via github.com/ziglang/zig at a tag.

### 2026-06-14 — 0.15→0.16 migration reference

- **Added**: `skills/zig/references/migration-0.16.md` — field-observed 0.15→0.16 breakages with BEFORE/AFTER snippets for 7 areas: sync primitives, Reader API, ArrayList, ordered maps, C interop, process API, macOS 26 build gotcha.
- **Verified against**: `~/.local/share/mise/installs/zig/0.16.0/lib/std/` — `Io.zig`, `Io/Reader.zig`, `Io/RwLock.zig`, `array_list.zig`, `array_hash_map.zig`, `process.zig`, `c.zig`, `Build/Module.zig`. Access date: 2026-06-14.
- **Linked from**: `skills/zig/SKILL.md` version table section (one level deep).

### 2026-06-12 — Zig 0.16.0

- **Release Notes**: https://ziglang.org/download/0.16.0/release-notes.html and https://ziglang.org/download/0.15.1/release-notes.html
- **Summary**: Updated plugin from 0.14 to 0.16.0 (current stable, released 2026-04-13). Added versioned templates (`templates/0.14.1/`, `templates/0.15.2/`, `templates/0.16.0/`) and `references/version-history.md` to the zig skill. 0.16 changes documented: std.Io async architecture (io parameter, Future, Io.Threaded), `@cImport` deprecated for `b.addTranslateC()`, `@Type` replaced by dedicated builtins, "juicy main", sync primitives under `std.Io.*`. 0.15 changes documented: std.Io Reader/Writer redesign ("Writergate"), unmanaged `std.ArrayList` default, `usingnamespace`/`async` removal, top-level `root_source_file` removed from build options, `addLibrary` replacing `addStaticLibrary`/`addSharedLibrary`, `{f}` format specifier.
- **Verified against source**: `lib/std/Build.zig` and `lib/std/heap/debug_allocator.zig` at tag 0.15.1 (DebugAllocator `.init` constant, `root_module`-only options structs).
- **0.14.0 Release Notes**: https://ziglang.org/download/0.14.0/release-notes.html (build.zig.zon `fingerprint` field, enum-literal `name`, new hash format)
- **Bootstrap**: Added `sources.toml` for staleness tracking. `check_method` is `manual`: ziglang stopped tagging GitHub releases after 0.15.2, so the GitHub releases API under-reports (it returned 0.15.1 as latest on 2026-06-12 while 0.16.0 was current). Authoritative list: https://ziglang.org/download/index.json.

## Zig Skill

### Zig Language Reference
- **URL**: https://ziglang.org/documentation/master/
- **Purpose**: Official language reference documentation
- **Date Accessed**: 2026-02-21
- **Key Topics**: Comptime, allocators, error handling, slices, optionals, packed structs, pointers, arrays, C interop, strings, enums, unions, testing

### Zig Language Overview
- **URL**: https://ziglang.org/learn/overview/
- **Purpose**: Language philosophy and design goals
- **Date Accessed**: 2026-02-21
- **Key Topics**: Design principles, no hidden control flow, no hidden allocations, C ecosystem integration, cross-compilation

### Zig Guide
- **URL**: https://zig.guide/
- **Purpose**: Practical patterns and examples for learning Zig
- **Date Accessed**: 2026-02-21
- **Key Topics**: Language basics, allocators, error handling, comptime, structs, defer

### Zig Build System
- **URL**: https://ziglang.org/learn/build-system/
- **Purpose**: Build system reference and patterns
- **Date Accessed**: 2026-02-21
- **Key Topics**: build.zig structure, build steps, dependencies, cross-compilation, linking, package management

### Zig Testing Reference
- **URL**: https://ziglang.org/documentation/master/#Zig-Test
- **Purpose**: Built-in test framework documentation
- **Date Accessed**: 2026-02-21
- **Key Topics**: Test syntax, test allocator, expect functions, build integration, filtering, doctests

## Plugin Information

- **Name**: zig
- **Description**: Zig programming skills: build system, comptime, allocators, error handling, C interop, and best practices
- **Skills**: 1 Zig skill
- **Created**: 2026-02-21
