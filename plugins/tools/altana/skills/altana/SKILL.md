---
name: altana
description: "Protocol knowledge for the altana CLI: config discovery, harness presets, JSON result contract, status codes, council synthesis, model picker, and response protocol. Use when running /altana:delegate, /altana:council, or /altana:harness; debugging altana JSON output or non-done statuses; configuring harness TOML presets; or integrating altana into a workflow."
license: MIT
---

# altana skill

Procedural knowledge for working with the altana CLI — a tool that delegates prompts to named AI harness presets, collects structured JSON results, and fans out tasks across multiple harnesses for diverse-perspective synthesis.

## When to Use

Activate when:
- Running `/altana:delegate`, `/altana:council`, or `/altana:harness` commands.
- Debugging non-`done` status values or unexpected JSON output.
- Configuring `altana.toml` harness presets or prompt templates.
- Choosing between foreground vs background invocation for long tasks.
- Synthesizing council results across multiple harness responses.
- Using the model picker or `altana models` to enumerate available models.

## Config Discovery

altana resolves its config in this order:

1. `$ALTANA_CONFIG` — if set, this path is used.
2. `~/.config/altana/altana.toml` — default location.

Copy `harnesses.example.toml` from the altana repo root to get started:

```bash
mkdir -p ~/.config/altana
cp harnesses.example.toml ~/.config/altana/altana.toml
```

Full schema details in `references/config.md`.

## Subcommands

### delegate

```
altana delegate <harness> "<task>" [--prompt <template>] [--write]
```

Sends one task to one harness. Exits 0 on `done`, 1 on all other statuses.

Stdout: JSON object `{harness, status, duration_s, log_path, response}`.

Use `--write` only when the task requires the agent to modify files (awman executor only). `council` rejects `--write` presets.

### council

```
altana council "<task>" [--harnesses a,b,c] [--prompt <template>]
```

Fans the same task out to N harnesses in parallel (read-only). Returns a JSON array in config-declaration order. Each element has the same schema as `delegate` output.

Council is the diverse-perspectives primitive. The synthesis step (agreements / disagreements / unique insights / recommendation) belongs in the caller — altana delivers raw results.

### harness

```
altana harness "<t1>" "<t2>" ... [--map idx@harness]
```

Distributes many tasks across harnesses. Returns a JSON array in task order. Round-robin by default; `--map` pins a specific task index to a named harness.

### models

```
altana models <harness>
```

Fetches `GET <ANTHROPIC_BASE_URL>/v1/models` using the harness's auth config and prints model IDs. Use to discover available models before setting `model =` in the preset.

### list / doctor

```
altana list
altana doctor
```

`list` — prints all configured harness names and prompt template names from config.
`doctor` — checks prerequisites (altana binary, awman on PATH, op reachable if op:// refs present) and exits 1 with a remediation message on failure.

## JSON Result Contract

All subcommands return JSON. The `delegate` response is a single object; `council` and `harness` return arrays.

| Field | Type | Present when |
|---|---|---|
| `harness` | string | always |
| `status` | string | always |
| `duration_s` | float | always |
| `log_path` | string | always |
| `response` | string or null | `status == "done"` → string; otherwise null |

### Status Codes

| Status | Meaning | Action |
|---|---|---|
| `done` | Agent exited 0 and emitted the completion sentinel | Parse `response` |
| `missing_sentinel` | Agent exited 0 but no sentinel found | Inspect `log_path` for truncated output |
| `crash` | Agent exited non-zero or failed to spawn | Inspect `log_path` for error details |
| `timeout` | Agent exceeded `timeout_s` | Increase `timeout_s` or break the task up |

`altana delegate` exits 0 only for `done`; exits 1 for all other statuses.

## Foreground vs Background Invocation

Run in the **foreground** (synchronous Bash call) when:
- The harness `timeout_s` is ≤ 300 seconds and no `--write` flag is used.
- A quick answer is expected (e.g. `altana models`).

Run in the **background** when:
- `timeout_s` > 300 seconds or `--write` is present.
- Using `council` (parallel fan-out; wall-clock time is bounded by the slowest harness).
- Using `harness` with multiple tasks.

The `/altana:delegate` command chooses foreground vs background automatically based on these criteria.

## Response Protocol

altana wraps every task in a protocol that instructs the agent to respond in a structured format and emit a completion sentinel. The agent is expected to reply with:

```
## Answer
<the answer>

## Evidence
<supporting evidence, citations, or tool output>

## Confidence
<high | medium | low>
```

Followed by the sentinel line:
```
=== ALTANA DONE <run_id> ===
```

altana strips the sentinel before placing the text in `response`. The three sections are consistent across all harnesses, enabling structured synthesis in council mode.

Custom `[prompt.<name>]` templates that include the section headers expose them to the agent as format guidance; altana does not duplicate them.

## Council Synthesis

When `council` results arrive, synthesize across all `done` responses:

1. **Extract answers** — for each `done` element, pull the `## Answer` section from `response`.
2. **Find agreements** — claims present (in substance) across all or most harnesses.
3. **Find disagreements** — positions that conflict across harnesses; attribute each to its harness.
4. **Surface unique insights** — observations raised by exactly one harness.
5. **Produce a recommendation** — a single synthesized conclusion that weighs the above.

Non-`done` elements are noted as absent from the synthesis with their status and `log_path`.

A synthesis table at the end lists harness, status, and duration for transparency.

## Model Picker

When a harness preset has no `model` field and stdin is a TTY, `altana delegate` fetches the model list and shows a numbered selection prompt:

```
1. claude-opus-4-5 (model)
2. claude-sonnet-4-5 (model)
Select a model (1-3):
```

In non-TTY contexts (scripts, CI) with no `model` configured, altana exits with an error naming the available models. Remedy: set `model =` in the preset or pass the harness name to `altana models` first.

Note: the interactive picker reads `ANTHROPIC_AUTH_TOKEN` (not `ANTHROPIC_API_KEY`) during the selection step.

## Anti-Fabrication

Do not claim an altana run succeeded without verifying the `status` field. Do not summarize `response` content from a non-`done` result. If `status != "done"`, cite the actual status value and point to `log_path` — do not fabricate a partial answer.

Always parse the actual JSON returned by altana before reporting results. Never describe a harness response from memory or assumption.

## References

- `references/config.md` — full `altana.toml` schema: harness fields, prompt templates, op:// secrets.
- `references/backends.md` — executor types (awman vs raw), local-provider env patterns, generic harness examples.
