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
