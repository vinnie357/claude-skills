# Operational Patterns and Troubleshooting

Runtime patterns supporting the twelve factors: health checks, graceful degradation, and a troubleshooting guide for common 12-factor violations.

## Health Checks

Implement health and readiness endpoints:

```javascript
// Liveness probe
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

// Readiness probe
app.get('/ready', async (req, res) => {
  try {
    await db.ping();
    await redis.ping();
    res.status(200).json({ status: 'ready' });
  } catch (err) {
    res.status(503).json({ status: 'not ready', error: err.message });
  }
});
```

Kubernetes probe manifests wiring these endpoints are in `kubernetes.md`.

## Graceful Degradation

Handle backing service failures gracefully:

```javascript
async function getCachedData(key) {
  try {
    return await redis.get(key);
  } catch (err) {
    logger.warn('Redis unavailable, falling back to database', { error: err.message });
    return await db.query('SELECT data FROM cache WHERE key = ?', [key]);
  }
}
```

## Troubleshooting Guide

### Application Won't Start

1. Check required environment variables are set
2. Validate configuration at startup
3. Check backing service connectivity
4. Review logs for initialization errors

### Application Won't Scale

1. Identify stateful operations
2. Move state to backing services
3. Remove file system dependencies
4. Eliminate sticky sessions

### Inconsistent Behavior Across Environments

1. Ensure same backing service types (not SQLite in dev, Postgres in prod)
2. Use containers for dev environment
3. Check for environment-specific code paths
4. Verify configuration is environment-only

### Logs Not Appearing

1. Ensure writing to stdout/stderr
2. Avoid buffering log output
3. Check log aggregation configuration
4. Verify Kubernetes logging sidecar/daemonset
