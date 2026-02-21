# Zig Language Reference

## Comptime

### Compile-Time Execution

```zig
comptime var x: i32 = 1;

comptime {
    // Executed at compile time
}

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
            return .{ .items = &.{}, .capacity = 0, .allocator = allocator };
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
const FileOpenError = error{ AccessDenied, OutOfMemory, FileNotFound };
```

### Error Unions

```zig
fn openFile(path: []const u8) FileOpenError!File { ... }

// Inferred error set
fn process() !void { ... }
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

## Data Types

### Structs

```zig
const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32 = 0,
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

const Status = enum(u8) { pending = 0, active = 1, complete = 2 };

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

const unwrapped = maybe orelse 0;
const forced = value.?;             // panic if null
if (maybe) |v| { /* v is unwrapped */ }
```

## Slices, Arrays, and Pointers

### Arrays (Fixed-Size)

```zig
const array: [5]u8 = [_]u8{ 1, 2, 3, 4, 5 };
const zeros: [10]u32 = [_]u32{0} ** 10;
const combined = array1 ++ array2;          // comptime only
```

### Slices (Fat Pointers)

```zig
var array = [_]u8{ 1, 2, 3, 4, 5 };
const slice: []u8 = array[1..4];    // indices 1,2,3
const open: []u8 = array[2..];      // index 2 to end
// slice.ptr, slice.len
```

### Sentinel-Terminated Types

```zig
const c_string: [:0]const u8 = "hello";
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

Zig strings are `[]const u8`. String literals are `*const [N:0]u8` which coerce to `[]const u8`.

```zig
const hello: []const u8 = "hello";
const multiline =
    \\line one
    \\line two
;
std.mem.eql(u8, string1, string2);
std.debug.print("Hello, {s}!\n", .{"World"});
```

## Resource Cleanup

### defer - Always Executes

```zig
const file = try std.fs.cwd().openFile("data.txt", .{});
defer file.close();
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

Multiple `defer` statements execute in LIFO (reverse) order.

## Naming Conventions

- `snake_case` for variables and functions
- `PascalCase` for types and type-returning functions
- `SCREAMING_SNAKE_CASE` for compile-time constants from `@import`
- Doc comments (`///`) for public API documentation
- Top-level comments (`//!`) for module-level documentation
