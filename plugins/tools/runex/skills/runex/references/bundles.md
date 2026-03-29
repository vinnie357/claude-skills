# Bundle Authoring Guide

Bundles are self-contained directories that package workflows, scripts, and tool dependencies for Runex.

## Table of Contents

- [Bundle Layout](#bundle-layout)
- [Root Workflow Pattern](#root-workflow-pattern)
- [Sub-Workflows](#sub-workflows)
- [Scripts](#scripts)
- [Tool Dependencies](#tool-dependencies)
- [Naming Conventions](#naming-conventions)
- [Real Bundle Examples](#real-bundle-examples)
- [Workflow TOML Syntax](#workflow-toml-syntax)

## Bundle Layout

```
bundle-name/
  workflow.toml          # Root dispatcher (routes ACTION param to scripts)
  mise.toml              # Tool dependencies (e.g., nushell, jq)
  workflows/             # Sub-workflows (invocable directly via API)
    action-one.toml
    action-two.toml
  scripts/               # Scripts called by workflow steps
    do-thing.nu
    helper.sh
```

Two locations for bundles:
- `~/github/runex-workflows/bundles/` -- shared, generic bundles
- `~/github/<app>/bundles/` -- app-specific bundles

## Root Workflow Pattern

The root `workflow.toml` acts as a dispatcher. It accepts an `ACTION` param and routes to the appropriate script:

```toml
[workflow]
name = "my-bundle"
description = "What this bundle does"

[workflow.params]
ACTION = { required = true, description = "Action to run: foo, bar, baz" }

[workflow.env]
BUNDLE_DIR = "bundles/my-bundle"

[[step]]
name = "dispatch"
driver = "shell"
command = """
case "$ACTION" in
  foo) nu "$BUNDLE_DIR/scripts/foo.nu" ;;
  bar) nu "$BUNDLE_DIR/scripts/bar.nu" ;;
  baz) sh "$BUNDLE_DIR/scripts/baz.sh" ;;
  *) echo "Unknown ACTION: $ACTION. Valid: foo, bar, baz" && exit 1 ;;
esac
"""
```

Submit via API:
```bash
curl -X POST http://localhost:4001/api/runs \
  -H "Content-Type: application/json" \
  -d '{"workflow_path": "bundles/my-bundle/workflow.toml", "params": {"ACTION": "foo"}}'
```

## Sub-Workflows

Sub-workflows in the `workflows/` directory can be invoked directly without the dispatcher. Each is a standalone workflow file:

```toml
[workflow]
name = "foo"
description = "Runs the foo action"

[workflow.env]
BUNDLE_DIR = "bundles/my-bundle"

[[step]]
name = "run-foo"
driver = "shell"
command = "nu $BUNDLE_DIR/scripts/foo.nu"
```

Submit directly:
```bash
curl -X POST http://localhost:4001/api/runs \
  -d '{"workflow_path": "bundles/my-bundle/workflows/foo.toml"}'
```

## Scripts

Scripts live in the `scripts/` directory. Nushell is the preferred scripting language. Scripts are invoked from workflow steps via shell commands:

```toml
[[step]]
name = "collect-info"
driver = "shell"
command = "nu $BUNDLE_DIR/scripts/system-info.nu"
```

Use `$BUNDLE_DIR` to reference scripts relative to the bundle root. This variable is set in `[workflow.env]`.

## Tool Dependencies

Each bundle includes a `mise.toml` that declares required tools:

```toml
[tools]
"github:nushell/nushell" = "latest"
```

This ensures the tools are available when the bundle runs on any Runex host.

## Naming Conventions

- **Bundle names**: Globally unique across all bundle locations. Use kebab-case (e.g., `deploy-to-mini`, `tool-verify`).
- **Workflow names**: Unique within their containing directory. Match the filename without extension.
- **Script names**: Descriptive, kebab-case, with appropriate extension (`.nu`, `.sh`).

## Real Bundle Examples

### core bundle

Shared primitives for all Runex instances.

```
core/
  workflow.toml          # Dispatches: system-info, health-check, tool-verify, install-mise
  mise.toml              # Requires nushell
  workflows/
    health-check.toml
    install-mise.toml
    system-info.toml
    tool-verify.toml
  scripts/
    health-check.nu
    install-mise.sh
    system-info.nu
    tool-verify.nu
```

### postgres bundle

Database management workflows.

```
postgres/
  workflow.toml          # Dispatches: query, setup, status
  mise.toml
  workflows/
    query.toml
    setup.toml
    status.toml
  scripts/
    apply-settings.nu
    reload-config.nu
    run-query.nu
    show-status.nu
```

### deploy-to-mini bundle

Deployment automation for the Mac Mini.

```
deploy-to-mini/
  workflow.toml
  mise.toml
  scripts/
    copy-binary.nu
    start-service.nu
    stop-service.nu
    verify-health.nu
```

## Workflow TOML Syntax

### Workflow Header

```toml
[workflow]
name = "workflow-name"
description = "What this workflow does"
```

### Parameters

```toml
[workflow.params]
PARAM_NAME = { required = true, description = "What this param controls" }
OPTIONAL_PARAM = { required = false, description = "Optional with default behavior" }
```

Params are injected as environment variables into step execution. Sensitive params (matching password/secret/token/key/url patterns) are auto-masked in step output.

### Environment Variables

```toml
[workflow.env]
BUNDLE_DIR = "bundles/my-bundle"
MY_CONFIG = "some-value"
```

Static environment variables available to all steps.

### Steps

```toml
[[step]]
name = "step-name"
driver = "shell"
command = "echo hello"
description = "Optional description of what this step does"
```

Steps can depend on other steps to form a DAG:

```toml
[[step]]
name = "build"
driver = "shell"
command = "make build"

[[step]]
name = "test"
driver = "shell"
command = "make test"
depends = ["build"]

[[step]]
name = "deploy"
driver = "shell"
command = "make deploy"
depends = ["test"]
```

### Drivers

Available step drivers:
- `shell` -- Executes via system shell
- `mise` -- Executes via mise
- `nushell` -- Executes via nushell directly
