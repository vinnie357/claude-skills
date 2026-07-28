# Dagu Executors Reference

Full executor type catalog for Dagu workflow steps. Step dependency, data flow,
environment, parameter, sub-workflow, handler, and templating syntax live in
steps-and-flow.md.

## Contents

- [Command Executor (Default)](#command-executor-default)
- [Docker Executor](#docker-executor)
- [SSH Executor](#ssh-executor)
- [HTTP Executor](#http-executor)
- [Mail Executor](#mail-executor)
- [JQ Executor](#jq-executor)

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

