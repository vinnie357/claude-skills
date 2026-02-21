---
name: zig
description: Guide for Zig programming language. Use when writing Zig code, setting up Zig projects, or needing an overview of Zig development workflows.
---

# Zig Programming Language

Entry point for Zig development. Provides an overview and routes to focused skills.

## When to Use This Skill

Activate when:
- Starting a new Zig project
- Needing a general overview of Zig capabilities
- Unsure which specific Zig skill to load

## Available Skills

This plugin provides focused skills for specific Zig topics:

- **zig:language** - Core language: comptime, error handling, data types, slices, defer
- **zig:build** - Build system: build.zig, cross-compilation, dependencies, CI
- **zig:allocators** - Memory management: allocator types, patterns, leak detection
- **zig:testing** - Built-in test framework, test allocator, build integration
- **zig:c-interop** - C interoperability: @cImport, type mappings, translate-c, linking
- **zig:troubleshooting** - Common errors, debugging, runtime panics, memory issues

## Quick Start

```bash
# Install via mise
mise use zig@0.14

# Create a new project
mkdir myproject && cd myproject
zig init
```

See `templates/mise.toml` for project task definitions.

## Key Principles

- **No hidden control flow**: if code does not look like it calls a function, it does not
- **No hidden memory allocations**: allocators are explicit parameters
- **No preprocessor, no macros**: comptime replaces both
- **Explicit over implicit**: be clear about allocations, errors, ownership
- **Performance and safety**: both achievable without compromise
- **C ecosystem integration**: use existing C libraries without depending on libc
- **Cross-compilation first-class**: target any platform from any platform
