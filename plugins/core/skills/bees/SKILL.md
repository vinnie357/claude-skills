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

### mise (Preferred)

Add to your `mise.toml`:

```toml
[tools."github:ctxshift/bees"]
version = "latest"

[tools."github:ctxshift/bees".platforms]
linux-x64 = { asset_pattern = "bees-linux-x86_64.tar.gz" }
linux-arm64 = { asset_pattern = "bees-linux-aarch64.tar.gz" }
macos-arm64 = { asset_pattern = "bees-macos-aarch64.tar.gz" }
macos-x64 = { asset_pattern = "bees-macos-x86_64.tar.gz" }
```

See `templates/mise.toml` for the full mise task definitions.

### Pre-built Binaries

Download from [GitHub Releases](https://github.com/ctxshift/bees/releases):

| Platform | Asset |
|----------|-------|
| Linux x86_64 | `bees-linux-x86_64.tar.gz` |
| Linux aarch64 | `bees-linux-aarch64.tar.gz` |
| macOS aarch64 | `bees-macos-aarch64.tar.gz` |
| macOS x86_64 | `bees-macos-x86_64.tar.gz` |

### Build from Source

Requires Zig 0.15.0+:

```bash
git clone https://github.com/ctxshift/bees.git
cd bees
zig build -Doptimize=ReleaseSafe
```

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

### create

Create a new issue:

```bash
bees create "Title"
bees create "Title" -d "Description text"
bees create "Title" -l "bug,priority:high"
bees create "Title" -a "alice" -o "bob"
bees create "Title" -p <parent-id>
```

Flags:
- `-d` / `--description`: Issue description
- `-l` / `--labels`: Comma-separated labels
- `-a` / `--assignee`: Assignee name
- `-o` / `--owner`: Owner name
- `-p` / `--parent`: Parent issue ID

### list

List issues with filtering:

```bash
bees list
bees list --status open
bees list --status closed
bees list --labels "bug"
bees list --assignee "alice"
bees list --json
```

### show

Show issue details:

```bash
bees show <id>
bees show <id> --json
```

### update

Update issue fields:

```bash
bees update <id> -d "Updated description"
bees update <id> -a "bob"
bees update <id> --status in_progress
```

### close

Close an issue:

```bash
bees close <id>
bees close <id> -r "Completed in PR #42"
```

The `-r` flag adds a closing reason.

### ready

List issues with no unresolved dependencies:

```bash
bees ready
bees ready --json
bees ready --labels "priority:high"
```

### dep

Manage dependencies between issues:

```bash
bees dep add <id> <blocker-id>           # id depends on blocker-id
bees dep add <id> <related-id> -t related  # related relationship
bees dep remove <id> <blocker-id>
bees dep list <id>
```

Dependency types (via `-t` flag):
- `blocks` (default): Blocker relationship
- `related`: Related issue, no blocking
- `parent`: Parent-child hierarchy

### label

Manage labels on issues:

```bash
bees label add <id> "bug,priority:high"
bees label remove <id> "wip"
```

### comment

Add and list comments on issues:

```bash
bees comment add <id> "Working on this now"
bees comment list <id>
```

### config

View and set configuration:

```bash
bees config                    # Show current config
bees config set key value      # Set a config value
bees config get key            # Get a config value
```

### sync

Export issues to JSONL format:

```bash
bees sync
```

Writes issues from the SQLite database to `issues.jsonl` in the `.bees/` directory. This is a one-directional export (database to JSONL).

### prime

Generate markdown output for LLM context:

```bash
bees prime
bees prime --status open
bees prime --labels "sprint:current"
```

Outputs a formatted markdown summary of issues suitable for including in AI agent prompts.

## Dependency Management

### Dependency Types

Bees supports three relationship types between issues:

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

### JSON Output

All list commands support `--json` for machine-readable output:

```bash
bees list --json
bees ready --json
bees show <id> --json
```

### Parse JSON in Scripts

```bash
# Get first ready issue ID
TASK_ID=$(bees ready --json | jq -r '.[0].id')

# Count open issues
bees list --json | jq 'length'

# Get issue titles
bees list --json | jq -r '.[].title'
```

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

```bash
#!/bin/bash
while true; do
  TASK=$(bees ready --json | jq -r '.[0] // empty')

  if [ -z "$TASK" ]; then
    echo "No ready issues"
    break
  fi

  TASK_ID=$(echo "$TASK" | jq -r '.id')
  TITLE=$(echo "$TASK" | jq -r '.title')

  echo "Working on: $TITLE ($TASK_ID)"

  # Do work...

  bees close "$TASK_ID"
  bees sync
done
```

## VS Code Integration

Bees creates a `.beads` symlink to `.bees/` for compatibility with the beads VS Code extensions:

### Beads Extension (`planet57.vscode-beads`)

```bash
code --install-extension planet57.vscode-beads
```

Task list sidebar, syntax highlighting, and issue ID autocompletion.

### Beads Kanban (`DavidCForbes.beads-kanban`)

```bash
code --install-extension DavidCForbes.beads-kanban
```

Drag-and-drop kanban board with dependency visualization.

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
```

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

```bash
# Verify Zig version (requires 0.15.0+)
zig version

# Clean build
rm -rf zig-cache zig-out
zig build -Doptimize=ReleaseSafe
```

### JSONL Out of Sync

If `issues.jsonl` is stale, regenerate:

```bash
bees sync
```

## References

- `references/teams-integration.md`: Protocol for mirroring bees issues into Claude's task list for Agent Teams coordination
- `references/migration-from-beads.md`: Guide for migrating from beads to bees
