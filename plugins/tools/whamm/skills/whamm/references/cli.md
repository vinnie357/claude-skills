# whamm CLI Reference

## Global flags

```bash
whamm --help          # Print help and exit
```

Set `RUST_LOG` in the environment to control log verbosity:

| Value   | Effect |
|---------|--------|
| `error` | Errors only |
| `warn`  | Warnings and errors |
| `info`  | Informational messages (default) |
| `debug` | Detailed debug output |
| `trace` | Full trace (very verbose) |
| `off`   | Suppress all log output |

```bash
RUST_LOG=debug whamm instr --app app.wasm --script monitor.mm -o out.wasm
```

---

## whamm instr

Instruments a WebAssembly module using a `.mm` monitor script.

### Bytecode-rewriting path

```bash
whamm instr --app app.wasm --script monitor.mm -o out.wasm
```

| Flag | Required | Description |
|------|----------|-------------|
| `--app <path>` | Yes (rewriting) | Path to the input `.wasm` binary |
| `--script <path>` | Yes | Path to the `.mm` monitor script |
| `-o <path>` | Yes | Output path for the instrumented `.wasm` |

The rewriting path embeds probe logic directly into the module's bytecode using the `wirm` Rust library. The output `.wasm` runs on any WebAssembly runtime that can preload `whamm_core.wasm`.

### Engine-support (wei) path

```bash
whamm instr --script monitor.mm --wei -o monitor.wasm
```

| Flag | Required | Description |
|------|----------|-------------|
| `--script <path>` | Yes | Path to the `.mm` monitor script |
| `--wei` | Yes | Compile for engine support (Wizard Engine Interface) |
| `-o <path>` | Yes | Output path for the compiled monitor module |
| `--app` | No | Omit — the engine attaches probes at runtime |

The `--wei` flag compiles the `.mm` script into a generic monitor `.wasm` module. No target binary is specified at compile time; the engine attaches probes when loading the monitor module alongside the target.

---

## whamm info

Inspects available bound variables for a given event match rule.

```bash
whamm info --rule "wasm:opcode:call:before"
```

| Flag | Description |
|------|-------------|
| `--rule <rule>` | Event match rule to inspect (e.g. `"wasm:opcode:call:before"`) |
| `-fv` | (optional) Full verbose output |

Example with verbose flag:

```bash
whamm info -fv --rule "wasm:opcode:i32.load:before"
```

Prints the variables bound at the given probe site — names, types, and whether they are mutable. Use this to discover what data is available in a probe body before writing the `.mm` script.

---

## Running instrumented modules

### Bytecode-rewriting path (wasmtime)

The rewriting path requires `whamm_core.wasm` preloaded as a named module:

```bash
wasmtime run \
  --env TO_CONSOLE=true \
  --preload whamm_core=whamm_core.wasm \
  out.wasm
```

- `--env TO_CONSOLE=true` — directs whamm_core to print probe output to stdout
- `--preload whamm_core=whamm_core.wasm` — loads `whamm_core.wasm` as the `whamm_core` import namespace

`whamm_core.wasm` must be built from source — it is not included in the prebuilt release binary. The `installation` reference covers the build step (`whamm:build-from-source`).

### Engine-support path (Wizard engine)

```bash
wizeng \
  --env=TO_CONSOLE=true \
  --monitors=monitor.wasm+whamm_core.wasm \
  app.wasm
```

- `--monitors` — comma- or plus-separated list of monitor modules to attach
- `app.wasm` — the unmodified target binary

The Wizard engine attaches the probes at runtime; `app.wasm` is never rewritten.
