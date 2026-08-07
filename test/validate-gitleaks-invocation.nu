#!/usr/bin/env nu

# Regression tests for claude-skills-267: gitleaks fail-open on non-git scan
# paths and on zero-commit git repos, and the security-skill template
# ignoring the native binary / shipping the same unfixed --no-git gap.
#
# Defect 1 (fail-open on a non-git directory, the important one):
# `gitleaks detect --source=<dir>` against a directory that is not a git
# work tree fails to enumerate any files at all — gitleaks logs "fatal: not
# a git repository" and reports "no leaks found" having scanned ~0 bytes,
# exit 0. scripts/gitleaks.nu built exactly this argument shape and treated
# exit 0 as "No secrets detected". Adding `--no-git` makes the scan real.
#
# Defect 2 (template ignores the native binary): the security skill's
# templates/mise.toml [tasks.gitleaks] invoked `container run`
# unconditionally with no native-binary path at all, contradicting root
# mise.toml's own comment that the native binary is "preferred by
# scripts/gitleaks.nu over container runtimes" (claude-skills-209) and this
# workspace's restriction on container runtimes.
#
# Defect 3 (fail-open on a zero-commit git repo, Gate 3 B2): the fix for
# defect 1 gates `--no-git` on `git rev-parse --is-inside-work-tree`, which
# returns true for a freshly `git init`'d repo with zero commits — even
# though `gitleaks detect` (without --no-git) walks git history, and a
# zero-commit repo has none to walk. An untracked file containing a real
# secret in such a repo is never scanned, exit 0, same fail-open shape as
# defect 1 under a check that reports "yes, git" when there's nothing for
# git-mode scanning to see.
#
# Defect 4 (template ships the unfixed arg shape, Gate 3 B3): the template
# task never gained the --no-git handling scripts/gitleaks.nu got for
# defect 1 — `grep -c -- "--no-git" templates/mise.toml` is 0.
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
# checks below can't be fooled by prose elsewhere in the file. Gate 3 B1
# found two such false matches: a bare "native" marker matched the
# description's own "native binary preferred" wording, and a bare
# "container run" substring matched inside the word "container runtime" in
# a top-of-file comment. Returns null if the task or its run body isn't
# found.
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

def main [] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let script = ($repo_root | path join "plugins" "core" "skills" "security" "scripts" "gitleaks.nu")
    let template = ($repo_root | path join "plugins" "core" "skills" "security" "templates" "mise.toml")

    if not ($script | path exists) {
        print $"(ansi red_bold)❌ gitleaks.nu not found at ($script)(ansi reset)"
        exit 1
    }
    if not ($template | path exists) {
        print $"(ansi red_bold)❌ security template mise.toml not found at ($template)(ansi reset)"
        exit 1
    }

    mut failed = false

    # --- Case 1: fail-open regression on a non-git scan path -------------
    # Asserts on the "Secrets detected!" marker gitleaks.nu prints only
    # from the exit-code-1 branch of run-gitleaks-native, NOT on the bare
    # exit code: `validate-runtime "native"` also exits 1 when no gitleaks
    # binary resolves at all, so exit_code == 1 alone passes vacuously in
    # an environment with no scanner installed (Gate 3 F6).
    let secret_dir = (make-non-git-secret-fixture)
    let scan = (nu $script --path $secret_dir -R native | complete)
    if not ($scan.stdout | str contains "Secrets detected!") {
        print $"(ansi red_bold)❌ non-git scan with a real secret present: want 'Secrets detected!' in output, script exit ($scan.exit_code) — fail-open regression \(claude-skills-267\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ non-git scan with a real secret present blocks \(Secrets detected!\)(ansi reset)"
    }
    rm -rf $secret_dir

    # --- Case 2: non-git scan path must add --no-git to the constructed
    # gitleaks arguments, so the scan is real instead of silently scanning
    # zero bytes. Driven through observable output: gitleaks.nu prints the
    # exact command line it invokes ("Command: <binary> <args>") before
    # running it.
    let plain_dir = (make-non-git-plain-fixture)
    let arg_check = (nu $script --path $plain_dir -R native | complete)
    let command_line = ($arg_check.stdout | lines | where {|l| $l | str contains "Command:"} | get -o 0 | default "")
    if not ($command_line | str contains "--no-git") {
        print $"(ansi red_bold)❌ non-git scan path: constructed gitleaks args do not include --no-git(ansi reset)"
        print $"   command line: ($command_line)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ non-git scan path: constructed gitleaks args include --no-git(ansi reset)"
    }
    rm -rf $plain_dir

    # --- Case 3: template [tasks.gitleaks] must attempt native-binary
    # resolution before any container invocation. Structural check against
    # the isolated run-script body only (see extract-gitleaks-task-body),
    # matching a single specific marker on each side: "mise which gitleaks"
    # (the actual resolution call, not the word "native" which also
    # appears in the task's own description) and "^container run" (the nu
    # external-command invocation, which "container runtime" in prose does
    # not contain — bare "container run" does, since "runtime" starts with
    # "run").
    let content = (open $template --raw)
    let task_body = (extract-gitleaks-task-body $content)
    if $task_body == null {
        print $"(ansi red_bold)❌ [tasks.gitleaks] run body not found in ($template)(ansi reset)"
        $failed = true
    } else {
        let native_index = ($task_body | str index-of "mise which gitleaks")
        let container_index = ($task_body | str index-of "^container run")

        if $native_index < 0 {
            print $"(ansi red_bold)❌ [tasks.gitleaks] has no native-binary resolution path at all \(claude-skills-267\)(ansi reset)"
            $failed = true
        } else if $container_index < 0 {
            print $"(ansi red_bold)❌ [tasks.gitleaks] has no container invocation to compare against — test assumption broken(ansi reset)"
            $failed = true
        } else if $native_index > $container_index {
            print $"(ansi red_bold)❌ [tasks.gitleaks] invokes container run \(offset ($container_index)\) before attempting native-binary resolution \(offset ($native_index)\)(ansi reset)"
            $failed = true
        } else {
            print $"(ansi green_bold)✅ [tasks.gitleaks] attempts native-binary resolution \(offset ($native_index)\) before container run \(offset ($container_index)\)(ansi reset)"
        }
    }

    # --- Case 4: fail-open on a zero-commit git repo (Gate 3 B2). A repo
    # is "inside a work tree" from the moment `git init` runs, well before
    # any commit exists — but gitleaks's default (non---no-git) mode walks
    # git history, which is empty. Same assertion shape as Case 1: the
    # "Secrets detected!" marker, not the bare exit code.
    let zero_commit_dir = (make-zero-commit-git-secret-fixture)
    let zero_commit_scan = (nu $script --path $zero_commit_dir -R native | complete)
    if not ($zero_commit_scan.stdout | str contains "Secrets detected!") {
        print $"(ansi red_bold)❌ zero-commit git repo with an untracked secret present: want 'Secrets detected!' in output, script exit ($zero_commit_scan.exit_code) — fail-open regression \(claude-skills-267 Gate 3 B2\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ zero-commit git repo with an untracked secret present blocks \(Secrets detected!\)(ansi reset)"
    }
    rm -rf $zero_commit_dir

    # --- Case 5: template [tasks.gitleaks] must handle the non-git case
    # the same way scripts/gitleaks.nu does (Gate 3 B3). Reuses the same
    # isolated run-script body as Case 3.
    if $task_body == null {
        print $"(ansi red_bold)❌ [tasks.gitleaks] run body not found in ($template) — cannot check --no-git handling(ansi reset)"
        $failed = true
    } else if not ($task_body | str contains "--no-git") {
        print $"(ansi red_bold)❌ [tasks.gitleaks] never passes --no-git — ships the same unfixed fail-open shape scripts/gitleaks.nu fixes \(claude-skills-267 Gate 3 B3\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [tasks.gitleaks] handles the non-git case with --no-git(ansi reset)"
    }

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ gitleaks invocation checks verified(ansi reset)"
}
