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

def main [--update-baseline] {
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
    mut registry = []
    for plugin in $marketplace.plugins {
        let source_type = ($plugin.source | describe)
        if ($source_type | str starts-with "record") { continue }
        if ($plugin.name == "all-skills") { continue }

        let plugin_dir = ($repo_root | path join ($plugin.source | str replace --regex '^\./' ''))
        let plugin_json_path = ($plugin_dir | path join ".claude-plugin" "plugin.json")
        if not ($plugin_json_path | path exists) { continue }

        let plugin_json = (open $plugin_json_path)
        let skill_names = ($plugin_json | get -o skills | default [] | each {|p|
            $p | str replace --regex '^\./' '' | path basename
        })
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

            # 9. Reference depth (no nested references; code examples don't count)
            let refs_dir = ($skill_dir | path join "references")
            let ref_files = if ($refs_dir | path exists) {
                glob ($refs_dir | path join "*.md")
            } else {
                []
            }
            let nested = ($ref_files | where {|f|
                (strip-fences (open --raw $f)) | str contains "references/"
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
            # Only validated when the path's top-level dir exists inside the skill,
            # so mentions of other repos' scripts/ etc. are not false positives.
            let link_paths = ($stripped
                | parse --regex '(?P<path>(?:references|templates|scripts|agents|hooks)/[A-Za-z0-9._/-]+\.[A-Za-z0-9]{1,6})'
                | get path | uniq)
            let broken_links = ($link_paths | where {|p|
                let top = ($p | split row "/" | first)
                (($skill_dir | path join $top) | path exists) and (not (($skill_dir | path join $p) | path exists))
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
            let no_urls = ($invocation_content | str replace --regex --all '[a-zA-Z][a-zA-Z0-9+.-]*://[^\s)]+' ' ')
            # Leading boundary required so image refs like REGISTRY/claude-code:v1
            # or ghcr.io/anthropics/claude-code:latest do not match.
            let invocations = ($no_urls
                | parse --regex '(?m)(?:^|[\s`(\[<"])/(?P<ns>[a-z][a-z0-9-]*):(?P<target>[a-z][a-z0-9-]*)'
                | select ns target | uniq)
            mut bad_invocations = []
            for inv in $invocations {
                let known = ($registry | where name == $inv.ns)
                if ($known | is-not-empty) {
                    if not ($inv.target in ($known | first | get invocables)) {
                        $bad_invocations = ($bad_invocations | append $"/($inv.ns):($inv.target)")
                    }
                }
            }
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

    if ($results | is-empty) {
        print "No skills found to validate."
        exit 1
    }

    # Print scorecard
    print ($results | table --expand --width 220)
    print ""
    print $"Total skills: ($total_skills)"
    print $"Perfect score: ($total_pass)/($total_skills)"

    if $update_baseline {
        {
            "_comment": "Ratchet baseline for test/validate-skills-quality.nu. Entries are pre-existing failures (plugin/skill:check) allowed to keep failing. Do not add entries for new code; fix the skill instead. When a fix lands, the validator requires removing the stale entry. Regenerate: nu test/validate-skills-quality.nu --update-baseline"
            allowed_failures: ($failing_keys | sort)
        } | to json --indent 2 | save -f $baseline_path
        print ""
        print $"Baseline updated: ($baseline_path) — ($failing_keys | length) allowed failures"
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
