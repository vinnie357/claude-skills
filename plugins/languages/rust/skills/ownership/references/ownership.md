# Rust Ownership and Borrowing

## Ownership Rules

Every value has exactly one owner:

```rust
// Ownership transfer (move)
let s1 = String::from("hello");
let s2 = s1;  // s1 is no longer valid
// println!("{}", s1);  // Error!
println!("{}", s2);  // OK

// Copy types (stack-only data)
let x = 5;
let y = x;  // x is still valid (Copy trait)
println!("{} {}", x, y);  // OK
```

## Borrowing

```rust
// Immutable borrow
fn calculate_length(s: &String) -> usize {
    s.len()
}

let s = String::from("hello");
let len = calculate_length(&s);
println!("{} has length {}", s, len);  // s still valid

// Mutable borrow
fn append_world(s: &mut String) {
    s.push_str(" world");
}

let mut s = String::from("hello");
append_world(&mut s);
println!("{}", s);  // "hello world"
```

## Borrowing Rules

```rust
// Rule 1: Multiple immutable borrows OK
let s = String::from("hello");
let r1 = &s;
let r2 = &s;
println!("{} {}", r1, r2);  // OK

// Rule 2: Only ONE mutable borrow at a time
let mut s = String::from("hello");
let r1 = &mut s;
// let r2 = &mut s;  // Error!
println!("{}", r1);

// Rule 3: Cannot have mutable and immutable borrows together
let mut s = String::from("hello");
let r1 = &s;
// let r2 = &mut s;  // Error!
println!("{}", r1);
```

## Slices

```rust
// String slices
let s = String::from("hello world");
let hello = &s[0..5];
let world = &s[6..11];

// Array slices
let arr = [1, 2, 3, 4, 5];
let slice = &arr[1..3];  // [2, 3]

// Function taking slice
fn first_word(s: &str) -> &str {
    let bytes = s.as_bytes();

    for (i, &item) in bytes.iter().enumerate() {
        if item == b' ' {
            return &s[0..i];
        }
    }

    &s[..]
}
```

## Lifetimes

### Lifetime Annotations

```rust
// Explicit lifetime annotation
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() {
        x
    } else {
        y
    }
}

// Usage
let s1 = String::from("long string");
let s2 = String::from("short");
let result = longest(&s1, &s2);
println!("Longest: {}", result);
```

### Lifetime in Structs

```rust
// Struct with lifetime
struct ImportantExcerpt<'a> {
    part: &'a str,
}

impl<'a> ImportantExcerpt<'a> {
    fn announce_and_return(&self) -> &str {
        println!("Attention: {}", self.part);
        self.part
    }
}

// Usage
let novel = String::from("Call me Ishmael. Some years ago...");
let first_sentence = novel.split('.').next().unwrap();
let excerpt = ImportantExcerpt { part: first_sentence };
```

### Lifetime Elision

```rust
// Compiler infers lifetimes (no annotation needed)
fn first_word(s: &str) -> &str {
    // Compiler infers: fn first_word<'a>(s: &'a str) -> &'a str
    let bytes = s.as_bytes();
    for (i, &item) in bytes.iter().enumerate() {
        if item == b' ' {
            return &s[0..i];
        }
    }
    &s[..]
}
```
