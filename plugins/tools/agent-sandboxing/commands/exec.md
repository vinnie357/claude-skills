---
description: "Exec into a Bound SandboxClaim's pod and run a command (defaults to interactive claude --print)."
argument-hint: "<session-id> [-- <command> [args...]]"
---

Run a command inside a provisioned sandbox pod via `kubectl exec`.

## Skills to load

- `/agent-sandboxing:k8s-agent-sandbox`
- `/agent-sandboxing:claude-code-on-sandbox`
- `/core:anti-fabrication`

## Steps

### 1. Parse arguments

- First positional arg = session id (required). Resolve to `session-<id>` if the user passed the short form.
- Everything after `--` is the command to run inside the pod. If absent, default to `claude --print --output-format json` (the image's CMD).

### 2. Verify the claim is Bound

```bash
PHASE=$(kubectl get sandboxclaim session-$SESSION_ID -o jsonpath='{.status.phase}')
if [ "$PHASE" != "Bound" ]; then
  echo "claim session-$SESSION_ID is in phase $PHASE; aborting"
  exit 1
fi
```

If not Bound, suggest `/agent-sandboxing:provision $SESSION_ID` first, or `kubectl describe sandboxclaim session-$SESSION_ID` to diagnose.

### 3. Resolve the bound pod

```bash
POD=$(kubectl get sandboxclaim session-$SESSION_ID -o jsonpath='{.status.boundSandbox.name}')
```

(Field name varies between API versions; check `kubectl get sandboxclaim ... -o yaml` if jsonpath is empty.)

### 4. Exec

```bash
kubectl exec -it sandbox/$POD -- <command>
```

For the default interactive case (claude --print):

```bash
kubectl exec -it sandbox/$POD -- claude --print --output-format json
```

For an ad-hoc shell:

```bash
kubectl exec -it sandbox/$POD -- /bin/bash
```

## Anti-fabrication

- Don't fake the output. If the exec fails (pod not ready, command not found, permission denied), report the verbatim stderr.
- If the user passed args expecting an interactive session, but kubectl is being invoked non-interactively (no TTY), warn them — `claude --print` works either way but `bash` doesn't.
