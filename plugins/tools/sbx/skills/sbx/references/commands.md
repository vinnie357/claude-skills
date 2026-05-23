# sbx Commands Reference

Source: https://docs.docker.com/reference/cli/sbx/

## Table of Contents

- [Interactive dashboard (no subcommand)](#interactive-dashboard-no-subcommand)
- [sbx run](#sbx-run)
- [sbx create](#sbx-create)
- [sbx exec](#sbx-exec)
- [sbx cp](#sbx-cp)
- [sbx ports](#sbx-ports)
- [sbx policy](#sbx-policy)
- [sbx ls](#sbx-ls)
- [sbx stop](#sbx-stop)
- [sbx rm](#sbx-rm)
- [sbx login](#sbx-login)
- [sbx version](#sbx-version)
- [sbx diagnose](#sbx-diagnose)

---

## Interactive dashboard (no subcommand)

Running `sbx` with no subcommand opens a terminal dashboard. Shortcuts: `c` create, `s` start/stop, `Enter` attach, `x` shell, `r` remove, `Tab` switch sandbox/network panels, `?` help.

```bash
sbx
```

---

## sbx run

Create and run a sandbox, attaching to the agent session.

**Confirmed flags:**
- `--branch <name>` — target an existing branch; `--branch auto` creates a Git worktree
- `--publish <host:container>` — publish a port on the host

```bash
sbx run claude
sbx run claude --branch auto
sbx run claude --branch my-feature --publish 8080:3000
```

---

## sbx create

Create a sandbox in the background without attaching.

**Confirmed flags:**
- `--branch <name>` — target an existing branch; `--branch auto` creates a Git worktree
- `--publish <host:container>` — publish a port on the host

```bash
sbx create claude
sbx create claude --branch auto
```

---

## sbx exec

Execute a command inside a running sandbox.

**Confirmed flags:**
- `-it` — interactive terminal (required for shells)

```bash
sbx exec -it my-sandbox bash
```

---

## sbx cp

Copy files between the host and a sandbox.

**Confirmed flags:** (see upstream docs)

```bash
# Host to sandbox
sbx cp ./file.txt my-sandbox:/workspace/file.txt

# Sandbox to host
sbx cp my-sandbox:/workspace/output.txt ./output.txt
```

---

## sbx ports

Manage port forwarding for a sandbox.

**Confirmed flags:**
- `--publish <host:container>` — map host port to sandbox port
- `--unpublish <host:container>` — remove an existing publish

```bash
sbx ports my-sandbox --publish 8080:3000
sbx ports my-sandbox --unpublish 8080:3000
```

---

## sbx policy

Manage the sandbox network policy. Deny-by-default; rules add explicit allows.

**Confirmed subcommands:**
- `allow network <pattern>` — permit egress to a host pattern (`**` matches multiple subdomain levels)
- `ls` — show current policy

**Confirmed flags:**
- `-g` (with `allow`) — apply the rule globally across all sandboxes

```bash
# Global allow for the npm registry
sbx policy allow network -g registry.npmjs.org

# List current rules
sbx policy ls
```

---

## sbx ls

List all sandboxes.

**Confirmed flags:** (see upstream docs)

```bash
sbx ls
```

---

## sbx stop

Pause a running sandbox.

**Confirmed flags:** (see upstream docs)

```bash
sbx stop my-sandbox
```

---

## sbx rm

Delete a sandbox. The VM filesystem is wiped. The workspace directory on the host is preserved.

**Confirmed flags:** (see upstream docs)

```bash
sbx rm my-sandbox
```

---

## sbx login

Authenticate with a Docker account. Stores credentials locally for subsequent commands.

**Confirmed flags:**
- `--username <user>` — provide username non-interactively
- `--password-stdin` — read password from stdin (use with `--username`)

```bash
# Interactive
sbx login

# CI / non-interactive
echo "$DOCKER_PAT" | sbx login --username vinnie357 --password-stdin
```

---

## sbx version

Print the installed sbx version.

**Confirmed flags:** none

```bash
sbx version
```

---

## sbx diagnose

Collect diagnostic information for troubleshooting.

**Confirmed flags:** (see upstream docs)

```bash
sbx diagnose
```
