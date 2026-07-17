---
name: cli
description: Guide for building Rust command-line applications. Use when parsing CLI arguments with clap, adding progress bars or verbosity flags, testing a CLI binary as a subprocess, choosing process exit codes, or reporting errors to end users with anyhow context.
---

# Rust CLI Applications

Argument parsing, user-facing output, exit codes, signal handling, and subprocess testing for command-line tools.

## When to Use This Skill

Activate when:
- Parsing arguments and subcommands with clap's derive API
- Adding an `anyhow::Context` to an error chain for a readable top-level failure message
- Printing progress bars, verbosity-gated logs, or machine-readable output (JSON/TSV) for piped consumers
- Handling Ctrl+C or other signals for graceful shutdown
- Choosing a process exit code on success or failure
- Testing a compiled binary as a subprocess with assert_cmd

For argument parsing, error context, output, signals, exit codes, and testing patterns, see `references/cli.md`.

## Example

```rust
use clap::Parser;

#[derive(Parser)]
struct Cli {
    pattern: String,
    path: std::path::PathBuf,
}

fn main() {
    let cli = Cli::parse(); // derives parsing, validation, and --help
}
```

The full argument-parsing, error-context, output, signals, exit-code, and testing patterns are in `references/cli.md`.

This skill covers CLI-specific ecosystem crates. For custom error enum design (thiserror) shared with non-CLI code, see `rust:error-handling`. For unit and integration test structure not specific to CLI binaries, see `rust:testing`.

See `/core:anti-fabrication` — crate versions and behavior claims in this skill are verified against crates.io and the upstream Rust CLI Book, not assumed.
