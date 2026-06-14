# Zig 0.15 → 0.16 Migration Reference

Field-observed breakages from migrating a downstream project from Zig 0.15 to
0.16. Zig is pre-1.0 — every minor release carries breaking API changes. All
`AFTER` snippets verified against the installed
`~/.local/share/mise/installs/zig/0.16.0/lib/std/` stdlib unless noted.

---

## 1. Sync primitives: `std.Thread.Mutex` removed

**Why.** 0.16 moves all blocking synchronization under `std.Io` because
cross-thread operations now require an `io` parameter to participate in the
async scheduler.

**BEFORE (0.15)**
```zig
var mu: std.Thread.Mutex = .{};
mu.lock();
defer mu.unlock();
```

**AFTER (0.16)**
```zig
// Full Io-backed mutex (requires an Io instance).
var mu: std.Io.Mutex = .init;
try mu.lock(io);          // Cancelable!void — cancelable, needs io
defer mu.unlock(io);

// Uncancelable variant (never returns an error):
mu.lockUncancelable(io);
defer mu.unlock(io);
```

**Test-local spinlock alternative.** When you only need mutual exclusion inside
a single test (no scheduler required), a lightweight spinlock on an atomic avoids
the need for an `Io`:

```zig
const std = @import("std");

pub const Spinlock = struct {
    state: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn lock(s: *Spinlock) void {
        while (s.state.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(s: *Spinlock) void {
        s.state.store(false, .release);
    }
};
```

`std.Thread.Condition`, `std.Thread.RwLock`, `std.Thread.Semaphore`,
`std.Thread.ResetEvent`, and `std.Thread.Pool` are also removed; use
`std.Io.Condition`, `std.Io.RwLock`, `std.Io.Semaphore`, `std.Io.Event`,
and `io.async`/`Io.Group` respectively.

---

## 2. Reader API: `fixedBufferStream` and `AnyReader` removed

**Why.** The 0.15 "Writergate" redesigned I/O to concrete `std.Io.Reader` /
`std.Io.Writer` types with explicit caller-provided buffers. In 0.16 the old
`std.io` shim layer is fully gone.

**BEFORE (0.15)**
```zig
const stream = std.io.fixedBufferStream(buf);
const reader = stream.reader().any();  // AnyReader
```

**AFTER (0.16)**
```zig
// Reader.fixed returns a Reader by value; pass a pointer to callers.
var reader: std.Io.Reader = std.Io.Reader.fixed(buf);
// Pass as *std.Io.Reader:
process(&reader);

fn process(r: *std.Io.Reader) void {
    // use r.peek(), r.discard(), r.appendExact(), etc.
}
```

`std.Io.Reader.fixed` is verified in
`lib/std/Io/Reader.zig:152`.

---

## 3. ArrayList: unmanaged by default (allocator per call)

**Why.** 0.15 made `std.ArrayList` unmanaged (no stored allocator field).
The managed wrapper moved to `std.array_list.Managed(T)` (deprecated).
`std.ArrayListUnmanaged` is now an alias for `std.ArrayList`.

**BEFORE (0.15 managed — via deprecated wrapper)**
```zig
var list = std.array_list.Managed(u8).init(gpa);
defer list.deinit();
try list.append('x');
```

**AFTER (0.16 — standard unmanaged form)**
```zig
var list: std.ArrayList(u8) = .empty;   // or = .{}
defer list.deinit(gpa);
try list.append(gpa, 'x');
```

The `empty` sentinel is verified in `lib/std/array_list.zig:591`.
Every method that allocates (`append`, `appendSlice`, `ensureCapacity`, …)
now takes `gpa: Allocator` as its first parameter.

---

## 4. Ordered maps: use `std.array_hash_map.String(V)` for insertion-order maps

**Why.** `std.StringHashMap` exists in 0.16 but does **not** preserve insertion
order. When iteration order matters, use the array-backed variant.

**BEFORE — unordered (still valid in 0.16, but order is undefined)**
```zig
var map = std.StringHashMap(u32).init(gpa);
defer map.deinit();
try map.put("a", 1);
try map.put("b", 2);
```

**AFTER — insertion-order preserved**
```zig
// std.array_hash_map.String(V) is the unmanaged, ordered form.
var map: std.array_hash_map.String(u32) = .empty;
defer map.deinit(gpa);
try map.put(gpa, "a", 1);
try map.put(gpa, "b", 2);
// Iteration yields "a" then "b" in insertion order.
```

`std.StringArrayHashMapUnmanaged` is an alias for `std.array_hash_map.String`
(verified in `lib/std/std.zig:41`). Pick deliberately:
- `std.StringHashMap` → unordered, bucket hash map, O(1) average lookup.
- `std.array_hash_map.String` → ordered, array-backed, O(N) ordered remove but
  preserves insertion order.

---

## 5. C interop + libc: explicit `link_libc` required

**Why.** `std.c.getenv`, `std.c.environ`, and platform functions like
`arc4random_buf` are declared in Zig's libc bindings. Calling them from a
module that does not link libc produces an undefined-symbol link error.

**BEFORE (0.15) — implicit libc sometimes worked**
```zig
// In source:
const val = std.c.getenv("HOME");
```

**AFTER (0.16) — require explicit libc linkage in build.zig**
```zig
// build.zig
const exe = b.addExecutable(.{
    .name = "myprog",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,   // <-- required for std.c.* usage
    }),
});
```

For `setenv`/`unsetenv` (not available as `std.c.*` in all configurations),
declare the extern directly:

```zig
extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;
extern "c" fn unsetenv(name: [*:0]const u8) c_int;
```

**Portability note.** `std.c.arc4random_buf` is only available on BSDs and
Darwin (verified in `lib/std/c.zig:10347`). For portable cryptographic random
bytes prefer `io.random(buffer)` (verified in `lib/std/Io.zig:2468`), which
works on all supported targets without libc.

---

## 6. Process API: `io` parameter required on `run` and `spawn`

**Why.** Process spawning is a blocking operation; 0.16's `std.Io` architecture
requires all blocking calls to accept an `io` parameter.

**BEFORE (0.15)**
```zig
const result = try std.process.Child.run(.{
    .allocator = gpa,
    .argv = &.{ "zig", "version" },
});
defer gpa.free(result.stdout);
defer gpa.free(result.stderr);
```

**AFTER (0.16)**
```zig
const result = try std.process.run(gpa, io, .{
    .argv = &.{ "zig", "version" },
});
defer gpa.free(result.stdout);
defer gpa.free(result.stderr);
```

Signature verified in `lib/std/process.zig:496`:
`pub fn run(gpa: Allocator, io: Io, options: RunOptions) RunError!RunResult`.

For fire-and-forget spawning: `std.process.spawn(io, .{ .argv = ... })`.

---

## 7. Build gotcha: macOS 26 link failure under cold cache

**Symptom.** On macOS 26 (Sequoia or later) with a cold Burrito/Zig cache,
`zig build -Doptimize=ReleaseSafe` (or `mix release`) fails with undefined
libc symbols from `compiler_rt` when the Xcode Command Line Tools (CLT) are
installed but the full Xcode.app is the active SDK.

```
ld: symbol(s) not found for architecture arm64
error: linker command failed with exit code 1
```

**Fix.** Force `xcrun` to resolve the CLT SDK by setting `DEVELOPER_DIR`
before the build:

```toml
# mise.toml [env] section
[env]
DEVELOPER_DIR = "/Library/Developer/CommandLineTools"
```

Or per-command:

```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools zig build
```

This is an environment / toolchain issue, not a Zig API change. It is
reproducible with a cold cache because a warm cache reuses pre-linked
`compiler_rt` objects from an earlier successful build where the SDK path
happened to be correct.

---

## Diagnosing common 0.15 → 0.16 error messages

| Error | Cause | Section above |
|---|---|---|
| `no field 'Mutex' in 'std.Thread'` | Thread sync primitives removed | §1 |
| `use of undeclared identifier 'fixedBufferStream'` | `std.io` shim removed | §2 |
| `no field 'AnyReader' in 'std.io'` | `std.io` shim removed | §2 |
| `expected type 'std.ArrayList'… wrong number of arguments to 'init'` | Unmanaged by default | §3 |
| `'append' takes 2 arguments, got 1` | Pass allocator per-call | §3 |
| `undefined symbol '_getenv'` | Missing `link_libc = true` | §5 |
| `'run' takes 3 arguments, got 2` | `io` param added | §6 |
| `symbol(s) not found for architecture arm64` (link) | macOS 26 SDK path | §7 |
