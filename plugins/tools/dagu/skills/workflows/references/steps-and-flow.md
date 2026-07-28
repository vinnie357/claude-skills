# Dagu Steps, Flow, and Configuration Reference

Step dependency patterns, inter-step data flow, environment variables, parameters,
sub-workflows, handlers, and templating syntax for Dagu workflows. Executor type
catalog (Docker, SSH, HTTP, Mail, JQ) lives in executors.md.

## Contents

- [Step Dependencies](#step-dependencies)
- [Data Flow](#data-flow)
- [Environment Variables](#environment-variables)
- [Parameters](#parameters)
- [Sub-Workflows](#sub-workflows)
- [Handlers](#handlers)
- [Templates and Variables](#templates-and-variables)

## Step Dependencies

### Simple Dependencies

```yaml
steps:
  - name: download
    command: wget https://example.com/data.zip

  - name: extract
    depends:
      - download
    command: unzip data.zip

  - name: process
    depends:
      - extract
    command: ./process.sh
```

### Multiple Dependencies

```yaml
steps:
  - name: fetch_data
    command: ./fetch.sh

  - name: fetch_config
    command: ./fetch_config.sh

  - name: process
    depends:
      - fetch_data
      - fetch_config
    command: ./process.sh
```

### Parallel Execution

```yaml
# These run in parallel (no dependencies)
steps:
  - name: task1
    command: ./task1.sh

  - name: task2
    command: ./task2.sh

  - name: task3
    command: ./task3.sh

  # This waits for all above to complete
  - name: finalize
    depends:
      - task1
      - task2
      - task3
    command: ./finalize.sh
```


## Data Flow

### Output Variables

```yaml
steps:
  - name: generate_id
    command: echo "ID_$(date +%s)"
    output: PROCESS_ID

  - name: use_id
    depends:
      - generate_id
    command: echo "Processing with ID: $PROCESS_ID"
```

### Script Output

```yaml
steps:
  - name: get_config
    script: |
      #!/bin/bash
      export DB_HOST="localhost"
      export DB_PORT="5432"
    output: DB_CONFIG

  - name: connect
    depends:
      - get_config
    command: ./connect.sh $DB_HOST $DB_PORT
```


## Environment Variables

### Global Environment

```yaml
env:
  - ENVIRONMENT: production
  - LOG_LEVEL: info
  - API_URL: https://api.example.com

steps:
  - name: use_env
    command: echo "Environment: $ENVIRONMENT"
```

### Step-Level Environment

```yaml
steps:
  - name: with_custom_env
    env:
      - CUSTOM_VAR: value
      - OVERRIDE: step_value
    command: ./script.sh
```

### Environment from File

```yaml
env:
  - .env  # Load from .env file

steps:
  - name: use_env_file
    command: echo "DB_HOST: $DB_HOST"
```


## Parameters

### Defining Parameters

```yaml
params: ENVIRONMENT=development VERSION=1.0.0

steps:
  - name: deploy
    command: ./deploy.sh $ENVIRONMENT $VERSION
```

### Using Parameters

```bash
# Run with default parameters
dagu start workflow.yaml

# Override parameters
dagu start workflow.yaml ENVIRONMENT=production VERSION=2.0.0
```


## Sub-Workflows

### Calling Sub-Workflows

```yaml
# main.yaml
steps:
  - name: run_sub_workflow
    run: sub_workflow.yaml
    params: PARAM=value

  - name: another_sub
    run: workflows/another.yaml
```

### Hierarchical Workflows

```yaml
# orchestrator.yaml
steps:
  - name: data_ingestion
    run: workflows/ingest.yaml

  - name: data_processing
    depends:
      - data_ingestion
    run: workflows/process.yaml

  - name: data_export
    depends:
      - data_processing
    run: workflows/export.yaml
```


## Handlers

### Cleanup Handler

```yaml
handlerOn:
  exit:
    - name: cleanup
      command: ./cleanup.sh

steps:
  - name: main_task
    command: ./task.sh
```

### Error Handler

```yaml
handlerOn:
  failure:
    - name: send_alert
      executor:
        type: mail
        config:
          to: alerts@example.com
          subject: "Workflow Failed"
          message: "Workflow {{.Name}} failed at {{.timestamp}}"

steps:
  - name: risky_operation
    command: ./operation.sh
```

### Success Handler

```yaml
handlerOn:
  success:
    - name: notify_success
      command: ./notify.sh "Workflow completed successfully"

steps:
  - name: task
    command: ./task.sh
```


## Templates and Variables

### Built-in Variables

```yaml
steps:
  - name: use_variables
    command: |
      echo "Workflow: {{.Name}}"
      echo "Step: {{.Step.Name}}"
      echo "Timestamp: {{.timestamp}}"
      echo "Request ID: {{.requestId}}"
```

### Custom Templates

```yaml
params: USER=alice

steps:
  - name: templated
    command: echo "Hello, {{.Params.USER}}!"
```

