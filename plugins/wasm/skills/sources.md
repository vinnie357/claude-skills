# Wasm Plugin Sources

This file documents the sources used to create the wasm plugin skills.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there. Entries: `wasmtime`, `bytecodealliance`, `component-model`, `wasi`, `cargo-component`, `wit-bindgen`, `wasm-tools`, `wasmex`, `zig-wasm-docs`, `rustwasm` (the Wasmtime Skill section below), `wit-language-reference`, `wit-worlds-spec` (the WIT Skill section below, alongside `component-model` above).

## Update History

### 2026-08-04 — claude-skills-204 content-verification pass

Claim-by-claim verification of `wasmtime` and `wit` skill content against live upstream sources (not the earlier presence-only `sources.toml` freshness pass from 2026-07-30).

**What a `verified against X` stamp on a Rust sample means here.** The named
API path, symbol, or signature was read on docs.rs at the pinned crate version
on the stated date, and the sample's use of it matches that signature. It does
**not** mean the enclosing snippet was compiled — there is no Rust toolchain or
wasmtime checkout in this repo's CI, so no sample in `references/*.md` is
compile-tested. Treat a stamp as "the API exists and is called with the right
shape", not as "this builds". (The zig plugin's stamps are stronger: those
snippets are compiled against a local 0.16.0 toolchain — see
`plugins/languages/zig/skills/sources.md`.)

Findings:

- **wasmtime crate version pins were stale**: `host-rust.md` pinned `wasmtime = "29"` / `wasmtime-wasi = "29"`; live crates.io check shows 47.0.3. Corrected in `host-rust.md`.
- **wit-bindgen version pins were stale**: `guest-rust.md` and `host-rust.md` pinned `wit-bindgen = "0.36"`; live crates.io check shows 0.60.0. Corrected in both files.
- **wasmex version pin was stale**: `host-elixir.md` pinned `{:wasmex, "~> 0.9"}`; live hex.pm check confirms the current release is 0.14.0. Corrected to `~> 0.14` so the example pins what the skill was actually checked against. (`~> 0.9` was loose, not broken: per elixir.hexdocs.pm/Version.html, `~> 2.0` means `>= 2.0.0 and < 3.0.0`, so `~> 0.9` means `>= 0.9.0 and < 1.0.0` and does admit 0.14.0. An earlier draft of this entry claimed it excluded 0.14.0 — that was wrong and is retracted.)
- **wasmtime-wasi API surface had moved**: read on docs.rs at 47.0.3. The `preview1` module was renamed to `p1`; `add_to_linker_sync`/`add_to_linker_async` moved from the crate root into `p1::`/`p2::` submodules; `WasiView` is now `pub trait WasiView: Send { fn ctx(&mut self) -> WasiCtxView<'_>; }`, replacing the separate `ctx()`/`table()` methods, with `WasiCtxView<'a> { pub ctx: &'a mut WasiCtx, pub table: &'a mut ResourceTable }` (not `#[non_exhaustive]`, so the struct literal in `host-rust.md` is valid). `WasiCtx`, `WasiCtxBuilder`, `WasiCtxView`, `DirPerms`, `FilePerms` are all crate-root re-exports; `WasiCtxBuilder::build(&mut self) -> WasiCtx` and `build_p1(&mut self) -> WasiP1Ctx`. Corrected across `host-rust.md`, `guest-rust.md`, and `overview.md`.
- **`p2::add_to_linker_sync` was called on a core-module linker**: `overview.md`'s Linker section builds a `wasmtime::Linker` (`func_wrap`, `Module`, `linker.instantiate`), but the WASI line called `p2::add_to_linker_sync`, whose signature is `add_to_linker_sync<T: WasiView>(linker: &mut wasmtime::component::Linker<T>)` — a type error. This defect was *introduced* by the first draft of this pass, which edited that line and stamped it verified. Rewritten as a genuine WASIp1 core-module example using `p1::add_to_linker_sync<T: Send + 'static>(linker: &mut Linker<T>, f: impl Fn(&mut T) -> &mut WasiP1Ctx + Copy + Send + Sync + 'static)`, with the p2 signature quoted alongside so the mismatch is explicit.
- **Glob-import ambiguity in `host-rust.md`**: two samples carried both `use wasmtime::*;` and `use wasmtime::component::*;`. `Linker` exists in both modules, so a bare `Linker` is ambiguous (E0659). Replaced with explicit imports in the WASIp2 sample and dropped the redundant `use wasmtime::*;` from the `bindgen!` sample. Pre-existing, but three of the affected samples had just been stamped verified.
- **Unused/missing imports in `overview.md` WASI samples**: the WASIp1 sample imported `p1` without using it and used `DirPerms`/`FilePerms` without importing them; the WASIp2 sample imported `WasiCtx`/`WasiView` without using them and likewise lacked `DirPerms`/`FilePerms`. Both import lists corrected. `wasmtime_wasi::p1::wasi_snapshot_preview1` was confirmed to exist as a real module on docs.rs.
- **WASI version guidance was incomplete, not wrong**: WASI 0.3 was announced stable on 2026-06-11 (verified against bytecodealliance.org/articles/WASI-0.3, which states "Wasmtime 45 runs the latest release candidate today, and Wasmtime 46 will ship WASI 0.3.0 with Component Model Async enabled by default"), adding `stream<T>`, `future<T>`, and `async` as first-class canonical-ABI constructs on top of the 0.2.0 baseline. Corroborated by the presence of a `p3` module at the `wasmtime-wasi` 47.0.3 crate root. Added a WASIp3 row to `wasmtime/SKILL.md`'s WASI Versions table and updated `wit/SKILL.md`'s WASI-pinning pitfall.
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
