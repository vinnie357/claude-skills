# whamm-dsl Language Reference

## Types

### Primitive types

| Type | Width | Notes |
|------|-------|-------|
| `bool` | — | `true` / `false` |
| `u8`, `i8` | 8-bit | unsigned / signed |
| `u16`, `i16` | 16-bit | unsigned / signed |
| `u32`, `i32` | 32-bit | unsigned / signed |
| `u64`, `i64` | 64-bit | unsigned / signed |
| `f32` | 32-bit | IEEE 754 float |
| `f64` | 64-bit | IEEE 754 float |
| `str` | static | Static string (internally `(mem_addr, length)`) |

### str methods and escapes

Strings are **static only** — they cannot be computed at runtime without library assistance (see `libraries.md`).

Methods available on `str` values:

```mm
var s: str = "hello world!";
s.len()              // u32 — byte length
s.starts_with("he")  // bool
s.ends_with("!")     // bool
s.contains("world")  // bool
```

Supported escape sequences: `\n`, `\t`, `\"`, `\'`, `\\`, `\0`, `\xNN`, `\u{NNNN}`.

### Tuples

Tuples group heterogeneous values. Access fields with `.0`, `.1`, `.1.0`, etc.

```mm
var pair: (i32, i32) = (1, 2);
var nested: (i32, (i32, i32)) = (0, (1, 2));
var x: i32 = nested.1.0;  // 1
```

Tuples are valid as map keys.

### Maps

Maps are declared with `map<K, V>`. They initialise to empty automatically.

```mm
report var counts: map<u32, u32>;
counts[fid]++;          // read or write; out-of-bounds access = wasm trap

report var graph: map<(u32, u32), u32>;
graph[(fid, imm0)]++;   // tuple key
```

## Variable kinds

### `var` — temporary

Reinitialised on every probe invocation. Use for values that should not persist across calls.

```mm
wasm:opcode:*:before {
    var was_taken: bool = arg0 != 0;
    // was_taken is re-declared fresh each time this probe fires
}
```

### `unshared var` — per-site, retained

One instance per match site. Retains its value across visits to that site. Declaring inside a probe body also creates an unshared var by default.

```mm
wasm::*if:before {
    report unshared var total: i32;
    total++;    // increments the counter specific to this call site
}
```

### `report var` — output accumulator

Alias for `report unshared var`. Values are flushed and printed at program end via WASI. Scalars print automatically; maps require `wham_core.print_map_as_csv` (see `libraries.md`).

```mm
report var count: u32;
report var call_graph: map<(u32, u32), u32>;
```

### `frame var` — function frame storage

Stored on the function's stack frame. Allows state to flow from `wasm:func:entry` to `wasm:func:exit` within the same invocation.

```mm
frame var entry_time: u64;

wasm:func:entry {
    entry_time = get_time();
}

wasm:func:exit {
    report var elapsed: u64;
    elapsed = elapsed + (get_time() - entry_time);
}
```

### `shared var` — NOT YET IMPLEMENTED

A single instance shared across ALL match sites. Declared as `shared var x: T;`. whamm! does not yet implement this kind; use `unshared var` or `report var` for accumulators.

## Operators

### Arithmetic

`+`, `-`, `*`, `/`, `%` — standard integer/float arithmetic.
`++`, `--` — post-increment / post-decrement on integer vars.

### Logical

`&&`, `||` — short-circuit boolean operators.
`!` — logical NOT.

### Ternary

```mm
var index: u32 = arg0 <= (num_targets - 1) ? arg0 : num_targets;
```

### Conditionals

```mm
if (was_taken) {
    taken = taken + 1;
} elif (something_else) {
    // ...
} else {
    // ...
};   // note trailing semicolon required
```

### Type casts

```mm
var l: u32 = s.len();
var ptr: i32 = whamm_core.mem_alloc(l as i32);   // cast with `as`
```

## Type bounds on match rules

Narrow a polymorphic probe to sites where an argument has a specific type:

```mm
wasm:opcode:call(arg0: i32):before {
    // fires only at call sites where arg0 is i32
}
```

## Functions — NOT YET IMPLEMENTED

The syntax `name(args) -> ret { .. }` for user-defined functions is documented in the whamm design but not yet fully implemented at v0.1.0.
