# Rust CLI Applications

Source: [Rust CLI Book](https://rust-cli.github.io/book/), verified crate versions from crates.io (accessed 2026-07-17).

## Argument Parsing with clap

`clap` (4.6.2) is the standard argument parser. The derive API generates parsing, validation, and `--help` from a struct:

```rust
use clap::{Parser, Subcommand};

/// Search for a pattern in a file
#[derive(Parser)]
#[command(name = "grrs", version)]
struct Cli {
    /// Pattern to look for
    pattern: String,
    /// File to search
    path: std::path::PathBuf,
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Count matches instead of printing them
    Count,
}

fn main() {
    let cli = Cli::parse();
    println!("pattern: {}, path: {:?}", cli.pattern, cli.path);
}
```
Add to `Cargo.toml`: `clap = { version = "4.6", features = ["derive"] }`.

## Error Context with anyhow

`anyhow` (1.0.103) provides `anyhow::Error` and a `Context` trait for CLI-level error reporting — attach what the program was trying to do, not just what the underlying library returned:

```rust
use anyhow::{Context, Result};

fn read_pattern_file(path: &std::path::Path) -> Result<String> {
    std::fs::read_to_string(path)
        .with_context(|| format!("could not read file `{}`", path.display()))
}
```

For the `thiserror` vs. `anyhow` library/binary boundary rule, see `rust:error-handling`.

## Output for Humans and Machines

Detect whether output is going to a terminal or being piped, and choose the format accordingly:

```rust
use std::io::IsTerminal;

fn main() {
    if std::io::stdout().is_terminal() {
        println!("Human-readable: 3 matches found");
    } else {
        println!("{}", serde_json::json!({"matches": 3}));
    }
}
```

A progress bar with `indicatif` (0.18.6):

```rust
use indicatif::ProgressBar;

fn main() {
    let bar = ProgressBar::new(100);
    for _ in 0..100 {
        bar.inc(1);
    }
    bar.finish_with_message("done");
}
```

Verbosity-gated logging with `log` (0.4.33), `env_logger` (0.11.11), and `clap-verbosity-flag` (3.0.4):

```rust
use clap_verbosity_flag::Verbosity;

#[derive(clap::Parser)]
struct Cli {
    #[command(flatten)]
    verbosity: Verbosity,
}

fn main() {
    env_logger::Builder::new()
        .filter_level(Cli::parse().verbosity.log_level_filter())
        .init();
}
```

## Signal Handling

For a simple Ctrl+C handler, use `ctrlc` (3.5.2):

```rust
fn main() -> Result<(), ctrlc::Error> {
    ctrlc::set_handler(move || {
        eprintln!("received Ctrl+C, shutting down");
        std::process::exit(130);
    })?;
    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
```

For multiple signal types (SIGTERM, SIGHUP) or async shutdown coordinated with tokio, the CLI Book's [signals chapter](https://rust-cli.github.io/book/in-depth/signals.html) covers `signal-hook` and `crossbeam-channel` — reach for those only when `ctrlc` alone cannot express the required signal set.

## Exit Codes

The `exitcode` crate (1.1.2) provides BSD `sysexits.h`-style constants as `i32`; convert through `u8` since `std::process::ExitCode` only implements `From<u8>`:

```rust
fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(_) => std::process::ExitCode::from(exitcode::DATAERR as u8),
    }
}
```

## Testing CLI Binaries

`assert_cmd` (2.2.2) with `predicates` (3.1.4) runs the compiled binary as a subprocess and asserts on stdout/stderr/exit code — this is integration testing for the actual user-facing behavior, not the internal functions:

```rust
use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn finds_a_match() {
    let mut cmd = Command::cargo_bin("grrs").unwrap();
    cmd.arg("foo").arg("tests/fixtures/sample.txt");
    cmd.assert()
        .success()
        .stdout(predicate::str::contains("foo"));
}
```

Extract the core logic into a library target (`src/lib.rs`) called from a thin `src/main.rs`, so unit tests can exercise the logic directly (see `rust:testing`) while `assert_cmd` covers the binary's observable behavior end to end.

## Packaging

Distribute a finished CLI via `cargo install` from crates.io first; add pre-built binaries via GitHub Releases once users need to avoid a local Rust toolchain. The CLI Book's [packaging chapter](https://rust-cli.github.io/book/tutorial/packaging.html) covers OS package manager integration (Homebrew, apt) as a later step — treat it as optional until a specific distribution channel is required.
