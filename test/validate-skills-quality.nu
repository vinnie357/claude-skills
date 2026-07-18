#!/usr/bin/env nu
# Validate skill quality across all plugins
#
# Runs static analysis checks on every skill and produces a scorecard table.
# Checks are sourced from Anthropic's skill best practices and the Agent Skills Specification.
#
# Enforcement uses a ratchet baseline (test/quality-baseline.json):
# - A failing check NOT in the baseline fails the run (new violations cannot land).
# - A baselined check that now passes fails the run with a prompt to remove the
#   stale entry (the baseline only shrinks).
# Regenerate the baseline with: nu test/validate-skills-quality.nu --update-baseline
#
# Usage:
#   nu test/validate-skills-quality.nu              # scan all plugins
#   nu test/validate-skills-quality.nu --self-test  # verify the skills: frontmatter checks

# Resolve every /plugin:skill token in `content` against the Pass-1 registry
# (list of {name, dir, invocables}). Unknown (external) plugin namespaces are
# skipped — only same-marketplace references are checked. Shared by check 16
# (per-skill SKILL.md + references) and the Pass 2 agents/commands surfaces
# so invocation resolution has exactly one implementation.
def find-bad-invocations [content: string, registry: list] {
    let no_urls = ($content | str replace --regex --all '[a-zA-Z][a-zA-Z0-9+.-]*://[^\s)]+' ' ')
    # Leading boundary required so image refs like REGISTRY/claude-code:v1
    # or ghcr.io/anthropics/claude-code:latest do not match.
    let invocations = ($no_urls
        | parse --regex '(?m)(?:^|[\s`(\[<"])/(?P<ns>[a-z][a-z0-9-]*):(?P<target>[a-z][a-z0-9-]*)'
        | select ns target | uniq)
    mut bad = []
    for inv in $invocations {
        let known = ($registry | where name == $inv.ns)
        if ($known | is-not-empty) {
            if not ($inv.target in ($known | first | get invocables)) {
                $bad = ($bad | append $"/($inv.ns):($inv.target)")
            }
        }
    }
    $bad
}

# Full directory path for a skill name, resolved via the Pass-1
# skill_dir_map (built once for all local plugins). When `plugin` is
# non-empty and a (skill, plugin) pair exists, that scoped match wins —
# this is what makes resolution namespace-aware for a skill name that
# collides across two local plugins. Otherwise (no plugin given, or the
# plugin doesn't carry that skill) falls back to the prior skill-name-only
# first-match, preserving lenient handling for unknown/external
# namespaces. Returns "" when the skill name is not a known local skill.
def lookup-skill-dir [skill_dir_map: list, skill: string, plugin: string = ""]: nothing -> string {
    if ($plugin | is-not-empty) {
        let scoped = ($skill_dir_map | where skill == $skill and plugin == $plugin)
        if ($scoped | is-not-empty) {
            return ($scoped | first | get dir)
        }
    }
    let m = ($skill_dir_map | where skill == $skill)
    if ($m | is-not-empty) { $m | first | get dir } else { "" }
}

# A references/<path> token is cross-skill qualified when the qualifier
# immediately preceding it on the same line — either a /plugin:skill token
# (the common case: "see `/core:restraint`'s references/foo.md") or a full
# plugins/<...>/skills/<other>/ prefix — names a DIFFERENT, REAL skill whose
# own directory actually contains that reference file. Existence is
# resolved against skill_dir_map (the Pass-1 registry of local skill
# directories), so an unrelated qualifier earlier on the line that doesn't
# actually own the path, or a broken cross-skill pointer, is NOT exempted —
# both fall through to the normal same-skill checks. When the /plugin:skill
# token's namespace names a known local plugin (checked against
# known_plugins, the Pass-1 registry's plugin names), resolution is scoped
# to that plugin's own tree — so a skill name that collides across two
# local plugins resolves against the plugin the token actually names,
# never whichever plugin's skill_dir_map entry happened to register first.
# Unknown/external skill names and unknown plugin namespaces (not in the
# local marketplace) cannot be existence-checked, so they stay exempted to
# preserve prior handling of genuinely external references — check 16
# (invocations) independently flags unresolvable /plugin:skill tokens
# naming a real-but-wrong local skill. Shared by check 9 (ref_depth) and
# check 14 (links).
def cross-skill-qualified [prefix_line: string, dir_name: string, path: string, skill_dir_map: list, known_plugins: list]: nothing -> bool {
    let qual_match = ($prefix_line | parse --regex '/(?P<ns>[a-z][a-z0-9-]*):(?P<skill>[a-z][a-z0-9-]*)')
    let candidate = if ($qual_match | is-not-empty) {
        $qual_match | last | get skill
    } else {
        let plugins_match = ($prefix_line | parse --regex 'skills/(?P<skill>[a-z][a-z0-9-]*)/$')
        if ($plugins_match | is-not-empty) {
            $plugins_match | first | get skill
        } else {
            ""
        }
    }
    if ($candidate | is-empty) or ($candidate == $dir_name) {
        return false
    }
    let candidate_ns = if ($qual_match | is-not-empty) { $qual_match | last | get ns } else { "" }
    let scoped_ns = if ($candidate_ns in $known_plugins) { $candidate_ns } else { "" }
    let target_dir = (lookup-skill-dir $skill_dir_map $candidate $scoped_ns)
    if ($target_dir | is-empty) {
        return true
    }
    ($target_dir | path join $path) | path exists
}

# Text preceding the first occurrence of `path` in `content`, truncated to
# just its own line (so cross-skill-qualified only sees same-line context).
def preceding-line [content: string, path: string]: nothing -> string {
    let idx = ($content | str index-of $path)
    if $idx < 0 {
        ""
    } else {
        let before = ($content | str substring 0..<$idx)
        ($before | split row "\n" | last)
    }
}

# True when `content` contains at least one "references/" token that is NOT
# cross-skill qualified (i.e. a genuine same-skill nested reference).
def has-unqualified-references-token [content: string, dir_name: string, skill_dir_map: list, known_plugins: list]: nothing -> bool {
    ($content | lines | any {|line|
        if not ($line | str contains "references/") {
            false
        } else {
            let idx = ($line | str index-of "references/")
            let prefix = ($line | str substring 0..<$idx)
            let rest = ($line | str substring $idx..)
            let path_match = ($rest | parse --regex '^(?P<path>references/[A-Za-z0-9._/-]+\.[A-Za-z0-9]{1,6})')
            let path = if ($path_match | is-not-empty) { $path_match | first | get path } else { $rest }
            not (cross-skill-qualified $prefix $dir_name $path $skill_dir_map $known_plugins)
        }
    })
}

# Parse an agent's `skills:` frontmatter field out of its already-extracted
# fm_lines. Three shapes: absent (no `skills:` key at all), inline scalar
# (`skills: foo` — invalid, flagged via shape_ok: false), or a YAML list of
# `- ns:skill` entries. Entry values are NOT shape-validated here (that's
# check-agent-skills' job) — this function only parses structure.
def parse-skills-frontmatter [fm_lines: list] {
    let hits = ($fm_lines | enumerate | where {|l| ($l.item | str starts-with "skills:")})
    if ($hits | is-empty) { return {present: false, entries: [], shape_ok: true} }
    let first = ($hits | first)
    if (($first.item | str replace "skills:" "" | str trim) | is-not-empty) {
        return {present: true, entries: [], shape_ok: false}   # inline scalar form
    }
    mut entries = []
    for line in ($fm_lines | skip ($first.index + 1)) {
        let t = ($line | str trim)
        if ($t | str starts-with "- ") { $entries = ($entries | append ($t | str substring 2.. | str trim)) } else { break }
    }
    {present: true, entries: $entries, shape_ok: true}
}

# Validate an agent's `skills:` frontmatter (claude-skills-119): well-formed
# `ns:skill` entries, no duplicates, and each entry resolves against the
# registry's `skills` list — NEVER `invocables`, since invocables also
# carries command names and a command token is not preloadable via an
# agent's `skills:` field. Unknown/external plugin namespaces are skipped,
# mirroring find-bad-invocations' external-namespace leniency. Shared by the
# Pass-2 agent loop and run-skills-self-test so there is exactly one
# implementation to keep in sync.
def check-agent-skills [fm_lines: list, registry: list] {
    let parsed = (parse-skills-frontmatter $fm_lines)
    if not $parsed.present {
        return {failed: [], bad_tokens: []}
    }
    mut failed = []
    let shape_bad = (not $parsed.shape_ok) or ($parsed.entries | any {|e|
        ($e | parse --regex '^[a-z][a-z0-9-]*:[a-z][a-z0-9-]*$') | is-empty
    })
    if $shape_bad { $failed = ($failed | append "skills_shape") }
    if ($parsed.entries | length) != ($parsed.entries | uniq | length) {
        $failed = ($failed | append "skills_duplicate")
    }
    mut bad_tokens = []
    for entry in $parsed.entries {
        let m = ($entry | parse --regex '^(?P<ns>[a-z][a-z0-9-]*):(?P<skill>[a-z][a-z0-9-]*)$')
        if ($m | is-not-empty) {
            let ns = ($m | first | get ns)
            let skill = ($m | first | get skill)
            let known = ($registry | where name == $ns)
            if ($known | is-not-empty) and ($skill not-in ($known | first | get skills)) {
                $bad_tokens = ($bad_tokens | append $entry)
            }
        }
    }
    if ($bad_tokens | is-not-empty) { $failed = ($failed | append "skills_unresolved") }
    {failed: $failed, bad_tokens: $bad_tokens}
}

# Remove fenced code blocks so code examples don't trip content checks
# (e.g. a `name: CI` line inside a GitHub Actions YAML example).
def strip-fences [content: string] {
    mut in_fence = false
    mut kept = []
    for line in ($content | lines) {
        if (($line | str trim) | str starts-with "```") {
            $in_fence = (not $in_fence)
        } else if (not $in_fence) {
            $kept = ($kept | append $line)
        }
    }
    $kept | str join "\n"
}

# Embedded self-test for the skills: frontmatter checks (claude-skills-119):
# every bad case must be flagged, every good case must pass clean. Exercises
# check-agent-skills directly — the same implementation the Pass-2 agent
# loop calls — so there is no drift between what's tested and what runs.
def run-skills-self-test [] {
    let fake_registry = [
        {name: "rust", dir: "", invocables: [], skills: ["rust" "testing" "error-handling"]}
        {name: "core", dir: "", invocables: [], skills: ["tdd" "anti-fabrication"]}
    ]
    mut failed = false

    # Case 1: inline scalar form (`skills: rust:rust` instead of a list)
    let inline = (check-agent-skills ["skills: rust:rust"] $fake_registry)
    if "skills_shape" not-in $inline.failed {
        print $"(ansi red_bold)❌ skills self-test: inline scalar form not flagged(ansi reset)"
        $failed = true
    }

    # Case 2: malformed token shape (uppercase / underscore violates ns:skill regex)
    let malformed = (check-agent-skills ["skills:" "  - Rust:BAD_Name"] $fake_registry)
    if "skills_shape" not-in $malformed.failed {
        print $"(ansi red_bold)❌ skills self-test: malformed token not flagged(ansi reset)"
        $failed = true
    }

    # Case 3: duplicate entries (both individually well-formed)
    let duplicate = (check-agent-skills ["skills:" "  - rust:rust" "  - rust:rust"] $fake_registry)
    if "skills_duplicate" not-in $duplicate.failed {
        print $"(ansi red_bold)❌ skills self-test: duplicate entries not flagged(ansi reset)"
        $failed = true
    }

    # Case 4: unresolvable token against a known namespace
    let unresolved = (check-agent-skills ["skills:" "  - rust:nonexistent"] $fake_registry)
    if ("skills_unresolved" not-in $unresolved.failed) or ("rust:nonexistent" not-in $unresolved.bad_tokens) {
        print $"(ansi red_bold)❌ skills self-test: unresolvable token not flagged(ansi reset)"
        $failed = true
    }

    # Case 5: clean list, plus an external/unknown namespace token that must
    # be skipped (leniency), not flagged unresolved
    let clean = (check-agent-skills ["skills:" "  - rust:rust" "  - core:tdd" "  - someexternal:thing"] $fake_registry)
    if ($clean.failed | is-not-empty) {
        print $"(ansi red_bold)❌ skills self-test: clean list flagged \(($clean.failed | str join ' ')\)(ansi reset)"
        $failed = true
    }

    if $failed { exit 1 }
    print $"(ansi green_bold)✅ Agent skills: frontmatter self-test passed \(5 cases\)(ansi reset)"
    exit 0
}

def main [--update-baseline, --self-test] {
    if $self_test {
        run-skills-self-test
        return
    }

    print "Validating skill quality across all plugins..."
    print ""

    let repo_root = (git rev-parse --show-toplevel | str trim)
    let marketplace_path = ($repo_root | path join ".claude-plugin" "marketplace.json")
    let marketplace = (open $marketplace_path)
    let code_fence = (['`' '`' '`'] | str join)

    let baseline_path = ($repo_root | path join "test" "quality-baseline.json")
    let baseline = if ($baseline_path | path exists) {
        open $baseline_path | get allowed_failures
    } else {
        []
    }

    # Pass 1: registry of local plugins -> skill dir names + command names,
    # used to resolve /plugin:skill invocations found in skill content.
    # skill_dir_map is a parallel flat list of {skill, dir, plugin} used to
    # existence-check cross-skill references/ pointers (see
    # cross-skill-qualified) — the plugin field lets that lookup be
    # namespace-aware when a skill name collides across two local plugins.
    mut registry = []
    mut skill_dir_map = []
    for plugin in $marketplace.plugins {
        let source_type = ($plugin.source | describe)
        if ($source_type | str starts-with "record") { continue }
        if ($plugin.name == "all-skills") { continue }

        let plugin_dir = ($repo_root | path join ($plugin.source | str replace --regex '^\./' ''))
        let plugin_json_path = ($plugin_dir | path join ".claude-plugin" "plugin.json")
        if not ($plugin_json_path | path exists) { continue }

        let plugin_json = (open $plugin_json_path)
        let skill_paths = ($plugin_json | get -o skills | default [])
        let skill_names = ($skill_paths | each {|p|
            $p | str replace --regex '^\./' '' | path basename
        })
        for p in $skill_paths {
            let full_dir = ($plugin_dir | path join ($p | str replace --regex '^\./' ''))
            $skill_dir_map = ($skill_dir_map | append {skill: ($full_dir | path basename), dir: $full_dir, plugin: $plugin_json.name})
        }
        let commands_dir = ($plugin_dir | path join "commands")
        let command_names = if ($commands_dir | path exists) {
            glob ($commands_dir | path join "*.md") | each {|f|
                $f | path basename | str replace ".md" ""
            }
        } else {
            []
        }
        $registry = ($registry | append {
            name: $plugin_json.name
            dir: $plugin_dir
            invocables: ($skill_names | append $command_names)
            skills: $skill_names
        })
    }

    mut results = []
    mut total_skills = 0
    mut total_pass = 0
    mut failing_keys = []

    for plugin in $registry {
        let plugin_dir = $plugin.dir
        let plugin_name = $plugin.name
        let plugin_json = (open ($plugin_dir | path join ".claude-plugin" "plugin.json"))
        let skills = ($plugin_json | get -o skills | default [])

        # Find sources.md for the plugin
        let sources_path = ($plugin_dir | path join "skills" "sources.md")
        let sources_content = if ($sources_path | path exists) {
            open --raw $sources_path
        } else {
            ""
        }

        for skill_path in $skills {
            let skill_dir = ($plugin_dir | path join ($skill_path | str replace --regex '^\./' ''))
            let skill_md_path = ($skill_dir | path join "SKILL.md")

            if not ($skill_md_path | path exists) {
                continue
            }

            $total_skills = $total_skills + 1

            let dir_name = ($skill_dir | path basename)
            let content = (open --raw $skill_md_path)
            let stripped = (strip-fences $content)
            let all_lines = ($content | lines)
            let line_count = ($all_lines | length)

            # Parse YAML frontmatter (between --- markers)
            let fm_lines = if ($all_lines | first | default "" | str trim) == "---" {
                let rest = ($all_lines | skip 1)
                let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "---"})
                if ($end_matches | is-not-empty) {
                    let end_idx = ($end_matches | first | get index)
                    $rest | first $end_idx
                } else {
                    []
                }
            } else {
                []
            }

            # Extract name field
            let name_lines = ($fm_lines | where {|line| $line | str starts-with "name:"})
            let name = if ($name_lines | is-not-empty) {
                $name_lines | first | str replace "name:" "" | str trim | str trim -c '"' | str trim -c "'"
            } else {
                ""
            }

            # Extract description field
            let desc_lines = ($fm_lines | where {|line| $line | str starts-with "description:"})
            let description = if ($desc_lines | is-not-empty) {
                $desc_lines | first | str replace "description:" "" | str trim | str trim -c '"' | str trim -c "'"
            } else {
                ""
            }

            mut failed = []

            # 1. Description length: non-empty, ≤1024 chars
            let desc_len = ($description | str length)
            if not ($desc_len > 0 and $desc_len <= 1024) { $failed = ($failed | append "desc") }

            # 2. Description has "Use when"
            let desc_lower = ($description | str downcase)
            if not ($desc_lower | str contains "use when") { $failed = ($failed | append "use_when") }

            # 3. Description third person (no "I can", "You can")
            let has_first = ($description | str contains "I can")
            let has_second = ($description | str contains "You can")
            let has_first_will = ($description | str contains "I will")
            let has_second_will = ($description | str contains "You will")
            if ($has_first or $has_second or $has_first_will or $has_second_will) {
                $failed = ($failed | append "third_person")
            }

            # 4. Name kebab-case
            let kebab_matches = ($name | parse --regex '^[a-z0-9]+(-[a-z0-9]+)*$')
            if ($kebab_matches | is-empty) { $failed = ($failed | append "kebab") }

            # 5. Name ≤64 chars
            let name_len = ($name | str length)
            if not ($name_len <= 64 and $name_len > 0) { $failed = ($failed | append "name_len") }

            # 6. No reserved words
            let has_anthropic = ($name | str contains "anthropic")
            let has_claude = ($name | str contains "claude")
            if ($has_anthropic or $has_claude) { $failed = ($failed | append "reserved") }

            # 7. SKILL.md ≤500 lines
            if $line_count > 500 { $failed = ($failed | append "lines") }

            # 8. Has examples (code blocks or example sections)
            let has_code_fence = ($content | str contains $code_fence)
            let has_example_header = ($content | str downcase | str contains "## example")
            if not ($has_code_fence or $has_example_header) { $failed = ($failed | append "examples") }

            # 9. Reference depth (no nested references; code examples don't count).
            # A references/ token qualified as pointing at another skill (see
            # cross-skill-qualified above) is not a same-skill nesting violation.
            let refs_dir = ($skill_dir | path join "references")
            let ref_files = if ($refs_dir | path exists) {
                glob ($refs_dir | path join "*.md")
            } else {
                []
            }
            let nested = ($ref_files | where {|f|
                has-unqualified-references-token (strip-fences (open --raw $f)) $dir_name $skill_dir_map ($registry | get name)
            })
            if ($nested | length) > 0 { $failed = ($failed | append "ref_depth") }

            # 10. Anti-fabrication present
            let content_lower = ($content | str downcase)
            let has_anti_fab_header = ($content_lower | str contains "anti-fabrication")
            let has_anti_fab_ref = ($content | str contains "core:anti-fabrication")
            let has_fabricat = ($content_lower | str contains "fabricat")
            if not ($has_anti_fab_header or $has_anti_fab_ref or $has_fabricat) {
                $failed = ($failed | append "anti_fab")
            }

            # 11. Source documented (keyed on directory name OR frontmatter name,
            # so a frontmatter/directory mismatch doesn't produce a false FAIL)
            let sources_lower = ($sources_content | str downcase)
            let source_ok = if ($sources_content | str length) > 0 {
                ($sources_lower | str contains ($dir_name | str downcase)) or ($sources_lower | str contains ($name | str downcase))
            } else {
                false
            }
            if not $source_ok { $failed = ($failed | append "source") }

            # 12. No 'allowed-tools' in frontmatter
            let has_allowed_tools = ($fm_lines | any {|line| ($line | str trim) | str starts-with "allowed-tools:"})
            if $has_allowed_tools { $failed = ($failed | append "allowed_tools") }

            # 13. Frontmatter name matches directory name (Agent Skills Specification)
            if $name != $dir_name { $failed = ($failed | append "name_dir") }

            # 14. Link integrity: asset paths mentioned in SKILL.md prose must exist.
            # references/ and agents/ are skill-spec dirs — their links must ALWAYS
            # resolve (a git checkout has no empty dirs, so a dir-exists guard would
            # make results environment-dependent). scripts/ templates/ hooks/ are
            # only validated when the dir exists inside the skill, so mentions of
            # other repos' scripts/ etc. are not false positives.
            # Leading boundary so a longer cross-plugin path like
            # plugins/core/skills/bees/agents/foo.md does not match on its
            # agents/foo.md substring.
            let link_paths = ($stripped
                | parse --regex '(?m)(?:^|[\s`(\[<"])(?P<path>(?:references|templates|scripts|agents|hooks)/[A-Za-z0-9._/-]+\.[A-Za-z0-9]{1,6})'
                | get path | uniq)
            let broken_links = ($link_paths | where {|p|
                let top = ($p | split row "/" | first)
                let dir_gated = $top in ["scripts" "templates" "hooks"]
                let in_scope = (not $dir_gated) or (($skill_dir | path join $top) | path exists)
                let missing = (not (($skill_dir | path join $p) | path exists))
                # A references/ path qualified as pointing at another skill
                # (see cross-skill-qualified above) resolves against that
                # skill's own tree, not $skill_dir — not a broken link here.
                let cross_skill = ($top == "references") and (cross-skill-qualified (preceding-line $stripped $p) $dir_name $p $skill_dir_map ($registry | get name))
                $in_scope and $missing and (not $cross_skill)
            })
            if ($broken_links | is-not-empty) { $failed = ($failed | append "links") }

            # 15. No orphan files: every references/*.md and agents/*.md must be
            # mentioned at least once from SKILL.md.
            let agents_dir = ($skill_dir | path join "agents")
            let agent_files = if ($agents_dir | path exists) {
                glob ($agents_dir | path join "*.md")
            } else {
                []
            }
            let orphans = ($ref_files | append $agent_files | where {|f|
                not ($content | str contains ($f | path basename))
            })
            if ($orphans | is-not-empty) { $failed = ($failed | append "orphans") }

            # 16. Cross-skill invocations resolve: every /plugin:skill token in
            # SKILL.md or references must name a real skill or command of a local
            # plugin. Unknown (external) plugin namespaces are skipped.
            let invocation_content = ($ref_files | each {|f| open --raw $f} | prepend $content | str join "\n")
            let bad_invocations = (find-bad-invocations $invocation_content $registry)
            if ($bad_invocations | is-not-empty) { $failed = ($failed | append "invocations") }

            # 17. Version pins agree with sources.md: a "Current stable: X" /
            # "Currently at version X" claim must appear as "X (current)" in the
            # plugin's sources.md. Skills without a pin pass (soft check).
            let pins = ($content
                | parse --regex 'Current stable: (?P<ver>v?[0-9][0-9A-Za-z.]*)'
                | append ($content | parse --regex 'Currently at version (?P<ver>v?[0-9][0-9A-Za-z.]*)')
                | get ver | each {|v| $v | str trim -c '.'} | uniq)
            let stale_pins = ($pins | where {|v|
                not ($sources_content | str contains ($v + " (current)"))
            })
            if ($stale_pins | is-not-empty) { $failed = ($failed | append "version_pin") }

            # Classify failures against the baseline
            let keys = ($failed | each {|c| $"($plugin_name)/($dir_name):($c)"})
            $failing_keys = ($failing_keys | append $keys)
            let baselined = ($failed | each {|c| $"($plugin_name)/($dir_name):($c)"} | where {|k| $k in $baseline} | length)
            let new_failures = ($keys | where {|k| $k not-in $baseline})

            let check_count = 17
            let score = $check_count - ($failed | length)

            $results = ($results | append {
                skill: $dir_name
                plugin: $plugin_name
                lines: $"($line_count)/500"
                score: $"($score)/($check_count)"
                failed: ($failed | str join " ")
                new: ($new_failures | each {|k| $k | split row ":" | last} | str join " ")
                details: ($broken_links | append $bad_invocations | append $stale_pins | append ($orphans | each {|f| $f | path basename}) | str join " ")
            })

            if ($failed | is-empty) {
                $total_pass = $total_pass + 1
            }
        }
    }

    # Pass 2: agents/*.md, commands/*.md, hooks/hooks.json — the surfaces a
    # `claude plugin validate` pass does not cover (bogus hook event names,
    # agents missing a name, unresolved /plugin:skill invocations). Reuses
    # the Pass-1 registry and find-bad-invocations (check 16's logic) rather
    # than a second resolver. Findings feed the same ratchet baseline as the
    # per-skill checks above.
    let known_models = ["haiku" "sonnet" "opus"]
    let known_hook_events = ["PreToolUse" "PostToolUse" "SessionStart" "SessionEnd" "UserPromptSubmit" "Stop" "SubagentStop" "PreCompact" "Notification"]
    mut surface_results = []

    for plugin in $registry {
        let plugin_dir = $plugin.dir
        let plugin_name = $plugin.name

        # Agents: plugin-level agents/ dir plus any skill-level nested agents/
        # dirs (same file format — cheap to include, so both are in scope).
        let plugin_level_agents = ($plugin_dir | path join "agents")
        let plugin_agent_files = if ($plugin_level_agents | path exists) {
            glob ($plugin_level_agents | path join "*.md")
        } else { [] }
        let nested_agent_files = (glob ($plugin_dir | path join "skills" "*" "agents" "*.md"))
        let agent_files = ($plugin_agent_files | append $nested_agent_files | uniq)

        for f in $agent_files {
            let content = (open --raw $f)
            let all_lines = ($content | lines)
            let fm_lines = if ($all_lines | first | default "" | str trim) == "---" {
                let rest = ($all_lines | skip 1)
                let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "---"})
                if ($end_matches | is-not-empty) {
                    $rest | first ($end_matches | first | get index)
                } else { [] }
            } else { [] }

            mut failed = []
            if not ($fm_lines | any {|line| $line | str starts-with "name:"}) {
                $failed = ($failed | append "missing_name")
            }
            if not ($fm_lines | any {|line| $line | str starts-with "description:"}) {
                $failed = ($failed | append "missing_desc")
            }
            let model_lines = ($fm_lines | where {|line| $line | str starts-with "model:"})
            if ($model_lines | is-not-empty) {
                let model_val = ($model_lines | first | str replace "model:" "" | str trim | str trim -c '"' | str trim -c "'" | str downcase)
                if $model_val not-in $known_models { $failed = ($failed | append "bad_model") }
            }

            # skills: frontmatter (claude-skills-119) — well-formed entries, no
            # duplicates, and each entry resolves against a local plugin's
            # `skills` list. Only runs when the agent has a `skills:` field.
            let skills_check = (check-agent-skills $fm_lines $registry)
            $failed = ($failed | append $skills_check.failed)

            let bad_invocations = (find-bad-invocations $content $registry)
            if ($bad_invocations | is-not-empty) { $failed = ($failed | append "bad_invocations") }

            if ($failed | is-not-empty) {
                let key_base = $"($plugin_name)/agents/($f | path basename)"
                $failing_keys = ($failing_keys | append ($failed | each {|c| $"($key_base):($c)"}))
                $surface_results = ($surface_results | append {
                    plugin: $plugin_name, kind: "agent", file: ($f | path basename), failed: ($failed | str join " ")
                    details: ($bad_invocations | append $skills_check.bad_tokens | str join " ")
                })
            }
        }

        # Commands: plugin-level commands/ dir only (no nested-skill convention observed).
        let commands_dir = ($plugin_dir | path join "commands")
        let command_files = if ($commands_dir | path exists) {
            glob ($commands_dir | path join "*.md")
        } else { [] }

        for f in $command_files {
            let content = (open --raw $f)
            let all_lines = ($content | lines)
            let fm_lines = if ($all_lines | first | default "" | str trim) == "---" {
                let rest = ($all_lines | skip 1)
                let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "---"})
                if ($end_matches | is-not-empty) {
                    $rest | first ($end_matches | first | get index)
                } else { [] }
            } else { [] }

            mut failed = []
            if not ($fm_lines | any {|line| $line | str starts-with "description:"}) {
                $failed = ($failed | append "missing_desc")
            }
            let bad_invocations = (find-bad-invocations $content $registry)
            if ($bad_invocations | is-not-empty) { $failed = ($failed | append "bad_invocations") }

            if ($failed | is-not-empty) {
                let key_base = $"($plugin_name)/commands/($f | path basename)"
                $failing_keys = ($failing_keys | append ($failed | each {|c| $"($key_base):($c)"}))
                $surface_results = ($surface_results | append {
                    plugin: $plugin_name, kind: "command", file: ($f | path basename), failed: ($failed | str join " ")
                    details: ($bad_invocations | str join " ")
                })
            }
        }

        # Hooks: plugin-level hooks/hooks.json only.
        let hooks_path = ($plugin_dir | path join "hooks" "hooks.json")
        if ($hooks_path | path exists) {
            mut failed = []
            let parsed = try {
                open $hooks_path
            } catch {
                null
            }
            if $parsed == null {
                $failed = ($failed | append "bad_wrapper")
            } else if (($parsed | get -o hooks) == null) {
                $failed = ($failed | append "bad_wrapper")
            } else {
                let bad_events = ($parsed.hooks | columns | where {|e| $e not-in $known_hook_events})
                if ($bad_events | is-not-empty) { $failed = ($failed | append "bad_event") }
            }

            if ($failed | is-not-empty) {
                let key_base = $"($plugin_name)/hooks/hooks.json"
                $failing_keys = ($failing_keys | append ($failed | each {|c| $"($key_base):($c)"}))
                $surface_results = ($surface_results | append {
                    plugin: $plugin_name, kind: "hooks", file: "hooks.json", failed: ($failed | str join " ")
                    details: ""
                })
            }
        }
    }

    if ($results | is-empty) {
        print "No skills found to validate."
        exit 1
    }

    # Print scorecard
    print ($results | table --expand --width 220)
    print ""
    print $"Total skills: ($total_skills)"
    print $"Perfect score: ($total_pass)/($total_skills)"

    print ""
    if ($surface_results | is-empty) {
        print "agents/commands/hooks surfaces: all clean"
    } else {
        print $"agents/commands/hooks surfaces: ($surface_results | length) finding\(s\)"
        print ($surface_results | table --expand --width 220)
    }

    if $update_baseline {
        # Shrink-only: the baseline is a ratchet, never a place to stash new
        # debt. Refuse to add any key that isn't already baselined — the only
        # thing --update-baseline is allowed to do is drop entries that now
        # pass (intersect currently-failing with the existing baseline).
        let new_keys = ($failing_keys | where {|k| $k not-in $baseline} | uniq)
        if ($new_keys | is-not-empty) {
            print ""
            print $"(ansi red_bold)❌ --update-baseline is shrink-only: refusing to add ($new_keys | length) new key\(s\):(ansi reset)"
            for key in $new_keys { print $"  ($key)" }
            print "Fix the skill instead of baselining a new violation. A deliberate net-new debt acknowledgment requires editing test/quality-baseline.json by hand and stating why in the PR."
            exit 1
        }
        let shrunk = ($baseline | where {|k| $k in $failing_keys} | uniq | sort)
        {
            "_comment": "Ratchet baseline for test/validate-skills-quality.nu. Entries are pre-existing failures (plugin/skill:check) allowed to keep failing. Do not add entries for new code; fix the skill instead. When a fix lands, the validator requires removing the stale entry. Regenerate: nu test/validate-skills-quality.nu --update-baseline (shrink-only — errors instead of adding new keys)."
            allowed_failures: $shrunk
        } | to json --indent 2 | save -f $baseline_path
        print ""
        print $"Baseline updated \(shrink-only\): ($baseline_path) — ($shrunk | length) allowed failures"
        exit 0
    }

    let hard_failures = ($failing_keys | where {|k| $k not-in $baseline})
    let stale_baseline = ($baseline | where {|k| $k not-in $failing_keys})

    mut exit_code = 0

    if ($hard_failures | is-not-empty) {
        print ""
        print $"FAIL: ($hard_failures | length) quality violations not in the baseline:"
        for key in $hard_failures { print $"  ($key)" }
        print "Fix the skill (preferred). See the 'details' column for broken links / bad invocations / stale pins / orphans."
        $exit_code = 1
    }

    if ($stale_baseline | is-not-empty) {
        print ""
        print $"FAIL: ($stale_baseline | length) baseline entries now pass — remove them to lock in the fix:"
        for key in $stale_baseline { print $"  ($key)" }
        print "Regenerate with: nu test/validate-skills-quality.nu --update-baseline"
        $exit_code = 1
    }

    if $exit_code == 0 {
        print ""
        print $"Skill quality validation complete! Baselined failures remaining to burn down: ($baseline | length)"
    }

    exit $exit_code
}
