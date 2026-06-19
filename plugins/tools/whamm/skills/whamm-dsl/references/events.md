# whamm-dsl Events Reference

The authoritative source for bound variables at any specific match rule is:

```bash
whamm info --rule "wasm:opcode:call:before"
```

This reference documents the provider hierarchy and bound variables known at v0.1.0.

## Provider hierarchy

```
wasm                          ← provider
  opcode                      ← package
    <opcode-name-or-glob>     ← event
      before | after | alt    ← mode
  func                        ← package
    (any function)            ← event (no name; matches all functions)
      entry | exit            ← mode  (unwind is planned, not available)
  block                       ← package
    end                       ← event
      (no mode)
  (top-level)
    begin                     ← special probe, no mode
    end                       ← special probe, no mode
    report                    ← special probe, no mode
```

## Available vs planned

| Probe | Status |
|-------|--------|
| `wasm:opcode:*:before` | Available |
| `wasm:opcode:*:after` | Available |
| `wasm:opcode:*:alt` | Available |
| `wasm:func:*:entry` | Available |
| `wasm:func:*:exit` | Available |
| `wasm:func:*:unwind` | **Planned — not yet available** |
| `wasm:block:end` | Available |
| `wasm:begin` | Available |
| `wasm:end` | Available |
| `wasm:report` | Available |
| `shared var` | **Planned — not yet available** |

## Event globbing

Empty package acts as a wildcard across packages:

```
wasm::*if:before     # matches wasm:opcode:if:before AND wasm:opcode:br_if:before
```

Pipe-separated alternatives:

```
wasm:opcode:call|return_call:before
wasm:opcode:*load*|*store*:before
```

Type bounds narrow by argument type at match time:

```
wasm:opcode:call(arg0: i32):before
```

## Bound variables — provider level (`wasm`, all probes)

These variables are available in every whamm probe:

| Variable | Type | Description |
|----------|------|-------------|
| `probe_id` | `i32` | Engine-assigned probe identifier |
| `fid` | `u32` | Index of the function containing the probe site |
| `pc` | `u32` | Program counter (bytecode offset) of the probe site |
| `opidx` | `u32` | Instruction index within the function |
| `at_func_end` | `bool` | True if the probe is at the last instruction of the function |
| `fname` | `str` | Name of the enclosing function (static) |
| `local0`, `local1`, … | dynamic | Local variable values (type depends on function signature) |

`fid`, `pc`, `opidx` are **static** — whamm! constant-folds predicates on them at compile time. A predicate `/ pc == 25 /` eliminates the probe entirely at non-matching sites.

## Bound variables — `wasm:opcode` common

Available in all `wasm:opcode:*` probes in addition to the provider-level vars:

| Variable | Type | Description |
|----------|------|-------------|
| `opname` | `str` | Textual name of the opcode (e.g. `"call"`) |
| `bytecode` | `u16` | Numeric opcode value |
| `category_id` | `u32` | Numeric category of the opcode |
| `category_name` | `str` | Textual category (e.g. `"control"`, `"memory"`) |
| `arg0`, `arg1`, … | dynamic | Stack arguments consumed by the opcode (type varies) |
| `imm0`, `imm1`, … | dynamic | Immediate (static) operands of the opcode |
| `res0`, `res1`, … | dynamic | Result values (**`after` mode only**) |

## Bound variables — opcode-specific

### `call` and `return_call`

| Variable | Type | Description |
|----------|------|-------------|
| `imm0` | `u32` | Target function index (static) |
| `target_fn_name` | `str` | Name of the target function (static) |
| `target_imp_module` | `str` | Import module name if imported, empty for locals (static) |
| `target_fn_type` | `str` | `"local"` or `"import"` (static) |

Bound functions available in `alt` mode:

- `alt_call_by_id(id: i32)` — redirect call to function by index
- `alt_call_by_name(name: str)` — redirect call to function by name

### `br_if`

| Variable | Type | Description |
|----------|------|-------------|
| `arg0` | dynamic | Condition value on the stack |
| `imm0` | `u32` | Branch label (static) |

### `br_table`

| Variable | Type | Description |
|----------|------|-------------|
| `arg0` | dynamic | Branch index |
| `num_targets` | `u32` | Number of targets in the table (static) |
| `target` | `u32` | Resolved target: `arg0 <= num_targets-1 ? arg0 : num_targets` |

### `*load*` / `*store*` (all memory load and store opcodes)

| Variable | Type | Description |
|----------|------|-------------|
| `data_size` | `u32` | Number of bytes transferred |
| `addr` | `u32` | Base address (alias: `arg0`) |
| `effective_addr` | `u32` | `addr + offset` |
| `offset` | `u64` | Static memory offset operand (static) |
| `is_write` | `bool` | True for store opcodes |

### `call_indirect`

| Variable | Type | Description |
|----------|------|-------------|
| `table_entry_idx` | dynamic | Index into the indirect call table |

### `wasm:block:end`

| Variable | Type | Description |
|----------|------|-------------|
| `instr_count` | `u32` | Number of instructions in the block |
