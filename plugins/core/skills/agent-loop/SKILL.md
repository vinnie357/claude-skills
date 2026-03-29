---
name: agent-loop
description: Generic epic-to-PR agent workflow with 4-phase execution and 6-tier prompt hierarchy. Use when spawned to work an epic, issue, or task as part of an agent team, orchestrating multi-agent workflows, or decomposing work into issues and tasks.
license: MIT
---

# Agent Loop

Defines the standard workflow for agents working epics, issues, and tasks through a 4-phase execution model with a 6-tier prompt hierarchy.

## 4-Phase Execution

Every agent, regardless of tier, follows these four phases:

| Phase | Name | Purpose |
|-------|------|---------|
| 1 | Pre-flight | Load skills, check tracker, verify branch, understand assignment |
| 2 | Working | Execute assigned work items, report progress, escalate blockers |
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

## Key Conventions

- **Tracker**: Use bees (`bees ready`, `bees close`) for issue management
- **Commits**: Conventional commits, no attribution, no Co-Authored-By
- **PRs**: Minimal format (title + bullet list), no templates, no attribution
- **TDD**: Code without tests is not complete
- **CI**: `mise run ci` must pass before any PR or merge
- **Branches**: One feature branch per epic (`feature/<epic-slug>`)
- **Merge**: Squash merge only, user approves

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

## References

- `references/team-leader.md` -- Epic decomposition, team formation, orchestration
- `references/sub-team-leader.md` -- Issue decomposition, worker management, model escalation
- `references/agent-worker.md` -- Task execution with TDD, skill loading, reporting
- `references/validator.md` -- Strictest CI per language, structured failure reporting
- `references/fix-agent.md` -- CI failure remediation, test fixing, escalation
- `references/epic-authoring.md` -- User guide for writing machine-executable epics
