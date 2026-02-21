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
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try list.append('a');
    try std.testing.expect(list.items.len == 1);
    // test fails automatically if any allocation is not freed
}
```

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

```zig
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
```

## Best Practices

- Use `std.testing.allocator` in every test that allocates memory
- Always `defer` cleanup in tests to prevent leak false positives
- Use descriptive test names that explain expected behavior
- Use doctests (named with identifiers) for API documentation
- Non-named tests always run even with `--test-filter`
- Use `error.SkipZigTest` to skip tests on unsupported platforms
