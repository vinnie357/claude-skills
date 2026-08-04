# Wasm Plugin Sources

This file documents the sources used to create the wasm plugin skills.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there. Entries: `wasmtime`, `bytecodealliance`, `component-model`, `wasi`, `cargo-component`, `wit-bindgen`, `wasm-tools`, `wasmex`, `zig-wasm-docs`, `rustwasm` (the Wasmtime Skill section below), `wit-language-reference`, `wit-worlds-spec` (the WIT Skill section below, alongside `component-model` above).

## Update History

### 2026-08-04 — claude-skills-204 content-verification pass

Claim-by-claim verification of `wasmtime` and `wit` skill content against live upstream sources (not the earlier presence-only `sources.toml` freshness pass from 2026-07-30). Findings:

- **wasmtime crate version pins were stale**: `host-rust.md` pinned `wasmtime = "29"` / `wasmtime-wasi = "29"`; live crates.io check shows 47.0.3. Corrected in `host-rust.md`.
- **wit-bindgen version pins were stale**: `guest-rust.md` and `host-rust.md` pinned `wit-bindgen = "0.36"`; live crates.io check shows 0.60.0. Corrected in both files.
- **wasmex version pin was stale**: `host-elixir.md` pinned `{:wasmex, "~> 0.9"}`, which excludes the current 0.14.0 release under hex's pessimistic-operator semantics; live hex.pm check confirms 0.14.0. Corrected to `~> 0.14`.
- **wasmtime-wasi API surface had moved**: verified against docs.rs/wasmtime-wasi/latest and docs.wasmtime.dev's WASIp1/WASIp2 example pages. The `preview1` module was renamed to `p1`; `add_to_linker_sync`/`add_to_linker_async` moved from the crate root into `p1::`/`p2::` submodules; `WasiView::ctx()` now returns a single `WasiCtxView<'_>` instead of separate `ctx()`/`table()` methods. All corrected across `host-rust.md`, `guest-rust.md`, and `overview.md`.
- **WASI version guidance was incomplete, not wrong**: WASI 0.3.0 shipped stable on 2026-06-11 (verified against wasi.dev and bytecodealliance.org/articles/WASI-0.3), adding native async (`stream<T>`/`future<T>`) on top of the 0.2.0 baseline the skills already documented. Added a WASIp3 row to `wasmtime/SKILL.md`'s WASI Versions table and updated `wit/SKILL.md`'s WASI-pinning pitfall.
- **WIT syntax content re-verified, no drift found**: `wit/SKILL.md`, `wit/references/syntax-reference.md`, and `wasmtime/references/overview.md`'s WIT sections were checked against component-model.bytecodealliance.org/design/wit.html live — package/interface/world/record/variant/enum/flags/resource/use syntax all still matches.
- Zig skills (`allocators`, `build`, `c-interop`, `language`, `testing`, `troubleshooting`, `zig`) are tracked in the separate `zig` plugin — see `plugins/languages/zig/skills/sources.md`.

## Wasmtime Skill

### Wasmtime Documentation
- **URL**: https://docs.wasmtime.dev/
- **Purpose**: Official Wasmtime runtime documentation
- **Key Topics**: Engine, Store, Module, Instance, Linker, WASI, Component Model, resource limits, AOT compilation

### Wasmtime API Reference (Rust)
- **URL**: https://docs.rs/wasmtime/latest/wasmtime/
- **Purpose**: Rust API reference for the wasmtime crate
- **Key Topics**: Embedding API, host functions, memory access, async support, typed function calls

### Bytecode Alliance
- **URL**: https://bytecodealliance.org/
- **Purpose**: Organization behind Wasmtime, WASI, and the Component Model
- **Key Topics**: WebAssembly standards, runtime implementations, community governance

### Component Model Documentation
- **URL**: https://component-model.bytecodealliance.org/
- **Purpose**: Component Model specification and guides
- **Key Topics**: WIT syntax, worlds, interfaces, composition, canonical ABI

### WASI Specification
- **URL**: https://wasi.dev/
- **Purpose**: WebAssembly System Interface specification
- **Key Topics**: WASIp1, WASIp2, WASIp3 (native async, stable since 2026-06-11), system interface design, capability-based security

### cargo-component
- **URL**: https://github.com/bytecodealliance/cargo-component
- **Purpose**: Cargo subcommand for building WebAssembly components from Rust
- **Key Topics**: Component builds, WIT integration, dependency management

### wit-bindgen
- **URL**: https://github.com/bytecodealliance/wit-bindgen
- **Purpose**: Language binding generator for WIT interfaces
- **Key Topics**: Rust bindings, guest code generation, type mapping

### wasm-tools
- **URL**: https://github.com/bytecodealliance/wasm-tools
- **Purpose**: CLI and Rust libraries for wasm manipulation
- **Key Topics**: Validation, composition, printing, component creation

### Wasmex (Elixir)
- **URL**: https://hexdocs.pm/wasmex/
- **Purpose**: Elixir wrapper around Wasmtime via Rust NIFs
- **Key Topics**: Module compilation, instance management, memory access, host callbacks, WASI support

### Wasmex GitHub Repository
- **URL**: https://github.com/tessi/wasmex
- **Purpose**: Source code and examples for the Wasmex library
- **Key Topics**: NIF implementation, store configuration, fuel metering

### Zig WebAssembly Documentation
- **URL**: https://ziglang.org/documentation/master/
- **Purpose**: Official Zig language documentation
- **Key Topics**: Wasm targets, build system, allocators, extern functions

### Zig WASI Guide
- **URL**: https://ziglang.org/documentation/master/#toc-WebAssembly-System-Interface-WASI
- **Purpose**: Zig's WASI target documentation
- **Key Topics**: wasm32-wasi target, std library WASI support, build configuration

### Rust Wasm Working Group
- **URL**: https://rustwasm.github.io/docs/book/
- **Purpose**: Rust and WebAssembly integration guide
- **Key Topics**: Wasm targets, wasm-pack, binary size optimization, debugging

## WIT Skill

### WIT Language Reference (Component Model)
- **URL**: https://component-model.bytecodealliance.org/design/wit.html
- **Purpose**: WIT syntax specification, type system, interfaces, and worlds
- **Date Accessed**: 2026-03-25
- **Key Topics**: Package naming, interfaces, worlds, type system (primitives, lists, options, results, records, variants, enums, flags, tuples), functions, resources

### Component Model Worlds
- **URL**: https://component-model.bytecodealliance.org/design/worlds.html
- **Purpose**: World definition patterns and component composition
- **Date Accessed**: 2026-03-25
- **Key Topics**: Import and export declarations, world includes, component targets

### Component Model Overview
- **URL**: https://component-model.bytecodealliance.org/
- **Purpose**: High-level overview of the WebAssembly Component Model
- **Date Accessed**: 2026-03-25
- **Key Topics**: Component architecture, interface-based composition, canonical ABI
