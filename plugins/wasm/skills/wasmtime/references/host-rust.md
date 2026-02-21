# Host Language: Rust

Embed the Wasmtime runtime in Rust applications.

## Dependencies

```toml
[dependencies]
wasmtime = "29"
wasmtime-wasi = "29"       # for WASI support
anyhow = "1"

# For async support
tokio = { version = "1", features = ["full"] }

# For Component Model
wit-bindgen = "0.36"       # (guest-side, if also building components)
```

## Core Module Embedding

### Minimal Example

```rust
use wasmtime::*;

fn main() -> anyhow::Result<()> {
    let engine = Engine::default();
    let module = Module::from_file(&engine, "module.wasm")?;
    let mut store = Store::new(&engine, ());
    let instance = Linker::new(&engine).instantiate(&mut store, &module)?;

    let func = instance.get_typed_func::<(i32, i32), i32>(&mut store, "add")?;
    let result = func.call(&mut store, (2, 3))?;
    println!("2 + 3 = {result}");
    Ok(())
}
```

### Host Functions

Define functions the wasm module can call:

```rust
use wasmtime::*;

struct HostState {
    log_buffer: Vec<String>,
}

fn main() -> anyhow::Result<()> {
    let engine = Engine::default();
    let module = Module::from_file(&engine, "module.wasm")?;

    let mut linker = Linker::new(&engine);

    // Simple host function
    linker.func_wrap("env", "host_random", || -> u32 {
        rand::random()
    })?;

    // Host function with Caller access (for reading guest memory)
    linker.func_wrap("env", "host_log", |mut caller: Caller<'_, HostState>, ptr: i32, len: i32| {
        let memory = caller.get_export("memory")
            .and_then(|e| e.into_memory())
            .expect("missing memory export");

        let data = memory.data(&caller);
        let msg = std::str::from_utf8(&data[ptr as usize..(ptr + len) as usize])
            .unwrap_or("<invalid utf8>");

        caller.data_mut().log_buffer.push(msg.to_string());
    })?;

    let state = HostState { log_buffer: Vec::new() };
    let mut store = Store::new(&engine, state);
    let instance = linker.instantiate(&mut store, &module)?;

    let run = instance.get_typed_func::<(), ()>(&mut store, "run")?;
    run.call(&mut store, ())?;

    println!("Logs: {:?}", store.data().log_buffer);
    Ok(())
}
```

### Memory Access

Read and write guest linear memory from the host:

```rust
let memory = instance.get_memory(&mut store, "memory")
    .expect("missing memory export");

// Read bytes from guest memory
let data = memory.data(&store);
let value = &data[offset..offset + length];

// Write bytes to guest memory
let data_mut = memory.data_mut(&mut store);
data_mut[offset..offset + length].copy_from_slice(&bytes);

// Grow memory
memory.grow(&mut store, 1)?;  // grow by 1 page (64KB)

// Current size
let pages = memory.size(&store);
let bytes = memory.data_size(&store);
```

## WASI Integration

### WASIp1 (Preview 1)

```rust
use wasmtime::*;
use wasmtime_wasi::preview1::{self, WasiP1Ctx};

fn main() -> anyhow::Result<()> {
    let engine = Engine::default();
    let module = Module::from_file(&engine, "wasi_app.wasm")?;

    let mut linker: Linker<WasiP1Ctx> = Linker::new(&engine);
    preview1::add_to_linker_sync(&mut linker, |ctx| ctx)?;

    let wasi_ctx = preview1::WasiCtxBuilder::new()
        .inherit_stdio()
        .inherit_env()
        .args(&["app", "--verbose"])
        .preopened_dir("./data", "data", DirPerms::all(), FilePerms::all())?
        .build();

    let mut store = Store::new(&engine, wasi_ctx);
    linker.module(&mut store, "", &module)?;

    let func = linker.get_default(&mut store, "")?
        .typed::<(), ()>(&store)?;
    func.call(&mut store, ())?;
    Ok(())
}
```

### WASIp2 (Preview 2)

```rust
use wasmtime::*;
use wasmtime::component::*;
use wasmtime_wasi::{WasiCtx, WasiCtxBuilder, WasiView};

struct ServerState {
    wasi: WasiCtx,
    table: ResourceTable,
}

impl WasiView for ServerState {
    fn ctx(&mut self) -> &mut WasiCtx { &mut self.wasi }
    fn table(&mut self) -> &mut ResourceTable { &mut self.table }
}

fn main() -> anyhow::Result<()> {
    let mut config = Config::new();
    config.wasm_component_model(true);

    let engine = Engine::new(&config)?;
    let component = Component::from_file(&engine, "component.wasm")?;

    let mut linker = Linker::new(&engine);
    wasmtime_wasi::add_to_linker_sync(&mut linker)?;

    let wasi = WasiCtxBuilder::new()
        .inherit_stdio()
        .build();

    let state = ServerState {
        wasi,
        table: ResourceTable::new(),
    };
    let mut store = Store::new(&engine, state);

    // Instantiate and use component...
    Ok(())
}
```

### WASI Configuration

```rust
let wasi = WasiCtxBuilder::new()
    // Stdio
    .inherit_stdio()                    // inherit host stdio
    .stdin(MemoryInputPipe::new(data))  // pipe data to stdin
    .stdout(MemoryOutputPipe::new())    // capture stdout

    // Environment
    .inherit_env()                      // inherit host env vars
    .env("KEY", "VALUE")               // set specific env var

    // Arguments
    .args(&["app", "--flag"])

    // Filesystem
    .preopened_dir(
        "/host/path",                   // host path
        "guest-alias",                  // guest mount point
        DirPerms::READ,                 // directory permissions
        FilePerms::READ,               // file permissions
    )?

    // Network (WASIp2)
    .inherit_network()                  // allow network access

    .build();
```

## Component Model Embedding

### bindgen! Macro

Generate Rust host bindings from WIT:

```rust
use wasmtime::component::*;
use wasmtime::*;

// Generate host-side bindings from WIT
bindgen!({
    world: "my-plugin",
    path: "wit",
    // async: true,                  // for async support
    // with: { "wasi:io": wasmtime_wasi::bindings::io },
});
```

Given this WIT:
```wit
package my-org:my-plugin@0.1.0;

interface plugin-api {
    record config {
        name: string,
        debug: bool,
    }

    process: func(input: string) -> result<string, string>;
    get-version: func() -> string;
}

world my-plugin {
    import log: func(msg: string);
    export plugin-api;
}
```

The `bindgen!` macro generates:
- A `MyPlugin` struct for instantiation
- Trait definitions for imports the host must satisfy
- Typed accessors for exports

### Implementing Host Imports

```rust
struct MyHost {
    wasi: WasiCtx,
    table: ResourceTable,
}

impl MyPluginImports for MyHost {
    fn log(&mut self, msg: String) {
        println!("[plugin] {msg}");
    }
}

impl WasiView for MyHost {
    fn ctx(&mut self) -> &mut WasiCtx { &mut self.wasi }
    fn table(&mut self) -> &mut ResourceTable { &mut self.table }
}
```

### Instantiating and Calling Components

```rust
fn main() -> anyhow::Result<()> {
    let mut config = Config::new();
    config.wasm_component_model(true);

    let engine = Engine::new(&config)?;
    let component = Component::from_file(&engine, "plugin.wasm")?;

    let mut linker = Linker::new(&engine);
    wasmtime_wasi::add_to_linker_sync(&mut linker)?;
    MyPlugin::add_to_linker(&mut linker, |state: &mut MyHost| state)?;

    let state = MyHost {
        wasi: WasiCtxBuilder::new().build(),
        table: ResourceTable::new(),
    };
    let mut store = Store::new(&engine, state);

    let (plugin, _instance) = MyPlugin::instantiate(&mut store, &component, &linker)?;

    // Call typed exports
    let api = plugin.my_org_my_plugin_plugin_api();
    let version = api.call_get_version(&mut store)?;
    let result = api.call_process(&mut store, "input data")?;
    match result {
        Ok(output) => println!("Output: {output}"),
        Err(e) => eprintln!("Plugin error: {e}"),
    }

    Ok(())
}
```

## Async Support

### Setup

```rust
let mut config = Config::new();
config.async_support(true);
config.wasm_component_model(true);

let engine = Engine::new(&config)?;
```

### Async Host Functions

```rust
bindgen!({
    world: "my-plugin",
    path: "wit",
    async: true,
});

#[async_trait::async_trait]
impl MyPluginImports for MyHost {
    async fn log(&mut self, msg: String) {
        // Can do async I/O here
        tokio::fs::write("log.txt", &msg).await.ok();
    }
}
```

### Async Instantiation

```rust
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let engine = Engine::new(&config)?;
    let component = Component::from_file(&engine, "plugin.wasm")?;

    let mut linker = Linker::new(&engine);
    wasmtime_wasi::add_to_linker_async(&mut linker)?;

    let mut store = Store::new(&engine, state);

    let (plugin, _) = MyPlugin::instantiate_async(&mut store, &component, &linker).await?;
    let result = plugin.call_process(&mut store, "data").await?;
    Ok(())
}
```

### Epoch-Based Async Cancellation

```rust
let engine = Engine::new(&config)?;

// Background thread increments epoch every 100ms
let engine_clone = engine.clone();
tokio::spawn(async move {
    loop {
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
        engine_clone.increment_epoch();
    }
});

let mut store = Store::new(&engine, state);
store.set_epoch_deadline(10);  // 10 ticks = ~1 second
store.epoch_deadline_async_yield_and_update(10);  // yield to async runtime on deadline
```

## Plugin System Patterns

### Dynamic Plugin Loading

```rust
use std::path::Path;
use wasmtime::component::*;

struct PluginManager {
    engine: Engine,
    linker: Linker<PluginState>,
}

impl PluginManager {
    fn new() -> anyhow::Result<Self> {
        let mut config = Config::new();
        config.wasm_component_model(true);

        let engine = Engine::new(&config)?;
        let mut linker = Linker::new(&engine);

        wasmtime_wasi::add_to_linker_sync(&mut linker)?;

        Ok(Self { engine, linker })
    }

    fn load_plugin(&self, path: &Path) -> anyhow::Result<LoadedPlugin> {
        let component = Component::from_file(&self.engine, path)?;
        let state = PluginState::new();
        let mut store = Store::new(&self.engine, state);

        let (instance, _) = MyPlugin::instantiate(&mut store, &component, &self.linker)?;

        Ok(LoadedPlugin { store, instance })
    }
}
```

### Pre-Compilation Cache

```rust
use std::collections::HashMap;
use std::path::PathBuf;

struct PluginCache {
    engine: Engine,
    compiled: HashMap<PathBuf, Vec<u8>>,
}

impl PluginCache {
    fn get_or_compile(&mut self, path: &PathBuf) -> anyhow::Result<Component> {
        if let Some(bytes) = self.compiled.get(path) {
            return unsafe { Component::deserialize(&self.engine, bytes) };
        }

        let wasm = std::fs::read(path)?;
        let compiled = self.engine.precompile_component(&wasm)?;
        self.compiled.insert(path.clone(), compiled.clone());

        unsafe { Component::deserialize(&self.engine, &compiled) }
    }
}
```

### Sandboxed Execution with Resource Limits

```rust
fn run_untrusted(wasm_bytes: &[u8]) -> anyhow::Result<String> {
    let mut config = Config::new();
    config.wasm_component_model(true);
    config.consume_fuel(true);
    config.epoch_interruption(true);

    let engine = Engine::new(&config)?;
    let component = Component::new(&engine, wasm_bytes)?;

    let mut linker = Linker::new(&engine);
    wasmtime_wasi::add_to_linker_sync(&mut linker)?;

    let wasi = WasiCtxBuilder::new()
        // No stdio, no env, no filesystem, no network
        .build();

    let state = SandboxState {
        wasi,
        table: ResourceTable::new(),
    };
    let mut store = Store::new(&engine, state);

    // Limit fuel (execution steps)
    store.set_fuel(1_000_000)?;

    // Limit memory
    store.limiter(|_| &mut StoreLimitsBuilder::new()
        .memory_size(10 * 65536)  // 640KB
        .instances(1)
        .build());

    let (plugin, _) = MyPlugin::instantiate(&mut store, &component, &linker)?;
    let result = plugin.call_process(&mut store, "input")?;
    result.map_err(|e| anyhow::anyhow!(e))
}
```

## Error Handling

### Trap Handling

```rust
use wasmtime::Trap;

match func.call(&mut store, ()) {
    Ok(result) => println!("Success: {result:?}"),
    Err(e) => {
        if let Some(trap) = e.downcast_ref::<Trap>() {
            match trap {
                Trap::StackOverflow => eprintln!("Stack overflow in wasm"),
                Trap::MemoryOutOfBounds => eprintln!("Out of bounds memory access"),
                Trap::UnreachableCodeReached => eprintln!("Hit unreachable instruction"),
                Trap::OutOfFuel => eprintln!("Fuel exhausted"),
                _ => eprintln!("Trap: {trap}"),
            }
        } else {
            eprintln!("Error: {e}");
        }
    }
}
```

### Backtraces

```rust
let mut config = Config::new();
config.wasm_backtrace_details(WasmBacktraceDetails::Enable);

// Errors will now include wasm stack traces
// Requires debug info in the wasm module
```

## Multi-Module Linking

Link multiple core modules together:

```rust
let mut linker = Linker::new(&engine);

// First module provides exports
let module_a = Module::from_file(&engine, "logger.wasm")?;
let instance_a = linker.instantiate(&mut store, &module_a)?;
linker.instance(&mut store, "logger", instance_a)?;

// Second module imports from first
let module_b = Module::from_file(&engine, "app.wasm")?;
let instance_b = linker.instantiate(&mut store, &module_b)?;
```

## Performance Tips

| Technique | When to Use |
|-----------|-------------|
| AOT compilation | Production deployments, fast startup |
| Pooling allocator | High-throughput, many short-lived instances |
| `cranelift_opt_level(Speed)` | CPU-bound workloads |
| Module caching | Same module loaded multiple times |
| Fuel over epochs | Fine-grained metering needed |
| Epochs over fuel | Low-overhead periodic checks |
| `Component::deserialize` | Cached pre-compiled components |
