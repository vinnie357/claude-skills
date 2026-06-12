---
name: zig
description: Guide for Zig programming language. Use when writing Zig code, setting up Zig projects, migrating between Zig versions, or needing an overview of Zig development workflows.
---

# Zig Programming Language

Entry point for Zig development. Provides an overview, version awareness, and routes to focused skills.

## When to Use This Skill

Activate when:
- Starting a new Zig project
- Needing a general overview of Zig capabilities
- Migrating a project between Zig versions
- Unsure which specific Zig skill to load

## Available Skills

This plugin provides focused skills for specific Zig topics:

- **zig:language** - Core language: comptime, error handling, data types, slices, defer
- **zig:build** - Build system: build.zig, cross-compilation, dependencies, CI
- **zig:allocators** - Memory management: allocator types, patterns, leak detection
- **zig:testing** - Built-in test framework, test allocator, build integration
- **zig:c-interop** - C interoperability: @cImport, type mappings, translate-c, linking
- **zig:troubleshooting** - Common errors, debugging, runtime panics, memory issues

## Version Awareness

Zig is pre-1.0: every minor release carries breaking changes. Run `zig version`
first and match guidance to the installed toolchain. This plugin documents
**0.16.0** (current stable, released 2026-04-13); 0.15.x and 0.14.x notes are
retained for migration. Check https://ziglang.org/download/index.json for the
release list — GitHub tags lag behind (they stop at 0.15.2).

| Version | Template | Highlights |
|---|---|---|
| 0.16.0 | `templates/0.16.0/mise.toml` | `std.Io` async architecture (all blocking ops take `io`, `io.async`/`Future`, `Io.Threaded`), `@cImport` deprecated for `b.addTranslateC()`, `@Type` replaced by dedicated builtins, "juicy main" `main(init: std.process.Init)`, sync primitives moved to `std.Io.*` |
| 0.15.2 | `templates/0.15.2/mise.toml` | `std.Io` Reader/Writer redesign ("Writergate"), unmanaged `std.ArrayList` default, `usingnamespace` and `async`/`await` removed, top-level `root_source_file` removed from build options, `{f}` format specifier, self-hosted x86_64 Debug backend |
| 0.14.1 | `templates/0.14.1/mise.toml` | Managed `std.ArrayList`, `root_module` introduced (old fields deprecated), `build.zig.zon` `fingerprint` + enum-literal `name` |

The full breaking-change tables and 0.14 → 0.15 migration checklist live in
`references/version-history.md`.

## Quick Start

```bash
# Install via mise (pin the exact version)
mise use zig@0.16.0

# Create a new project
mkdir myproject && cd myproject
zig init        # add --minimal for just a build.zig.zon stub (0.15+)
```

Copy `templates/0.16.0/mise.toml` into the project for build/test/fmt/watch
tasks. Projects pinned to older toolchains use `templates/0.15.2/mise.toml` or
`templates/0.14.1/mise.toml`.

## Key Principles

- **No hidden control flow**: if code does not look like it calls a function, it does not
- **No hidden memory allocations**: allocators are explicit parameters
- **No preprocessor, no macros**: comptime replaces both
- **Explicit over implicit**: be clear about allocations, errors, ownership
- **Performance and safety**: both achievable without compromise
- **C ecosystem integration**: use existing C libraries without depending on libc
- **Cross-compilation first-class**: target any platform from any platform
