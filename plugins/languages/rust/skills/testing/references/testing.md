# Rust Testing and Cargo

## Unit Tests

```rust
// Tests in same file
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }

    #[test]
    fn test_add() {
        assert_eq!(add(2, 2), 4);
    }

    #[test]
    #[should_panic]
    fn test_panic() {
        panic!("This should panic");
    }

    #[test]
    fn test_result() -> Result<(), String> {
        if 2 + 2 == 4 {
            Ok(())
        } else {
            Err(String::from("two plus two does not equal four"))
        }
    }
}

fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

## Integration Tests

```rust
// tests/integration_test.rs
use my_crate;

#[test]
fn test_integration() {
    assert_eq!(my_crate::add(2, 2), 4);
}
```

## Running Tests

```bash
# Run all tests
cargo test

# Run specific test
cargo test test_add

# Run with output
cargo test -- --nocapture

# Run integration tests only
cargo test --test integration_test
```

## Cargo.toml

```toml
[package]
name = "my_project"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = { version = "1.0", features = ["derive"] }
tokio = { version = "1", features = ["full"] }
reqwest = "0.11"

[dev-dependencies]
mockall = "0.11"

[profile.release]
opt-level = 3
lto = true
```

## Common Commands

```bash
# Create new project
cargo new my_project
cargo new --lib my_lib

# Build
cargo build
cargo build --release

# Run
cargo run
cargo run --release

# Test
cargo test

# Check (faster than build)
cargo check

# Format code
cargo fmt

# Lint
cargo clippy

# Update dependencies
cargo update

# Add dependency
cargo add serde
```
