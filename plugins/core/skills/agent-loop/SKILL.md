---
name: agent-loop
description: Generic epic-to-PR agent workflow with 4-phase execution and 6-tier prompt hierarchy. Use when spawned to work an epic, issue, or task as part of an agent team, orchestrating multi-agent workflows, or decomposing work into issues and tasks.
license: MIT
---

# Agent Loop

Defines the standard workflow for agents working epics, issues, and tasks through a 4-phase execution model with a 6-tier prompt hierarchy.

## Required plugins

This skill's multi-agent workflow assumes both plugins are installed:

- `core@vinnie357` (this plugin) — provides agent-loop, anti-fabrication, tdd, mise, nushell, security, bees
- `claude-code@vinnie357` — provides claude-agents, claude-teams, plugin-marketplace, claude-hooks; carries the agent file format and team architecture knowledge that the spawning steps below reference by name

When `core` is installed standalone, the spawning sections still describe the workflow but the cross-plugin skill names (e.g., `/claude-code:claude-agents`) do not resolve. Install `claude-code@vinnie357` for the full agent-loop experience, or treat those references as procedural-only.

## 4-Phase Execution

Every agent, regardless of tier, follows these four phases:

| Phase | Name | Purpose |
|-------|------|---------|
| 1 | Pre-flight | Load skills, check tracker, verify branch, understand assignment |
| 2 | Working | Execute work items. **Before any spawn**: re-verify core skills loaded, load `/claude-code:claude-agents` always, load `/claude-code:claude-teams` for ≥2 parallel workers. |
| 3 | Validation | Run strictest CI suite, iterate with fix agent until clean |
| 4 | Submit | Create PR, wait for CI, report to upstream, clean up after merge |

## 6-Tier Prompt Hierarchy

| Tier | Role | Scope | Default Model | Reference |
|------|------|-------|---------------|-----------|
| 0 | Epic Author | Write machine-executable epics | human | `references/epic-authoring.md` |
| 1 | Team Leader | Decompose epic into issues, spawn agents | sonnet | `references/team-leader.md` |
| 2 | Sub-team Leader | Decompose issue into tasks, manage workers | sonnet | `references/sub-team-leader.md` |
| 3 | Agent Worker | Execute a single task with TDD | haiku | `references/agent-worker.md` |
| 4 | Validator | Run CI, report all failures, never fix | haiku | `references/validator.md` |
| 5 | Fix Agent | Receive failures, fix code, re-run tests | haiku | `references/fix-agent.md` |

## Model Escalation

Default assignment starts at haiku. On repeated failure (2 attempts on same work item):

```
haiku -> sonnet -> opus
```

Maximum 2 promotions per agent. If opus fails, escalate to the upstream tier (sub-lead to lead, lead to user).

## Core Skills (Mandatory)

Every agent at every tier loads these before any work:

```
/core:anti-fabrication
/core:git
/core:tdd
/core:twelve-factor
/core:security
/core:mise
/core:nushell
```

Domain-specific skills load based on issue/task labels.

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
- **CI**: `mise run ci` must pass before any PR or merge
- **Branches**: One feature branch per epic (`feature/<epic-slug>`)
- **Merge**: Squash merge only, user approves

## Agent Worker Execution Order

Every agent worker (Tier 3) follows these steps:

1. Create feature branch
2. Write tests first (TDD)
3. Implement
4. Run local CI (`mise run ci`) — fix until 0 failures
5. Commit without attribution
6. Run gitleaks scan on committed changes — fix if secrets detected
7. Push, create PR
8. Watch remote CI (`gh pr checks --watch`) — fix and push until passing
9. Close bees issue, notify leader of PR status and URL

Agents never merge — they report the PR URL to the team leader.

## Agent Prompt Template

Team leaders structure agent prompts with these sections:

```
## Load skills
/core:anti-fabrication
/core:git
/core:tdd
/core:security
/core:mise
/core:nushell
<domain-specific skills based on task>

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

Key: always reference existing code and functions to reuse. "Implement X" is vague — "add import/2 action to WorkflowController, reuse serialize_workflow/1 from line 28" is machine-executable.

### Proof of loading

Require each spawned agent to quote one sentence from each loaded skill in its first response. Do not proceed with the agent's work until proof is received. Listing skill names in the prompt is not the same as the agent loading them — proof prevents skipped loads.

### Leader spawn — concrete example

Team leader's Task-tool prompt for an Elixir worker on a Phoenix endpoint:

```
## Load skills
/core:anti-fabrication
/core:git
/core:tdd
/core:security
/core:mise
/core:nushell
/elixir:phoenix-framework
/elixir:elixir-testing
/elixir:style

## Working directory
cd /Users/vinnie/github/runex

## Bees issue
runex-142: add /api/workflows/import endpoint

## Context
WorkflowController already exposes /export at lib/runex_web/controllers/workflow_controller.ex:14. Mirror that pattern for import. Existing serializer Runex.Workflow.serialize/1 at lib/runex/workflow.ex:28 — reuse it inverse for deserialize.

## What to implement
- POST /api/workflows/import accepting JSON body
- New action import/2 in WorkflowController
- Reuse Runex.Workflow.deserialize/1 (already exists at line 41)
- Tests in test/runex_web/controllers/workflow_controller_test.exs

## Rules
- TDD: failing test first
- async: true on all tests
- Mock Runex.WorkflowStore.put/2

## Execution order
Follow the 9-step Agent Worker Execution Order. After step 2 (write tests),
quote one sentence from each loaded skill and post your test code before
proceeding to step 3.
```

Compact. Names files and functions to reuse. Anchors the proof-of-loading checkpoint inside the execution order.

## Model Selection

Choose the initial model by task complexity:

| Task Type | Model | Examples |
|-----------|-------|---------|
| Multi-file implementation, design decisions | sonnet | New API endpoint, adapter refactor |
| Simple ops, monitoring, status checks | haiku | Deploy monitor, log reader, port check |
| Research, codebase exploration | Explore subagent | Pattern discovery, ADR review |
| Architecture design | Plan subagent | API design, system integration |

Default to haiku. Use sonnet when the task requires judgment across multiple files or architectural decisions. The escalation path (haiku → sonnet → opus) applies when an agent fails twice on the same work.

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
- **Infrastructure**: Runex workflows, not direct SSH
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

## References

- `references/team-leader.md` -- Epic decomposition, team formation, orchestration
- `references/sub-team-leader.md` -- Issue decomposition, worker management, model escalation
- `references/agent-worker.md` -- Task execution with TDD, skill loading, reporting
- `references/validator.md` -- Strictest CI per language, structured failure reporting
- `references/fix-agent.md` -- CI failure remediation, test fixing, escalation
- `references/epic-authoring.md` -- User guide for writing machine-executable epics
