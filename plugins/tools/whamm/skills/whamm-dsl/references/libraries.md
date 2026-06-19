# whamm-dsl Libraries Reference

## Importing a library

```mm
use whamm_core;
```

Place `use` declarations at the top of the `.mm` file, before probes. After importing, call functions as `lib.fn(args)`.

```mm
use whamm_core;

wasm:opcode:drop:before {
    var l: u32 = 12;
    var ptr: i32 = whamm_core.mem_alloc(l as i32);
    // ...
    whamm_core.mem_free(ptr);
}
```

## whamm_core built-ins

`whamm_core` is the built-in standard library. Import it with `use whamm_core;`.

| Function | Signature | Description |
|----------|-----------|-------------|
| `puts` | `(ptr: i32, len: i32)` | Print `len` bytes from linear memory at `ptr` to stdout |
| `mem_alloc` | `(size: i32) -> i32` | Allocate `size` bytes; returns pointer into the library's linear memory |
| `mem_free` | `(ptr: i32)` | Free a previously allocated pointer |
| `print_map_as_csv` | `(map_id: i32)` | Print a `report var` map as CSV rows at program end |

## String memory interop

`str` values in whamm are static. To pass a string to a library function that operates on linear memory (e.g. `puts`), use these built-in interop helpers:

| Helper | Description |
|--------|-------------|
| `memid(lib)` | Returns the memory ID of `lib`'s linear memory |
| `write_str(memid, ptr, s)` | Writes string `s` into linear memory `memid` at address `ptr` |
| `read_str(memid, ptr, len)` | Reads `len` bytes from linear memory `memid` at `ptr` into a `str` |

### String interop example

Write a static string into whamm_core's memory and print it:

```mm
use whamm_core;

wasm:opcode:drop:before {
    var s: str = "hello world!";
    var l: u32 = s.len();
    var ptr: i32 = whamm_core.mem_alloc(l as i32);
    write_str(memid(whamm_core), ptr, s);
    whamm_core.puts(ptr, l as i32);
    whamm_core.mem_free(ptr);
}
```

## `@static` call modifier

`@static lib.fn(..)` calls the function at **match (compile) time**, not at runtime.

- Use for calls that must happen once during instrumentation, e.g. registering a cache configuration.
- The function must be side-effect-free for the bytecode-rewriting path (state is lost between rewriting and execution).
- On the `wei` (engine-support) path, `@static` state persists because the engine holds the library module.

```mm
use cache;

wasm:opcode:*load*|*store*:before {
    @static cache.init(64, 4);   // called at match time
    var result: i32 = cache.check_access(effective_addr as i32, data_size as i32);
}
```

## `@init` call modifier

`@init lib.fn()` runs the function at **probe initialisation** (program start), once per script load.

```mm
use whamm_core;

wasm:begin {
    @init whamm_core.setup();
}
```

## `wasm:report` override

By default, `report var` scalars print automatically. To customise output — e.g. print a map as CSV — add a `wasm:report` probe:

```mm
use whamm_core;

report var call_graph: map<(u32, u32), u32>;

// ... probes that populate call_graph ...

wasm:report {
    whamm_core.print_map_as_csv(0);
}
```

`print_map_as_csv(0)` prints the first `report var` map declared in the script. Index corresponds to declaration order among `report var` maps.

### Call graph example (uses whamm_core and report override)

```mm
use whamm_core;

// (from, to) -> count
report var call_graph: map<(u32, u32), u32>;
var tracking_target: bool;
var caller: u32;

wasm:opcode:call|return_call:before {
    call_graph[(fid, imm0)]++;
}

wasm:opcode:*call_indirect|*call_ref:before {
    tracking_target = true;
    caller = fid;
}

wasm:func:entry {
    if (tracking_target) {
        call_graph[(caller, fid)]++;
        tracking_target = false;
    }
}

wasm:report {
    whamm_core.print_map_as_csv(0);
}
```

## Custom libraries

Any Wasm module that exports the expected functions can be used as a whamm library. Custom libraries follow the same `use`/`lib.fn()` pattern as `whamm_core`. The `cache` library in the cache simulator example (see `examples.md`) is a custom library that exports `check_access(effective_addr, data_size) -> i32`.
