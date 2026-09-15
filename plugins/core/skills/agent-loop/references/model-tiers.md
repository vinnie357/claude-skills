# Model tiers per harness

Policy: ADR 0001 decision 5. This file is the only place model ids, effort flags, and
effort values appear. Verified 2026-09-15 against the CLIs named below.

Agent-file `model:` frontmatter values are claude-harness config drawn from the claude
column.

| Tier | claude (Claude Code 2.1.272) | codex (codex-cli 0.154.0) | agy (Antigravity CLI 1.2.3) |
|---|---|---|---|
| strongest reasoning | `fable` | `gpt-6-astra` | `claude-opus-4-6-thinking` |
| strongest fallback (unavailable only) | `opus` | `gpt-5.6-sol` | `gemini-3.1-pro-high` |
| deep reasoning | `opus` | `gpt-5.6-sol` | `gemini-3.1-pro-high` |
| general | `sonnet` | `gpt-5.6-terra` | `claude-sonnet-4-6` |
| smallest fast | `haiku` (`Explore` agent type for text research) | `gpt-5.6-luna` | `gemini-3.8-flash-medium` |
| multimodal | unverified | unverified | unverified |
| effort setting | `--effort <level>`; agent `effort:` frontmatter | `-c model_reasoning_effort=<level>` | `--effort <level>` on models that accept it; Gemini ids carry effort as a `-low`/`-medium`/`-high` suffix |
| effort values | `low medium high xhigh max` | `gpt-6-astra`: `low medium high xhigh max` (rejects `none`, `minimal`) | `low medium high` |
| harness default effort | `high` (Claude Code model picker; not listed by `--help`) | unverified | `medium` |

- claude and codex rows follow each harness's model-picker descriptions ("most capable" → strongest … "fast"/"fastest" → smallest fast).
- agy's picker shows no descriptions; its row follows the same capability ordering and needs operator validation.
- agy rejects `--effort` for `claude-opus-4-6-thinking` ("--effort is not supported") — its Claude models take no effort setting, and `claude-sonnet-4-6` effort is unverified.
- agy `--model gemini-3.8-flash-medium --effort high` fails ("conflicts with --effort=high") — pass Gemini effort through the id suffix only.
- `gemini-3.1-pro` has no `-medium` id.
- gpt-5.5 and older Flash ids map to no tier.

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
AGENT_LOOP_HANDS_MODEL=gpt-5.6-luna
AGENT_LOOP_REVIEWER_EFFORT=medium
AGENT_LOOP_HANDS_EFFORT=low
```

```bash
# agy — omit effort for Claude ids; Gemini effort rides the id suffix
AGENT_LOOP_REVIEWER_MODEL=claude-opus-4-6-thinking
AGENT_LOOP_HANDS_MODEL=gemini-3.8-flash-medium
```

`high` is a per-run override (ADR 0001 decision 5).

## Adding a harness

- Read its model picker's own capability descriptions.
- Map ids by capability wording, not version number.
- Probe each id and effort value with a one-shot non-interactive run; record the CLI version.
- Mark anything not probed `unverified`.
