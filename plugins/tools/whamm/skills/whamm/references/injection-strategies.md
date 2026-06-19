# whamm Injection Strategies

whamm! supports two injection strategies. The choice determines the CLI flags, runtime requirements, and behavioral guarantees.

---

## Strategy 1: Bytecode Rewriting

whamm reads the target `.wasm` binary into an AST (using the `wirm` Rust library), locates probe sites, injects the compiled probe logic inline, and writes a new `.wasm` output file. The target module is permanently modified.

**Compile time:**
```bash
whamm instr --app app.wasm --script monitor.mm -o out.wasm
```

**Run time:**
```bash
wasmtime run --env TO_CONSOLE=true --preload whamm_core=whamm_core.wasm out.wasm
```

---

## Strategy 2: Engine Support (wei)

whamm compiles the `.mm` script into a generic monitor module (a `.wasm` file) without referencing any target binary. The Wizard engine loads the monitor alongside the target at runtime and attaches the probes dynamically.

**Compile time:**
```bash
whamm instr --script monitor.mm --wei -o monitor.wasm
```

**Run time:**
```bash
wizeng --env=TO_CONSOLE=true --monitors=monitor.wasm+whamm_core.wasm app.wasm
```

---

## Comparison

| Property | Bytecode Rewriting | Engine Support (wei) |
|----------|-------------------|----------------------|
| `--app` required at compile time | Yes | No |
| Target `.wasm` modified | Yes (intrusive) | No (non-intrusive) |
| Runtime compatibility | Any runtime (wasmtime, wasmer, node, etc.) | Wizard engine only |
| Attach timing | Compile time (static) | Runtime (dynamic) |
| JIT optimization of probes | No | Yes (Wizard can JIT probes) |
| `@static` library state persists across calls | No (rewriting resets module state) | Yes |
| `whamm_core.wasm` needed at runtime | Yes (`--preload`) | Yes (`--monitors`) |
| Use case | Broad runtime compatibility, one-shot analysis | Low-overhead production monitoring, stateful probes |

---

## Selecting a strategy

Use **bytecode rewriting** when:
- The target runtime is not Wizard (wasmtime, wasmer, Node.js WASI, Deno, etc.)
- You need a self-contained instrumented binary to distribute or archive
- Probe persistence across module instantiation is not required

Use **engine support (wei)** when:
- The Wizard engine is available
- Probes must not modify the original binary (auditing, production tracing)
- You need `@static` state that survives across probe invocations
- JIT-optimized probe execution matters for low overhead at high call frequency
