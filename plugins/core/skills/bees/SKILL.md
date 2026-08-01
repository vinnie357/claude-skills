---
name: bees
description: Guide for using Bees, a lightweight SQLite-backed local issue tracker. Use when managing issues, tracking dependencies, exporting for AI context, or running local-first project management.
license: MIT
---

# Bees - Lightweight SQLite-Backed Issue Tracker

This skill activates when working with Bees for issue tracking, dependency management, and AI-augmented workflows.

## When to Use This Skill

Activate when:
- Managing issues with dependencies in a local repository
- Exporting issue context for AI agents (`bees list --json`, `bees show --json`)
- Tracking issue hierarchies and dependency graphs
- Needing SQLite-backed performance for large issue sets
- Syncing issues to JSONL for portability (`bees sync`)
- Working with AI agents that need structured task queues

## What is Bees?

Bees is a lightweight, local-first issue tracker designed for AI-augmented development:

- **SQLite storage**: WAL-mode SQLite database for fast queries
- **Single binary**: Written in Zig, compiles to a small static binary
- **AI-augmented**: `bees prime` dumps a workflow cheatsheet for agents, `bees sync` exports JSONL, `--json` flags on read commands
- **Dependency-aware**: Query ready issues with `bees ready`, supports blocks/related/parent-child
- **Local-first**: No server required, everything stored in `.bees/` directory

## Installation

Install via mise: add `[tools."github:ctxshift/bees"]` with `version = "latest"` to `mise.toml` (see `templates/mise.toml`), then `mise install`. Full install matrix, platform asset patterns, pre-built binaries, and source build: `references/installation.md`.

## Getting Started

### Initialize Bees

```bash
bees init
```

Creates the `.bees/` directory with SQLite database and configuration.

### Create an Issue

```bash
bees create "Implement user authentication"
```

### List Issues

```bash
bees list
```

### Show Issue Details

```bash
bees show <id>
```

### Close an Issue

```bash
bees close <id>
```

### Find Ready Issues

```bash
bees ready
```

Returns issues with no unresolved dependencies.

## Commands Reference

Per-flag syntax for the 13 day-to-day subcommands (`create`, `list`, `show`, `update`, `close`, `ready`, `dep`, `label`, `comment`, `config`, `sync`, `import`, `prime`): `references/commands.md`. bees 0.4.0 has 19 top-level commands; for the rest (`upgrade`, `edit`, `rename-prefix`, `daemon`, `version`, and the `ls` alias) run `bees <cmd> --help` — except `bees upgrade --help`, which executes a real database migration instead of printing help (see Troubleshooting).

## No Enum Validation — a Typo Silently Breaks the Queue

bees 0.4.0 does not validate enum-shaped values against the sets `--help` documents. `bees create -t`, `bees update --status`/`-t`, and `bees dep add -t` all accept and store any string verbatim — a typo does not error, it is stored, and it breaks queue behavior later with no indication why.

Verified against bees 0.4.0 in a throwaway `.bees/`:

```bash
$ bees update <id> --status bogus
Updated <id>                                    # exit 0
$ bees list --json | jq '.[] | select(.id=="<id>") | .status'
"bogus"
```

The issue then silently disappears from `bees ready` — no error, no warning, nothing distinguishing it from a real `closed` or `deferred` state. The same pattern holds for `bees dep add <id> <blocker> -t nonsense` (exit 0, `nonsense` stored as the dependency type) and `bees create <title> -t garbage` (exit 0, `garbage` stored as `issue_type`).

Documented value sets, none of them enforced:
- `create -t` / `update -t` (issue type): `task, bug, feature, epic, story` per `--help` — `bees prime`'s cheatsheet lists `chore` in place of `story`; both are accepted since nothing validates either.
- `update -s`/`--status`: `open, in_progress, closed, deferred`
- `dep add -t`: `blocks, related, parent-child` per `--help` — this doc's own table below uses `parent`; both spellings are accepted since nothing validates either.

**Mitigation**: after `bees update --status` or `bees dep add -t`, verify with `bees show <id> --json` (check `.status`) or `bees dep list <id> --json` (check `.depends_on[].type`) rather than trusting a zero exit code. An issue missing from `bees ready` with no explicit close and no blocking dependency is the tell of a typo'd status, not a real state transition.

This is upstream bees behavior, not a docs defect in this skill — worth a feature request against `ctxshift/bees` for enum validation on `create -t`, `update -s`/`-t`, and `dep add -t`.

## `.bees/` Is Found by Walking Up, Like `.git/`

`bees list`, `bees ready`, `bees create`, and every other bees command that needs a tracker walk up from the current directory to the nearest ancestor `.bees/`, the same way `git` walks up to `.git/`. There is no scoping to "this project" — a subdirectory of an already-initialized tree silently participates in the parent's tracker instead of getting its own.

Verified against bees 0.4.0: from an uninitialized child directory of an already-initialized parent, `bees create` writes the new issue into the *parent's* tracker (ID prefixed with the parent's project prefix) with no local `.bees/` created and no error — behaviorally indistinguishable from having its own tracker until `bees show <id>` or `bees list --json` is checked. Beads has the identical behavior: `bd status` from the child reports the parent's `.beads/` stats, again with no local `.beads/` and no error.

**Mitigation**: don't infer "already initialized here" from a zero exit code on `bees list`/`bees ready` (or `bd status`) — that only proves an ancestor tracker exists somewhere on the path, not that it belongs to the current directory. Check for the directory itself:

```bash
test -d .bees      # bees — true only if THIS directory owns a tracker
test -d .beads     # beads — same caveat
```

This is the same failure class as the enum-validation trap above: a command that exits 0 and looks correct while quietly doing the wrong thing. A `cd` that lands anywhere under a bees-tracked tree — not just the tracker root — followed by `bees create`, silently files into that tree's tracker with no indication the write landed somewhere other than intended.

## Dependency Management

### Dependency Types

Bees supports three relationship types between issues. Argument order is a gotcha — the dependent issue comes first:

```bash
bees dep add <id> <blocker-id>           # id depends on blocker-id
```

| Type | Flag | Behavior |
|------|------|----------|
| blocks | `-t blocks` (default) | Prevents `bees ready` from showing dependent issue |
| related | `-t related` | Informational link, no blocking |
| parent | `-t parent` | Parent-child hierarchy |

`--help` spells this type `parent-child`; both `parent` and `parent-child` are accepted as literal, distinct stored values since neither is validated — see "No Enum Validation" above.

### Ready Queue

`bees ready` returns issues where:
- Status is `open`
- No open `blocks` dependencies remain

Only `blocks`-type dependencies gate readiness. `parent-child` and `related` dependencies never do — a child issue stays in `bees ready` whether its parent is open or closed (verified against bees 0.4.0). To make a child wait on its parent, add an explicit `blocks` edge.

### Cycles are NOT rejected — check before adding a reverse edge

Bees does **not** detect circular dependencies. Both edges are accepted, and the pair then
deadlocks: each blocks the other, so neither ever appears in `bees ready`.

```bash
bees dep add taskA taskB   # accepted
bees dep add taskB taskA   # ALSO accepted, exit 0 — no cycle error
bees ready                 # "No ready issues." — both are now unreachable
```

Verified against bees 0.4.0. Inspect `bees dep list <id>` before adding an edge in the reverse
direction; nothing else will stop you.

## AI Integration

### bees sync (JSONL Export)

Export all issues to JSONL for external tooling:

```bash
bees sync
# Writes .bees/issues.jsonl
```

The JSONL file contains one JSON object per line, compatible with standard data processing tools.

### bees prime (Agent Workflow Cheatsheet)

Dump the static workflow-context cheatsheet for AI agents:

```bash
bees prime
```

The output is a fixed markdown dump of workflow rules and essential commands — it contains **no issue data** (verified against bees 0.4.0: a repo with 4 issues produced zero mentions of any issue id). It takes no flags. For issue context — titles, descriptions, labels, dependencies, status — use `bees list --json` and `bees show <id> --json`.

`--json` flag coverage and jq scripting recipes: `references/commands.md`.

## Storage and File Structure

```
.bees/
├── bees.db          # SQLite database (WAL mode) - primary storage
├── issues.jsonl     # JSONL export (created by bees sync)
├── metadata.json    # Repository metadata
├── config.json      # Local configuration
└── .gitignore       # Excludes bees.db from version control
```

### SQLite as Primary Storage

Unlike beads (which uses JSONL as primary with SQLite cache), bees uses SQLite as the primary data store:
- WAL mode for concurrent read access
- `bees sync` exports to JSONL for portability
- `bees import` rebuilds the database from `issues.jsonl` (drops and re-creates `bees.db`) — use after pulling a new `issues.jsonl`

## Workflow Examples

### PR-Based Development Workflow

#### Session Start

```bash
git checkout main && git pull
bees ready                       # Find available issues
bees show <id>                   # Read requirements
```

#### Issue Execution

```bash
git checkout -b feature/<name>
bees update <id> --status in_progress

# Do the work:
# - Read existing code to understand patterns
# - Implement following project conventions
# - Run quality gates (tests, linters, formatters)

git add <files>
git commit -m "type(scope): description"
```

#### PR Creation

```bash
git push -u origin <branch>
gh pr create --title "type(scope): description" --body "- Change one
- Change two"
```

#### Watch CI and Close

```bash
gh pr checks --watch
bees close <id>
git add .bees/ && git commit -m "chore(bees): close <id>"
git push
```

#### Cleanup

After user merges:

```bash
git checkout main && git pull
git branch -d <branch>
bees ready                       # Find next issue
```

### AI Agent Task Loop

An automated task-loop script (poll `bees ready --json`, work, close, sync): `references/commands.md`.

## Bees vs Beads

| Feature | Bees | Beads |
|---------|------|-------|
| Storage | SQLite (WAL mode) | JSONL + SQLite cache |
| Language | Zig | Go |
| Binary | Single static binary | Go binary |
| Sync model | One-directional export (`bees sync`) | Bidirectional git sync (`bd sync`/`bd pull`) |
| AI context | `bees prime` (static workflow cheatsheet); issue data via `--json` flags | `--json` flags only |
| Init modes | Local-first only | Full, stealth, contributor |
| Comments | `bees comment add` | `bd comment` |
| Dependency types | blocks, related, parent (`-t` flag) | blocks only |
| Rebuild from JSONL | `bees import` | `bd rebuild` |

## Best Practices

### Priorities and Labels

```
type:bug, type:feature, type:chore
priority:high, priority:medium, priority:low
status:wip, status:blocked, status:review
sprint:42, epic:auth
skill:git, skill:security, skill:rust
complexity:trivial, complexity:complex
```

### Complexity labels (drives the pipeline decision)

Bees issues carry one of two complexity labels. The label tells the picker whether to dispatch a single agent or the full five-tier pipeline:

- `complexity:trivial` → dispatch one haiku worker (see "Workflow Examples")
- `complexity:complex` → dispatch the five-tier pipeline internally (see `/core:agent-loop` "Five-Tier Decomposition Pipeline")

Apply with `bees label add <id> <label>`, one label per invocation — `bees update` has no `--labels` flag, and a comma-separated string becomes a single literal label. Adding a `priority:pN` label does not change the issue's priority field; set that separately with `bees update <id> -p <N>`.

Bees never carries `team:*` labels. The five tier names (`team:opus-planner`, `team:sonnet-test`, `team:sonnet-impl`, `team:haiku-ci`, `team:opus-review`) are dispatch-time strings the Sub-team Leader puts inside each Task spawn prompt. They identify the stage being dispatched, not the bees row.

One bees issue == one slice. A complex slice still gets ONE bees issue; the five pipeline stages produce intermediate artifacts (bees comments on the same issue, git commits, PR comments), not five chained bees rows.

### Dependencies

- Keep dependency chains shallow (< 5 levels)
- Use `bees ready` to find actionable issues
- Prefer `blocks` type for ordering constraints
- Use `related` type for informational links

### AI Integration Tips

- Use `bees prime` to inject the workflow cheatsheet into agent prompts; inject issue context with `bees list --json` / `bees show <id> --json`
- Use `bees ready --json` for automated task queue polling
- Use `bees sync` to create portable JSONL snapshots
- Close issues atomically after completion

### Comments

Use `bees comment add` to record progress notes:

```bash
bees comment add <id> "Completed initial implementation"
bees comment list <id>
```

### Claude-teams-aware bee format

Bees that an agent loop picks up directly need structured labels and a structured description body. Single-paragraph bees are appropriate for operator-only notes; agent-targeted bees follow this shape:

**Labels** (apply via `bees label add <id> <label>`, one label per call; set priority itself with `bees update <id> -p <N>`):
- `team:*` — the agent team that owns the work (e.g., `team:opus-planner`, `team:sonnet-impl`)
- `skill:<plugin>:<skill>` — domain skills the worker loads (e.g., `skill:elixir:phoenix`)
- `model:<model>` — initial model assignment (`model:haiku`, `model:sonnet`, `model:opus`)
- `complexity:trivial` OR `complexity:complex` — pipeline-decision label
- `priority:p<N>` — keeps `bees ready` queue order

**Description sections** (markdown H2 or H3):
- `## CRITICAL` — must-not-violate constraints (one bullet per line)
- `## Objective` — what success looks like
- `## Context` — existing code, prior commits, related PRs
- `## Acceptance criteria` — bullet list, testable
- `## Deliverables` — concrete artifacts (files, PRs, commits)
- `## Load skills` — exact skill names the worker invokes

### Single-writer constraint

The SQLite database under `.bees/bees.db` is single-writer. Concurrent workers MUST NOT run `bees create`, `bees close`, `bees update`, `bees label add`, or `bees dep add` directly — concurrent writes raise `SQLITE_CONSTRAINT` or `daemon.lock` failures that lose work.

Workers collect proposed writes in their final report (a `## BEES REQUESTS` section). The lead applies the queued writes through a single serial writer — the `bees-manager` agent (see `agents/bees-manager.md`).

### `bees ready` as canonical queue

`bees ready` (run from the repo root that owns the `.bees/` directory) is the canonical ordering of "what an agent picks up next". Edit the queue order via `bees` (`priority:pN` label OR `bees dep add`), never by mutating storage out-of-band. Downstream systems that synchronize bee state to other trackers read `bees ready` order; raw-database edits skip the synchronization layer and leave consumers stale.

## Troubleshooting

### Database Issues

```bash
# Check database integrity
sqlite3 .bees/bees.db "PRAGMA integrity_check;"

# Database is locked
# Ensure no other process has an exclusive lock
lsof .bees/bees.db
```

### `bees upgrade --help` runs the migration

`bees upgrade --help` does not print help — it executes the real upgrade (refreshes `.bees/.gitignore` and applies schema migrations to `bees.db`), verified against bees 0.4.0. Do not probe `upgrade` with `--help` on a tracker you are not ready to migrate.

### Build Issues (from source)

Troubleshooting for source builds lives with the build instructions: `references/installation.md`.

### JSONL Out of Sync

If `issues.jsonl` is stale, regenerate:

```bash
bees sync
```

## References

- `references/commands.md`: Per-flag syntax for the 13 day-to-day subcommands, `--json` output, jq scripting recipes, and the agent task-loop script
- `references/installation.md`: Install matrix (mise, pre-built binaries, source build) and build troubleshooting
- `references/teams-integration.md`: Protocol for mirroring bees issues into Claude's task list for Agent Teams coordination
- `references/migration-from-beads.md`: Guide for migrating from beads to bees
- `references/skill-catalog.md`: Marketplace-wide skill catalog with keyword triggers for matching tracker issues to skills

## Paired agents

- `agents/bees-manager.md`: Serial writer for bees DBs. Use when concurrent workers need to apply queued bees writes through a single SQLite writer to avoid `SQLITE_CONSTRAINT` and `daemon.lock` failures.
- `agents/bees-worker.md`: Processes bees issues by polling `bees ready`, executing work, and syncing results. Use for automating issue queues or AI-driven workflows.
