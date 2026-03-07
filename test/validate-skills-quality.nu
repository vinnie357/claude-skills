#!/usr/bin/env nu
# Validate skill quality across all plugins
#
# Runs static analysis checks on every skill and produces a scorecard table.
# Checks are sourced from Anthropic's skill best practices and the Agent Skills Specification.

def main [] {
    print "Validating skill quality across all plugins..."
    print ""

    let repo_root = (git rev-parse --show-toplevel | str trim)
    let marketplace_path = ($repo_root | path join ".claude-plugin" "marketplace.json")
    let marketplace = (open $marketplace_path)
    let code_fence = (['`' '`' '`'] | str join)

    mut results = []
    mut total_skills = 0
    mut total_pass = 0

    for plugin in $marketplace.plugins {
        let source_type = ($plugin.source | describe)

        # Skip external plugins (source is an object)
        if ($source_type | str starts-with "record") {
            continue
        }

        # Skip meta-plugin (all-skills) to avoid double-counting
        if ($plugin.name == "all-skills") {
            continue
        }

        let plugin_dir = ($repo_root | path join ($plugin.source | str replace --regex '^\./' ''))
        let plugin_json_path = ($plugin_dir | path join ".claude-plugin" "plugin.json")

        if not ($plugin_json_path | path exists) {
            continue
        }

        let plugin_json = (open $plugin_json_path)
        let plugin_name = $plugin_json.name
        let skills = ($plugin_json | get -o skills | default [])

        # Find sources.md for the plugin
        let sources_path = ($plugin_dir | path join "skills" "sources.md")
        let sources_content = if ($sources_path | path exists) {
            open $sources_path
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

            let content = (open $skill_md_path)
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

            # Run checks
            mut score = 0

            # 1. Description length: non-empty, ≤1024 chars
            let desc_len = ($description | str length)
            let desc_ok = $desc_len > 0 and $desc_len <= 1024
            if $desc_ok { $score = $score + 1 }

            # 2. Description has "Use when"
            let desc_lower = ($description | str downcase)
            let use_when_ok = ($desc_lower | str contains "use when")
            if $use_when_ok { $score = $score + 1 }

            # 3. Description third person (no "I can", "You can")
            let has_first = ($description | str contains "I can")
            let has_second = ($description | str contains "You can")
            let has_first_will = ($description | str contains "I will")
            let has_second_will = ($description | str contains "You will")
            let third_person_ok = not ($has_first or $has_second or $has_first_will or $has_second_will)
            if $third_person_ok { $score = $score + 1 }

            # 4. Name kebab-case
            let kebab_matches = ($name | parse --regex '^[a-z0-9]+(-[a-z0-9]+)*$')
            let kebab_ok = ($kebab_matches | is-not-empty)
            if $kebab_ok { $score = $score + 1 }

            # 5. Name ≤64 chars
            let name_len = ($name | str length)
            let name_len_ok = $name_len <= 64 and $name_len > 0
            if $name_len_ok { $score = $score + 1 }

            # 6. No reserved words
            let has_anthropic = ($name | str contains "anthropic")
            let has_claude = ($name | str contains "claude")
            let no_reserved = not ($has_anthropic or $has_claude)
            if $no_reserved { $score = $score + 1 }

            # 7. SKILL.md ≤500 lines
            let lines_ok = $line_count <= 500
            if $lines_ok { $score = $score + 1 }

            # 8. Has examples (code blocks or example sections)
            let has_code_fence = ($content | str contains $code_fence)
            let has_example_header = ($content | str downcase | str contains "## example")
            let has_examples = $has_code_fence or $has_example_header
            if $has_examples { $score = $score + 1 }

            # 9. Reference depth (no nested references)
            let refs_dir = ($skill_dir | path join "references")
            let ref_depth_ok = if ($refs_dir | path exists) {
                let ref_files = (glob ($refs_dir | path join "*.md"))
                let nested = ($ref_files | where {|f|
                    let ref_content = (open $f)
                    $ref_content | str contains "references/"
                })
                ($nested | length) == 0
            } else {
                true
            }
            if $ref_depth_ok { $score = $score + 1 }

            # 10. Anti-fabrication present
            let content_lower = ($content | str downcase)
            let has_anti_fab_header = ($content_lower | str contains "anti-fabrication")
            let has_anti_fab_ref = ($content | str contains "core:anti-fabrication")
            let has_fabricat = ($content_lower | str contains "fabricat")
            let anti_fab_ok = $has_anti_fab_header or $has_anti_fab_ref or $has_fabricat
            if $anti_fab_ok { $score = $score + 1 }

            # 11. Source documented
            let source_ok = if ($sources_content | str length) > 0 {
                let has_exact = ($sources_content | str contains $name)
                let has_lower = ($sources_content | str downcase | str contains ($name | str downcase))
                $has_exact or $has_lower
            } else {
                false
            }
            if $source_ok { $score = $score + 1 }

            let desc_result = if $desc_ok { "Pass" } else { "FAIL" }
            let use_when_result = if $use_when_ok { "Pass" } else { "FAIL" }
            let lines_str = $"($line_count)/500"
            let lines_result = if $lines_ok { "Pass" } else { "FAIL" }
            let examples_result = if $has_examples { "Pass" } else { "FAIL" }
            let anti_fab_result = if $anti_fab_ok { "Pass" } else { "FAIL" }
            let score_str = $"($score)/11"

            $results = ($results | append {
                skill: $name
                plugin: $plugin_name
                desc: $desc_result
                use_when: $use_when_result
                lines: $lines_str
                lines_ok: $lines_result
                examples: $examples_result
                anti_fab: $anti_fab_result
                score: $score_str
            })

            if $score == 11 {
                $total_pass = $total_pass + 1
            }
        }
    }

    if ($results | is-empty) {
        print "No skills found to validate."
        exit 1
    }

    # Print scorecard
    print ($results | table --expand --width 200)

    print ""
    print $"Total skills: ($total_skills)"
    print $"Perfect score 11/11: ($total_pass)/($total_skills)"

    # Check for critical failures (name or description issues)
    let failures = ($results | where desc == "FAIL" or use_when == "FAIL")
    if ($failures | is-not-empty) {
        print ""
        print "Skills with description issues:"
        print ($failures | select skill plugin desc use_when | table --expand)
    }

    print ""
    print "Skill quality validation complete!"
}
