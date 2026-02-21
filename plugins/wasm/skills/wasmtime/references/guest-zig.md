# Guest Language: Zig

Compile Zig code to WebAssembly for execution in Wasmtime.

## Wasm Targets

| Target | Use Case | WASI |
|--------|----------|------|
| `wasm32-wasi` | WASI modules (WASIp1) | Yes |
| `wasm32-freestanding` | Bare wasm, no system interface | No |

## Basic Setup

### Freestanding Module (No WASI)

`src/main.zig`:
```zig
export fn add(a: i32, b: i32) i32 {
    return a + b;
}
```

Build:
```bash
zig build-lib src/main.zig -target wasm32-freestanding -dynamic -O ReleaseSmall
# Output: main.wasm
```

### With build.zig

`build.zig`:
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "my_lib",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Export specific symbols
    lib.rdynamic = true;

    b.installArtifact(lib);
}
```

```bash
zig build -Doptimize=ReleaseSmall
# Output: zig-out/lib/my_lib.wasm
```

### WASI Module

`build.zig`:
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "my_app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);
}
```

`src/main.zig`:
```zig
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello from Zig WASI!\n", .{});
}
```

```bash
zig build -Doptimize=ReleaseSmall
wasmtime zig-out/bin/my_app.wasm
```

## Exporting Functions

### Basic Exports

```zig
// Functions marked `export` are visible to the host
export fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

// Export with a different name
comptime {
    @export(internalName, .{ .name = "external_name" });
}

fn internalName(x: i32) i32 {
    return x * 2;
}
```

### Exporting Memory

```zig
// The host needs access to the module's linear memory
// Zig automatically exports memory as "memory" for wasm targets
```

### Passing Strings and Buffers

Wasm only supports numeric types at the boundary. Pass strings as pointer + length.

```zig
// Allocate buffer in wasm memory for the host to write into
var buffer: [1024]u8 = undefined;

export fn get_buffer_ptr() [*]u8 {
    return &buffer;
}

export fn get_buffer_len() usize {
    return buffer.len;
}

// Process data the host wrote into the buffer
export fn process_buffer(len: usize) i32 {
    const data = buffer[0..len];
    // process data...
    return @intCast(data.len);
}
```

### Returning Strings to Host

```zig
const std = @import("std");

var result_buf: [4096]u8 = undefined;
var result_len: usize = 0;

export fn get_result_ptr() [*]const u8 {
    return &result_buf;
}

export fn get_result_len() usize {
    return result_len;
}

export fn greet(name_ptr: [*]const u8, name_len: usize) void {
    const name = name_ptr[0..name_len];
    const greeting = std.fmt.bufPrint(&result_buf, "Hello, {s}!", .{name}) catch return;
    result_len = greeting.len;
}
```

## Allocator Patterns

### No Allocator (Stack/Static Only)

For simple modules, avoid heap allocation entirely:

```zig
var static_buffer: [65536]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&static_buffer);

export fn process(ptr: [*]const u8, len: usize) i32 {
    const allocator = fba.allocator();
    defer fba.reset();
    // use allocator...
    return 0;
}
```

### Page Allocator

Use Zig's page allocator backed by `memory.grow`:

```zig
const allocator = std.heap.page_allocator;

export fn allocate(size: usize) ?[*]u8 {
    const slice = allocator.alloc(u8, size) catch return null;
    return slice.ptr;
}

export fn deallocate(ptr: [*]u8, size: usize) void {
    allocator.free(ptr[0..size]);
}
```

### General Purpose Allocator

For complex allocation patterns:

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
```

Note: The GPA has more overhead. Prefer fixed-buffer or page allocator for wasm when possible.

## Importing Host Functions

### WASI Imports

WASI functions are automatically available through `std` when targeting `wasm32-wasi`:

```zig
const std = @import("std");

pub fn main() !void {
    // File I/O (through WASI)
    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    // Environment variables
    var env = try std.process.getEnvMap(std.heap.page_allocator);
    defer env.deinit();

    // Clock
    const timestamp = std.time.timestamp();
    _ = timestamp;
}
```

### Custom Host Imports

Declare external functions the host must provide:

```zig
// Declare imports from the "env" module
extern "env" fn host_log(ptr: [*]const u8, len: usize) void;
extern "env" fn host_random() u32;
extern "env" fn host_get_time() i64;

export fn run() void {
    const msg = "Hello from guest";
    host_log(msg.ptr, msg.len);

    const rand = host_random();
    _ = rand;
}
```

The host must provide matching function definitions when instantiating the module.

## Build Configuration

### Optimization Levels

| Flag | Size | Speed | Debug |
|------|------|-------|-------|
| `Debug` | Large | Slow | Full debug info |
| `ReleaseSafe` | Medium | Fast | Safety checks |
| `ReleaseFast` | Medium | Fastest | No safety checks |
| `ReleaseSmall` | Smallest | Fast | No safety checks |

Use `ReleaseSmall` for production wasm to minimize binary size.

### Stripping

```zig
// In build.zig
lib.root_module.strip = true;  // strip debug info for smaller binary
```

### Stack Size

```zig
// In build.zig
exe.stack_size = 64 * 1024;  // 64KB stack (default is larger)
```

## Common Patterns

### Error Handling Across the Boundary

Zig errors cannot cross the wasm boundary. Convert to numeric codes:

```zig
const ErrorCode = enum(i32) {
    ok = 0,
    invalid_input = -1,
    out_of_memory = -2,
    io_error = -3,
};

export fn process(ptr: [*]const u8, len: usize) i32 {
    return processInner(ptr, len) catch |err| switch (err) {
        error.InvalidInput => @intFromEnum(ErrorCode.invalid_input),
        error.OutOfMemory => @intFromEnum(ErrorCode.out_of_memory),
        else => @intFromEnum(ErrorCode.io_error),
    };
}

fn processInner(ptr: [*]const u8, len: usize) !i32 {
    // actual implementation with proper error handling
    const data = ptr[0..len];
    if (data.len == 0) return error.InvalidInput;
    return @intCast(data.len);
}
```

### Multi-Value Returns

Wasm supports single return values. Return structs through memory:

```zig
const Result = extern struct {
    x: f32,
    y: f32,
    status: i32,
};

var last_result: Result = .{ .x = 0, .y = 0, .status = 0 };

export fn compute() *const Result {
    last_result = .{
        .x = 1.5,
        .y = 2.5,
        .status = 0,
    };
    return &last_result;
}
```

### Limiting Memory Usage

Control the initial and maximum memory:

```zig
// In build.zig
lib.root_module.initial_memory = 65536 * 2;  // 2 pages (128KB)
lib.root_module.max_memory = 65536 * 16;     // 16 pages (1MB)
```

## Testing

### Native Tests

Test logic natively (not as wasm):

```bash
zig build test
```

### Wasm Integration Tests

Build and run with Wasmtime:

```bash
zig build -Doptimize=ReleaseSmall
wasmtime zig-out/bin/my_app.wasm
```

For automated testing, use a host-side test harness (Rust or other) that loads the Zig-compiled wasm and validates exports.

## Binary Size Tips

| Technique | Impact |
|-----------|--------|
| `ReleaseSmall` | Baseline optimization |
| `strip = true` | Remove debug symbols |
| Avoid `std.fmt` | `std.fmt` adds significant code |
| Avoid `std.json` | Large parser, use manual parsing |
| Fixed buffers over heap | Eliminate allocator code |
| `wasm-opt -Oz` | Post-build optimization (10-30%) |

```bash
# Post-process with wasm-opt (from binaryen)
wasm-opt -Oz zig-out/lib/my_lib.wasm -o my_lib.opt.wasm
```
