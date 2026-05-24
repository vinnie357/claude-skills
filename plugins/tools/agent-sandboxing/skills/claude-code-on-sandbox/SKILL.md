---
name: claude-code-on-sandbox
description: Package Claude Code as an OCI image using mise and deploy it as a kubernetes-sigs/agent-sandbox SandboxTemplate workload. Use when building a mise-driven Dockerfile for Claude Code, configuring the ~/.claude named volume for session persistence, injecting ANTHROPIC_API_KEY per SandboxClaim, applying per-pod egress allowlists for api.anthropic.com, or running Claude Code headlessly inside a Kata or gVisor isolated pod.
license: MIT
---

# claude-code-on-sandbox

Claude Code does not ship an officially maintained standalone OCI image. The supported path is the `@anthropic-ai/claude-code` npm CLI plus the Anthropic-published Dev Container Feature (`ghcr.io/anthropics/devcontainer-features/claude-code:1.0`). For sandboxed Kubernetes deployment, the pattern is: build a Dockerfile that installs Claude Code via mise (using the registry short name), wire it into a `SandboxTemplate` that pins a `runtimeClassName`, and let agent-sandbox provision per-session pods from that template.

## When to use

- Building a Dockerfile that packages Claude Code for in-cluster execution.
- Deploying Claude Code as a `SandboxTemplate` workload on a kind/Kata, GKE/Kata, or kina cluster.
- Persisting `~/.claude` (auth, settings, sessions) across SandboxClaims via a PVC.
- Locking down outbound traffic to Anthropic's API only.

## Mise-based Dockerfile

The plugin ships `templates/Dockerfile.claude-code` and `templates/mise.toml.claude-code`. Use them verbatim or adapt.

`Dockerfile.claude-code`:

```dockerfile
# syntax=docker/dockerfile:1.7
FROM debian:12-slim AS base

ARG MISE_VERSION=2026.5.0
ENV MISE_DATA_DIR=/opt/mise \
    CLAUDE_CONFIG_DIR=/home/agent/.claude \
    PATH=/opt/mise/shims:/home/agent/.local/bin:$PATH

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq iproute2 iptables sudo gnupg

RUN useradd -m -u 1000 -s /bin/bash agent
USER agent
WORKDIR /home/agent

RUN curl -fsSL https://mise.run | sh

COPY --chown=agent:agent mise.toml /home/agent/mise.toml

RUN --mount=type=cache,uid=1000,target=/home/agent/.cache/mise \
    /home/agent/.local/bin/mise install

ENTRYPOINT ["/home/agent/.local/bin/mise", "exec", "--", "claude"]
CMD ["--print", "--output-format", "json"]
```

`mise.toml.claude-code`:

```toml
[tools]
node = "lts"
claude-code = "latest"
```

Use the mise registry short name `claude-code` — not `npm:@anthropic-ai/claude-code`. mise's registry maps the short name to the npm package internally, and the short form keeps the template clean.

## BuildKit cache mounts

The Dockerfile uses two BuildKit cache mounts:

- `/var/cache/apt` + `/var/lib/apt/lists` — apt package cache, so repeated builds don't re-download.
- `/home/agent/.cache/mise` — mise's per-tool download cache. The `uid=1000` is critical; mise runs as the `agent` user so the cache must be owned by UID 1000.

Build:

```bash
docker buildx build \
  --tag REGISTRY/claude-code:$(date +%Y%m%d) \
  --push \
  -f templates/Dockerfile.claude-code \
  --build-context templates=templates/ \
  templates/
```

Or with `--load` instead of `--push` for local-only iteration.

## Authentication: `ANTHROPIC_API_KEY` vs OAuth token

Two auth modes:

1. **`ANTHROPIC_API_KEY`** (env var) — direct API key. Simplest. Inject via the SandboxClaim's `spec.env`.
2. **`CLAUDE_CODE_OAUTH_TOKEN`** (env var) — OAuth token from `claude setup-token`. Useful when the operator already has a Claude account and wants billing/usage tied to it.

See `references/auth.md` for the secret/SecretProviderClass patterns and rotation guidance.

## The `~/.claude` named volume

Claude Code stores auth state, session history, and settings at `$CLAUDE_CONFIG_DIR` (defaults to `~/.claude`). For headless, ephemeral sandboxes you can omit this entirely and re-auth per session. For continuity (resume sessions, preserve preferences), mount a PVC:

```yaml
spec:
  podTemplate:
    spec:
      containers:
        - name: claude
          volumeMounts:
            - { name: claude-home, mountPath: /home/agent/.claude }
      volumes:
        - name: claude-home
          persistentVolumeClaim:
            claimName: claude-home
```

The PVC can be shared across SandboxClaims for a single user, or distinct per tenant. See `references/home-volume.md` for storage class recommendations and the per-tenant pattern.

## Headless invocation

The Dockerfile entrypoint runs `claude --print --output-format json` by default. Override per claim if needed:

```bash
kubectl exec -it sandbox/session-abc -- claude --print "summarize TODO list" --output-format json
```

`--print` skips the TUI and writes a single JSON object to stdout. `--dangerously-skip-permissions` short-circuits permission prompts but the CLI rejects this as root, so the Dockerfile's `USER agent` (UID 1000) is required to use it.

## SandboxTemplate variants

Three variants in `templates/`:

- `SandboxTemplate.kata.yaml` — `runtimeClassName: kata-qemu`. Pairs with `kata-on-kind` or `kata-on-gke`.
- `SandboxTemplate.gvisor.yaml` — `runtimeClassName: gvisor`. Pairs with GKE managed Agent Sandbox or any cluster with gVisor RuntimeClass installed.
- `SandboxTemplate.kina.yaml` — no `runtimeClassName`. Pairs with `kina-microvm` because the node IS the microVM.

All three reference the same Claude Code image. Swap `runtimeClassName` to match the substrate; the rest of the template stays identical.

## End-to-end flow

```bash
# 0. Pick your substrate skill (kata-on-kind / kata-on-gke / kina-microvm) and bring up the cluster.

# 1. Build + push the image
docker buildx build -t REGISTRY/claude-code:v1 --push -f templates/Dockerfile.claude-code templates/

# 2. Create the Anthropic secret
kubectl create secret generic anthropic --from-literal=api-key=sk-ant-...

# 3. Apply the SandboxTemplate (kata variant shown)
kubectl apply -f templates/SandboxTemplate.kata.yaml

# 4. Apply a per-session SandboxClaim
SESSION_ID=$(uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | head -c 12)
sed "s/\${SESSION_ID}/${SESSION_ID}/" templates/SandboxClaim.session.yaml | kubectl apply -f -

# 5. Run Claude Code
kubectl wait --for=condition=Bound sandboxclaim/session-${SESSION_ID} --timeout=60s
kubectl exec -it sandbox/session-${SESSION_ID} -- claude --print "list files" --output-format json

# 6. Reap
kubectl delete sandboxclaim/session-${SESSION_ID}
```

## See also

- `references/auth.md` — `ANTHROPIC_API_KEY` and OAuth token patterns with k8s Secrets.
- `references/home-volume.md` — `~/.claude` PVC sizing and per-tenant separation.
- `core:mise` — mise discipline (registry short names per [[feedback-mise-registry-short-names]]).
- `k8s-agent-sandbox` — the controller, CRDs, and per-session lifecycle.
- `kata-on-kind` / `kata-on-gke` / `kina-microvm` — substrate setup.
- Upstream devcontainer reference: https://code.claude.com/docs/en/devcontainer

## Anti-fabrication

- The npm package is `@anthropic-ai/claude-code`; the mise registry short name is `claude-code`. The `ghcr.io/anthropics/claude-code:latest` image is referenced by community guides but NOT by Anthropic's official devcontainer docs — do not depend on it. Build your own image from this skill's Dockerfile.
- `--dangerously-skip-permissions` requires non-root. If the Dockerfile is changed to run as root, the flag will fail at runtime.
- Test the built image locally (`docker run --rm IMAGE claude --version`) before pushing to a registry and applying SandboxTemplate. A broken image leaves SandboxClaims in `CrashLoopBackOff`.
- Confirm `ANTHROPIC_API_KEY` reaches the pod via `kubectl exec -- env | grep ANTHROPIC` — the SandboxClaim's `spec.env` injection only takes effect if the controller version supports it (check API version per the `k8s-agent-sandbox` skill).
