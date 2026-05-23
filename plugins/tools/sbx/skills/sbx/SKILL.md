---
name: sbx
description: Guide for Docker Sandboxes (sbx CLI). Run AI coding agents in isolated microVMs with hypervisor-level isolation, deny-by-default networking, and credential-injection proxies. Use when installing sbx, launching agent sandboxes, managing sandbox lifecycle, port-forwarding into a sandbox, copying files in or out, or reasoning about the microVM isolation boundary.
license: MIT
---

# Docker Sandboxes (sbx)

## What is sbx?

Docker Sandboxes runs AI coding agents in microVMs backed by a KVM hypervisor. The binary is `sbx` — not `docker sbx`. Each sandbox gets its own kernel, its own Docker daemon, and an isolated network namespace. Only the workspace directory is mounted into the VM. A credential proxy injects API keys host-side so secrets never enter the VM filesystem.

## Install

### macOS (Apple silicon, Sonoma+)

Requires Homebrew.

```bash
brew install docker/tap/sbx
```

### Windows 11

Requires Hypervisor Platform enabled in Windows Features.

```powershell
winget install Docker.sbx
```

### Ubuntu 24.04+

Requires KVM and user in the `kvm` group.

```bash
curl -fsSL https://get.docker.com | sudo REPO_ONLY=1 sh
sudo apt-get install docker-sbx
```

## Authenticate

```bash
sbx login
```

Prompts for an API key and stores credentials locally.

## Run an agent

```bash
# Create and immediately run a sandbox with Claude Code
sbx run claude
```

Available agents: Claude Code, Codex, Copilot, Cursor, Droid, Gemini, Kiro, OpenCode, Docker Agent, Shell (agent-less).

Create a sandbox in the background without attaching:

```bash
sbx create claude
```

## Branch isolation

`--branch auto` creates a Git worktree for the sandbox, keeping branch changes isolated from the main working tree.

```bash
# Auto-create a worktree branch
sbx run claude --branch auto

# Target an existing branch
sbx run claude --branch my-feature
```

## Sandbox lifecycle

```bash
# List all sandboxes
sbx ls

# Pause a running sandbox
sbx stop my-sandbox

# Delete a sandbox (VM filesystem wiped; workspace directory preserved)
sbx rm my-sandbox
```

`sbx rm` wipes the VM filesystem. The workspace directory on the host is not deleted.

## Move files in and out

```bash
# Copy a file from host into the sandbox
sbx cp ./local-file.txt my-sandbox:/workspace/local-file.txt

# Copy a file out of the sandbox to the host
sbx cp my-sandbox:/workspace/output.txt ./output.txt
```

## Forward ports

```bash
sbx ports my-sandbox --publish 8080:3000
```

Maps host port 8080 to container port 3000 inside the sandbox.

## Exec into a running sandbox

```bash
sbx exec my-sandbox bash
```

Opens an interactive shell inside the running sandbox.

## Security boundary

Four isolation layers:

1. **Hypervisor isolation** — KVM microVM with a separate kernel per sandbox.
2. **Network proxy** — deny-by-default; HTTP/HTTPS traffic goes through a proxy; non-HTTP protocols are blocked; the agent cannot reach the host's localhost.
3. **Per-VM Docker daemon** — each sandbox runs its own Docker daemon, isolated from the host daemon.
4. **Credential proxy** — API keys are injected host-side via the proxy; they never appear in the VM filesystem or environment variables visible inside the VM.

### Workspace caveat

The workspace directory is shared between the host and the VM. An agent running inside the sandbox can modify Git hooks, CI configuration files, and build scripts in that shared workspace. Those files execute on the host the next time the host invokes them (e.g., on the next `git commit` or CI run). Review workspace-written hooks and scripts before executing them on the host.

### What is NOT a boundary

Code that an agent writes to the workspace and that you then execute on the host runs with host privileges. The microVM boundary does not extend to host-side execution of workspace artifacts.

See `references/security-model.md` for the full four-layer breakdown and network policy detail.

## Diagnostics

```bash
# Print installed sbx version
sbx version

# Collect diagnostic information
sbx diagnose
```

For release history, see https://github.com/docker/sbx-releases.

## Reference

- `references/commands.md` — all 11 subcommands with confirmed flags and canonical invocations
- `references/security-model.md` — four-layer isolation model, network policy, credential injection, workspace caveat

Related: `/core:container` — Apple Container CLI (lightweight Linux VMs on Apple silicon via Virtualization.framework; different layer from sbx microVMs).

## Anti-fabrication

This skill follows `core:anti-fabrication`. The subcommand list, flags, install commands, and security model are extracted verbatim from the upstream docs cited in `sources.md`. The introduction version is not stated upstream and is not fabricated here — release history lives at https://github.com/docker/sbx-releases.
