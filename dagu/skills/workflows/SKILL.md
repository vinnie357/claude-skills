---
name: dagu-workflows
description: Guide for authoring Dagu workflows including YAML syntax, steps, executors, scheduling, dependencies, and workflow composition
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

### Command Executor (Default)

```yaml
steps:
  - name: shell_command
    command: ./script.sh
```

### Docker Executor

```yaml
steps:
  - name: run_in_container
    executor:
      type: docker
      config:
        image: alpine:latest
    command: echo "Running in Docker"

  - name: with_volumes
    executor:
      type: docker
      config:
        image: node:18
        volumes:
          - /host/path:/container/path
        env:
          - NODE_ENV=production
    command: npm run build
```

### SSH Executor

```yaml
steps:
  - name: remote_execution
    executor:
      type: ssh
      config:
        user: deploy
        host: server.example.com
        key: /path/to/ssh/key
    command: ./remote_script.sh
```

### HTTP Executor

```yaml
steps:
  - name: api_call
    executor:
      type: http
      config:
        method: POST
        url: https://api.example.com/webhook
        headers:
          Content-Type: application/json
          Authorization: Bearer $API_TOKEN
        body: |
          {
            "event": "workflow_complete",
            "timestamp": "{{.timestamp}}"
          }
```

### Mail Executor

```yaml
steps:
  - name: send_notification
    executor:
      type: mail
      config:
        to: user@example.com
        from: dagu@example.com
        subject: Workflow Complete
        message: |
          The workflow has completed successfully.
          Time: {{.timestamp}}
```

### JQ Executor

```yaml
steps:
  - name: transform_json
    executor:
      type: jq
      config:
        query: '.users[] | select(.active == true) | .email'
    command: cat users.json
```

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

## Common Patterns

### ETL Pipeline

```yaml
name: etl_pipeline
description: Extract, Transform, Load data pipeline

schedule: "0 2 * * *"  # Daily at 2 AM

env:
  - DATA_SOURCE: s3://bucket/data
  - TARGET_DB: postgresql://localhost/warehouse

steps:
  - name: extract
    command: ./extract.sh $DATA_SOURCE
    output: EXTRACTED_FILE

  - name: transform
    depends:
      - extract
    command: ./transform.sh $EXTRACTED_FILE
    output: TRANSFORMED_FILE

  - name: load
    depends:
      - transform
    command: ./load.sh $TRANSFORMED_FILE $TARGET_DB

  - name: cleanup
    depends:
      - load
    command: rm -f $EXTRACTED_FILE $TRANSFORMED_FILE

handlerOn:
  failure:
    - name: alert
      executor:
        type: mail
        config:
          to: data-team@example.com
          subject: "ETL Pipeline Failed"
```

### Multi-Environment Deployment

```yaml
name: deploy
description: Deploy application to multiple environments

params: ENVIRONMENT=staging VERSION=latest

steps:
  - name: build
    command: docker build -t app:$VERSION .

  - name: test
    depends:
      - build
    command: docker run app:$VERSION npm test

  - name: deploy_staging
    depends:
      - test
    preconditions:
      - condition: "`echo $ENVIRONMENT`"
        expected: "staging"
    executor:
      type: ssh
      config:
        user: deploy
        host: staging.example.com
    command: ./deploy.sh $VERSION

  - name: deploy_production
    depends:
      - test
    preconditions:
      - condition: "`echo $ENVIRONMENT`"
        expected: "production"
    executor:
      type: ssh
      config:
        user: deploy
        host: prod.example.com
    command: ./deploy.sh $VERSION
```

### Data Backup Workflow

```yaml
name: database_backup
description: Automated database backup workflow

schedule: "0 3 * * *"  # Daily at 3 AM

env:
  - DB_HOST: localhost
  - DB_NAME: myapp
  - BACKUP_DIR: /backups
  - S3_BUCKET: s3://backups/db

steps:
  - name: create_backup
    command: |
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      pg_dump -h $DB_HOST $DB_NAME > $BACKUP_DIR/backup_$TIMESTAMP.sql
      echo "backup_$TIMESTAMP.sql"
    output: BACKUP_FILE

  - name: compress
    depends:
      - create_backup
    command: gzip $BACKUP_DIR/$BACKUP_FILE
    output: COMPRESSED_FILE

  - name: upload_to_s3
    depends:
      - compress
    command: aws s3 cp $BACKUP_DIR/$COMPRESSED_FILE.gz $S3_BUCKET/

  - name: cleanup_old_backups
    depends:
      - upload_to_s3
    command: |
      find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete
      aws s3 ls $S3_BUCKET/ | awk '{print $4}' | head -n -30 | xargs -I {} aws s3 rm $S3_BUCKET/{}

handlerOn:
  failure:
    - name: alert_failure
      executor:
        type: mail
        config:
          to: dba@example.com
          subject: "Backup Failed"
  success:
    - name: log_success
      command: echo "Backup completed at $(date)" >> /var/log/backups.log
```

### Monitoring and Alerts

```yaml
name: health_check
description: Monitor services and send alerts

schedule: "*/5 * * * *"  # Every 5 minutes

steps:
  - name: check_web_service
    command: curl -f https://app.example.com/health
    retryPolicy:
      limit: 3
      intervalSec: 10
    continueOn:
      failure: true

  - name: check_api_service
    command: curl -f https://api.example.com/health
    retryPolicy:
      limit: 3
      intervalSec: 10
    continueOn:
      failure: true

  - name: check_database
    command: pg_isready -h db.example.com
    continueOn:
      failure: true

handlerOn:
  failure:
    - name: alert_on_failure
      executor:
        type: http
        config:
          method: POST
          url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
          headers:
            Content-Type: application/json
          body: |
            {
              "text": "⚠️ Service health check failed",
              "attachments": [{
                "color": "danger",
                "fields": [
                  {"title": "Workflow", "value": "{{.Name}}", "short": true},
                  {"title": "Time", "value": "{{.timestamp}}", "short": true}
                ]
              }]
            }
```

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
