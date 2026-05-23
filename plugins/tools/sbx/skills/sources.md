# Sources

## sbx skill

### Docker Sandboxes Documentation

- **Source**: https://docs.docker.com/reference/cli/sbx/
  - Extracted: subcommand list (run, create, exec, cp, ports, ls, stop, rm, login, version, diagnose), confirmed flags (--branch, --publish)
  - Accessed 2026-05-22

- **Source**: https://docs.docker.com/ai/sandboxes/
  - Extracted: product overview — microVM architecture, KVM hypervisor, per-VM Docker daemon, workspace mount
  - Accessed 2026-05-22

- **Source**: https://docs.docker.com/ai/sandboxes/get-started/
  - Extracted: install commands for macOS (brew), Windows (winget), Ubuntu (apt), prerequisite notes
  - Accessed 2026-05-22

- **Source**: https://docs.docker.com/ai/sandboxes/usage/
  - Extracted: agent list (Claude Code, Codex, Copilot, Cursor, Droid, Gemini, Kiro, OpenCode, Docker Agent, Shell), `--branch auto` worktree flag, lifecycle commands
  - Accessed 2026-05-22

- **Source**: https://docs.docker.com/ai/sandboxes/security/
  - Extracted: four-layer isolation model (hypervisor, network proxy, per-VM daemon, credential proxy), deny-by-default network policy, workspace caveat (hooks/CI/build scripts execute on host)
  - Accessed 2026-05-22

- **Source**: https://github.com/docker/sbx-releases
  - Extracted: release history reference; no version number fabricated from this source
  - Accessed 2026-05-22

- **Source**: https://github.com/docker/sbx-releases/releases/download/v0.30.0/DockerSandboxes-darwin.tar.gz (and `-linux.tar.gz`)
  - Extracted: archive layout (`bin/sbx` + `libexec/` runtime tree + `completions/`); verified mise github backend installs and extracts the tarball correctly with SLSA provenance verification
  - Accessed 2026-05-22

### Third-party

- **Source**: https://www.msbiro.net/posts/docker-sandboxes-ai-agents/ — Matteo Bisi, 2026-04-07
  - Extracted: `sbx policy allow network -g <host>` syntax, `sbx policy ls` (both confirmed against upstream usage page), `sbx exec -it` flag, interactive dashboard keyboard shortcuts (confirmed against upstream), `.sbx/` worktree directory + gitignore recommendation, `--branch` as recommended pattern for reviewable agent edits
  - Note: `sbx secret` subcommand mentioned in the blog is NOT confirmed against upstream docs; omitted from this skill per anti-fabrication policy
  - Accessed 2026-05-22
