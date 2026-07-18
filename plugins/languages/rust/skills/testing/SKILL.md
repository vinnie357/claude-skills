---
name: testing
description: Guide for Rust testing and Cargo usage. Use when writing unit or integration tests, configuring Cargo.toml, or running cargo commands.
---

# Rust Testing and Cargo

Unit tests, integration tests, Cargo.toml configuration, and common commands.

## When to Use This Skill

Activate when:
- Writing unit tests with #[test] and #[cfg(test)]
- Setting up integration tests in tests/ directory
- Configuring Cargo.toml dependencies and profiles
- Running cargo test, build, clippy, or fmt
- Using #[should_panic] or Result-returning tests

For test patterns, Cargo.toml configuration, and command reference, see `references/testing.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Every claim about `cargo test`/`cargo` command
behavior and Cargo.toml configuration is verified against the Cargo Book cited in
`sources.md` — not inferred from generic familiarity with the tool. Before asserting a
Cargo command or flag this skill and its references do not cover, check `cargo help` or the
installed Cargo version's documentation rather than guessing.
