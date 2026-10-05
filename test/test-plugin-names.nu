#!/usr/bin/env nu

# Tests for the offline reserved plugin name check
# (test/plugin-names.nu and test/validate-plugin-names.nu).
#
# Rule source: the `name` field of the plugin manifest reference at
# https://code.claude.com/docs/en/plugins/manifest-reference. Ground-truth
# verdicts below were measured with `claude plugin validate` (claude 2.1.287).
#
# Usage:
#   nu test/test-plugin-names.nu

use plugin-names.nu *

const TEST_DIR = (path self | path dirname)

const ERROR_NAMES = [
    claude claude-code claude-mods anthropic anthropics Claude-Code CLAUDE
    claude--code claude_code claude.code claude-tools anthropic-tools
    anthropics-x cc-plugin-x official-claude claude-official official-anthropic
    anthropic-official officialclaude claude-for-x claude_ claude-code-tools
    claude-codex official--claude cc--plugin-x cc__plugin__x claude-.-code
    Claude--Code-Tools Official-Claude Anthropic-Tools
]
const WARNING_NAMES = [
    extras-claude-code my-claude my-claude-tools mcp-for-claude
    tool-anthropic-x official-plugin-claude my-anthropics-tool my--claude
    My-Claude MY-ANTHROPICS-TOOL Official_Plugin-Claude Mcp-For-Claude
]
const OK_NAMES = [
    extras-cc extras anthropicx claudex cc-tools cc-plugin official-tools
]

# One result record per assertion; the script exits once, at the end.
def result [label: string, ok: bool, detail: string = ""]: nothing -> record {
    {label: $label, ok: $ok, detail: $detail}
}

def check-eq [label: string, got: any, want: any]: nothing -> record {
    if $got == $want {
        result $label true
    } else {
        result $label false $"want ($want | to nuon), got ($got | to nuon)"
    }
}

# Runs a closure returning a list of results; a thrown error becomes one failure.
def guarded [label: string, body: closure]: nothing -> list {
    try { do $body } catch { |e| [(result $label false $"raised: ($e.msg)")] }
}

def verdict-cases [names: list<string>, level: string]: nothing -> list {
    $names | each { |n|
        guarded $"verdict ($n) is ($level)" {
            let v = (reserved-name-verdict $n)
            let level_res = (check-eq $"verdict ($n) level" $v.level $level)
            let reason_ok = if $level == "ok" {
                $v.reason == ""
            } else {
                ($v.reason | describe) == "string" and ($v.reason | str length) > 0
            }
            [$level_res (result $"verdict ($n) reason shape" $reason_ok $"reason=($v.reason | to nuon)")]
        }
    } | flatten
}

def new-tree [tag: string]: nothing -> string {
    let cols = ($nu | columns)
    let base = if "temp-dir" in $cols { $nu | get temp-dir } else { $nu | get temp-path }
    let root = ($base | path join $"plugin-names-($tag)-(random uuid)")
    mkdir ($root | path join ".claude-plugin")
    $root
}

def write-json [path: string, value: any]: nothing -> nothing {
    mkdir ($path | path dirname)
    $value | to json | save --force $path
}

def write-marketplace [root: string, names: list<string>]: nothing -> nothing {
    write-json ($root | path join ".claude-plugin" "marketplace.json") {
        name: "fixture-marketplace"
        plugins: ($names | each { |n| {name: $n, source: $"./plugins/($n)"} })
    }
}

def write-root-plugin [root: string, name: string]: nothing -> nothing {
    write-json ($root | path join ".claude-plugin" "plugin.json") {name: $name, version: "0.0.1"}
}

def write-nested-plugin [root: string, rel_dir: string, name: string]: nothing -> nothing {
    write-json ($root | path join $rel_dir ".claude-plugin" "plugin.json") {name: $name, version: "0.0.1"}
}

def scan-cases []: nothing -> list {
    mut out = []

    # clean tree
    let clean = (new-tree clean)
    write-marketplace $clean [extras-cc cc-tools]
    write-root-plugin $clean all-skills
    write-nested-plugin $clean plugins/tools/extras-cc extras-cc
    $out = ($out | append (guarded "scan clean tree" {
        [(check-eq "scan clean tree is empty" (scan-manifests $clean) [])]
    }))

    # error tree: marketplace entry and plugin.json both claude-code
    let bad = (new-tree bad)
    write-marketplace $bad [claude-code]
    write-nested-plugin $bad plugins/tools/claude-code claude-code
    $out = ($out | append (guarded "scan error tree" {
        let got = (scan-manifests $bad | sort-by file)
        let files = ($got | get file)
        [
            (check-eq "error tree finding count" ($got | length) 2)
            (check-eq "error tree files" $files [
                ".claude-plugin/marketplace.json"
                "plugins/tools/claude-code/.claude-plugin/plugin.json"
            ])
            (check-eq "error tree names" ($got | get name | uniq) [claude-code])
            (check-eq "error tree levels" ($got | get level | uniq) [error])
            (result "error tree reasons non-empty" ($got | all { |r| ($r.reason | str length) > 0 }))
        ]
    }))

    # warning-only tree
    let warn = (new-tree warn)
    write-marketplace $warn [my-claude extras-cc]
    write-nested-plugin $warn plugins/x/my-claude my-claude
    $out = ($out | append (guarded "scan warning tree" {
        let got = (scan-manifests $warn)
        [
            (check-eq "warning tree finding count" ($got | length) 2)
            (check-eq "warning tree levels" ($got | get level | uniq) [warning])
            (check-eq "warning tree names" ($got | get name | uniq) [my-claude])
        ]
    }))

    # plugin.json under plugins/a/b/.claude-plugin/ is found
    let nested = (new-tree nested)
    write-marketplace $nested []
    write-nested-plugin $nested plugins/a/b claude-tools
    $out = ($out | append (guarded "scan nested plugin.json" {
        let got = (scan-manifests $nested)
        [
            (check-eq "nested finding count" ($got | length) 1)
            (check-eq "nested file" ($got | get file) ["plugins/a/b/.claude-plugin/plugin.json"])
            (check-eq "nested level" ($got | get level) [error])
        ]
    }))

    # root plugin.json is checked when present
    let rootp = (new-tree rootp)
    write-marketplace $rootp []
    write-root-plugin $rootp claude-code
    $out = ($out | append (guarded "scan root plugin.json" {
        let got = (scan-manifests $rootp)
        [
            (check-eq "root plugin finding files" ($got | get file) [".claude-plugin/plugin.json"])
        ]
    }))

    # missing root plugin.json is tolerated
    let noroot = (new-tree noroot)
    write-marketplace $noroot [extras]
    $out = ($out | append (guarded "scan missing root plugin.json" {
        [(check-eq "missing root plugin.json tolerated" (scan-manifests $noroot) [])]
    }))

    # the marketplace's own top-level name is not checked
    let topname = (new-tree topname)
    write-json ($topname | path join ".claude-plugin" "marketplace.json") {name: "claude-code", plugins: []}
    $out = ($out | append (guarded "scan ignores marketplace top-level name" {
        [(check-eq "marketplace top-level name ignored" (scan-manifests $topname) [])]
    }))

    # depth-1 plugin.json (plugins/<name>/.claude-plugin/plugin.json)
    let shallow_err = (new-tree shallowerr)
    write-marketplace $shallow_err []
    write-nested-plugin $shallow_err plugins/core claude-code
    $out = ($out | append (guarded "scan depth-1 error" {
        let got = (scan-manifests $shallow_err)
        [
            (check-eq "depth-1 error files" ($got | get file) ["plugins/core/.claude-plugin/plugin.json"])
            (check-eq "depth-1 error level" ($got | get level) [error])
            (check-eq "depth-1 error name" ($got | get name) [claude-code])
        ]
    }))

    let shallow_warn = (new-tree shallowwarn)
    write-marketplace $shallow_warn []
    write-nested-plugin $shallow_warn plugins/pm my-claude
    $out = ($out | append (guarded "scan depth-1 warning" {
        let got = (scan-manifests $shallow_warn)
        [
            (check-eq "depth-1 warning files" ($got | get file) ["plugins/pm/.claude-plugin/plugin.json"])
            (check-eq "depth-1 warning level" ($got | get level) [warning])
        ]
    }))

    let shallow_ok = (new-tree shallowok)
    write-marketplace $shallow_ok []
    write-nested-plugin $shallow_ok plugins/ui extras-cc
    $out = ($out | append (guarded "scan depth-1 clean" {
        [(check-eq "depth-1 clean tree is empty" (scan-manifests $shallow_ok) [])]
    }))

    # one finding at each depth: both are returned
    let mixed = (new-tree mixed)
    write-marketplace $mixed []
    write-nested-plugin $mixed plugins/core claude-code
    write-nested-plugin $mixed plugins/tools/deep claude-tools
    $out = ($out | append (guarded "scan mixed depths" {
        let got = (scan-manifests $mixed | sort-by file)
        [
            (check-eq "mixed depths files" ($got | get file) [
                "plugins/core/.claude-plugin/plugin.json"
                "plugins/tools/deep/.claude-plugin/plugin.json"
            ])
            (check-eq "mixed depths levels" ($got | get level | uniq) [error])
        ]
    }))

    for t in [$clean $bad $warn $nested $rootp $noroot $topname $shallow_err $shallow_warn $shallow_ok $mixed] { rm -rf $t }
    $out
}

# True when one output line carries every token (a per-finding line, not the counts line).
def line-has [stdout: string, tokens: list<string>]: nothing -> bool {
    $stdout | lines | any { |l|
        $tokens | all { |t| $l | str contains --ignore-case $t }
    }
}

# A reason substring that is long enough to be specific to the verdict.
def reason-token [name: string]: nothing -> string {
    (reserved-name-verdict $name).reason | split chars | first 20 | str join
}

def run-cli [root: string]: nothing -> record {
    ^nu ($TEST_DIR | path join "validate-plugin-names.nu") --root $root | complete
}

def cli-cases []: nothing -> list {
    mut out = []

    let bad = (new-tree clibad)
    write-marketplace $bad [claude-code]
    write-nested-plugin $bad plugins/tools/claude-code claude-code
    $out = ($out | append (guarded "cli error fixture" {
        let r = (run-cli $bad)
        [
            (check-eq "cli error fixture exit code" $r.exit_code 1)
            (result "cli error: marketplace finding line has file, name, level, reason" (line-has $r.stdout [".claude-plugin/marketplace.json" "claude-code" "error" (reason-token "claude-code")]) $r.stdout)
            (result "cli error: plugin.json finding line has file, name, level, reason" (line-has $r.stdout ["plugins/tools/claude-code/.claude-plugin/plugin.json" "claude-code" "error" (reason-token "claude-code")]) $r.stdout)
        ]
    }))

    let clean = (new-tree cliclean)
    write-marketplace $clean [extras-cc]
    write-nested-plugin $clean plugins/tools/extras-cc extras-cc
    $out = ($out | append (guarded "cli clean fixture" {
        let r = (run-cli $clean)
        [
            (check-eq "cli clean fixture exit code" $r.exit_code 0)
            (result "cli clean fixture prints a counts summary" ($r.stdout =~ '\d') $r.stdout)
        ]
    }))

    let warn = (new-tree cliwarn)
    write-marketplace $warn [my-claude]
    write-nested-plugin $warn plugins/x/my-claude my-claude
    $out = ($out | append (guarded "cli warning fixture" {
        let r = (run-cli $warn)
        [
            (check-eq "cli warning fixture exit code" $r.exit_code 0)
            (result "cli warning: marketplace finding line has file, name, level, reason" (line-has $r.stdout [".claude-plugin/marketplace.json" "my-claude" "warning" (reason-token "my-claude")]) $r.stdout)
            (result "cli warning: plugin.json finding line has file, name, level, reason" (line-has $r.stdout ["plugins/x/my-claude/.claude-plugin/plugin.json" "my-claude" "warning" (reason-token "my-claude")]) $r.stdout)
            (result "cli warning fixture has no error finding line" (not (line-has $r.stdout ["my-claude" "error"])) $r.stdout)
        ]
    }))

    for t in [$bad $clean $warn] { rm -rf $t }
    $out
}

# Frozen rename expectation: the shipped tree has no error-level plugin name.
def real-repo-cases []: nothing -> list {
    guarded "real repo scan" {
        let repo_root = ($TEST_DIR | path dirname)
        let errors = (scan-manifests $repo_root | where level == "error")
        [(check-eq "real repo has zero error-level plugin names" $errors [])]
    }
}

# Every real manifest path must be one scan-manifests inspects: copy each real
# plugin.json's relative path into a temp tree with its name replaced by a
# reserved name, then require an error finding for exactly that file.
def real-coverage-cases []: nothing -> list {
    guarded "real manifest coverage" {
        let repo_root = ($TEST_DIR | path dirname)
        let tracked = (
            ^git -C $repo_root ls-files 'plugins/**/.claude-plugin/plugin.json'
            | lines | where { |l| ($l | str length) > 0 } | sort
        )
        let on_disk = (
            glob $"($repo_root)/plugins/**/.claude-plugin/plugin.json"
            | each { |f| $f | path relative-to $repo_root } | sort
        )
        let tree = (new-tree coverage)
        write-marketplace $tree []
        for rel in $tracked {
            write-json ($tree | path join $rel) {name: "claude-code", version: "0.0.1"}
        }
        let found = (scan-manifests $tree | where level == "error" | get file | sort)
        rm -rf $tree
        [
            (result "real manifests exist" (($tracked | length) > 0) $"tracked=($tracked | length)")
            (check-eq "tracked manifest count equals on-disk count" ($tracked | length) ($on_disk | length))
            (check-eq "scan-manifests inspects every real manifest path" $found $tracked)
        ]
    }
}

# Harness self-checks: prove the assertion helpers can fail, so a green run is not vacuous.
def harness-cases []: nothing -> list {
    let wrong = (check-eq "deliberately wrong" "error" "ok")
    let right = (check-eq "deliberately right" "ok" "ok")
    let raised = (guarded "deliberate raise" { error make {msg: "boom"} })
    [
        (check-eq "harness reports a wrong expectation as failure" $wrong.ok false)
        (check-eq "harness reports a right expectation as success" $right.ok true)
        (check-eq "harness converts a raised error into a failure" ($raised | get ok) [false])
    ]
}

def main [] {
    let results = (
        (harness-cases)
        | append (verdict-cases $ERROR_NAMES "error")
        | append (verdict-cases $WARNING_NAMES "warning")
        | append (verdict-cases $OK_NAMES "ok")
        | append (scan-cases)
        | append (cli-cases)
        | append (real-repo-cases)
        | append (real-coverage-cases)
    )

    for r in $results {
        if $r.ok {
            print $"(ansi green)PASS(ansi reset) ($r.label)"
        } else {
            print $"(ansi red_bold)FAIL(ansi reset) ($r.label) :: ($r.detail)"
        }
    }

    let failed = ($results | where ok == false | length)
    print $"\n($results | length) assertions, ($failed) failed"
    if $failed > 0 { exit 1 }
}
