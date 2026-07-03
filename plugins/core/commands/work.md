---
description: "Run Forge (the agent-loop default operating model) on an epic, an issue, or the next ready item"
argument-hint: "<epic-id> | <issue-id> | ready"
---

Work the target with **Forge** — the agent-loop operating model. Target: `$ARGUMENTS`

## First, load skills

Invoke the Skill tool for each by exact name before any other step:

- `/core:anti-fabrication`
- `/core:git`
- `/core:tdd`
- `/core:twelve-factor`
- `/core:restraint`
- `/core:security`
- `/core:mise`
- `/core:nushell`
- `/core:agent-loop` (carries Forge: paired teams, the hands pattern, fan-out)
- `/core:bees` (the tracker)
- `/claude-code:claude-agents` (always, before spawning) and `/claude-code:claude-teams` (when spawning ≥2 parallel workers)

Canonical list: `/core:agent-loop` "Core Skills (Mandatory)"; drift-checked in CI.

Quote one sentence from `/core:agent-loop` describing Forge as proof of loading.

## Resolve the target

- `ready` (or empty) → run `bees ready` and take the top item.
- An epic id (e.g. `VIN-42`) → work the epic: run Phase 1.5 decomposition gate, then Forge per issue.
- An issue id (e.g. `claude-skills-77`) → work that single issue with Forge.

## Run Forge

Apply the agent-loop 4-phase execution with Forge as the operating model — no need to ask which tier system to use, Forge is the default:

1. **Pre-flight** — load skills (above), confirm the tracker item, branch from fresh `origin/main` (`feat/<slug>`).
2. **Plan** — spawn a Test Planner (opus) preceded by a hands pass that builds its `## Starting index`; the planner slices the issue into independent test groups. See `references/forge.md`.
3. **Author + review tests** — Test Author (sonnet) writes failing tests; the Test Reviewer (opus, with haiku hands) verifies plan-conformance and non-redundancy before any implementor starts.
4. **Implement (fan out)** — one Implementor + Test Runner pair per slice, dispatched in dependency waves. `N=1` for a one-slice issue.
5. **Review** — Reviewer then Final Reviewer (opus, each with haiku hands consuming a startup index, never searching themselves); review findings route to a Remediation pair, then re-review.
6. **Validate + submit** — `mise run ci` green, gitleaks, push, open the PR. Agents never merge — report the PR URL and wait for operator approval.

Principals never run their own `Grep`/`Glob`/large-`Read` sweeps — they spawn focused read-only hands and read only the returned `file:line` index. Vision research (screenshots, rendered pages, Playwright output) uses a multimodal hands model. See the hands pattern in `references/researcher.md`.
