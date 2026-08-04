#!/usr/bin/env nu

# fenced-literals.toml schema + content-agreement validator (claude-skills-176).
#
# Validates plugins/tools/claude-code/skills/skill-update/fenced-literals.toml:
#   B-group: schema (required/unknown keys, enums, conditional fields)
#   C-group: registry <-> doc-content agreement (the `file` exists, and the
#            `literal` string still appears in it — catches registry drift
#            when a doc changes without the registry being updated)
#
# Zero network calls. This is NOT a freshness check — it cannot tell you
# whether a literal is stale. That question needs upstream, and belongs to
# the separate, deliberately-manual `mise sources:fence-check`
# (scripts/fence-freshness.nu). This check only proves the registry is
# telling the truth about what is CURRENTLY in the docs.
#
# Usage:
#   nu test/validate-fenced-literals.nu              # scan the real registry
#   nu test/validate-fenced-literals.nu --self-test  # verify the rules themselves

const ENTRY_KEYS = [
    "file" "literal" "context" "check_method" "github_repo" "docker_image"
    "pinned_tag" "eol_product" "eol_cycle" "policy" "notes"
]
const CHECK_METHODS = ["github-releases" "docker-hub" "manual"]
const POLICIES = ["track" "intentional-pin"]
const ENTRY_REQUIRED_ALWAYS = ["file" "literal" "check_method" "policy"]

# Returns [{rule, severity, message}] for one entry. Pure — the caller
# supplies doc content, so this has no filesystem access and is fully
# self-testable.
def check-entry [entry: record, doc_content: any]: nothing -> list {
    mut findings = []
    let cols = ($entry | columns)
    let name = ($entry.file? | default "unnamed")

    for k in $cols {
        if $k not-in $ENTRY_KEYS {
            $findings = ($findings | append {
                rule: "b1_unknown_key"
                severity: "fail"
                message: $"($name): unknown key '($k)'"
            })
        }
    }

    for k in $ENTRY_REQUIRED_ALWAYS {
        if $k not-in $cols {
            $findings = ($findings | append {
                rule: "b1_missing_key"
                severity: "fail"
                message: $"($name): missing required key '($k)'"
            })
        }
    }

    let check_method = ($entry.check_method? | default "")
    if ("check_method" in $cols) and ($check_method not-in $CHECK_METHODS) {
        $findings = ($findings | append {
            rule: "b2_enum"
            severity: "fail"
            message: $"($name): check_method '($check_method)' not one of github-releases|docker-hub|manual"
        })
    }

    let policy = ($entry.policy? | default "")
    if ("policy" in $cols) and ($policy not-in $POLICIES) {
        $findings = ($findings | append {
            rule: "b2_enum"
            severity: "fail"
            message: $"($name): policy '($policy)' not one of track|intentional-pin"
        })
    }

    if $check_method == "github-releases" {
        if "github_repo" not-in $cols {
            $findings = ($findings | append {
                rule: "b4_conditional"
                severity: "fail"
                message: $"($name): check_method=github-releases requires github_repo"
            })
        }
        if "pinned_tag" not-in $cols {
            $findings = ($findings | append {
                rule: "b4_conditional"
                severity: "fail"
                message: $"($name): check_method=github-releases requires pinned_tag"
            })
        }
    }
    if $check_method == "docker-hub" {
        if "docker_image" not-in $cols {
            $findings = ($findings | append {
                rule: "b4_conditional"
                severity: "fail"
                message: $"($name): check_method=docker-hub requires docker_image"
            })
        }
        if "pinned_tag" not-in $cols {
            $findings = ($findings | append {
                rule: "b4_conditional"
                severity: "fail"
                message: $"($name): check_method=docker-hub requires pinned_tag"
            })
        }
    }

    # policy=intentional-pin requires notes explaining why — same convention
    # as sources.toml's check_method=none requiring notes (claude-skills-180).
    if $policy == "intentional-pin" {
        let notes = ($entry.notes? | default "")
        if ($notes | is-empty) {
            $findings = ($findings | append {
                rule: "b4_intentional_pin_notes"
                severity: "fail"
                message: $"($name): policy=intentional-pin requires notes stating why this literal is exempt from the EOL check"
            })
        }
    }

    # C-group: registry <-> doc content agreement. $doc_content is null when
    # the caller couldn't read `file` (missing/unreadable) — reported
    # separately by the caller as c1_file_missing, not duplicated here.
    if $doc_content != null and ("literal" in $cols) {
        let literal = ($entry.literal? | default "")
        if ($literal | is-not-empty) and not ($doc_content | str contains $literal) {
            $findings = ($findings | append {
                rule: "c1_literal_drift"
                severity: "fail"
                message: $"($name): literal '($literal)' no longer appears in the file — doc changed without the registry being updated, or the registry has a typo"
            })
        }
    }

    $findings
}

def run-self-test [] {
    let cases = [
        {
            label: "clean github-releases entry, literal present in content"
            entry: {file: "x.md" literal: "v1.0.0" check_method: "github-releases" github_repo: "o/r" pinned_tag: "v1.0.0" policy: "track"}
            content: "some doc text mentioning v1.0.0 inline"
            want: []
        }
        {
            label: "clean docker-hub entry"
            entry: {file: "x.md" literal: "alpine:3.24" check_method: "docker-hub" docker_image: "library/alpine" pinned_tag: "3.24" policy: "track"}
            content: "FROM alpine:3.24"
            want: []
        }
        {
            label: "clean manual entry"
            entry: {file: "x.md" literal: "zig@0.16.0" check_method: "manual" policy: "track"}
            content: "mise use zig@0.16.0"
            want: []
        }
        {
            label: "clean intentional-pin with notes"
            entry: {file: "x.md" literal: "node:16-buster-slim" check_method: "docker-hub" docker_image: "library/node" pinned_tag: "16-buster-slim" policy: "intentional-pin" notes: "upstream-documented default"}
            content: "node:16-buster-slim"
            want: []
        }
        {
            label: "unknown key rejected"
            entry: {file: "x.md" literal: "v1.0.0" check_method: "manual" policy: "track" bogus_field: "x"}
            content: "v1.0.0"
            want: ["b1_unknown_key"]
        }
        {
            label: "missing required key"
            entry: {literal: "v1.0.0" check_method: "manual" policy: "track"}
            content: "v1.0.0"
            want: ["b1_missing_key"]
        }
        {
            label: "bad check_method enum"
            entry: {file: "x.md" literal: "v1.0.0" check_method: "npm-typo" policy: "track"}
            content: "v1.0.0"
            want: ["b2_enum"]
        }
        {
            label: "bad policy enum"
            entry: {file: "x.md" literal: "v1.0.0" check_method: "manual" policy: "sometimes"}
            content: "v1.0.0"
            want: ["b2_enum"]
        }
        {
            label: "github-releases missing github_repo and pinned_tag"
            entry: {file: "x.md" literal: "v1.0.0" check_method: "github-releases" policy: "track"}
            content: "v1.0.0"
            want: ["b4_conditional" "b4_conditional"]
        }
        {
            label: "docker-hub missing docker_image and pinned_tag"
            entry: {file: "x.md" literal: "v1.0.0" check_method: "docker-hub" policy: "track"}
            content: "v1.0.0"
            want: ["b4_conditional" "b4_conditional"]
        }
        {
            label: "intentional-pin without notes"
            entry: {file: "x.md" literal: "v1.0.0" check_method: "manual" policy: "intentional-pin"}
            content: "v1.0.0"
            want: ["b4_intentional_pin_notes"]
        }
        {
            label: "literal drift — doc no longer contains the pinned literal"
            entry: {file: "x.md" literal: "v1.0.0" check_method: "manual" policy: "track"}
            content: "this doc now says v2.0.0 instead"
            want: ["c1_literal_drift"]
        }
        {
            label: "null doc content (file unreadable) does not double-report — caller handles c1_file_missing separately"
            entry: {file: "x.md" literal: "v1.0.0" check_method: "manual" policy: "track"}
            content: null
            want: []
        }
    ]

    mut failed = false
    for c in $cases {
        let got = (
            check-entry $c.entry $c.content
            | get rule
            | sort
        )
        let want = ($c.want | sort)
        if $got != $want {
            print $"(ansi red_bold)❌ ($c.label): want ($want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    if $failed { exit 1 }
    print $"(ansi green_bold)✅ fenced-literals self-test passed \(($cases | length) cases\)(ansi reset)"
    exit 0
}

def main [--self-test] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    cd $repo_root

    if $self_test {
        run-self-test
        return
    }

    let toml_path = ($repo_root | path join "plugins" "tools" "claude-code" "skills" "skill-update" "fenced-literals.toml")
    if not ($toml_path | path exists) {
        print $"(ansi yellow)No fenced-literals.toml found — nothing to validate.(ansi reset)"
        exit 0
    }

    let parsed = (try { open $toml_path } catch {|e| print $"(ansi red_bold)❌ fenced-literals.toml does not parse: ($e.msg)(ansi reset)"; exit 1 })
    let entries = ($parsed | get -o literals | default [])

    mut findings = []
    for entry in $entries {
        let name = ($entry.file? | default "unnamed")
        let file_path = ($repo_root | path join ($entry.file? | default ""))
        let content = if ($entry.file? | default "" | is-empty) or not ($file_path | path exists) {
            $findings = ($findings | append {
                rule: "c1_file_missing"
                severity: "fail"
                message: $"($name): file does not exist at ($file_path)"
            })
            null
        } else {
            open --raw $file_path
        }
        $findings = ($findings | append (check-entry $entry $content))
    }

    let fail_findings = ($findings | where severity == "fail")
    if ($fail_findings | is-not-empty) {
        print $"(ansi red_bold)❌ ($fail_findings | length) finding\(s\):(ansi reset)\n"
        print ($fail_findings | select rule message | table --expand)
        exit 1
    }

    print $"(ansi green_bold)✅ fenced-literals.toml validation clean \(($entries | length) entries validated\)(ansi reset)"
    exit 0
}
