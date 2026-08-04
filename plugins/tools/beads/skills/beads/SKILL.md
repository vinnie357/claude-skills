---
name: beads
description: Guide for using Beads (bd) distributed git-backed graph issue tracker. Use when managing tasks, tracking dependencies, working with AI agents, or running multi-branch parallel workflows.
license: MIT
---

# Beads - Distributed Git-Backed Issue Tracker

This skill activates when working with Beads (`bd`) for task management, dependency tracking, and AI agent workflows.

## When to Use This Skill

Activate when:
- Managing tasks with dependencies in a git repository
- Working with AI agents that need task queue access
- Running multi-branch parallel development workflows
- Needing collision-resistant task IDs across distributed teams
- Tracking task hierarchies and dependency graphs
- Integrating issue tracking directly into version control

## What is Beads?

Beads is a distributed graph issue tracker designed for AI agents and modern development workflows. As of v1.1.x it is powered by [Dolt](https://github.com/dolthub/dolt) — a version-controlled SQL database — not plain JSONL+SQLite (confirmed against `gastownhall/beads` README, tag `v1.1.2`; the legacy SQLite backend has been removed):

- **Hash-based IDs**: Collision-resistant task identifiers of the form `<prefix>-<suffix>`. Observed default in `bd` 1.1.0: a 3-character base36 suffix (letters+digits, not hex — e.g. ten fresh issues produced `i8v, 0bh, j63, 21c, 1k4, tt6, 6do, da7, uki, u0f`; `v/k/o/u/i/t` aren't hex digits). `bd config set id.hash_length <n>` / `id.prefix <name>` both return "not a recognized config key. Did you mean 'git.hash_length'/'git.prefix'?" and still store the value as an arbitrary key with no observed effect on ID generation — `bd config list` shows the real, already-set prefix key is `issue_prefix` (defaulted from the directory name at init), not `id.prefix`. Hierarchical children append `.N` (e.g. `bd-a3f8e9.1`).
- **Dolt-backed storage**: Issue data lives in a Dolt database under `.beads/embeddeddolt/` (embedded mode, the default) or `.beads/dolt/` (`bd init --server`, external `dolt sql-server`). `.beads/issues.jsonl` is an export for viewers/interchange/migration — it is not the source of truth and not the sync channel.
- **Dependency-aware**: Query ready tasks with `bd ready`
- **JSON output**: Machine-readable format via the global `--json` flag
- **Cross-machine sync via Dolt remotes**: `bd dolt push` / `bd dolt pull` against `refs/dolt/data` on the git remote, separate from source branches

## Installation

See `references/installation.md` for npm, Homebrew, Go install, and mise
(multi-architecture) methods:

```bash
npm install -g @beads/bd
```

## Getting Started

### Initialize Beads

```bash
# Default (maintainer) mode - Dolt database tracked in the repo, syncs via
# `bd dolt push`/`bd dolt pull`
bd init

# Stealth mode - global gitattributes/gitignore keep beads files out of the
# repo entirely (no local repo tracking); nothing is committed
bd init --stealth

# Contributor mode - runs an interactive OSS-contributor wizard that routes
# planning issues to a separate local planning repo (e.g. `~/.beads-planning`)
# instead of the forked repo, keeping experimental work out of PRs
bd init --contributor
```

### Create Tasks

```bash
# Create a task with title
bd create "Implement user authentication"

# Create with description
bd create "Fix login bug" --description "Users cannot log in with special characters"

# Create with labels
bd create "Add dark mode" --labels "feature,ui"

# Create with assignee
bd create "Review PR" --assignee "alice"
```

### List Tasks

```bash
# List all open tasks
bd list

# List ready tasks (no blockers)
bd ready

# JSON output for agents
bd list --json
bd ready --json

# Filter by status
bd list --status open
bd list --status closed

# Filter by label (singular flag — `--labels` does not exist and errors "unknown flag")
bd list --label "bug"

# Filter by assignee
bd list --assignee "bob"
```

### Show Task Details

```bash
# Show task by ID (use first 4+ characters)
bd show abc1

# Full JSON output (returns an array, even for one ID: [ {...} ])
bd show abc1 --json

# Stream full comment bodies in JSON output (--comments alone does not exist)
bd show abc1 --json --include-comments
```

### Manage Dependencies

```bash
# Add dependency (task2 depends on task1)
bd dep add task2 task1

# Remove dependency
bd dep remove task2 task1

# View dependency tree rooted at a task (`bd dep graph` does not exist)
bd dep tree task2

# List blockers for a task (default direction=down: what this depends on)
bd dep list task2

# List tasks blocked by a task (direction=up: what depends on this)
bd dep list task1 --direction=up
```

`bd dep blockers`/`bd dep blocking` are not real subcommands (`bd dep --help` lists only `add, cycles, list, relate, remove, tree, unrelate`) — `bd dep list [id] [--direction=up|down]` is the actual query surface.

### Update Tasks

```bash
# Close a task
bd close abc1

# Reopen a task
bd reopen abc1

# Add a comment
bd comment abc1 "Working on this now"

# Update labels (subcommand form — `--add`/`--remove` flags don't exist)
bd label add abc1 "priority:high"
bd label remove abc1 "wip"

# Assign task
bd assign abc1 alice

# Unassign (empty string; there is no separate `bd unassign` command)
bd assign abc1 ""
```

### Sync with Dolt

Cross-machine sync moves the Dolt database, not JSONL, over `refs/dolt/data`
on the git remote — `bd sync`/`bd pull` as standalone commands do not exist:

```bash
# Push commits to the configured Dolt remote (a no-op with a "No remote is
# configured — skipping" message if none is set, not a hard error)
bd dolt push

# Pull commits from the Dolt remote
bd dolt pull

# Issue-count/status overview (not literally "sync status" — see `bd dolt status`
# for Dolt server state specifically)
bd status

# Export issues for interchange/viewers (not a sync channel). Bare `bd export`
# streams JSONL to STDOUT — it does NOT write .beads/issues.jsonl by itself.
# Use -o to write the file:
bd export -o issues.jsonl
```

## JSON Output for AI Agents

All commands support `--json` for machine-readable output:

### List Ready Tasks (JSON)

```bash
bd ready --json
```

Output shape (field names verified against `bd` 1.1.0 live output; a fresh
issue with no dependencies/comments — dependency/comment bodies are counts,
not embedded arrays, unless `--include-dependents`/`--include-comments` is
passed):
```json
[
  {
    "id": "bd-throwaway-bad",
    "title": "Implement login form",
    "description": "desc",
    "status": "open",
    "priority": 2,
    "issue_type": "task",
    "assignee": "alice",
    "owner": "vinnie@example.com",
    "created_at": "2026-08-04T22:10:17Z",
    "created_by": "Vinnie Mazza",
    "updated_at": "2026-08-04T22:10:17Z",
    "labels": ["feature", "ui"],
    "dependent_count": 0,
    "dependency_count": 0,
    "comment_count": 0
  }
]
```

### Show Task Details (JSON)

```bash
bd show abc1 --json
```

`bd show --json` always returns an array, even for a single ID — not a bare
object. The field set matches the `bd ready --json` shape above.

### Parse JSON in Scripts

```bash
# Get first ready task ID
TASK_ID=$(bd ready --json | jq -r '.[0].id')

# Count open tasks
bd list --json | jq 'length'

# Get task titles
bd list --json | jq -r '.[].title'
```

## Task Hierarchies

### Parent-Child Relationships

```bash
# Create parent task
bd create "Authentication system"
# Returns: Created task auth123

# Create child tasks
bd create "Login form" --parent auth123
bd create "Password reset" --parent auth123
bd create "Session management" --parent auth123

# List children (also accepts --json / --pretty)
bd children auth123
```

`bd children <id>` is a convenience alias for `bd list --parent <id> --status all`; there
is no separate top-level `bd tree` command. `bd dep tree <id>` is a different thing —
it walks blocking dependencies, not parent-child hierarchy.

### Epic/Story/Task Pattern

```bash
# Create epic
bd create "User Management Epic" --labels "epic"

# Create stories under epic
bd create "User registration story" --parent epic123 --labels "story"
bd create "User profile story" --parent epic123 --labels "story"

# Create tasks under stories
bd create "Design registration form" --parent story456 --labels "task"
bd create "Implement validation" --parent story456 --labels "task"
```

## Dependency Management

### Dependency Types

```bash
# Task A blocks Task B (B depends on A)
bd dep add taskB taskA

# View what blocks a task (default direction=down)
bd dep list taskB

# View what a task blocks (direction=up)
bd dep list taskA --direction=up

# Circular dependency detection — confirmed live: exit 1,
# "Error: adding dependency would create a cycle" (bd 1.1.0)
bd dep add taskA taskB  # Error if creates cycle
```

### Ready Tasks Query

The `bd ready` command shows tasks with no unresolved dependencies:

```bash
# All ready tasks
bd ready

# Ready tasks with label
bd ready --labels "priority:high"

# Ready tasks for assignee
bd ready --assignee "alice"
```

## Storage and Sync

### File Structure

Verified against a fresh `bd init --non-interactive` (bd 1.1.0, embedded/default
mode) — this is the file set present immediately after init; `issues.jsonl`
is NOT among them (it appears only after `bd export -o issues.jsonl` runs;
bare `bd export` streams to STDOUT and writes nothing):

```
.beads/
├── embeddeddolt/     # The Dolt database itself (source of truth)
│   └── <db-name>/
├── config.yaml       # Local configuration
├── metadata.json     # Repository metadata
├── README.md         # Generated usage pointer
├── interactions.jsonl
├── hooks/             # git hooks installed by `bd init` (pre-commit, post-merge, ...)
├── last-touched       # Appears after the first create/update/show/close — tracks
│                      # the "current" issue for commands like `bd close` with no ID
├── .local_version
└── .gitignore
```

`.beads/issues.jsonl` is export-only — for interchange/viewers, not the source of
truth and not the sync channel — and only exists once something has exported to
it (`bd export -o issues.jsonl`, or auto-export if `export.auto` is enabled).

There is no `.beads.sqlite` — the legacy SQLite backend was removed in the
Dolt-based releases; `bd init --backend=sqlite` only prints a deprecation
notice.

### Sync Modes

| Mode | `bd init` Flag | Behavior |
|------|----------------|----------|
| Maintainer (default) | (default), or `--role maintainer` | Dolt database tracked and committed in the repo; sync via `bd dolt push`/`bd dolt pull` |
| Stealth | `--stealth` | Global gitattributes/gitignore keep beads files out of the repo entirely; nothing local is tracked or committed |
| Contributor | `--contributor` | Interactive OSS-contributor wizard; routes planning issues to a separate local planning repo instead of the forked repo |

### Conflict Resolution

Beads is Dolt-backed, not append-only JSONL — Dolt itself handles merge/diff at the
database level. There is no `git mergetool` step against `.beads/*.jsonl` and no
`bd rebuild` command:

```bash
# Pull remote changes (Dolt commits, not a git pull of .beads/)
bd dolt pull

# Inspect Dolt-level state/diffs directly if a pull reports conflicts
bd dolt status
bd diff HEAD~1 HEAD   # bd diff takes two required refs (commits, branches, or HEAD~N)
```

## Workflow Examples

PR-based development, automated AI agent task loops, feature branches, sprint
planning, and the Claude Teams epic pattern: see `references/workflow-examples.md`.

## Best Practices

### Task ID References

- Use at least 4 characters of the hash ID
- Full IDs are 8+ characters (e.g., `abc12345`)
- Shorter prefixes work if unique in the repo

### Commit Messages

Reference task IDs in commits:

```bash
git commit -m "Implement login form

Closes: abc12345"
```

### Labels Convention

```
type:bug, type:feature, type:chore
priority:high, priority:medium, priority:low
status:wip, status:blocked, status:review
sprint:42, epic:auth
skill:git, skill:security, skill:rust    # Suggested skills for task execution
```

### Dependency Best Practices

- Keep dependency chains shallow (< 5 levels)
- Use `bd ready` to find actionable tasks
- Avoid circular dependencies (bd detects these)
- Document blocking reasons in comments

### AI Agent Integration

- Use `--json` for all programmatic access
- Poll `bd ready` for task queue
- Close tasks atomically after completion
- Sync frequently in multi-agent scenarios

### Skills-Aware Task Creation

When creating tasks, analyze the task domain and suggest relevant marketplace skills using `skill:` labels. This helps the beads-worker agent (and humans) know which skills to activate during execution.

**How to suggest skills:**

1. Identify the task domain from its title, description, and labels
2. Consult `/core:bees`'s `references/skill-catalog.md` for the keyword-to-skill mapping (Tier 1: static catalog)
3. Check available skills in the current session for additional matches beyond the catalog (Tier 2: runtime discovery)
4. Add 1-3 `skill:` labels for the most relevant skills from either tier

**Matching priority:** explicit `skill:` labels > static catalog keyword match > runtime skill description match.

**Note:** `skill:` labels work with any installed skill, not just those in the static catalog. If a user has third-party skills loaded, those can be suggested and activated by the worker.

**Example with skill suggestions:**

```bash
bd create "Add pre-commit gitleaks scanning" \
  --labels "type:feature,skill:security,skill:git" \
  --description "## Task
Integrate gitleaks pre-commit hook for secret detection.

## Suggested Skills
- security: gitleaks configuration and scanning patterns
- git: pre-commit hook setup and git workflow integration"
```

Include a `## Suggested Skills` block in the description when skills need context beyond the label name. This tells the worker *why* each skill is relevant.

## IDE Integration

VS Code extensions (task sidebar, kanban board) and recommended editor settings:
see `references/ide-integration.md`.

## Troubleshooting

### Database Issues

There is no SQLite cache or `bd rebuild` command in the Dolt-backed releases —
`bd doctor` is the equivalent entry point ("Check and fix beads installation
health (start here)"):

```bash
bd doctor
bd dolt status      # Dolt server/connection state
bd ping             # Check database connectivity
```

### Sync Conflicts

```bash
# Issue-count/status overview
bd status

# Dolt-level state and connection test
bd dolt show
bd dolt test
```

### ID Collisions

Hash collisions are rare but possible:

```bash
# Use more characters if ambiguous
bd show abc1234  # Instead of abc1

# Full IDs are always unique
bd show abc12345678
```

## References

- Consult `/core:bees`'s `references/skill-catalog.md` for the keyword-to-skill mapping used in task matching
- `references/teams-integration.md`: Full protocol for mirroring beads tasks into Claude's task list for Agent Teams coordination
- `references/installation.md`: npm, Homebrew, Go install, and mise installation methods
- `references/workflow-examples.md`: PR-based development, AI agent task loop, feature branch, sprint planning, and Claude Teams epic workflows
- `references/ide-integration.md`: VS Code extensions and recommended editor settings

## Paired agents

- `agents/beads-worker.md`: Processes beads tasks by polling `bd ready`, executing work, and syncing results. Use for automating task queues or AI-driven workflows.

## Key Principles

- **Git-native**: Tasks live in the repo, versioned with code
- **Collision-resistant**: Hash IDs work across branches and forks
- **Dependency-aware**: Query ready tasks, manage blockers
- **AI-friendly**: JSON output for programmatic access
- **Distributed**: Sync via Dolt remotes (`bd dolt push`/`bd dolt pull`, `refs/dolt/data` on the git remote), not a central application server
