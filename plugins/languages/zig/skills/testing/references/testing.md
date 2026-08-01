# Zig Testing Reference

## Test Declaration

```zig
const std = @import("std");

test "descriptive test name" {
    try std.testing.expect(addOne(41) == 42);
}

test addOne { // doctest - appears in generated docs
    try std.testing.expect(addOne(41) == 42);
}
```

## Assertion Functions

```zig
try std.testing.expect(condition);                      // boolean
try std.testing.expectEqual(expected, actual);           // equality
try std.testing.expectError(expected_err, result);       // error check
try std.testing.expectEqualStrings(expected, actual);    // strings
try std.testing.expectEqualSlices(T, expected, actual);  // slices
try std.testing.expectApproxEqAbs(expected, actual, tolerance); // float
```

## Test Allocator (Leak Detection)

```zig
test "no memory leaks" {
    const allocator = std.testing.allocator;
    // 0.15+: std.ArrayList is unmanaged — pass the allocator per call
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);
    try list.append(allocator, 'a');
    try std.testing.expect(list.items.len == 1);
    // test fails automatically if any allocation is not freed
}
```

On Zig 0.14.x the managed form applies instead: `var list = std.ArrayList(u8).init(allocator); defer list.deinit(); try list.append('a');`

## Running Tests

```bash
zig test file.zig                       # run tests in file
zig test file.zig --test-filter "name"  # filter by name
zig build test                          # run via build system
```

## Skipping Tests

```zig
const builtin = @import("builtin");

test "platform-specific" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;
    // test body runs only on non-Windows
}
```

## Detecting Test Builds

```zig
const builtin = @import("builtin");
if (builtin.is_test) {
    // test-only code path
}
```

## Build Integration

Wire the test step into `build.zig` alongside the executable step — see `/zig:build` `references/build.md` "build.zig Structure" for the full `build.zig` this is lifted from (including the 0.15+ `root_module` requirement). The essential piece: `b.addTest(...)` creates the test compilation from the same module shape as the executable, `b.addRunArtifact()` wraps it in a runnable step, and `b.step("test", ...).dependOn(&run_tests.step)` exposes it as `zig build test`.

## Best Practices

- Use `std.testing.allocator` in every test that allocates memory
- On 0.16+, use `std.testing.io` for tests that perform I/O (analogous to `std.testing.allocator`)
- Always `defer` cleanup in tests to prevent leak false positives
- Use descriptive test names that explain expected behavior
- Use doctests (named with identifiers) for API documentation
- Non-named tests always run even with `--test-filter`
- Use `error.SkipZigTest` to skip tests on unsupported platforms
