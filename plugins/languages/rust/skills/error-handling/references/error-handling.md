# Rust Error Handling

## Result Type

```rust
use std::fs::File;
use std::io::{self, Read};

// Returning Result
fn read_username_from_file() -> Result<String, io::Error> {
    let mut file = File::open("username.txt")?;
    let mut username = String::new();
    file.read_to_string(&mut username)?;
    Ok(username)
}

// Using Result
match read_username_from_file() {
    Ok(username) => println!("Username: {}", username),
    Err(e) => println!("Error: {}", e),
}
```

## Option Type

```rust
// Option for optional values
fn find_user(id: u32) -> Option<User> {
    if id == 1 {
        Some(User { id: 1, name: "Alice".to_string() })
    } else {
        None
    }
}

// Using Option
match find_user(1) {
    Some(user) => println!("Found: {}", user.name),
    None => println!("User not found"),
}

// Option combinators
let user = find_user(1)
    .map(|u| u.name)
    .unwrap_or("Unknown".to_string());
```

## The ? Operator

```rust
// ? operator for error propagation
fn read_file(path: &str) -> Result<String, io::Error> {
    let mut file = File::open(path)?;  // Returns early if Err
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;
    Ok(contents)
}

// Chaining with ?
fn process_file(path: &str) -> Result<usize, io::Error> {
    let contents = read_file(path)?;
    Ok(contents.len())
}
```

## Custom Error Types

```rust
use std::fmt;

#[derive(Debug)]
enum AppError {
    Io(io::Error),
    Parse(std::num::ParseIntError),
    Custom(String),
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            AppError::Io(e) => write!(f, "IO error: {}", e),
            AppError::Parse(e) => write!(f, "Parse error: {}", e),
            AppError::Custom(s) => write!(f, "Error: {}", s),
        }
    }
}

impl From<io::Error> for AppError {
    fn from(error: io::Error) -> Self {
        AppError::Io(error)
    }
}

// Usage
fn process() -> Result<(), AppError> {
    let file = File::open("data.txt")?;  // Auto-converts io::Error
    // ...
    Ok(())
}
```

## Ecosystem Error Crates

The hand-rolled `AppError` above is the pattern to know, but most Rust codebases
reach for `thiserror` (2.0.18) to derive it instead of writing `Display` and `From`
by hand:

```rust
use thiserror::Error;

#[derive(Error, Debug)]
enum AppError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("parse error: {0}")]
    Parse(#[from] std::num::ParseIntError),
    #[error("{0}")]
    Custom(String),
}
```

`#[from]` generates the same `From<io::Error>` impl written manually above;
`#[error("...")]` generates `Display`. Use `thiserror` for a library's public
error type — callers match on the enum's variants.

`anyhow` (1.0.103) is the complementary crate for the *calling* side — a binary
or top-level function that only needs to propagate and print an error, not let
callers match on it:

```rust
use anyhow::{Context, Result};

fn load_config(path: &str) -> Result<String> {
    std::fs::read_to_string(path)
        .with_context(|| format!("failed to load config from {path}"))
}
```

Rule of thumb: `thiserror` for a library's typed error enum, `anyhow` at the
application boundary that only reports the error. Don't use `anyhow::Error` as
a public library return type — it erases the type information callers need to
match on specific failure modes.

## `.unwrap()` in Teaching Examples vs. the No-Unwrap Rule

Skill examples across this plugin sometimes call `.unwrap()`/`.expect()` for brevity —
on a mutex lock, a channel receive, or a value the surrounding code just checked. That is
not a contradiction of the no-unwrap discipline: the rule targets *fallible* paths whose
success depends on external state (file I/O, network calls, parsing untrusted input,
`/rust:anti-patterns` entry 5) — not every occurrence of `.unwrap()` in an illustrative
snippet. When writing production code (not a teaching example), unwrap only a value the
code has locally proven cannot fail; propagate everything else with `?`.
