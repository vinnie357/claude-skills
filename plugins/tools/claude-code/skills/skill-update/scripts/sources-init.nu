#!/usr/bin/env nu

# Bootstrap a DRAFT sources.toml from an existing sources.md file
# Parses skill sections, source subsections, URLs, and dates from the markdown
# and prints a TOML draft with check_method = "manual" as default.
#
# NOT A TRUSTED MIGRATOR. The heading-to-skill-directory mapping is a naive
# slug of the markdown heading — it is NOT resolved against the plugin's
# plugin.json skill directories (that resolution, plus NEEDS-JUDGMENT
# markers for unresolved headings, is deferred to the PR2/PR3 migration
# waves). Every `skills = [...]` entry in the output must be hand-verified
# against the owning plugin's plugin.json before the file is committed.
#
# Default mode PRINTS ONLY — nothing is written to disk unless --write is
# passed. This is the honest default for a tool proven to misattribute.
#
# Usage: nu sources-init.nu <plugin-name> [--write]

# Resolve the repo root relative to this script's location
def repo-root [] {
    $env.FILE_PWD | path join ".." ".." ".." ".." ".." ".." | path expand
}

# Load marketplace.json
def load-marketplace [repo: string] {
    let mp_path = $"($repo)/.claude-plugin/marketplace.json"
    if not ($mp_path | path exists) {
        error make { msg: $"marketplace.json not found at ($mp_path)" }
    }
    open $mp_path
}

# Resolve plugin source path to absolute directory
def resolve-plugin-path [repo: string, source: any] {
    if ($source | describe) == "string" {
        let rel = $source | str replace -r '^\./' ''
        $"($repo)/($rel)"
    } else {
        null
    }
}

# Convert a heading string to a kebab-case slug used as a name
def to-slug [text: string] {
    $text
        | str downcase
        | str replace -ra '[^a-z0-9\s-]' ''
        | str replace -ra '\s+' '-'
        | str replace -ra '-+' '-'
        | str trim -c '-'
}

# Extract a URL from a markdown bullet like: - **URL**: https://...
def extract-url [line: string] {
    let m = $line | parse -r '\*\*URL\*\*:\s*(?P<url>https?://\S+)'
    if ($m | length) > 0 {
        $m | first | get url
    } else {
        ""
    }
}

# Extract a date from a markdown bullet like: - **Date Accessed**: 2025-11-15
def extract-date [line: string] {
    let m = $line | parse -r '\*\*Date Accessed\*\*:\s*(?P<date>\d{4}-\d{2}-\d{2})'
    if ($m | length) > 0 {
        $m | first | get date
    } else {
        ""
    }
}

# Parse sources.md into structured records
# Returns list of: { skill, name, url, date }
def parse-sources-md [md_path: string] {
    let lines = open --raw $md_path | lines

    mut current_skill = "general"
    mut current_source = ""
    mut current_url = ""
    mut current_date = ""
    mut sources = []

    for line in $lines {
        let trimmed = $line | str trim

        # ## Heading → skill section
        if ($trimmed | str starts-with "## ") {
            # Save previous source if any
            if not ($current_source | is-empty) {
                $sources = ($sources | append {
                    skill: $current_skill
                    name:  $current_source
                    url:   $current_url
                    date:  $current_date
                })
                $current_source = ""
                $current_url = ""
                $current_date = ""
            }
            let heading = $trimmed | str replace -r '^#{1,2}\s+' ''
            # Skip known non-skill sections
            if $heading not-in ["Plugin Information", "Project Context", "Implementation Approach", "Overall Goals"] {
                $current_skill = to-slug $heading
            }
            continue
        }

        # ### Heading → source entry
        if ($trimmed | str starts-with "### ") {
            # Save previous source if any
            if not ($current_source | is-empty) {
                $sources = ($sources | append {
                    skill: $current_skill
                    name:  $current_source
                    url:   $current_url
                    date:  $current_date
                })
            }
            $current_source = $trimmed | str replace -r '^#{1,3}\s+' ''
            $current_url = ""
            $current_date = ""
            continue
        }

        # Extract URL from bullet lines
        if ($trimmed | str starts-with "- **URL**:") or ($trimmed | str starts-with "- **Url**:") {
            $current_url = extract-url $trimmed
            continue
        }

        # Extract date from bullet lines
        if ($trimmed | str starts-with "- **Date Accessed**:") {
            $current_date = extract-date $trimmed
            continue
        }
    }

    # Flush last source
    if not ($current_source | is-empty) {
        $sources = ($sources | append {
            skill: $current_skill
            name:  $current_source
            url:   $current_url
            date:  $current_date
        })
    }

    # Filter out empty entries
    $sources | where { |s| not ($s.name | is-empty) }
}

# Render a single [[sources]] TOML block as a string
def render-source-block [s: record, index: int] {
    let skill_slug = to-slug $s.skill
    let url_line = if not ($s.url | is-empty) {
        $"url = \"($s.url)\"\n"
    } else {
        $"# url = \"\"  # NEEDS-JUDGMENT: no URL parsed for this entry\n"
    }
    let date_line = if not ($s.date | is-empty) {
        $"last_checked = \"($s.date)\"\n"
    } else {
        $"last_checked = \"unknown\"\n"
    }

    $"[[sources]]\nskills = [\"($skill_slug)\"]  # NEEDS-JUDGMENT: verify against plugin.json skill dirs\nname = \"($s.name)\"\n($url_line)check_method = \"manual\"\ncurrent_version = \"unknown\"\nversion_constraint = \"semver\"\nupdate_priority = \"medium\"\n($date_line)"
}

# Generate TOML content string from parsed sources list
def generate-toml [plugin_name: string, sources: list] {
    let today = (date now | format date "%Y-%m-%d")

    let header = $"# DRAFT - generated by sources-init.nu on ($today). NOT VALIDATED, NOT TRUSTED.
# Every skills = [...] list and every NEEDS-JUDGMENT marker must be resolved
# by a human/agent reading sources.md before this file is committed.
#
# sources.toml — structured source-of-truth for plugin: ($plugin_name)
# Edit check_method and repo/package/crate fields to enable automated version checks.
# Valid check_method values: github-releases | hex-pm | crates-io | manual | none
# `mise test:sources` will reject this file until every NEEDS-JUDGMENT marker
# is resolved and skills = [...] holds only real plugin.json skill directories.

[meta]
plugin = \"($plugin_name)\"
reviewed_at_plugin_version = \"unknown\"
last_full_check = \"unknown\"

"

    let blocks = $sources | enumerate | each { |it|
        render-source-block $it.item $it.index
    }

    $header + ($blocks | str join "\n")
}

def main [plugin_name: string, --write] {
    let repo = repo-root

    print $"(ansi cyan_bold)Bootstrapping DRAFT sources.toml for plugin: ($plugin_name)(ansi reset)"
    print $"Repo root: ($repo)"
    print ""

    # Find the plugin in the marketplace
    let marketplace = load-marketplace $repo
    let plugins = $marketplace.plugins? | default []
    let matches = $plugins | where name == $plugin_name

    if ($matches | is-empty) {
        print $"(ansi red)Error: plugin '($plugin_name)' not found in marketplace.json(ansi reset)"
        print ""
        print "Available plugins:"
        $plugins | get name | each { |n| print $"  - ($n)" }
        exit 1
    }

    let pl = $matches | first
    let pl_dir = resolve-plugin-path $repo $pl.source

    if $pl_dir == null {
        print $"(ansi red)Error: plugin '($plugin_name)' has an external source and cannot be bootstrapped locally.(ansi reset)"
        exit 1
    }

    let md_path   = $"($pl_dir)/skills/sources.md"
    let toml_path = $"($pl_dir)/skills/sources.toml"

    if not ($md_path | path exists) {
        print $"(ansi red)Error: sources.md not found at ($md_path)(ansi reset)"
        print "Create a sources.md first, then re-run this script."
        exit 1
    }

    if ($toml_path | path exists) and $write {
        print $"(ansi yellow)Warning: ($toml_path) already exists.(ansi reset)"
        print "Overwrite? [y/N] " --no-newline
        let answer = input
        if ($answer | str trim | str downcase) != "y" {
            print "Aborted."
            exit 0
        }
    }

    print $"Parsing: ($md_path)"
    let sources = parse-sources-md $md_path

    if ($sources | is-empty) {
        print $"(ansi yellow)No sources found in ($md_path).(ansi reset)"
        print "Ensure sources.md has ## skill and ### source headings with - **URL**: lines."
        exit 1
    }

    print $"Found ($sources | length) source\(s\):"
    for s in $sources {
        let url_display = if not ($s.url | is-empty) { $s.url } else { "(no URL)" }
        print $"  [($s.skill)] ($s.name) — ($url_display)"
    }
    print ""

    let toml_content = generate-toml $plugin_name $sources

    if not $write {
        print $"(ansi cyan_bold)--- DRAFT \(pass --write to save to ($toml_path)\) ---(ansi reset)"
        print ""
        print $toml_content
        print $"(ansi cyan_bold)--- End draft ---(ansi reset)"
        print ""
        print $"(ansi yellow)This draft is NOT validated. Resolve every NEEDS-JUDGMENT marker and skills = [...] entry against ($plugin_name)'s plugin.json before committing, then run: mise test:sources(ansi reset)"
    } else {
        $toml_content | save --force $toml_path
        print $"(ansi green)Written DRAFT: ($toml_path)(ansi reset)"
        print ""
        print "Next steps (this file is NOT yet valid — mise test:sources will reject it):"
        print "  1. Resolve every NEEDS-JUDGMENT marker — verify skills = [...] against plugin.json skill dirs"
        print "  2. Set check_method for each source:"
        print "       github-releases  → add: github_repo = \"owner/repo\""
        print "       hex-pm           → add: hex_package = \"package_name\""
        print "       crates-io        → add: crate_name = \"crate_name\""
        print "       manual           → no additional fields needed"
        print "       none             → remove url/current_version/version_constraint/update_priority; notes required"
        print "  3. Set current_version to the version you currently depend on"
        print "  4. Run: mise test:sources"
        print "  5. Run: nu sources-check.nu --plugin ($plugin_name)"
    }
}
