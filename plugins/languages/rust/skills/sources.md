# Rust Plugin Sources

This file documents the sources used to create the rust plugin skills.

## Rust Skill

### Official Rust Documentation
- **URL**: https://doc.rust-lang.org/stable/
- **Purpose**: Official Rust language documentation
- **Date Accessed**: 2025-11-15
- **Key Topics**: Rust language features, standard library, best practices, patterns

### The Rust Programming Language Book
- **URL**: https://doc.rust-lang.org/book/
- **Purpose**: Comprehensive guide to learning Rust
- **Key Topics**:
  - Ownership and borrowing
  - Lifetimes
  - Error handling with Result and Option
  - Traits and generics
  - Smart pointers
  - Concurrency
  - Async programming

### Rust by Example
- **URL**: https://doc.rust-lang.org/rust-by-example/
- **Purpose**: Learning Rust through practical examples
- **Key Topics**: Pattern matching, modules, crates, error handling, testing

### Rust Standard Library Documentation
- **URL**: https://doc.rust-lang.org/std/
- **Purpose**: Standard library API reference
- **Key Topics**:
  - Collections (Vec, HashMap, etc.)
  - Iterators and functional programming
  - I/O operations
  - File system operations
  - Threading and synchronization

### Async Rust Book
- **URL**: https://rust-lang.github.io/async-book/
- **Purpose**: Asynchronous programming in Rust
- **Key Topics**:
  - async/await syntax
  - Futures and executors
  - Tokio runtime
  - Async streams
  - Pinning

### Rust API Guidelines
- **URL**: https://rust-lang.github.io/api-guidelines/
- **Purpose**: Best practices for designing Rust APIs
- **Key Topics**:
  - Naming conventions
  - Type safety
  - Error handling patterns
  - Documentation standards

### Cargo Book
- **URL**: https://doc.rust-lang.org/cargo/
- **Purpose**: Rust's package manager and build system
- **Key Topics**:
  - Project structure
  - Dependencies management
  - Build configuration
  - Testing and benchmarking
  - Publishing crates

### Rust Stable Releases
- **URL**: https://github.com/rust-lang/rust/releases
- **Purpose**: Rust compiler release tracking
- **Date Accessed**: 2026-07-17
- **Key Topics**: Version 1.97.1 (current stable), edition 2024, release notes

### Tokio Runtime
- **URL**: https://crates.io/crates/tokio
- **Purpose**: Async runtime version tracking
- **Date Accessed**: 2026-07-17
- **Key Topics**: Version 1.53.0 (current), async/await, task spawning

### Serde Serialization
- **URL**: https://crates.io/crates/serde
- **Purpose**: Serialization framework version tracking
- **Date Accessed**: 2026-07-17
- **Key Topics**: Version 1.0.228 (current), derive macros, data formats

## Anti-Patterns Skill

### Rust Design Patterns Book — Anti-Patterns
- **URL**: https://rust-unofficial.github.io/patterns/anti_patterns/
- **Purpose**: Catalog of the 3 documented Rust anti-patterns (clone-to-satisfy-borrow-checker, `#![deny(warnings)]`, Deref polymorphism)
- **Date Accessed**: 2026-07-17
- **Key Topics**: Borrow checker workarounds, lint-denial forward compatibility, Deref misuse for inheritance simulation

### Rust Design Patterns Book — Idioms
- **URL**: https://rust-unofficial.github.io/patterns/idioms/
- **Purpose**: Source for idiom-violation entries (borrowed-type parameters, mem::take/replace, return-consumed-argument-on-error, closure variable capture) selected for agent-relevance
- **Date Accessed**: 2026-07-17
- **Key Topics**: coercion-arguments, mem-replace, return-consumed-arg-on-error, pass-var-to-closure

### Clippy Lint Index
- **URL**: https://rust-lang.github.io/rust-clippy/master/index.html
- **Purpose**: Verify exact clippy lint names and default-enabled status cited in the anti-patterns skill (ptr_arg, unwrap_used, expect_used)
- **Date Accessed**: 2026-07-17
- **Key Topics**: ptr_arg (style group, warn-by-default), unwrap_used / expect_used (restriction group, opt-in only)

## CLI Skill

### Rust CLI Book
- **URL**: https://rust-cli.github.io/book/
- **Purpose**: Building command-line applications — argument parsing, output, signals, exit codes, testing, packaging
- **Date Accessed**: 2026-07-17
- **Key Topics**: clap derive API, anyhow context, indicatif progress bars, log/env_logger verbosity, ctrlc signal handling, exitcode, assert_cmd/predicates subprocess testing

### CLI Crates (version tracking, verified via crates.io API, 2026-07-17)
- **clap** — https://crates.io/crates/clap — 4.6.2
- **anyhow** — https://crates.io/crates/anyhow — 1.0.103
- **thiserror** — https://crates.io/crates/thiserror — 2.0.18
- **indicatif** — https://crates.io/crates/indicatif — 0.18.6
- **assert_cmd** — https://crates.io/crates/assert_cmd — 2.2.2
- **predicates** — https://crates.io/crates/predicates — 3.1.4
- **ctrlc** — https://crates.io/crates/ctrlc — 3.5.2
- **exitcode** — https://crates.io/crates/exitcode — 1.1.2
- **log** — https://crates.io/crates/log — 0.4.33
- **env_logger** — https://crates.io/crates/env_logger — 0.11.11
- **clap-verbosity-flag** — https://crates.io/crates/clap-verbosity-flag — 3.0.4

### Rust Cookbook (pointer only, not mirrored)
- **URL**: https://rust-lang-nursery.github.io/rust-cookbook/
- **Purpose**: Ecosystem crate discovery for the `rust:rust` "Common Crates by Task" table — used to confirm which crate is canonical for a given task (error handling, CLI, HTTP, etc.), not copied as recipe content
- **Date Accessed**: 2026-07-17
- **Key Topics**: 24 chapters, ~380 recipes; only the error-handling (thiserror/anyhow) and CLI-adjacent entries were pulled into skill content — the remaining chapters (algorithms, compression, cryptography, database, science, WebAssembly, multimedia, raw networking, parser combinators) are out of scope for this update

## Plugin Information

- **Name**: rust
- **Version**: 0.1.7
- **Description**: Rust programming skills: ownership, borrowing, lifetimes, async, best practices, anti-patterns, and CLI apps
- **Skills**: 8 skills
- **Created**: 2025-11-15
- **Updated**: 2026-07-17
