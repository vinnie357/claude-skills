# Migration from Beads to Bees

Guide for converting from beads (`bd`) to bees for issue tracking.

## Overview

Consider migrating when:
- SQLite performance benefits matter for large issue sets
- `bees prime` markdown output is needed for AI agent context
- Simpler sync model (one-directional export) is preferred
- Multiple dependency types (blocks, related, parent) are needed

## Concept Mapping

| Beads | Bees | Notes |
|-------|------|-------|
| `bd create` | `bees create` | Similar flags, bees adds `-o owner` |
| `bd list --json` | `bees list --json` | Compatible JSON output |
| `bd show` | `bees show` | Same pattern |
| `bd close` | `bees close` | Bees adds `-r reason` |
| `bd ready` | `bees ready` | Same concept |
| `bd dep add` | `bees dep add` | Bees uses `-t` flag for type (blocks, related, parent) |
| `bd sync` | `bees sync` | One-directional in bees (export only) |
| `bd pull` | _(none)_ | Bees has no pull; share via git + JSONL |
| `bd comment` | `bees comment add` | Subcommand style: `bees comment add <id> <text>` |
| `bd assign` | `bees update -a` | Via update flag |
| `bd label --add` | `bees label add` | Separate subcommand |
| `bd rebuild` | _(none)_ | Not needed; SQLite is primary storage |
| `bd init --stealth` | _(none)_ | Bees is always local-first |
| `bd reopen` | `bees update --status open` | Via status update |
| `.beads/` | `.bees/` | Different directory, `.beads` symlink created |
| `[bd:ID]` | `[bees:ID]` | Claude Teams subject convention |

## Data Migration Script

Nushell script template to export beads issues and import into bees:

```nu
#!/usr/bin/env nu

# Export beads tasks as JSON
let tasks = (bd list --json | from json)

# Create each task in bees
for task in $tasks {
    mut args = ["create", $task.title]

    if ($task.description? | is-not-empty) {
        $args = ($args | append ["-d", $task.description])
    }
    if ($task.labels? | is-not-empty) {
        $args = ($args | append ["-l", ($task.labels | str join ",")])
    }
    if ($task.assignee? | is-not-empty) {
        $args = ($args | append ["-a", $task.assignee])
    }

    print $"Creating: ($task.title)"
    ^bees ...$args

    # Close if the beads task was closed
    if ($task.status == "closed") {
        # Note: you'll need the new bees ID from the create output
        print $"  (task was closed in beads - close manually after verifying ID)"
    }
}

print "Migration complete. Verify issues with: bees list"
print "Then recreate dependencies with: bees dep add <id> <blocker-id>"
```

After running the script:
1. Verify issues with `bees list`
2. Recreate dependencies manually with `bees dep add`
3. Replay labels with `bees label add` if not captured in create

## Mise Task Migration

| Beads Task | Bees Task | Notes |
|------------|-----------|-------|
| `beads:init` | `bees:init` | No stealth/contributor modes |
| `beads:init:stealth` | _(none)_ | Bees is always local-first |
| `beads:init:contributor` | _(none)_ | No contributor mode |
| `beads:ready` | `bees:ready` | Same pattern |
| `beads:list` | `bees:list` | Same pattern |
| `beads:show` | `bees:show` | Same pattern |
| `beads:create` | `bees:create` | Adds `-o` owner flag |
| `beads:close` | `bees:close` | Adds `-r` reason flag |
| `beads:reopen` | _(use bees:update)_ | `bees update --status open` |
| `beads:sync` | `bees:sync` | One-directional export only |
| `beads:pull` | _(none)_ | No pull equivalent |
| `beads:status` | _(none)_ | Use `bees list` |
| `beads:dep:add` | `bees:dep:add` | Adds `-t` type flag |
| `beads:dep:remove` | `bees:dep:remove` | Same pattern |
| `beads:dep:graph` | `bees:dep:list` | Per-issue listing |
| `beads:comment` | `bees:comment:add` | `bees comment add <id> <text>` |
| `beads:assign` | _(use bees:update)_ | `bees update -a` |
| `beads:label` | `bees:label:add` / `bees:label:remove` | Separate add/remove |
| `beads:tree` | _(none)_ | No tree view |
| `beads:rebuild` | _(none)_ | Not needed with SQLite |
| _(none)_ | `bees:prime` | New: markdown for LLMs |
| _(none)_ | `bees:config` | New: configuration management |

## Worker Agent Switchover

To switch from `beads-worker` to `bees-worker`:

1. Update your `.claude/agents/` configuration to reference `bees-worker` instead of `beads-worker`
2. Change task subject convention from `[bd:ID]` to `[bees:ID]`
3. Replace `bd comment` calls with `bees comment add` for progress notes
4. Replace `bd sync` with `bees sync` (note: one-directional only)

## Coexistence

Both tools can run in the same repository:

- Beads uses `.beads/` directory
- Bees uses `.bees/` directory (with `.beads` symlink)
- The `.beads` symlink created by bees may conflict with an existing `.beads/` directory
- To coexist: initialize bees first, or rename the existing `.beads/` before running `bees init`

Add both directories to `.gitignore` if using stealth/local-only mode:

```gitignore
.beads/
.bees/
.beads
```
