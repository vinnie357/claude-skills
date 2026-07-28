---
name: workflows
description: Guide for authoring Dagu workflows with YAML syntax. Use when creating workflow definitions, configuring steps and executors, or setting up scheduling and dependencies.
---

# Dagu Workflow Authoring

This skill activates when creating or modifying Dagu workflow definitions, configuring workflow steps, scheduling, or composing complex workflows.

## When to Use This Skill

Activate when:
- Writing Dagu workflow YAML files
- Configuring workflow steps and executors
- Setting up workflow scheduling with cron
- Defining step dependencies and data flow
- Implementing error handling and retries
- Composing hierarchical workflows
- Using environment variables and parameters

## Basic Workflow Structure

### Minimal Workflow

```yaml
# hello.yaml
steps:
  - name: hello
    command: echo "Hello from Dagu!"
```

### Complete Workflow Structure

```yaml
name: my_workflow
description: Description of what this workflow does

# Schedule (optional)
schedule: "0 2 * * *"  # Cron format: daily at 2 AM

# Environment variables
env:
  - KEY: value
  - DB_HOST: localhost

# Parameters
params: ENVIRONMENT=production

# Email notifications (optional)
mailOn:
  failure: true
  success: false

smtp:
  host: smtp.example.com
  port: 587

errorMail:
  from: dagu@example.com
  to: alerts@example.com

# Workflow steps
steps:
  - name: step1
    command: echo "First step"

  - name: step2
    command: echo "Second step"
    depends:
      - step1
```

## Steps

### Basic Step

```yaml
steps:
  - name: greet
    command: echo "Hello, World!"
```

### Step with Script

```yaml
steps:
  - name: process
    command: |
      echo "Starting processing..."
      ./scripts/process.sh
      echo "Done!"
```

### Step with Working Directory

```yaml
steps:
  - name: build
    dir: /path/to/project
    command: make build
```

### Step with Environment Variables

```yaml
steps:
  - name: deploy
    env:
      - ENVIRONMENT: production
      - API_KEY: $API_KEY  # From global env
    command: ./deploy.sh
```

## Executors

Command (default), Docker, SSH, HTTP, Mail, and JQ executor configuration: see executors.md.

Gotcha: the default executor (no `executor:` block) is the Command Executor — set
`executor.type` only when a step needs Docker, SSH, HTTP, Mail, or JQ.

## Step Dependencies

Simple, multiple, and parallel dependency patterns via `depends:`: see steps-and-flow.md.

Gotcha: steps with no `depends:` run in parallel by default — sequencing is opt-in.

## Conditional Execution

### Preconditions

```yaml
steps:
  - name: deploy_production
    preconditions:
      - condition: "`echo $ENVIRONMENT`"
        expected: "production"
    command: ./deploy.sh
```

### Continue On Failure

```yaml
steps:
  - name: optional_step
    continueOn:
      failure: true
    command: ./might_fail.sh

  - name: cleanup
    depends:
      - optional_step
    command: ./cleanup.sh  # Runs even if optional_step fails
```

## Error Handling and Retries

### Retry Configuration

```yaml
steps:
  - name: flaky_api_call
    command: curl https://api.example.com/data
    retryPolicy:
      limit: 3
      intervalSec: 10
```

### Exponential Backoff

```yaml
steps:
  - name: with_backoff
    command: ./external_api.sh
    retryPolicy:
      limit: 5
      intervalSec: 5
      exponentialBackoff: true  # 5s, 10s, 20s, 40s, 80s
```

### Signal on Stop

```yaml
steps:
  - name: graceful_shutdown
    command: ./long_running_process.sh
    signalOnStop: SIGTERM  # Send SIGTERM instead of SIGKILL
```

## Data Flow

Passing step output to later steps via `output:` and captured `script:` variables: see steps-and-flow.md.

## Scheduling

### Cron Schedule

```yaml
# Daily at 2 AM
schedule: "0 2 * * *"

# Every Monday at 9 AM
schedule: "0 9 * * 1"

# Every 15 minutes
schedule: "*/15 * * * *"

# First day of month at midnight
schedule: "0 0 1 * *"
```

### Start/Stop Times

```yaml
# Only run during business hours
schedule:
  start: "2024-01-01"
  end: "2024-12-31"
  cron: "0 9-17 * * 1-5"  # Mon-Fri, 9 AM to 5 PM
```

## Environment Variables

Global, step-level, and file-loaded (`.env`) environment variables: see steps-and-flow.md.

## Parameters

Defining workflow `params:` and overriding them from the CLI: see steps-and-flow.md.

## Sub-Workflows

Calling and nesting sub-workflows with `run:`: see steps-and-flow.md.

## Handlers

Exit, failure, and success handlers via `handlerOn:`: see steps-and-flow.md.

Gotcha: `handlerOn` is declared once per workflow, alongside `steps:` — it is not nested inside an individual step.

## Templates and Variables

Built-in (`{{.Name}}`, `{{.Step.Name}}`, `{{.timestamp}}`, `{{.requestId}}`) and custom `params:`-backed templates: see steps-and-flow.md.

Gotcha: custom parameters are referenced as `{{.Params.NAME}}`, not bare `{{.NAME}}` — the bare form is reserved for built-ins.

## Common Patterns

Complete ETL pipeline, multi-environment deployment, database backup, and health-check monitoring workflow artifacts: see common-patterns.md.

## Best Practices

### Workflow Organization

```yaml
# Good: Clear, descriptive names
name: user_data_sync
description: Synchronize user data from CRM to database

# Good: Logical step names
steps:
  - name: fetch_from_crm
  - name: validate_data
  - name: update_database

# Avoid: Generic names
name: workflow1
steps:
  - name: step1
  - name: step2
```

### Error Handling

```yaml
# Always define error handlers for critical workflows
handlerOn:
  failure:
    - name: cleanup
      command: ./cleanup.sh
    - name: notify
      executor:
        type: mail
        config:
          to: team@example.com

# Use retries for flaky operations
steps:
  - name: api_call
    command: curl https://api.example.com
    retryPolicy:
      limit: 3
      intervalSec: 5
      exponentialBackoff: true
```

### Environment Management

```yaml
# Use parameters for environment-specific values
params: ENVIRONMENT=development

# Load environment from files
env:
  - config/$ENVIRONMENT.env

# Override in production
# dagu start workflow.yaml ENVIRONMENT=production
```

### Modular Workflows

```yaml
# Break complex workflows into sub-workflows
steps:
  - name: data_ingestion
    run: workflows/ingestion.yaml

  - name: data_transformation
    run: workflows/transformation.yaml
    depends:
      - data_ingestion
```

## Key Principles

- **Keep workflows focused**: One workflow per logical task
- **Use dependencies wisely**: Parallelize when possible
- **Handle errors explicitly**: Define failure handlers
- **Use retries for flaky operations**: Network calls, external APIs
- **Parameterize configurations**: Make workflows reusable
- **Document workflows**: Add clear names and descriptions
- **Test workflows**: Start with small, focused workflows
- **Monitor and alert**: Use handlers to track workflow health

## References

- `references/executors.md` — Command (default), Docker, SSH, HTTP, Mail, and JQ executor configuration
- `references/steps-and-flow.md` — step dependencies, data flow, environment variables, parameters, sub-workflows, handlers, templating
- `references/common-patterns.md` — complete ETL, multi-environment deployment, backup, and monitoring workflow artifacts
