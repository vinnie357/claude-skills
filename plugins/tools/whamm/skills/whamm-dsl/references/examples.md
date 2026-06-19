# whamm-dsl Examples

All scripts below are verbatim `.mm` examples. Each fires at the match sites described; output is emitted via WASI at program exit unless otherwise noted.

---

## Instruction count

Counts every WebAssembly opcode executed. The `report var` scalar is printed automatically at exit.

```mm
report var count: u32;

wasm:opcode:*:before {
    count++;
}
```

**What it instruments:** every opcode in the module, before execution.
**What it reports:** total opcode count for the run, printed to stdout on exit.

---

## Branch monitor

Tracks how often each conditional branch is taken and records indirect branch table distribution.

```mm
// Matches _if and br_if events
wasm::*if:before {
  report unshared var taken: i32;
  report unshared var total: i32;

  var was_taken: bool = arg0 != 0;
  taken = taken + (was_taken as i32);
  total++;
}

wasm::br_table:before {
  report unshared var taken_branches: map<u32, u32>;

  var index: u32 = arg0 <= (num_targets - 1) ? arg0 : num_targets;
  taken_branches[index]++;
}
```

**What it instruments:** `if`, `br_if` (via `*if` glob), and `br_table` opcodes.
**What it reports:** per-site taken/total counts for conditionals; per-target counts for branch tables.

---

## Call graph

Records a weighted directed call graph: `(caller_fid, callee_fid) → count`. Handles direct calls, tail calls, and indirect/reference calls via a tracking flag that resolves the callee at `func:entry`. Uses `whamm_core.print_map_as_csv` for output.

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

**What it instruments:** direct/tail calls (at the call opcode), indirect/reference calls (resolved at callee entry).
**What it reports:** CSV of `(caller_fid, callee_fid, count)` rows via `wasm:report` override.

---

## Cache simulator

Simulates a cache and accumulates hit/miss counts across all memory load and store opcodes. Uses a custom `cache` library that exports `check_access(effective_addr, data_size) -> i32`. The return value packs hit and miss counts into the high and low 16 bits.

```mm
use cache;

wasm:opcode:*load*|*store*:before {
    report var hit: u32;
    report var miss: u32;

    var result: i32 = cache.check_access(effective_addr as i32, data_size as i32);
    var num_hits: i32 = (result & 0xFFFF0000) >> 16;
    var num_misses: i32 = (result & 0x0000FFFF);

    hit = hit + (num_hits as u32);
    miss = miss + (num_misses as u32);
}
```

**What it instruments:** all memory load and store opcodes.
**What it reports:** total cache hits and misses accumulated across the run.

---

## String interop

Demonstrates writing a static string into whamm_core's linear memory and printing it via `puts`. Fires on every `drop` opcode.

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

**What it instruments:** every `drop` opcode in the module.
**What it reports:** prints `"hello world!"` to stdout each time a `drop` executes; demonstrates `mem_alloc`/`write_str`/`puts`/`mem_free` interop pattern.
