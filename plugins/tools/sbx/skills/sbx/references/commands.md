# sbx Commands Reference

Source: https://docs.docker.com/reference/cli/sbx/

## Table of Contents

- [sbx run](#sbx-run)
- [sbx create](#sbx-create)
- [sbx exec](#sbx-exec)
- [sbx cp](#sbx-cp)
- [sbx ports](#sbx-ports)
- [sbx ls](#sbx-ls)
- [sbx stop](#sbx-stop)
- [sbx rm](#sbx-rm)
- [sbx login](#sbx-login)
- [sbx version](#sbx-version)
- [sbx diagnose](#sbx-diagnose)

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

**Confirmed flags:** (see upstream docs)

```bash
sbx exec my-sandbox bash
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

```bash
sbx ports my-sandbox --publish 8080:3000
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

Authenticate with an API key. Stores credentials locally for subsequent commands.

**Confirmed flags:** (see upstream docs)

```bash
sbx login
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
