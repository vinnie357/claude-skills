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

## Pre-Commit Hook (Automatic)

When this skill is loaded, a pre-commit hook automatically scans staged files for secrets before every `git commit` command, providing defense-in-depth by catching secrets before they enter git history. Only staged files are scanned (not the entire working tree); `.gitleaks-baseline.json` and `.gitleaks.toml`, when present, are honored for known false positives and custom rules.

If the hook detects secrets, the commit is **blocked** (exit code 2) with guidance to remove the secret, switch to an environment variable, or add it to the baseline if it's a false positive.

The hook requires a container runtime (Apple Container, Docker, or Colima via mise) to run gitleaks. **If no runtime is available, the hook logs a warning and allows the commit** — it fails open, not closed.

See [references/gitleaks-usage.md](references/gitleaks-usage.md) for the hook's exact flow diagram and block-message text.

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

**No safe invocation.** These commands are banned outright above — presenting a "correct" piped form here would imply a sanctioned way to run a banned command, and there isn't one. Each command reads the complete environment into its own process memory the instant it runs, independent of any pipe; that much is unavoidable, but it is not itself a transcript exposure — in `ps … | grep`, the full output goes into a pipe that `grep` consumes, and only what `grep` matches reaches stdout and the transcript. What makes a piped form dangerous instead of protective is that the protection is entirely conditional on the filter being exactly right: one mistyped variable name, one over-broad pattern, a stray `-v`, a missing anchor, and the full dump reaches the transcript with no way to take it back — a single-mistake failure mode on a command that cannot be run twice safely to check. The incident history backs this up rather than undercuts it: the 2026-07-30 incident ran a filtered form — `printenv | grep -i database` — and still leaked, because a case-insensitive substring match is exactly the over-broad pattern described above. A bare, unfiltered command is still the natural first move when you don't yet know the variable name you're hunting for, and that instinct is real — but the record includes both shapes, filtered and unfiltered, which is itself the point: neither shape is safe. Do not run `ps eww -p <pid> | tr ' ' '\n' | grep '^VARNAME='` or any variant expecting the pipe to make it safe.

If you need to know something about your OWN process's environment, use `test -n "$VAR"` (Agent Secret Safety, above) — that reads your own shell state directly, with no diagnostic exec'd against a target process. If you need a variable belonging to a DIFFERENT process, there is no safe way to read it via `ps`, `/proc`, or `printenv`: use that process's own introspection surface (a documented health/info/config endpoint) or ask the operator, rather than enumerating its environment.

**Inspection discipline.**
- Never inspect an environment "for context" or "to see what's there." Name the specific variable you need before running anything.
- Never place a secret on a command line (`env VAR=value cmd`, `curl -H "Authorization: Bearer $TOKEN"` with `$TOKEN` interpolated visibly) — command lines land in shell history and process listings same as the commands above.
- Treat `-e`/`-E`-shaped flags on any unfamiliar tool as suspect until you've checked what they do; the macOS/Linux split above (`-E` vs bare `e` vs `-e`-means-"all") is exactly the kind of one-letter, cross-platform inconsistency that causes an agent to reach for the wrong flag under the impression it is the safe one.

**Recovery.** If an environment dump reaches the transcript despite the above, self-report the exposure immediately and ask the operator to rotate every credential that appeared — do not wait to be asked, and do not attempt to redact it after the fact (the value is already in context/logs).

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

## Key Principles

- **Defense in depth**: Run checks at multiple stages (local, CI, scheduled)
- **Fail fast**: Block PRs with detected secrets
- **Zero tolerance**: Treat all secret exposures as security incidents
- **Continuous monitoring**: Schedule regular scans of entire history
- **Clear ownership**: Define who handles secret remediation
- **No restraint trade-offs**: restraint never trades security or validation for brevity (`/core:restraint` "Never lazy about")
- **Evidence-based claims**: every behavior claim in the references below (scan scope, hook bypasses, runtime detection) is tagged with how it was checked — re-verify against the current gitleaks/hook version before trusting an old claim; see `core:anti-fabrication`

## References

- [references/gitleaks-usage.md](references/gitleaks-usage.md) — read this when invoking gitleaks directly: manual scan commands, `.gitleaks.toml` config, exit codes, the bundled `gitleaks.nu`/`gitleaks.sh` scripts, the shell-function shadowing trap, baseline management, and the full "committed history only" scan-scope caveat with known hook bypasses
- [references/container-runtimes.md](references/container-runtimes.md) — read this when no native gitleaks binary is available and you need the Apple Container/Docker/Colima fallback, or when copying the Mise Tasks Template into a new project
- [references/ci-and-prevention.md](references/ci-and-prevention.md) — read this when wiring gitleaks into `pre-commit` or a CI/CD pipeline (GitHub Actions, GitLab CI) outside this skill's own PreToolUse hook, or reviewing the shift-left prevention checklist
