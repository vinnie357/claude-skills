# Leader spawn — concrete example

A Team Leader's Task-tool prompt for an Elixir worker on a Phoenix endpoint. Use this shape as a template: name real files and functions to reuse, anchor the proof-of-loading checkpoint inside the execution order, no vague "implement X".

The explicit skill list at the top is mandatory — never use `/core:*` globs in spawn prompts, since globs don't expand in Agent prompts. The mandatory core skills (per SKILL.md "Core Skills (Mandatory)") are `/core:anti-fabrication`, `/core:git`, `/core:tdd`, `/core:twelve-factor`, `/core:restraint`, `/core:security`, `/core:mise`, `/core:nushell`, `/core:agent-loop`, `/core:bees`. Domain skills (`/elixir:*` below) are added based on the issue's labels.

```
## Load skills
/core:anti-fabrication
/core:git
/core:tdd
/core:twelve-factor
/core:restraint
/core:security
/core:mise
/core:nushell
/core:agent-loop
/core:bees
/elixir:phoenix
/elixir:testing
/elixir:style

## Reporting back
This spawn passes a `name` parameter (`142-impl-sonnet-2` below), so you are a teammate: your
plain final text is never delivered to the leader. On completion, call `SendMessage` with your
full report, addressed to `<leader-name>` — the leader fills its own name in here when it
writes the prompt. If the prompt names no leader, address the lead given in your own identity
context. Never address the report to your own name, and never hardcode a literal leader name.

## Working directory
cd /path/to/your-repo

## Bees issue
runex-142: add /api/workflows/import endpoint

## Context
WorkflowController already exposes /export at lib/runex_web/controllers/workflow_controller.ex:14. Mirror that pattern for import. Existing serializer Runex.Workflow.serialize/1 at lib/runex/workflow.ex:28 — reuse it inverse for deserialize.

## What to implement
- POST /api/workflows/import accepting JSON body
- New action import/2 in WorkflowController
- Reuse Runex.Workflow.deserialize/1 (already exists at line 41)
- Tests in test/runex_web/controllers/workflow_controller_test.exs

## Rules
- TDD: failing test first
- async: true on all tests
- Mock Runex.WorkflowStore.put/2

## Execution order
Follow the 9-step Agent Worker Execution Order. After step 2 (write tests),
quote one sentence from each loaded skill — except /core:anti-fabrication,
/core:restraint, /core:git, and /core:security, which are invoked but not
quoted (see "Proof of loading" exemption) — and post your test code before
proceeding to step 3.
```

Canonical list: `/core:agent-loop` "Core Skills (Mandatory)"; drift-checked in CI.

Compact. Names files and functions to reuse. Anchors the proof-of-loading checkpoint inside the execution order.

## Agent naming convention

Name the agent `<issue>-<role>-<model>-<n>`. The worker below is the implementer on issue `runex-142`, running sonnet, and the second agent spawned this session:

```
Agent({
  name: '142-impl-sonnet-2',
  description: 'Implement /api/workflows/import endpoint',
  prompt: '(the prompt template above)'
})
```

`/claude-code:claude-agents` "Agent Spawning Naming Convention" defines each segment and states the counter rule. This file does not restate them.
