# Dagu Web UI: Workflow Monitoring Reference

This document provides detailed information about monitoring workflows through the Dagu Web UI.

## Execution Status Indicators

### Status Colors and Meanings

- **Green (Running)**: Workflow is currently executing
- **Blue (Success)**: Workflow completed successfully
- **Red (Failed)**: Workflow encountered an error
- **Yellow (Pending)**: Workflow scheduled but not yet started
- **Gray (Stopped)**: Workflow was manually stopped

### Step-Level Status

Each step within a workflow shows its own status:
- **Waiting**: Step hasn't started (dependencies not met)
- **Running**: Step currently executing
- **Done**: Step completed successfully
- **Error**: Step failed
- **Skipped**: Step skipped due to conditions

## Real-Time Log Viewing

### Accessing Logs

1. Click on the workflow execution
2. View the step list
3. Click any step name to see its logs
4. Logs update in real-time for running steps

### Log Features

- **Auto-scroll**: Logs automatically scroll to show newest entries
- **Search**: Use browser search (Ctrl+F) to find specific log entries
- **Copy**: Select and copy log text for external analysis
- **Download**: Download full logs for archiving

## Progress Tracking

### Workflow Progress

The UI shows:
- Total steps in workflow
- Completed steps count
- Currently running steps
- Estimated time remaining (if available)

### Step Progress

For each step:
- Start time
- Duration (elapsed time)
- Output (stdout/stderr)
- Exit code
- Retry attempts (if configured)

## Monitoring Multiple Workflows

### Dashboard View

The main dashboard shows:
- All active workflows
- Recently completed workflows
- Failed workflows requiring attention
- Scheduled upcoming executions

### Filtering and Sorting

- Filter by status (running, failed, success)
- Sort by start time, duration, or name
- Search by workflow name
- Group by tags or categories

## Error Detection

### Identifying Issues

When a step fails, the UI highlights:
- The failed step in red
- Error message from the step
- Exit code (non-zero indicates failure)
- Stack trace if available

### Common Error Patterns

Look for these in logs:
- "Command not found" - Missing executable
- "Permission denied" - File permission issues
- "Connection refused" - Network/service issues
- "No such file or directory" - Missing dependencies

## Performance Monitoring

### Execution Metrics

View these metrics for each workflow:
- Total execution time
- Per-step execution times
- Wait time (time waiting for dependencies)
- Retry count and time spent in retries

### Resource Usage

Some executors (like Docker) may show:
- CPU usage
- Memory consumption
- Network I/O
- Disk usage

## Alerts and Notifications

### Visual Alerts

The UI provides visual indicators for:
- Long-running steps (exceeding expected duration)
- Failed retries
- Workflows approaching timeout
- Resource constraints

### Notification Configuration

Check the workflow's email notification settings:
- Success notifications
- Failure notifications
- Email recipients
- SMTP configuration status

## Troubleshooting Tips

### Workflow Stuck?

If a workflow appears stuck:
1. Check if a step is waiting for dependencies
2. Look for long-running external processes
3. Verify network connectivity for remote executors
4. Check system resource availability

### Logs Not Updating?

If logs aren't showing:
1. Refresh the page
2. Check if the workflow is actually running (verify process)
3. Look for log file permission issues
4. Verify Dagu server is running

### Missing Workflows?

If workflows don't appear:
1. Verify workflow files are in the correct directory
2. Check for YAML syntax errors
3. Restart Dagu server
4. Check server logs for loading errors

## Advanced Monitoring

### Custom Metrics

If your workflow outputs metrics, you can:
- Parse logs for metric values
- Export to external monitoring systems
- Set up alerts based on metric thresholds

### Integration with External Tools

Dagu can integrate with:
- Prometheus for metrics
- Grafana for dashboards
- Elasticsearch for log aggregation
- Datadog or New Relic for observability

## Best Practices

1. **Check status regularly**: Monitor critical workflows actively
2. **Review failure logs immediately**: Quick diagnosis prevents recurring issues
3. **Set up email notifications**: Don't rely solely on UI monitoring
4. **Use workflow tags**: Organize and filter workflows effectively
5. **Archive old executions**: Keep history manageable
6. **Monitor trends**: Look for patterns in execution times and failures
