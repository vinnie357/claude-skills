# `~/.claude` named volume for session persistence

Claude Code stores auth state, session history, settings, and per-project context at `$CLAUDE_CONFIG_DIR` (defaults to `~/.claude`, mapped to `/home/agent/.claude` in the plugin's Dockerfile). Whether to persist this across SandboxClaims is a per-use-case decision.

## When to persist

- **Resume long sessions** across SandboxClaims: yes, mount a PVC.
- **Track Claude Code preferences** per operator/tenant: yes.
- **Run truly ephemeral one-shot jobs** (CI, autonomous loops): no — let the dir live in the pod's tmpfs and disappear at session end.

## PVC + StorageClass

Allocate one PVC per persistent identity (per operator, per tenant, per long-running session). Storage class depends on the cluster:

- **GKE**: `standard-rwo` for single-node access (Block) or `standard-rwx` for multi-pod access (Filestore). For a single SandboxClaim at a time, `standard-rwo` is fine and cheaper.
- **kind + local-path-provisioner**: `standard` (the default with `kind`).
- **kina**: kina ships a PTP CNI by default; check `kubectl get sc` and use whichever default StorageClass kina installs.

Minimal PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claude-home
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Gi
  storageClassName: standard-rwo  # adjust per cluster
```

Mount into the SandboxTemplate:

```yaml
spec:
  podTemplate:
    spec:
      containers:
        - name: claude
          volumeMounts:
            - name: claude-home
              mountPath: /home/agent/.claude
      volumes:
        - name: claude-home
          persistentVolumeClaim:
            claimName: claude-home
```

## Per-tenant separation

For multi-tenant deployments, each tenant gets its own PVC:

```yaml
# Tenant A
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claude-home-tenant-a
  namespace: tenant-a
spec: ...
```

Then the SandboxTemplate lives in the tenant's namespace and references the tenant-scoped PVC. agent-sandbox's `SandboxClaim` honors the template's namespace; cross-namespace claims aren't supported.

## Sizing

- Auth + settings: < 10 MB.
- Per-session conversation history: typically 1–50 MB for a multi-hour session.
- Long-lived workspace context (file caches, command history): up to a few hundred MB.

2 GiB is comfortable for years of moderate use. Bump to 10 GiB if the SandboxTemplate also stages a checked-out repo into `/home/agent`.

## Read-only auth, writable cache

For a hardened production posture, split the auth from the cache:

```yaml
volumeMounts:
  - { name: claude-auth, mountPath: /home/agent/.claude/auth.json, subPath: auth.json, readOnly: true }
  - { name: claude-cache, mountPath: /home/agent/.claude }
volumes:
  - name: claude-auth
    secret:
      secretName: claude-auth
      items: [{ key: auth.json, path: auth.json }]
  - name: claude-cache
    emptyDir: {}
```

Auth comes from a secret (immutable); the rest of `~/.claude` is ephemeral. Trades convenience (no session resume) for stronger isolation.

## Garbage collection

Persistent `~/.claude` volumes accumulate session history. Long-term, the dir grows. Schedule a CronJob (or a kina/operator-side mise task) that prunes stale data:

```bash
# Inside the pod:
find /home/agent/.claude/sessions -mtime +90 -delete
```

For a SandboxWarmPool that recycles pods, mount the PVC `readOnly: false` so the pool's pods write back. Note that pool-replacement can leave the PVC bound to the old pod for a few seconds — don't share one PVC across multiple concurrent pool replicas.

## On kina

kina's storage layer is Apple Container's volume mechanism. The PVC binding works the same as kind, but performance characteristics differ — Apple Container volumes are typically slower than native ext4 on Linux. For dev work, fine. For benchmarking session-load times, expect higher latency than kind on Linux.
