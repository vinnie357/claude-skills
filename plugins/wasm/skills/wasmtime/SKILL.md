---
name: wasmtime
description: Guide for WebAssembly development with Wasmtime runtime. Use when compiling Rust or Zig to wasm, embedding Wasmtime in Rust or Elixir hosts, working with WASI, or using the Component Model.
license: MIT
---

# Wasmtime Development

Wasmtime is a standalone, fast, secure WebAssembly runtime from the Bytecode Alliance. It implements the WebAssembly standard and extensions including WASI (WebAssembly System Interface) and the Component Model.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Wasmtime ships major-version bumps roughly
monthly, so pinned versions and API paths are high-risk. Verified against wasmtime
47.0.3 (crates.io, claude-skills-204): the host/guest Rust examples were pinned to a
stale "29" and used the pre-reorg `wasmtime_wasi` API — corrected to the `p1::`/`p2::`
submodule layout confirmed against docs.rs/wasmtime-wasi/latest, and `WasiView::ctx()`
was corrected to return a single `WasiCtxView<'_>` rather than separate `ctx()`/`table()`
methods. WASI 0.3.0 native-async coverage (stream/future in the Component Model,
requires Wasmtime 46+) was added, confirmed against wasi.dev and bytecodealliance.org.
Re-verify against `docs.rs/wasmtime/latest` before asserting an API this skill doesn't
cover — this crate changes fast enough that a stale example compiles against nothing.

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

Authoring WIT interface files continues in `/wasm:wit`.

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
| WASIp2 (Preview 2) | Stable, Component Model baseline | Typed interfaces, synchronous streams |
| WASIp3 (0.3) | Announced stable 2026-06-11 (bytecodealliance.org/articles/WASI-0.3, read 2026-08-04) | Native async — `stream<T>`/`future<T>`/`async` as first-class canonical-ABI constructs; Wasmtime 46 ships it with Component Model Async on by default |

Use WASIp2 for broad compatibility, WASIp3 for new components that need native async and target Wasmtime 46+. WASIp1 remains supported for existing code. See [overview.md](references/overview.md) for migration details.

## Reference Index

| Reference | Contents |
|-----------|----------|
| [overview.md](references/overview.md) | Installation, core concepts detail, Component Model, WIT syntax, WASI deep dive, resource limits, AOT compilation, debugging |
| [guest-rust.md](references/guest-rust.md) | Rust wasm targets, cargo-component, wit-bindgen, binary size optimization, testing strategies |
| [guest-zig.md](references/guest-zig.md) | Zig wasm targets, build.zig configuration, allocator patterns, WASI imports, exports |
| [host-rust.md](references/host-rust.md) | Wasmtime Rust API, WASI context setup, Component Model bindgen!, async support, plugin system patterns |
| [host-elixir.md](references/host-elixir.md) | Wasmex API, GenServer integration, memory access, host callbacks, supervision patterns |

## WebAssembly instrumentation (whamm)

whamm! instruments compiled `.wasm` modules by inserting probes through bytecode rewriting, using a DTrace-inspired `.mm` DSL for profiling, opcode counting, cache simulation, and call graph analysis. Run instrumented modules on wasmtime by preloading the whamm core library: `wasmtime run --env TO_CONSOLE=true --preload whamm_core=whamm_core.wasm out.wasm`. For CLI installation (mise github backend), the `.mm` language, and instrumentation strategies, see the `whamm` and `whamm-dsl` skills in the whamm plugin (`/plugin install whamm@vinnie357`).

## Common Pitfalls

- **Wrong target triple**: Use `wasm32-wasip2` for Component Model, `wasm32-wasip1` for legacy WASI, `wasm32-unknown-unknown` for bare modules
- **Missing WASI context**: Host must add WASI to the linker before instantiating WASI-dependent modules
- **Store lifetime**: Each `Store` owns instance state — do not share stores across threads without synchronization
- **Fuel exhaustion**: Enable fuel metering for untrusted code and handle `OutOfFuel` traps
- **Component vs Module**: Components use WIT-typed interfaces; core modules use raw numeric imports/exports — do not mix APIs
- **Linear memory bounds**: Always validate pointer+length pairs when passing data through linear memory
