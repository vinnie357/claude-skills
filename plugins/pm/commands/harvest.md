---
description: "Harvest implementation-agnostic feature specs from a prototype by spawning a PM team that inventories, separates, assesses, and writes spec artifacts"
argument-hint: "[path-to-prototype] [--output=<dir>]"
---

Harvest implementation-agnostic feature specs from a working prototype. Spawns the `pm-lead` agent, which fans out discovery workers across the prototype's routes/pages, data models, integrations/dependencies/stack, and (when present) a read-only bees map; classifies findings into customer-value features versus prototype shortcuts; runs the SDLC guardrail checklist; and writes markdown spec artifacts.

**What it does:**

1. **Discovery** — `pm-discovery` shards inventory routes/pages, data models, and integrations/deps/stack in parallel, plus a bees map when `.bees/` exists in the prototype. Pure inventory, no judgement, every entry cited to a file path.
2. **Separation** — `pm-separator` spot-verifies sampled claims, classifies each item as a customer-value feature or a prototype shortcut that must not carry forward (zero/minimal auth, hardcoded data, scale/perf assumptions), and drafts WHAT/WHY value statements that pass the portability test.
3. **SDLC assessment** — `pm-sdlc-assessor` walks the licensing/security/supportability checklist from `/pm:spec-harvest`'s `references/sdlc-checklist.md`, evidencing every row.
4. **Spec generation** — `pm-spec-writer` composes the feature-inventory and SDLC-assessment artifacts, then one `pm-prd-author` runs per major feature area in grounded mode to produce a PRD.

Artifacts land under `<OUTPUT_DIR>/`: `<DATE>-feature-inventory.md`, `<DATE>-sdlc-assessment.md`, `prd/<DATE>-<feature-area>.md` per feature area.

**Arguments:**

- `[path-to-prototype]` — absolute or relative path to the prototype repo. When omitted, ask the user where the prototype lives before doing anything else.
- `--output=<dir>` — output directory for artifacts. Default `docs/pm/` under the prototype root.

**Examples:**

```
/pm:harvest ~/github/checkout-prototype
/pm:harvest ../checkout-prototype --output=docs/specs/
```

**Skills the lead loads (no globs — explicit names):**

- `/pm:spec-harvest`
- `/core:agent-loop`
- `/core:anti-fabrication`
- `/core:bees`
- `/claude-code:claude-teams`

**Task instructions:**

Before spawning anything, ask the operator (unless already answered in the invocation): the intended production audience, any known feature areas to prioritize, and the output directory if not already given via `--output`. Resolve `[path-to-prototype]` to an absolute path relative to the current working directory. Verify the path exists (`test -d`) — if not, stop and report. Probe for `<path>/.bees` (existence only). Compute `DATE` as today in `YYYY-MM-DD`. Resolve `OUTPUT_DIR` to an absolute path (default `<path-to-prototype>/docs/pm/`).

Spawn the `pm-lead` subagent with `PROTOTYPE_ROOT=<resolved path>`, `MODE=harvest`, `OUTPUT_DIR`, `DATE`, and `OPERATOR_ANSWERS` set to the clarifying-question responses. Relay the lead's final report to the user, including the artifact paths and the confidence-tag summary.
