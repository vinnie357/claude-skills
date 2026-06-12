# Zig Version History

Version-aware reference for the zig plugin skills. Zig is pre-1.0: every minor
release carries breaking changes. Run `zig version` before asserting that any
documented API exists in the installed toolchain.

Sources: https://ziglang.org/download/0.16.0/release-notes.html,
https://ziglang.org/download/0.15.1/release-notes.html, and
https://ziglang.org/download/0.14.0/release-notes.html (accessed 2026-06-12).

Authoritative release list: https://ziglang.org/download/index.json — GitHub
tags stop at 0.15.2, so do NOT rely on the GitHub releases API for staleness.

## 0.16.0 (2026-04-13) — current

### Language

| Change | Migration |
|---|---|
| `@Type` builtin removed | Use dedicated builtins: `@Int()`, `@Struct()`, `@Enum()`, `@Union()`, `@Pointer()`, `@Fn()`, `@Tuple()`, `@EnumLiteral()` (e.g. `@Int(.unsigned, 10)`) |
| `@cImport` deprecated | Move includes to a C header and use `b.addTranslateC()` in build.zig + `@import("c")` |
| `@floor`/`@ceil`/`@round`/`@trunc` convert directly to integers | `const n: u8 = @round(value);` — `@intFromFloat` deprecated for this use |
| Small int-to-float coercion allowed when lossless | `var f: f32 = small_int;` works without `@floatFromInt` |
| Returning the address of an expired local is a compile error | Return by value or allocate |
| Packed unions must fill the backing integer; pointers forbidden in packed types | `packed union(u16) {...}`; store `usize` + `@ptrFromInt` |
| Extern enums require explicit tag types | `enum(u8) { a, b }` not `enum { a, b }` |
| Runtime vector indexing forbidden | Coerce the vector to an array first |
| `*u8` and `*align(1) u8` are now distinct types | Annotate alignment where required |

### Standard library — std.Io async architecture lands

All blocking/nondeterministic operations now take an `io: Io` parameter.
Implementations: `Io.Threaded` (complete), `Io.Evented` (WIP), `Io.Uring`
(proof-of-concept). Fallback for code without an Io:

```zig
var threaded: Io.Threaded = .init_single_threaded;
const io = threaded.io();
```

| Change | Migration |
|---|---|
| Filesystem moves to `std.Io.Dir`/`std.Io.File` | `fs.cwd()` → `std.Io.Dir.cwd()`; `file.read()` → `file.readStreaming(io)` |
| Process spawning reworked | `std.process.Child.init` → `std.process.spawn(io, .{ .argv = argv })`; `Child.run` → `std.process.run(allocator, io, .{...})` |
| Sync primitives move under `std.Io` | `std.Thread.Mutex/Condition/RwLock/Semaphore/ResetEvent` → `std.Io.Mutex/Condition/RwLock/Semaphore/Event`; `std.Thread.Pool` and `std.once` removed |
| Async tasks | `io.async(fn, args)` / `io.concurrent(fn, args)` → `Future(T)` with `.await(io)`/`.cancel(io)`; `Io.Group` for many tasks; built-in cancellation (`error.Canceled`) |
| Entropy and time | `std.crypto.random.bytes()` → `io.random()`; `std.time.Instant`/`Timer` → `std.Io.Timestamp` |
| "Juicy main" | `pub fn main(init: std.process.Init) !void` provides `init.arena`, `init.gpa`, `init.io`, `init.minimal.args`; env vars and args are no longer global |
| `ArenaAllocator` thread-safe and lock-free; `std.heap.ThreadSafeAllocator` removed | Drop the wrapper |
| Removed: `SegmentedList`, `Io.GenericWriter`/`AnyWriter`/`null_writer`, `Io.CountingReader`, `fs.getAppDataDir`, `*Z`/`*W` path variants | See release notes for per-API replacements |
| Renamed: `fmt.Formatter` → `fmt.Alt`, `fmt.bufPrintZ` → `bufPrintSentinel`, `fs.File.Mode` → `std.Io.File.Permissions` | Mechanical rename |
| Stack trace API reworked | `std.debug.captureCurrentStackTrace(options, addr_buf)` / `writeCurrentStackTrace` |
| `std.testing.io` added | Use in tests that perform I/O, like `std.testing.allocator` |

### Build system and toolchain

| Change | Migration |
|---|---|
| `b.addTranslateC()` is the C-import path | See zig:c-interop skill |
| Unit test timeouts; `--error-style` and `--multiline-errors` flags; project-local package directory; local package overrides | New capabilities, no migration |
| LLVM 21; new self-hosted ELF linker; x86_64/aarch64/wasm backend improvements | Re-test with `-fllvm` when suspecting backend bugs |
| Platform changes | Solaris/AIX/z/OS removed; maccatalyst + loongarch32-linux added; glibc 2.43, musl 1.2.5 |

## 0.15.x (0.15.1 2025-08-19, 0.15.2 2025-10-11)

0.15.1 superseded 0.15.0 within days; 0.15.2 is the final 0.15 patch.

### Language

| Change | Migration |
|---|---|
| `usingnamespace` removed | Replace conditional inclusion with `if`/`@compileError()`; for mixins use zero-bit fields + `@fieldParentPtr()` |
| `async`/`await` keywords and `@frameSize` removed | Async moves to the standard library as part of the upcoming `std.Io` interface |
| Inline assembly clobbers are typed | `"rcx", "r11"` → `.{ .rcx = true, .r11 = true }`; `zig fmt` upgrades automatically |
| Lossy int-to-float coercion is a compile error | Change integer literals to float literals (`123_456_789.0`) |
| `@ptrCast` can cast single-item pointers to slices | New capability, no migration |
| Non-exhaustive enum `switch` may mix explicit tags with `_` prong | `else` and `_` in the same switch is now a compile error |

### Standard library — "Writergate" I/O redesign

`std.io` generic readers/writers are replaced by concrete `std.Io.Reader` /
`std.Io.Writer` interfaces with caller-provided buffers and precise error sets.

```zig
// 0.14
const stdout = std.io.getStdOut().writer();
var bw = std.io.bufferedWriter(stdout);

// 0.15
var stdout_buffer: [1024]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;
// ... write ...
try stdout.flush(); // explicit flush required
```

Bridge legacy streams with `old_writer.adaptToNewApi(&.{})`.

Removed types: `std.io.BufferedReader/BufferedWriter`, `CountingWriter` (use
`std.Io.Writer.Discarding`), `BitReader/BitWriter`, `SeekableStream`,
`LimitedReader`, `GenericReader`/`AnyReader`, `std.fifo.LinearFifo`,
`std.RingBuffer`.

### Standard library — containers and formatting

| Change | Migration |
|---|---|
| `std.ArrayList(T)` is now unmanaged (no stored allocator) | `var list: std.ArrayList(u8) = .empty;` then pass the allocator to `append`/`deinit`. Old managed type lives on as `std.array_list.Managed(T)` (deprecated) |
| `std.BoundedArray` removed | Use `std.ArrayListUnmanaged.initBuffer(&buf)` for stack buffers, or a plain slice + length |
| Linked lists de-generified | Embed `std.DoublyLinkedList.Node` as a field; recover the parent with `@fieldParentPtr` |
| `{}` no longer calls custom `format` methods | Use `{f}`; `format` signature is now `fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void` |
| New format specifiers | `{t}` (`@tagName`/`@errorName`), `{B}`/`{Bi}` (sizes), `{D}` (duration), `{b64}` (base64), `{x}`/`{X}` (hex slices) |
| `std.fmt.format` removed | Use `std.Io.Writer.print` |
| `std.compress.flate` compression removed; decompression API reworked | `var d: std.compress.flate.Decompress = .init(reader, .zlib, &buf)`; checksums are out-of-band |
| `std.http` client/server redesigned over `std.Io.Reader/Writer` | Separate `sendBodiless()` / `receiveHead()` / explicit `reader()` calls |

### Build system and toolchain

| Change | Migration |
|---|---|
| Top-level `root_source_file` removed from `addExecutable`/`addTest` options | Use `.root_module = b.createModule(.{ .root_source_file = ..., .target = ..., .optimize = ... })` (the 0.14-recommended form) |
| Self-hosted x86_64 backend is the Debug-mode default | Opt out with `-fllvm` or `use_llvm = true` if you hit backend bugs |
| `sanitize_c` build option type changed `?bool` → `?std.zig.SanitizeC` | `true` → `.full`, `false` → `.off`; CLI gains `-fsanitize-c=trap|full` |
| `zig build --watch` fixed on macOS; pairs with `-fincremental` | New `watch` task in `templates/0.15.2/mise.toml` |
| `zig init` template includes module + executable; `--minimal`/`-m` flag added | — |
| `zig test-obj` emits a test object for external harnesses | Build API: `addTest(.{ .emit_object = true, ... })` |
| `zig objcopy` temporarily removed | Operations error "unimplemented" pending rework (ziglang/zig#24522) |
| LLVM 20.1.8; glibc 2.42; FreeBSD/NetBSD cross-compilation with dynamic libc | — |

### Diagnosing 0.14 → 0.15 breakage

- `error: no field named 'root_source_file' in struct 'Build.ExecutableOptions'` → wrap in `root_module = b.createModule(...)`
- Errors about missing `init`/`deinit` arity on `ArrayList` → unmanaged migration (pass allocator per call)
- Custom `format` method never called / format compile errors → switch `{}` to `{f}` and update the signature; build with `-freference-trace` to locate every offending format string
- Output never appears → missing explicit `try writer.flush()`

## 0.14.x (2025-03-05 / 0.14.1 2025-05)

Documented baseline for `templates/0.14.1/mise.toml`. Key facts relevant to this plugin:

- `build.zig.zon` gained the auto-generated `fingerprint` field (never change it once created); `name` must be a valid bare Zig identifier (32-byte limit) written as an enum literal (`.name = .myproject`)
- New package hash format embeds name/version metadata (`mime-3.0.0-zwmL-...`)
- `root_module = b.createModule(...)` introduced as the recommended form; the top-level `root_source_file` fields were deprecated (removed in 0.15)
- `std.ArrayList` was still managed (`init(allocator)` / `list.deinit()`)
- `usingnamespace` and `async`/`await` still parsed (removed in 0.15)
