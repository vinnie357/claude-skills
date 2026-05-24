---
description: "Delete a SandboxClaim and tear down its bound pod. Pass --all to reap every claim in the current namespace."
argument-hint: "<session-id> | --all"
---

Tear down one (or all) SandboxClaims.

## Skills to load

- `/agent-sandboxing:k8s-agent-sandbox`
- `/core:anti-fabrication`

## Steps

### Single claim

```bash
kubectl delete sandboxclaim session-$SESSION_ID
```

`shutdownPolicy: Delete` on the claim's spec.lifecycle means the controller reaps the bound pod as part of the delete. No additional cleanup needed.

### All claims (operator opt-in only)

```bash
kubectl get sandboxclaim --no-headers -o custom-columns=NAME:.metadata.name | while read claim; do
  kubectl delete sandboxclaim $claim
done
```

This is destructive — confirm with the user before proceeding. Useful at end-of-day or during cluster cleanup.

### Verify

```bash
kubectl get sandboxclaim session-$SESSION_ID 2>&1 | grep -q "NotFound" && echo "reaped"
```

For `--all`, run `/agent-sandboxing:status` afterwards to confirm zero claims remain.

## Anti-fabrication

- Don't claim a reap succeeded without `kubectl get` showing `NotFound`.
- Don't run `--all` without explicit user confirmation. Listing 17 active claims and reaping them all without warning would lose work.
