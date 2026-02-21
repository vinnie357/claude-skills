# Rust Core Language Features

Traits, generics, collections, and pattern matching.

## Traits

### Defining Traits

```rust
// Define a trait
trait Summary {
    fn summarize(&self) -> String;

    // Default implementation
    fn summarize_author(&self) -> String {
        String::from("(Read more...)")
    }
}

// Implement trait
struct Article {
    title: String,
    content: String,
}

impl Summary for Article {
    fn summarize(&self) -> String {
        format!("{}: {}", self.title, self.content)
    }
}
```

### Trait Bounds

```rust
// Function with trait bound
fn notify<T: Summary>(item: &T) {
    println!("Breaking news! {}", item.summarize());
}

// Multiple trait bounds
fn process<T: Summary + Display>(item: &T) {
    // ...
}

// Where clause (clearer for complex bounds)
fn complex<T, U>(t: &T, u: &U)
where
    T: Summary + Clone,
    U: Summary + Debug,
{
    // ...
}

// impl Trait syntax
fn returns_summarizable() -> impl Summary {
    Article {
        title: String::from("Title"),
        content: String::from("Content"),
    }
}
```

### Common Traits

```rust
// Clone and Copy
#[derive(Clone)]
struct Point {
    x: i32,
    y: i32,
}

// Debug
#[derive(Debug)]
struct User {
    name: String,
    age: u32,
}

// PartialEq and Eq
#[derive(PartialEq, Eq)]
struct Id(u32);

// PartialOrd and Ord
#[derive(PartialOrd, Ord, PartialEq, Eq)]
struct Priority(u32);
```

## Generics

### Generic Functions

```rust
// Generic function
fn largest<T: PartialOrd>(list: &[T]) -> &T {
    let mut largest = &list[0];

    for item in list {
        if item > largest {
            largest = item;
        }
    }

    largest
}

// Usage
let numbers = vec![34, 50, 25, 100, 65];
let result = largest(&numbers);

let chars = vec!['y', 'm', 'a', 'q'];
let result = largest(&chars);
```

### Generic Structs

```rust
// Generic struct
struct Point<T> {
    x: T,
    y: T,
}

impl<T> Point<T> {
    fn new(x: T, y: T) -> Self {
        Point { x, y }
    }
}

// Specific implementation for certain types
impl Point<f64> {
    fn distance_from_origin(&self) -> f64 {
        (self.x.powi(2) + self.y.powi(2)).sqrt()
    }
}

// Multiple type parameters
struct Pair<T, U> {
    first: T,
    second: U,
}
```

### Generic Enums

```rust
// Option is a generic enum
enum Option<T> {
    Some(T),
    None,
}

// Result is a generic enum
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

## Collections

### Vectors

```rust
// Create vector
let mut v: Vec<i32> = Vec::new();
let v = vec![1, 2, 3];

// Add elements
v.push(4);
v.push(5);

// Access elements
let third = &v[2];  // Panics if out of bounds
let third = v.get(2);  // Returns Option<&T>

// Iterate
for i in &v {
    println!("{}", i);
}

// Iterate and modify
for i in &mut v {
    *i += 50;
}
```

### HashMaps

```rust
use std::collections::HashMap;

// Create HashMap
let mut scores = HashMap::new();
scores.insert(String::from("Blue"), 10);
scores.insert(String::from("Yellow"), 50);

// Access values
let team = String::from("Blue");
let score = scores.get(&team);  // Returns Option<&V>

// Iterate
for (key, value) in &scores {
    println!("{}: {}", key, value);
}

// Update values
scores.entry(String::from("Blue")).or_insert(0);
*scores.entry(String::from("Blue")).or_insert(0) += 10;
```

### Strings

```rust
// Create strings
let s = String::from("hello");
let s = "hello".to_string();

// Concatenation
let s1 = String::from("Hello, ");
let s2 = String::from("world!");
let s3 = s1 + &s2;  // s1 is moved

// format! macro
let s = format!("{}-{}", "hello", "world");

// Iterate
for c in "hello".chars() {
    println!("{}", c);
}

// Slicing (be careful with UTF-8!)
let hello = "Здравствуйте";
let s = &hello[0..4];  // "Зд"
```

## Pattern Matching

### Match Expressions

```rust
// Basic match
let number = 7;
match number {
    1 => println!("One"),
    2 | 3 | 5 | 7 | 11 => println!("Prime"),
    13..=19 => println!("Teen"),
    _ => println!("Other"),
}

// Match with destructuring
struct Point {
    x: i32,
    y: i32,
}

let p = Point { x: 0, y: 7 };
match p {
    Point { x: 0, y } => println!("On y axis at {}", y),
    Point { x, y: 0 } => println!("On x axis at {}", x),
    Point { x, y } => println!("At ({}, {})", x, y),
}
```

### If Let

```rust
// if let for simple matches
let some_value = Some(3);

if let Some(3) = some_value {
    println!("three");
}

// With else
if let Some(x) = some_value {
    println!("{}", x);
} else {
    println!("None");
}
```

### While Let

```rust
// while let for loops
let mut stack = vec![1, 2, 3];

while let Some(top) = stack.pop() {
    println!("{}", top);
}
```
