# Beads Workflow Examples

Worked end-to-end workflows: PR-based development, automated AI agent task loops,
feature branches, sprint planning, and the Claude Teams epic pattern.

## Contents

- [PR-Based Development Workflow](#pr-based-development-workflow)
- [AI Agent Task Loop (Automated)](#ai-agent-task-loop-automated)
- [Feature Branch Workflow](#feature-branch-workflow)
- [Sprint Planning](#sprint-planning)
- [Claude Teams Epic Workflow](#claude-teams-epic-workflow)

### PR-Based Development Workflow

The recommended workflow for git repositories integrates beads with feature branches and pull requests:

#### Session Start

```bash
git checkout main && git pull    # Start fresh
bd ready                         # Find available tasks
bd show <id>                     # Read task requirements
```

#### Task Execution

```bash
git checkout -b feature/<name>   # Create feature branch
bd update <id> --status in_progress  # Claim task

# Do the work:
# - Read existing code to understand patterns
# - Implement following TDD (tests first when practical)
# - Run quality gates (tests, linters, formatters)

git add <files>                  # Stage changes
git commit -m "type(scope): description"  # Commit
```

#### PR Creation

```bash
git push -u origin <branch>
gh pr create --title "type(scope): description" --body "- Change one
- Change two"

# Notify user: "PR created: <url>"
```

#### Watch CI & Close Tasks

Watch CI until it passes, then close tasks:

```bash
gh pr checks --watch             # Wait for CI to complete
bd close <id>                    # Close completed task
git add .beads/ && git commit -m "chore(beads): close <id>"
git push                         # Push closure to branch
```

Notify user: "CI passed, tasks closed. Ready for merge review."

#### Cleanup & Continue

After user merges:

```bash
git checkout main && git pull    # Sync with merged changes
git branch -d <branch>           # Delete feature branch
bd ready                         # Find next task
```

#### Key Principles

1. **One task = one branch = one PR** - Keep changes atomic
2. **Claim before working** - `bd update --status in_progress`
3. **Close with completion** - Document what was done
4. **Minimal PRs** - Title + bullets only, no templates
5. **Report, do not merge** - The default merge policy authorizes no agent merge; never assume approval
6. **Clean up** - Delete local branch after merge

### AI Agent Task Loop (Automated)

For automated processing without PRs:

```bash
#!/bin/bash
# Agent picks up ready tasks until none remain

while true; do
  TASK=$(bd ready --json | jq -r '.[0] // empty')

  if [ -z "$TASK" ]; then
    echo "No ready tasks"
    break
  fi

  TASK_ID=$(echo "$TASK" | jq -r '.id')
  TITLE=$(echo "$TASK" | jq -r '.title')

  echo "Working on: $TITLE ($TASK_ID)"

  # Do work...

  bd close "$TASK_ID"
  bd dolt push   # no-op with a "No remote configured" message if unset; `bd sync` does not exist
done
```

### Feature Branch Workflow

```bash
# Create feature tasks
bd create "Feature: Dark Mode" --labels "feature"
bd create "Add theme toggle" --parent feat123
bd create "Update color palette" --parent feat123
bd dep add toggle456 palette789  # Toggle depends on palette

# Work on branch
git checkout -b feature/dark-mode

# Complete tasks as you go
bd close palette789
bd dolt push   # no-op with a "No remote configured" message if unset; `bd sync` does not exist

# Toggle is now ready
bd ready  # Shows toggle456
```

### Sprint Planning

```bash
# Create sprint container
bd create "Sprint 42" --labels "sprint"

# Add sprint items
bd create "User story 1" --parent sprint42
bd create "User story 2" --parent sprint42
bd create "Bug fix 1" --parent sprint42

# Assign work
bd assign story1 alice
bd assign story2 bob
bd assign bug1 charlie

# Track progress
bd list --parent sprint42 --json | jq '[.[] | select(.status=="closed")] | length'
```

### Claude Teams Epic Workflow

When using Claude Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) with beads, the team lead decomposes an epic into beads tasks and mirrors them into Claude's built-in task list for real-time coordination. The `claude-teams` skill should be available for full guidance on team setup.

#### Step 1: Team Lead Plans and Decomposes

```bash
# Create epic with stories
bd create "Auth System Epic" --labels "epic"
bd create "Login API endpoint" --parent epic123 --labels "story,skill:security"
bd create "Session middleware" --parent epic123 --labels "story,skill:twelve-factor"
bd create "Login UI form" --parent epic123 --labels "story,skill:accessibility"

# Set dependencies
bd dep add session456 login789   # Session depends on Login API
```

#### Step 2: Mirror into Claude Task List

For each beads task, create a matching Claude task with `[bd:ID]` in the subject for cross-referencing:

```
TaskCreate subject="[bd:login789] Login API endpoint"
  description="Implement POST /api/auth/login. Skills: security. See bd show login789 for full spec."

TaskCreate subject="[bd:session456] Session middleware"
  description="JWT session management. Skills: twelve-factor. See bd show session456 for full spec."

TaskCreate subject="[bd:ui321] Login UI form"
  description="Login form with validation. Skills: accessibility. See bd show ui321 for full spec."

# Mirror dependencies
TaskUpdate taskId="session-task" addBlockedBy=["login-task"]
```

#### Step 3: Teammates Claim and Execute

Each teammate checks both systems:

```bash
# 1. Find available work
TaskList                          # See unblocked Claude tasks
bd show <id>                      # Get full spec from beads

# 2. Claim in both systems
bd update <id> --status in_progress
TaskUpdate taskId="<claude-id>" status="in_progress"

# 3. Do the work, then close both
bd close <id>
TaskUpdate taskId="<claude-id>" status="completed"
```

#### Step 4: Dual-System Sync Rules

| Event | Beads Action | Claude Task Action |
|-------|-------------|-------------------|
| Task created | `bd create` | `TaskCreate` with `[bd:ID]` subject |
| Work started | `bd update --status in_progress` | `TaskUpdate status="in_progress"` |
| Work completed | `bd close` (first) | `TaskUpdate status="completed"` (second) |
| Work blocked | `bd comment` with blocker | `TaskUpdate addBlockedBy` |

Beads is the persistent source of truth (git-backed). Claude's task list is the ephemeral coordination layer (session-scoped). Always update beads first.

See `teams-integration.md` for the full mirroring protocol.

