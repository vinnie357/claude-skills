---
description: "Provision a per-session Claude Code sandbox: render SandboxClaim from template, apply, wait for Bound, print endpoint."
argument-hint: "[--session-id=<id>] [--template=<name>] [--shutdown-time=<rfc3339>]"
---

Create one ephemeral SandboxClaim from a pre-installed SandboxTemplate and return its endpoint.

## Skills to load

- `/agent-sandboxing:k8s-agent-sandbox`
- `/agent-sandboxing:claude-code-on-sandbox`
- `/core:nushell`
- `/core:anti-fabrication`

## Steps

### 1. Determine session id

If `--session-id` is not provided, generate one:

```bash
SESSION_ID=$(uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | head -c 12)
```

### 2. Determine template name

If `--template` is not provided, list installed templates and ask the user which to use:

```bash
kubectl get sandboxtemplate -o name
```

Typical names: `claude-code-kata`, `claude-code-gvisor`, `claude-code-kina`.

### 3. Render the claim

```bash
nu ${CLAUDE_PLUGIN_ROOT}/scripts/render-claim.nu \
  --session-id $SESSION_ID \
  --template $TEMPLATE_NAME \
  ${SHUTDOWN_TIME:+--shutdown-time $SHUTDOWN_TIME} \
  | kubectl apply -f -
```

The script reads `templates/SandboxClaim.session.yaml`, substitutes placeholders, and emits the final YAML to stdout. If the operator wants to inspect before applying, drop the pipe to `kubectl apply`.

### 4. Wait for Bound

```bash
nu ${CLAUDE_PLUGIN_ROOT}/scripts/wait-bound.nu --session-id $SESSION_ID --timeout 120
```

The script polls `kubectl get sandboxclaim` every 2 seconds until `status.phase == Bound` or the timeout elapses. Reports the bound pod name on success; reports controller log excerpts on timeout.

If the claim sticks in Pending, common causes:
- Missing RuntimeClass — `kubectl describe sandboxclaim session-$SESSION_ID` will say so.
- Missing image — `kubectl describe pod ... -n <claim-namespace>` will show ImagePullBackOff.
- Missing `anthropic` secret — pod will be Running but `claude --version` will fail at exec time.

### 5. Report the endpoint

```bash
kubectl get sandboxclaim session-$SESSION_ID -o jsonpath='{.status.endpoint}'
echo
```

Tell the user the session id, the bound pod name, and the endpoint. Suggest the next command is `/agent-sandboxing:exec $SESSION_ID` to run something, or `/agent-sandboxing:reap $SESSION_ID` when done.

## Anti-fabrication

- Don't report Bound without `kubectl get` confirming `phase: Bound`. Phase claims invented from controller log noise are wrong.
- Don't assume the image exists in the registry. If pull fails, surface the actual `ImagePullBackOff` reason from `kubectl describe pod`.
- Don't paste this command's output without the actual `session-<id>` substring — generic confirmations are useless to the operator.
