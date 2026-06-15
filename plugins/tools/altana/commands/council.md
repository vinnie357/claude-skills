---
description: "Send the same task to multiple altana harnesses in parallel and synthesize the responses into agreements, disagreements, unique insights, and a recommendation"
argument-hint: "<task> [--harnesses a,b,c] [--rounds N] [--interactive] [--prompt <template>]"
---

Run `altana council` to fan out one task to N harnesses simultaneously, then synthesize the array of responses into a structured analysis. Two modes are available: one-shot (default) and interactive (persistent-session, multi-round deliberation).

**What it does:**

1. Invokes `altana council "<task>" [--harnesses <list>] [--rounds N] [--interactive] [--prompt <template>]`.
2. Runs in the background (council calls are inherently parallel and may take time).
3. Receives a JSON array of result objects — one per harness, in config-declaration order.
   - In one-shot mode each element has a single `response` string.
   - In interactive mode each element carries a `rounds` array of `{round, response}` objects instead of a single `response`.
4. Synthesizes the responses into a structured report:
   - **Agreements** — claims all harnesses converge on.
   - **Disagreements** — points where harnesses diverge; note which harness said what.
   - **Unique insights** — observations raised by only one harness.
   - **Recommendation** — a synthesized conclusion weighing all perspectives.

**Why council?** Different harnesses run different models or executors. The same question delegated to multiple independent agents surfaces blind spots, validates conclusions, and reveals model-specific biases. The synthesis step is where the value lands — raw JSON alone does not exploit the diverse perspectives.

**Arguments:**

- `<task>` — the prompt to fan out. Council is read-only; `--write` presets are rejected by altana.
- `--harnesses a,b,c` — comma-separated list of harness names; defaults to all configured harnesses when omitted.
- `--rounds N` — number of deliberation rounds when `--interactive` is set; default 2.
- `--interactive` — opens one persistent session per harness; from round 2 on each harness sees labeled digests of its peers' prior-round answers and can react. Synthesis remains the caller's responsibility.
- `--prompt <template>` — optional named prompt template applied to each harness invocation.

**Result array element fields** (same schema as `delegate`):

| Field | Type |
|---|---|
| `harness` | string |
| `status` | `done` \| `timeout` \| `crash` \| `missing_sentinel` |
| `duration_s` | float |
| `log_path` | string |
| `response` | string or null |

**If `altana` is not installed:**

Install altana (see its README — it is a Zig CLI built with `zig 0.16`). After building, place the binary on your `PATH` or invoke via `mise exec -- zig-out/bin/altana`.

**Examples:**

```
/council "what are the risks of removing the retry loop in src/client.zig?"
/council "critique the API surface in src/api.zig" --harnesses opus-harness,sonnet-harness
/council "review this design doc" --prompt design-review
/council "compare these two API designs" --interactive --rounds 1 --harnesses claude-cloud,claude-local
```

**Task instructions:**

Parse the argument: everything before the first `--` flag is `<task>`; extract `--harnesses`, `--rounds`, `--interactive`, and `--prompt` from the flags. Flags must appear after the task string (the working invocation order is `altana council "<task>" --flag value`).

Run (in background): `altana council "<task>" [--harnesses <list>] [--rounds N] [--interactive] [--prompt <template>]`

Once the result arrives, parse the JSON array. For each element where `status == "done"`, extract the `## Answer` section from `response`. For non-`done` entries, note the harness name and failure status.

Synthesize across all `done` responses:

1. **Agreements** — identify claims that appear (in substance) across all or most harnesses.
2. **Disagreements** — identify points where harnesses give incompatible answers; attribute each position to its harness.
3. **Unique insights** — note observations raised by exactly one harness that the others did not mention.
4. **Recommendation** — produce a single synthesized answer that weighs the agreements, resolves or flags the disagreements, and incorporates the unique insights.

Report the synthesis. Append a table showing harness, status, and duration for transparency. If any harness returned non-`done`, note what was missing from the synthesis and point to the `log_path` for investigation.

Load `/altana:altana` for protocol and config reference before running.
