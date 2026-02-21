# Zig Allocators Reference

## Allocator Types

| Allocator | Use Case | Notes |
|-----------|----------|-------|
| `std.heap.page_allocator` | System page allocation | Slow, wasteful for small items |
| `std.heap.FixedBufferAllocator` | Pre-allocated fixed buffer | No heap; returns `OutOfMemory` when full |
| `std.heap.ArenaAllocator` | Batch deallocation | Wraps child allocator; frees all at once |
| `std.heap.DebugAllocator` | Safety-focused development | Detects double-free, use-after-free, leaks |
| `std.heap.SmpAllocator` | High-performance general purpose | Multithreaded, minimal safety checks |
| `std.heap.c_allocator` | C malloc/free wrapper | Requires `-lc` |
| `std.testing.allocator` | Testing only | Detects leaks, reports in test output |

## Allocation Patterns

### Allocate and Free with defer

```zig
const allocator = std.heap.page_allocator;
const memory = try allocator.alloc(u8, 100);
defer allocator.free(memory);
```

### Single Item Allocation

```zig
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

### Fixed Buffer Allocator (No Heap)

```zig
var buf: [1024]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);
const alloc = fba.allocator();
```

### Debug Allocator

```zig
var debug_alloc = std.heap.DebugAllocator(.{}).init(std.heap.page_allocator);
defer {
    const check = debug_alloc.deinit();
    if (check == .leak) @panic("memory leak detected");
}
const alloc = debug_alloc.allocator();
```

## Allocator Interface

All allocators implement `std.mem.Allocator`:

```zig
fn doWork(allocator: std.mem.Allocator) !void {
    const data = try allocator.alloc(u8, 256);
    defer allocator.free(data);
}
```

### Key Methods

- `alloc(T, n)` - allocate n items of type T
- `free(slice)` - free previously allocated slice
- `create(T)` - allocate a single item of type T
- `destroy(ptr)` - free a single item
- `realloc(slice, new_len)` - resize allocation
- `dupe(T, slice)` - duplicate a slice

## errdefer for Error-Safe Cleanup

```zig
fn allocateResource(allocator: Allocator) !Resource {
    var resource = try allocator.create(Resource);
    errdefer allocator.destroy(resource);
    resource.data = try allocator.alloc(u8, 1024);
    errdefer allocator.free(resource.data);
    return resource;
}
```

## Choosing an Allocator

- **Performance-critical, short-lived**: `ArenaAllocator`
- **Embedded/no-heap**: `FixedBufferAllocator`
- **General purpose**: `SmpAllocator` (production) or `page_allocator` (simple)
- **Development/debugging**: `DebugAllocator`
- **C interop**: `c_allocator`
- **Tests**: `std.testing.allocator`

## Key Principles

- No hidden memory allocations in the language or standard library
- Allocators are passed as explicit parameters to functions
- Always pair allocations with `defer` cleanup
- Use `errdefer` for cleanup on error paths
- Libraries accept allocator parameters for portability
