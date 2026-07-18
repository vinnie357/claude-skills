---
name: anti-patterns
description: Identify and refactor Rust anti-patterns and clippy anti-idioms. Use when reviewing Rust code for smells, hunting anti-patterns to fix or remove, or refactoring code that clones to satisfy the borrow checker, takes &String/&Vec parameters, unwraps on fallible paths, or returns sentinel values instead of Option/Result.
license: MIT
---

# Rust Anti-Patterns

Catalog of Rust anti-patterns and clippy anti-idioms for reviewers and implementers actively hunting code to fix or remove. Complements `/rust:troubleshooting` (which teaches the idiomatic GOOD patterns) by naming the BAD patterns explicitly, with detection hints.

## When to Use This Skill

Activate when:
- Reviewing a Rust diff or module for anti-patterns
- Refactoring code flagged by clippy or code review
- Deciding whether a `.clone()`, `&Vec<T>` parameter, `unwrap()`, or sentinel return value is a bug to fix

## Sources

Rust Design Patterns book ([anti-patterns](https://rust-unofficial.github.io/patterns/anti_patterns/), [idioms](https://rust-unofficial.github.io/patterns/idioms/)) and the [Clippy lint index](https://rust-lang.github.io/rust-clippy/master/index.html) — full attribution per entry in `references/anti-patterns.md`, dated URLs in `sources.md`.

## Example

```rust
// BAD: clippy::ptr_arg — forces callers to hold an owned Vec
fn process(data: &Vec<i32>) { /* ... */ }

// GOOD: accepts a Vec, an array, or a slice via deref coercion
fn process(data: &[i32]) { /* ... */ }
```

The full catalog (9 entries) is in `references/anti-patterns.md`.

## Usage Guidelines

1. **Scan for the pattern** — check the diff or module against `references/anti-patterns.md`
2. **Confirm it's not deliberate** — a `restraint:` comment or documented tradeoff can justify what looks like an anti-pattern; anti-patterns are defaults to avoid, not absolute bans
3. **Fix at the root** — apply the GOOD replacement, don't just silence the lint
4. **Cite the source** — when flagging in review, reference the anti-pattern name so the author can look it up

## Anti-Fabrication

Every entry in `references/anti-patterns.md` cites its source URL. Do not assert a clippy lint name, its default-enabled status, or a "this catches N% of cases" claim without verifying against the linked clippy documentation — see `/core:anti-fabrication`.
