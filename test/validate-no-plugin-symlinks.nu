#!/usr/bin/env nu

# No-symlinks-under-plugins/ lint (claude-skills-236).
#
# `test/validate-skills-quality.nu`'s external-content quarantine check now
# canonicalizes reference paths so a symlinked ANCESTOR directory can't be
# used to smuggle a reference outside its skill's own tree (a symlinked dir
# resolves to its real target before the containment check runs). That
# closes the read side — a symlink that WOULD have bypassed containment now
# gets caught. This lint closes the write side: no CI check previously
# forbade a symlink from landing under plugins/ at all, so the class of
# problem existed even though the specific containment bypass had a fix.
# Making symlinks unreachable under plugins/ is a stronger guarantee than
# "handled if present" — this lint fires the moment one is committed,
# instead of relying on every other check to correctly account for it.
#
# Scope is plugins/ ONLY, not repo-wide. This repo's own root-level
# AGENTS.md is a symlink to CLAUDE.md by explicit convention (see
# ~/github/CLAUDE.md's "Multi-harness note" and this repo's own CLAUDE.md
# header `@plugins/tools/claude-code/templates/CLAUDE.md`) — a blanket
# repo-wide ban would break a pattern this project already uses on purpose.
# Marketplace content (everything under plugins/) has no equivalent
# legitimate use for a symlink: skills are distributed as plugin archives/
# copies, and a symlink inside one either points outside the plugin (an
# external-content or containment risk) or points at another file inside
# the SAME plugin (better expressed as a real reference/duplication, not a
# filesystem symlink an installer may or may not preserve).
#
# templates/ exception: deliberately NOT carved out. `find plugins -type l`
# is 0 today — there is no existing shipped example that needs one, and
# adding an exception ahead of a real need is exactly what /core:restraint's
# YAGNI rung warns against. If a future skill genuinely needs to ship a
# symlink as example content, that's a decision to make explicitly when it
# happens (an allowlist entry with a reason), not a standing carve-out.
#
# Detection is via `git ls-files -s` (mode 120000 = symlink), not a
# filesystem walk — this checks what's actually TRACKED (what CI and a
# clone actually see), matching the disclosure lint's tracked-files scope,
# and sidesteps any cross-platform difference in how a live filesystem walk
# reports symlink type.
#
# Usage:
#   nu test/validate-no-plugin-symlinks.nu              # scan the real tree
#   nu test/validate-no-plugin-symlinks.nu --self-test   # verify the rule itself

const SYMLINK_MODE = "120000"

# Pure — takes already-parsed `git ls-files -s` records ({mode, path}) and
# returns the paths that are both a symlink AND under plugins/. No
# filesystem or git access, so this is fully self-testable.
def find-plugin-symlinks [entries: list]: nothing -> list {
    $entries
    | where mode == $SYMLINK_MODE
    | where { |e| $e.path | str starts-with "plugins/" }
    | get path
}

# Parses one line of `git ls-files -s` output: "<mode> <sha> <stage>\t<path>"
def parse-ls-files-line [line: string]: nothing -> record {
    let parts = ($line | split row "\t")
    let meta = ($parts | get 0 | str trim | split row " ")
    { mode: ($meta | get 0), path: ($parts | get 1) }
}

def run-self-test [] {
    let cases = [
        {
            label: "symlink under plugins/ is caught"
            entries: [{mode: "120000" path: "plugins/core/skills/git/evil.md"}]
            want: ["plugins/core/skills/git/evil.md"]
        }
        {
            label: "regular file under plugins/ is not flagged"
            entries: [{mode: "100644" path: "plugins/core/skills/git/SKILL.md"}]
            want: []
        }
        {
            label: "symlink OUTSIDE plugins/ (e.g. AGENTS.md -> CLAUDE.md) is out of scope, not flagged"
            entries: [{mode: "120000" path: "AGENTS.md"}]
            want: []
        }
        {
            label: "symlink under a templates/ dir inside plugins/ is still caught — no exception carved out"
            entries: [{mode: "120000" path: "plugins/tools/runex/skills/runex/templates/0.0.7/evil-link"}]
            want: ["plugins/tools/runex/skills/runex/templates/0.0.7/evil-link"]
        }
        {
            label: "mixed set — only the in-scope symlink is reported"
            entries: [
                {mode: "100644" path: "plugins/core/skills/git/SKILL.md"}
                {mode: "120000" path: "AGENTS.md"}
                {mode: "120000" path: "plugins/wasm/skills/wit/evil.md"}
                {mode: "100755" path: "test/validate-no-plugin-symlinks.nu"}
            ]
            want: ["plugins/wasm/skills/wit/evil.md"]
        }
        {
            label: "empty tree — nothing to report"
            entries: []
            want: []
        }
    ]

    mut failed = false
    for c in $cases {
        let got = (find-plugin-symlinks $c.entries | sort)
        let want = ($c.want | sort)
        if $got != $want {
            print $"(ansi red_bold)❌ ($c.label): want ($want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    # parse-ls-files-line: confirm real git output parses to the record
    # shape find-plugin-symlinks expects.
    let parsed = (parse-ls-files-line "120000 98e9c3c6feb601c3f8666d088fd83928497c715a 0\tplugins/core/skills/git/evil.md")
    if $parsed.mode != "120000" or $parsed.path != "plugins/core/skills/git/evil.md" {
        print $"(ansi red_bold)❌ parse-ls-files-line: got ($parsed | to nuon)(ansi reset)"
        $failed = true
    }

    if $failed { exit 1 }
    print $"(ansi green_bold)✅ no-plugin-symlinks self-test passed \(($cases | length) cases\)(ansi reset)"
    exit 0
}

def main [--self-test] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    cd $repo_root

    if $self_test {
        run-self-test
        return
    }

    let raw = (do { git ls-files -s -- plugins/ } | complete)
    if $raw.exit_code != 0 {
        print $"(ansi red_bold)❌ git ls-files failed: ($raw.stderr)(ansi reset)"
        exit 1
    }

    let entries = (
        $raw.stdout
        | lines
        | where ($it | is-not-empty)
        | each { |l| parse-ls-files-line $l }
    )

    let offenders = (find-plugin-symlinks $entries)

    if ($offenders | is-not-empty) {
        print $"(ansi red_bold)❌ ($offenders | length) symlink\(s\) tracked under plugins/ — not allowed:(ansi reset)\n"
        for p in $offenders {
            print $"  ($p)"
        }
        print $"\n(ansi yellow)Marketplace content must be real files, not symlinks — see the header comment in test/validate-no-plugin-symlinks.nu for why.(ansi reset)"
        exit 1
    }

    print $"(ansi green_bold)✅ no symlinks tracked under plugins/ \(($entries | length) tracked entries scanned\)(ansi reset)"
    exit 0
}
