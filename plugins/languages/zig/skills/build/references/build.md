# Zig Build System Reference

## build.zig Structure

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

## Build Modes

| Mode | Safety Checks | Optimizations | Use Case |
|------|---------------|---------------|----------|
| `Debug` | Yes | None | Development |
| `ReleaseSafe` | Yes | Yes | Production with safety |
| `ReleaseFast` | No | Maximum | Performance-critical |
| `ReleaseSmall` | No | Size-focused | Embedded/WASM |

## Build Commands

```bash
zig build                          # Default build
zig build run                      # Build and run
zig build test                     # Run tests
zig build -Doptimize=ReleaseSafe   # Build with safety + optimizations
zig build -Dtarget=x86_64-linux-gnu  # Cross-compile
```

## Build API Methods

- `b.addExecutable()` - create executable binaries
- `b.addStaticLibrary()` / `b.addSharedLibrary()` - create libraries
- `b.addTest()` - create test suites
- `b.addRunArtifact()` - execute compiled artifacts
- `b.installArtifact()` - copy outputs to install prefix
- `b.step()` - create custom named build steps
- `b.option()` - declare project-specific build options
- `b.addOptions()` - pass compile-time values to source

## Linking C Libraries

```zig
exe.linkSystemLibrary("z");
exe.linkLibC();
exe.addIncludePath(b.path("include"));
exe.addCSourceFile(.{
    .file = b.path("src/legacy.c"),
    .flags = &.{"-std=c99"},
});
```

## Build Options

```zig
const version = b.option([]const u8, "version", "App version") orelse "dev";
const options = b.addOptions();
options.addOption([]const u8, "version", version);
exe.root_module.addOptions("config", options);
// In source: const config = @import("config");
```

## Dependencies (build.zig.zon)

```zig
.{
    .name = "myproject",
    .version = "0.1.0",
    .dependencies = .{
        .@"dep-name" = .{
            .url = "https://github.com/owner/repo/archive/refs/tags/v1.0.0.tar.gz",
            .hash = "...",
        },
    },
}
```

```bash
zig fetch --save https://github.com/owner/repo/archive/refs/tags/v1.0.0.tar.gz
```

## Cross-Compilation

```zig
.target = b.resolveTargetQuery(.{
    .cpu_arch = .x86_64,
    .os_tag = .windows,
}),
```

```bash
zig build -Dtarget=x86_64-linux-gnu
zig build -Dtarget=aarch64-linux-gnu
zig build -Dtarget=x86_64-windows
zig build -Dtarget=wasm32-wasi
```

## Directory Structure

- `.zig-cache/` - compilation cache (exclude from VCS)
- `zig-out/` - installation prefix (binaries, libs, headers)
- `build.zig` - build configuration
- `build.zig.zon` - dependency manifest

## CI Pipeline

```bash
zig fmt --check src/ && zig build test && zig build -Doptimize=ReleaseSafe
```

## Best Practices

- Always use `standardTargetOptions()` and `standardOptimizeOption()`
- Use build steps for complex workflows (eliminates make/cmake)
- Generate source at build time rather than committing generated files
- Add `.zig-cache/` and `zig-out/` to `.gitignore`
