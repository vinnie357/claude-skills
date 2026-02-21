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

Check paths are relative to build root:

```zig
.root_source_file = b.path("src/main.zig"),
```

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
