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

Params are injected as environment variables into step execution. Sensitive env var masking is controlled by `RUNEX_MASKED_VARS` (default: `TOKEN,SECRET,KEY,PASSWORD,CREDENTIAL,DATABASE_URL`), which is operator-configurable via that environment variable (see `config/runtime.exs:386-394` for the default). The Shell driver additionally strips param names matching these substrings from the inherited OS env before passing it downstream — this is the `@default_sensitive_patterns` behavior in `lib/runex/drivers/shell.ex`.

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
- `shell` -- Executes shell commands as workflow steps
- `mise` -- Executes mise tasks as workflow steps
- `nushell` -- Executes nushell scripts as workflow steps
- `runex` -- Sub-workflow driver; executes another workflow file as a step (inline, no new Run record)
- `wasm` -- WebAssembly driver; executes pre-compiled `.wasm` modules via Wasmex (Rust wasmtime NIF) for sandboxed, near-native execution
- `container` -- Executes workflow steps in Docker/OCI containers; supports Apple Containers on macOS 26+
- `flame` -- Executes workflow steps in ephemeral FLAME pools; spins up compute on demand for heavy workloads (experimental — falls back to local `FLAME.LocalBackend`)
- `workflow` -- Executes another workflow as a nested child run; the child inherits only the step's `params` field and receives its own `RUNEX_RUN_DIR`

### Step Schema

| Field | Type | Required | Default | Purpose |
|-------|------|----------|---------|---------|
| name | string | yes | — | Step identifier (must be unique within a workflow) |
| driver | string | no | `"shell"` | Which driver runs the step |
| command | string | one-of | — | Shell command (driver=shell), or container image:tag (driver=container), or path to .wasm file (driver=wasm) |
| script | string | one-of | — | Path to script (driver=nushell); also accepted by container driver as the command to run inside the container |
| task | string | one-of | — | Mise task name (driver=mise); also used by wasm driver as the exported function name (default: `"_start"`) |
| workflow | string | one-of | — | Sub-workflow path (driver=runex or driver=workflow) |
| params | table | no | `{}` | Step-level params injected as env vars |
| depends | list | no | `[]` | Step names this step depends on (DAG ordering) |
| env | table | no | `{}` | Step-level env vars merged on top of workflow env |
| secrets | table | no | `{}` | 1Password/credential injections (resolved at runtime) |
| timeout | int | no | `300000` (5 min) | Milliseconds before the step is killed |
| timeout_initial | int | no | — | Optional first-attempt timeout in ms |
| timeout_extension | int | no | — | Milliseconds added per heartbeat call |
| timeout_max | int | no | — | Ceiling on total timeout across all extensions |
| max_attempts | int | no | `1` | Retry count on failure |
| region | string | no | — | Federation routing hint |
| datacenter | string | no | — | Federation routing hint |

The `timeout`, `timeout_initial`, `timeout_extension`, and `timeout_max` fields work together with the `POST /api/runs/:run_id/steps/:step_id/heartbeat` endpoint. Long-running steps call heartbeat periodically to extend their deadline by `timeout_extension` milliseconds per call; the total timeout cannot exceed `timeout_max`. This lets a step stay alive for hours while still being killed automatically if it stops reporting progress.

## Examples by Driver

### driver = "runex" (sub-workflow, inline)

Invokes another workflow file as a step. The sub-workflow runs inline — no new Run record is created, and it inherits the parent's `RUNEX_RUN_DIR`. Use this for logical grouping within the same bundle.

```toml
[[step]]
name = "health-check"
driver = "runex"
workflow = "bundles/core/workflows/health-check.toml"
```

### driver = "wasm" (WebAssembly module)

Executes a pre-compiled `.wasm` module via Wasmex (Rust wasmtime NIF). The `command` field is the path to the `.wasm` file; `task` is the exported function name (defaults to `"_start"`). Note: WASI is not yet supported — no env, argv, or stdin/stdout capture.

```toml
[[step]]
name = "run-wasm"
driver = "wasm"
command = "bundles/my-bundle/modules/compute.wasm"
task = "run"   # optional: exported function name (default: "_start")
```

### driver = "container" (Docker/OCI, Apple Containers)

Executes a step inside a container. `command` is the image (image:tag); `script` is the shell command to run inside the container. Runtime preference: Apple Container CLI (macOS 26+) → docker → podman.

```toml
[[step]]
name = "run-in-container"
driver = "container"
command = "ghcr.io/my-org/my-image:latest"   # required: container image
script = "echo hello from inside the container"  # command to run inside
```
