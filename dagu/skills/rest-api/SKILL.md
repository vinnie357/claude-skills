---
name: dagu-rest-api
description: Guide for using the Dagu REST API to programmatically manage and execute workflows, query status, and integrate with external systems
---

# Dagu REST API

Use this skill when integrating Dagu with external systems, automating workflow operations, or programmatically managing workflows through the API.

## When to Use This Skill

Activate when:
- Triggering workflows programmatically
- Querying workflow status from applications
- Building automation around Dagu
- Integrating Dagu with CI/CD pipelines
- Creating custom dashboards or monitoring tools
- Scheduling workflows dynamically
- Fetching execution logs programmatically

## Core API Capabilities

The Dagu REST API provides endpoints for:

1. **Workflow Operations** - Start, stop, retry workflows
2. **Status Queries** - Get workflow and execution status
3. **DAG Management** - List and inspect workflow definitions
4. **Execution History** - Query past executions
5. **Log Retrieval** - Fetch execution logs

## Base URL

Default API base URL: `http://localhost:8080/api/v1`

Configure in Dagu settings if using a different host/port.

## Authentication

Consult `references/authentication.md` for details on:
- API token configuration
- Authentication headers
- Security best practices

## Quick Start Operations

### Start a Workflow

```bash
POST /dags/{dagName}/start
```

Basic example:
```bash
curl -X POST http://localhost:8080/api/v1/dags/my_workflow/start
```

For parameter passing and advanced options, see `references/workflow-operations.md`.

### Get Workflow Status

```bash
GET /dags/{dagName}/status
```

Returns current status, running steps, and execution details.

### Stop a Workflow

```bash
POST /dags/{dagName}/stop
```

Stops currently running execution.

## When to Consult References

- **Detailed endpoint documentation**: Read `references/api-endpoints.md`
- **Workflow operations (start/stop/retry)**: Read `references/workflow-operations.md`
- **Status and monitoring queries**: Read `references/status-queries.md`
- **Authentication setup**: Read `references/authentication.md`
- **Integration examples**: Read `references/integration-examples.md`
- **Error handling**: Read `references/error-handling.md`

## Common Use Cases

### CI/CD Integration

Trigger Dagu workflows from your CI/CD pipeline:

```bash
# In GitHub Actions, GitLab CI, etc.
curl -X POST http://dagu-server:8080/api/v1/dags/deploy_production/start \
  -H "Content-Type: application/json" \
  -d '{"params": "VERSION=1.2.3 ENVIRONMENT=production"}'
```

For complete CI/CD integration patterns, see `references/integration-examples.md`.

### Monitoring and Alerting

Query workflow status for external monitoring:

```bash
# Check if workflow is running
curl http://localhost:8080/api/v1/dags/critical_job/status
```

Build custom alerts based on status responses. See `references/status-queries.md` for response format details.

### Dynamic Scheduling

Trigger workflows based on external events:

```python
import requests

def trigger_workflow(dag_name, params=None):
    url = f"http://localhost:8080/api/v1/dags/{dag_name}/start"
    data = {"params": params} if params else {}
    response = requests.post(url, json=data)
    return response.json()
```

For comprehensive examples in multiple languages, see `references/integration-examples.md`.

## Response Formats

All API responses are JSON. Common response structure:

```json
{
  "status": "success",
  "data": { ... }
}
```

Error responses:
```json
{
  "status": "error",
  "message": "Error description"
}
```

For complete response schemas, consult `references/api-endpoints.md`.

## Key Principles

- **RESTful design**: Standard HTTP methods (GET, POST, DELETE)
- **JSON responses**: All responses in JSON format
- **Idempotent operations**: Safe to retry most operations
- **Error codes**: Standard HTTP status codes
- **Stateless**: Each request is independent

## Pro Tips

- Use the API for automation, use Web UI for manual operations
- Implement retry logic for network failures
- Cache DAG lists if querying frequently
- Use webhooks for event-driven workflows when possible
- Monitor API response times for performance issues
- Validate workflow names before calling API to avoid errors
