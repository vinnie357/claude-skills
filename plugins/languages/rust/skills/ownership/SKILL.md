---
name: ownership
description: Guide for Rust ownership, borrowing, and lifetimes. Use when working with ownership rules, move semantics, borrowing, slices, or lifetime annotations.
---

# Rust Ownership and Borrowing

Ownership rules, borrowing, slices, and lifetimes.

## When to Use This Skill

Activate when:
- Understanding ownership and move semantics
- Working with references and borrowing rules
- Using string or array slices
- Annotating or debugging lifetimes
- Fixing borrow checker errors

For ownership rules, borrowing patterns, slices, and lifetime annotations, see `references/ownership.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Every claim about ownership, borrowing, and
lifetime rules is verified against the official Rust Book chapters cited in `sources.md` —
not inferred from generic familiarity with the language. Before asserting borrow-checker
behavior this skill and its references do not cover, check the installed Rust toolchain's
documentation rather than guessing.
