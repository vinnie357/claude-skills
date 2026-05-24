# Shell interop pitfalls

Cross-shell and HTTP-API gotchas commonly hit when nushell scripts orchestrate external HTTP services or embed bash commands. Each section is self-contained.

## Runex HTTP API response shape via nushell

Runex's `/api/runs` (and related) endpoints wrap response objects under a `.data` field:

```nu
let resp = (http get $"http://localhost:4001/api/runs/($id)")
# WRONG — reads top-level
let status = $resp.status

# CORRECT — reads under .data
let status = $resp.data.status
```

A defensive helper that accepts BOTH shapes (some other API tiers do NOT wrap, and helper code is often shared across mixed-shape consumers):

```nu
def unwrap-data [resp] {
  if ($resp | columns | any { |c| $c == "data" }) {
    $resp.data
  } else {
    $resp
  }
}
```

### `data.id` is INT, pipe through string before string ops

```nu
let id = $resp.data.id  # INT
# WRONG — concatenation against int
let url = "http://host/runs/" + $id
# CORRECT — coerce to string
let url = $"http://host/runs/($id | into string)"
```

### Terminal-status set

Status comparisons must include all terminal values. The complete set for Runex runs is:

```nu
let terminal = ["complete" "failed" "error" "cancelled" "success"]
```

`success` is often omitted by accident; some endpoint shapes return `success` instead of `complete` for clean exits. Include all five in any "is the run done?" check.

### Nushell common pitfalls

- **`$env.HOME`** is the canonical home-directory accessor — `$nu.home-path` exists but `$env.HOME` is more reliable across nushell versions and respects shell-level HOME overrides.
- **Parens in string interpolation parse as expressions**: `$"hello (world)"` tries to evaluate `world` as a variable. Escape the parens or lift the value into a variable first.
- **`sort-by -r` is NOT stable**: ties reorder unpredictably. Use `sort-by <field> | reverse` instead.
- **No `2>&1` in nushell**: bash-style file-descriptor redirection does not exist. Use `out+err> file.log` (or `o+e>` short form) to capture both streams to one destination.
