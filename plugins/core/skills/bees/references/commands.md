# Bees Commands Reference

Per-flag syntax for every `bees` subcommand, JSON output for scripting, and the agent task-loop script. Decision-shaped guidance (dependency types, ready queue, workflows, best practices) stays in the skill body.

## Commands Reference

### create

Create a new issue:

```bash
bees create "Title"
bees create "Title" -d "Description text"
bees create "Title" -t bug -p 2
bees create "Title" -a "alice" -o "bob"
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
