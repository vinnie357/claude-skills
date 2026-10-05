# Model tiers per harness

Policy: ADR 0001 decision 5. This file is the only place model ids, effort flags, and
effort values appear. Verified 2026-09-15 against the CLIs named below, except the rows
re-checked 2026-10-05: the codex `general` id against `codex debug models` (codex-cli
0.159.1) and every agy id against `agy models` (Antigravity CLI 1.2.17).

Agent-file `model:` frontmatter values are claude-harness config drawn from the claude
column.

| Tier | claude (Claude Code 2.1.272) | codex (codex-cli 0.154.0) | agy (Antigravity CLI 1.2.3) |
|---|---|---|---|
| strongest reasoning | `fable` | `gpt-6-astra` | `claude-opus-5-5-high` |
| strongest fallback (unavailable only) | `opus` | `gpt-6.1-sol` | `gemini-3.1-pro-high` |
| deep reasoning | `opus` | `gpt-6.1-sol` | `gemini-3.1-pro-high` |
| general | `sonnet` | `gpt-6.1-sol` | `claude-sonnet-5-5-medium` |
| smallest fast | `haiku` (`Explore` agent type for text research) | `gpt-6-luna` | `gemini-3.8-flash-medium` |
| multimodal | unverified | unverified | unverified |
| effort setting | `--effort <level>`; agent `effort:` frontmatter | `-c model_reasoning_effort=<level>` | `--effort <level>` (acceptance per model unverified); every listed id carries effort as a `-low`/`-medium`/`-high` suffix |
| effort values | `low medium high xhigh max` | `gpt-6-astra`: `low medium high xhigh max` (rejects `none`, `minimal`) | `low medium high` as id suffixes; `--help` lists `low medium high xhigh max` for the flag |
| harness default effort | `high` (Claude Code model picker; not listed by `--help`) | unverified | `medium` |

- claude and codex rows follow each harness's model-picker descriptions ("most capable" → strongest … "fast"/"fastest" → smallest fast).
- General tier effort: claude `sonnet` runs at `medium` to `high` (operator decision; `sonnet` currently resolves to Sonnet 5.5 per the operator, unverified by the CLI, which documents only the alias); codex `gpt-6.1-sol` runs at `medium` (listed as a supported level in the `codex debug models` catalog).
- agy ids come from `agy models`: `claude-opus-5-5-{low,medium,high}`, `claude-sonnet-5-5-{low,medium,high}`, `gemini-3.1-pro-{low,high}`, `gemini-3.8-flash-{low,medium,high}`. The effort suffix in each id above is a choice; the other suffixes exist.
- agy's picker shows no descriptions; its row follows the same capability ordering and needs operator validation.
- agy `--effort` support for `claude-opus-5-5-*` and `claude-sonnet-5-5-*` is unverified. An earlier agy release rejected `--effort` for a retired Claude id; that result does not carry over to these ids.
- agy `--model gemini-3.8-flash-medium --effort high` failed ("conflicts with --effort=high") on agy 1.2.3 and was not re-probed on 1.2.17 — pass Gemini effort through the id suffix only.
- `gemini-3.1-pro` has no `-medium` id (`agy models` lists `-low` and `-high` only).
- `gpt-6-luna` comes from the codex configuration and was not probed with a one-shot run. The 2026-09-15 verification date does not cover it. `gpt-6.1-sol` appears in the `codex debug models` catalog; no one-shot run exercised it.

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
