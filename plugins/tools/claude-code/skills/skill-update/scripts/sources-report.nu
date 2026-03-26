#!/usr/bin/env nu

# Generate a full markdown update report for all tracked sources
# Suitable for pasting into a GitHub issue body
#
# Usage: nu sources-report.nu [--plugin <name>]
#
# Output: markdown to stdout (redirect to a file or pipe to pbcopy)

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

# Check latest version via github-releases API
def check-github-releases [repo: string] {
    let url = $"https://api.github.com/repos/($repo)/releases/latest"
    let token = $env.GITHUB_TOKEN? | default ""
    let headers = if ($token | is-not-empty) {
        [Authorization $"Bearer ($token)" User-Agent "sources-report.nu/1.0"]
    } else {
        [User-Agent "sources-report.nu/1.0"]
    }
    try {
        let response = http get -H $headers $url
        let tag = $response.tag_name? | default ""
        $tag | str replace -r '^v' ''
    } catch {
        "error"
    }
}

# Check latest version via hex.pm API
def check-hex-pm [package: string] {
    let url = $"https://hex.pm/api/packages/($package)"
    try {
        let response = http get $url
        let releases = $response.releases? | default []
        if ($releases | length) > 0 {
            $releases | first | get version? | default "unknown"
        } else {
            "unknown"
        }
    } catch {
        "error"
    }
}

# Check latest version via crates.io API
def check-crates-io [crate_name: string] {
    let url = $"https://crates.io/api/v1/crates/($crate_name)"
    let headers = [User-Agent "sources-report.nu/1.0 (claude-skills)"]
    try {
        let response = http get -H $headers $url
        $response.crate?.max_version? | default "unknown"
    } catch {
        "error"
    }
}

# Dispatch version check by method
def fetch-latest [source: record] {
    let method = $source.check_method? | default "manual"
    match $method {
        "github-releases" => {
            let repo = $source.github_repo? | default ""
            if ($repo | is-empty) { "error" } else { check-github-releases $repo }
        }
        "hex-pm" => {
            let pkg = $source.hex_package? | default ""
            if ($pkg | is-empty) { "error" } else { check-hex-pm $pkg }
        }
        "crates-io" => {
            let crate_name = $source.crate_name? | default ""
            if ($crate_name | is-empty) { "error" } else { check-crates-io $crate_name }
        }
        "manual" => { "manual" }
        _ => { "unknown-method" }
    }
}

# Render a stale indicator emoji for markdown
def stale-badge [stale: string] {
    match $stale {
        "yes"    => "🔴 stale"
        "no"     => "🟢 current"
        "manual" => "🔵 manual"
        "error"  => "⚠️ error"
        "unset"  => "❓ unset"
        _        => $stale
    }
}

# Process a sources.toml and return enriched rows
def process-sources-toml [toml_path: string, plugin_name: string] {
    let data = try {
        open $toml_path
    } catch {
        return []
    }

    let sources = $data.sources? | default []

    $sources | each { |src|
        let skill    = $src.skill?           | default ""
        let name     = $src.name?            | default ""
        let current  = $src.current_version? | default "unset"
        let priority = $src.update_priority?  | default "medium"
        let method   = $src.check_method?    | default "manual"
        let url      = $src.url?             | default ""
        let last_checked = $src.last_checked? | default "unknown"

        let latest = fetch-latest $src

        let stale = if $latest == "manual" {
            "manual"
        } else if $latest == "error" {
            "error"
        } else if $current == "unset" {
            "unset"
        } else if $current != $latest {
            "yes"
        } else {
            "no"
        }

        {
            plugin:       $plugin_name
            skill:        $skill
            source:       $name
            url:          $url
            current:      $current
            latest:       $latest
            stale:        $stale
            priority:     $priority
            method:       $method
            last_checked: $last_checked
        }
    }
}

# Render markdown table row
def md-row [r: record] {
    let badge = stale-badge $r.stale
    let link = if not ($r.url | is-empty) {
        $"[($r.source)]\(($r.url)\)"
    } else {
        $r.source
    }
    $"| ($r.plugin) | ($r.skill) | ($link) | ($r.current) | ($r.latest) | ($badge) | ($r.priority) |"
}

def main [--plugin: string = ""] {
    let repo = repo-root

    # Suppress progress output when redirected (stderr vs stdout)
    print -e $"(ansi cyan)Gathering source data...(ansi reset)"

    let marketplace = load-marketplace $repo
    let plugins = $marketplace.plugins? | default []

    let filtered = if ($plugin | is-empty) {
        $plugins
    } else {
        $plugins | where name == $plugin
    }

    mut all_rows = []
    mut plugin_groups: record = {}

    for pl in $filtered {
        let pl_name = $pl.name
        let pl_dir  = resolve-plugin-path $repo $pl.source

        if $pl_dir == null { continue }

        let toml_path = $"($pl_dir)/skills/sources.toml"
        if not ($toml_path | path exists) { continue }

        print -e $"  Processing ($pl_name)..."
        let rows = process-sources-toml $toml_path $pl_name
        $all_rows = ($all_rows | append $rows)
    }

    # ─── Render markdown ───────────────────────────────────────────────────────

    let today = (date now | format date "%Y-%m-%d")
    let stale_count = $all_rows | where stale == "yes" | length

    print $"# Skill Sources Update Report"
    print ""
    print $"Generated: ($today)"
    if not ($plugin | is-empty) {
        print $"Plugin filter: `($plugin)`"
    }
    print ""

    # ─── Summary table ─────────────────────────────────────────────────────────
    print "## Summary"
    print ""

    let total   = $all_rows | length
    let current = $all_rows | where stale == "no"     | length
    let stale   = $all_rows | where stale == "yes"    | length
    let manual  = $all_rows | where stale == "manual" | length
    let errored = $all_rows | where stale == "error"  | length

    print $"| Metric | Count |"
    print $"| ------ | ----- |"
    print $"| Total sources tracked | ($total) |"
    print $"| Up to date | ($current) |"
    print $"| Stale (needs update) | ($stale) |"
    print $"| Manual check required | ($manual) |"
    print $"| Check errors | ($errored) |"
    print ""

    if $stale_count > 0 {
        print $"## Stale Sources"
        print ""
        print $"> The following ($stale_count) source\(s\) have newer versions available."
        print ""
        print "| Plugin | Skill | Source | Current | Latest | Status | Priority |"
        print "| ------ | ----- | ------ | ------- | ------ | ------ | -------- |"
        for r in ($all_rows | where stale == "yes" | sort-by priority) {
            print (md-row $r)
        }
        print ""
    }

    # ─── All sources table ─────────────────────────────────────────────────────
    print "## All Tracked Sources"
    print ""
    print "| Plugin | Skill | Source | Current | Latest | Status | Priority |"
    print "| ------ | ----- | ------ | ------- | ------ | ------ | -------- |"
    for r in $all_rows {
        print (md-row $r)
    }
    print ""

    # ─── Per-plugin sections ───────────────────────────────────────────────────
    print "## Per-Plugin Details"
    print ""

    let plugin_names = $all_rows | get plugin | uniq
    for pl_name in $plugin_names {
        let pl_rows = $all_rows | where plugin == $pl_name
        let pl_stale = $pl_rows | where stale == "yes" | length

        print $"### ($pl_name)"
        print ""
        if $pl_stale > 0 {
            print $"> ($pl_stale) stale source\(s\)"
            print ""
        }
        print "| Skill | Source | Current | Latest | Status |"
        print "| ----- | ------ | ------- | ------ | ------ |"
        for r in $pl_rows {
            let badge = stale-badge $r.stale
            let link = if not ($r.url | is-empty) {
                $"[($r.source)]\(($r.url)\)"
            } else {
                $r.source
            }
            print $"| ($r.skill) | ($link) | ($r.current) | ($r.latest) | ($badge) |"
        }
        print ""
    }

    if ($all_rows | is-empty) {
        print $"_No sources.toml files found. Run `sources-init.nu` to bootstrap them._"
        print ""
    }
}
