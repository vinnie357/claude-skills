---
description: "Run only the SDLC assessment (licensing, security, supportability) against a prototype and write the assessment artifact"
argument-hint: "[path-to-prototype] [--output=<dir>]"
---

Run only the SDLC guardrail assessment against a prototype — licensing, security, and supportability — without the full feature-harvest pipeline. Spawns the `pm-lead` agent scoped to a single discovery shard (`integrations-deps-stack`) followed by `pm-sdlc-assessor` and `pm-spec-writer`, producing one artifact.

**What it does:**

1. **Discovery (scoped)** — `pm-discovery` inventories dependencies, external integrations, and stack/framework choices only. No routes/pages or data-model shards, no bees map.
2. **SDLC assessment** — `pm-sdlc-assessor` walks the licensing/security/supportability checklist from `/pm:spec-harvest`'s `references/sdlc-checklist.md`, evidencing every row.
3. **Write** — `pm-spec-writer` composes `<OUTPUT_DIR>/<DATE>-sdlc-assessment.md` only. No feature inventory, no PRDs.

**Arguments:**

- `[path-to-prototype]` — absolute or relative path to the prototype repo. When omitted, ask the user where the prototype lives before doing anything else.
- `--output=<dir>` — output directory for the assessment artifact. Default `docs/pm/` under the prototype root.

**Examples:**

```
/pm:assess ~/github/checkout-prototype
/pm:assess ../checkout-prototype --output=docs/specs/
```

**Skills the lead loads (no globs — explicit names):**

- `/pm:spec-harvest`
- `/core:agent-loop`
- `/core:anti-fabrication`
- `/core:bees`
- `/claude-code:claude-teams`

**Task instructions:**

Resolve `[path-to-prototype]` to an absolute path relative to the current working directory; if omitted, ask the operator first. Verify the path exists (`test -d`) — if not, stop and report. Compute `DATE` as today in `YYYY-MM-DD`. Resolve `OUTPUT_DIR` to an absolute path (default `<path-to-prototype>/docs/pm/`).

Spawn the `pm-lead` subagent with `PROTOTYPE_ROOT=<resolved path>`, `MODE=assess`, `OUTPUT_DIR`, `DATE`. No `OPERATOR_ANSWERS` clarifying pass is required for assessment-only runs — the scope is fixed to the SDLC checklist. Relay the lead's final report to the user, including the artifact path and the confidence-tag summary.
