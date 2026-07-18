---
name: error-handling
description: Guide for Rust error handling. Use when working with Result, Option, the ? operator, implementing custom error types, or composing errors with thiserror and anyhow.
---

# Rust Error Handling

Result, Option, error propagation, and custom error types.

## When to Use This Skill

Activate when:
- Returning and handling Result types
- Working with Option for optional values
- Using the ? operator for error propagation
- Implementing custom error types with Display and From
- Composing error enums with thiserror or adding caller context with anyhow

For Result, Option, ? operator, custom error type patterns, and the thiserror/anyhow ecosystem crates, see `references/error-handling.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Every claim about `Result`/`Option` behavior,
the `?` operator, and the `thiserror`/`anyhow` crate APIs is verified against the official
documentation and crates.io versions cited in `sources.md` — not inferred from generic
familiarity with the ecosystem. Before asserting an error-handling pattern or crate API this
skill and its references do not cover, check the installed crate version's docs.rs page
rather than guessing.
