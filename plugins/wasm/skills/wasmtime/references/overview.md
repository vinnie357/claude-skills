# Wasmtime Overview

## Installation

### Wasmtime CLI

```bash
# Install via installer script
curl https://wasmtime.dev/install.sh -sSf | bash

# Or via cargo
cargo install wasmtime-cli

# Verify
wasmtime --version
```

### Essential Tools

```bash
# cargo-component: build Rust components targeting the Component Model
cargo install cargo-component

# wasm-tools: inspect, validate, compose wasm binaries
cargo install wasm-tools

# wit-bindgen: generate language bindings from WIT
cargo install wit-bindgen-cli
```

## Core Concepts in Detail

### Engine

Global compilation configuration shared across all modules. Create once, reuse.

```rust
use wasmtime::*;

let mut config = Config::new();
config.cranelift_opt_level(OptLevel::Speed);
config.wasm_component_model(true);  // enable Component Model
config.async_support(true);          // enable async calls

let engine = Engine::new(&config)?;
```

Key configuration options:
- `cranelift_opt_level`: `None`, `Speed`, `SpeedAndSize`
- `wasm_component_model(true)`: required for components
- `async_support(true)`: required for async host functions
- `epoch_interruption(true)`: enable epoch-based interruption
- `consume_fuel(true)`: enable fuel metering

### Store

Owns all runtime state for instances. Carries user-defined host data.

```rust
struct HostState {
    wasi: wasmtime_wasi::WasiCtx,
    table: wasmtime::component::ResourceTable,
}

let mut store = Store::new(&engine, HostState { /* ... */ });

// Set fuel limit
store.set_fuel(10_000)?;

// Set epoch deadline
store.set_epoch_deadline(1);
```

### Module (Core WebAssembly)

A compiled core wasm module. Use for legacy or non-component wasm.

```rust
// From file
let module = Module::from_file(&engine, "path/to/module.wasm")?;

// From bytes
let module = Module::new(&engine, wasm_bytes)?;

// Precompiled (AOT)
let module = unsafe { Module::deserialize_file(&engine, "module.cwasm")? };
```

### Linker

Resolves module imports to host functions or other module exports.

```rust
let mut linker = Linker::new(&engine);

// Define a host function
linker.func_wrap("env", "log", |caller: Caller<'_, HostState>, ptr: i32, len: i32| {
    // read string from caller memory
})?;

// Add WASI
wasmtime_wasi::add_to_linker_sync(&mut linker)?;

// Instantiate
let instance = linker.instantiate(&mut store, &module)?;
```

### Instance

A runtime instantiation with its own memory and state.

```rust
let instance = linker.instantiate(&mut store, &module)?;

// Call exported function
let func = instance.get_typed_func::<(i32, i32), i32>(&mut store, "add")?;
let result = func.call(&mut store, (2, 3))?;
```

## Component Model

The Component Model adds typed, language-agnostic interfaces on top of core wasm.

### Key Differences from Core Modules

| Aspect | Core Module | Component |
|--------|-------------|-----------|
| Interface | Numeric types only (i32, i64, f32, f64) | Rich types (strings, records, variants, lists) |
| Linking | By function name | By interface (package/name) |
| Memory | Shared linear memory | Each component owns its memory |
| Composition | Manual wiring | `wasm-tools compose` |
| Standard | WebAssembly 1.0+ | Component Model proposal |

### WIT (WebAssembly Interface Type)

WIT defines typed contracts between components.

#### Syntax

```wit
// Package declaration
package my-org:my-package@1.0.0;

// World: defines a component's full interface
world my-world {
    // Imports (what the component needs)
    import log: func(msg: string);
    import wasi:filesystem/types@0.2.0;

    // Exports (what the component provides)
    export process: func(input: list<u8>) -> result<list<u8>, string>;
}

// Interface: reusable group of types and functions
interface types {
    record point {
        x: f64,
        y: f64,
    }

    variant shape {
        circle(f64),
        rectangle(point),
    }

    enum color {
        red,
        green,
        blue,
    }

    flags permissions {
        read,
        write,
        execute,
    }

    resource file-handle {
        constructor(path: string);
        read: func(size: u32) -> list<u8>;
        write: func(data: list<u8>);
    }
}
```

#### WIT Types

| WIT Type | Description | Rust Mapping |
|----------|-------------|--------------|
| `bool` | Boolean | `bool` |
| `u8`..`u64`, `s8`..`s64` | Integers | `u8`..`u64`, `i8`..`i64` |
| `f32`, `f64` | Floats | `f32`, `f64` |
| `char` | Unicode character | `char` |
| `string` | UTF-8 string | `String` |
| `list<T>` | Variable-length list | `Vec<T>` |
| `option<T>` | Optional value | `Option<T>` |
| `result<T, E>` | Success or error | `Result<T, E>` |
| `tuple<T, U>` | Fixed tuple | `(T, U)` |
| `record` | Named fields | `struct` |
| `variant` | Tagged union | `enum` |
| `enum` | Simple enumeration | `enum` (unit variants) |
| `flags` | Bit flags | bitflags struct |
| `resource` | Handle to host object | trait + handle |

### Component Composition

Combine multiple components into one using `wasm-tools compose`:

```bash
# Compose component A (needs interface X) with component B (provides interface X)
wasm-tools compose -d b.wasm a.wasm -o composed.wasm
```

## WASI Deep Dive

### WASIp1 (Preview 1)

POSIX-inspired system interface using core wasm imports.

```rust
// Host setup for WASIp1
use wasmtime_wasi::preview1;

let wasi = preview1::WasiCtxBuilder::new()
    .inherit_stdio()
    .preopened_dir("/sandbox", ".", DirPerms::all(), FilePerms::all())?
    .build();
```

Key WASIp1 modules:
- `wasi_snapshot_preview1`: filesystem, clock, random, args, environ

### WASIp2 (Preview 2)

Component Model-based system interface with typed streams.

```rust
// Host setup for WASIp2
use wasmtime_wasi::{WasiCtx, WasiCtxBuilder, WasiView};

let wasi_ctx = WasiCtxBuilder::new()
    .inherit_stdio()
    .preopened_dir("/sandbox", "sandbox", DirPerms::all(), FilePerms::all())?
    .build();
```

Key WASIp2 interfaces:
- `wasi:cli/*` — args, environment, stdin/stdout/stderr
- `wasi:filesystem/*` — files, directories, paths
- `wasi:sockets/*` — TCP, UDP, name resolution
- `wasi:clocks/*` — wall clock, monotonic clock
- `wasi:random/*` — random number generation
- `wasi:io/*` — streams, polling

### Migration from WASIp1 to WASIp2

1. Change target from `wasm32-wasip1` to `wasm32-wasip2`
2. Replace `fd_*` calls with WIT-generated bindings
3. Switch from `wasi_snapshot_preview1` imports to component imports
4. Use `wasm-tools component new` to wrap existing p1 modules for p2 compatibility:
   ```bash
   wasm-tools component new module.wasm --adapt wasi_snapshot_preview1.reactor.wasm -o component.wasm
   ```

## Resource Limits

### Fuel Metering

Count execution cost per instruction.

```rust
let mut config = Config::new();
config.consume_fuel(true);

let mut store = Store::new(&engine, state);
store.set_fuel(100_000)?;

// Check remaining
let remaining = store.get_fuel()?;

// Handle exhaustion
match func.call(&mut store, ()) {
    Err(e) if e.downcast_ref::<wasmtime::Trap>() == Some(&Trap::OutOfFuel) => {
        // refuel or terminate
    }
    other => other,
}
```

### Epoch Interruption

Coarse-grained cooperative interruption.

```rust
let mut config = Config::new();
config.epoch_interruption(true);

let mut store = Store::new(&engine, state);
store.set_epoch_deadline(1);  // interrupt after 1 epoch tick

// In another thread or timer:
engine.increment_epoch();
```

### Memory Limits

```rust
// Limit memory per-instance
let memory_type = MemoryType::new(1, Some(10));  // min 1 page, max 10 pages (640KB)

// Or via Store limits
let mut store = Store::new(&engine, state);
store.limiter(|_| &mut StoreLimitsBuilder::new()
    .memory_size(10 * 65536)  // 10 pages
    .instances(10)
    .tables(4)
    .build());
```

### Pooling Allocator

Pre-allocate resources for fast instantiation in high-throughput scenarios.

```rust
let mut pool = PoolingAllocationConfig::default();
pool.total_memories(100);
pool.total_tables(100);
pool.max_memory_size(1 << 20);  // 1MB per memory

let mut config = Config::new();
config.allocation_strategy(InstanceAllocationStrategy::Pooling(pool));
```

## AOT Compilation

Pre-compile wasm to native code for faster startup.

```bash
# CLI
wasmtime compile module.wasm -o module.cwasm

# Cross-compile for different target
wasmtime compile --target aarch64-unknown-linux-gnu module.wasm -o module.cwasm
```

```rust
// Programmatic AOT
let engine = Engine::default();
let cwasm_bytes = engine.precompile_module(wasm_bytes)?;

// Later, deserialize (unsafe: must trust the bytes)
let module = unsafe { Module::deserialize(&engine, &cwasm_bytes)? };
```

AOT-compiled modules (`.cwasm`) are architecture-specific. The engine configuration at deserialization must match the configuration used during compilation.

## Debugging and Profiling

### DWARF Debug Info

```rust
let mut config = Config::new();
config.debug_info(true);  // preserve DWARF in compiled code
```

### Profiling

```rust
let mut config = Config::new();
config.profiler(ProfilingStrategy::JitDump);  // Linux perf
// or
config.profiler(ProfilingStrategy::VTune);    // Intel VTune
```

### Logging

Enable wasmtime's tracing output:

```bash
WASMTIME_LOG=wasmtime=debug cargo run
```

### Inspecting Wasm Binaries

```bash
# Print module structure
wasm-tools print module.wasm

# Validate
wasm-tools validate module.wasm

# Show component interfaces
wasm-tools component wit component.wasm

# Module info
wasm-tools dump module.wasm
```
