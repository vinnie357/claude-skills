---
name: whamm
description: Install and operate whamm!, the WebAssembly bytecode instrumentation tool. Use when instrumenting or profiling a .wasm binary, counting opcodes or function calls, choosing between bytecode-rewriting and engine-support (wei) injection strategies, or running an instrumented module with wasmtime or Wizard.
license: MIT
---

# whamm — WebAssembly Instrumentation Tool

Entry point for installing, configuring, and running whamm! (v0.1.0). whamm! instruments compiled `.wasm` binaries using a DTrace-inspired `.mm` monitor script; no source changes to the target application are required.

For the `.mm` language itself — probe syntax, events, libraries, and examples — load the companion **whamm-dsl** skill in this plugin.

## When to Use This Skill

Activate when:
- Instrumenting or profiling a `.wasm` binary without modifying source
- Counting opcodes, tracking function calls, or measuring memory access patterns in a WebAssembly module
- Installing whamm via `mise` or building from source
- Choosing between bytecode-rewriting and wei (engine-support) injection strategies
- Running an instrumented module with `wasmtime` (rewriting path) or Wizard engine (wei path)

## Install (mise github backend)

Copy the stanzas from `templates/mise.toml` into your project's `mise.toml`. Full explanation of asset patterns, Rosetta caveat, and build-from-source steps lives in `references/installation.md`.

```toml
[tools."github:ejrgilbert/whamm"]
version = "0.1.0"

[tools."github:ejrgilbert/whamm".platforms]
linux-x64   = { asset_pattern = "whamm-linux-x86_64" }
macos-x64   = { asset_pattern = "whamm-macos-x86_64" }
macos-arm64 = { asset_pattern = "whamm-macos-x86_64" }  # Rosetta 2
```

Verify the install:

```bash
mise install
whamm --help
```

v0.1.0 ships bare binaries for `x86_64` only. On Apple Silicon without Rosetta 2, build from source — see `references/installation.md`.

## CLI quickstart

Full flag reference lives in `references/cli.md`. Core commands:

```bash
# Instrument: bytecode-rewriting path
whamm instr --app app.wasm --script monitor.mm -o out.wasm

# Compile monitor for engine-support (wei) path — no --app
whamm instr --script monitor.mm --wei -o monitor.wasm

# Inspect bound variables available at a match rule
whamm info --rule "wasm:opcode:call:before"

# Global help
whamm --help
```

Set `RUST_LOG={error|warn|info|debug|trace|off}` to control verbosity.

## End-to-end workflow (bytecode-rewriting path)

1. Write a `.mm` monitor script (see `whamm-dsl` skill).
2. Instrument the target module:
   ```bash
   whamm instr --app app.wasm --script monitor.mm -o out.wasm
   ```
3. Run the instrumented module. The rewriting path requires `whamm_core.wasm` preloaded at runtime:
   ```bash
   wasmtime run \
     --env TO_CONSOLE=true \
     --preload whamm_core=whamm_core.wasm \
     out.wasm
   ```

`whamm_core.wasm` is NOT included in the prebuilt release binary. Build it from source — see `references/installation.md`.

## End-to-end workflow (wei / Wizard engine path)

1. Compile the monitor without `--app`:
   ```bash
   whamm instr --script monitor.mm --wei -o monitor.wasm
   ```
2. Run with Wizard engine:
   ```bash
   wizeng \
     --env=TO_CONSOLE=true \
     --monitors=monitor.wasm+whamm_core.wasm \
     app.wasm
   ```

The Wizard engine attaches probes at runtime; the target `.wasm` is not modified.

## Injection strategies

Two strategies exist: **bytecode rewriting** (any runtime, `--app` required at instr time, intrusive) and **engine support via `--wei`** (Wizard engine only, non-intrusive, supports JIT optimization and persistent `@static` state). A full comparison table covering intrusiveness, runtime compatibility, JIT optimization, and `@static` state behavior lives in `references/injection-strategies.md`.

## The .mm language

Load the **whamm-dsl** skill in this plugin for probe syntax, event matching, built-in variables, library functions, and annotated `.mm` examples. This skill (whamm) covers the tool only.

## Verification

Treat `whamm info --rule "<match-rule>"` as the authoritative source for the bound variables available at a probe site, and confirm probe output against an actual instrumented run. This follows `/core:anti-fabrication` — verify behavior with the tool at the installed version, do not infer it.

## References

- `templates/mise.toml` — mise stanzas with platform asset patterns and task definitions
- `references/installation.md` — mise github backend explained, build-from-source steps, whamm_core.wasm, verification
- `references/cli.md` — all flags for `whamm instr`, `whamm info`, RUST_LOG, both run paths
- `references/injection-strategies.md` — strategy comparison table and selection guide
