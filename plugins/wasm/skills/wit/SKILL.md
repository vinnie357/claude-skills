---
name: wit
description: Guide for WebAssembly Interface Type (WIT) language. Use when defining component interfaces, writing WIT files, designing worlds and interfaces, or working with the Component Model type system.
license: MIT
---

# WIT (WebAssembly Interface Types)

WIT is the Interface Definition Language (IDL) for the WebAssembly Component Model. It defines typed contracts between components in a language-agnostic way, enabling interoperability across programming languages at the wasm boundary.

See also: [wasmtime skill](../wasmtime/SKILL.md) for runtime embedding and compilation details.

## When to Use This Skill

Activate when:
- Writing `.wit` files to define component interfaces
- Designing worlds for WebAssembly components
- Understanding the Component Model type system
- Using `cargo-component`, `wit-bindgen`, or `wasm-tools`
- Mapping WIT types to host language types (Rust, Go, Python, JavaScript)
- Structuring packages and namespaces for wasm components
- Composing components via shared interfaces

## WIT File Structure

A WIT file contains one or more of: package declaration, interfaces, worlds, and use declarations.

```wit
package namespace:package-name@1.0.0;

use wasi:io/streams@0.2.0.{input-stream, output-stream};

interface my-interface {
    // types and functions
}

world my-world {
    import my-interface;
    export my-interface;
}
```

## Packages

Every WIT file belongs to a package. The package declaration names the namespace, package, and optional semver version.

```wit
package my-org:my-lib@0.1.0;
```

- `namespace`: organization or project identifier (kebab-case)
- `package`: library name (kebab-case)
- `@version`: optional semver string

Package names use kebab-case identifiers. Dots are not allowed in identifiers; use hyphens.

## Identifiers

WIT identifiers use kebab-case. Reserved words may be used as identifiers when prefixed with `%`:

```wit
interface example {
    // 'type' is reserved — prefix with %
    get-type: func() -> %type;
    type %type = string;
}
```

## Interfaces

An interface groups related types and functions into a named, reusable unit.

```wit
interface geometry {
    record point {
        x: f64,
        y: f64,
    }

    distance: func(a: point, b: point) -> f64;
    translate: func(p: point, dx: f64, dy: f64) -> point;
}
```

Interfaces can be imported by worlds or by other interfaces using `use`.

## Worlds

A world defines a complete component contract: what it imports (needs) and what it exports (provides). Worlds serve a dual role — they describe a component's requirements AND define the hosting environment that runs it. The only ways a component can interact with anything outside itself are by having its exports called or by calling its imports. A component cannot access resources it does not explicitly import, providing strong sandboxing boundaries.

```wit
world image-processor {
    // Imports: capabilities the component requires from the host
    import wasi:filesystem/preopens@0.2.0;
    import log: func(msg: string);

    // Exports: capabilities the component provides to callers
    export process: func(input: list<u8>) -> result<list<u8>, string>;
    export geometry;
}
```

### World Items

| Item | Syntax | Purpose |
|------|--------|---------|
| Import interface | `import name: interface { ... }` | Inline imported interface |
| Import named | `import wasi:io/streams@0.2.0;` | Import by package path |
| Import function | `import log: func(msg: string);` | Single function import |
| Import type | `import wasi:io/streams.{input-stream};` | Import specific types |
| Export interface | `export my-interface;` | Export a named interface |
| Export function | `export run: func();` | Export a single function |
| Include world | `include other-world;` | Inherit another world's items |

### World Includes

Worlds can include other worlds to inherit their imports and exports:

```wit
world base {
    import wasi:cli/environment@0.2.0;
}

world extended {
    include base;
    export my-app: func();
}
```

The `with` clause renames included items to avoid conflicts:

```wit
world combined {
    include world-a with { run as run-a };
    include world-b with { run as run-b };
}
```

## Type System

Full reference: [syntax-reference.md](references/syntax-reference.md)

### Primitives

| Type | Description |
|------|-------------|
| `bool` | Boolean |
| `u8`, `u16`, `u32`, `u64` | Unsigned integers |
| `s8`, `s16`, `s32`, `s64` | Signed integers |
| `f32`, `f64` | IEEE 754 floats |
| `char` | Unicode scalar value |
| `string` | UTF-8 string |

### Compound Types

```wit
interface types {
    // List: variable-length sequence
    type byte-array = list<u8>;

    // Option: nullable value
    type maybe-string = option<string>;

    // Result: success or error
    type parse-result = result<u32, string>;
    type io-result = result<_, string>;   // ok with no payload
    type check-result = result;           // both ok and err have no payload

    // Tuple: fixed-length heterogeneous sequence
    type pair = tuple<string, u32>;
}
```

### Records

Named field structs — equivalent to a `struct` in most languages.

```wit
record http-request {
    method: string,
    url: string,
    headers: list<tuple<string, string>>,
    body: option<list<u8>>,
}
```

### Variants

Tagged unions where each case may carry a payload.

```wit
variant ip-address {
    ipv4(tuple<u8, u8, u8, u8>),
    ipv6(string),
}

variant error-kind {
    not-found,
    permission-denied(string),
    timeout(u32),
    unknown,
}
```

### Enums

Variants without payloads — a simple discriminant.

```wit
enum color {
    red,
    green,
    blue,
}

enum log-level {
    trace,
    debug,
    info,
    warn,
    error,
}
```

### Flags

Bit-flag sets where multiple values can be active simultaneously.

```wit
flags permissions {
    read,
    write,
    execute,
}

// Usage: a value can hold any combination of these flags
```

### Type Aliases

```wit
type bytes = list<u8>;
type error-message = string;
```

## Functions

Functions are defined in interfaces with named parameters and return types.

```wit
interface math {
    // No return value
    reset: func();

    // Single return
    add: func(a: s32, b: s32) -> s32;

    // Named returns (multiple values)
    div-rem: func(num: s32, denom: s32) -> (quotient: s32, remainder: s32);

    // Result return
    parse-int: func(s: string) -> result<s32, string>;

    // Option return
    find: func(haystack: list<string>, needle: string) -> option<u32>;
}
```

Named return values appear as a named tuple: `-> (name: type, ...)`.

## Resources

Resources represent opaque handles to objects with identity — equivalent to objects or handles in host languages.

```wit
resource file-handle {
    // Constructor: creates a new resource instance
    constructor(path: string, mode: open-mode);

    // Regular methods: take `self` implicitly
    read: func(max-bytes: u32) -> result<list<u8>, io-error>;
    write: func(data: list<u8>) -> result<u32, io-error>;
    flush: func() -> result<_, io-error>;

    // Static method: no implicit self
    exists: static func(path: string) -> bool;
}
```

Resource instances are automatically dropped when the handle goes out of scope in the host language. The Component Model tracks ownership.

Resources can also be used as plain types in interfaces:

```wit
interface storage {
    resource blob {
        constructor(data: list<u8>);
        size: func() -> u64;
        slice: func(start: u64, end: u64) -> blob;
    }

    store: func(key: string, value: borrow<blob>) -> result<_, string>;
    load: func(key: string) -> result<blob, string>;
}
```

`borrow<T>` passes a resource by borrowed reference (no ownership transfer). Without `borrow`, the resource is moved (owned transfer).

## Use Declarations

Import types or interfaces from other packages or from within the same package.

```wit
// Import specific types from another package
use wasi:io/streams@0.2.0.{input-stream, output-stream};

// Import an entire interface
use wasi:filesystem/types@0.2.0;

// Alias an imported type
use wasi:clocks/wall-clock@0.2.0.{datetime as wall-datetime};
```

Use declarations appear at the top of an interface or world, before other items.

## Comments

```wit
// Single-line comment

/*
  Multi-line comment
*/

/// Documentation comment (attached to the next item)
/// Appears in generated bindings as doc comments.
interface documented {
    /// Returns the current UTC timestamp in seconds.
    now: func() -> u64;
}
```

## Tooling

### cargo-component

Build Rust components targeting the Component Model:

```bash
# Install
cargo install cargo-component

# Create a new component project
cargo component new my-component --lib

# Build
cargo component build

# Build for release
cargo component build --release
```

The generated `Cargo.toml` references WIT files via the `[package.metadata.component]` section:

```toml
[package.metadata.component]
package = "my-org:my-component"
```

### wit-bindgen

Generate language bindings from WIT files:

```bash
# Install CLI
cargo install wit-bindgen-cli

# Generate Rust bindings
wit-bindgen rust wit/ --out-dir src/bindings

# Generate C bindings
wit-bindgen c wit/ --out-dir include/
```

In Rust guest code, use the macro:

```rust
wit_bindgen::generate!({
    world: "my-world",
    path: "wit/",
});
```

### wasm-tools

Inspect and manipulate WIT and wasm binaries:

```bash
# Validate a WIT package
wasm-tools component wit wit/

# Extract WIT from a compiled component
wasm-tools component wit component.wasm

# Compose components
wasm-tools compose -d dependency.wasm main.wasm -o composed.wasm

# Validate a component
wasm-tools validate --features component-model component.wasm
```

## Common Patterns

### Plugin Interface

```wit
package my-app:plugin@0.1.0;

world plugin {
    // Host provides these to the plugin
    import log: func(level: string, msg: string);
    import config: func(key: string) -> option<string>;

    // Plugin must provide these
    export init: func() -> result<_, string>;
    export process: func(input: list<u8>) -> result<list<u8>, string>;
    export shutdown: func();
}
```

### Service Interface with Resources

```wit
package my-org:database@1.0.0;

interface db {
    resource connection {
        constructor(url: string) -> result<connection, string>;
        query: func(sql: string, params: list<string>) -> result<list<list<string>>, string>;
        close: func();
    }

    resource transaction {
        begin: static func(conn: borrow<connection>) -> result<transaction, string>;
        commit: func() -> result<_, string>;
        rollback: func() -> result<_, string>;
    }
}

world database-client {
    import db;
}
```

### Shared Type Library

```wit
package my-org:types@0.1.0;

interface common {
    record timestamp {
        seconds: u64,
        nanos: u32,
    }

    variant status {
        ok,
        error(string),
        pending,
    }
}
```

Then in another package:

```wit
package my-org:service@0.1.0;

use my-org:types/common@0.1.0.{timestamp, status};

interface service {
    get-status: func() -> status;
    last-updated: func() -> timestamp;
}
```

## Common Pitfalls

- **Kebab-case identifiers**: WIT requires `my-function`, not `myFunction` or `my_function`
- **No dot in identifiers**: use `wasi:io/streams`, not `wasi.io.streams`; dots are not valid in names
- **Result without payloads**: `result<_, E>` for ok-unit, `result<T, _>` for err-unit, `result` for both unit
- **borrow vs owned resource**: pass `borrow<resource-type>` when not transferring ownership; plain `resource-type` transfers ownership
- **Pin to WASI 0.2.0**: use `@0.2.0` for all WASI imports — this is the first stable WASI release and the recommended target for new components
- **Version in use paths**: always include `@version` when referencing external packages to ensure deterministic resolution
- **Package path in worlds**: `import wasi:io/streams@0.2.0` imports the `streams` interface from the `wasi:io` package
- **Missing semicolons**: type alias definitions require a trailing semicolon: `type bytes = list<u8>;`
