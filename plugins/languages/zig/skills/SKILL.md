---
name: zig-language
description: Guide for writing Zig code. Use when working with build.zig, comptime generics, allocators, error unions, C interop, or following Zig best practices.
---

# Zig Programming Language

This skill activates when writing Zig code, working with the build system, using comptime for generics, managing memory with allocators, or interfacing with C libraries.

## When to Use This Skill

Activate when:
- Writing Zig code
- Configuring build.zig and build steps
- Using comptime for compile-time execution and generics
- Managing memory with allocators
- Handling errors with error unions and errdefer
- Working with slices, arrays, and pointers
- Interfacing with C libraries via @cImport
- Writing and running tests with zig test
- Formatting code with zig fmt

## Build System

### build.zig Structure

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    // Run step
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    // Test step
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
```

### Build Modes

| Mode | Safety Checks | Optimizations | Use Case |
|------|---------------|---------------|----------|
| `Debug` | Yes | None | Development |
| `ReleaseSafe` | Yes | Yes | Production with safety |
| `ReleaseFast` | No | Maximum | Performance-critical |
| `ReleaseSmall` | No | Size-focused | Embedded/WASM |

### Build Commands

```bash
zig build                          # Default build
zig build run                      # Build and run
zig build test                     # Run tests
zig build -Doptimize=ReleaseSafe   # Build with safety + optimizations
zig build -Dtarget=x86_64-linux-gnu  # Cross-compile
```

### Linking C Libraries

```zig
exe.linkSystemLibrary("z");
exe.linkLibC();
```

### Build Options

```zig
const version = b.option([]const u8, "version", "Application version") orelse "dev";
const options = b.addOptions();
options.addOption([]const u8, "version", version);
exe.root_module.addOptions("config", options);
// In source: const config = @import("config");
```

### Dependencies (build.zig.zon)

External dependencies are declared in `build.zig.zon` and fetched with `zig fetch`.

### Directory Structure

- `.zig-cache/` - compilation cache (exclude from VCS)
- `zig-out/` - installation prefix (binaries, libs, headers)

## Memory Management

### Allocator Types

| Allocator | Use Case |
|-----------|----------|
| `std.heap.page_allocator` | System page allocation, slow for small items |
| `std.heap.FixedBufferAllocator` | Pre-allocated fixed buffer, no heap |
| `std.heap.ArenaAllocator` | Batch deallocation, wraps child allocator |
| `std.heap.DebugAllocator` | Detects double-free, use-after-free, leaks |
| `std.heap.SmpAllocator` | High-performance general purpose, multithreaded |
| `std.heap.c_allocator` | C malloc/free wrapper, requires -lc |
| `std.testing.allocator` | Testing only, detects leaks in test output |

### Allocation Patterns

```zig
// Allocate and free with defer
const allocator = std.heap.page_allocator;
const memory = try allocator.alloc(u8, 100);
defer allocator.free(memory);

// Single item allocation
const byte = try allocator.create(u8);
defer allocator.destroy(byte);
```

### Arena Allocator (Batch Deallocation)

```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const alloc = arena.allocator();
// All allocations freed at once when arena.deinit() runs
```

### Key Principles

- No hidden memory allocations in the language or standard library
- Allocators are passed as explicit parameters to functions
- Always pair allocations with `defer` cleanup
- Use `errdefer` for cleanup on error paths

## Comptime

### Compile-Time Execution

```zig
// Comptime variable
comptime var x: i32 = 1;

// Comptime block
comptime {
    // Executed at compile time
}

// Comptime function execution
const result = comptime fibonacci(10);
```

### Generics via Comptime

```zig
fn List(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,

        const Self = @This();

        pub fn append(self: *Self, item: T) !void {
            // ...
        }
    };
}

// Usage
var my_list = List(i32).init(allocator);
```

### Generic Data Structure Pattern

```zig
fn ArrayList(comptime T: type) type {
    return struct {
        items: []T,
        capacity: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = &.{},
                .capacity = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.items);
        }
    };
}
```

### Key Builtins

- `@typeInfo(T)` - returns tagged union describing the type
- `@Type(info)` - constructs a type from @typeInfo data
- `@TypeOf(expr)` - gets the type of an expression
- `@This()` - self-referential type within struct/union
- `@compileError(msg)` - emit compile-time error
- `@compileLog(...)` - compile-time debug logging

### Comptime Rules

- `comptime_int` has arbitrary precision, no overflow
- Array concatenation (`++`) and repetition (`**`) are comptime-only
- Comptime code cannot depend on runtime values
- Use `PascalCase` for functions that return types

## Error Handling

### Error Sets

```zig
const FileOpenError = error{
    AccessDenied,
    OutOfMemory,
    FileNotFound,
};
```

### Error Unions

```zig
fn openFile(path: []const u8) FileOpenError!File {
    // Returns either File or FileOpenError
}

// Inferred error set
fn process() !void {
    // Error set inferred from all possible errors
}
```

### try - Error Propagation

```zig
const file = try openFile("config.json");
// Equivalent to:
const file = openFile("config.json") catch |err| return err;
```

### catch - Error Handling

```zig
const value = riskyOperation() catch |err| {
    std.log.err("Failed: {}", .{err});
    return defaultValue;
};

// Default value on error
const value = riskyOperation() catch 42;
```

### errdefer - Cleanup on Error

```zig
fn allocateResource(allocator: Allocator) !Resource {
    var resource = try allocator.create(Resource);
    errdefer allocator.destroy(resource);

    resource.data = try allocator.alloc(u8, 1024);
    errdefer allocator.free(resource.data);

    return resource;
}
```

### Merging Error Sets

```zig
const CombinedErrors = ErrorSetA || ErrorSetB;
```

### Best Practices

- Use specific error sets rather than `anyerror` for type safety
- Use `errdefer` for resource cleanup on error paths
- Zig forces explicit error handling via `try` or `catch`
- Error return traces are captured in debug builds automatically

## Data Types

### Structs

```zig
const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32 = 0, // default value

    const Self = @This();

    pub fn length(self: Self) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }
};

const v: Vec3 = .{ .x = 1, .y = 2 };
```

### Packed Structs (Bit-Level Control)

```zig
const Flags = packed struct {
    enabled: bool,  // 1 bit
    mode: u2,       // 2 bits
    reserved: u5,   // 5 bits
};
// Total: 8 bits = 1 byte
```

### Enums

```zig
const Color = enum { red, green, blue };

const Status = enum(u8) {
    pending = 0,
    active = 1,
    complete = 2,
};

const val = @intFromEnum(Status.active); // 1
```

### Tagged Unions

```zig
const Value = union(enum) {
    integer: i32,
    float: f32,
    string: []const u8,
    none: void,
};

switch (my_value) {
    .integer => |val| { /* handle i32 */ },
    .float => |val| { /* handle f32 */ },
    .string => |val| { /* handle string */ },
    .none => {},
}
```

### Optionals

```zig
const maybe: ?i32 = null;
const value: ?i32 = 42;

const unwrapped = maybe orelse 0;   // default value
const forced = value.?;             // panic if null
if (maybe) |v| {                    // if-capture
    // v is the unwrapped value
}
```

## Slices, Arrays, and Pointers

### Arrays (Fixed-Size)

```zig
const array: [5]u8 = [_]u8{ 1, 2, 3, 4, 5 };
const zeros: [10]u32 = [_]u32{0} ** 10;   // repeat pattern
const combined = array1 ++ array2;          // comptime concat
```

### Slices (Fat Pointers)

```zig
var array = [_]u8{ 1, 2, 3, 4, 5 };
const slice: []u8 = array[1..4];    // elements at indices 1,2,3
const open: []u8 = array[2..];      // from index 2 to end
// slice.ptr - pointer to data
// slice.len - number of elements
```

### Sentinel-Terminated Types

```zig
const c_string: [:0]const u8 = "hello"; // null-terminated string
```

### Pointer Types

| Type | Description |
|------|-------------|
| `*T` | Single-item pointer |
| `[*]T` | Many-item pointer (supports arithmetic) |
| `*[N]T` | Pointer to array |
| `[]T` | Slice (fat pointer: ptr + len) |
| `[*:0]T` | Sentinel-terminated many-item pointer |

### Strings

Zig strings are `[]const u8` (byte slices). String literals are `*const [N:0]u8` which coerce to `[]const u8`.

```zig
const hello: []const u8 = "hello";
const multiline =
    \\line one
    \\line two
;
std.mem.eql(u8, string1, string2); // string comparison
std.debug.print("Hello, {s}!\n", .{"World"});
```

## Resource Cleanup

### defer - Always Executes

```zig
const file = try std.fs.cwd().openFile("data.txt", .{});
defer file.close();
// file.close() runs when scope exits, regardless of how
```

### errdefer - Executes Only on Error

```zig
fn createThing(allocator: Allocator) !*Thing {
    const thing = try allocator.create(Thing);
    errdefer allocator.destroy(thing);
    thing.data = try allocator.alloc(u8, 1024);
    errdefer allocator.free(thing.data);
    return thing;
}
```

### Execution Order

Multiple `defer` statements execute in LIFO (reverse) order.

## Testing

### Test Declaration

```zig
const std = @import("std");

test "descriptive test name" {
    try std.testing.expect(addOne(41) == 42);
}

test addOne { // doctest - appears in generated docs
    try std.testing.expect(addOne(41) == 42);
}
```

### Testing Functions

```zig
try std.testing.expect(condition);                      // boolean
try std.testing.expectEqual(expected, actual);           // equality
try std.testing.expectError(expected_err, result);       // error check
try std.testing.expectEqualStrings(expected, actual);    // strings
try std.testing.expectEqualSlices(T, expected, actual);  // slices
```

### Test Allocator (Leak Detection)

```zig
test "no memory leaks" {
    const allocator = std.testing.allocator;
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try list.append('a');
    try std.testing.expect(list.items.len == 1);
}
```

### Running Tests

```bash
zig test file.zig                       # run tests in file
zig test file.zig --test-filter "name"  # filter by name
zig build test                          # run via build system
```

### Skipping Tests

```zig
test "platform-specific" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    // test body
}
```

### Detecting Test Builds

```zig
const builtin = @import("builtin");
if (builtin.is_test) {
    // test-only code
}
```

## C Interop

### Importing C Headers

```zig
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cDefine("_GNU_SOURCE", {});
});

const result = c.printf("Hello from C\n");
```

### Exporting Zig to C

```zig
pub export fn zig_function(param: c_int) c_int {
    return param + 1;
}
```

### C Type Mappings

| Zig Type | C Equivalent |
|----------|-------------|
| `c_char` | `char` |
| `c_int` | `int` |
| `c_long` | `long` |
| `c_uint` | `unsigned int` |
| `c_ulong` | `unsigned long` |

### translate-c Tool

```bash
zig translate-c -target x86_64-linux-gnu header.h > zig_header.zig
```

### Best Practices

- Keep C boundaries thin; wrap C APIs in Zig abstractions
- Use `[:0]const u8` for C string interop
- Prefer `@cImport` for simple headers; `translate-c` for complex ones

## Formatting and Style

### zig fmt

```bash
zig fmt file.zig      # format single file
zig fmt src/          # format directory recursively
zig fmt --check src/  # CI check (exit code 1 if unformatted)
```

### Naming Conventions

- `snake_case` for variables and functions
- `PascalCase` for types and type-returning functions
- `SCREAMING_SNAKE_CASE` for compile-time constants from `@import`
- Doc comments (`///`) for public API documentation
- Top-level comments (`//!`) for module-level documentation

## CI Patterns

```bash
# Full CI pipeline
zig fmt --check src/ && zig build test && zig build -Doptimize=ReleaseSafe

# Cross-compile targets
zig build -Dtarget=x86_64-linux-gnu
zig build -Dtarget=aarch64-linux-gnu
zig build -Dtarget=x86_64-windows
```

### mise Integration

Install Zig with mise and define project tasks for build, test, format, and CI workflows. See `templates/mise.toml` for a complete reusable configuration.

```bash
# Install Zig via mise
mise use zig@0.14

# Verify installation
mise exec -- zig version
```

```toml
# Project mise.toml
[tools]
zig = "0.14"

[tasks.build]
run = "zig build"

[tasks.test]
run = "zig build test"

[tasks.fmt]
run = "zig fmt src/"

[tasks."fmt:check"]
run = "zig fmt --check src/"

[tasks.ci]
description = "Run full CI pipeline (format check + tests)"
depends = ["fmt:check", "test"]
```

For build mode variants and the full task set, copy from `templates/mise.toml`.

## Key Principles

- **No hidden control flow**: if code does not look like it calls a function, it does not
- **No hidden memory allocations**: allocators are explicit parameters
- **No preprocessor, no macros**: comptime replaces both
- **Explicit over implicit**: be clear about allocations, errors, ownership
- **Performance and safety**: both achievable without compromise
- **C ecosystem integration**: use existing C libraries without depending on libc
- **Cross-compilation first-class**: target any platform from any platform
