# Bees Commands Reference

Per-flag syntax for the 13 day-to-day `bees` subcommands, JSON output for scripting, and the agent task-loop script. Decision-shaped guidance (dependency types, ready queue, workflows, best practices) stays in the skill body.

bees 0.4.0 has 19 top-level commands. The rest (`init`, `upgrade`, `edit`, `rename-prefix`, `daemon`, `version`, and the `ls` alias for `list`) are out of scope here — run `bees <cmd> --help` for their syntax. Exception: do NOT run `bees upgrade --help` casually — it executes a real database migration instead of printing help (verified against bees 0.4.0).

## Commands Reference

### create

Create a new issue:

```bash
bees create "Title"
bees create "Title" -d "Description text"
bees create "Title" -t bug -p 2
bees create "Title" -a "alice" -o "bob"
```

Flags (from `bees create --help`, bees 0.4.0 — there is **no** label flag and **no** parent flag):
- `-t` / `--type`: Issue type (task, bug, feature, epic, story)
- `-p` / `--priority`: Priority, 1=critical to 4=low
- `-a` / `--assignee`: Assignee name
- `-o` / `--owner`: Owner name
- `-d` / `--description`: Issue description
- `--design`, `--acceptance`, `--notes`, `--external-ref`, `--due`, `--defer`, `--json`

Labels are added after creation with `bees label add <id> <label>`.

### list

List issues with filtering:

```bash
bees list
bees list --status open
bees list --status closed
bees list --assignee "alice"
bees list --json
```

Flags (from `bees list --help`, bees 0.4.0):
- `-s` / `--status`: Filter by status (open, in_progress, closed, deferred)
- `-p` / `--priority`: Filter by priority
- `-a` / `--assignee`: Filter by assignee
- `--json`: Output as JSON array

There is **no** label filter — `bees list --labels` exits 1 with `Error: InvalidArgument`. Filter labels client-side: `bees list --json | jq '[.[] | select(.labels | index("bug"))]'`.

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

List open issues with no unresolved blocking dependencies:

```bash
bees ready
bees ready --json
```

`--json` is the **only** flag `ready` accepts (`bees ready --help`, bees 0.4.0); `bees ready --labels` exits 1. Only `blocks`-type dependencies gate readiness — see "Ready Queue" in the skill body.

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

Manage labels on issues. **One label per invocation** — `bees label add <id> "a,b"` creates a single
literal label named `a,b`, verified against the installed binary (`--json` shows `["a,b"]`, versus
`["a","b"]` when added separately). `bees create` has **no** label flag:

```bash
bees label add <id> bug
bees label add <id> priority:high
bees label remove <id> wip
```

### comment

Add and list comments on issues:

```bash
bees comment add <id> "Working on this now"
bees comment list <id>
```

### config

Get and set configuration values:

```bash
bees config get <key>          # Get a config value
bees config set <key> <value>  # Set a config value
```

A bare `bees config` does not show the current config — it exits 1 with `Error: subcommand required (get, set)`.

### sync

Export issues to JSONL format:

```bash
bees sync
```

Writes issues from the SQLite database to `issues.jsonl` in the `.bees/` directory. This is a one-directional export (database to JSONL).

### import

Rebuild the database from JSONL:

```bash
bees import
```

Rebuilds the database from `issues.jsonl` — drops and re-creates `.bees/bees.db` (`bees import --help`). Use after pulling a new `issues.jsonl`. This is bees' equivalent of beads' `bd rebuild`.

### prime

Dump the static agent-workflow cheatsheet:

```bash
bees prime
```

Outputs a fixed markdown workflow-context dump for AI agents (core rules, essential commands, session-recovery guidance). The output contains **no issue data** — verified against bees 0.4.0: a repo with 4 issues produced 58 lines with zero mentions of any issue id. `prime` accepts no flags; `bees prime --status` and `bees prime --labels` both exit 1. For issue context, use `bees list --json` and `bees show <id> --json`.

## JSON Output and Scripting

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

## Workflow Scripts

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
