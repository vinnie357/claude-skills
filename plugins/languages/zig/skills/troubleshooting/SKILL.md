---
name: troubleshooting
description: Guide for debugging and troubleshooting Zig programs. Use when diagnosing compiler errors, runtime panics, memory issues, build failures, or common Zig pitfalls.
---

# Zig Troubleshooting

Common errors, debugging techniques, and solutions for Zig development issues.

For error catalogs, debugging patterns, and common pitfalls, see `references/troubleshooting.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. This file carried three of the six
corrections found across the plugin (claude-skills-204, verified against zig 0.16.0
locally installed by compiling the documented snippets): `references/
troubleshooting.md` called `std.heap.DebugAllocator(.{}).init(...)` a function call —
at 0.16.0 `init` is a constant, not callable, so the snippet did not compile; it listed
`@cImport` deprecation warnings as an observed error, but `@cImport` compiles silently
at 0.16.0 (the deprecation is release-notes-only); and it read `std.process.Child` as
removed in favor of `std.process.spawn`, when `Child` still exists as the handle type
`spawn` returns — only `Child.run`/`Child.init` moved to free functions. All three
reworded. Re-verify against a locally installed `zig build-exe` reproducing the actual
error before asserting a diagnostic this skill doesn't cover.
