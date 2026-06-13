---
description: "Delegate a task to a named altana harness and surface the structured JSON result"
argument-hint: "<harness> <task> [--prompt=<template>] [--write]"
---

Run `altana delegate` to send a task to a single named harness preset and return the structured result.

**What it does:**

1. Invokes `altana delegate <harness> "<task>"` with any supplied flags via Bash.
2. For long-running agents (timeout_s > 300 or when `--write` is present) runs the command in the background and streams the result when complete.
3. Parses the JSON object from stdout.
4. Surfaces a human-readable summary: harness name, status, duration, response text (trimmed to key sections), and log path for debugging.
5. On non-`done` status, explains the failure mode and points to the log file.

**Arguments:**

- `<harness>` — name of a configured harness preset (see `altana list` to enumerate presets).
- `<task>` — the prompt string to delegate. Wrap in quotes if it contains spaces.
- `--prompt=<template>` — optional named prompt template from `[prompt.<name>]` in config; wraps the task before dispatch.
- `--write` — grant the agent write access to the working directory inside the container (awman executor only).

**JSON result fields:**

| Field | Type | Description |
|---|---|---|
| `harness` | string | Harness name used |
| `status` | string | `done` \| `timeout` \| `crash` \| `missing_sentinel` |
| `duration_s` | float | Wall-clock seconds |
| `log_path` | string | Full subprocess log path |
| `response` | string or null | Agent response (sentinel stripped); null on non-`done` |

**Status meanings:**

- `done` — agent exited 0 and emitted the completion sentinel; `response` is populated.
- `missing_sentinel` — agent exited 0 but did not emit the sentinel; check `log_path`.
- `crash` — agent exited non-zero or failed to spawn; check `log_path`.
- `timeout` — agent exceeded the configured `timeout_s`; check `log_path` for partial output.

**If `altana` is not installed:**

Install altana (see its README — it is a Zig CLI built with `zig 0.16`). After building, place the binary on your `PATH` or invoke via `mise exec -- zig-out/bin/altana`.

**Examples:**

```
/delegate my-claude "explain the failing test in src/parser_test.zig"
/delegate critique-harness "review src/main.zig" --prompt=critique
/delegate coding-agent "add error handling to the fetch function" --write
```

**Task instructions:**

Resolve the argument string: the first positional token is `<harness>`, the remaining text up to the first `--` flag is `<task>`. Reconstruct any `--prompt=` or `--write` flags from the parsed argument.

Run: `altana delegate "<harness>" "<task>" [flags]`

Parse the JSON result. Present:
- A one-line status line: `harness: <name> | status: <status> | duration: <duration_s>s`
- If `status == "done"`: the `response` content (show `## Answer`, `## Evidence`, `## Confidence` sections).
- If `status != "done"`: the failure mode explanation and the `log_path` to inspect.

Load `/altana:altana` for protocol and config reference before running.
