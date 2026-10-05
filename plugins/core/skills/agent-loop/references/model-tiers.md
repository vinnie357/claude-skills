# Model tiers per harness

Policy: ADR 0001 decision 5. This file is the only place model ids, effort flags, and
effort values appear. Verified 2026-09-15 against the CLIs named below, except the cells
re-read 2026-10-05: every codex id against the `codex debug models` catalog (codex-cli
0.159.1) and every agy id against `agy models` (Antigravity CLI 1.2.17). The claude
column was not re-probed; 2.1.286 is the pinned version.

Agent-file `model:` frontmatter values are claude-harness config drawn from the claude
column.

| Tier | claude (Claude Code 2.1.286 pinned) | codex (codex-cli 0.159.1) | agy (Antigravity CLI 1.2.17) |
|---|---|---|---|
| strongest reasoning | `fable` | `gpt-6-astra` | `claude-opus-5-5-high` |
| strongest fallback (unavailable only) | `opus` | `gpt-6.1-sol` | `gemini-3.1-pro-high` |
| deep reasoning | `opus` | `gpt-6.1-sol` | `gemini-3.1-pro-high` |
| general | `sonnet` | `gpt-6.1-sol` | `claude-sonnet-5-5-medium` |
| smallest fast | `haiku` (`Explore` agent type for text research) | `gpt-6-luna` | `gemini-3.8-flash-medium` |
| multimodal | unverified | unverified | unverified |
| effort setting | `--effort <level>`; agent `effort:` frontmatter | `-c model_reasoning_effort=<level>` | `--effort <level>` (acceptance per model unverified); every listed id carries effort as a `-low`/`-medium`/`-high` suffix |
| effort values | `low medium high xhigh max` | `gpt-6-astra`: `low medium high xhigh max ultra` (rejects `none`, `minimal`) | `low medium high` as id suffixes; `--help` lists `low medium high xhigh max` for the flag |
| harness default effort | `high` (Claude Code model picker; not listed by `--help`) | unverified | `medium` |

- claude and codex rows follow each harness's model-picker descriptions ("most capable" → strongest … "fast"/"fastest" → smallest fast).
- General tier effort: claude `sonnet` runs at `medium` to `high` (operator decision; `sonnet` currently resolves to Sonnet 5.5 per the operator, unverified by the CLI, which documents only the alias); codex `gpt-6.1-sol` runs at `medium` (listed as a supported level in the `codex debug models` catalog).
- agy ids come from `agy models`. The effort suffix in each table id is a choice; the other suffixes exist. `gemini-3.7-flash`, `gemini-3.6-flash` and `gpt-oss-120b-medium` are listed and unmapped.
- In the codex column the strongest fallback, deep reasoning and general rows all map to `gpt-6.1-sol`, so escalating between them changes nothing unless the effort changes. The deep-tier effort is unverified: the operator set only general = `medium`, and the catalog default for `gpt-6.1-sol` is `low`.
- agy `--effort` support for `claude-opus-5-5-*` and `claude-sonnet-5-5-*` is unverified. An earlier agy release rejected `--effort` for a retired Claude id; that result does not carry over to these ids.
- agy `--model gemini-3.8-flash-medium --effort high` failed ("conflicts with --effort=high") on agy 1.2.3 and was not re-probed on 1.2.17 — pass Gemini effort through the id suffix only.
- `gemini-3.1-pro` has no `-medium` id.
- `gpt-6.1-sol` and `gpt-6-luna` both appear in the `codex debug models` catalog; no one-shot run exercised either.

## Example launch config

```bash
# claude
AGENT_LOOP_REVIEWER_MODEL=fable
AGENT_LOOP_HANDS_MODEL=haiku
AGENT_LOOP_REVIEWER_EFFORT=medium
AGENT_LOOP_HANDS_EFFORT=low
```

```bash
# codex
AGENT_LOOP_REVIEWER_MODEL=gpt-6-astra
AGENT_LOOP_HANDS_MODEL=gpt-6-luna
AGENT_LOOP_REVIEWER_EFFORT=medium
AGENT_LOOP_HANDS_EFFORT=low
```

```bash
# agy — effort rides the id suffix
AGENT_LOOP_REVIEWER_MODEL=claude-opus-5-5-high
AGENT_LOOP_HANDS_MODEL=gemini-3.8-flash-medium
```

`high` is a per-run override (ADR 0001 decision 5).

## Adding a harness

- Read its model picker's own capability descriptions.
- Map ids by capability wording, not version number.
- Probe each id and effort value with a one-shot non-interactive run; record the CLI version.
- Mark anything not probed `unverified`.
