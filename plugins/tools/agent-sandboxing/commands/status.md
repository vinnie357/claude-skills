---
description: "List all SandboxClaims with phase, age, template, and bound pod. Detects stuck-in-Pending claims and surfaces likely causes."
argument-hint: "[--namespace=<ns>] [--watch]"
---

Show the live state of all SandboxClaims for at-a-glance triage.

## Skills to load

- `/agent-sandboxing:k8s-agent-sandbox`
- `/core:nushell`
- `/core:anti-fabrication`

## Steps

### 1. Render the table

```bash
nu ${CLAUDE_PLUGIN_ROOT}/scripts/list-claims.nu ${NAMESPACE:+--namespace $NAMESPACE}
```

The script wraps `kubectl get sandboxclaim -o json`, extracts session id, phase, template ref, bound pod, age, and shutdown policy, and emits a nushell table.

### 2. Annotate stuck claims

For any claim in `Pending` for >60 seconds, run:

```bash
kubectl describe sandboxclaim <name>
```

Common stuck-in-Pending causes:

- **Missing RuntimeClass** — controller condition will say `RuntimeClass "kata-qemu" not found`.
- **ImagePullBackOff** on the underlying pod — `kubectl get pod -l agent-sandbox.x-k8s.io/claim=<name>` then `describe pod`.
- **Missing secret** — controller condition will mention the referenced Secret.
- **WarmPool drained** — `kubectl describe sandboxwarmpool` shows 0 ready replicas.

Surface the actual condition text, not a guess.

### 3. Watch mode

If `--watch` was passed:

```bash
watch -n 2 "nu ${CLAUDE_PLUGIN_ROOT}/scripts/list-claims.nu"
```

Or with kubectl directly:

```bash
kubectl get sandboxclaim -w
```

## Anti-fabrication

- Don't summarize claim state from memory. Always re-run `kubectl get` for fresh data.
- Don't claim a stuck claim is "almost ready" without timestamps to back it up — pull `metadata.creationTimestamp` and compare to now.
