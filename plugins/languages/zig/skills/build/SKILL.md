---
name: build
description: Guide for the Zig build system and CI integration. Use when configuring build.zig, adding build steps, cross-compiling, managing dependencies, or setting up CI pipelines.
---

# Zig Build System

Build configuration, cross-compilation, dependency management, and CI patterns.

## When to Use This Skill

Activate when:
- Creating or editing build.zig files
- Adding build steps, options, or dependencies
- Cross-compiling for different targets
- Setting up CI pipelines for Zig projects
- Managing build.zig.zon dependencies

For detailed build.zig patterns, API methods, and examples, see `references/build.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Verified against zig 0.16.0 (locally
installed, claude-skills-204): `references/build.md`'s `build.zig` + `build.zig.zon`
sample builds, tests, and runs end to end, and the documented flags (`--watch`,
`-fincremental`, `--time-report`, `-Doptimize`, `-Dtarget`) are all present in
`zig build --help` — no corrections needed. Re-verify against a locally installed
`zig build --help` and a real build before asserting a flag or API this skill doesn't
cover — Zig is pre-1.0 and the build system has broken across minor releases before
(0.15's Writergate, 0.16's `root_source_file`/`.fingerprint` changes this file already
documents).
