---
name: testing
description: Guide for Zig built-in testing framework. Use when writing tests, using test allocator for leak detection, filtering tests, setting up build.zig test steps, or integrating tests into CI.
---

# Zig Testing

Built-in test framework, leak detection, and CI integration.

For assertion functions, test allocator patterns, and build integration, see `references/testing.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Verified against zig 0.16.0 (locally
installed, claude-skills-204): `references/testing.md`'s snippets compile and pass as
`zig test` — no corrections needed. Re-verify against a locally installed `zig test`
before asserting a testing-framework API this skill doesn't cover — Zig is pre-1.0 and
`std` breaks across minor releases.
