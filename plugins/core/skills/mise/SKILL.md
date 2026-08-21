---
name: mise
description: Guide for using mise to manage development tools and runtime versions. Use when configuring project tooling, managing environment variables, or defining project tasks.
---

# mise - Development Environment Management

This skill activates when working with mise for managing tool versions, environment variables, and project tasks.

## What is mise?

Current stable: v2026.3.15

mise is a polyglot runtime manager and development environment tool that combines:
- **Tool version management** - Install and manage multiple versions of dev tools
- **Environment configuration** - Set environment variables per project
- **Task automation** - Define and run project tasks
- **Cross-platform** - Works on macOS, Linux, and Windows

Install with `curl https://mise.run | sh` (or `brew install mise`), then activate in the shell: `eval "$(mise activate zsh)"`. Full install matrix, shims, IDE and CI/CD integration: `references/setup-and-troubleshooting.md`.

## Tool Backends

mise uses different backends (package managers) to install tools:

- **asdf** - Traditional asdf plugins (default for many tools)
- **github** - GitHub release-asset installer (replaces deprecated ubi backend)
- **cargo** - Rust packages (requires Rust installed)
- **npm** - Node.js packages (requires Node installed)
- **go** - Go packages (requires Go installed)
- **aqua** - Package manager
- **pipx** - Python packages (requires Python installed)
- **gem** - Ruby packages (requires Ruby installed)
- **gitlab** - Direct from GitLab repositories
- **http** - Direct HTTP downloads

Prefer registry short names (`ripgrep`) over backend-prefixed forms (`cargo:ripgrep`) when the tool is in the mise registry (`mise registry | grep <tool-name>`). Fall back to an explicit backend prefix when the registry has no entry.

Per-backend detail — github backend options (`exe`, `asset_pattern`, `extract_all`, `rename_exe`), multi-arch platform keys, cargo prerequisites and git installs, upgrades and aliases: `references/backends.md`.

## Verify Before Pinning — ls-remote

`mise ls-remote <backend>:<target>` returns all available versions for any backend. Run this BEFORE pinning a version in mise.toml to confirm the backend can actually see the tool:

```bash
mise ls-remote node                  # registry tool
mise ls-remote github:sharkdp/fd     # explicit backend
mise registry | grep <tool-name>     # search the registry
```

**Failure mode — the tool lives in a different repo than you expect.** Sometimes the CLI binary is released from a different repository than the documentation or project homepage:

```bash
$ mise ls-remote github:juxt/allium | head -5
(no output)                          # wrong repo — homepage, no releases

$ mise ls-remote github:juxt/allium-tools | head -5
0.1.0                                # correct repo for the CLI releases
```

If `ls-remote` returns nothing, check whether the project publishes releases to a separate repository (e.g., a `-tools`, `-cli`, or `-releases` repo). Don't pin a version you haven't verified ls-remote can see. Per-backend ls-remote output examples: `references/backends.md`.

## Installing and Using Tools

**Key difference**: `mise install` only installs tools; `mise use` installs AND adds the tool to your configuration file. `mise use` is the primary way to add tools to projects.

```bash
mise install                  # install everything in .mise.toml / .tool-versions
mise install node@20.10.0     # install without touching config

mise use node@20              # fuzzy version — saves "20" (default)
mise use --pin node@20.10.0   # exact version — saves "20.10.0"
mise use node@latest          # saves "latest"
mise use cargo:ripgrep@latest # explicit backend
mise use --remove node        # remove tool from config
mise use --force node@20      # force reinstall
mise use --dry-run node@20    # preview changes
```

Version pinning: fuzzy (`node@20`) auto-updates within the major version; `--pin` locks the exact version; `latest` always updates. **Best Practice**: Use fuzzy versions for flexibility, `mise.lock` for reproducibility.

### Configuration file selection

`mise use` writes to configuration files in this priority order:

1. **`--global` flag**: `~/.config/mise/config.toml`
2. **`--path <file>` flag**: Specified file path
3. **`--env <env>` flag**: `.mise.<env>.toml`
4. **Default**: `mise.toml` in current directory

## .mise.toml Schema

```toml
[tools]
node = "20.10.0"
python = "3.12"
terraform = "latest"

# Backends - use quotes for namespaced tools
"cargo:ripgrep" = "latest"           # Requires rust installed
"github:sharkdp/fd" = "latest"       # GitHub releases
"npm:typescript" = "latest"          # Requires node installed
"github:nushell/nushell" = "latest"  # Nushell (structured shell)

# Version from file
node = { version = "lts", resolve = "latest-lts" }
```

mise reads configuration from multiple locations (in order):

1. `.mise.toml` - Project local config
2. `.mise/config.toml` - Project local config (alternative)
3. `~/.config/mise/config.toml` - Global config
4. Environment variables - `MISE_*`

## Environment Variables

```toml
[env]
DATABASE_URL = "postgresql://localhost/myapp"
NODE_ENV = "development"

# Go templates — {{ config_root }} is the directory containing mise.toml
APP_ROOT = "{{ config_root }}"
PATH = ["{{ config_root }}/bin", "$PATH"]

# File-based env vars
_.file = ".env"
_.path = ["/custom/bin"]
```

Secrets via `mise set`:

```bash
mise set SECRET_KEY sops://path/to/secret     # sops
mise set API_TOKEN age://path/to/secret       # age
mise set BUILD_ID "$(git rev-parse HEAD)"     # from command
```

## Tasks

```toml
[tasks.build]
description = "Build the project"
run = "npm run build"
sources = ["src/**/*.ts"]      # Only run if sources changed
outputs = ["dist/**/*"]         # Check outputs for changes
dir = "frontend"                # Run in specific directory
env = { NODE_ENV = "production" }

[tasks.test]
description = "Run tests"
run = "npm test"

[tasks.lint]
description = "Run linter"
run = "npm run lint"
depends = ["build"]             # depends run first, in order

[tasks.ci]
description = "Run CI pipeline"
depends = ["lint", "test"]

[tasks.watch]
run = "npm run watch"
raw = true                      # Don't wrap in shell
```

```bash
mise run build            # run a task
mise build                # short form
mise run lint test        # run multiple tasks
mise tasks                # list available tasks
mise run script -- arg1   # pass arguments
```

Define a `ci` task that aggregates the project's format, lint, and test checks — `mise run ci` is the local quality gate other skills and agents in this workspace invoke before commit. File-based tasks (`.mise/tasks/`) and complete Node/Python/monorepo/multi-tool project setups: `references/tasks-and-workflows.md`.

## Sandboxing

mise sandboxing restricts filesystem, network, and env access for `mise exec` / `mise run` using OS-level primitives (Landlock/seccomp on Linux, Seatbelt on macOS; Windows unsupported). Gotcha: `mise settings experimental=true` is required first — without it, deny/allow flags are silently no-ops.

```bash
mise x --deny-all --allow-read=. --allow-write=./dist --allow-net=registry.npmjs.org -- npm install
```

Full flag reference, platform support matrix, task-level config, and limitations: `references/sandboxing.md`. Runnable examples: `templates/sandboxing.md`.

## Lock Files

```bash
mise lock                 # generate .mise.lock
mise install --locked     # use locked versions
```

```toml
[settings]
lockfile = true  # Auto-generate lock file
```

## Templates

The `templates/` directory contains reusable configuration snippets for common mise patterns:

- `templates/multi-arch.md` — platform-specific asset patterns for GitHub-release tools (pattern detail in `references/backends.md`)
- `templates/sandboxing.md` — runnable sandbox invocations

## Best Practices

- **Use .mise.toml for projects**: Better than .tool-versions (more features)
- **Pin versions in projects**: Ensure consistency across team
- **Use tasks for common operations**: Document and standardize workflows
- **Lock files in production**: Use `mise lock` for reproducibility
- **Global tools for dev**: Set global defaults, override per project
- **Environment per project**: Keep secrets and config in .mise.toml
- **Commit .mise.toml**: Share config with team
- **Don't commit .mise.lock**: Let mise generate per environment
- **Zero setup for team**: Clone and `mise install` to get started

## References

- `references/backends.md` — per-backend ls-remote examples, github backend options, multi-arch asset patterns, cargo backend, upgrades and aliases
- `references/tasks-and-workflows.md` — file-based tasks and complete project workflow examples (Node.js, Python, monorepo, multi-tool)
- `references/sandboxing.md` — sandbox flag reference, platform support matrix, task-level config, limitations
- `references/setup-and-troubleshooting.md` — installation matrix, shims, IDE integration, CI/CD integration (GitHub Actions, GitLab CI), troubleshooting, `.tool-versions` migration
- `references/transitive-runtime-deps.md` — `mise exec` does NOT auto-install transitive deps (Elixir-needs-Erlang failure mode); prefer portable secret-generation commands (`openssl`, `python3`, `/dev/urandom`)
