---
name: workflows
description: Write and optimize GitHub Actions workflows. Use when creating CI/CD pipelines, configuring workflow triggers, managing artifacts, or debugging workflow runs.
---

# GitHub Workflows

Activate when creating, modifying, debugging, or optimizing GitHub Actions workflow files. This skill covers workflow structure, best practices, and common CI/CD patterns; full YAML syntax detail lives in `references/`.

## When to Use This Skill

Activate when:
- Writing .github/workflows/*.yml files
- Configuring workflow triggers and events
- Defining jobs, steps, and dependencies
- Using expressions and contexts
- Managing secrets and environment variables
- Implementing CI/CD pipelines
- Optimizing workflow performance
- Debugging workflow failures

## Workflow File Structure

File anatomy (`name:`, `on:`, `env:`, `jobs:`) and the `.github/workflows/` location requirement: see `references/workflow-syntax.md`.

## Trigger Events (on:)

Push/PR branch, tag, and path filters, cron schedules, `workflow_dispatch` inputs, and multi-event triggers: see `references/workflow-syntax.md`.

## Jobs

Runner selection, matrix strategy, `needs:` dependencies, and conditional job execution: see `references/jobs-and-steps.md`.

## Steps

Using actions, `run:` commands, conditional steps, and `continue-on-error`: see `references/jobs-and-steps.md`.

## Environment Variables and Secrets

Global/job/step-level `env`, `secrets.*` usage, and inter-step outputs: see `references/jobs-and-steps.md`.

Gotcha: pass values between steps with `echo "key=value" >> $GITHUB_OUTPUT` — the deprecated `set-output` command no longer works.

## Contexts

`github`, `env`, `job`, `steps`, `runner`, and `matrix` context fields: see `references/contexts-and-expressions.md`.

## Expressions

Operators, status functions (`success()`, `failure()`, `always()`), and string/JSON/hash functions: see `references/contexts-and-expressions.md`.

Gotcha: quote expression negations — `if: "!cancelled()"` — because a bare leading `!` is a YAML tag and breaks parsing.

## Artifacts

`upload-artifact` / `download-artifact` usage, retention, and cross-job handoff: see `references/workflow-syntax.md`.

## Caching

`setup-node` built-in caching and manual `actions/cache` key construction: see `references/workflow-syntax.md`.

## Permissions

Workflow- and job-level `GITHUB_TOKEN` permission scopes: see `references/workflow-syntax.md`.

Grant least privilege: declare an explicit `permissions:` block (e.g. `contents: read`) rather than inheriting the default token scope.

## Concurrency

Workflow- and job-level concurrency groups and `cancel-in-progress`: see `references/workflow-syntax.md`.

## Reusable Workflows

`workflow_call` inputs/outputs/secrets and calling syntax: see `references/workflow-syntax.md`.

## Common CI/CD Patterns

Complete Docker build-and-push and deploy-on-release workflow artifacts: see `references/workflow-syntax.md`. The two patterns below stay here because agents adapt them in-conversation.

### Node.js CI

```yaml
name: Node.js CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 21]

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm test
      - run: npm run build
```

### Monorepo with Path Filtering

```yaml
name: Monorepo CI

on:
  pull_request:
    paths:
      - 'packages/**'

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      frontend: ${{ steps.filter.outputs.frontend }}
      backend: ${{ steps.filter.outputs.backend }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            frontend:
              - 'packages/frontend/**'
            backend:
              - 'packages/backend/**'

  test-frontend:
    needs: detect-changes
    if: needs.detect-changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: npm test --workspace=frontend

  test-backend:
    needs: detect-changes
    if: needs.detect-changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: npm test --workspace=backend
```

## Debugging Workflows

Replay a workflow locally with `act` before pushing — see `/github:act` for local run configuration and troubleshooting.

### Enable Debug Logging

Set repository secrets:
- `ACTIONS_RUNNER_DEBUG`: true
- `ACTIONS_STEP_DEBUG`: true

### Debug Steps

```yaml
steps:
  - name: Debug context
    run: |
      echo "Event: ${{ github.event_name }}"
      echo "Ref: ${{ github.ref }}"
      echo "SHA: ${{ github.sha }}"
      echo "Actor: ${{ github.actor }}"

  - name: Dump GitHub context
    run: echo '${{ toJSON(github) }}'

  - name: Dump runner context
    run: echo '${{ toJSON(runner) }}'
```

### Tmate Debugging

```yaml
steps:
  - name: Setup tmate session
    if: failure()
    uses: mxschmitt/action-tmate@v3
    timeout-minutes: 30
```

## Performance Optimization

Dependency caching, shallow/sparse checkout, and parallel job graphs: see `references/workflow-syntax.md`.

## Anti-Fabrication Requirements

- Execute Read tool to verify workflow files exist before claiming structure
- Use Bash with `gh workflow list` to confirm actual workflow names before referencing them
- Execute `gh workflow view <workflow>` to verify trigger configuration before documenting it
- Use Glob to find actual workflow files before claiming their presence
- Execute `gh run list` to verify actual workflow runs before discussing execution patterns
- Never claim workflow success rates without actual run history analysis
- Validate YAML syntax using yamllint or similar tools via Bash before claiming correctness
- Report actual permission errors from workflow runs, not fabricated authorization issues
- Execute actual cache operations before claiming cache hit/miss percentages
- Use Read tool on action.yml files to verify action inputs/outputs before documenting usage

## References

- `references/workflow-syntax.md` — file structure, triggers, artifacts, caching, permissions, concurrency, reusable workflows, performance optimization, complete Docker/deploy examples
- `references/jobs-and-steps.md` — job configuration, runners, matrix strategy, dependencies, step mechanics, environment variables and secrets
- `references/contexts-and-expressions.md` — context objects, operators, and built-in expression functions
