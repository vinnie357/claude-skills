# Dagu REST API: Complete Endpoint Reference

This document provides detailed information about all available Dagu REST API endpoints.

## Base URL

```
http://localhost:8080/api/v1
```

## Workflow Management Endpoints

### List All DAGs

```
GET /dags
```

**Response:**
```json
{
  "DAGs": [
    {
      "File": "/path/to/workflow.yaml",
      "Dir": "/workflows",
      "DAG": {
        "Name": "my_workflow",
        "Schedule": "0 2 * * *",
        "Description": "Description of workflow"
      },
      "Status": {
        "Status": "running",
        "StatusText": "Running",
        "PID": 12345,
        "StartedAt": "2024-01-15T10:00:00Z"
      },
      "Suspended": false,
      "Error": null
    }
  ],
  "Errors": [],
  "HasError": false
}
```

### Get DAG Details

```
GET /dags/{dagName}
```

**Path Parameters:**
- `dagName`: Name of the workflow

**Response:**
```json
{
  "Title": "My Workflow",
  "DAG": {
    "Name": "my_workflow",
    "Schedule": "0 2 * * *",
    "Description": "Workflow description",
    "Env": ["KEY=value"],
    "Steps": [
      {
        "Name": "step1",
        "Command": "echo 'Hello'",
        "Depends": []
      }
    ]
  },
  "Tab": "status"
}
```

### Get DAG Spec (Raw YAML)

```
GET /dags/{dagName}/spec
```

Returns the raw YAML content of the workflow file.

## Workflow Execution Endpoints

### Start Workflow

```
POST /dags/{dagName}/start
```

**Request Body:**
```json
{
  "params": "PARAM1=value1 PARAM2=value2"
}
```

**Response:**
```json
{
  "RequestId": "20240115-100000-abc123"
}
```

### Stop Workflow

```
POST /dags/{dagName}/stop
```

**Query Parameters:**
- `requestId`: Optional. Specific execution to stop

**Response:**
```json
{
  "status": "success"
}
```

### Retry Workflow

```
POST /dags/{dagName}/retry
```

**Query Parameters:**
- `requestId`: Required. Execution to retry

**Response:**
```json
{
  "RequestId": "20240115-110000-def456"
}
```

### Restart Workflow

```
POST /dags/{dagName}/restart
```

**Query Parameters:**
- `requestId`: Optional. Specific execution to restart

Stops current execution and starts new one.

## Status and Monitoring Endpoints

### Get Workflow Status

```
GET /dags/{dagName}/status
```

**Response:**
```json
{
  "Status": {
    "Name": "my_workflow",
    "Status": "running",
    "StatusText": "Running",
    "PID": 12345,
    "Nodes": [
      {
        "Step": {
          "Name": "step1",
          "Command": "echo 'Hello'"
        },
        "Status": "success",
        "StatusText": "Finished",
        "Log": "Hello\n",
        "StartedAt": "2024-01-15T10:00:00Z",
        "FinishedAt": "2024-01-15T10:00:01Z",
        "RetryCount": 0,
        "DoneCount": 1,
        "Error": ""
      }
    ],
    "OnExit": null,
    "OnSuccess": null,
    "OnFailure": null,
    "OnCancel": null,
    "StartedAt": "2024-01-15T10:00:00Z",
    "FinishedAt": "2024-01-15T10:05:00Z",
    "RequestId": "20240115-100000-abc123",
    "Params": "PARAM1=value1"
  }
}
```

### Get Execution Log

```
GET /dags/{dagName}/log
```

**Query Parameters:**
- `requestId`: Optional. Specific execution log
- `file`: Optional. Specific log file name

**Response:**
Plain text log content.

## History Endpoints

### List Execution History

```
GET /dags/{dagName}/history
```

**Response:**
```json
{
  "GridData": [
    {
      "Name": "my_workflow",
      "RequestId": "20240115-100000-abc123",
      "StartedAt": "2024-01-15T10:00:00",
      "FinishedAt": "2024-01-15T10:05:00",
      "Status": "success",
      "StatusText": "Finished",
      "Params": "PARAM1=value1",
      "Log": "/path/to/log"
    }
  ],
  "Pagination": {
    "PageCount": 10,
    "Page": 1,
    "PerPage": 20
  }
}
```

### Get Specific Execution Details

```
GET /dags/{dagName}/history/{requestId}
```

Returns detailed status for a specific execution.

### Delete Execution History

```
DELETE /dags/{dagName}/history/{requestId}
```

Deletes a specific execution record and its logs.

## DAG Management Endpoints

### Create/Update DAG

```
POST /dags/{dagName}
```

**Request Body:**
```json
{
  "action": "save",
  "value": "name: my_workflow\nsteps:\n  - name: step1\n    command: echo 'Hello'"
}
```

Creates or updates a workflow file.

### Rename DAG

```
POST /dags/{dagName}
```

**Request Body:**
```json
{
  "action": "rename",
  "value": "new_workflow_name"
}
```

### Delete DAG

```
DELETE /dags/{dagName}
```

Deletes the workflow file.

## Search Endpoints

### Search DAGs

```
POST /search
```

**Request Body:**
```json
{
  "query": "search term"
}
```

**Response:**
```json
{
  "Results": [
    {
      "Name": "my_workflow",
      "DAG": { ... },
      "Matches": [
        {
          "Line": 5,
          "StartLine": 3,
          "Col": 10,
          "EndCol": 20,
          "Match": "matched text"
        }
      ]
    }
  ],
  "Errors": []
}
```

## HTTP Status Codes

- `200 OK`: Successful request
- `400 Bad Request`: Invalid request parameters
- `404 Not Found`: DAG or resource not found
- `500 Internal Server Error`: Server error

## Error Response Format

```json
{
  "error": "Error message description"
}
```

## Common Query Parameters

### Pagination

Many list endpoints support pagination:
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20)

Example:
```
GET /dags/my_workflow/history?page=2&limit=50
```

## Headers

### Request Headers

- `Content-Type: application/json`: For POST/PUT requests with JSON body

### Response Headers

- `Content-Type: application/json`: JSON responses
- `Content-Type: text/plain`: Log file responses

## Rate Limiting

Currently no rate limiting is implemented. Use responsibly.

## Webhooks (if configured)

If webhooks are enabled, Dagu can send notifications to external URLs on workflow events.

Configure in workflow YAML:
```yaml
webhooks:
  - url: https://example.com/webhook
    events: [success, failure]
```

## Best Practices

1. **Always check status codes**: Don't assume success
2. **Handle 404s gracefully**: Workflow might be deleted
3. **Parse JSON errors**: Error messages are in response body
4. **Use request IDs**: Track specific executions
5. **Implement timeouts**: Don't wait indefinitely for responses
6. **Cache DAG lists**: Avoid frequent list calls
7. **Use specific endpoints**: Prefer specific queries over listing all
