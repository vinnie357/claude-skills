---
name: security
description: Secret detection and credential scanning using gitleaks. Use when scanning repositories for leaked secrets, API keys, passwords, tokens, or implementing pre-commit security checks.
license: MIT
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/skills/security/hooks/check-secrets-before-commit.sh"
          timeout: 120
---

# Security: Secret Detection

This skill activates when performing secret detection, credential scanning, or implementing security checks for leaked sensitive data in code repositories.

## When to Use This Skill

Activate when:
- Scanning repositories for leaked secrets, API keys, or credentials
- Setting up pre-commit hooks for secret detection
- Auditing codebases for exposed passwords or tokens
- Implementing CI/CD security pipelines
- Checking git history for accidentally committed secrets
- Validating that .gitignore excludes sensitive files

## Pre-Commit Hook (Automatic)

When this skill is loaded, a pre-commit hook automatically scans staged files for secrets before every `git commit` command. This provides defense-in-depth by catching secrets before they enter git history.

### Hook Behavior

```
git commit -m "message"
         ↓
PreToolUse hook fires
         ↓
Extract staged files
         ↓
Run gitleaks --no-git
         ↓
    ┌─ Clean ─┴─ Secrets ─┐
    ↓                     ↓
  Allow               Block commit
  commit              (exit code 2)
```

### What Gets Scanned

- Only **staged files** are scanned (not the entire working tree)
- Uses `.gitleaks-baseline.json` if present to ignore known false positives
- Uses `.gitleaks.toml` if present for custom detection rules

### When Secrets Are Detected

If the hook detects secrets, the commit is blocked with guidance:

```
[gitleaks] SECRETS DETECTED in staged files!
[gitleaks] Commit blocked. Remove secrets before committing.
[gitleaks]
[gitleaks] Options:
[gitleaks]   1. Remove the secret from the file
[gitleaks]   2. Use environment variables instead
[gitleaks]   3. Add to .gitleaks-baseline.json if false positive
```

### Container Runtime Requirements

The hook requires a container runtime to run gitleaks. It auto-detects:
1. **Apple Container** (macOS 26+)
2. **Docker** (Docker Desktop or Engine)
3. **Colima** via mise

If no runtime is available, the hook logs a warning and allows the commit.

## Agent Secret Safety

When agents interact with secrets (1Password, environment variables, keychains):

- **Never print secret values** in output, logs, or reports
- **Confirm existence only**: `test -n "$VAR" && echo "set" || echo "empty"`
- **Never use `--reveal`** in agent scripts — use it only in launcher scripts that don't capture output
- If a secret value is accidentally exposed in conversation context, the user must rotate it immediately

This applies to all agent tiers. A leaked secret in agent output forces credential rotation.

### Commands that leak environments

"Never print secret values" is not enough on its own — some commands leak the full environment as a *side effect* of an unrelated-looking diagnostic. The command reads as "get a bit more context on this process," not "dump every credential this process can see," so the guidance above does not visibly apply and the leak happens anyway.

**Incident (2026-08-04):** an agent confirming one environment variable on a running process followed up with `ps -E -p <pid>` as a diagnostic. On macOS, `-E` appends the process's entire environment after the command line, undifferentiated from the command-line arguments — four live credentials landed in the transcript in plaintext, requiring rotation of all four. A prior incident (2026-07-30) came from `printenv | grep -i database` on a pod — same shape, different command. A third incident, the same day as the first, happened while *drafting the guidance below*: an agent ran the exact command this section warns about, to confirm it leaks, against a session holding live credentials — and leaked them.

**Do not run these commands to check whether they leak.** This is the operative instruction, ahead of the table below. `ps -E`/`-e`-shaped flags, `COMMAND_MODE=legacy ps -e`, `/proc/<pid>/environ`, and unfiltered `printenv`/`env` all read and emit the target's real environment the instant they execute — there is no dry-run, no filtered form, no "just to see." Verifying the hazard reproduces the hazard. An agent session routinely holds live service-account tokens and API keys in its own environment, so "let me confirm this actually leaks" against a real process is itself the leak, not a safe way to check one. Take the mechanism below as established fact — do not re-derive it by running anything:

- Observed on macOS 26.6, against a mise-installed (non-platform) binary: `ps -E` output grew from an 11-word baseline (command line only) to 105 words once the process's environment was appended, with a marker variable present only in the appended portion.
- Observed on macOS 26.6: `COMMAND_MODE=legacy ps -e` targeted at one process returned 2 lines — a header and that process with its environment appended. The same flag with `COMMAND_MODE` unset returned 961 lines, one per running process on the system, confirming the default (`unix2003`) reading of `-e` is "select all processes" (matching Linux), not "append environment." `man ps` LEGACY DESCRIPTION documents the flip: "`-e`  Display the environment as well. Same as `-E`."
- Apple's own platform binaries (`/bin/sleep`, `/bin/cat`, and similar) ship codesigned with the hardened runtime and are shielded from the environment-append behavior — a check against one of those looks clean and is not evidence the flag is safe. That shielding does not extend to anything an agent actually spawns: mise-installed binaries, language runtimes (`nu`, `node`, `python`, `elixir`), and project-local tooling all leak reliably. This is background for why the hazard is broader than "system processes," not an invitation to compare the two yourself.

Banned outright — never run any of these, on any platform, filtered or not:

| Command | Platform | Why it leaks |
|---|---|---|
| `ps -E` | macOS/BSD | Documented flag: "Display the environment as well" (`man ps`). Appends the target process's full environment to its command-line output. |
| `ps eww` (or any BSD keyletter set with `e` appended, e.g. `auxe`) | macOS/BSD | The no-dash keyletter form of the same append-environment behavior as `-E`. |
| `ps e` (bare `e` appended to a keyletter set, e.g. `psaux` → `auxe`, or `lwwe`) | Linux (GNU ps / procps) | Documented: "Show the environment after the command." GNU ps has no `-E` flag — `-e` there means "select all processes" (same as `-A`), not environment; do not confuse the two. |
| `COMMAND_MODE=legacy ps -e` | macOS/BSD | `man ps` LEGACY DESCRIPTION: "`-e`  Display the environment as well. Same as `-E`." Under the default `unix2003` `COMMAND_MODE` (or with the variable unset), macOS `-e` means "select all processes," matching Linux — no environment appended. Setting `COMMAND_MODE=legacy` flips `-e` to behave exactly like `-E`. |
| `cat /proc/<pid>/environ` or any read of it | Linux | "This file contains the initial environment that was set when the currently executing program was started" (`proc_pid_environ(5)`), NUL-separated. Readable for any process you can `ptrace` — typically your own processes or, as root, any process. |
| Unfiltered `printenv` / `env` (no args) | All | Prints the calling shell's entire environment, not one variable. |

**No safe invocation.** There is no piped or filtered form of the commands above that avoids the leak. Each one reads and emits the complete environment the moment it runs — a trailing `| grep '^VARNAME='` or `| tr ' ' '\n'` narrows what prints to the screen, not what the command already read, and in a transcript-logged agent session the full output has typically already reached tool-output logging before the filter stage ever executes. Do not run `ps eww -p <pid> | tr ' ' '\n' | grep '^VARNAME='` or any variant expecting the pipe to make it safe — that pattern still executes the dump.

If you need to know something about your OWN process's environment, use `test -n "$VAR"` (Agent Secret Safety, above) — that reads your own shell state directly, with no diagnostic exec'd against a target process. If you need a variable belonging to a DIFFERENT process, there is no safe way to read it via `ps`, `/proc`, or `printenv`: use that process's own introspection surface (a documented health/info/config endpoint) or ask the operator, rather than enumerating its environment.

**Inspection discipline.**
- Never inspect an environment "for context" or "to see what's there." Name the specific variable you need before running anything.
- Never place a secret on a command line (`env VAR=value cmd`, `curl -H "Authorization: Bearer $TOKEN"` with `$TOKEN` interpolated visibly) — command lines land in shell history and process listings same as the commands above.
- Treat `-e`/`-E`-shaped flags on any unfamiliar tool as suspect until you've checked what they do; the macOS/Linux split above (`-E` vs bare `e` vs `-e`-means-"all") is exactly the kind of one-letter, cross-platform inconsistency that causes an agent to reach for the wrong flag under the impression it is the safe one.

**Recovery.** If an environment dump reaches the transcript despite the above, self-report the exposure immediately and ask the operator to rotate every credential that appeared — do not wait to be asked, and do not attempt to redact it after the fact (the value is already in context/logs).

## When to Use security-review Instead

Use the `security-review` skill for:
- STRIDE threat modeling
- Security architecture reviews
- Vulnerability assessments
- Security documentation and reports
- Risk prioritization
- Attack surface analysis

| Task | Use `security` | Use `security-review` |
|------|---------------|----------------------|
| Scan for secrets in code | ✓ | |
| Detect leaked API keys | ✓ | |
| Pre-commit secret scanning | ✓ | |
| STRIDE threat modeling | | ✓ |
| Security architecture review | | ✓ |
| Vulnerability assessment | | ✓ |
| Security report documentation | | ✓ |
| Risk prioritization | | ✓ |

## Gitleaks

Gitleaks is an open-source tool for detecting secrets and sensitive information in git repositories. It scans commit history and file contents for patterns matching known secret formats.

### Common Secrets Detected

- AWS Access Keys and Secret Keys
- Google Cloud API Keys
- GitHub Personal Access Tokens
- Private Keys (RSA, SSH, PGP)
- Database Connection Strings
- JWT Tokens
- Stripe API Keys
- Slack Tokens
- Generic Passwords and API Keys

### Basic Usage

```bash
# Scan current directory
gitleaks detect --source="." -v

# Scan with JSON report
gitleaks detect --source="." -v --report-path=report.json --report-format=json

# Scan only staged changes (pre-commit)
gitleaks protect --staged

# Scan git history
gitleaks detect --source="." --log-opts="--all"
```

### Configuration

Create a `.gitleaks.toml` file to customize detection:

```toml
[extend]
# Extend default rules
useDefault = true

[[rules]]
id = "custom-api-key"
description = "Custom API Key Pattern"
regex = '''(?i)custom[_-]?api[_-]?key['\"]?\s*[=:]\s*['\"]([a-zA-Z0-9]{32,})'''
keywords = ["custom_api_key", "custom-api-key"]

[allowlist]
paths = [
  '''\.gitleaks\.toml$''',
  '''(.*)?test(.*)''',
  '''\.git'''
]

regexes = [
  '''EXAMPLE_.*''',
  '''REDACTED'''
]
```

### Exit Codes

- `0`: No leaks found
- `1`: Leaks detected
- Other: Configuration or runtime error

## Scripts

This skill includes scripts for running gitleaks, preferring a native binary and falling back to a container runtime.

### gitleaks.nu (Nushell)

Cross-platform Nushell script with automatic runtime detection. `gitleaks.nu` resolves a runtime in this priority order and never fails opaquely — if nothing is found, it prints exactly which install paths it checked and exits 1:

1. **native (mise)** — a mise-managed `gitleaks` binary, resolved via `mise which gitleaks`. Preferred: no container/VM startup cost, no image pull.
2. **native (PATH)** — a `gitleaks` binary on `PATH` installed some other way (e.g. `brew install gitleaks`).
3. **container** — Apple Container (macOS 26+)
4. **docker** — Docker Desktop or Docker Engine
5. **colima** — Colima via mise exec

```bash
# Run with auto-detected runtime (prefers native, falls back to container)
nu scripts/gitleaks.nu

# Force a specific runtime
nu scripts/gitleaks.nu --runtime native
nu scripts/gitleaks.nu --runtime docker
nu scripts/gitleaks.nu --runtime container  # Apple Container (macOS 26+)
nu scripts/gitleaks.nu --runtime colima

# Generate report
nu scripts/gitleaks.nu --report ./report.json

# Use custom config
nu scripts/gitleaks.nu --config ./.gitleaks.toml

# Scan specific path
nu scripts/gitleaks.nu --path ./src

# Run the internal selection-logic self-tests (no subprocess/container calls)
nu scripts/gitleaks.nu --self-test
```

#### Shell-function shadowing trap

A shell function named `gitleaks` defined in an interactive shell's rc file (zsh/bash) can shadow the real binary and silently reroute a bare `gitleaks ...` invocation at the terminal through `container run` instead of the native binary — observed on a real host, where an rc-sourced snapshot defined exactly such a function. `gitleaks.nu` itself is immune: it never invokes a bare `gitleaks` command, it resolves the binary's absolute path via `mise which gitleaks` (or `which gitleaks` as fallback) and executes that resolved path directly. The trap only bites a human typing `gitleaks ...` directly at an interactive prompt. Check for it with `type gitleaks` — if the output names a shell function or an rc file instead of a binary path, the shadow is active; invoke `nu scripts/gitleaks.nu` (or the mise-resolved absolute path) instead of the bare command.

### gitleaks.sh (Bash)

Bash script covering the same container runtimes as `gitleaks.nu`. It does NOT yet have the native-binary path or `--self-test` described above (claude-skills-209 scoped the native-first fix to `gitleaks.nu`) — prefer `gitleaks.nu` when a native binary is available:

```bash
# Run with auto-detected runtime
./scripts/gitleaks.sh

# Specify runtime
./scripts/gitleaks.sh --runtime docker
./scripts/gitleaks.sh -R container

# Generate report
./scripts/gitleaks.sh --report ./report.json

# Use custom config
./scripts/gitleaks.sh --config ./.gitleaks.toml
```

## Container Runtimes

The scripts support three container runtimes with automatic detection:

### Detection Priority

1. **Apple Container** (macOS 26+) - Native macOS containerization
2. **Docker** - Docker Desktop or Docker Engine
3. **Colima** - Lightweight container runtime via mise

### Apple Container (macOS 26+)

Native container support in macOS 26 and later:

```bash
# Check status
container system status

# Start runtime
container system start

# Run gitleaks
container run -v $(pwd):/code zricethezav/gitleaks detect --source="/code" -v
```

### Docker

Docker Desktop or Docker Engine:

```bash
# Check status
docker info >/dev/null 2>&1

# Start (macOS)
open -a Docker

# Run gitleaks
docker run -v $(pwd):/code zricethezav/gitleaks detect --source="/code" -v
```

### Colima via mise

Lightweight runtime managed through mise:

```bash
# Check status
mise exec colima@latest -- colima status

# Start runtime
mise exec colima@latest -- colima start

# Run gitleaks
mise exec colima@latest -- docker run -v $(pwd):/code zricethezav/gitleaks detect --source="/code" -v
```

Using `mise exec` provides automatic installation and version management without requiring global installation.

## Pre-Commit Integration

Add gitleaks to pre-commit hooks:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
```

Install and run:

```bash
pre-commit install
pre-commit run gitleaks --all-files
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Gitleaks

on: [push, pull_request]

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0

      - uses: gitleaks/gitleaks-action@v3
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### GitLab CI

```yaml
gitleaks:
  stage: security
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --source="." -v
  allow_failure: false
```

## Baseline Management

Create a baseline to ignore known false positives:

```bash
# Generate baseline
gitleaks detect --source="." -v --baseline-path=.gitleaks-baseline.json

# Scan using baseline
gitleaks detect --source="." -v --baseline-path=.gitleaks-baseline.json
```

Add `.gitleaks-baseline.json` to version control to track acknowledged findings.

## Best Practices

### Shift-Left Security

- Enable gitleaks in pre-commit hooks to catch secrets before they enter history
- Run scans on every PR in CI/CD pipelines
- Scan regularly even if not making changes

### When Secrets Are Found

1. **Revoke immediately** - Rotate the exposed credential
2. **Remove from history** - Use `git filter-branch` or BFG Repo Cleaner
3. **Add to .gitignore** - Prevent future commits of sensitive files
4. **Update baseline** - If false positive, add to baseline

### Prevention

- Use environment variables for secrets
- Use secret management tools (Vault, AWS Secrets Manager)
- Add secret patterns to `.gitignore`
- Configure IDE plugins to warn about secrets
- Use `.env.example` files without real values

## Mise Tasks Template

Copy the mise tasks from `templates/mise.toml` to add gitleaks scanning to any project:

```bash
# Available tasks after copying template
mise gitleaks              # Scan with Apple Container (default)
mise gitleaks:docker       # Scan with Docker
mise gitleaks:colima       # Scan with Colima

mise gitleaks:stop         # Stop all runtimes
mise gitleaks:stop:container
mise gitleaks:stop:docker
mise gitleaks:stop:colima
```

The tasks automatically:
- Detect and use `.gitleaks-baseline.json` if present
- Start the container runtime if not running
- Scan the repository root

## Key Principles

- **Defense in depth**: Run checks at multiple stages (local, CI, scheduled)
- **Fail fast**: Block PRs with detected secrets
- **Zero tolerance**: Treat all secret exposures as security incidents
- **Continuous monitoring**: Schedule regular scans of entire history
- **Clear ownership**: Define who handles secret remediation
- **No restraint trade-offs**: restraint never trades security or validation for brevity (`/core:restraint` "Never lazy about")
