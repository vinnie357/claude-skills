# Gitleaks Usage

Reference for invoking gitleaks directly — the exact PreToolUse hook flow and block message, manual scan commands, custom `.gitleaks.toml` config, exit codes, the bundled `gitleaks.nu`/`gitleaks.sh` scripts, and baseline management. See the parent SKILL.md for when the automatic pre-commit hook runs and its fails-open behavior.

## Pre-Commit Hook Flow

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

If the hook detects secrets, the commit is blocked with this guidance:

```
[gitleaks] SECRETS DETECTED in staged files!
[gitleaks] Commit blocked. Remove secrets before committing.
[gitleaks]
[gitleaks] Options:
[gitleaks]   1. Remove the secret from the file
[gitleaks]   2. Use environment variables instead
[gitleaks]   3. Add to .gitleaks-baseline.json if false positive
```

Only **staged files** are scanned (not the entire working tree). Uses `.gitleaks-baseline.json` if present to ignore known false positives, and `.gitleaks.toml` if present for custom detection rules.

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

Invoke gitleaks via its resolved absolute path (`$(mise which gitleaks)`), never a bare `gitleaks` command in an interactive shell — an rc-file shell function can silently reroute the bare command through a full-history container scan regardless of the flags you passed. See "Shell-function shadowing trap" below for the mechanism and how to check for it.

Current syntax (verified against gitleaks 8.30.1) uses `git`/`dir` subcommands — `detect`/`protect` still work but are deprecated aliases no longer listed in `--help`:

```bash
GITLEAKS=$(mise which gitleaks)

# Scan the current git repository's full history
"$GITLEAKS" git . -v

# Scan with JSON report
"$GITLEAKS" git . -v --report-path=report.json --report-format=json

# Scan only staged changes (pre-commit)
"$GITLEAKS" git . --staged

# Scan git history explicitly (equivalent to the default; --log-opts scopes the range)
"$GITLEAKS" git . --log-opts="--all"

# Scan a directory or files without git awareness
"$GITLEAKS" dir . -v
```

#### Scan scope: committed history only

In a git working tree with at least one commit — the common case — `git` mode walks committed history; it does not examine uncommitted working-tree changes. A clean result means nothing in the scanned history matched a known secret pattern, not that the repository holds no secrets: verified against a fixture with one committed file, an uncommitted file, and a gitignored `.env`, each holding a live-shaped token — the history scan reported "no leaks found" while a `dir` scan of the same tree caught both (`claude-skills-268`). A bare repository (no working tree) does not get its history walked either — the same empty-history behavior applies to a container mount that isn't a committed git repo (see the SKILL.md's References list for the Container Runtimes write-up). A directory that is not a git repository at all is the inverse: `gitleaks.nu`'s own fallback runs a full content scan there instead, catching what the committed-history case above misses (verified directly) — the `dir` invocation is redundant for that one shape, though the Mise Tasks Template can never reach it: its target comes from `git rev-parse --show-toplevel`, which errors outright outside a repo, so the task fails before any scan runs rather than falling back the way `gitleaks.nu` does (verified). The committed-history-only scope — not the non-git-directory fallback — is what applies identically to `gitleaks.sh` and the Mise Tasks Template: all three build the same `detect --source=<path>` args, with `--no-git` appended from the same is-a-git-worktree check, whenever the target is a git working tree.

The staged case has partial coverage, not full — known bypasses, not necessarily every bypass. The `check-secrets-before-commit.sh` PreToolUse hook reads `git diff --cached` and scans that content with `--no-git`, but only what is already staged when the hook fires: `git commit -a`, `-am`, and the pathspec form (`git commit <path>`) stage during the commit itself, after the hook has already run, so a modified-but-unstaged tracked file is invisible to it (verified: a live token in such a file produces "No staged files to scan" and exit 0 for all three commit forms; the same token pre-staged is caught, exit 2). A second, worse class: the hook's own trigger regex, `^git[[:space:]]+commit`, is anchored at the start of the command string — anything that is not literally `git commit …` at position 0 never fires it, not even the "no staged files" message. That covers a compound command (`git add . && git commit …`), a `cd … &&` prefix, an env-var prefix, leading whitespace, or a global option such as `git -C <dir> commit` (verified with the secret correctly staged: each form is not intercepted, exit 0, no scan attempted; plain `git commit -m x` with the same staged secret is blocked, exit 2). The compound form matters most because it is what this repo's own workflow prescribes: `/core:git`'s PR-workflow step, the bees skill, and this repository's own `CLAUDE.md` all instruct `git add .bees/ && git commit -m "chore(bees): close <id>"` for closing a tracker issue — the exact invocation the hook this section documents never sees. Both classes tracked as `claude-skills-271`. The hook fails open when no scanner is available (see the SKILL.md's Pre-Commit Hook section). Its registration is not scoped to `/core:security`'s own turn: Claude Code's hooks documentation states that once a skill hook is registered — by loading the skill in the session — it keeps running "for the rest of the session, on turns after the skill's own turn as well." The real gap is narrower than "not currently loaded": a session that never invokes `/core:security` at all never registers the hook, but one that invoked it earlier still has it armed. To check uncommitted working-tree content directly, scan with `dir` instead: `$(mise which gitleaks) dir . -v` — verified it also flags gitignored files, which is why this stays a manual check rather than the automatic gate: a `.env` holding a real secret is normal practice, and a check that routinely flags it gets baselined or ignored.

A third, narrower class involves the untracked-files pass specifically: `git ls-files --others --exclude-standard` correctly hides gitignored paths, so `git add -f <gitignored-path> && git commit -m x` in a single compound command reaches the hook before the force-add has actually run — the file is still untracked and excluded at the moment every pass evaluates, and none of them see it (verified: a live token in a gitignored `.env`, force-added and committed in one compound command, produces "No staged, modified-tracked, or new untracked files to scan" and exit 0). A separate `git add -f <path>` followed by a distinct `git commit` is not affected — the file is genuinely in the index by the time the hook fires, caught by the staged pass exactly like any other staged secret (verified: same fixture split into two hook invocations, blocked at the commit, exit 2). Two attempts to widen the untracked pass for the compound case were each defeated by a real false positive and reverted rather than replaced by a third: a bare `-f` substring match caught `git commit --fixup=HEAD` and `--file=<path>`; a whitespace-bounded `-f`/`--force` token match caught `rm -f tmp.txt && git commit`, `grep -f patterns.txt file && git commit`, `docker build -f Dockerfile . && git commit`, and `tar -x -f a.tar && git commit` — a command string does not carry the structure to say whose flag a `-f` belongs to. A widened pass here also could not keep `--exclude-standard`, since including force-added files was the entire point, so every false trigger would have scanned every gitignored file in the repo, not only the one force-added. The gap is pinned by tests (`test/validate-security-hook.nu` Parts 15–17), not forgotten — tracked as `claude-skills-272`. Force-adding a gitignored path is worth a manual check first: `$(mise which gitleaks) dir <path> -v`.

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

Same committed-history-only scan scope as manual `git` mode above — see the "Scan scope: committed history only" section above for the full caveat and known bypass classes.

#### Shell-function shadowing trap

A shell function named `gitleaks` defined in an interactive shell's rc file (zsh/bash) can shadow the real binary and silently reroute a bare `gitleaks ...` invocation at the terminal through `container run` instead of the native binary — observed on a real host, where an rc-sourced snapshot defined exactly such a function. `gitleaks.nu` itself is immune: it never invokes a bare `gitleaks` command, it resolves the binary's absolute path via `mise which gitleaks` (or `which gitleaks` as fallback) and executes that resolved path directly. The trap only bites a human typing `gitleaks ...` directly at an interactive prompt. Check for it with `type gitleaks` — if the output names a shell function or an rc file instead of a binary path, the shadow is active; invoke `nu scripts/gitleaks.nu` (or the mise-resolved absolute path) instead of the bare command.

### gitleaks.sh (Bash)

Bash script with the same runtime-detection precedence, native-binary resolution, and committed-history-only scan scope as `gitleaks.nu` (same committed-history-only caveat as `git` mode above — see the "Scan scope: committed history only" section earlier in this file for the full write-up). Both scripts, and the Mise Tasks Template, anchor the bytes-verification invariant on gitleaks' own scan-summary line shape (`scanned ~<digits> bytes (<total>) in <duration>`) rather than picking a substring by position — a cross-implementation conformance test, `test/validate-gitleaks-invocation.nu`, feeds identical stderr fixtures to all three and requires identical verdicts. Ran it directly: all 6 conformance cases pass, agreeing across `gitleaks.nu`, `gitleaks.sh`, and the template. The one remaining gap: `gitleaks.sh` has no `--self-test` flag, so its own selection logic can only be exercised by actually running it, never in isolation. Prefer `gitleaks.nu` — this repo is nushell-first (`/core:nushell`), and only `gitleaks.nu`'s `--self-test` lets you check that logic without a gitleaks binary or container runtime present. Use `gitleaks.sh` on a host without nushell installed:

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

## Baseline Management

Create a baseline to ignore known false positives:

Invoke via the resolved binary path, not a bare `gitleaks` command — see "Shell-function shadowing trap" above.

```bash
GITLEAKS=$(mise which gitleaks)

# Generate baseline
"$GITLEAKS" git . -v --baseline-path=.gitleaks-baseline.json

# Scan using baseline
"$GITLEAKS" git . -v --baseline-path=.gitleaks-baseline.json
```

Add `.gitleaks-baseline.json` to version control to track acknowledged findings.
