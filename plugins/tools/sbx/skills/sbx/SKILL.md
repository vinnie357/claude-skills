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

### mise (macOS, Linux)

mise's github backend extracts the platform tarball, preserves the `bin/sbx` + `libexec/` layout, and verifies SLSA provenance. See `templates/mise.toml`.

```toml
[tools]
"github:docker/sbx-releases" = "0.30.0"
```

```bash
mise install
sbx version
```

Apple silicon and Linux x86_64 are confirmed. Windows is not packaged as a tarball asset — use `winget` above.

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

`--branch auto` creates a Git worktree for the sandbox, keeping branch changes isolated from the main working tree. Worktrees live under `.sbx/` in the repo root. Add `.sbx/` to `.gitignore` (or global gitignore) to keep it out of `git status`.

```bash
# Auto-create a worktree branch (with trailing path)
sbx run claude --branch auto .

# Target an existing branch
sbx run claude --branch my-feature

# Suggested gitignore entry
echo '.sbx/' >> .gitignore
```

`--branch` is the recommended pattern for any agent that writes code — it keeps every agent edit on a reviewable branch the operator can diff and merge deliberately.

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
# Publish host port 8080 → sandbox port 3000
sbx ports my-sandbox --publish 8080:3000

# Remove an existing publish
sbx ports my-sandbox --unpublish 8080:3000
```

## Exec into a running sandbox

```bash
sbx exec -it my-sandbox bash
```

`-it` keeps the shell interactive. Without it, `exec` runs the command and exits.

## Network policy

`sbx` ships a deny-by-default network policy. Add explicit allow rules per host or wildcard:

```bash
# Allow a global host for all sandboxes
sbx policy allow network -g registry.npmjs.org

# Inspect current policy
sbx policy ls
```

`**` matches multiple subdomain levels in the rule grammar.

## Interactive dashboard

Running `sbx` with no subcommand opens a terminal dashboard. Key shortcuts:

| Key | Action |
|-----|--------|
| `c` | Create a sandbox |
| `s` | Start or stop the selected sandbox |
| `Enter` | Attach to the agent session |
| `x` | Open a shell (same as `sbx exec`) |
| `r` | Remove the selected sandbox |
| `Tab` | Switch between sandbox and network governance panels |
| `?` | Show all shortcuts |

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

## Docker inside a sandbox

Each sandbox runs its own Docker daemon, so the agent can spin up service containers (Postgres, Redis, etc.) inside the VM without touching the host's Docker. The workspace dir is mounted into the VM, so a `compose.yaml` in the repo works as-is.

See `templates/elixir-tidewave/` for a worked example: Phoenix app + Postgres container + Tidewave runtime introspection, all inside a single sandbox where Claude is the running agent.

## Reference

- `references/commands.md` — confirmed subcommands and flags with canonical invocations
- `references/security-model.md` — four-layer isolation model, network policy, credential injection, workspace caveat
- `templates/mise.toml` — mise github backend pin for sbx
- `templates/elixir-tidewave/` — Docker-in-sbx workflow with Phoenix + Postgres + Tidewave

Related: `/core:container` — Apple Container CLI (lightweight Linux VMs on Apple silicon via Virtualization.framework; different layer from sbx microVMs). `/elixir:tidewave` — Tidewave MCP setup detail used by the elixir-tidewave template.

## Anti-fabrication

This skill follows `core:anti-fabrication`. The subcommand list, flags, install commands, and security model are extracted verbatim from the upstream docs cited in `sources.md`. The introduction version is not stated upstream and is not fabricated here — release history lives at https://github.com/docker/sbx-releases.
