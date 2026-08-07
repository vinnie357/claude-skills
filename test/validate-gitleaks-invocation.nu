#!/usr/bin/env nu

# Regression tests for claude-skills-267: gitleaks fail-open on non-git scan
# paths and on zero-commit git repos, the security-skill template ignoring
# the native binary / shipping the same unfixed --no-git gap, and the same
# defects in gitleaks.sh (bash parity script).
#
# Defect 1 (fail-open on a non-git directory, the important one):
# `gitleaks detect --source=<dir>` against a directory that is not a git
# work tree fails to enumerate any files at all — gitleaks logs "fatal: not
# a git repository" and reports "no leaks found" having scanned ~0 bytes,
# exit 0. Adding `--no-git` makes the scan real.
#
# Defect 2 (template ignores the native binary): the security skill's
# templates/mise.toml [tasks.gitleaks] invoked `container run`
# unconditionally with no native-binary path at all.
#
# Defect 3 (fail-open on a zero-commit git repo, Gate 3 B2): gating
# `--no-git` on `git rev-parse --is-inside-work-tree` is not enough — that
# check returns true for a freshly `git init`'d repo with zero commits,
# even though `gitleaks detect` (without --no-git) walks git history, and a
# zero-commit repo has none to walk. Closed via a separate invariant:
# refuse to report clean unless gitleaks' own scan summary shows bytes
# actually scanned (see gitleaks.nu's gitleaks-verified-clean).
#
# Defect 4 (template ships the unfixed arg shape, Gate 3 B3): the template
# task didn't originally have the --no-git handling scripts/gitleaks.nu got
# for defect 1.
#
# Gate 3 R1 (structural-check comment blindness): the FIRST tightened
# version of Case 3/Case 5 (marker substring match over an isolated
# run-body slice) still passed on a template with ZERO real native
# resolution and ZERO --no-git, because the reviewer's mutation put both
# marker strings inside COMMENT LINES describing what the code does NOT do
# ("we do not call mise which gitleaks", "we deliberately do NOT pass
# --no-git here") while the real code was an unconditional container run.
# Fixed by stripping full comment lines before matching (strip-comment-lines).
#
# Gate 3 R5 (marker split): gitleaks.nu now prints a distinct "Scan
# unverified!" marker (not "Secrets detected!") from the
# refuse-to-report-clean branch — printing "Secrets detected!" when nothing
# was actually detected was itself a fabricated claim in a security tool.
# Case 1/2 assert genuine detection ("Secrets detected!"); Case 4 (which
# takes the zero-bytes/unverified branch, not genuine detection) asserts
# "Scan unverified!" specifically so it can no longer pass vacuously
# regardless of which branch actually fired.
#
# Usage: nu test/validate-gitleaks-invocation.nu

# Slack bot token pattern gitleaks's default ruleset detects (RuleID:
# slack-bot-token) and does NOT allowlist — verified directly against
# gitleaks 8.30.1 before this test was written. The canonical AWS example
# key (AKIAIOSFODNN7EXAMPLE) is allowlisted by gitleaks's default config and
# produces "no leaks found" even when scanned correctly, so it cannot be
# used as a fixture here.
#
# Built at RUNTIME from parts, not as a single committed literal: a literal
# token-shaped string in this file would itself trip the slack-bot-token
# rule on every future scan of this repo, adding a permanent false positive
# to the exact gate this test exists to strengthen. The temp file(s) this
# writes still contain a complete, real token gitleaks detects — only the
# on-disk form of THIS source file avoids the pattern.
def fixture-secret [] {
    ["xoxb" "123456789012" "123456789012" "abcdefghijklmnopqrstuvwx"] | str join "-"
}

# A unique, non-git temp directory containing one file with a real
# (non-allowlisted) secret pattern. Caller is responsible for `rm -rf`.
def make-non-git-secret-fixture [] {
    let dir = (mktemp -d)
    $"slack_token = \"(fixture-secret)\"\n" | save --force ($dir | path join "secret.txt")
    $dir
}

# A unique, non-git temp directory containing one innocuous file — no
# secret content, used for the arg-construction test where detection
# outcome doesn't matter, only the invocation shape does.
def make-non-git-plain-fixture [] {
    let dir = (mktemp -d)
    "hello world\n" | save --force ($dir | path join "plain.txt")
    $dir
}

# A unique git repository with ZERO commits, containing one UNTRACKED file
# with a real secret. `git rev-parse --is-inside-work-tree` reports true
# here (it is a real work tree) even though `git log` has nothing to walk —
# the exact condition defect 3 exploits. Caller is responsible for `rm -rf`.
def make-zero-commit-git-secret-fixture [] {
    let dir = (mktemp -d)
    git -C $dir init -q
    git -C $dir config user.email "test@example.com"
    git -C $dir config user.name "test"
    $"slack_token = \"(fixture-secret)\"\n" | save --force ($dir | path join "secret.txt")
    $dir
}

# Isolates the [tasks.gitleaks] task's `run = """..."""` body — excludes
# the task header and its `description = "..."` line — so structural
# checks below can't be fooled by prose elsewhere in the file. Returns null
# if the task or its run body isn't found.
def extract-gitleaks-task-body [content: string] {
    let task_start = ($content | str index-of "[tasks.gitleaks]")
    if $task_start < 0 {
        return null
    }
    let rest = ($content | str substring $task_start..)
    let run_marker = 'run = """'
    let run_offset = ($rest | str index-of $run_marker)
    if $run_offset < 0 {
        return null
    }
    let after_run = ($rest | str substring ($run_offset + ($run_marker | str length))..)
    # next top-level task header bounds this task's body
    let next_task_offset = ($after_run | str index-of "\n[tasks.")
    if $next_task_offset < 0 {
        $after_run
    } else {
        $after_run | str substring 0..$next_task_offset
    }
}

# Strips full comment lines before structural marker checks (Gate 3 R1).
# A bare substring match over the raw run body treats prose and code
# identically — the reviewer's mutation embedded BOTH the native-resolution
# marker and --no-git inside comment lines describing what the real code
# (a bare unconditional container run) does NOT do, and the un-stripped
# check still printed ✅. Strips any line whose TRIMMED content starts with
# `#` (nu's comment syntax), so only real code can satisfy a marker.
#
# Known limitation (asked for explicitly in review): this is line-based,
# not a real parser. A `#` that starts a physical line while inside an
# OPEN multi-line string literal would be wrongly stripped as if it were a
# comment. Checked directly against the current templates/mise.toml
# (`grep -n '^\s*#' plugins/core/skills/security/templates/mise.toml`):
# every line matching that pattern today is a genuine top-level comment or
# shebang — none are string content — so this risk is not live in the file
# as it exists now. A future edit introducing a multi-line string with a
# line-initial `#` would need a real TOML/nu parser to handle correctly;
# noting the limitation here rather than silently assuming it can never
# happen.
def strip-comment-lines [text: string] {
    $text
        | lines
        | where {|l| not ($l | str trim | str starts-with "#")}
        | str join "\n"
}

def main [] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let script = ($repo_root | path join "plugins" "core" "skills" "security" "scripts" "gitleaks.nu")
    let sh_script = ($repo_root | path join "plugins" "core" "skills" "security" "scripts" "gitleaks.sh")
    let template = ($repo_root | path join "plugins" "core" "skills" "security" "templates" "mise.toml")

    if not ($script | path exists) {
        print $"(ansi red_bold)❌ gitleaks.nu not found at ($script)(ansi reset)"
        exit 1
    }
    if not ($sh_script | path exists) {
        print $"(ansi red_bold)❌ gitleaks.sh not found at ($sh_script)(ansi reset)"
        exit 1
    }
    if not ($template | path exists) {
        print $"(ansi red_bold)❌ security template mise.toml not found at ($template)(ansi reset)"
        exit 1
    }

    mut failed = false

    # --- Case 1: fail-open regression on a non-git scan path (gitleaks.nu)
    # Asserts on the "Secrets detected!" marker — genuine detection, not
    # the unrelated "Scan unverified!" refuse-to-report-clean marker
    # (Gate 3 R5 split) and not the bare exit code (Gate 3 F6: exit 1 also
    # fires when no gitleaks binary resolves at all).
    let secret_dir = (make-non-git-secret-fixture)
    let scan = (nu $script --path $secret_dir -R native | complete)
    if not ($scan.stdout | str contains "Secrets detected!") {
        print $"(ansi red_bold)❌ [gitleaks.nu] non-git scan with a real secret present: want 'Secrets detected!' in output, script exit ($scan.exit_code) — fail-open regression \(claude-skills-267\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.nu] non-git scan with a real secret present blocks \(Secrets detected!\)(ansi reset)"
    }
    rm -rf $secret_dir

    # --- Case 2: non-git scan path must add --no-git to the constructed
    # gitleaks arguments (gitleaks.nu), so the scan is real instead of
    # silently scanning zero bytes. Driven through observable output:
    # gitleaks.nu prints the exact command line it invokes before running
    # it.
    let plain_dir = (make-non-git-plain-fixture)
    let arg_check = (nu $script --path $plain_dir -R native | complete)
    let command_line = ($arg_check.stdout | lines | where {|l| $l | str contains "Command:"} | get -o 0 | default "")
    if not ($command_line | str contains "--no-git") {
        print $"(ansi red_bold)❌ [gitleaks.nu] non-git scan path: constructed gitleaks args do not include --no-git(ansi reset)"
        print $"   command line: ($command_line)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.nu] non-git scan path: constructed gitleaks args include --no-git(ansi reset)"
    }
    rm -rf $plain_dir

    # --- Case 3: template [tasks.gitleaks] must attempt native-binary
    # resolution before any container invocation. Structural check against
    # the isolated, COMMENT-STRIPPED run-script body (Gate 3 R1 — see
    # strip-comment-lines), matching a single specific marker on each side,
    # both anchored to nu's `^` external-command sigil so a QUOTED STRING
    # LITERAL containing the same words (e.g. `let label = "mise which
    # gitleaks"`, which is real code but not an invocation) cannot satisfy
    # the check either — verified against exactly this shape during Gate 3
    # R1 remediation, alongside the comment and description shapes:
    # "^mise which gitleaks" (the actual resolution call) and
    # "^container run" (the nu external-command invocation, which the
    # English word "runtime" does not contain even though "container run"
    # bare does, since "runtime" starts with "run").
    let content = (open $template --raw)
    let raw_task_body = (extract-gitleaks-task-body $content)
    let task_body = if $raw_task_body == null { null } else { strip-comment-lines $raw_task_body }
    if $task_body == null {
        print $"(ansi red_bold)❌ [template] [tasks.gitleaks] run body not found in ($template)(ansi reset)"
        $failed = true
    } else {
        let native_index = ($task_body | str index-of "^mise which gitleaks")
        let container_index = ($task_body | str index-of "^container run")

        if $native_index < 0 {
            print $"(ansi red_bold)❌ [template] [tasks.gitleaks] has no native-binary resolution path at all \(claude-skills-267\)(ansi reset)"
            $failed = true
        } else if $container_index < 0 {
            print $"(ansi red_bold)❌ [template] [tasks.gitleaks] has no container invocation to compare against — test assumption broken(ansi reset)"
            $failed = true
        } else if $native_index > $container_index {
            print $"(ansi red_bold)❌ [template] [tasks.gitleaks] invokes container run \(offset ($container_index)\) before attempting native-binary resolution \(offset ($native_index)\)(ansi reset)"
            $failed = true
        } else {
            print $"(ansi green_bold)✅ [template] [tasks.gitleaks] attempts native-binary resolution \(offset ($native_index)\) before container run \(offset ($container_index)\), comment-stripped(ansi reset)"
        }
    }

    # --- Case 4: fail-open on a zero-commit git repo (Gate 3 B2, gitleaks.nu).
    # A repo is "inside a work tree" from the moment `git init` runs, well
    # before any commit exists — but gitleaks's default (non---no-git) mode
    # walks git history, which is empty. This fixture never trips the
    # "Secrets detected!" branch at all — it takes the zero-bytes
    # refuse-to-report-clean path — so asserting the split "Scan
    # unverified!" marker (Gate 3 R5) is required for this case to
    # distinguish genuine detection from the unverified-scan branch;
    # asserting "Secrets detected!" here would pass whether or not that
    # branch actually fires.
    let zero_commit_dir = (make-zero-commit-git-secret-fixture)
    let zero_commit_scan = (nu $script --path $zero_commit_dir -R native | complete)
    if not ($zero_commit_scan.stdout | str contains "Scan unverified!") {
        print $"(ansi red_bold)❌ [gitleaks.nu] zero-commit git repo with an untracked secret present: want 'Scan unverified!' in output, script exit ($zero_commit_scan.exit_code) — fail-open regression \(claude-skills-267 Gate 3 B2\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.nu] zero-commit git repo with an untracked secret present blocks \(Scan unverified!\)(ansi reset)"
    }
    rm -rf $zero_commit_dir

    # --- Case 5: template [tasks.gitleaks] must handle the non-git case
    # the same way scripts/gitleaks.nu does (Gate 3 B3). Reuses the same
    # comment-stripped body as Case 3 (Gate 3 R1).
    if $task_body == null {
        print $"(ansi red_bold)❌ [template] [tasks.gitleaks] run body not found in ($template) — cannot check --no-git handling(ansi reset)"
        $failed = true
    } else if not ($task_body | str contains "--no-git") {
        print $"(ansi red_bold)❌ [template] [tasks.gitleaks] never passes --no-git — ships the same unfixed fail-open shape scripts/gitleaks.nu fixes \(claude-skills-267 Gate 3 B3\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [template] [tasks.gitleaks] handles the non-git case with --no-git, comment-stripped(ansi reset)"
    }

    # --- Case 6/7: gitleaks.sh parity (operator decision: bring gitleaks.sh
    # to the same fixed behavior as gitleaks.nu). gitleaks.sh currently has
    # zero --no-git handling, zero native-binary resolution, and zero
    # scanned-bytes verification. These assert the SAME two fail-open
    # shapes as Cases 1 and 4, invoked with -R native mirroring
    # gitleaks.nu's flag and marker conventions (the parity port's target
    # shape) — `-R native` is currently rejected by gitleaks.sh's
    # validate_runtime() ("Invalid runtime 'native'"), which fails these
    # cases WITHOUT invoking any container runtime, so they stay
    # side-effect-free and CI-safe both before and after the port.
    let sh_secret_dir = (make-non-git-secret-fixture)
    let sh_scan = (do { ^bash $sh_script --path $sh_secret_dir -R native } | complete)
    let sh_combined = ($sh_scan.stdout + $sh_scan.stderr)
    if not ($sh_combined | str contains "Secrets detected!") {
        print $"(ansi red_bold)❌ [gitleaks.sh] non-git scan with a real secret present: want 'Secrets detected!' in output, script exit ($sh_scan.exit_code) — fail-open regression, no native/--no-git parity yet \(claude-skills-267\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.sh] non-git scan with a real secret present blocks \(Secrets detected!\)(ansi reset)"
    }
    rm -rf $sh_secret_dir

    let sh_zero_commit_dir = (make-zero-commit-git-secret-fixture)
    let sh_zero_scan = (do { ^bash $sh_script --path $sh_zero_commit_dir -R native } | complete)
    let sh_zero_combined = ($sh_zero_scan.stdout + $sh_zero_scan.stderr)
    if not ($sh_zero_combined | str contains "Scan unverified!") {
        print $"(ansi red_bold)❌ [gitleaks.sh] zero-commit git repo with an untracked secret present: want 'Scan unverified!' in output, script exit ($sh_zero_scan.exit_code) — fail-open regression, no native/--no-git/zero-bytes parity yet \(claude-skills-267 Gate 3 B2\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.sh] zero-commit git repo with an untracked secret present blocks \(Scan unverified!\)(ansi reset)"
    }
    rm -rf $sh_zero_commit_dir

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ gitleaks invocation checks verified(ansi reset)"
}
