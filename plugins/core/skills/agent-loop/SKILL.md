---
name: agent-loop
description: Generic epic-to-PR agent workflow (codename Forge) with 4-phase execution, a 6-tier hierarchy, and paired-team fan-out. Use when coordinating any feature delivery, working an issue or epic ("work epic <id>", "work issue <id>", "use Forge on the next bees ready item", "forge <id>"), picking up an epic in a fresh session (decomposing path) or with pre-existing issues (dispatching path), implementing a multi-step task that benefits from plan→test→implement→review phases, asking clarifying questions before decomposing, forming a team and assigning models per tier, or orchestrating multi-agent workflows. Loads on casual feature requests too — not only when the word "epic" appears.
license: MIT
---

# Agent Loop

Defines the standard workflow for agents working epics, issues, and tasks through a 4-phase execution model with a 6-tier prompt hierarchy.

## Forge — the default operating model

**Forge** is the name for how this skill works an issue: paired teams of strong-model principals and cheap read-only **hands**, fanned out across the issue's slices, with reviewers on the best-thinker model. Forge is the implied default for all work — the lead applies it without being told to "use the 5/6-tier system."

Activate Forge by work phrasing ("work epic/issue <id>", acting on `bees ready`), by `forge <id>` in a mission / spawn prompt, or by the `/work` command in an interactive session — all load this skill and run Forge on the target.

Two disciplines make Forge cheap and reliable:

- **Hands do the searching.** Principals (planners, reviewers) never run their own `Grep`/`Glob`/large-`Read` sweeps. They spawn focused read-only hands on the smallest fast model, receive a `file:line` index, and `Read` only those lines. See `references/researcher.md`.
- **Paired teams fan out.** Every issue runs the same paired structure; fan-out width `N` = the planner's slice count (`N=1` for a small issue, same path). See `references/forge.md`.

## Required plugins

Assumes both `core@vinnie357` (this plugin) and `claude-code@vinnie357` (agent/team file formats, referenced by name in spawning steps) are installed. Standalone `core` still describes the workflow, but cross-plugin skill names like `/claude-code:claude-agents` won't resolve until `claude-code@vinnie357` is installed too — treat those references as procedural-only until then.

## 4-Phase Execution

Every agent, regardless of tier, follows these four phases:

| Phase | Name | Purpose |
|-------|------|---------|
| 1 | Pre-flight | Load skills, check tracker, verify branch, understand assignment |
| 2 | Working | Execute work items. **Before any spawn**: re-verify core skills loaded, load `/claude-code:claude-agents` always, load `/claude-code:claude-teams` for ≥2 parallel workers. |
| 3 | Validation | Run strictest CI suite, iterate with fix agent until clean |
| 4 | Submit | Create PR, wait for CI, report to upstream, clean up after merge |

## Phase 1.5: Decomposition Gate

Between Phase 1 (pre-flight) and Phase 2 (spawn), the Team Leader checks two deterministic signals — no file searching:

1. **bees:** `bees list --epic <slug>` — does the epic already have issues?
2. **`DECOMPOSITION_PATH` env var:** is it set AND does the file it points at exist? This is the canonical signal an upstream process sets to hand off a pre-computed proposal.

| State | bees | `DECOMPOSITION_PATH` | Action |
|-------|------|----------------------|--------|
| A | Has issues | Unset, OR set+missing | Skip Phase 1.5a. Spot-check each issue (AC, skill labels, dep edges). Flag gaps, proceed. |
| B | Empty | Unset, OR set+missing | Run Phase 1.5a — produce the decomposition from the epic objective + AC, record assumptions, decompose into bees. Ask only on a genuine fork or hard blocker. |
| C | Empty | Set + file exists | Consume the proposal verbatim — `bees create` one issue per proposed item with AC, skill labels, and dep edges as written. Topological order (deps before dependents); map `depends_on` titles to bee IDs returned by prior `bees create` calls as you go. If any cycle is detected in the dep graph (2-cycle X↔Y, 3-cycle A→B→C→A, or longer), halt and report all cycle members — create zero issues. No clarifying questions. Spot-check after, proceed. |
| D | Has issues | Set + file exists | Resume gap — diff proposal titles vs existing bees titles. Materialize each missing proposed item with the same rules as State C (topological order, cycle detection). Spot-check the complete set, proceed. Never re-ask, never re-decompose. |

**Robustness:**
- Empty string (`""`) for `DECOMPOSITION_PATH` = unset — no log, proceed as State A or B per the bees-state column.
- Set but file missing: emit exactly one line — `agent-loop: DECOMPOSITION_PATH=<value> not found; proceeding as State <B|A>` (B if bees empty, A if bees has issues). No retry, no search, no crash.
- Never search for proposal files outside `DECOMPOSITION_PATH`. Unset or empty = no proposal, full stop.

**Proposal file format:** this skill mandates only the consumption rules above; the file's on-disk schema is defined by whatever upstream process produces it. A minimum interoperable shape is a JSON array of issues each carrying `title`, `acceptance_criteria` (list), `labels` (list), and `depends_on` (list of titles or stable local keys that resolve to other entries in the same file).

### Phase 1.5a: Default to proceeding (State B only)

Plan presence, not who is at the keyboard, is the operative question. A plan is PRESENT when `DECOMPOSITION_PATH` is set and the file exists, OR bees already has issues, OR an upstream proposal exists. States A / C / D are plan-present — consume, spot-check, or resume and proceed; never ask clarifying questions there.

State B is plan-absent: the lead PRODUCES the decomposition from the epic objective and acceptance criteria, records assumptions as a bees comment (audit trail), and proceeds on the most reasonable interpretation.

Reserve AskUserQuestion for a genuine architectural fork the user owns that can't be responsibly defaulted, or a hard blocker: missing repository, missing credential, or contradictory acceptance criteria with no clear winner. A preference question — "approach A or B?" — is NOT a blocker; pick the reasonable default, record it, proceed.

When escalating, group related questions into a single AskUserQuestion call (max 4 questions, 2–4 options each) — never one at a time. Once a decision is judged a genuine fork the user owns, ask rather than guess. Doesn't apply to single-file mechanical refactors, status checks, or log diagnosis.

Applies in every context: a host running without a human supplies the plan (State C fires); with no plan, the default is still proceed-on-reasonable-default.

## 6-Tier Prompt Hierarchy

These six tiers describe authority — who reports to whom across an epic. For the orthogonal axis of how a single issue flows through staged agents, see "Five-Tier Decomposition Pipeline" below.

| Tier | Role | Scope | Default Model | Reference |
|------|------|-------|---------------|-----------|
| 0 | Epic Author | Write machine-executable epics | human | `references/epic-authoring.md` |
| 1 | Team Leader | Four-state gate (spot-check / consume proposal / ask+decompose / resume gap); spawn agents | opus | `references/team-leader.md` |
| 2 | Sub-team Leader | Decompose issue into tasks, manage workers | sonnet | `references/sub-team-leader.md` |
| 3 | Agent Worker | Execute a single task with TDD | haiku | `references/agent-worker.md` |
| 4 | Validator | Run CI, report all failures, never fix | haiku | `references/validator.md` |
| 5 | Fix Agent | Receive failures, fix code, re-run tests | haiku | `references/fix-agent.md` |

## Model overrides (env-var convention)

Model defaults per tier are exactly that — defaults. Each tier honors an env var so a deployment can swap models when a new family ships, without changing the spawn script (12-factor config):

| Tier | Env var | Default |
|------|---------|---------|
| 1 Team Leader | `AGENT_LOOP_LEAD_MODEL` | `opus` |
| 2 Sub-team Leader | `AGENT_LOOP_SUBLEAD_MODEL` | `sonnet` |
| 3 Agent Worker | `AGENT_LOOP_WORKER_MODEL` | `haiku` |
| 4 Validator | `AGENT_LOOP_VALIDATOR_MODEL` | `haiku` |
| 5 Fix Agent | `AGENT_LOOP_FIX_MODEL` | `haiku` |
| Research hands (text) | `AGENT_LOOP_HANDS_MODEL` | smallest fast model (`Explore`) |
| Research hands (vision) | `AGENT_LOOP_HANDS_VISION_MODEL` | a multimodal-capable model the harness offers |

The two hands vars follow the same contract as the tier vars: the launching process resolves them and passes the model to the spawn; no model name appears as a literal in the prompt body. The vision var is set by capability, not by a fixed name — the available multimodal model shifts with the harness and model family. See `references/researcher.md`.

**Contract:** whoever launches the spawning process (shell command, CI job, parent Claude session, external orchestrator) sets these env vars; the spawn script reads `$AGENT_LOOP_*` and passes the resolved model to the Task tool invocation (`subagent_type`/`model` argument) — never as a literal in the prompt body. An empty string (`AGENT_LOOP_LEAD_MODEL=""`) is treated identically to unset, falling through to the default, so orchestrators can emit "" to mean "use default" without special-casing.

The escalation chain is also overridable: `AGENT_LOOP_ESCALATION_CHAIN` (comma-separated names; default `haiku,sonnet,opus`).

## Model Escalation

Default assignment starts at haiku. On repeated failure (2 attempts on same work item):

```
haiku -> sonnet -> opus
```

Maximum 2 promotions per agent. If opus fails, escalate to the upstream tier (sub-lead to lead, lead to user).

## Five-Tier Decomposition Pipeline

The 6-tier hierarchy above describes WHO reports to whom (authority). The five-tier pipeline below describes HOW one work item flows through five sequential agents (process). They are orthogonal: a Sub-team Leader (tier 2 authority) dispatches a pipeline (process) to deliver one issue.

The five roles below are the linear `N=1` form; **Forge** (`references/forge.md`) is the canonical shape that generalizes them to paired teams and `N`-slice fan-out, with identical role-to-model defaults and adversarial separation.

For each issue, the Sub-team Leader spawns distinct Agent invocations in order. No shared context across stages — each stage is adversarial against the next.

| Pipeline Stage | Model | Responsibility | Forbidden |
|----------------|-------|----------------|-----------|
| P1 Test Planner | opus | Translate acceptance criteria into ordered test list + edge cases | Writing code or tests |
| P2 Test Author | sonnet | Write failing tests against P1's spec | Reading impl source; modifying after handoff |
| P3 Implementer | sonnet | Make tests pass | Modifying test files; reading P2's chat context |
| P4 CI Runner | haiku | Run CI, capture verbatim output, report green/red | Judging correctness; touching code |
| P5 Reviewer | opus | Verify tests exercise AC, no overfit, no missed edges | Authoring fixes (sends back to P2 or P3 with findings) |

Each stage owes the restraint ladder its phase duty — see `/core:restraint`'s agent-loop-phases reference for the row mapping (P1 → Test planning, P2 → Test authoring, P3 → Implementation, P5 → Review).

### When to apply

Apply for multi-file changes, public API surfaces (HTTP/exported/schema), cross-repo work, or any issue carrying explicit acceptance criteria. Single-agent stays acceptable for one-liners, mechanical refactors, status checks, and log diagnosis. When in doubt, decompose.

Fan-out happens at the Sub-team Leader, not at the epic decomposer or the bees-worker. Decomposition produces one bees issue per slice; the leader picking up the issue is the one that spawns the five stages.

### Orchestration rules

- Each stage is a separate Agent invocation (no SendMessage continuations between tiers).
- The leader verifies stage transitions before dispatching the next: test commit present before P3, test files unmodified before P5.
- P4 reports verbatim CI output; on red the leader dispatches a fresh P3 (no chat continuity).
- P5 reads `git diff main...HEAD`, tests, and the acceptance criteria; approves with one line or rejects with a structured findings list. P5 reviews per `/core:code-review`, including its Restraint and Scope checklist item.
- bees issues carry a single `complexity:complex` or `complexity:trivial` label, not tier labels. The Sub-team Leader picks up the issue, reads complexity, and (for complex) dispatches the five stages internally — each Task spawn prompt names its tier (`team:opus-planner` ... `team:opus-review`) as dispatch-time metadata. Tier labels never land on bees rows. See `/core:bees`.
- The five stages run as Task spawns by default. When Claude Code workflows are available and the operator opts in, encode them as one workflow script instead — the stage gates become deterministic assertions. See "Optional: workflow execution substrate" below and `references/workflows-execution.md`.

### Avoiding pipeline collapse

Single agents tend to merge planning + test-writing + implementation into one pass, defeating the adversarial separation. The leader prompt MUST explicitly name the stage (`You are P2 — test author for issue <id>`) and forbid out-of-stage activity.

## Delegated research — the hands pattern

The costly principals (Test Planner, Test Reviewer, Reviewer, Final Reviewer) delegate all search to hands (see the Forge disciplines above). Select the hands model by capability, set in config — never a hardcoded name: text and code research use the smallest fast model (`AGENT_LOOP_HANDS_MODEL`); research that requires vision (images, screenshots, rendered web pages, visual PDFs, Playwright or visual MCP output) uses a multimodal-capable model the harness offers (`AGENT_LOOP_HANDS_VISION_MODEL`). Full contract in `references/researcher.md`; `references/dispatch-discipline.md` carries the delegate-before-you-search rule.

## Core Skills (Mandatory)

Every agent at every tier loads these before any work, with one bounded exemption below:

```
/core:anti-fabrication
/core:git
/core:tdd
/core:twelve-factor
/core:restraint
/core:security
/core:mise
/core:nushell
/core:agent-loop
/core:bees
```

This block is the canonical copy. `test/validate-core-list.nu` drift-checks it against the eight sites it lists — this skill, four tier references, `/core:work`, the core session-start hook, and the operator CLAUDE.md template. Other files that enumerate core skills are not covered; add a site to that script when it starts carrying the full stack.

**The exemption: a tier may omit an individual skill its role cannot exercise — nothing more.** Apply the test per skill, not per tier. `/core:tdd` is the worked case: `references/validator.md` runs the suite and reports failures without writing code, so it omits `/core:tdd`; `references/fix-agent.md` writes the fix, so it keeps it. `/core:anti-fabrication` is never omissible — every tier reports, and a fabricated pass is worse than a red build. A subsetting tier states what it omits and why in its own pre-flight step, so the omission is a decision on the record rather than an accident.

Two limits on how far this is enforced. What a subsetting tier *names* is checked: the `invocations` check in `test/validate-skills-quality.nu` scans `references/` and fails the run on any `/plugin:skill` token that does not resolve, so a stale or misspelled name cannot survive a core-list change. What a tier *omits* is not checked — a tier that drops a skill it should carry passes CI, and only review catches it.

Domain-specific skills activate from their own `Use when` descriptions — that is the discovery mechanism at every tier. Two rules descriptions cannot express:

- **Tracker state:** a repo tracked by beads loads `/core:beads` in place of `/core:bees`.
- **Issue labels:** load the domain-plugin skills named by the issue's labels, by exact name.

Enforcement, not description, carries a third rule: leaders name every skill explicitly in the spawn prompt's `## Load skills` block — globs do not expand, and listed is not loaded.

### Skills to load before spawning

When a leader (Tier 1 or Tier 2) prepares to spawn an agent, load these by exact name with the Skill tool:

- `/claude-code:claude-agents` — always. Carries agent file format, tool allowlists, and model selection.
- `/claude-code:claude-teams` — if forming a team or spawning ≥2 parallel workers. Carries peer-to-peer messaging, shared task list, Agent SDK patterns.
- `/claude-code:plugin-marketplace` — when the spawned agent needs a skill not already in the team's load list.

Glob patterns like `/core:*` do not expand in Agent prompts. List skill names explicitly.

## Key Conventions

- **Tracker**: Use bees (`bees ready`, `bees close`) for issue management
- **Commits**: Conventional commits, no attribution, no Co-Authored-By
- **PRs**: Minimal format (title + bullet list), no templates, no attribution
- **TDD**: Code without tests is not complete
- **Merge gates (three)**: Gate 1 — local `mise run ci` green before every commit; Gate 2 — local + remote `gh pr checks` green; Gate 3 — adversarial review of the PR by a separate agent on the strongest available model, findings addressed or answered. All three before any squash merge (see `/core:git` Three-Gate Merge Policy). Gate 3 is distinct from this skill's pipeline reviewers, including Forge's Final Reviewer — it is identified by its defeat-the-change brief, not by when it runs.
- **Branches**: One feature branch per epic (`feature/<epic-slug>`)
- **Merge**: Squash merge only, user approves

## Agent Worker Execution Order

Every agent worker (Tier 3) follows these steps:

1. Create feature branch
2. Write tests first (TDD)
3. Implement
4. **Gate 1** — Run local CI (`mise run ci`) — fix until 0 failures
5. Commit without attribution
6. Run gitleaks scan on committed changes — fix if secrets detected
7. Push, create PR
8. **Gate 2** — Watch remote CI (`gh pr checks --watch`) — fix and push until local + remote are green
9. Close bees issue, notify leader of PR status and URL. The PR is NOT merge-ready yet: **Gate 3** — adversarial review by a separate agent — is the leader's to arrange, and merge waits on it

Agents never merge — they report the PR URL to the team leader.

## Agent Prompt Template

Team leaders structure agent prompts with these sections:

```
## Load skills
<every name from "Core Skills (Mandatory)", one per line — never this placeholder, never a glob>
<domain skills for this task, per the issue's labels and the tracker-state rule>

## Working directory
cd /path/to/repo

## Bees issue
<issue-id>: <title>

## Context
<what exists, what's needed, why>

## What to implement
<specific files, existing functions to reuse, code patterns>

## Rules
<project-specific constraints>

## Execution order
<the 9 steps above>
```

Canonical list: `/core:agent-loop` "Core Skills (Mandatory)"; drift-checked in CI.

Key: always reference existing code and functions to reuse. "Implement X" is vague — "add import/2 action to WorkflowController, reuse serialize_workflow/1 from line 28" is machine-executable.

### Proof of loading

Require each spawned agent to quote one sentence from each loaded skill in its first response. Do not proceed with the agent's work until proof is received. Listing skill names in the prompt is not the same as the agent loading them — proof prevents skipped loads.

### Leader spawn — concrete example

See `references/leader-spawn-example.md` for a worked Phoenix-endpoint Task-tool prompt. The mandatory `/core:*` skill list at the top of any spawn prompt is enumerated in "Core Skills (Mandatory)" above — never use globs in spawn prompts (they don't expand).

## Model Selection

Scale the team to the work — choose by role, not by a trivial-vs-complex guess:

| Role | Model | Examples |
|------|-------|---------|
| Multi-file implementation | sonnet | New API endpoint, adapter refactor |
| Test planning, architecture design | opus (or `Plan` subagent) | Test-list design, system integration |
| Simple ops, monitoring, status checks | haiku | Deploy monitor, log reader, port check |

Hands and reviewer models follow the Forge convention — see "Model overrides" above and `references/forge.md`.

## Secret Safety

Agents must NEVER read, print, or report actual secret values (API keys, tokens, passwords). Only confirm secrets exist and are non-empty:

```bash
# WRONG — exposes the secret
op item get "KEY" --vault Vault --fields credential --reveal

# RIGHT — confirms it's set without exposing
test -n "$(op item get KEY --vault Vault --fields credential 2>/dev/null)" && echo "set" || echo "empty"
```

## Tool Preferences

- **JSON parsing**: Use `jq`, not `python3 -c "import json..."`
- **Scripting**: Nushell (`.nu`), not bash — cross-platform, structured data
- **Infrastructure**: parameterized workflow tools, not direct SSH
- **Tool management**: mise, not brew — portable across macOS and Linux
- **Issue tracking**: bees, not beads

## The Layered Model

- **Epic** -- what the user writes. Objective, skills, constraints. No implementation details.
- **Issues** -- created by team leader. Independently deliverable slices with acceptance criteria.
- **Tasks** -- created by agents. Granular implementation steps, invisible to the user.

## Usage

Load the reference matching your assigned role:

```
Team Leader    -> Read references/team-leader.md
Sub-team Leader -> Read references/sub-team-leader.md
Agent Worker   -> Read references/agent-worker.md
Validator      -> Read references/validator.md
Fix Agent      -> Read references/fix-agent.md
Epic Author    -> Read references/epic-authoring.md
```

## Spec-Driven Epics (optional)

Epics may include a `spec:` field pointing to a `.allium` behavioral spec file (e.g., `spec: docs/specs/<epic-slug>.allium`). When present:

- The team leader checks for the spec in Phase 1. On a refactor epic without a `spec:` field, run `/allium:distill` to derive a baseline spec from existing code before decomposition.
- Agent workers invoke `/allium:propagate` to seed failing test skeletons before implementation.
- The validator invokes `/allium:weed` after CI passes to flag spec/code divergence.

Epics WITHOUT a `spec:` field behave exactly as today — all spec-driven steps are no-ops. Requires the upstream allium plugin: `/plugin install allium@juxt`. See `/allium:allium` for full integration details.

## Optional: workflow execution substrate

Claude Code dynamic workflows are an optional runtime for the five-tier pipeline. When available and opted-in, the Sub-team Leader encodes one issue's pipeline as a workflow script instead of dispatching five Task spawns — the adversarial separation and stage gates (`test files unmodified before P5`, `mise run ci` green before review) become deterministic script assertions, model escalation becomes a retry ladder, and the validator↔fix iteration becomes a bounded loop. `isolation: 'worktree'` gives each parallel implementer its own tree, replacing the shallow-clone workaround for working-tree contention.

The boundary: decomposition, any Phase 1.5a escalation (the rare fork-or-blocker AskUserQuestion), and merge approval stay in the interactive loop — a workflow has no mid-run user input. The workflow executes already-decomposed issues (gate States A/C/D); it never decomposes them.

The Forge shape encodes the same way at larger fan-out: `templates/forge-issue.workflow.js` is the runnable `/forge-issue` workflow — a startup-index hands pass per principal, planner slicing, dep-wave `parallel()` implementor + test-runner fan-out, and the remediation pair.

Workflows are a research preview on paid plans. When disabled, the default Task-spawn path applies unchanged. See `references/workflows-execution.md` and the `/claude-code:claude-workflows` skill.

## References

- `references/forge.md` -- The Forge operating model: paired teams (principal + cheap hands), implementation fan-out (N pairs by slice), reviewers as the best-thinker tier, startup-index handoff, gates between pairs
- `references/researcher.md` -- The hands pattern: read-only focused research, startup vs on-demand modes, the `file:line` index output contract, capability-based `AGENT_LOOP_HANDS_MODEL` / `AGENT_LOOP_HANDS_VISION_MODEL` selection
- `references/team-leader.md` -- Epic decomposition, team formation, orchestration
- `references/sub-team-leader.md` -- Issue decomposition, worker management, model escalation
- `references/agent-worker.md` -- Task execution with TDD, skill loading, reporting
- `references/validator.md` -- Strictest CI per language, structured failure reporting
- `references/fix-agent.md` -- CI failure remediation, test fixing, escalation
- `references/epic-authoring.md` -- User guide for writing machine-executable epics
- `references/leader-spawn-example.md` -- Worked Phoenix-endpoint Team Leader spawn prompt with explicit `/core:*` + `/elixir:*` skill list
- `references/dep-doc-introspection.md` — Staged-pipeline prompts name the runtime-introspection tools AND the specific deps touched, never abstract "use the introspection tools"
- `references/no-todos.md` — Implementer prompts ban TODO/FIXME/XXX/HACK/KLUDGE/DEFERRED markers, enforced by pre-commit grep; tempted workers escalate-or-implement-now instead of punting scope via a comment
- `references/dispatch-discipline.md` — Spawn-prompt rules: explicit model, specialized subagent types, lead delegates all execution, fresh-main branch creation, read-only agents never mutate the shared tree (scratchpad clone instead), no polling, host-inspection over claims, ADR search before proposing architecture
- `references/secret-provisioning.md` — Tier 1 plans include symmetric secret provisioning (generation, store creation, prod/dev deploy diffs); Tier 5 blocker check
- `references/workflows-execution.md` — Optional workflow substrate for the five-tier pipeline: pipeline-as-script, stage gates, escalation ladder, teams-of-teams; decomposition/merge stay interactive
- `templates/five-tier-issue.workflow.js` — Runnable `N=1` five-tier pipeline template: stage prompts, `skillProof` schemas, diff-boundary gate, escalation ladder, bounded fix loop
- `templates/forge-issue.workflow.js` — Runnable Forge workflow: startup-index hands, planner slicing, dep-wave fan-out, opus reviewers with haiku hands, remediation pair
