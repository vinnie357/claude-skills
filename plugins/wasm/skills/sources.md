# Wasm Plugin Sources

This file documents the sources used to create the wasm plugin skills.

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
- **Key Topics**: WASIp1, WASIp2, system interface design, capability-based security

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

## Plugin Information

- **Name**: wasm
- **Version**: 0.1.3
- **Description**: WebAssembly skills: wasmtime runtime, component model, guest compilation, and host embedding
- **Skills**: 2 skills (wasmtime, wit)
- **Created**: 2026-02-21
