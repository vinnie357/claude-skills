# Managing Workflow Runs

Triggering, monitoring, saving, and disabling dynamic workflows in Claude Code. Source: https://code.claude.com/docs/en/workflows and the Claude Code Workflow tool contract.

## Table of contents

- [Triggering a workflow](#triggering-a-workflow)
- [Approval flow](#approval-flow)
- [The /workflows TUI](#the-workflows-tui)
- [Resume behavior](#resume-behavior)
- [Saving workflows](#saving-workflows)
- [Availability](#availability)
- [Disabling workflows](#disabling-workflows)

## Triggering a workflow

Workflows require explicit opt-in. Three paths:

1. **Include the word "workflow" in the prompt.** Claude Code highlights it and writes a workflow script for the task. Example: `Run a workflow to audit every API endpoint under src/routes/ for missing auth checks`.
2. **`/effort ultracode`.** Combines `xhigh` reasoning effort with automatic workflow orchestration. Claude decides when each substantive task warrants a workflow; one request can turn into several workflows — one to understand code, one to make changes, one to verify.
3. **Run a saved or bundled workflow.** `/deep-research` is the built-in workflow. Saved workflow scripts become their own slash commands, invoked as `/<workflow-name>`.

## Approval flow

Before each run, the CLI shows the planned phases and offers to view the raw script, approve once, or approve for future runs in that project. Press `Ctrl+G` to view or edit the raw script before approval. Spawned agents always run in `acceptEdits` mode and inherit the session's tool allowlist regardless of the session's own permission mode.

## The /workflows TUI

Run `/workflows` to list and monitor runs. Each entry shows its phases with agent count, token total, and elapsed time; drill into a phase to see individual agents. Live progress also appears in the task panel below the input box.

Keybindings:

| Key | Action |
|-----|--------|
| `↑` `↓` | Select |
| `Enter` / `→` | Drill in |
| `Esc` | Back |
| `j` / `k` | Scroll |
| `p` | Pause / resume |
| `x` | Stop |
| `r` | Restart |
| `s` | Save |

## Resume behavior

Within the same session, a run pauses and resumes — agents that already completed replay their cached results, and the rest run live. Exiting Claude Code discards in-session run state; the workflow restarts fresh on next launch. For programmatic resume across an edit, relaunch the Workflow tool with `{ scriptPath, resumeFromRunId }` (see `script-api.md`).

## Saving workflows

Save a script from the `/workflows` TUI (`s`) or place it directly in a workflows directory:

- `.claude/workflows/` — project-scoped, becomes a project command.
- `~/.claude/workflows/` — home-scoped, available across projects.

A saved workflow is invoked as `/<workflow-name>` and accepts an `args` value passed to its `args` global.

## Availability

- Research preview, Claude Code v2.1.154 or later.
- Pro (enable via the `/config` toggle), Max, Team, and Enterprise plans. Enterprise requires admin enablement.
- Also available with Anthropic API access and on Amazon Bedrock, Google Cloud Vertex AI, and Microsoft Foundry.

## Disabling workflows

Any one of:

- Toggle off in `/config`.
- Set `"disableWorkflows": true` in `settings.json`.
- Set the environment variable `CLAUDE_CODE_DISABLE_WORKFLOWS=1`.

To disable shell injection in skills (a separate control), use `"disableSkillShellExecution": true`.
