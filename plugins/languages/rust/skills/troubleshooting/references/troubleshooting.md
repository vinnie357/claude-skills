# Rust Best Practices and Common Patterns

## Best Practices

### Prefer Borrowing

```rust
// Good: Borrow when possible
fn process(data: &Vec<i32>) {
    // Use data without taking ownership
}

// Avoid: Taking ownership unless needed
fn process(data: Vec<i32>) {
    // Can't use data after calling this
}
```

### Use ? for Error Propagation

```rust
// Good: Use ? operator
fn read_file(path: &str) -> Result<String, io::Error> {
    let mut file = File::open(path)?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;
    Ok(contents)
}

// Avoid: Manual match for each error
fn read_file(path: &str) -> Result<String, io::Error> {
    let mut file = match File::open(path) {
        Ok(f) => f,
        Err(e) => return Err(e),
    };
    // ...
}
```

### Use Iterators

```rust
// Good: Iterators (lazy, efficient)
let sum: i32 = vec![1, 2, 3, 4, 5]
    .iter()
    .filter(|x| *x % 2 == 0)
    .map(|x| x * 2)
    .sum();

// Avoid: Manual loops when iterators work
let mut sum = 0;
for x in vec![1, 2, 3, 4, 5] {
    if x % 2 == 0 {
        sum += x * 2;
    }
}
```

### Prefer &str over &String

```rust
// Good: Accept string slices
fn greet(name: &str) {
    println!("Hello, {}", name);
}

// Can be called with both &str and &String
greet("Alice");
greet(&String::from("Bob"));

// Less flexible: Only accepts &String
fn greet(name: &String) {
    println!("Hello, {}", name);
}
```

## Common Patterns

### Builder Pattern

```rust
#[derive(Default)]
struct User {
    name: String,
    email: String,
    age: Option<u32>,
}

impl User {
    fn builder() -> UserBuilder {
        UserBuilder::default()
    }
}

#[derive(Default)]
struct UserBuilder {
    name: String,
    email: String,
    age: Option<u32>,
}

impl UserBuilder {
    fn name(mut self, name: impl Into<String>) -> Self {
        self.name = name.into();
        self
    }

    fn email(mut self, email: impl Into<String>) -> Self {
        self.email = email.into();
        self
    }

    fn age(mut self, age: u32) -> Self {
        self.age = Some(age);
        self
    }

    fn build(self) -> User {
        User {
            name: self.name,
            email: self.email,
            age: self.age,
        }
    }
}

// Usage
let user = User::builder()
    .name("Alice")
    .email("alice@example.com")
    .age(30)
    .build();
```

### Newtype Pattern

```rust
// Newtype for type safety
struct Meters(f64);
struct Seconds(f64);

fn calculate_speed(distance: Meters, time: Seconds) -> f64 {
    distance.0 / time.0
}

// Can't accidentally swap parameters
let speed = calculate_speed(Meters(100.0), Seconds(9.8));
```
