# Guest Language: Rust

Compile Rust code to WebAssembly for execution in Wasmtime.

## Wasm Targets

| Target | Use Case | WASI | Component Model |
|--------|----------|------|-----------------|
| `wasm32-wasip1` | Legacy WASI modules | WASIp1 | No (core module) |
| `wasm32-wasip2` | Component Model components | WASIp2 | Yes |
| `wasm32-unknown-unknown` | Bare wasm, no system interface | No | No |

### Adding Targets

```bash
rustup target add wasm32-wasip1
rustup target add wasm32-wasip2
rustup target add wasm32-unknown-unknown
```

## Core Module (wasm32-wasip1)

### Basic Setup

```bash
cargo new --lib my-wasm-lib
cd my-wasm-lib
```

`Cargo.toml`:
```toml
[lib]
crate-type = ["cdylib"]
```

`src/lib.rs`:
```rust
#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

Build:
```bash
cargo build --target wasm32-wasip1 --release
# Output: target/wasm32-wasip1/release/my_wasm_lib.wasm
```

### WASI Command (main executable)

```rust
fn main() {
    let args: Vec<String> = std::env::args().collect();
    println!("Hello from WASI! Args: {:?}", args);
}
```

```bash
cargo build --target wasm32-wasip1 --release
wasmtime target/wasm32-wasip1/release/my_wasm_app.wasm -- arg1 arg2
```

## Component Model (wasm32-wasip2)

### cargo-component

The primary tool for building Rust components.

```bash
cargo install cargo-component
```

#### Create a New Component

```bash
cargo component new my-component
cd my-component
```

This generates:
- `Cargo.toml` with `cargo-component-bindings` dependency
- `wit/world.wit` defining the component interface
- `src/lib.rs` with binding scaffolding

#### Define WIT Interface

`wit/world.wit`:
```wit
package my-org:my-component@0.1.0;

world my-component {
    export process: func(input: string) -> string;
}
```

#### Implement the Component

`src/lib.rs`:
```rust
#[allow(warnings)]
mod bindings;

use bindings::Guest;

struct Component;

impl Guest for Component {
    fn process(input: String) -> String {
        format!("processed: {input}")
    }
}

bindings::export!(Component with_types_in bindings);
```

#### Build

```bash
cargo component build --release
# Output: target/wasm32-wasip2/release/my_component.wasm
```

### wit-bindgen

Generate Rust bindings from WIT files manually (without cargo-component).

```toml
[dependencies]
wit-bindgen = "0.36"
```

```rust
wit_bindgen::generate!({
    world: "my-world",
    path: "wit",
});
```

### Using WASI Interfaces in Components

Access WASI from within a component:

`wit/world.wit`:
```wit
package my-org:my-app@0.1.0;

world my-app {
    include wasi:cli/imports@0.2.0;
    export run: func() -> result<_, string>;
}
```

```rust
use bindings::wasi::filesystem::types::*;
use bindings::wasi::io::streams::*;

impl Guest for Component {
    fn run() -> Result<(), String> {
        // Use WASI interfaces through generated bindings
        Ok(())
    }
}
```

### Importing Host Functions

`wit/world.wit`:
```wit
package my-org:plugin@0.1.0;

interface host-api {
    log: func(level: log-level, msg: string);
    get-config: func(key: string) -> option<string>;

    enum log-level {
        debug,
        info,
        warn,
        error,
    }
}

world plugin {
    import host-api;
    export run: func() -> result<string, string>;
}
```

```rust
use bindings::my_org::plugin::host_api;

impl Guest for Component {
    fn run() -> Result<String, String> {
        host_api::log(host_api::LogLevel::Info, "plugin starting");
        let val = host_api::get_config("key").unwrap_or_default();
        Ok(val)
    }
}
```

## Binary Size Optimization

Wasm binary size directly affects load time and memory usage.

### Cargo.toml Profile

```toml
[profile.release]
opt-level = "z"          # optimize for size
lto = true               # link-time optimization
codegen-units = 1        # single codegen unit for better optimization
strip = true             # strip debug info
panic = "abort"          # no unwinding overhead
```

### Additional Techniques

| Technique | Savings | How |
|-----------|---------|-----|
| `wasm-opt` | 10-30% | `wasm-opt -Oz input.wasm -o output.wasm` |
| `wasm-strip` | Debug info | `wasm-tools strip input.wasm -o output.wasm` |
| Avoid `std` | Significant | `#![no_std]` with `wee_alloc` or custom allocator |
| Avoid `format!` | ~20KB | Use fixed strings where possible |
| Avoid panics | ~10KB | Use `Result` instead of `unwrap()` |

### Install wasm-opt

```bash
# Via binaryen
cargo install wasm-opt
# or
brew install binaryen
```

### Size Analysis

```bash
# Show section sizes
wasm-tools strip -a input.wasm | wasm-tools dump | head -20

# Detailed function-level analysis
cargo install twiggy
twiggy top target/wasm32-wasip2/release/my_component.wasm
twiggy dominators target/wasm32-wasip2/release/my_component.wasm
```

## Testing

### Unit Tests (native)

Run tests on the host (not in wasm) for logic testing:

```bash
cargo test
```

### Integration Tests with Wasmtime

Test compiled wasm in a host harness:

```rust
// tests/integration.rs (runs on host)
use wasmtime::*;

#[test]
fn test_add() -> anyhow::Result<()> {
    let engine = Engine::default();
    let module = Module::from_file(&engine, "target/wasm32-wasip1/release/my_lib.wasm")?;
    let mut store = Store::new(&engine, ());
    let instance = Linker::new(&engine).instantiate(&mut store, &module)?;

    let add = instance.get_typed_func::<(i32, i32), i32>(&mut store, "add")?;
    assert_eq!(add.call(&mut store, (2, 3))?, 5);
    Ok(())
}
```

### Testing with WASI

```rust
#[test]
fn test_wasi_command() -> anyhow::Result<()> {
    let engine = Engine::default();
    let module = Module::from_file(&engine, "target/wasm32-wasip1/release/my_app.wasm")?;

    let mut linker = Linker::new(&engine);
    wasmtime_wasi::preview1::add_to_linker_sync(&mut linker, |s| s)?;

    let wasi = wasmtime_wasi::preview1::WasiCtxBuilder::new()
        .inherit_stdio()
        .build();

    let mut store = Store::new(&engine, wasi);
    linker.module(&mut store, "", &module)?;

    let func = linker.get_default(&mut store, "")?
        .typed::<(), ()>(&store)?;
    func.call(&mut store, ())?;
    Ok(())
}
```

### Component Testing

```rust
use wasmtime::component::*;

bindgen!({
    world: "my-component",
    path: "wit",
});

#[test]
fn test_component() -> anyhow::Result<()> {
    let engine = Engine::default();
    let component = Component::from_file(&engine, "target/wasm32-wasip2/release/my_component.wasm")?;

    let mut linker = Linker::new(&engine);
    let mut store = Store::new(&engine, ());

    let instance = MyComponent::instantiate(&mut store, &component, &linker)?;
    let result = instance.call_process(&mut store, "hello")?;
    assert_eq!(result, "processed: hello");
    Ok(())
}
```

## Common Patterns

### Reactor vs Command

- **Command**: Has `fn main()`, runs once, used for CLI tools
- **Reactor**: Has `#[no_mangle]` exports, stays loaded, used for libraries and plugins

For reactors with WASIp1:
```toml
[lib]
crate-type = ["cdylib"]
```

For components, `cargo-component` handles this automatically.

### Error Handling Across the Boundary

Use `result<T, E>` in WIT for fallible exports:

```wit
export parse: func(input: string) -> result<parsed-data, parse-error>;
```

Map to Rust `Result`:
```rust
impl Guest for Component {
    fn parse(input: String) -> Result<ParsedData, ParseError> {
        // errors cross the boundary cleanly
        serde_json::from_str(&input).map_err(|e| ParseError { message: e.to_string() })
    }
}
```

### State Across Calls (Reactor Pattern)

Use `thread_local!` or `static` for persistent state in reactor-style components:

```rust
use std::cell::RefCell;

thread_local! {
    static STATE: RefCell<Vec<String>> = RefCell::new(Vec::new());
}

impl Guest for Component {
    fn add_item(item: String) {
        STATE.with(|s| s.borrow_mut().push(item));
    }

    fn get_items() -> Vec<String> {
        STATE.with(|s| s.borrow().clone())
    }
}
```
