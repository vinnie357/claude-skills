---
name: troubleshooting
description: Guide for Rust best practices, common patterns, and idiomatic code. Use when following Rust idioms, applying design patterns, or writing idiomatic Rust.
---

# Rust Troubleshooting

Best practices, common patterns, and idiomatic Rust.

## When to Use This Skill

Activate when:
- Following Rust best practices (borrowing, error propagation, iterators)
- Applying design patterns (builder, newtype)
- Choosing between &str and &String
- Writing idiomatic Rust code

For best practices, common patterns, and idiomatic guidelines, see `references/troubleshooting.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Every claim about idiomatic patterns and API
guidelines is verified against the Rust API Guidelines and clippy documentation cited in
`sources.md` — not inferred from generic familiarity with the ecosystem. Before asserting a
clippy lint name or its default-enabled status this skill and its references do not cover,
check the clippy lint index rather than guessing.
