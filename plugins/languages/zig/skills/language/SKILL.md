---
name: zig-language
description: Guide for Zig core language features. Use when writing Zig code with comptime, error handling, data types, slices, optionals, defer, or following Zig idioms.
---

# Zig Language

Core language features, data types, and idioms for writing Zig code.

## When to Use This Skill

Activate when:
- Writing Zig code with structs, enums, unions, optionals
- Using comptime for compile-time execution and generics
- Handling errors with error unions, try, catch, errdefer
- Working with slices, arrays, pointers, and strings
- Using defer/errdefer for resource cleanup

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
