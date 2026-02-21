---
name: rust
description: Guide for Rust programming language. Use when writing Rust code, setting up Rust projects, or needing an overview of Rust development workflows.
---

# Rust Programming Language

Entry point for Rust development. Provides an overview and routes to focused skills.

## When to Use This Skill

Activate when:
- Starting a new Rust project
- Needing a general overview of Rust capabilities
- Unsure which specific Rust skill to load

## Available Skills

This plugin provides focused skills for specific Rust topics:

- **rust:ownership** - Ownership rules, borrowing, slices, lifetimes
- **rust:error-handling** - Result, Option, ? operator, custom error types
- **rust:async** - Async functions, tokio, streams, threads, channels, shared state
- **rust:testing** - Unit tests, integration tests, cargo test, Cargo.toml, commands
- **rust:troubleshooting** - Best practices, common patterns, idiomatic Rust

For core language features (traits, generics, collections, pattern matching), see `references/language.md`.

## Quick Start

```bash
# Install via mise
mise use rust@latest

# Create a new project
cargo new myproject
cd myproject

# Build and run
cargo run
```

See `templates/mise.toml` for project task definitions.

## Key Principles

- **Ownership ensures memory safety**: no garbage collector needed
- **Borrow checker prevents data races**: compile-time safety
- **Zero-cost abstractions**: high-level code compiles to efficient machine code
- **Explicit over implicit**: be clear about ownership, mutability, errors
- **Prefer immutability**: use `mut` only when needed
- **Use the type system**: let the compiler catch errors
- **Test thoroughly**: tests are first-class in Rust
- **Use clippy**: catch common mistakes and non-idiomatic code
