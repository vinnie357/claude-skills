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
- Exporting issue context for AI agents (`bees prime`)
- Tracking issue hierarchies and dependency graphs
- Needing SQLite-backed performance for large issue sets
- Syncing issues to JSONL for portability (`bees sync`)
- Working with AI agents that need structured task queues

## What is Bees?

Bees is a lightweight, local-first issue tracker designed for AI-augmented development:

- **SQLite storage**: WAL-mode SQLite database for fast queries
- **Single binary**: Written in Zig, compiles to a small static binary
- **AI-augmented**: `bees prime` outputs markdown for LLM context, `bees sync` exports JSONL
- **Dependency-aware**: Query ready issues with `bees ready`, supports blocks/related/parent-child
- **VS Code integration**: Compatible with beads VS Code extensions via `.beads` symlink
- **Local-first**: No server required, everything stored in `.bees/` directory

## Installation

Install via mise: add `[tools."github:ctxshift/bees"]` with `version = "latest"` to `mise.toml` (see `templates/mise.toml`), then `mise install`. Full install matrix, platform asset patterns, pre-built binaries, source build, and VS Code extensions: `references/installation.md`.

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

Per-flag syntax for all 12 subcommands (`create`, `list`, `show`, `update`, `close`, `ready`, `dep`, `label`, `comment`, `config`, `sync`, `prime`): `references/commands.md`.

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

### Ready Queue

`bees ready` returns issues where:
- Status is `open`
- No open `blocks` dependencies remain
- Parent issues (if any) are still open

### Cycle Detection

Bees detects circular dependencies and rejects them:

```bash
bees dep add taskA taskB
bees dep add taskB taskA  # Error: would create cycle
```

## AI Integration

### bees sync (JSONL Export)

Export all issues to JSONL for external tooling:

```bash
bees sync
# Writes .bees/issues.jsonl
```

The JSONL file contains one JSON object per line, compatible with standard data processing tools.

### bees prime (Markdown for LLMs)

Generate a markdown summary for LLM context windows:

```bash
bees prime
```

Output includes issue titles, descriptions, labels, dependencies, and status in a readable markdown format. Pipe directly into agent prompts or save to file.

`--json` flag coverage and jq scripting recipes: `references/commands.md`.

## Storage and File Structure

```
.bees/
├── bees.db          # SQLite database (WAL mode) - primary storage
├── issues.jsonl     # JSONL export (created by bees sync)
├── metadata.json    # Repository metadata
├── config.json      # Local configuration
└── .beads           # Symlink for VS Code extension compatibility
```

### SQLite as Primary Storage

Unlike beads (which uses JSONL as primary with SQLite cache), bees uses SQLite as the primary data store:
- WAL mode for concurrent read access
- No need for `rebuild` commands
- `bees sync` exports to JSONL for portability

### The .beads Symlink

Bees creates a `.beads` symlink pointing to the `.bees/` directory. This enables compatibility with VS Code extensions designed for beads (`vscode-beads` and `beads-kanban`).

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

## VS Code Integration

The `.beads` symlink makes the beads VS Code extensions work with bees; extension install commands: `references/installation.md`.

## Bees vs Beads

| Feature | Bees | Beads |
|---------|------|-------|
| Storage | SQLite (WAL mode) | JSONL + SQLite cache |
| Language | Zig | Go |
| Binary | Single static binary | Go binary |
| Sync model | One-directional export (`bees sync`) | Bidirectional git sync (`bd sync`/`bd pull`) |
| AI context | `bees prime` (markdown output) | `--json` flags only |
| Init modes | Local-first only | Full, stealth, contributor |
| Comments | `bees comment add` | `bd comment` |
| Dependency types | blocks, related, parent (`-t` flag) | blocks only |
| VS Code | Via `.beads` symlink | Native |
| Conflict resolution | Not needed (SQLite primary) | `bd rebuild` from JSONL |

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

- Use `bees prime` to inject issue context into agent prompts
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

### Build Issues (from source)

Troubleshooting for source builds lives with the build instructions: `references/installation.md`.

### JSONL Out of Sync

If `issues.jsonl` is stale, regenerate:

```bash
bees sync
```

## References

- `references/commands.md`: Per-flag syntax for all 12 subcommands, `--json` output, jq scripting recipes, and the agent task-loop script
- `references/installation.md`: Install matrix (mise, pre-built binaries, source build), VS Code extensions, and build troubleshooting
- `references/teams-integration.md`: Protocol for mirroring bees issues into Claude's task list for Agent Teams coordination
- `references/migration-from-beads.md`: Guide for migrating from beads to bees

## Paired agents

- `agents/bees-manager.md`: Serial writer for bees DBs. Use when concurrent workers need to apply queued bees writes through a single SQLite writer to avoid `SQLITE_CONSTRAINT` and `daemon.lock` failures.
- `agents/bees-worker.md`: Processes bees issues by polling `bees ready`, executing work, and syncing results. Use for automating issue queues or AI-driven workflows.
