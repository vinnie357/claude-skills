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
# A MISSING sources.toml is a FAILURE (claude-skills-184). It was reported
# rather than failed during the PR1..PR3 rollout, as the lever that let the
# migration land plugin-by-plugin; all 28 are converted, so the lever is
# pulled. Adding a plugin without a sources.toml now breaks the build.
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
# Shape-based (not strict semver) — accepts "unknown" as a literal, checked
# separately. See claude-skills-189: upstream version schemes are
# heterogeneous (CalVer, OTP-style, bare major/minor) and not all semver.
# claude-skills-196 (D1b): suffix class widened by one character (added the
# trailing '-') to match SEMVER_RE four lines above, which already accepts a
# hyphenated prerelease segment (e.g. "1.0.0-alpha-1"). Not a policy
# widening — this file was internally inconsistent, rejecting here what it
# already accepted there. Measured: 0 of 39 corpus values change acceptance.
# What the extra character newly admits is exactly the hyphenated-suffix
# family: the two intended forms above, plus degenerate ones like "1.0.0--"
# (which SEMVER_RE already accepts, so agreeing with it is the point) and
# "a-1-2-3" (alpha prefix plus hyphenated suffix — not a plausible typo).
# No plausible authoring mistake became acceptable. PEP 440 separator-less suffixes
# (D1a) and dual -prerelease+build suffixes (D1c) were also considered and
# rejected — see SKILL.md's field table for the reasoning.
const VERSION_SHAPE_RE = '^[A-Za-z]{0,10}[-.]?\d+(\.\d+){0,4}([-+][0-9A-Za-z.-]+)?$'

# Returns [{rule, severity, message}] for ONE plugin. severity is "fail" or
# "info"; main exits 1 only on "fail". Pure: no filesystem, no network —
# every input is an argument, so the self-test feeds literal TOML through
# `from toml`.
#   plugin      - plugin.json `name`
#   version     - plugin.json `version`
#   skill_dirs  - skill directory basenames from plugin.json
#   parsed      - the `open`ed / `from toml`ed sources.toml as a record
#   md          - sources.md content, or null when the file is missing
# claude-skills-185 round 2: `into string` maps a LIST elementwise (yielding
# list<string>, which `=~` then rejects) and throws outright on a record. Every
# scalar-expecting field goes through this so a wrong-type value REPORTS.
def scalar-str [v: any]: nothing -> any {
    let t = ($v | describe)
    if ($t == "string") {
        $v
    } else if ($t in ["int" "bool" "float" "datetime" "filesize" "duration"]) {
        $v | into string
    } else {
        null
    }
}

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
    } else if (($meta | describe --detailed | get type) != "record") {
        # claude-skills-185: a WRONG-TYPE root, e.g. `meta = "awman"`. Without
        # this arm `$meta | columns` aborts the whole scan with a raw nushell
        # error naming this file's line, not the offending plugin — so one bad
        # file hid findings in the other 27.
        $findings = ($findings | append {
            rule: "b1_meta_not_table"
            severity: "fail"
            message: $"($plugin): sources.toml 'meta' is a ($meta | describe), expected a [meta] table"
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
            let reviewed_at = (scalar-str $meta.reviewed_at_plugin_version)
            if $reviewed_at != $version {
                $findings = ($findings | append {
                    rule: "a4_review_pending"
                    severity: "info"
                    message: $"($plugin): sources reviewed at plugin version ($reviewed_at), plugin.json is now ($version) — review pending"
                })
            }
            if $reviewed_at == null {
                $findings = ($findings | append {
                    rule: "b3_semver"
                    severity: "fail"
                    message: $"($plugin): meta.reviewed_at_plugin_version is a ($meta.reviewed_at_plugin_version | describe), expected a version string or 'unknown'"
                })
            } else if not ($reviewed_at == "unknown" or ($reviewed_at =~ $SEMVER_RE)) {
                $findings = ($findings | append {
                    rule: "b3_semver"
                    severity: "fail"
                    message: $"($plugin): meta.reviewed_at_plugin_version '($reviewed_at)' is neither semver nor 'unknown'"
                })
            }
        }

        if "last_full_check" in $meta_cols {
            let lfc = (scalar-str $meta.last_full_check)
            if $lfc == null {
                $findings = ($findings | append {
                    rule: "b3_date"
                    severity: "fail"
                    message: $"($plugin): meta.last_full_check is a ($meta.last_full_check | describe), expected YYYY-MM-DD or 'unknown'"
                })
            } else if not ($lfc == "unknown" or ($lfc =~ $DATE_RE)) {
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
    if $sources == null {
        $findings = ($findings | append {
            rule: "b1_entry_missing"
            severity: "fail"
            message: $"($plugin): sources.toml has no [[sources]] entries"
        })
    } else if (($sources | describe --detailed | get type) != "list") {
        # claude-skills-185 round 2: `any` itself throws on non-list input, so
        # the previous guard aborted on exactly the inputs it meant to report.
        # `[sources]` (single brackets) parses as a RECORD and is the likeliest
        # hand-authoring mistake of this family, with 26 files still to write.
        $findings = ($findings | append {
            rule: "b1_sources_not_list"
            severity: "fail"
            message: $"($plugin): sources.toml 'sources' is a ($sources | describe), expected [[sources]] entries \(double brackets\)"
        })
    } else if ($sources | is-empty) {
        $findings = ($findings | append {
            rule: "b1_entry_missing"
            severity: "fail"
            message: $"($plugin): sources.toml has no [[sources]] entries"
        })
    } else if (($sources | any {|e| ($e | describe --detailed | get type) != "record" })) {
        # claude-skills-185: WRONG-TYPE entries, e.g. `sources = ["not-a-table"]`.
        # Without this arm the `$s.skills?` cell path aborts on a string.
        # Checked per-entry, not via `describe` on the collection: a
        # heterogeneous table reports only its column intersection.
        let bad = ($sources | enumerate | where {|r| ($r.item | describe --detailed | get type) != "record" } | get index)
        $findings = ($findings | append {
            rule: "b1_entry_not_table"
            severity: "fail"
            message: $"($plugin): sources.toml [[sources]] entries at index ($bad | str join ', ') are not tables"
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
            if (($v | describe --detailed | get type) == "list") { $v } else { [] }
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

        # claude-skills-185: duplicate entry NAMES within one plugin.
        # Two entries covering the same SKILL stays legal on purpose — a skill
        # can genuinely have several upstreams (claude-code documents 35 across
        # 12 skills). Two entries sharing a NAME is the copy-paste error, and
        # it also makes `mise sources:check` output ambiguous.
        # Deliberately not `group-by --to-table`: with a closure it emits a
        # GENERATED column name (`closure_0`), so depending on it is a silent
        # breakage waiting for a nushell version bump.
        let entry_names = ($sources | each {|s| $s.name? | default null} | compact)
        let dup_names = ($entry_names | uniq | where {|n|
            ($entry_names | where {|x| $x == $n} | length) > 1
        })
        if ($dup_names | is-not-empty) {
            $findings = ($findings | append {
                rule: "b6_duplicate_name"
                severity: "fail"
                message: $"($plugin): duplicate [[sources]] name\(s\): [($dup_names | str join ', ')] — entries may share a skill, but not a name"
            })
        }

        # B-group + entry-scoped C2: iterate per-record, never via table
        # column projection (`describe`/`get` on the whole table only see the
        # column INTERSECTION across heterogeneous entries).
        for entry in $sources {
            let cols = ($entry | columns)
            let name_raw = ($entry.name? | default "unnamed")
            let name = ((scalar-str $name_raw) | default "unnamed")

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
                let vc = (scalar-str $entry.version_constraint)
                if $vc not-in $VERSION_CONSTRAINTS {
                    $findings = ($findings | append {
                        rule: "b2_enum"
                        severity: "fail"
                        message: $"($plugin)/($name): version_constraint '($vc)' not one of pre-1.0|semver|rolling|stable"
                    })
                }
            }
            if "update_priority" in $cols {
                let up = (scalar-str $entry.update_priority)
                if $up not-in $UPDATE_PRIORITIES {
                    $findings = ($findings | append {
                        rule: "b2_enum"
                        severity: "fail"
                        message: $"($plugin)/($name): update_priority '($up)' not one of high|medium|low"
                    })
                }
            }

            if "last_checked" in $cols {
                let lc = (scalar-str $entry.last_checked)
                if $lc == null {
                    $findings = ($findings | append {
                        rule: "b3_date"
                        severity: "fail"
                        message: $"($plugin)/($name): last_checked is a ($entry.last_checked | describe), expected YYYY-MM-DD or 'unknown'"
                    })
                } else if not ($lc == "unknown" or ($lc =~ $DATE_RE)) {
                    $findings = ($findings | append {
                        rule: "b3_date"
                        severity: "fail"
                        message: $"($plugin)/($name): last_checked '($lc)' is neither YYYY-MM-DD nor 'unknown'"
                    })
                }
            }

            if "current_version" in $cols {
                let raw_t = ($entry.current_version | describe)
                if $raw_t != "string" {
                    # claude-skills-197: current_version is the ONLY scalar-str
                    # consumer whose check silently ACCEPTS a coerced numeric —
                    # an unquoted 1.10 parses as a TOML float and coerces to
                    # "1.1", a different version, with no diagnostic. Every
                    # other scalar-str field (b3_date, SEMVER_RE, the two
                    # enums) rejects a coerced numeric loudly on its own, so
                    # they need no extra type rule. Hence the divergence from
                    # the shared helper here and nowhere else. Checking the
                    # RAW type ahead of scalar-str also subsumes the old
                    # `$cv == null` wrong-type branch (list / datetime), so
                    # those cases keep landing on this same rule id. Measured:
                    # 0 corpus entries are non-string.
                    $findings = ($findings | append {
                        rule: "b3_version_shape"
                        severity: "fail"
                        message: $"($plugin)/($name): current_version is a ($raw_t), expected a QUOTED version string or 'unknown' — an unquoted numeric records a different value \(1.10 becomes 1.1\)"
                    })
                } else if not ($entry.current_version == "unknown"
                               or ($entry.current_version =~ $VERSION_SHAPE_RE)) {
                    $findings = ($findings | append {
                        rule: "b3_version_shape"
                        severity: "fail"
                        message: $"($plugin)/($name): current_version '($entry.current_version)' is neither a recognizable version string nor 'unknown'"
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
        # claude-skills-186: strip scheme-prefixed URLs before matching, so an
        # entry can no longer pass c2 solely because its name happens to sit
        # inside its own `- **URL**:` field (rig/lemonade-server was the
        # motivating case — no prose named it, only its url did). Scheme-only
        # — NOT a bare-domain strip — is deliberate: bare-domain entry names
        # (design's m3.material.io, pm's cucumber.io) are legitimate
        # identifiers and must still match when prose names them without a
        # scheme. Measured on this corpus (109 entries, 20 plugins): scheme-only
        # strips leave 0 failures, while a full bare-domain strip fails 9 — the
        # 7 pm entries (cucumber.io, spdx.org, owasp.org, ...) and 2 design
        # entries (m3.material.io, oritop.co), every one of them a legitimate
        # bare-domain name a reader would recognise. Do not "simplify" this to
        # a domain strip; it is the difference between 0 and 9.
        let md_prose = ($md_lower | str replace -a -r 'https?://[^\s)>"\]]+' '')
        # claude-skills-185 rd2: type-check here too. `$sources != null` is not
        # enough — a string root reaches `where` and throws. Third site of one
        # root cause; the guard belongs at every consumer, not just the first.
        if $sources != null and (($sources | describe --detailed | get type) == "list") {
            # claude-skills-185: filter to record entries here too. This loop
            # lives in a different scope from the b1_entry_not_table guard, so
            # guarding only the root left this site still crashing on a
            # wrong-type entry — the exact fix-one-site-leave-the-sibling
            # pattern this repo keeps hitting.
            for entry in ($sources | where {|e| ($e | describe --detailed | get type) == "record" }) {
                let name = ((scalar-str ($entry.name? | default "")) | default "")
                if ($name | is-not-empty) and not ($md_prose | str contains ($name | str downcase)) {
                    $findings = ($findings | append {
                        rule: "c2_md_no_mention"
                        severity: "fail"
                        message: $"($plugin): sources.md does not mention entry '($name)' in prose — URLs do not count; add it to the Entries: sentence"
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

# The missing-sources.toml guard, extracted so it can be self-tested
# (claude-skills-192). Takes the raw (unsorted) pending plugin-name list and
# returns one {rule, severity, message} finding per name, sorted by name to
# match main's `for name in ($pending | sort)` iteration order.
def missing-sources-findings [pending: list<string>]: nothing -> list<record> {
    $pending | sort | each {|name| {
        rule: "missing_sources_toml"
        severity: "fail"
        message: $"($name): missing skills/sources.toml — every plugin must have one \(migration complete as of claude-skills-180\)"
    }}
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
        # Object sources (github/url) are skipped. Detailed form for the same
        # reason as everywhere else in this file — see scalar-str.
        if (($p.source | describe --detailed | get type) == "record") { continue }
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
        $findings = ($findings | append (missing-sources-findings $pending))
    }

    # claude-skills-198 / D4(b): guard the AUTHORING TEMPLATE against the same
    # drift it teaches authors to avoid. Reads the real file — not a copy —
    # so this check cannot itself become the stale second place. Only the
    # format-ruled fields are checked; url/notes/skills/name are legitimately
    # placeholders (see plan §6).
    let tmpl_path = ($repo_root | path join "plugins" "tools" "claude-code" "skills" "skill-update" "templates" "sources.toml")
    let tmpl = (open $tmpl_path)
    let tmpl_src = ($tmpl.sources | first)
    let tmpl_checks = [
        ["meta.reviewed_at_plugin_version" $tmpl.meta.reviewed_at_plugin_version ($tmpl.meta.reviewed_at_plugin_version == "unknown" or $tmpl.meta.reviewed_at_plugin_version =~ $SEMVER_RE)]
        ["meta.last_full_check" $tmpl.meta.last_full_check ($tmpl.meta.last_full_check == "unknown" or $tmpl.meta.last_full_check =~ $DATE_RE)]
        ["sources.0.current_version" $tmpl_src.current_version ($tmpl_src.current_version == "unknown" or $tmpl_src.current_version =~ $VERSION_SHAPE_RE)]
        ["sources.0.last_checked" $tmpl_src.last_checked ($tmpl_src.last_checked == "unknown" or $tmpl_src.last_checked =~ $DATE_RE)]
        ["sources.0.version_constraint" $tmpl_src.version_constraint ($tmpl_src.version_constraint in $VERSION_CONSTRAINTS)]
        ["sources.0.update_priority" $tmpl_src.update_priority ($tmpl_src.update_priority in $UPDATE_PRIORITIES)]
    ]
    for row in $tmpl_checks {
        let field = ($row | get 0)
        let value = ($row | get 1)
        let ok = ($row | get 2)
        if not $ok {
            $findings = ($findings | append {
                rule: "b6_template_drift"
                severity: "fail"
                message: $"templates/sources.toml: ($field) = '($value)' fails its own format rule"
            })
        }
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

    print $"(ansi green_bold)✅ sources.toml validation clean \(($validated) file\(s\) validated, 0 pending\)(ansi reset)"
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
            label: "sources is a scalar string, not a list (claude-skills-185 rd2)"
            toml: '
sources = "nope"
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "nothing"
            want: ["b1_sources_not_list"]
        }
        {
            label: "[sources] single-bracket typo parses as a record (claude-skills-185 rd2)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[sources]
skills = ["a"]
name = "demo-source"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b1_sources_not_list"]
        }
        {
            label: "entry name is an int, must not crash str downcase (claude-skills-185 rd2)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = 123
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
            md: "123 is documented here"
            want: []
        }
        {
            label: "meta.last_full_check as a list must report, not crash =~ (claude-skills-185 rd2)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = ["2026-01-01"]
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
            want: ["b3_date"]
        }
        {
            label: "entry last_checked as a list must report, not crash =~ (claude-skills-185 rd2)"
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
last_checked = ["2026-01-01"]
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_date"]
        }
        {
            label: "meta is a scalar, not a table (claude-skills-185)"
            toml: '
meta = "demo"
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
            want: ["b1_meta_not_table"]
        }
        {
            label: "[[sources]] entries are strings, not tables (claude-skills-185)"
            toml: '
sources = ["not-a-table"]
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "nothing documented"
            want: ["b1_entry_not_table"]
        }
        {
            label: "two entries sharing a name (claude-skills-185)"
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
[[sources]]
skills = ["a"]
name = "demo-source"
url = "https://example.org"
check_method = "manual"
current_version = "2.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b6_duplicate_name"]
        }
        {
            label: "two entries sharing a SKILL but not a name stays legal (claude-skills-185)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "upstream-one"
url = "https://example.com"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
[[sources]]
skills = ["a"]
name = "upstream-two"
url = "https://example.org"
check_method = "manual"
current_version = "2.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "upstream-one and upstream-two are documented here"
            want: []
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
        # ---- c2: prose-only match, scheme-prefixed URLs excluded (claude-skills-186) ----
        {
            label: "c2: name appears only inside a scheme-prefixed URL — must still fail"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "lemonade-server"
url = "https://lemonade-server.ai/"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "- **URL**: https://lemonade-server.ai/\n"
            want: ["c2_md_no_mention"]
        }
        {
            label: "c2: name appears in prose (regression guard)"
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
            md: "demo-source is covered in the section below.\n"
            want: []
        }
        {
            label: "c2: bare-domain name in prose without a scheme must NOT be stripped (scheme-only strip, not domain-strip)"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "m3.material.io"
url = "https://m3.material.io/"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "See m3.material.io for the component specs.\n"
            want: []
        }
        {
            label: "c2: name appears in both prose and a URL"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "lemonade-server"
url = "https://lemonade-server.ai/"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "lemonade-server is documented at https://lemonade-server.ai/\n"
            want: []
        }
        {
            label: "c2: name appears only inside a URL embedded mid-sentence (markdown link target, not line-start) — must still fail"
            toml: '
[meta]
plugin = "demo"
reviewed_at_plugin_version = "1.0.0"
last_full_check = "2026-01-01"
[[sources]]
skills = ["a"]
name = "foo-bar"
url = "https://foo-bar.io/x"
check_method = "manual"
current_version = "1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "Check the [docs](https://foo-bar.io/x) for details.\n"
            want: ["c2_md_no_mention"]
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
        # ---- b3_version_shape: current_version format validation (claude-skills-189) ----
        # Contract (shape-based, not strict semver — see claude-skills-189):
        # accept the literal "unknown", or a string matching
        # ^[A-Za-z]{0,10}[-.]?\d+(\.\d+){0,4}([-+][0-9A-Za-z.]+)?$
        # i.e. an optional short alpha prefix (v, OTP, ...) with an optional
        # '-' or '.' separator, one to five dot-separated numeric groups, and
        # an optional -prerelease or +build suffix. No whitespace, no URL
        # scheme, no letters after the numeric body outside that suffix.
        # Rejects: no digits at all, embedded whitespace, a pasted URL, and
        # an empty string. TOML-native int/float values are coerced via
        # scalar-str (same helper already used for last_checked/
        # update_priority/version_constraint) before the shape check runs, so
        # an unquoted `current_version = 2025` or `= 1.0` is judged on its
        # stringified form, not rejected for wrong type.
        {
            label: "current_version = unknown"
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
current_version = "unknown"
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
            label: "current_version = 1.0.0 (valid semver)"
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
        {
            label: "current_version = v2026.3.15 (v-prefixed CalVer, real corpus value)"
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
current_version = "v2026.3.15"
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
            label: "current_version = OTP-29.0.4 (letter-prefixed scheme, absent from corpus today but must be accepted)"
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
current_version = "OTP-29.0.4"
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
            label: "current_version = 1.0.0-rc1 (pre-release suffix, absent from corpus today but must be accepted)"
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
current_version = "1.0.0-rc1"
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
            label: "current_version = 1.0.0+build.5 (build metadata suffix, absent from corpus today but must be accepted)"
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
current_version = "1.0.0+build.5"
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
            # claude-skills-196 (D1b): the suffix class widens by one
            # character ([-+][0-9A-Za-z.]+ -> [-+][0-9A-Za-z.-]+) so a
            # hyphenated prerelease segment is legal. Not a policy widening —
            # SEMVER_RE four lines above already accepts this exact string;
            # VERSION_SHAPE_RE was narrower than the strict-semver constant
            # sitting next to it for this input, an internal contradiction.
            # Measured: 0 of 39 corpus values affected, 0 of 31 adversarial
            # junk strings newly accepted.
            label: "current_version = 1.0.0-alpha-1 (hyphenated prerelease segment — SEMVER_RE already accepts this; claude-skills-196)"
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
current_version = "1.0.0-alpha-1"
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
            label: "current_version = 1.0.0-rc-2 (hyphenated prerelease segment — SEMVER_RE already accepts this; claude-skills-196)"
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
current_version = "1.0.0-rc-2"
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
            label: "current_version = 3 (bare single-digit string, real corpus value)"
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
current_version = "3"
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
            # claude-skills-197: this used to assert want: [] under the label
            # "real corpus value" — misleading. The corpus value is the QUOTED
            # string "2025"; unquoted here only to exercise scalar-str's int
            # coercion path. That silent coercion is exactly the bug: an
            # unquoted int/float current_version records a DIFFERENT value
            # than what the author typed (2025 -> "2025" round-trips here,
            # but 1.10 -> "1.1" does not — see the sibling float case below).
            # current_version is the only scalar-str consumer with no natural
            # type guard (b3_date needs YYYY-MM-DD, SEMVER_RE needs 3 numeric
            # groups, both enums need exact membership — all reject a coerced
            # numeric loudly already). This case now requires a QUOTED string.
            label: "current_version = 2025 (unquoted TOML int — now REJECTED, must be a quoted string; claude-skills-197)"
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
current_version = 2025
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            # claude-skills-197: this used to assert want: [] under the label
            # "exercises scalar-str's float path" — the case that motivates
            # the whole fix. Unquoted 1.0 parses as a TOML float and coerces
            # to "1" (not "1.0"), a value the author never wrote, and the
            # shape regex happened to accept the coerced "1" silently. Now
            # rejected at the type-check site before coercion runs.
            label: "current_version = 1.0 (unquoted TOML float — now REJECTED; coerces to '1', a different value than the author typed; claude-skills-197)"
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
current_version = 1.0
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            # claude-skills-197 (D3 positive control): a QUOTED "1.10" must
            # still be accepted. Proves the new type-check targets the TOML
            # TYPE (must be a string), not the value — a trailing-zero
            # version like 1.10 is legitimate and quoting it is all an author
            # needs to do. Without this case, an implementer could satisfy
            # the two flipped cases above by over-rejecting valid strings.
            label: "current_version = \"1.10\" (quoted trailing-zero version — must stay accepted; claude-skills-197)"
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
current_version = "1.10"
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
            label: "current_version = banana (no digit at all — clearly invalid)"
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
current_version = "banana"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            label: "current_version = '1.0.0 beta' (embedded whitespace — clearly invalid)"
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
current_version = "1.0.0 beta"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            label: "current_version = a pasted URL (accidental paste — clearly invalid)"
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
current_version = "https://example.com/releases/v1.0.0"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            label: "current_version = '' (empty string — clearly invalid)"
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
current_version = ""
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        # ---- D1a / D1c: deliberate won't-fix rejections (claude-skills-196)
        # ----
        # These pin the plan's refusal so a later widening of
        # VERSION_SHAPE_RE is a deliberate act, not silent drift. Measured
        # cost of admitting the PEP-440 separator-less form (D1a): 4 more
        # corpus-style targets gained, but 6 of 31 adversarial junk strings
        # newly accepted, the sharpest being "1.x" — a version CONSTRAINT,
        # not a version, exactly the class of silently-wrong pin this rule
        # exists to block. There is also no PyPI check_method and 0 corpus
        # entries name a Python/CPython upstream, so the demand is absent,
        # not dormant. D1c (dual -prerelease+build suffix) is rejected by
        # SEMVER_RE itself, which permits only one suffix group — widening
        # VERSION_SHAPE_RE alone would make it wider than strict semver in a
        # direction semver itself forbids.
        {
            label: "current_version = 3.13.0rc1 (PEP 440 separator-less suffix — WON'T FIX, D1a; claude-skills-196)"
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
current_version = "3.13.0rc1"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            label: "current_version = 2.0b1 (PEP 440 separator-less suffix — WON'T FIX, D1a; claude-skills-196)"
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
current_version = "2.0b1"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            label: "current_version = 1.0.post1 (PEP 440 separator-less suffix — WON'T FIX, D1a; claude-skills-196)"
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
current_version = "1.0.post1"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            label: "current_version = 1.0.0-rc.1+build.5 (dual prerelease+build suffix — WON'T FIX, D1c; rejected by SEMVER_RE too; claude-skills-196)"
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
current_version = "1.0.0-rc.1+build.5"
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            # Mirrors "entry last_checked as a list must report, not crash =~
            # (claude-skills-185 rd2)" above: scalar-str returns null for a
            # list<string> (not in its coercible-type set), which routes
            # through the genuine `$cv == null` wrong-type branch rather than
            # the shape-regex branch.
            # claude-skills-197 verification note: the D3 fix moves the type
            # check ahead of scalar-str, testing `describe` on the RAW value
            # directly. A list's raw type is "list<string>", never "string",
            # so this case is caught by the new pre-coercion check instead of
            # the old post-scalar-str null branch — same rule id
            # (b3_version_shape), unchanged `want`. This case must keep
            # passing unmodified; if the implementer's diff changes its
            # outcome or rule id, that is a regression, not an expected
            # side-effect of D3.
            label: "current_version as a list must report, not crash =~ (claude-skills-189 wrong-type guard)"
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
current_version = ["1.0"]
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
        {
            # Mirrors "A-F4.3: TOML-native unquoted date must not crash =~"
            # above. Looks like a plausible authoring mistake (someone typing
            # a bare date meaning a version). Unlike the list case, `datetime`
            # IS in scalar-str's coercible set, so under the OLD logic this
            # did not hit the `$cv == null` branch — it coerced to a string
            # like "Thu Jan  1 00:00:00 2026" and failed the shape regex.
            # claude-skills-197 verification note: under the D3 fix the raw
            # `describe` of a TOML date is "date" (or "datetime"), never
            # "string" — coercion never runs, so this now lands on the NEW
            # pre-coercion type-check branch instead of the old
            # shape-mismatch branch. Still the same rule id
            # (b3_version_shape) and unchanged `want`, but the reasoning for
            # WHY it fails moves from "shape regex mismatch" to "wrong TOML
            # type" — a distinction that only shows up if a future change
            # inspects the message text, not the rule id this self-test
            # checks. Pinned anyway because it is the sneakier of the two
            # non-scalar shapes: it reads as ordinary input, not an obvious
            # wrong type.
            label: "current_version = unquoted TOML date must not crash — parses as datetime, not a version string (claude-skills-189 wrong-type guard)"
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
current_version = 2026-01-01
version_constraint = "semver"
last_checked = "2026-01-01"
update_priority = "medium"
'
            dirs: ["a"]
            plugin: "demo"
            version: "1.0.0"
            md: "demo-source is documented here"
            want: ["b3_version_shape"]
        }
    ]

    # ---- claude-skills-198 / D4(b) — b6_template_drift: NOT covered by a
    # $cases entry, deliberately ----
    # The plan's own restraint note names this the cuttable item, and warns
    # explicitly against faking coverage: "do NOT write a self-test that
    # hard-codes the template's expected values — that is a copy that can
    # drift from the template, reproducing the exact two-places-no-link
    # failure being fixed."
    #
    # check-sources (tested via $cases above) takes an already-parsed record
    # plus a plugin name/version/skill_dirs/md — it has no notion of "read
    # this specific file path." The D4(b) check as scoped in the plan lives
    # in `main` (~10 lines, reusing VERSION_SHAPE_RE / DATE_RE /
    # VERSION_CONSTRAINTS / UPDATE_PRIORITIES) and reads
    # plugins/tools/claude-code/skills/skill-update/templates/sources.toml
    # directly — unlike missing-sources-findings (claude-skills-192), the
    # plan does not specify a pure, testable function contract for it, and
    # inventing one here would be the test author deciding an implementation
    # shape the plan left open, not encoding a contract that exists.
    #
    # Two options were considered and rejected:
    #   1. A $cases entry with a literal copy of the template's live-block
    #      values, asserting want: [] or want: ["b6_template_drift"] — this
    #      is exactly the hard-coded-copy anti-pattern the plan calls out.
    #   2. A synthetic record with deliberately bad values (e.g.
    #      current_version = "") asserting the rule fires — this tests
    #      generic type/shape logic already covered by the b3_version_shape
    #      cases above; it does not touch the actual template file at all,
    #      so it would not catch template drift (the defect claude-skills-198
    #      reports) — coverage theater, not coverage.
    #
    # The honest answer: b6_template_drift is only meaningfully verified as
    # an INTEGRATION check, run after D4(a) (the template doc fix) and D4(b)
    # (the check itself) both land:
    #   - `nu test/validate-sources.nu` must report zero b6_template_drift
    #     findings against the real (fixed) template on disk.
    #   - A manual regression probe — temporarily reintroduce
    #     `current_version = ""` in templates/sources.toml and re-run the
    #     validator — must show the new rule firing, then the edit reverted.
    # This is implementer/CI-verification work, not something a unit-style
    # $cases entry can honestly cover without copying the file it is meant
    # to guard.

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
        print $"(ansi red_bold)❌ a4_review_pending severity case: expected exactly one info finding \(a4_review_pending\) and zero fail findings, got ($severity_findings | to nuon)(ansi reset)"
        $failed = true
    }

    # missing-sources-findings (claude-skills-192): the pure function
    # extracted from main's pending-plugin loop (lines ~488-525). main
    # accumulates plugin names lacking a sources.toml into `pending`, then
    # turns each into a missing_sources_toml finding — that finding-
    # production half was never reachable from check-sources (which only
    # ever receives an already-parsed toml), so it is untestable inline.
    # Contract: `missing-sources-findings [pending: list<string>]` takes the
    # raw (unsorted) plugin-name list and returns one {rule, severity,
    # message} record per name, sorted by name to match today's `for name in
    # ($pending | sort)` iteration order. The emitted message text is exact —
    # it must not change: "<name>: missing skills/sources.toml — every
    # plugin must have one (migration complete as of claude-skills-180)".
    #
    # The function does not exist yet (that is the implementer's job), so
    # every case below wraps its call in try/catch. Nushell resolves a
    # custom-command call at RUNTIME here, not at parse time (confirmed by
    # probe: a script with an undefined call still parses and runs everything
    # before it) — so an unguarded call would raise `nu::shell::
    # external_command` ("Command ... not found") and abort the whole
    # self-test with no further output. The catch turns that into one red
    # line per case (naming the case and nushell's message) and a sentinel
    # string result, so all cases still get evaluated, the pre-existing 48
    # cases above are unaffected, and $failed still drives `exit 1` below —
    # no unhandled-error abort. Once the implementer adds the function, the
    # try block just returns its real result and these become normal
    # got-vs-want comparisons.
    let missing_cases = [
        {
            label: "empty pending list produces no findings"
            pending: []
            want: []
        }
        {
            label: "one missing plugin produces one finding naming it"
            pending: ["demo-plugin"]
            want: ["demo-plugin: missing skills/sources.toml — every plugin must have one (migration complete as of claude-skills-180)"]
        }
        {
            label: "multiple missing plugins each produce their own finding, sorted by name"
            pending: ["zeta-plugin" "alpha-plugin"]
            want: [
                "alpha-plugin: missing skills/sources.toml — every plugin must have one (migration complete as of claude-skills-180)"
                "zeta-plugin: missing skills/sources.toml — every plugin must have one (migration complete as of claude-skills-180)"
            ]
        }
    ]
    for c in $missing_cases {
        let got = (try {
            missing-sources-findings $c.pending
        } catch {|e|
            print $"(ansi red_bold)❌ missing-sources-findings: ($c.label): call raised \(($e.msg)\)(ansi reset)"
            "MISSING-SOURCES-FINDINGS-NOT-IMPLEMENTED"
        })
        if ($got | describe) == "string" {
            $failed = true
            continue
        }
        let got_messages = ($got | get message)
        let rules_ok = ($got | all {|f| $f.rule == "missing_sources_toml" and $f.severity == "fail"})
        if $got_messages != $c.want or (not $rules_ok) {
            print $"(ansi red_bold)❌ missing-sources-findings: ($c.label): want ($c.want), got ($got | to nuon)(ansi reset)"
            $failed = true
        }
    }

    if $failed { exit 1 }
    print $"(ansi green_bold)✅ sources self-test passed \(($cases | length) cases\)(ansi reset)"
    exit 0
}
