# Zig C Interop Reference

## Importing C Headers

```zig
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cDefine("_GNU_SOURCE", {});
});

const result = c.printf("Hello from C\n");
```

## Exporting Zig to C

```zig
pub export fn zig_function(param: c_int) c_int {
    return param + 1;
}
```

## C Type Mappings

| Zig Type | C Equivalent |
|----------|-------------|
| `c_char` | `char` |
| `c_short` | `short` |
| `c_int` | `int` |
| `c_long` | `long` |
| `c_longlong` | `long long` |
| `c_uint` | `unsigned int` |
| `c_ulong` | `unsigned long` |
| `c_longdouble` | `long double` |
| `[*c]T` | `T*` (C pointer) |
| `[:0]const u8` | `const char*` (null-terminated) |

## translate-c Tool

```bash
zig translate-c -target x86_64-linux-gnu header.h > zig_header.zig
```

## Linking in build.zig

```zig
exe.linkSystemLibrary("z");
exe.linkLibC();
exe.addIncludePath(b.path("include"));
exe.addCSourceFile(.{
    .file = b.path("src/legacy.c"),
    .flags = &.{"-std=c99"},
});
```

## String Interop

```zig
// Zig string to C: string literals are already sentinel-terminated
const c_str: [*:0]const u8 = "hello";

// C string to Zig slice
const c_ptr: [*:0]const u8 = c.some_c_function();
const zig_slice = std.mem.span(c_ptr); // []const u8
```

## Best Practices

- Keep C boundaries thin; wrap C APIs in Zig abstractions
- Use `[:0]const u8` for C string interop
- Prefer `@cImport` for simple headers; `translate-c` for complex ones
- Use `[*c]T` C pointers only at the boundary; convert to Zig pointers internally
- Be careful with C pointer nullability (`[*c]T` can be null, `*T` cannot)
