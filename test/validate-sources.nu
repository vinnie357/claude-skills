#!/usr/bin/env nu

# sources.toml schema and three-way agreement validator (claude-skills-181).
#
# Validates, per plugin that has a skills/sources.toml:
#   A-group: plugin.json <-> sources.toml agreement (coverage, phantom names,
#            meta.plugin identity, review-pending drift)
#   B-group: internal sources.toml schema (required/unknown keys, enums,
#            dates, conditional fields, skills list shape)
#   C-group: sources.toml <-> sources.md agreement (index exists, every
#            entry is mentioned, no stale '- **Version**:' bullet)
#
# MISSING sources.toml is reported, not failed — this is the PR1..PR3
# migration rollout lever (claude-skills-180). PR4 flips it to a failure
# once every plugin has been converted.
#
# Zero network calls. Reads only the working tree.
#
# Usage:
#   nu test/validate-sources.nu              # scan all local plugins
#   nu test/validate-sources.nu --self-test  # verify the rules themselves

const META_KEYS = ["plugin" "reviewed_at_plugin_version" "last_full_check"]
const ENTRY_KEYS = [
    "skills" "name" "url" "releases_url" "check_method"
    "github_repo" "hex_package" "crate_name"
    "current_version" "version_constraint" "last_checked"
    "update_priority" "breaking_changes_likely" "notes"
]
const CHECK_METHODS = ["github-releases" "hex-pm" "crates-io" "manual" "none"]
const VERSION_CONSTRAINTS = ["pre-1.0" "semver" "rolling" "stable"]
const UPDATE_PRIORITIES = ["high" "medium" "low"]
# Required on every entry regardless of check_method.
const ENTRY_REQUIRED_ALWAYS = ["skills" "name" "check_method" "last_checked"]
# Additionally required when check_method != "none"; forbidden when it IS "none".
const ENTRY_NETWORK_KEYS = ["url" "current_version" "version_constraint" "update_priority"]
# Forbidden when check_method = "none" (network keys plus the ID fields and releases_url).
const NONE_FORBIDDEN = ["url" "releases_url" "current_version" "version_constraint"
                        "update_priority" "github_repo" "hex_package" "crate_name"]
const DATE_RE = '^\d{4}-\d{2}-\d{2}$'
const SEMVER_RE = '^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$'

# Returns [{rule, severity, message}] for ONE plugin. severity is "fail" or
# "info"; main exits 1 only on "fail". Pure: no filesystem, no network —
# every input is an argument, so the self-test feeds literal TOML through
# `from toml`.
#   plugin      - plugin.json `name`
#   version     - plugin.json `version`
#   skill_dirs  - skill directory basenames from plugin.json
#   parsed      - the `open`ed / `from toml`ed sources.toml as a record
#   md          - sources.md content, or null when the file is missing
def check-sources [
    plugin: string
    version: string
    skill_dirs: list<string>
    parsed: record
    md: any
]: nothing -> list {
    mut findings = []

    # A-F4 guard 1: [meta] table absent entirely.
    let meta = ($parsed | get -o meta)
    if $meta == null {
        $findings = ($findings | append {
            rule: "b1_meta_missing"
            severity: "fail"
            message: $"($plugin): sources.toml missing required table '[meta]'"
        })
    } else {
        let meta_cols = ($meta | columns)

        for k in $META_KEYS {
            if ($meta | get -o $k) == null {
                $findings = ($findings | append {
                    rule: "b1_meta_missing"
                    severity: "fail"
                    message: $"($plugin): sources.toml [meta] missing required key '($k)'"
                })
            }
        }
        for k in $meta_cols {
            if $k not-in $META_KEYS {
                $findings = ($findings | append {
                    rule: "b1_meta_unknown"
                    severity: "fail"
                    message: $"($plugin): sources.toml [meta] unknown key '($k)' — allowed: plugin, reviewed_at_plugin_version, last_full_check"
                })
            }
        }

        # A1: meta.plugin must equal plugin.json name.
        if "plugin" in $meta_cols {
            let meta_plugin = $meta.plugin
            if $meta_plugin != $plugin {
                $findings = ($findings | append {
                    rule: "a1_meta_plugin"
                    severity: "fail"
                    message: $"($plugin): sources.toml meta.plugin '($meta_plugin)' != plugin.json name '($plugin)'"
                })
            }
        }

        # A4: review-pending drift is informational, never a failure.
        if "reviewed_at_plugin_version" in $meta_cols {
            let reviewed_at = ($meta.reviewed_at_plugin_version | into string)
            if $reviewed_at != $version {
                $findings = ($findings | append {
                    rule: "a4_review_pending"
                    severity: "info"
                    message: $"($plugin): sources reviewed at plugin version ($reviewed_at), plugin.json is now ($version) — review pending"
                })
            }
            if not ($reviewed_at == "unknown" or ($reviewed_at =~ $SEMVER_RE)) {
                $findings = ($findings | append {
                    rule: "b3_semver"
                    severity: "fail"
                    message: $"($plugin): meta.reviewed_at_plugin_version '($reviewed_at)' is neither semver nor 'unknown'"
                })
            }
        }

        if "last_full_check" in $meta_cols {
            let lfc = ($meta.last_full_check | into string)
            if not ($lfc == "unknown" or ($lfc =~ $DATE_RE)) {
                $findings = ($findings | append {
                    rule: "b3_date"
                    severity: "fail"
                    message: $"($plugin)/meta: last_full_check '($lfc)' is neither YYYY-MM-DD nor 'unknown'"
                })
            }
        }
    }

    # A-F4 guard 2: [[sources]] absent entirely (same shape of failure).
    let sources = ($parsed | get -o sources)
    if $sources == null or ($sources | is-empty) {
        $findings = ($findings | append {
            rule: "b1_entry_missing"
            severity: "fail"
            message: $"($plugin): sources.toml has no [[sources]] entries"
        })
    } else {
        # A-F2: the coverage union MUST be per-record — `$sources | get skills`
        # hard-errors when any entry lacks the column (table-intersection trap).
        # A malformed (non-list) `skills` value contributes nothing here —
        # b5_skills_not_list is what flags it; treating a scalar string as a
        # one-element list would let it masquerade as real coverage/phantom
        # data.
        let covered = ($sources | each {|s|
            let v = ($s.skills? | default [])
            if ($v | describe | str starts-with "list") { $v } else { [] }
        } | flatten | uniq)

        let uncovered = ($skill_dirs | where {|d| $d not-in $covered})
        if ($uncovered | is-not-empty) {
            $findings = ($findings | append {
                rule: "a2_uncovered"
                severity: "fail"
                message: $"($plugin): skills with no sources entry: [($uncovered | str join ', ')] — add them to an existing entry's skills list, or add a check_method=\"none\" entry"
            })
        }
        let phantom = ($covered | where {|s| $s not-in $skill_dirs})
        if ($phantom | is-not-empty) {
            $findings = ($findings | append {
                rule: "a3_phantom"
                severity: "fail"
                message: $"($plugin): sources.toml names unknown skills: [($phantom | str join ', ')] \(not in plugin.json skills\)"
            })
        }

        # B-group + entry-scoped C2: iterate per-record, never via table
        # column projection (`describe`/`get` on the whole table only see the
        # column INTERSECTION across heterogeneous entries).
        for entry in $sources {
            let cols = ($entry | columns)
            let name = ($entry.name? | default "unnamed")

            for k in $cols {
                if $k not-in $ENTRY_KEYS {
                    $findings = ($findings | append {
                        rule: "b1_entry_unknown"
                        severity: "fail"
                        message: $"($plugin)/($name): unknown key '($k)' — did you mean one of: skills, name, url, ..."
                    })
                }
            }

            let check_method = ($entry.check_method? | default "")
            let is_none = ($check_method == "none")

            for k in $ENTRY_REQUIRED_ALWAYS {
                if $k not-in $cols {
                    $findings = ($findings | append {
                        rule: "b1_entry_missing"
                        severity: "fail"
                        message: $"($plugin)/($name): missing required key '($k)'"
                    })
                }
            }

            if $is_none {
                let notes = ($entry.notes? | default "")
                if ($notes | is-empty) {
                    $findings = ($findings | append {
                        rule: "b4_none_notes"
                        severity: "fail"
                        message: $"($plugin)/($name): check_method=none requires notes stating why there is no upstream"
                    })
                }
                for k in $NONE_FORBIDDEN {
                    if $k in $cols {
                        $findings = ($findings | append {
                            rule: "b4_none_forbidden"
                            severity: "fail"
                            message: $"($plugin)/($name): check_method=none forbids '($k)' — an entry with no upstream has no url or version"
                        })
                    }
                }
            } else {
                for k in $ENTRY_NETWORK_KEYS {
                    if $k not-in $cols {
                        $findings = ($findings | append {
                            rule: "b1_entry_missing"
                            severity: "fail"
                            message: $"($plugin)/($name): missing required key '($k)'"
                        })
                    }
                }
            }

            if "skills" in $cols {
                let sv = $entry.skills
                let is_list = ($sv | describe | str starts-with "list")
                if not $is_list or ($sv | is-empty) {
                    $findings = ($findings | append {
                        rule: "b5_skills_not_list"
                        severity: "fail"
                        message: $"($plugin)/($name): skills must be a non-empty list of skill directory names \(got ($sv | describe)\)"
                    })
                }
            }

            if "check_method" in $cols and ($check_method not-in $CHECK_METHODS) {
                $findings = ($findings | append {
                    rule: "b2_enum"
                    severity: "fail"
                    message: $"($plugin)/($name): check_method '($check_method)' not one of github-releases|hex-pm|crates-io|manual|none"
                })
            }
            if "version_constraint" in $cols {
                let vc = ($entry.version_constraint | into string)
                if $vc not-in $VERSION_CONSTRAINTS {
                    $findings = ($findings | append {
                        rule: "b2_enum"
                        severity: "fail"
                        message: $"($plugin)/($name): version_constraint '($vc)' not one of pre-1.0|semver|rolling|stable"
                    })
                }
            }
            if "update_priority" in $cols {
                let up = ($entry.update_priority | into string)
                if $up not-in $UPDATE_PRIORITIES {
                    $findings = ($findings | append {
                        rule: "b2_enum"
                        severity: "fail"
                        message: $"($plugin)/($name): update_priority '($up)' not one of high|medium|low"
                    })
                }
            }

            if "last_checked" in $cols {
                let lc = ($entry.last_checked | into string)
                if not ($lc == "unknown" or ($lc =~ $DATE_RE)) {
                    $findings = ($findings | append {
                        rule: "b3_date"
                        severity: "fail"
                        message: $"($plugin)/($name): last_checked '($lc)' is neither YYYY-MM-DD nor 'unknown'"
                    })
                }
            }

            # b4_conditional — required-WHEN, one direction only (A-F1
            # BLOCKER: the reverse "forbidden under the wrong check_method"
            # clause is dropped; zig legitimately carries github_repo next to
            # check_method = "manual" because the notes field explains WHY
            # github-releases is unusable, and the repo identity is still
            # real, informative data).
            if $check_method == "github-releases" and ("github_repo" not-in $cols) {
                $findings = ($findings | append {
                    rule: "b4_conditional"
                    severity: "fail"
                    message: $"($plugin)/($name): check_method=github-releases requires github_repo"
                })
            }
            if $check_method == "hex-pm" and ("hex_package" not-in $cols) {
                $findings = ($findings | append {
                    rule: "b4_conditional"
                    severity: "fail"
                    message: $"($plugin)/($name): check_method=hex-pm requires hex_package"
                })
            }
            if $check_method == "crates-io" and ("crate_name" not-in $cols) {
                $findings = ($findings | append {
                    rule: "b4_conditional"
                    severity: "fail"
                    message: $"($plugin)/($name): check_method=crates-io requires crate_name"
                })
            }
        }
    }

    # C-group. A-F4 guard 4: md == null skips C2/C3 entirely rather than
    # crashing `str downcase` on a null.
    if $md == null {
        $findings = ($findings | append {
            rule: "c1_md_missing"
            severity: "fail"
            message: $"($plugin): skills/sources.md missing — sources.toml requires its narrative index"
        })
    } else {
        let md_lower = ($md | str downcase)
        if $sources != null {
            for entry in $sources {
                let name = ($entry.name? | default "")
                if ($name | is-not-empty) and not ($md_lower | str contains ($name | str downcase)) {
                    $findings = ($findings | append {
                        rule: "c2_md_no_mention"
                        severity: "fail"
                        message: $"($plugin): sources.md does not mention entry '($name)' — the index must cover every sources.toml entry"
                    })
                }
            }
        }
        let has_version_bullet = ($md | lines | any {|l| $l =~ '^\s*-\s*\*\*Version\*\*:' })
        if $has_version_bullet {
            $findings = ($findings | append {
                rule: "c3_md_version_bullet"
                severity: "fail"
                message: $"($plugin): sources.md carries a '- **Version**:' bullet — the plugin version at last review lives in sources.toml [meta].reviewed_at_plugin_version"
            })
        }
    }

    $findings
}

def main [--self-test] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    cd $repo_root

    if $self_test {
        run-self-test
        return
    }

    let marketplace = (open ($repo_root | path join ".claude-plugin" "marketplace.json"))

    mut plugins = []
    for p in $marketplace.plugins {
        if (($p.source | describe) | str starts-with "record") { continue }
        if ($p.name == "all-skills") { continue }
        let plugin_dir = ($repo_root | path join ($p.source | str replace --regex '^\./' ''))
        if not (($plugin_dir | path join ".claude-plugin" "plugin.json") | path exists) { continue }
        $plugins = ($plugins | append {name: $p.name, dir: $plugin_dir})
    }

    print $"🔍 Validating sources.toml across ($plugins | length) plugins...\n"

    mut findings = []
    mut pending = []
    mut validated = 0

    for pl in $plugins {
        let toml_path = ($pl.dir | path join "skills" "sources.toml")
        if not ($toml_path | path exists) {
            $pending = ($pending | append $pl.name)
            continue
        }

        let parsed = (try { open $toml_path } catch {|err| null })
        if $parsed == null {
            $findings = ($findings | append {
                rule: "parse_error"
                severity: "fail"
                message: $"($pl.name): sources.toml does not parse as TOML: (try { open $toml_path } catch {|e| $e.msg })"
            })
            continue
        }

        let plugin_json = (open ($pl.dir | path join ".claude-plugin" "plugin.json"))
        let skill_paths = ($plugin_json | get -o skills | default [])
        let skill_dirs = ($skill_paths | each {|p| $p | str replace --regex '^\./' '' | path basename})

        let md_path = ($pl.dir | path join "skills" "sources.md")
        let md = if ($md_path | path exists) { open --raw $md_path } else { null }

        let plugin_findings = (check-sources $plugin_json.name $plugin_json.version $skill_dirs $parsed $md)
        $findings = ($findings | append $plugin_findings)
        $validated = $validated + 1
    }

    if ($pending | is-not-empty) {
        print $"  ⚪ ($pending | length) plugin\(s\) without sources.toml — migration pending \(claude-skills-180\):"
        print $"     ($pending | sort | str join ', ')\n"
    }

    let info_findings = ($findings | where severity == "info")
    for f in $info_findings {
        print $"  ℹ  ($f.message)"
    }
    if ($info_findings | is-not-empty) { print "" }

    let fail_findings = ($findings | where severity == "fail")
    if ($fail_findings | is-not-empty) {
        print $"(ansi red_bold)❌ ($fail_findings | length) finding\(s\):(ansi reset)\n"
        print ($fail_findings | select rule message | table --expand)
        print ""
        print "Fix guidance:"
        print "  • schema reference: plugins/tools/claude-code/skills/skill-update/templates/sources.toml"
        print "  • skills = [...] is a non-empty LIST of skill directory names from plugin.json"
        print "  • check_method = \"none\" is for skills with no external upstream: notes required, url/version forbidden"
        exit 1
    }

    print $"(ansi green_bold)✅ sources.toml validation clean \(($validated) file\(s\) validated, ($pending | length) pending\)(ansi reset)"
    exit 0
}

# Case-table self-test, following the house pattern (run-frontmatter-schema-
# self-test in test/validate-skills-quality.nu): records with named fields
# rather than positional tuples, one `got != want` comparison per case.
def run-self-test [] {
    let cases = [
        # ---- positive, want [] --------------------------------------------
        {
            label: "clean github-releases entry with full coverage"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "github-releases"
github_repo = "owner/repo"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: []
        }
        {
            label: "clean none entry with notes and last_checked"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "internal-doctrine"
check_method = "none"
last_checked = "2026-01-01"
notes = "first-party doctrine"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "internal-doctrine is documented here"
            want: []
        }
        {
            label: "last_checked = unknown"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "unknown"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: []
        }
        {
            label: "reviewed_at_plugin_version = unknown"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "unknown"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: []
        }
        {
            label: "the zig shape - one entry whose skills covers 7 dirs"
            toml: '
[meta]
plugin = "zig"
reviewed_at_plugin_version = "0.1.2"
last_full_check = "2026-06-12"
[[sources]]
skills = ["zig", "language", "build", "allocators", "testing", "c-interop", "troubleshooting"]
name = "zig"
url = "https://ziglang.org"
check_method = "manual"
github_repo = "ziglang/zig"
current_version = "0.16.0"
version_constraint = "pre-1.0"
last_checked = "2026-06-12"
update_priority = "medium"
'
            dirs: ["zig", "language", "build", "allocators", "testing", "c-interop", "troubleshooting"]
            plugin: "zig"
            version: "0.1.2"
            md: "zig is documented here"
            want: []
        }
        {
            label: "manual entry carrying all four network keys and no ID field"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: []
        }
        # ---- negative -------------------------------------------------------
        {
            label: "[meta] missing reviewed_at_plugin_version"
            toml: '
[meta]
plugin = "demo"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b1_meta_missing"]
        }
        {
            label: "[meta] with generated_at"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
generated_at = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b1_meta_unknown"]
        }
        {
            label: "entry with surprise_field"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
surprise_field = "x"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b1_entry_unknown"]
        }
        {
            label: "scalar skill = x (A-F3: dirs explicit empty so a2 does not also fire)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skill = "x"
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: []
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b1_entry_missing" "b1_entry_unknown"]
        }
        {
            label: "skills = x (scalar string, not a list)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = "x"
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: []
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b5_skills_not_list"]
        }
        {
            label: "skills = []"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = []
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: []
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b5_skills_not_list"]
        }
        {
            label: "check_method = githubreleases (typo)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "githubreleases"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b2_enum"]
        }
        {
            label: "version_constraint = calver"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "calver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b2_enum"]
        }
        {
            label: "update_priority = normal (guards the exact bad value sources-init used to emit)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "normal"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b2_enum"]
        }
        {
            label: "last_checked = 6/12/2026 (not YYYY-MM-DD)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "6/12/2026"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_date"]
        }
        {
            label: "reviewed_at_plugin_version = v0.1.2 (not semver)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "v0.1.2"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "v0.1.2"
            md: "demo-source is documented here"
            want: ["b3_semver"]
        }
        {
            label: "github-releases without github_repo"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "github-releases"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b4_conditional"]
        }
        {
            label: "hex-pm without hex_package"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "hex-pm"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b4_conditional"]
        }
        {
            label: "crates-io without crate_name"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "crates-io"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b4_conditional"]
        }
        {
            label: "github_repo present with check_method=manual (A-F1: legal, not an error)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
github_repo = "owner/repo"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: []
        }
        {
            label: "check_method=none carrying url"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "internal-doctrine"
check_method = "none"
last_checked = "2026-01-01"
notes = "first-party doctrine"
url = "https://example.com"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "internal-doctrine is documented here"
            want: ["b4_none_forbidden"]
        }
        {
            label: "check_method=none carrying current_version"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "internal-doctrine"
check_method = "none"
last_checked = "2026-01-01"
notes = "first-party doctrine"
current_version = "1.0.0"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "internal-doctrine is documented here"
            want: ["b4_none_forbidden"]
        }
        {
            label: "check_method=none with no notes"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "internal-doctrine"
check_method = "none"
last_checked = "2026-01-01"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "internal-doctrine is documented here"
            want: ["b4_none_notes"]
        }
        {
            label: "manual entry missing current_version"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b1_entry_missing"]
        }
        {
            label: "dirs entry covered by no skills list"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a" "b"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["a2_uncovered"]
        }
        {
            label: "skills naming a dir not in dirs"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a", "ghost"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["a3_phantom"]
        }
        {
            label: "meta.plugin = core while plugin = zig"
            toml: '
[meta]
plugin = "core"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "zig"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["a1_meta_plugin"]
        }
        {
            label: "md = null (A-F4: must not crash)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: null
            want: ["c1_md_missing"]
        }
        {
            label: "entry name absent from md"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "nothing relevant here"
            want: ["c2_md_no_mention"]
        }
        {
            label: "md containing - **Version**: 0.1.0"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here\n- **Version**: 0.1.0\n"
            want: ["c3_md_version_bullet"]
        }
        # ---- A-F4 crash-vector guards ---------------------------------------
        {
            label: "A-F4.1: [meta] absent entirely"
            toml: '
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b1_meta_missing"]
        }
        {
            label: "A-F4.2: no [[sources]] at all"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "nothing relevant here"
            want: ["b1_entry_missing"]
        }
        {
            label: "A-F4.3: TOML-native unquoted date must not crash =~"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = 2026-06-12
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_date"]
        }
    ]

    mut failed = false
    for c in $cases {
        let parsed = ($c.toml | from toml)
        let got = (
            check-sources $c.plugin $c.version $c.dirs $parsed $c.md
            | where severity == "fail"
            | get rule
            | sort
            | uniq
        )
        let want = ($c.want | sort)
        if $got != $want {
            print $"(ansi red_bold)❌ ($c.label): want ($want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    # Separately: the a4_review_pending severity assertion — exactly one
    # info finding, zero fail findings, proving drift REPORTS rather than
    # FAILS.
    let severity_parsed = ('
[meta]
plugin = "demo"
reviewed_at_plugin_version = "0.1.2"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
' | from toml)
    let severity_findings = (check-sources "demo" "0.1.5" ["a"] $severity_parsed "demo-source is documented here")
    let severity_fail = ($severity_findings | where severity == "fail")
    let severity_info = ($severity_findings | where severity == "info")
    if ($severity_fail | is-not-empty) or ($severity_info | length) != 1 or ($severity_info | first | get rule) != "a4_review_pending" {
        print $"(ansi red_bold)❌ a4_review_pending severity case: expected exactly one info finding (a4_review_pending) and zero fail findings, got ($severity_findings | to nuon)(ansi reset)"
        $failed = true
    }

    if $failed { exit 1 }
    print $"(ansi green_bold)✅ sources self-test passed \(($cases | length) cases\)(ansi reset)"
    exit 0
}
