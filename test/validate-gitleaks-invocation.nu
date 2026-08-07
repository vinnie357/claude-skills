#!/usr/bin/env nu

# Regression tests for claude-skills-267: gitleaks fail-open on non-git scan
# paths, and the security-skill template ignoring the native binary.
#
# Defect 1 (fail-open, the important one): `gitleaks detect --source=<dir>`
# against a directory that is not a git work tree fails to enumerate any
# files at all — gitleaks logs "fatal: not a git repository" and reports
# "no leaks found" having scanned ~0 bytes, exit 0. scripts/gitleaks.nu
# builds exactly this argument shape (build-gitleaks-args-native, ~line
# 386) and treats exit 0 as "No secrets detected" (run-gitleaks-native,
# ~line 466) — so pointing the script at a non-git directory yields a green
# security gate that scanned nothing. Adding `--no-git` makes the scan real.
#
# Defect 2 (template ignores the native binary): the security skill's
# templates/mise.toml [tasks.gitleaks] invokes `container run` unconditionally
# with no native-binary path at all, contradicting root mise.toml's own
# comment that the native binary is "preferred by scripts/gitleaks.nu over
# container runtimes" (claude-skills-209) and this workspace's restriction
# on container runtimes.
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
# to the exact gate this test exists to strengthen. The temp file this
# writes still contains a complete, real token gitleaks detects — only the
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
    let secret_dir = (make-non-git-secret-fixture)
    let scan = (nu $script --path $secret_dir -R native | complete)
    if $scan.exit_code != 1 {
        print $"(ansi red_bold)❌ non-git scan with a real secret present: want script exit 1 \(secrets detected\), got ($scan.exit_code) — fail-open regression \(claude-skills-267\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ non-git scan with a real secret present blocks \(script exit 1\)(ansi reset)"
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
    # resolution before any container invocation. Structural check, not a
    # bare substring match: the FIRST native-resolution marker must appear
    # at a lower byte offset than the FIRST container invocation, within
    # the [tasks.gitleaks] task body specifically (not the whole file,
    # which also documents container-only fallback tasks by design).
    let content = (open $template --raw)
    let task_start = ($content | str index-of "[tasks.gitleaks]")
    if $task_start < 0 {
        print $"(ansi red_bold)❌ [tasks.gitleaks] not found in ($template)(ansi reset)"
        $failed = true
    } else {
        let rest = ($content | str substring $task_start..)
        # next top-level task header (skip the opening one at offset 0)
        let next_task_offset = ($rest | str substring 1.. | str index-of "\n[tasks.")
        let task_body = if $next_task_offset < 0 {
            $rest
        } else {
            $rest | str substring 0..($next_task_offset + 1)
        }

        let native_markers = ["mise which gitleaks" "which gitleaks" "gitleaks.nu" "native"]
        let native_indices = ($native_markers
            | each {|m| $task_body | str downcase | str index-of ($m | str downcase)}
            | where {|i| $i >= 0})
        let container_index = ($task_body | str index-of "container run")

        if ($native_indices | is-empty) {
            print $"(ansi red_bold)❌ [tasks.gitleaks] has no native-binary resolution path at all \(claude-skills-267\)(ansi reset)"
            $failed = true
        } else if $container_index < 0 {
            print $"(ansi red_bold)❌ [tasks.gitleaks] has no container invocation to compare against — test assumption broken(ansi reset)"
            $failed = true
        } else {
            let earliest_native = ($native_indices | math min)
            if $earliest_native > $container_index {
                print $"(ansi red_bold)❌ [tasks.gitleaks] invokes container run \(offset ($container_index)\) before attempting native-binary resolution \(offset ($earliest_native)\)(ansi reset)"
                $failed = true
            } else {
                print $"(ansi green_bold)✅ [tasks.gitleaks] attempts native-binary resolution \(offset ($earliest_native)\) before container run \(offset ($container_index)\)(ansi reset)"
            }
        }
    }

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ gitleaks invocation checks verified(ansi reset)"
}
