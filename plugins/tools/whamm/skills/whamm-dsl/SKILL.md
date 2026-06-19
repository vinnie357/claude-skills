---
name: whamm-dsl
description: Guide for the whamm! `.mm` monitor DSL — the DTrace-inspired language for WebAssembly instrumentation. Use when writing or reading `.mm` scripts, composing match rules, choosing variable kinds, writing predicates, or understanding bound variables at a probe site.
license: MIT
---

# whamm-dsl — The `.mm` Monitor Language

A `.mm` script is the instrumentation program whamm! injects into a WebAssembly binary (or compiles for engine-support). Each script contains global declarations followed by one or more **probes**. whamm! statically analyses match rules to decide which probes apply at each site, folding away constant guards before injection.

For installing whamm! and running instrumented modules, load the companion **whamm** skill in this plugin.

## When to Use This Skill

Activate when:
- Writing `.mm` monitor scripts to instrument WebAssembly binaries
- Reading or debugging existing `.mm` files
- Choosing the right match rule, mode, or predicate for a probe
- Selecting between `var`, `unshared var`, `report var`, and `frame var`
- Understanding which bound variables are available at a given probe site
- Using libraries (`use whamm_core;`) or the `@static`/`@init` call modifiers
- Looking up type syntax (tuples, maps, strings, type bounds)

## Script structure

A `.mm` file contains, in order:

1. **`use` declarations** — `use lib;` imports a named library.
2. **Global variable declarations** — `report var`, `var`, etc. declared at file scope.
3. **Function definitions** — `name(args) -> ret { .. }` (NOT YET IMPLEMENTED).
4. **Probes** — one or more match-rule blocks, each optionally gated by a predicate.

## Match rules

```
provider:package:event:mode / predicate / { actions }
```

The predicate is optional. Without it: `provider:package:event:mode { actions }`.

**Hierarchy:** `wasm` (provider) → package → event → mode.

| Package | Events | Modes |
|---------|--------|-------|
| `opcode` | any opcode name or glob | `before`, `after`, `alt` |
| `func` | _(any function)_ | `entry`, `exit` (`unwind` planned) |
| `block` | `end` | _(none)_ |
| _(none)_ | `begin`, `end`, `report` | _(none — top-level probes)_ |

**Globbing examples:**

```
wasm:opcode:*:before              # all opcodes, before
wasm::*if:before                  # if + br_if (empty package = wildcard)
wasm:opcode:*load*|*store*:before # all memory loads and stores
wasm:opcode:call|return_call:before
```

**Type bounds** narrow polymorphic args: `wasm:opcode:call(arg0: i32):before` matches only call sites where `arg0` is i32.

Full event and bound-variable tables: see [`references/events.md`](references/events.md).

## Predicated probes & modes

```mm
wasm:opcode:call:before / pc == 25 && arg0 == 1 / {
    count++;
}
```

whamm! performs **constant folding** on static vars (`pc`, `fid`, `imm0`, …). At a site where `pc != 25`, the probe is not injected at all. At `pc == 25` the dynamic guard `arg0 == 1` is emitted inline.

**Modes:**
- `before` — inject before the opcode executes.
- `after` — inject after; result vars `res0`, `res1`, … hold the opcode's outputs.
- `alt` — replace the opcode; call `drop_args()` to discard its input args.
- `entry` / `exit` — inject at function entry or exit.

## Variables

| Kind | Declared as | Lifetime | Typical use |
|------|-------------|----------|-------------|
| `var` | `var x: T;` or `var x: T = v;` | Reinitialised on each probe invocation | Temporaries |
| `unshared var` | `unshared var x: T;` | One instance per match site; retained across visits | Per-callsite counters |
| `report var` | `report var x: T;` | Alias for `report unshared var`; printed at program end via WASI | Output accumulators |
| `frame var` | `frame var x: T;` | Stored on the function frame; shared between `func:entry` and `func:exit` | Entry→exit state |
| `shared var` | `shared var x: T;` | Single instance across ALL sites | NOT YET IMPLEMENTED |

Variables declared **inside** a probe body behave as `unshared var` by default.

Full type syntax — ints, floats, str, tuples, maps: see [`references/language.md`](references/language.md).

## A first script

Count every WebAssembly opcode executed:

```mm
report var count: u32;

wasm:opcode:*:before {
    count++;
}
```

`report var` is global and printed automatically when the instrumented module exits (via WASI). No `wasm:report` block required for simple scalars.

## Verifying bound variables

The bound-variable lists in this skill are derived from the whamm documentation. Per `/core:anti-fabrication`, confirm the exact variables available at a given match rule with `whamm info --rule "<rule>"` at the installed version rather than assuming — the authoritative set is what the binary reports.

## References

- [`references/language.md`](references/language.md) — types, var kinds with examples, operators, strings, tuples, maps; functions (planned)
- [`references/events.md`](references/events.md) — full provider hierarchy, available vs planned, all bound-variable tables
- [`references/libraries.md`](references/libraries.md) — `use`, whamm_core built-ins, string memory interop, `@static`/`@init`, `wasm:report` override
- [`references/examples.md`](references/examples.md) — annotated `.mm` scripts: instruction count, branch monitor, call graph, cache simulator, string interop

Companion skill for install and CLI: **whamm** (same plugin).
