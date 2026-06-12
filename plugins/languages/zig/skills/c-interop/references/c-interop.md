# Zig C Interop Reference

## Importing C Headers

### 0.16+: translate-c via the build system

`@cImport` is deprecated in 0.16. Put the includes in a C header and translate it in `build.zig`:

```c
// src/c.h
#include <stdio.h>
#include <stdlib.h>
```

```zig
// build.zig
const translate_c = b.addTranslateC(.{
    .root_source_file = b.path("src/c.h"),
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("c", translate_c.createModule());
```

```zig
// in source
const c = @import("c");
const result = c.printf("Hello from C\n");
```

### 0.15 and earlier: @cImport

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
- On 0.16+, use `b.addTranslateC()` + `@import("c")` (`@cImport` is deprecated); on 0.15 and earlier prefer `@cImport` for simple headers, `translate-c` for complex ones
- Use `[*c]T` C pointers only at the boundary; convert to Zig pointers internally
- Be careful with C pointer nullability (`[*c]T` can be null, `*T` cannot)
