---
name: allocators
description: Guide for Zig memory management and allocators. Use when choosing allocators, managing memory lifecycle, debugging leaks, or understanding arena vs page vs fixed-buffer allocation patterns.
---

# Zig Allocators

Memory management patterns, allocator types, and allocation lifecycle.

## When to Use This Skill

Activate when:
- Choosing an allocator for a specific use case
- Managing memory allocation and deallocation
- Debugging memory leaks or use-after-free
- Writing allocator-aware library code

For allocator types, patterns, and examples, see `references/allocators.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Verified against zig 0.16.0 (locally
installed, claude-skills-204): `references/allocators.md`'s `DebugAllocator` snippets
compile and pass as `zig test` — this file already had the correct `init` form
(`pub const init: Self = .{};`, a value, not a function call); a contradicting
function-call form was found and fixed in the troubleshooting skill instead, not here.
Re-verify against a locally installed `zig test` before asserting an allocator API this
skill doesn't cover — `std.heap`'s allocator-init pattern changed between 0.15 and 0.16.
