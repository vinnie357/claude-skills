# Zig Troubleshooting Reference

## Common Compiler Errors

### "expected type 'X', found 'Y'"

Type mismatch. Common causes:
- Passing `[]u8` where `[]const u8` is expected (add `const`)
- Mixing signed and unsigned integers (use `@intCast()`)
- Forgetting to dereference a pointer (`ptr.*` not `ptr`)

```zig
const unsigned: u32 = @intCast(signed_value);
```

### "error: use of comptime value at runtime"

Attempting to use a comptime-only value at runtime:

```zig
// Wrong: comptime_int used at runtime
const x = 5;
some_runtime_fn(x); // Error

// Fix: annotate with runtime type
const x: usize = 5;
```

### "error: expected tuple or struct, found 'void'"

Missing `.{}` in print format:

```zig
// Wrong
std.debug.print("hello\n");

// Fix
std.debug.print("hello\n", .{});
```

### "error: value not captured"

Forgetting to capture a value from for/while/if:

```zig
// Wrong
for (items) { }

// Fix
for (items) |item| { _ = item; }
```

### "error: unused variable/parameter"

Zig does not allow unused variables. Use `_` to discard:

```zig
fn callback(_: *Context, data: []const u8) void {
    _ = data;
}
```

## Runtime Panics

### "index out of bounds"

Array or slice access beyond length (Debug and ReleaseSafe modes).

```zig
if (index < slice.len) {
    const val = slice[index];
}
```

### "integer overflow"

Arithmetic overflow detected in safe modes.

```zig
const result = a +% b;  // wrapping add
const result = a +| b;  // saturating add
```

### "reached unreachable code"

An `unreachable` was executed. Usually a non-exhaustive switch.

### "null pointer dereference"

Accessing `.?` on a null optional:

```zig
if (maybe_ptr) |ptr| {
    ptr.doSomething();
} else {
    // handle null
}
```

## Memory Issues

### Detecting Leaks in Tests

```zig
test "no leaks" {
    const alloc = std.testing.allocator;
    var data = try alloc.alloc(u8, 100);
    defer alloc.free(data);
}
```

### Use-After-Free / Double-Free

Use `DebugAllocator` to detect at runtime:

```zig
var debug_alloc = std.heap.DebugAllocator(.{}).init(std.heap.page_allocator);
defer _ = debug_alloc.deinit();
```

### Common Leak Pattern

```zig
// Leak: errdefer missing
fn create(alloc: Allocator) !*Thing {
    const a = try alloc.create(Thing);
    a.data = try alloc.alloc(u8, 100); // if this fails, 'a' leaks
    return a;
}

// Fix
fn create(alloc: Allocator) !*Thing {
    const a = try alloc.create(Thing);
    errdefer alloc.destroy(a);
    a.data = try alloc.alloc(u8, 100);
    errdefer alloc.free(a.data);
    return a;
}
```

## Build Issues

### "error: FileNotFound" for source files

Check paths are relative to build root (inside `b.createModule(...)`):

```zig
.root_source_file = b.path("src/main.zig"),
```

### 0.14 → 0.15 migration errors

| Error | Cause | Fix |
|---|---|---|
| `no field named 'root_source_file' in struct 'Build.ExecutableOptions'` | Top-level build fields removed in 0.15 | Wrap in `.root_module = b.createModule(.{ .root_source_file = ..., .target = ..., .optimize = ... })` |
| `no member named 'init' in struct` on `std.ArrayList` | `ArrayList` is unmanaged in 0.15 | `var list: std.ArrayList(T) = .empty;` and pass the allocator to `append`/`deinit` |
| Compile errors in custom `format` methods; `{}` no longer formats a struct | Format method signature changed in 0.15 | Use `{f}` and `fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void`; build with `-freference-trace` to find every broken format string |
| `usingnamespace` / `async` / `await` syntax errors | Keywords removed in 0.15 | Restructure with explicit declarations; async moves to the std.Io interface |
| Program produces no output with new `std.Io` writers | Buffered writer never flushed | Call `try writer.flush()` before exit |
| Suspected codegen bug in Debug builds (0.15+) | Self-hosted x86_64 backend is the Debug default | Re-test with `-fllvm` to compare against the LLVM backend |

### 0.15 → 0.16 migration errors

| Error | Cause | Fix |
|---|---|---|
| `@Type` not found | Builtin removed in 0.16 | Use the dedicated builtins: `@Int()`, `@Struct()`, `@Enum()`, `@Union()`, `@Pointer()`, `@Fn()`, `@Tuple()`, `@EnumLiteral()` |
| `@cImport` deprecation warnings | Moving to the build system in 0.16 | `b.addTranslateC(.{...})` in build.zig + `@import("c")` in source |
| Filesystem/network/process calls fail to compile, missing `io` argument | 0.16 `std.Io` interface: blocking operations take an `io: Io` parameter | Thread an `Io` instance through (e.g. `var threaded: Io.Threaded = .init_single_threaded; const io = threaded.io();`); `fs.cwd()` → `std.Io.Dir.cwd()`, `std.process.Child` → `std.process.spawn(io, ...)` |
| `std.Thread.Mutex` / `Condition` / `RwLock` / `Pool` not found | Sync primitives moved under `std.Io` in 0.16 | `std.Io.Mutex`, `std.Io.Condition`, `std.Io.RwLock` (require an `Io`); `std.Thread.Pool` removed — use `io.async`/`Io.Group` |
| `returning address of expired local variable` | New 0.16 compile error | Return by value or allocate; do not return pointers to locals |
| `@intFromFloat` deprecation | 0.16 lets `@floor`/`@ceil`/`@round`/`@trunc` produce integers directly | `const n: u8 = @round(value);` |

### Dependency fetch failures

```bash
rm -rf .zig-cache
zig fetch --save <url>
```

### .zig-cache corruption

```bash
rm -rf .zig-cache
zig build
```

## Debugging Techniques

### Compile-Time Debugging

```zig
comptime {
    @compileLog("value is:", some_comptime_value);
}
```

### Runtime Debugging

```zig
std.debug.print("value: {d}, ptr: {*}\n", .{ value, ptr });
std.log.info("processing {d} items", .{count});
std.log.err("failed: {s}", .{path});
```

### Format Specifiers

| Specifier | Type | Output |
|-----------|------|--------|
| `{d}` | integers | decimal |
| `{x}` | integers | hexadecimal |
| `{b}` | integers | binary |
| `{s}` | `[]const u8` | string |
| `{*}` | pointers | address |
| `{any}` | any type | debug format |
| `{e}` | errors | error name |

## Common Pitfalls

- Forgetting `.{}` in print/log calls
- Mutating through `const` slice (use `var` binding)
- Returning pointer to stack variable (use allocator)
- Using `[]const u8` where C expects `[:0]const u8` (sentinel-terminated)
