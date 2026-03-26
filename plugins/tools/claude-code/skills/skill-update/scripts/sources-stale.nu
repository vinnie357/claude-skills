#!/usr/bin/env nu

# Show only stale or outdated sources
# A source is stale when current_version != latest_version, or last_checked is older than --days threshold
#
# Usage: nu sources-stale.nu [--days <int>] [--plugin <name>]
#
# Output: table sorted by priority (high first), showing only stale entries

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
        [Authorization $"Bearer ($token)" User-Agent "sources-stale.nu/1.0"]
    } else {
        [User-Agent "sources-stale.nu/1.0"]
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
    let headers = [User-Agent "sources-stale.nu/1.0 (claude-skills)"]
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

# Map priority string to sort weight (lower = higher priority)
def priority-weight [p: string] {
    match $p {
        "critical" => 0
        "high"     => 1
        "normal"   => 2
        "low"      => 3
        _          => 4
    }
}

# Check whether a date string is older than N days from today
def is-date-stale [date_str: string, days: int] {
    if ($date_str | is-empty) {
        return true
    }
    try {
        let checked = $date_str | into datetime
        let now     = (date now)
        let diff    = ($now - $checked)
        # diff is a duration; compare to threshold in seconds
        let threshold_secs = $days * 86400
        ($diff | into int) > ($threshold_secs * 1_000_000_000)
    } catch {
        true
    }
}

# Process a single sources.toml and return only stale rows
def process-sources-toml [toml_path: string, plugin_name: string, days: int] {
    let data = try {
        open $toml_path
    } catch {
        print $"(ansi yellow)Warning: could not parse ($toml_path)(ansi reset)"
        return []
    }

    let sources = $data.sources? | default []

    $sources | each { |src|
        let skill        = $src.skill?            | default ""
        let name         = $src.name?             | default ""
        let current      = $src.current_version?  | default "unset"
        let priority     = $src.update_priority?   | default "medium"
        let method       = $src.check_method?     | default "manual"
        let last_checked = $src.last_checked?     | default ""

        let latest = fetch-latest $src

        let version_stale = if $latest in ["manual", "error", "unknown", "unknown-method"] {
            false
        } else if $current == "unset" {
            true
        } else {
            $current != $latest
        }

        let date_stale = is-date-stale $last_checked $days

        if $version_stale or $date_stale {
            let reason = if $version_stale and $date_stale {
                "version+date"
            } else if $version_stale {
                "version"
            } else {
                "date"
            }
            {
                plugin:       $plugin_name
                skill:        $skill
                source:       $name
                current:      $current
                latest:       $latest
                priority:     $priority
                reason:       $reason
                last_checked: $last_checked
                _sort_key:    (priority-weight $priority)
            }
        } else {
            null
        }
    } | where { |r| $r != null }
}

def main [--days: int = 30, --plugin: string = ""] {
    let repo = repo-root

    print $"(ansi cyan_bold)Stale Sources Report(ansi reset)"
    print $"Staleness threshold: ($days) days | Repo: ($repo)"
    print ""

    let marketplace = load-marketplace $repo
    let plugins = $marketplace.plugins? | default []

    let filtered = if ($plugin | is-empty) {
        $plugins
    } else {
        $plugins | where name == $plugin
    }

    if ($filtered | is-empty) {
        if not ($plugin | is-empty) {
            print $"(ansi red)No plugin found with name: ($plugin)(ansi reset)"
            exit 1
        }
        print $"(ansi yellow)No plugins found in marketplace.(ansi reset)"
        exit 0
    }

    mut stale_rows = []

    for pl in $filtered {
        let pl_name = $pl.name
        let pl_dir  = resolve-plugin-path $repo $pl.source

        if $pl_dir == null {
            continue
        }

        let toml_path = $"($pl_dir)/skills/sources.toml"
        if not ($toml_path | path exists) {
            continue
        }

        let rows = process-sources-toml $toml_path $pl_name $days
        $stale_rows = ($stale_rows | append $rows)
    }

    if ($stale_rows | is-empty) {
        print $"(ansi green)All sources are up to date. No stale entries found.(ansi reset)"
        exit 0
    }

    let sorted = $stale_rows | sort-by _sort_key | select plugin skill source current latest priority reason last_checked

    print $"(ansi yellow_bold)Found ($sorted | length) stale source\(s\):(ansi reset)"
    print ""
    $sorted
}
