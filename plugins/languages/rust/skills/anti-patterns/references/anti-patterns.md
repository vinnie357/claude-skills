# Rust Anti-Patterns Catalog

Each entry: a labeled BAD example, a GOOD replacement, and a one-line source + why + detection hint. BAD examples are labeled so no one copies them.

## Table of Contents

1. [Clone to Satisfy the Borrow Checker](#1-clone-to-satisfy-the-borrow-checker)
2. [`#![deny(warnings)]`](#2-denywarnings)
3. [Deref Polymorphism](#3-deref-polymorphism)
4. [`&String` / `&Vec<T>` Parameters (ptr_arg)](#4-string--vect-parameters-ptr_arg)
5. [`unwrap()` / `expect()` on Fallible Paths](#5-unwrap--expect-on-fallible-paths)
6. [Sentinel Values Instead of `Option`/`Result`](#6-sentinel-values-instead-of-optionresult)
7. [Clone Instead of `mem::take`/`mem::replace`](#7-clone-instead-of-memtakememreplace)
8. [Losing Ownership on the Error Path](#8-losing-ownership-on-the-error-path)
9. [Over-Broad Closure Capture](#9-over-broad-closure-capture)

## 1. Clone to Satisfy the Borrow Checker

[Source](https://rust-unofficial.github.io/patterns/anti_patterns/borrow_clone.html): reaching for `.clone()` when the borrow checker complains produces a divergent copy that hides the real design issue behind a working build — `is_empty()` below only needs `&self`.
```rust
// BAD: clones just to make the compiler happy
fn push_if_empty(v: &mut Vec<i32>, x: i32) {
    if v.clone().is_empty() { v.push(x); }
}
// GOOD: no aliasing conflict exists once the borrow is scoped correctly
fn push_if_empty(v: &mut Vec<i32>, x: i32) {
    if v.is_empty() { v.push(x); }
}
```
**Detection:** a `.clone()` added to silence a borrow-checker error — check whether scoping, `mem::take`/`mem::replace` (#7), or splitting the borrow removes the need for it.

## 2. `#![deny(warnings)]`

[Source](https://rust-unofficial.github.io/patterns/anti_patterns/deny-warnings.html): `warnings` is not a fixed set — denying the whole group at the crate root couples the crate's ability to compile to lints that didn't exist when it was written, breaking on a future toolchain bump.
```rust
// BAD: crate root
#![deny(warnings)]
// GOOD: only deny lints that are stable and intentional
#![deny(nonstandard_style, dead_code, unused)]
```
Or set `RUSTFLAGS="-D warnings"` in CI only, leaving local builds unaffected. **Detection:** `grep -rn "deny(warnings)" --include=*.rs` — no clippy lint flags this (compiler attribute, not a code pattern).

## 3. Deref Polymorphism

[Source](https://rust-unofficial.github.io/patterns/anti_patterns/deref.html): `Deref`'s contract is "acts like a pointer to T" (see #4's `Vec<T>`→`&[T]` coercion), not "is a T" — forwarding through it to simulate inheritance gives the wrapper none of the inner type's trait impls.
```rust
// BAD: Deref used to fake inheritance
struct Bar { f: Foo }
impl Deref for Bar {
    type Target = Foo;
    fn deref(&self) -> &Foo { &self.f }
}
// bar.m() silently resolves through Foo — not an explicit relationship
// GOOD: explicit delegation, or a trait shared by both types
impl Bar {
    fn m(&self) { self.f.m() }
}
```
**Detection:** any `impl Deref for` where `Target` is a sibling business-logic struct, not a pointer/collection/wrapper the struct owns as its primary payload.

## 4. `&String` / `&Vec<T>` Parameters (ptr_arg)

[`clippy::ptr_arg`](https://rust-lang.github.io/rust-clippy/master/index.html#ptr_arg) (style, warn-by-default) / [idiom source](https://rust-unofficial.github.io/patterns/idioms/coercion-arguments.html): `&String`/`&Vec<T>`/`&PathBuf`/`&Box<T>` params force a caller holding a borrowed form to allocate, when the borrowed form is a strict superset of what the owned-reference form accepts.
```rust
// BAD: clippy::ptr_arg — forces callers to hold an owned Vec
fn process(data: &Vec<i32>) { for x in data { println!("{x}"); } }
// GOOD: accepts a Vec, an array, or a slice via deref coercion
fn process(data: &[i32]) { for x in data { println!("{x}"); } }
```
Same substitution: `&String` → `&str`, `&PathBuf` → `&Path`, `&Box<T>` → `&T`. **Detection:** `cargo clippy` flags this by default.

## 5. `unwrap()` / `expect()` on Fallible Paths

[`clippy::unwrap_used`](https://rust-lang.github.io/rust-clippy/master/index.html#unwrap_used) / [`expect_used`](https://rust-lang.github.io/rust-clippy/master/index.html#expect_used) (`restriction` group, opt-in only): unwrapping a `Result`/`Option` from a fallible operation (I/O, network, parsing, user input) turns a recoverable error into a panic — distinct from unwrapping a value already proven infallible locally (e.g. a regex from a known-valid literal).
```rust
// BAD: panics the whole process on a missing/malformed config file
fn load_config(path: &str) -> Config {
    let contents = std::fs::read_to_string(path).unwrap();
    toml::from_str(&contents).unwrap()
}
// GOOD: propagate with ? so the caller decides how to handle failure
fn load_config(path: &str) -> Result<Config, ConfigError> {
    let contents = std::fs::read_to_string(path)?;
    Ok(toml::from_str(&contents)?)
}
```
**Detection:** enable with `#![warn(clippy::unwrap_used, clippy::expect_used)]`, `[lints.clippy]` in `Cargo.toml`, or `cargo clippy -- -W clippy::unwrap_used` — `clippy.toml` cannot enable a lint, only configure one already active.

## 6. Sentinel Values Instead of `Option`/`Result`

Returning a magic value (`-1`, `0`, an empty string) instead of `Option<T>`/`Result<T, E>` removes the "absence is possible" contract from the return type, so a caller can silently treat the sentinel as valid data.
```rust
// BAD: -1 must be remembered by every caller as "not found"
fn find_index(haystack: &[i32], needle: i32) -> i32 {
    haystack.iter().position(|&x| x == needle).map(|i| i as i32).unwrap_or(-1)
}
// GOOD: the type signature carries the "might not be found" contract
fn find_index(haystack: &[i32], needle: i32) -> Option<usize> {
    haystack.iter().position(|&x| x == needle)
}
```
**Detection:** no dedicated clippy lint (a design smell, not syntax) — review functions returning a primitive where a comment explains what value means "not found."

## 7. Clone Instead of `mem::take`/`mem::replace`

[Source](https://rust-unofficial.github.io/patterns/idioms/mem-replace.html): cloning to move an owned value out of a `&mut` reference (e.g. swapping enum variants) copies data that `mem::take`/`mem::replace` would move directly, leaving a cheap default behind instead.
```rust
// BAD: clones the whole String just to move it into a new variant
fn process(e: &mut MyEnum) {
    if let MyEnum::A { name } = e { *e = MyEnum::B { name: name.clone() }; }
}
// GOOD: mem::take moves `name` out and leaves an empty String behind
use std::mem;
fn process(e: &mut MyEnum) {
    if let MyEnum::A { name } = e { *e = MyEnum::B { name: mem::take(name) }; }
}
```
**Detection:** a `.clone()` on a field read out of an enum/struct immediately reassigned or dropped afterward.

## 8. Losing Ownership on the Error Path

[Source](https://rust-unofficial.github.io/patterns/idioms/return-consumed-arg-on-error.html): a fallible function that takes ownership of an argument and returns only an error on failure discards the caller's value, forcing a defensive clone if the caller wants to retry.
```rust
// BAD: on failure, the caller's `item` is gone — no way to retry
fn send(channel: &Channel, item: String) -> Result<(), String> {
    channel.try_send(item).map_err(|_| "channel full".to_string())
}
// GOOD: the error carries the value back so the caller can retry
struct SendError(String);
fn send(channel: &Channel, item: String) -> Result<(), SendError> {
    channel.try_send(item).map_err(SendError)
}
```
**Detection:** a fallible function taking an owned parameter that returns a bare error type on failure, with no way for the caller to recover the argument.

## 9. Over-Broad Closure Capture

[Source](https://rust-unofficial.github.io/patterns/idioms/pass-var-to-closure.html): a blanket `move` pulls in every referenced variable the same way, which can move a value the caller still needed or force an unnecessary clone of something that only needed to be borrowed.
```rust
// BAD: `move` takes ownership of both, even though `num1` is only read
use std::cell::RefCell;
use std::rc::Rc;
let num1 = Rc::new(1);
let num2 = Rc::new(RefCell::new(2));
let closure = move || {
    println!("{num1}");
    *num2.borrow_mut() += 1;
};
// GOOD: rebind explicitly — borrow the read-only var, clone only the
// one needing shared ownership for its mutation to outlive this scope
let closure = {
    let num1 = num1.as_ref();
    let num2 = Rc::clone(&num2);
    move || {
        println!("{num1}");
        *num2.borrow_mut() += 1;
    }
};
```
**Detection:** a `move || { ... }` closure referencing more than one outer variable — check whether every captured variable needs to move, or should be cloned/borrowed via an explicit rebinding first.
