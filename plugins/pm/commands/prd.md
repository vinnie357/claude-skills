---
description: "Author a structured PRD as an implementation contract via the pm-prd-author questionnaire agent"
argument-hint: "<feature-area-slug> [--inventory=<path>] [--output=<dir>]"
---

Author a Product Requirements Document via the `pm-prd-author` agent. The PRD is the implementation contract between product intent and the team that builds it — human or agent — and stays at the WHAT/WHY altitude, never naming implementation technologies.

**What it does:**

1. **Validate the slug** — `<feature-area-slug>` must match `^[a-z0-9]+(-[a-z0-9]+)*$`. Reject and stop otherwise.
2. **Resolve mode** — `--inventory=<path>` present → `MODE=grounded`, the file at `<path>` is a `/pm:spec-harvest` feature inventory, no interview. Absent → `MODE=interactive`; this session conducts the interview below and collects `OPERATOR_ANSWERS`.
3. **Resolve OUTPUT_DIR** — `--output=<dir>` if provided, otherwise `docs/pm/`.
4. **Compute DATE** — today, ISO format (`YYYY-MM-DD`).
5. **Pre-check for overwrite** — confirm `<OUTPUT_DIR>/prd/<DATE>-<feature-area-slug>.md` does not already exist. Refuse and stop if it does.
6. **Spawn `pm-prd-author`** with the Input contract below.

**Interview (interactive mode only, conducted by THIS session, never by the spawned agent):**

`pm-prd-author` runs as a Task-spawned subagent — it has no `AskUserQuestion` tool and no conversational channel to the operator. This session is the only place in the flow with a live channel, so it conducts the interview itself, before spawning the agent, using `AskUserQuestion`. Ask in this order, grouped into two calls (max 4 questions per call), each question offering a free-text `Other` option for answers that do not fit a preset choice:

- **Call 1** (4 topics): problem / opportunity; target users & personas; goals & success metrics; non-goals / out of scope.
- **Call 2** (3 topics): user stories + acceptance criteria; constraints & dependencies; release phasing.

Record each answer under its topic label. If the operator has no answer for a topic, leave that topic absent from `OPERATOR_ANSWERS` rather than inventing one — `pm-prd-author` turns an absent topic into an Open Questions row.

**Input contract passed to `pm-prd-author`:**

- `MODE` — `interactive` or `grounded`
- `FEATURE_AREA` — the validated `<feature-area-slug>`
- `INVENTORY_PATH` — the `--inventory` path (grounded mode only)
- `OPERATOR_ANSWERS` — interactive mode only; the topic-labeled answers collected by the interview above
- `OUTPUT_DIR` — resolved output directory
- `DATE` — resolved ISO date

**Examples:**

```
/pm:prd checkout-flow
/pm:prd checkout-flow --output=docs/product/
/pm:prd checkout-flow --inventory=docs/pm/2026-07-15-feature-inventory.md
```

**Skills the agent loads (no globs — explicit names):**

- `/pm:prd`
- `/pm:spec-harvest`
- `/core:anti-fabrication`
