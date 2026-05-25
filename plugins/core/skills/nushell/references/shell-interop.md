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

## Bash logical-operator silent error mask

When a nushell script invokes bash (`^bash -c "..."`, mise task runner, or embedded bash heredocs in workflow scripts), the bash shorthand `cmd1 && cmd2 || cmd3` looks like an if/else but is NOT one. It silently masks failures.

### The trap

```bash
test -f /path/to/binary && do-thing /path/to/binary || echo "skip"
```

Intent: "if the binary exists, do-thing; else skip."

Reality: bash parses this as `(test -f /path/to/binary && do-thing /path/to/binary) || echo "skip"`. If `do-thing` LEGITIMATELY fails (permission denied, immutable signature, kernel sigkill), the `|| echo "skip"` fires and the OVERALL exit code is 0 (assuming `echo` succeeds). The script proceeds as if `do-thing` succeeded.

Nushell guards on `$last.exit_code` see 0 and report success. Downstream steps run against a partial / broken state.

### The fix

Use bash `if/else`, which propagates the inner command's exit code:

```bash
if test -f /path/to/binary; then
  do-thing /path/to/binary
else
  echo "skip — binary absent"
fi
```

`do-thing`'s exit code propagates through the `then` branch. Failures surface to the calling script. The nushell guard on `$last.exit_code` sees the actual failure.

### When the trap fires

Any command in the `cmd2` position that can fail for reasons OTHER than the precondition `cmd1` checks. Examples:
- `codesign`, `chmod`, `chown` — can fail on permissions even when target file exists.
- `ssh`, `scp` — can fail on network even when host is reachable.
- `kubectl apply`, `helm install` — can fail on cluster state even when manifest validates.
- `mix release`, `cargo build` — can fail on toolchain even when source compiles.

For any non-zero-tolerant command, `&& ... ||` is wrong. Use `if/else`.

### Detection

Scan workflow scripts for the pattern:

```bash
grep -rnE '&&[^&|]+\|\|' bundles/ scripts/ .github/workflows/
```

Lines matching are candidates for review. Most are legitimate "default value" idioms (`getval && echo "$result" || echo "<default>"`) but any that wrap a non-zero-tolerant `cmd2` should be rewritten to `if/else`.
