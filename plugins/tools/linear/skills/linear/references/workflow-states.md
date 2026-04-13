# Linear Workflow States and VantageEx Mapping

## Linear State Types

Linear workflow states have a `type` field that categorizes them:

| Type | Meaning | Default States |
|------|---------|---------------|
| `triage` | Needs triage | Triage |
| `backlog` | In backlog | Backlog |
| `unstarted` | Ready but not started | Todo |
| `started` | In progress | In Progress |
| `completed` | Done | Done |
| `canceled` | Cancelled | Canceled |

Teams can create custom state names that map to these types. Always match on `type` for automation and use `name` for display.

## VantageEx Status Workflow (ADR-025)

Six user-facing statuses displayed as kanban columns:

```
Ready -> Up Next -> In Progress -> In Review -> Done -> Archived
                        |
                   Needs Help
                        |
                   Up Next (re-queued)
```

### Status Definitions

| VantageEx | Meaning | Who Transitions | Next |
|-----------|---------|-----------------|------|
| `ready` | All required fields present. Backlog. | Linear poller or manual creation | User moves to `up_next` |
| `up_next` | User approved for agent work. The gate. | User (dashboard or Linear) | Picker worker moves to `in_progress` |
| `in_progress` | Agent assigned and actively working | EpicPickerWorker | Agent completes -> `review`, or fails -> `needs_help` |
| `needs_help` | Agent exhausted 3 fix cycles. Summary stored in `last_failure_output`. | ValidateWorker | User re-queues to `up_next` with instructions |
| `review` | CI passed, PR created. PR URL on epic. | PRWorker | User merges -> `complete` |
| `complete` | PR merged, work done | User (post-merge) or webhook | Auto-archive or manual |
| `archived` | Hidden from dashboard | User or auto | Terminal |

### Internal Sub-States

Displayed under "In Progress" on the kanban board:

- `validating` — ValidateWorker running `mise run ci`
- `fixing` — FixWorker running with escalated model
- `paused` — User paused the validation-fix loop

## Cross-System Mapping

| VantageEx | Linear State | Bees | Dashboard Column |
|-----------|-------------|------|-----------------|
| `ready` | Backlog / Ready | open | Ready |
| `up_next` | Up Next | open | Up Next |
| `in_progress` | In Progress | in_progress | In Progress |
| `validating` | In Progress | in_progress | In Progress |
| `fixing` | In Progress | in_progress | In Progress |
| `paused` | In Progress | in_progress | In Progress |
| `needs_help` | Needs Help | open | Needs Help |
| `review` | In Review | open | In Review |
| `complete` | Done | closed | Done |
| `archived` | Archived | closed | (hidden) |

## Linear State Setup

VantageEx requires custom workflow states in Linear that do not exist by default:

- **Up Next** (type: `unstarted`) — the user-approval gate
- **Needs Help** (type: `started`) — failure escalation
- **In Review** (type: `started`) — PR submitted, waiting for human merge

Create these in Linear: Settings > Teams > [Team] > Workflow > Add State.

## State Transitions

### The Gate: Up Next

The `EpicPickerWorker` (Oban cron, every 60 seconds):

1. Query: any epic with status = `up_next`?
2. Query: any epic with status in (`in_progress`, `validating`, `fixing`)?
3. If `up_next` exists AND nothing in progress: pick oldest, set to `in_progress`
4. Otherwise: do nothing

Only user-approved epics get worked. Only 1 epic at a time.

### Needs Help Flow

1. FixWorker fails on cycle 3 (opus model)
2. ValidateWorker sets status = `needs_help`
3. Summary written to `last_failure_output` (what failed, what was attempted, which models used, root cause assessment)
4. PubSub broadcasts update to dashboard
5. User reads summary, edits epic, moves to `up_next` with `## Instructions`

### Re-Queue with Instructions (ADR-027)

1. User provides guidance text in dashboard "Re-queue Guidance" field
2. VantageEx writes `## Instructions` to Linear description
3. VantageEx sets `epic.user_instructions` field
4. Epic moved from `needs_help` to `up_next`
5. New agent receives `EPIC_INSTRUCTIONS` env var

### Querying States for Transitions

Always fetch the exact `stateId` before transitioning:

```graphql
query IssueTeamStates($id: String!) {
  issue(id: $id) {
    team {
      states {
        nodes { id name type }
      }
    }
  }
}
```

Match by `name` to find the target state, then use the `id` in the `issueUpdate` mutation. Never hardcode state IDs — they vary per team.
