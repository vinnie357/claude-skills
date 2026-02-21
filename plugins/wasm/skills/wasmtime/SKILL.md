---
name: wasmtime
description: Guide for WebAssembly development with Wasmtime runtime. Use when compiling Rust or Zig to wasm, embedding Wasmtime in Rust or Elixir hosts, working with WASI, or using the Component Model.
license: MIT
---

# Wasmtime Development

Wasmtime is a standalone, fast, secure WebAssembly runtime from the Bytecode Alliance. It implements the WebAssembly standard and extensions including WASI (WebAssembly System Interface) and the Component Model.

## When to Use This Skill

Activate when:
- Compiling Rust or Zig code to WebAssembly targets
- Embedding a WebAssembly runtime in Rust or Elixir applications
- Working with WASI for system interface access
- Using the Component Model and WIT interfaces
- Building plugin systems with WebAssembly sandboxing
- Optimizing wasm module size or runtime performance

## Core Concepts

| Concept | Purpose |
|---------|---------|
| Engine | Shared compilation environment and configuration |
| Store | Per-instance state container (fuel, epoch, host data) |
| Module | Compiled `.wasm` binary (core module) |
| Component | Compiled component with typed interfaces (WIT-based) |
| Instance | Runtime instantiation of a module or component |
| Linker | Resolves imports by name, defines host functions |
| WIT | WebAssembly Interface Type language for component contracts |

## Supported Languages

### Guest Languages (compile TO wasm)

| Language | Target | Tooling | Reference |
|----------|--------|---------|-----------|
| Rust | `wasm32-wasip1`, `wasm32-wasip2`, `wasm32-unknown-unknown` | `cargo-component`, `wit-bindgen` | [guest-rust.md](references/guest-rust.md) |
| Zig | `wasm32-wasi`, `wasm32-freestanding` | `zig build`, `build.zig` | [guest-zig.md](references/guest-zig.md) |

### Host Languages (embed wasmtime IN)

| Language | Crate/Package | Async Support | Reference |
|----------|---------------|---------------|-----------|
| Rust | `wasmtime` crate | Yes (tokio) | [host-rust.md](references/host-rust.md) |
| Elixir | `wasmex` hex package | Via GenServer | [host-elixir.md](references/host-elixir.md) |

## WASI Versions

| Version | Status | Key Differences |
|---------|--------|-----------------|
| WASIp1 (Preview 1) | Stable, widely supported | POSIX-like, `fd_*` functions, linear memory I/O |
| WASIp2 (Preview 2) | Current standard | Component Model-based, typed streams, async-ready |

Use WASIp2 for new projects. WASIp1 remains supported for existing code. See [overview.md](references/overview.md) for migration details.

## Reference Index

| Reference | Contents |
|-----------|----------|
| [overview.md](references/overview.md) | Installation, core concepts detail, Component Model, WIT syntax, WASI deep dive, resource limits, AOT compilation, debugging |
| [guest-rust.md](references/guest-rust.md) | Rust wasm targets, cargo-component, wit-bindgen, binary size optimization, testing strategies |
| [guest-zig.md](references/guest-zig.md) | Zig wasm targets, build.zig configuration, allocator patterns, WASI imports, exports |
| [host-rust.md](references/host-rust.md) | Wasmtime Rust API, WASI context setup, Component Model bindgen!, async support, plugin system patterns |
| [host-elixir.md](references/host-elixir.md) | Wasmex API, GenServer integration, memory access, host callbacks, supervision patterns |

## Common Pitfalls

- **Wrong target triple**: Use `wasm32-wasip2` for Component Model, `wasm32-wasip1` for legacy WASI, `wasm32-unknown-unknown` for bare modules
- **Missing WASI context**: Host must add WASI to the linker before instantiating WASI-dependent modules
- **Store lifetime**: Each `Store` owns instance state — do not share stores across threads without synchronization
- **Fuel exhaustion**: Enable fuel metering for untrusted code and handle `OutOfFuel` traps
- **Component vs Module**: Components use WIT-typed interfaces; core modules use raw numeric imports/exports — do not mix APIs
- **Linear memory bounds**: Always validate pointer+length pairs when passing data through linear memory
