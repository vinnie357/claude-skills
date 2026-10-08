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
// init is a default-value constant, not a function; backing allocator
// defaults to std.heap.page_allocator (override via the field)
var debug_alloc: std.heap.DebugAllocator(.{}) = .init;
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

## Ownership Transfer and Asynchronous Teardown

When inserting into a container that owns its items, name the current owner and
transfer ownership only after insertion succeeds. Keep the new item's cleanup
guard armed while allocating and initializing it, append it to the destination,
then disarm the guard. The owning container's cleanup must release inserted
items. This prevents both a leak when insertion fails and a double-free after
ownership has moved. A container such as `ArrayList` owns its backing storage,
not automatically any allocations referenced by its elements; the surrounding
type must define and implement that element-ownership contract. Apply the same
commit-point reasoning to other transfers without requiring a particular
container or framework.

Cancellation is a request, not proof that asynchronous work has completed or
that its resources may be destroyed. A worker may still borrow memory, a
mailbox, a timer, or other state after cancellation is requested. Observe its
terminal completion and join or otherwise establish that it has stopped before
freeing borrowed resources. Choose the synchronization mechanism that fits the
program rather than turning this into a universal threading architecture.

This guidance draws on Ghostty's renderer-thread lifecycle: its paired loop,
async work, timer, and mailbox setup is in
[`src/renderer/Thread.zig` lines 120–154](https://github.com/ghostty-org/ghostty/blob/44f2a44df7e8c4a0c6df3f7d872ef3d7ead88e51/src/renderer/Thread.zig#L120-L154),
and its join-before-deinit ordering is in
[lines 181–195](https://github.com/ghostty-org/ghostty/blob/44f2a44df7e8c4a0c6df3f7d872ef3d7ead88e51/src/renderer/Thread.zig#L181-L195).
When describing the conceptual influence, use wording such as “Inspired by
Ghostty, `src/renderer/Thread.zig` at commit `44f2a44`; independently
implemented.” If code is copied or substantially adapted instead, retain the
full applicable copyright and MIT permission notice from Ghostty's
[`LICENSE`](https://github.com/ghostty-org/ghostty/blob/44f2a44df7e8c4a0c6df3f7d872ef3d7ead88e51/LICENSE)
(Copyright (c) 2024 Mitchell Hashimoto, Ghostty contributors).

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
