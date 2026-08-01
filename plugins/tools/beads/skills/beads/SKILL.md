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

Beads is a distributed git-backed graph issue tracker designed for AI agents and modern development workflows:

- **Hash-based IDs**: Collision-resistant task identifiers (8+ hex characters)
- **Git-native storage**: Tasks stored as JSONL in `.beads/` directory
- **Dependency-aware**: Query ready tasks with `bd ready`
- **JSON output**: Machine-readable format for AI agent integration
- **SQLite cache**: Fast local queries with git sync

## Installation

See `references/installation.md` for npm, Homebrew, Go install, and mise
(multi-architecture) methods:

```bash
npm install -g @beads/bd
```

## Getting Started

### Initialize Beads

```bash
# Full mode - syncs to remote (shared with team)
bd init

# Stealth mode - local only, no commits
bd init --stealth

# Contributor mode - pull only, no push
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

# Filter by label
bd list --labels "bug"

# Filter by assignee
bd list --assignee "bob"
```

### Show Task Details

```bash
# Show task by ID (use first 4+ characters)
bd show abc1

# Full JSON output
bd show abc1 --json

# Show with comments
bd show abc1 --comments
```

### Manage Dependencies

```bash
# Add dependency (task2 depends on task1)
bd dep add task2 task1

# Remove dependency
bd dep remove task2 task1

# View dependency graph
bd dep graph

# List blockers for a task
bd dep blockers task2

# List tasks blocked by a task
bd dep blocking task1
```

### Update Tasks

```bash
# Close a task
bd close abc1

# Reopen a task
bd reopen abc1

# Add a comment
bd comment abc1 "Working on this now"

# Update labels
bd label abc1 --add "priority:high"
bd label abc1 --remove "wip"

# Assign task
bd assign abc1 alice

# Unassign
bd unassign abc1
```

### Sync with Git

```bash
# Sync changes to remote
bd sync

# Pull changes from remote
bd pull

# Check sync status
bd status
```

## JSON Output for AI Agents

All commands support `--json` for machine-readable output:

### List Ready Tasks (JSON)

```bash
bd ready --json
```

Output:
```json
[
  {
    "id": "abc12345",
    "title": "Implement login form",
    "status": "open",
    "labels": ["feature", "frontend"],
    "created": "2024-01-15T10:30:00Z",
    "dependencies": [],
    "blocking": ["def67890"]
  }
]
```

### Show Task Details (JSON)

```bash
bd show abc1 --json
```

Output:
```json
{
  "id": "abc12345",
  "title": "Implement login form",
  "description": "Create a login form with email and password fields",
  "status": "open",
  "labels": ["feature", "frontend"],
  "assignee": "alice",
  "created": "2024-01-15T10:30:00Z",
  "updated": "2024-01-16T14:20:00Z",
  "dependencies": [],
  "blocking": ["def67890"],
  "comments": [
    {
      "author": "bob",
      "body": "Should we add OAuth support?",
      "created": "2024-01-15T11:00:00Z"
    }
  ]
}
```

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

# List children
bd list --parent auth123

# View hierarchy
bd tree auth123
```

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

# View what blocks a task
bd dep blockers taskB

# View what a task blocks
bd dep blocking taskA

# Circular dependency detection
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

```
.beads/
├── tasks.jsonl     # Task data (append-only)
├── comments.jsonl  # Comments (append-only)
└── deps.jsonl      # Dependencies (append-only)

.beads.sqlite       # Local cache (not committed)
```

### Sync Modes

| Mode | `bd init` Flag | Commits | Pushes | Use Case |
|------|----------------|---------|--------|----------|
| Full | (default) | Yes | Yes | Team shared |
| Stealth | `--stealth` | No | No | Local only |
| Contributor | `--contributor` | Yes | No | Pull-only |

### Conflict Resolution

Beads uses append-only JSONL and hash-based IDs to minimize conflicts:

```bash
# Pull remote changes
bd pull

# Resolve conflicts in .beads/ files
git mergetool .beads/tasks.jsonl

# Rebuild cache after conflict resolution
bd rebuild
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

### Cache Issues

```bash
# Rebuild SQLite cache from JSONL
bd rebuild

# Clear and rebuild
rm .beads.sqlite
bd rebuild
```

### Sync Conflicts

```bash
# Check status
bd status

# Manual conflict resolution
git status .beads/
git mergetool .beads/tasks.jsonl
bd rebuild
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
- **Distributed**: No central server, sync via git
