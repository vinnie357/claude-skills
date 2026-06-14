# Zig Plugin Sources

This file documents the sources used to create the zig plugin skills.

## Update History

### 2026-06-14 — 0.15→0.16 migration reference

- **Added**: `skills/zig/references/migration-0.16.md` — field-observed 0.15→0.16 breakages with BEFORE/AFTER snippets for 7 areas: sync primitives, Reader API, ArrayList, ordered maps, C interop, process API, macOS 26 build gotcha.
- **Verified against**: `~/.local/share/mise/installs/zig/0.16.0/lib/std/` — `Io.zig`, `Io/Reader.zig`, `Io/RwLock.zig`, `array_list.zig`, `array_hash_map.zig`, `process.zig`, `c.zig`, `Build/Module.zig`. Access date: 2026-06-14.
- **Linked from**: `skills/zig/SKILL.md` version table section (one level deep).

### 2026-06-12 — Zig 0.16.0

- **Release Notes**: https://ziglang.org/download/0.16.0/release-notes.html and https://ziglang.org/download/0.15.1/release-notes.html
- **Summary**: Updated plugin from 0.14 to 0.16.0 (current stable, released 2026-04-13). Added versioned templates (`templates/0.14.1/`, `templates/0.15.2/`, `templates/0.16.0/`) and `references/version-history.md` to the zig skill. 0.16 changes documented: std.Io async architecture (io parameter, Future, Io.Threaded), `@cImport` deprecated for `b.addTranslateC()`, `@Type` replaced by dedicated builtins, "juicy main", sync primitives under `std.Io.*`. 0.15 changes documented: std.Io Reader/Writer redesign ("Writergate"), unmanaged `std.ArrayList` default, `usingnamespace`/`async` removal, top-level `root_source_file` removed from build options, `addLibrary` replacing `addStaticLibrary`/`addSharedLibrary`, `{f}` format specifier.
- **Verified against source**: `lib/std/Build.zig` and `lib/std/heap/debug_allocator.zig` at tag 0.15.1 (DebugAllocator `.init` constant, `root_module`-only options structs).
- **0.14.0 Release Notes**: https://ziglang.org/download/0.14.0/release-notes.html (build.zig.zon `fingerprint` field, enum-literal `name`, new hash format)
- **Bootstrap**: Added `sources.toml` for staleness tracking. `check_method` is `manual`: ziglang stopped tagging GitHub releases after 0.15.2, so the GitHub releases API under-reports (it returned 0.15.1 as latest on 2026-06-12 while 0.16.0 was current). Authoritative list: https://ziglang.org/download/index.json.

## Zig Skill

### Zig Language Reference
- **URL**: https://ziglang.org/documentation/master/
- **Purpose**: Official language reference documentation
- **Date Accessed**: 2026-02-21
- **Key Topics**: Comptime, allocators, error handling, slices, optionals, packed structs, pointers, arrays, C interop, strings, enums, unions, testing

### Zig Language Overview
- **URL**: https://ziglang.org/learn/overview/
- **Purpose**: Language philosophy and design goals
- **Date Accessed**: 2026-02-21
- **Key Topics**: Design principles, no hidden control flow, no hidden allocations, C ecosystem integration, cross-compilation

### Zig Guide
- **URL**: https://zig.guide/
- **Purpose**: Practical patterns and examples for learning Zig
- **Date Accessed**: 2026-02-21
- **Key Topics**: Language basics, allocators, error handling, comptime, structs, defer

### Zig Build System
- **URL**: https://ziglang.org/learn/build-system/
- **Purpose**: Build system reference and patterns
- **Date Accessed**: 2026-02-21
- **Key Topics**: build.zig structure, build steps, dependencies, cross-compilation, linking, package management

### Zig Testing Reference
- **URL**: https://ziglang.org/documentation/master/#Zig-Test
- **Purpose**: Built-in test framework documentation
- **Date Accessed**: 2026-02-21
- **Key Topics**: Test syntax, test allocator, expect functions, build integration, filtering, doctests

## Plugin Information

- **Name**: zig
- **Version**: 0.1.0
- **Description**: Zig programming skills: build system, comptime, allocators, error handling, C interop, and best practices
- **Skills**: 1 comprehensive Zig skill
- **Created**: 2026-02-21
