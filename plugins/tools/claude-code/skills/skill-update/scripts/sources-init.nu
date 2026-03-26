#!/usr/bin/env nu

# Bootstrap a sources.toml from an existing sources.md file
# Parses skill sections, source subsections, URLs, and dates from the markdown
# and writes a TOML file with check_method = "manual" as default
#
# Usage: nu sources-init.nu <plugin-name> [--dry-run]

# Resolve the repo root relative to this script's location
def repo-root [] {
    $env.FILE_PWD | path join ".." ".." ".." ".." ".." ".." ".." | path expand
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
    let lines = open $md_path | lines

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
    let name_slug = to-slug $s.name
    let url_line = if not ($s.url | is-empty) {
        $"url           = \"($s.url)\"\n"
    } else {
        $"# url         = \"\"\n"
    }
    let date_line = if not ($s.date | is-empty) {
        $"last_checked  = \"($s.date)\"\n"
    } else {
        $"# last_checked = \"\"\n"
    }

    $"[[sources]]\nskill         = \"($s.skill)\"\nname          = \"($s.name)\"\n($url_line)check_method  = \"manual\"\ncurrent_version = \"unknown\"\npriority      = \"normal\"\n($date_line)"
}

# Generate TOML content string from parsed sources list
def generate-toml [plugin_name: string, sources: list] {
    let today = (date now | format date "%Y-%m-%d")
    let count = $sources | length

    let header = $"# sources.toml — machine-readable source tracking for plugin: ($plugin_name)
# Generated by sources-init.nu on ($today)
# Edit check_method and repo/package/crate fields to enable automated version checks.
# Valid check_method values: github-releases | hex-pm | crates-io | manual

\[meta\]
plugin       = \"($plugin_name)\"
generated_at = \"($today)\"
source_count = ($count)

"

    let blocks = $sources | enumerate | each { |it|
        render-source-block $it.item $it.index
    }

    $header + ($blocks | str join "\n")
}

def main [plugin_name: string, --dry-run] {
    let repo = repo-root

    print $"(ansi cyan_bold)Bootstrapping sources.toml for plugin: ($plugin_name)(ansi reset)"
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

    if ($toml_path | path exists) and not $dry_run {
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
        print $"  [$($s.skill)] ($s.name) — ($url_display)"
    }
    print ""

    let toml_content = generate-toml $plugin_name $sources

    if $dry_run {
        print $"(ansi cyan_bold)--- Dry run: would write to ($toml_path) ---(ansi reset)"
        print ""
        print $toml_content
        print $"(ansi cyan_bold)--- End dry run ---(ansi reset)"
    } else {
        $toml_content | save --force $toml_path
        print $"(ansi green)Written: ($toml_path)(ansi reset)"
        print ""
        print "Next steps:"
        print "  1. Open the generated sources.toml"
        print "  2. Set check_method for each source:"
        print "       github-releases  → add: repo = \"owner/repo\""
        print "       hex-pm           → add: package = \"package_name\""
        print "       crates-io        → add: crate = \"crate_name\""
        print "       manual           → no additional fields needed"
        print "  3. Set current_version to the version you currently depend on"
        print "  4. Run: nu sources-check.nu --plugin ($plugin_name)"
    }
}
