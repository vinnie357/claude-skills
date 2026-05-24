---
name: sandbox
description: Index for agent-sandboxing approaches — routes to the right sub-skill based on host OS, isolation tier, and deployment scale. Use when picking a sandboxing strategy for an AI coding agent, comparing kernel-level isolation (gVisor) vs microVM isolation (Kata, Apple Container, Docker), choosing between Kubernetes-orchestrated and single-host CLI approaches, or unsure which agent-sandboxing skill to load next.
license: MIT
---

# sandbox

Entry-point index for the `agent-sandboxing` plugin. Load this skill first when the task is "give me an isolated environment for an AI agent" and you don't yet know which substrate fits. The body routes to the right deeper skill via decision tree + one-line index.

The plugin covers the **Kubernetes-orchestrated** path (multi-pod, per-session lifecycle, controller-managed). For the **single-host CLI** path (one operator, one machine, Docker microVMs), the sibling [`sbx`](https://github.com/vinnie357/claude-skills/tree/main/plugins/tools/sbx) plugin is the right tool — same mental goal, different shape.

## Decision tree

```
Need to sandbox an AI agent
│
├─ Single host, no Kubernetes?
│   └─→ /sbx:sbx                          (Docker microVMs, sbx CLI)
│
└─ Kubernetes (kind / GKE / kina)?
    │
    ├─ Host OS = macOS Apple Silicon?
    │   └─→ /agent-sandboxing:kina-microvm      (Apple Container microVM nodes)
    │
    ├─ Host OS = Linux + want microVM isolation?
    │   └─→ /agent-sandboxing:kata-on-kind      (Kata Containers on kind)
    │
    ├─ Production GKE + microVM isolation?
    │   └─→ /agent-sandboxing:kata-on-gke       (self-managed Kata on Ubuntu N2)
    │
    └─ Production GKE + userspace kernel isolation?
        └─→ /agent-sandboxing:k8s-agent-sandbox (covers GKE managed Agent Sandbox = gVisor)
```

For every k8s path: also load `/agent-sandboxing:k8s-agent-sandbox` (controller + CRDs + lifecycle) and `/agent-sandboxing:claude-code-on-sandbox` (workload packaging).

## Isolation tier comparison

| Tier | Mechanism | Where it runs | Plugin skill |
|---|---|---|---|
| Hardware microVM (KVM) | Kata Containers | Linux + nested virt | `kata-on-kind`, `kata-on-gke` |
| Hardware microVM (Virtualization.framework) | Apple Container, node-level | macOS Apple Silicon | `kina-microvm` |
| Hardware microVM (KVM/Docker) | sbx CLI, single-host | Linux + macOS | `/sbx:sbx` (sibling plugin) |
| Userspace kernel | gVisor | Anywhere (no nested virt needed) | `k8s-agent-sandbox` (gVisor variant) |
| Process-level (none) | runc default | Anywhere | Not recommended for untrusted agents |

## Skills in this plugin (one-line index)

Load the index entry first (you're here). Load deeper skills only as needed.

- **`/agent-sandboxing:k8s-agent-sandbox`** — `kubernetes-sigs/agent-sandbox` controller install, CRDs (`Sandbox` / `SandboxTemplate` / `SandboxClaim` / `SandboxWarmPool`), per-session lifecycle, default-deny networking. **Load this for any k8s-based path.**
- **`/agent-sandboxing:kata-on-kind`** — install Kata Containers on a local Linux kind cluster via kata-deploy. Registers the `kata-qemu` RuntimeClass.
- **`/agent-sandboxing:kata-on-gke`** — self-managed Kata on a GKE Ubuntu N2 node pool with nested virtualization. The managed GKE Agent Sandbox is gVisor-only; Kata requires this path.
- **`/agent-sandboxing:kina-microvm`** — macOS path via kina (Kubernetes-in-Apple-Containers, the `kind` analogue for Apple Container). Cluster nodes ARE the microVM tier; no per-pod RuntimeClass.
- **`/agent-sandboxing:claude-code-on-sandbox`** — mise-driven Dockerfile for Claude Code, `~/.claude` persistence, `ANTHROPIC_API_KEY` injection, per-pod egress policy. **Load this for any workload-packaging step.**
- **`/agent-sandboxing:agent-substrate-overview`** — short reference for the alpha `agent-substrate/substrate` alternative control plane. Not recommended for production today.

## Slash commands (one-line index)

These wrap multi-step kubectl + docker flows. Load `sandbox` (this) first to know which to invoke.

- **`/agent-sandboxing:bootstrap`** — substrate picker → install controller → install first SandboxTemplate. **Run this once per cluster.**
- **`/agent-sandboxing:build-image`** — `docker buildx build` from `templates/Dockerfile.claude-code` (mise-driven). Run before the first provision.
- **`/agent-sandboxing:provision`** — render + apply per-session `SandboxClaim`, wait for `Bound`, return endpoint. **Run this per session.**
- **`/agent-sandboxing:exec`** — `kubectl exec` into the bound pod. Default command: `claude --print --output-format json`.
- **`/agent-sandboxing:status`** — formatted table of all SandboxClaims with phase, template, bound pod, age.
- **`/agent-sandboxing:reap`** — delete one (`<session-id>`) or all (`--all`) claims.

## Sibling: `/sbx:sbx` (Docker single-host microVMs)

When the use case is "one operator, one Mac, one running agent" rather than "cluster of per-session pods," `/sbx:sbx` is simpler. It runs AI agents in Docker microVMs with a credential-injection proxy and deny-by-default networking — all without Kubernetes. The mental model:

- This plugin = **fleet / multi-tenant / per-session lifecycle** (controller schedules pods, claims reap, warm pools pre-warm).
- `/sbx:sbx` = **single-host CLI / one-at-a-time** (you invoke `sbx run`, it spawns one microVM, you work, you exit).

Both isolate untrusted agent code from the host. Both are valid; pick the one whose lifecycle matches the workflow.

## Substrate-specific files in this plugin

- `templates/Dockerfile.claude-code` — mise-driven OCI image (uses `claude-code = "latest"` mise registry short name).
- `templates/SandboxTemplate.{kata,gvisor,kina}.yaml` — three variants; pick by substrate.
- `templates/SandboxClaim.session.yaml` — per-session claim with `shutdownPolicy: Delete`.
- `templates/NetworkPolicy.anthropic.yaml` — standalone default-deny + Anthropic egress allowlist (when `networkPolicyManagement: Unmanaged`).
- `scripts/render-claim.nu`, `scripts/wait-bound.nu`, `scripts/list-claims.nu` — nushell scripts invoked by the slash commands.
- `mise.toml` — plugin-root mise.toml pinning `nu` + `jq`; exposes `mise run render-claim` / `wait-bound` / `list-claims` / `install-controller` for direct operator use without Claude.

## Anti-fabrication

- This is an index. **Don't repeat sub-skill content here** — link and route. If you find yourself pasting Kata install commands into this skill, move them back to `/agent-sandboxing:kata-on-kind`.
- Don't recommend a substrate without checking the host. `uname -s` first, then route — macOS → kina, Linux → kata-on-kind/gke, otherwise → ask.
- Don't conflate the isolation tiers. gVisor is userspace kernel (no nested virt); Kata + Apple Container + Docker microVM are all hardware microVMs with different hypervisors. The table above is the authoritative comparison.
- Don't claim `/sbx:sbx` is part of this plugin. It's a sibling plugin and not installed unless the user has added it.
