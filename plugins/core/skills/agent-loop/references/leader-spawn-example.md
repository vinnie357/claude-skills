# Leader spawn — concrete example

A Team Leader's Task-tool prompt for an Elixir worker on a Phoenix endpoint. Use this shape as a template: name real files and functions to reuse, anchor the proof-of-loading checkpoint inside the execution order, no vague "implement X".

The explicit skill list at the top is mandatory — never use `/core:*` globs in spawn prompts, since globs don't expand in Agent prompts. The mandatory core skills (per SKILL.md "Core Skills (Mandatory)") are `/core:anti-fabrication`, `/core:git`, `/core:tdd`, `/core:twelve-factor`, `/core:security`, `/core:mise`, `/core:nushell`. Domain skills are added based on the issue's labels.

```
## Load skills
/core:anti-fabrication
/core:git
/core:tdd
/core:twelve-factor
/core:security
/core:mise
/core:nushell
/elixir:phoenix-framework
/elixir:elixir-testing
/elixir:style

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
quote one sentence from each loaded skill and post your test code before
proceeding to step 3.
```

Compact. Names files and functions to reuse. Anchors the proof-of-loading checkpoint inside the execution order.
