# Per-session lifecycle and warm pools

How a `SandboxClaim` becomes a running pod and how it gets reaped.

## States

`SandboxClaim.status.phase` transitions:

```
Pending → Bound → Terminating → (deleted)
```

- **Pending** — controller is binding the claim. If a `SandboxWarmPool` is referenced and has a ready replica, this is sub-second. Otherwise the controller schedules a fresh pod from the template, which takes normal Pod scheduling time.
- **Bound** — the claim has a pod. `status.endpoint` is populated. Caller can exec, port-forward, or hit the router endpoint.
- **Terminating** — `shutdownPolicy: Delete` is reaping, or the user ran `kubectl delete sandboxclaim`. Pod is being torn down.

## Shutdown policies

`spec.lifecycle.shutdownPolicy` values:

- `Delete` — controller deletes the pod when `shutdownTime` is reached OR when the claim is deleted. Default for ephemeral sessions.
- `Retain` — controller leaves the pod for forensic inspection. Useful for debugging a failed agent run.

`spec.lifecycle.shutdownTime` — RFC3339 timestamp. If set, controller honors it even without an explicit `kubectl delete`. If unset and `shutdownPolicy: Delete`, the pod lives until the claim is deleted.

## Per-claim env injection

`spec.env` on the claim is appended to every container in the template. Use this to inject secrets that must not live in the template (e.g. per-tenant API keys):

```yaml
spec:
  env:
    - name: ANTHROPIC_API_KEY
      valueFrom:
        secretKeyRef:
          name: anthropic-${TENANT_ID}
          key: api-key
```

Templates stay generic; claims inject per-session identity.

## Warm pools

For interactive sessions (Claude Code on a laptop), Pod scheduling time (5–15 seconds for a Kata pod with image pull) is noticeable. `SandboxWarmPool` keeps N pods pre-pulled, pre-scheduled, and idle so claims bind in sub-second.

```yaml
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxWarmPool
metadata:
  name: claude-code-kata-pool
spec:
  sandboxTemplateRef:
    name: claude-code-kata
  replicas: 3
```

A `SandboxClaim` opts into the pool with `spec.warmPoolRef.name`:

```yaml
spec:
  sandboxTemplateRef:
    name: claude-code-kata
  warmPoolRef:
    name: claude-code-kata-pool
```

Watch the pool come up:

```bash
kubectl get sandboxwarmpool claude-code-kata-pool -w
kubectl describe sandboxwarmpool claude-code-kata-pool
```

Pool size tradeoff: replicas idle on the cluster cost compute even when no session is active. Size to peak concurrency, not to total user count.

## Pool churn on template updates

When you change the underlying `SandboxTemplate` (image tag bump, env addition), the pool rolls — old replicas drain, new ones spin up. There's a brief window where the pool has fewer than `spec.replicas` ready. Plan template updates outside peak claim hours.

## Verification commands

```bash
# Watch a claim transition
kubectl get sandboxclaim session-abc123 -w

# Inspect why a claim is Pending
kubectl describe sandboxclaim session-abc123

# Controller logs
kubectl logs -n agent-sandbox-system deploy/agent-sandbox-controller -f

# Exec into the bound pod
kubectl exec -it sandbox/session-abc123 -- /bin/sh
```
