---
name: language
description: Guide for Zig core language features. Use when writing Zig code with comptime, error handling, data types, slices, optionals, defer, or following Zig idioms.
---

# Zig Language

Core language features, data types, and idioms for writing Zig code.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Verified against zig 0.16.0 (locally
installed, claude-skills-204) by compiling the documented snippets:
`references/language.md`'s `defer` example opened a file with `std.fs.cwd()`, which does
not exist at 0.16.0 — rewritten against `std.Io.Dir.cwd().openFile(io, ...)` /
`file.close(io)`, with the pre-0.16 form kept as a note for readers on older
toolchains. Re-verify against a locally installed `zig version` before asserting a
`std` API this skill doesn't cover — Zig is pre-1.0 and `std` breaks across minor
releases.

## Key Topics

For detailed syntax, patterns, and examples, see `references/language.md`.

Topics covered:
- Comptime: compile-time execution, generics via comptime parameters, key builtins
- Error handling: error sets, error unions, try/catch, errdefer, merging error sets
- Data types: structs, packed structs, enums, tagged unions, optionals
- Slices, arrays, pointers, and sentinel-terminated types
- Strings as `[]const u8` byte slices
- Resource cleanup with defer/errdefer (LIFO execution order)
- Naming conventions and formatting style
