# Rust Anti-Patterns Catalog

Each entry: the anti-pattern, a labeled BAD example, a GOOD replacement, why it matters, and a detection hint. BAD examples are labeled so no one copies them.

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

---

## 1. Clone to Satisfy the Borrow Checker

**Source:** https://rust-unofficial.github.io/patterns/anti_patterns/borrow_clone.html

**Problem:** Reaching for `.clone()` the moment the borrow checker complains, instead of understanding why it complained. The clone compiles, but produces a second copy that no longer shares state with the original — mutations to one no longer show up in the other. The design issue that caused the borrow conflict remains, hidden behind a working build.

**BAD:**
```rust
// BAD: clones just to make the compiler happy
fn push_if_empty(v: &mut Vec<i32>, x: i32) {
    if v.clone().is_empty() {
        v.push(x);
    }
}
```

**GOOD:**
```rust
// GOOD: no aliasing conflict exists once the borrow is scoped correctly
fn push_if_empty(v: &mut Vec<i32>, x: i32) {
    if v.is_empty() {
        v.push(x);
    }
}
```

**Why:** `v.clone().is_empty()` was never necessary — `is_empty()` only needs `&self`. The clone masked that the original code had no real borrow conflict; in cases where a real conflict exists, cloning is a workaround that produces divergent copies instead of fixing the lifetime/scope.

**Detection hint:** No single clippy lint flags all instances (`clippy::redundant_clone` catches some, when the clone is provably unused for mutation). Review any `.clone()` added specifically to silence a borrow-checker error and ask whether restructuring scope, using `mem::take`/`mem::replace` (see #7), or splitting the borrow removes the need for it.

---

## 2. `#![deny(warnings)]`

**Source:** https://rust-unofficial.github.io/patterns/anti_patterns/deny-warnings.html

**Problem:** Denying the entire `warnings` group at the crate root breaks forward compatibility. New compiler lints introduced in a later toolchain (even during their grace/allow period) or newly-deprecated APIs can turn into hard build failures on a `cargo update` or toolchain bump the author didn't intend to gate on. It also blocks running clippy without editing the crate, since clippy's warnings pile onto the same denied group.

**BAD:**
```rust
// BAD: crate root
#![deny(warnings)]
```

**GOOD:**
```rust
// GOOD: crate root — only deny lints that are stable and intentional
#![deny(nonstandard_style, dead_code, unused)]
```
Or set `RUSTFLAGS="-D warnings"` in CI only, leaving local builds unaffected by new lints.

**Why:** `warnings` is not a fixed set — its membership grows with every Rust release. Denying it couples a crate's ability to compile to lints that didn't exist when the crate was written.

**Detection hint:** `grep -rn "deny(warnings)" --include=*.rs`. No clippy lint flags this since it's a compiler attribute, not a code pattern.

---

## 3. Deref Polymorphism

**Source:** https://rust-unofficial.github.io/patterns/anti_patterns/deref.html

**Problem:** Implementing `Deref` on a wrapper struct so that method calls on the wrapper implicitly forward to an embedded struct — simulating inheritance. `Deref` exists for building custom pointer/smart-pointer types (see #4's discussion of `Vec<T>` derefing to `&[T]`), not for establishing an is-a relationship. Forwarding through `Deref` doesn't give the wrapper the inner type's trait implementations and produces surprising implicit conversions at call sites.

**BAD:**
```rust
// BAD: Deref used to fake inheritance
struct Foo {}
impl Foo {
    fn m(&self) { /* ... */ }
}

struct Bar {
    f: Foo,
}
impl Deref for Bar {
    type Target = Foo;
    fn deref(&self) -> &Foo { &self.f }
}

// bar.m() silently resolves through Foo — not an explicit relationship
```

**GOOD:**
```rust
// GOOD: explicit delegation, or a trait shared by both types
struct Bar {
    f: Foo,
}
impl Bar {
    fn m(&self) { self.f.m() }
}
```

**Why:** `Deref`'s contract is "acts like a pointer to T," not "is a T." Using it for method forwarding hides the relationship from readers and from the trait system (traits implemented on `Foo` are not automatically implemented on `Bar`).

**Detection hint:** Review any `impl Deref for` where `Target` is a sibling business-logic struct rather than a pointer/collection/wrapper type the struct actually owns as its primary payload.

---

## 4. `&String` / `&Vec<T>` Parameters (ptr_arg)

**Source (idiom):** https://rust-unofficial.github.io/patterns/idioms/coercion-arguments.html
**Source (lint):** [`clippy::ptr_arg`](https://rust-lang.github.io/rust-clippy/master/index.html#ptr_arg) — style group, warn-by-default.

**Problem:** Taking `&String`, `&Vec<T>`, `&PathBuf`, or `&Box<T>` as a function parameter when the function only reads the data. It compiles and works, but forces every caller holding a `&str`/`&[T]`/`&Path` to allocate or restructure to call the function, and forecloses deref coercion that would otherwise let one function accept both owned and borrowed forms.

**BAD:**
```rust
// BAD: clippy::ptr_arg — forces callers to hold an owned Vec
fn process(data: &Vec<i32>) {
    for x in data {
        println!("{x}");
    }
}
```

**GOOD:**
```rust
// GOOD: accepts a Vec, an array, or a slice via deref coercion
fn process(data: &[i32]) {
    for x in data {
        println!("{x}");
    }
}
```

Same substitution applies to `&String` → `&str`, `&PathBuf` → `&Path`, `&Box<T>` → `&T`.

**Why:** The borrowed form is a strict superset of what the owned-reference form accepts, at no cost to the callee — slices and `&str` support the same read-only operations as `&Vec<T>`/`&String` in the common case.

**Detection hint:** `clippy::ptr_arg` fires directly on this. Run `cargo clippy` — it is enabled by default, no `#[allow]` needed to see it.

---

## 5. `unwrap()` / `expect()` on Fallible Paths

**Source (lints):** [`clippy::unwrap_used`](https://rust-lang.github.io/rust-clippy/master/index.html#unwrap_used), [`clippy::expect_used`](https://rust-lang.github.io/rust-clippy/master/index.html#expect_used) — both in the `restriction` group, which is opt-in only (not part of clippy's default warn set).

**Problem:** Calling `.unwrap()` or `.expect()` on a `Result`/`Option` that came from a fallible operation (file I/O, network, parsing, user input, a lookup that can legitimately miss) turns a recoverable error into an unconditional panic. This is distinct from `unwrap()` on a value the code has already proven infallible (e.g., a regex compiled from a string literal known to be valid) — the anti-pattern is unwrapping paths that depend on external state.

**BAD:**
```rust
// BAD: panics the whole process on a missing/malformed config file
fn load_config(path: &str) -> Config {
    let contents = std::fs::read_to_string(path).unwrap();
    toml::from_str(&contents).unwrap()
}
```

**GOOD:**
```rust
// GOOD: propagate with ? so the caller decides how to handle failure
fn load_config(path: &str) -> Result<Config, ConfigError> {
    let contents = std::fs::read_to_string(path)?;
    let config = toml::from_str(&contents)?;
    Ok(config)
}
```

**Why:** A library or service that unwraps on I/O or parsing turns an operational failure (missing file, bad network response) into a crash indistinguishable from a programming bug, and gives the caller no chance to retry, fall back, or report a clean error.

**Detection hint:** `clippy::unwrap_used` / `clippy::expect_used` are restriction-group lints — they do not fire under a plain `cargo clippy`. Enable them explicitly with one of: `#![warn(clippy::unwrap_used, clippy::expect_used)]` at the crate root, a `[lints.clippy]` table in `Cargo.toml` (`unwrap_used = "warn"`), or a one-off `cargo clippy -- -W clippy::unwrap_used`. `clippy.toml` cannot enable a lint — it only configures parameters (thresholds, allowed names) for lints already active some other way. Manually: grep for `.unwrap()`/`.expect(` and check whether the receiver's fallibility depends on I/O, parsing, or external input rather than a locally-provable invariant.

---

## 6. Sentinel Values Instead of `Option`/`Result`

**Problem:** Returning a magic value (`-1`, `0`, an empty string, `None`-shaped-as-a-default) to signal "no result" or "failure," instead of `Option<T>` or `Result<T, E>`. The function's return type no longer documents that absence/failure is possible, so callers can silently treat the sentinel as valid data.

**BAD:**
```rust
// BAD: -1 must be remembered by every caller as "not found"
fn find_index(haystack: &[i32], needle: i32) -> i32 {
    for (i, &x) in haystack.iter().enumerate() {
        if x == needle {
            return i as i32;
        }
    }
    -1
}
```

**GOOD:**
```rust
// GOOD: the type signature carries the "might not be found" contract
fn find_index(haystack: &[i32], needle: i32) -> Option<usize> {
    haystack.iter().position(|&x| x == needle)
}
```

**Why:** `Option<T>`/`Result<T, E>` make the possibility of absence or failure part of the type the compiler checks — a caller must explicitly handle `None`/`Err` (or explicitly panic) before reaching the value. A sentinel is just an `i32` the compiler will happily let a caller use as an array index.

**Detection hint:** No dedicated clippy lint catches arbitrary sentinel conventions (this is a design smell, not a syntax pattern). Review functions returning a primitive type (`i32`, `String`, a bare struct) where a comment or doc line explains what value means "not found" or "failed" — that comment is the tell.

---

## 7. Clone Instead of `mem::take`/`mem::replace`

**Source:** https://rust-unofficial.github.io/patterns/idioms/mem-replace.html

**Problem:** When code needs to move an owned value out of a `&mut` reference (e.g., to move data from one enum variant into a new variant), reaching for `.clone()` to get an owned copy while leaving the original untouched — when `mem::take`/`mem::replace` would move the value out directly, leaving a cheap default (or explicit replacement) behind, with no clone.

**BAD:**
```rust
// BAD: clones the whole String just to move it into a new variant
fn process(e: &mut MyEnum) {
    if let MyEnum::A { name } = e {
        *e = MyEnum::B { name: name.clone() };
    }
}
```

**GOOD:**
```rust
// GOOD: mem::take moves `name` out and leaves an empty String behind
use std::mem;

fn process(e: &mut MyEnum) {
    if let MyEnum::A { name } = e {
        *e = MyEnum::B { name: mem::take(name) };
    }
}
```

**Why:** `*e` is behind a `&mut` reference, so the compiler won't let code move `name` out of it directly — `mem::take` satisfies the borrow checker by swapping in `String::default()` (a no-allocation empty string) instead of requiring a full clone of the original data.

**Detection hint:** Look for `.clone()` on a field being read out of an enum/struct that is immediately reassigned or dropped afterward — a clone whose source is about to be overwritten or discarded is a `mem::take`/`mem::replace` candidate.

---

## 8. Losing Ownership on the Error Path

**Source:** https://rust-unofficial.github.io/patterns/idioms/return-consumed-arg-on-error.html

**Problem:** A fallible function that takes ownership of an argument, then on failure returns only an error value — discarding the argument the caller passed in. If the caller wants to retry or try an alternative, they must have kept a clone around beforehand, defeating the point of taking ownership in the first place.

**BAD:**
```rust
// BAD: on failure, the caller's `item` is gone — no way to retry
fn send(channel: &Channel, item: String) -> Result<(), String> {
    channel.try_send(item).map_err(|_| "channel full".to_string())
}
```

**GOOD:**
```rust
// GOOD: the error carries the value back so the caller can retry
struct SendError(String);

fn send(channel: &Channel, item: String) -> Result<(), SendError> {
    channel.try_send(item).map_err(SendError)
}
```

**Why:** Returning the consumed argument inside the error variant (as `std::sync::mpsc`'s `SendError` and `String::from_utf8`'s `FromUtf8Error` both do) lets the caller retry, log, or fall back without having cloned defensively before the call.

**Detection hint:** Review fallible functions that take an owned parameter (`String`, `Vec<T>`, a struct by value) and return a bare error type on failure — check whether the caller has any way to recover the argument, and add it to the error variant if not.

---

## 9. Over-Broad Closure Capture

**Source:** https://rust-unofficial.github.io/patterns/idioms/pass-var-to-closure.html

**Problem:** Slapping `move` on a closure to make the borrow checker happy, without controlling which variables actually get moved vs. cloned vs. borrowed. A blanket `move` pulls in every variable the closure body references, which can silently move a value the caller still needed afterward, or force an unnecessary clone of a large value that only needed to be borrowed.

**BAD:**
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
```

**GOOD:**
```rust
// GOOD: rebind each variable explicitly before the closure — borrow the
// read-only one instead of moving it, clone only the one that needs
// shared ownership for its mutation to outlive this scope
use std::cell::RefCell;
use std::rc::Rc;

let num1 = Rc::new(1);
let num2 = Rc::new(RefCell::new(2));
let closure = {
    let num1 = num1.as_ref();
    let num2 = Rc::clone(&num2);
    move || {
        println!("{num1}");
        *num2.borrow_mut() += 1;
    }
};
```

**Why:** Rebinding inside an inner scope before the closure makes the capture strategy for each variable an explicit, readable line, instead of leaving the reader to infer from the closure body which variables were moved, cloned, or borrowed by the blanket `move`. The GOOD version stops moving `num1` away from the enclosing scope — it only needed to be read, so it is borrowed via `.as_ref()` instead, mirroring the same rebinding technique the source idiom uses for its own borrowed variable.

**Detection hint:** Review `move || { ... }` closures that reference more than one outer variable — check whether every captured variable actually needs to be moved, or whether some should be cloned/borrowed via an explicit rebinding before the closure.
