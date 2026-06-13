---
description: "Distribute multiple tasks across altana harnesses and present a per-task results table"
argument-hint: "<t1> | <t2> | ... [--map idx@harness]"
---

Run `altana harness` to fan out many tasks, distributing them across configured harnesses, and present the results as a per-task table.

**What it does:**

1. Parses the pipe-separated task list from the argument string.
2. Invokes `altana harness "<t1>" "<t2>" ... [--map <idx>@<harness>]`.
3. Runs in the background (multiple agents run concurrently).
4. Receives a JSON array of result objects in task order.
5. Presents a per-task results table with harness, status, duration, and a one-line answer excerpt.

**Arguments:**

- `<t1> | <t2> | ...` — task strings separated by ` | ` (pipe with spaces). Each becomes one element in the harness call.
- `--map idx@harness` — pin a specific task index (0-based) to a named harness. Multiple `--map` flags are accepted. Tasks without a pin are distributed in round-robin order across all configured harnesses.

**Result table format:**

```
#  | Harness       | Status  | Duration | Answer excerpt
---|---------------|---------|----------|---------------
0  | claude-local  | done    | 9.4s     | "Hello there, fr..."
1  | codex         | done    | 4.1s     | "The fix requires..."
2  | claude-local  | crash   | 0.3s     | (see log_path)
```

**If `altana` is not installed:**

Install altana (see its README — it is a Zig CLI built with `zig 0.16`). After building, place the binary on your `PATH` or invoke via `mise exec -- zig-out/bin/altana`.

**Examples:**

```
/harness explain the delegate subcommand | explain the council subcommand | explain the harness subcommand
/harness write a docstring for parse_config | write a docstring for run_delegate | write tests for council --map 0@opus-harness
/harness "audit error handling in src/delegate.zig" | "audit error handling in src/council.zig"
```

**Task instructions:**

Parse the argument: split on ` | ` to produce the task list. Extract any `--map` flags from the remaining tokens.

Reconstruct the altana call: `altana harness "<t1>" "<t2>" ... [--map ...]`

Run in background.

Once results arrive, parse the JSON array (index corresponds to task order). Build the results table:
- For `status == "done"`: extract the first non-empty line of `## Answer` as the excerpt.
- For non-`done` statuses: show the status value and the `log_path`.

Present the table. For any `done` entries where the full response is needed, show it on request.

Load `/altana:altana` for protocol and config reference before running.
