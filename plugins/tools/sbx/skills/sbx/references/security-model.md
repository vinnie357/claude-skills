# sbx Security Model

Source: https://docs.docker.com/ai/sandboxes/security/

## The Four Isolation Layers

Docker Sandboxes stacks four layers of isolation. Each layer addresses a distinct attack surface.

### Layer 1: Hypervisor Isolation (KVM microVM)

Each sandbox runs inside a microVM backed by the KVM hypervisor. The guest gets its own kernel — not a shared kernel as in Linux namespaces or cgroups. A compromised guest process cannot escape to the host kernel through kernel exploits that rely on shared kernel state.

### Layer 2: Network Proxy

All outbound network traffic from the sandbox passes through a proxy.

- **HTTP and HTTPS** are allowed through the proxy.
- **Non-HTTP protocols** are blocked at the proxy; the sandbox cannot open arbitrary TCP or UDP connections.
- **Host localhost is unreachable** from inside the sandbox. The agent cannot connect to services bound to `127.0.0.1` or `::1` on the host.
- The deny-by-default policy means traffic not explicitly permitted by the proxy rules is dropped.

### Layer 3: Per-VM Docker Daemon

Each sandbox runs its own Docker daemon inside the microVM. The guest daemon is isolated from the host Docker daemon. Containers launched inside the sandbox cannot interact with host containers or images.

### Layer 4: Credential Proxy

API keys required by the AI agent (e.g., Anthropic API key for Claude Code) are injected by the host-side credential proxy. The keys:

- Never appear in the VM filesystem.
- Never appear in environment variables visible to processes inside the VM through normal inspection paths.
- Are forwarded on-demand through the proxy when the agent makes authenticated API calls.

## Deny-by-Default Network Policy

The network policy starts from a closed posture:

| Traffic type | Policy |
|---|---|
| HTTP outbound | Allowed (via proxy) |
| HTTPS outbound | Allowed (via proxy) |
| Non-HTTP TCP/UDP | Blocked |
| Host localhost | Blocked |
| Inbound from host | Via `sbx ports` only |

## Credential Injection Detail

The credential proxy intercepts requests from the agent to the AI provider API. It appends the API key at the proxy layer before forwarding to the provider. The agent process never holds the raw key; it holds only a proxy-local token that is only valid within the session.

## Workspace Caveat

The workspace directory is bind-mounted from the host into the microVM. This creates a shared filesystem path. An AI agent running inside the sandbox has write access to the entire workspace, including:

- `.git/hooks/` — pre-commit, post-merge, and other hooks that run on the host
- CI configuration files (`.github/workflows/`, `.circleci/config.yml`, etc.)
- Build scripts (`Makefile`, `mise.toml`, `package.json` scripts, etc.)

These files execute on the host the next time a host-side process invokes them. The microVM boundary does not protect host execution of workspace artifacts.

**Mitigation:** audit workspace-written hook and CI files before running them on the host. Treat the workspace as untrusted input from the agent.

## What This Is NOT

sbx is not:

- **A Linux container** — containers share the host kernel; sbx microVMs have a separate kernel per sandbox.
- **A namespace or cgroup boundary** — those are kernel-level isolation within a single kernel; sbx uses full VM-level isolation.
- **A seccomp filter** — seccomp restricts syscalls within a shared kernel; sbx eliminates shared kernel state entirely.

sbx microVMs provide hypervisor-level isolation comparable to cloud VM boundaries, not container-level isolation.
