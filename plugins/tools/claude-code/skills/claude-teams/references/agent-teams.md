# Agent Teams

Agent Teams is an experimental first-party feature for coordinating multiple Claude Code instances. One session acts as the team lead, spawning teammates that work independently with peer-to-peer communication and a shared task list.

**Status**: Experimental, disabled by default.
**Source**: https://code.claude.com/docs/en/agent-teams

## Enabling

Set the environment variable or add to `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## Architecture

An agent team has four components:

| Component | Role |
|-----------|------|
| **Team Lead** | Main session that creates the team, spawns teammates, and coordinates work |
| **Teammates** | Separate Claude Code instances working on assigned tasks |
| **Task List** | Shared work items that teammates claim and complete |
| **Mailbox** | Messaging system for inter-agent communication |

Storage:
- Team config: `~/.claude/teams/{team-name}/config.json`
- Task list: `~/.claude/tasks/{team-name}/`

## Communication

Unlike subagents (which only report back to the parent), teammates communicate directly with each other.

Mechanisms:
- **message**: Send to one specific teammate
- **broadcast**: Send to all teammates (use sparingly due to token cost)
- **Automatic delivery**: Messages arrive without polling
- **Idle notifications**: a liveness/presence signal only — it fires when a teammate finishes, but it does NOT carry the teammate's report. A teammate's plain final text is dropped; its report reaches the lead only through an explicit `SendMessage` call. An idle notification sometimes includes a message summary and sometimes does not, even for a teammate that did send a report — never infer delivery from the notification's shape.
- **Shared task list**: All agents see task status and claim available work

### Resuming a finished teammate

Sending a message to a named teammate that has already reported RESUMES it: the teammate continues working and can push further commits. This is the recovery path when a report was never sent.

Bound this carefully:
- Message a finished teammate ONLY to request its report, with an instruction such as "send the report via SendMessage and take no other action."
- Never message a finished teammate while a review of its work is in flight — a resumed agent with write tools can push commits mid-review, leaving the reviewer's verdict against a stale HEAD. A review needs no report to run: it reads the diff, so a lead can dispatch one on a teammate that idled without reporting. Recover a missing report before dispatching that review, or after its verdict lands — never while it is in flight.
- "Reported done" does not mean "finished": reading a resumed agent's files mid-run can show a half-applied state.

## Task Coordination

Tasks have three states: **pending**, **in progress**, and **completed**.

Tasks support dependencies: a pending task with unresolved dependencies cannot be claimed until those dependencies complete. When a teammate completes a dependency, blocked tasks unblock automatically.

Task claiming uses file locking to prevent race conditions when multiple teammates try to claim the same task.

## Plan Approval

Require teammates to plan before implementing for complex or risky tasks:

```
Spawn an architect teammate to refactor the authentication module.
Require plan approval before they make any changes.
```

The teammate works in read-only plan mode until the lead approves their approach.

## Display Modes

| Mode | Description | Requirement |
|------|-------------|-------------|
| **in-process** | All teammates in the main terminal. `Shift+Down` to cycle. | None |
| **split** | Each teammate in its own pane | tmux or iTerm2 |

Configure in settings:
```json
{ "teammateMode": "in-process" }
```

Or per-session: `claude --teammate-mode in-process`

## Delegate Mode

Press `Shift+Tab` to enter delegate mode. This restricts the lead to coordination only, preventing it from implementing instead of delegating.

## Context and Permissions

- Each teammate has its own context window
- Teammates load the same project context as a regular session (CLAUDE.md, MCP servers, skills)
- The lead's conversation history does not carry over to teammates
- Teammates inherit the lead's permission settings

## Hooks

Two hook events specific to agent teams:

| Hook | Behavior |
|------|----------|
| **TeammateIdle** | Fires when a teammate is about to go idle. Exit code 2 sends feedback and keeps the teammate working. |
| **TaskCompleted** | Fires when a task is being marked complete. Exit code 2 prevents completion and sends feedback. |

## Known Limitations

- No session resumption with in-process teammates (`/resume` and `/rewind` do not restore teammates)
- Task status can lag (teammates sometimes fail to mark tasks completed)
- Shutdown can be slow
- One team per session
- No nested teams (teammates cannot spawn their own teams)
- Lead is fixed for the lifetime of the team
- Permissions set at spawn time for all teammates
- Split panes require tmux or iTerm2
