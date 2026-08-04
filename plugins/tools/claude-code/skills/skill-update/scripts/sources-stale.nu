#!/usr/bin/env nu

# Show only stale or outdated sources
# A source is stale when current_version != latest_version, or last_checked is older than --days threshold
#
# Usage: nu sources-stale.nu [--days <int>] [--plugin <name>]
#        nu sources-stale.nu --self-test
#
# Output: table sorted by priority (high first), showing only stale entries
#
# On-demand, network-dependent operator tool (claude-skills-176). Deliberately
# NOT wired into `mise test`/`mise run ci` — CI has no credentials and must
# pass with zero external dependencies. Run manually via `mise sources:stale`.

use sources-lib.nu *
# Also imported module-qualified (below, unstarred) so the local
# `run-self-test` wrapper can call `sources-lib run-self-test` without
# colliding with its own name — a starred re-import of the same symbol
# would make the wrapper recurse into itself.
use sources-lib.nu

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

# classify-fetch-error, check-github-releases, check-hex-pm, check-crates-io,
# fetch-latest, and classify-staleness live in sources-lib.nu (claude-skills-211)
# — imported above via `use sources-lib.nu *`.

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

# classify-staleness lives in sources-lib.nu (claude-skills-211) — imported
# above via `use sources-lib.nu *`. Reused here only to derive the
# version_stale boolean below; this script's narrower job is "does this pin
# need an update", so no-releases/rate-limited/manual/error stay non-stale
# here — sources-check.nu and sources-report.nu surface those states for
# diagnosis instead.

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
        let skill        = $src.skills? | default [] | str join ","
        let name         = $src.name?             | default ""
        let current      = $src.current_version?  | default "unset"
        let priority     = $src.update_priority?   | default "medium"
        let method       = $src.check_method?     | default "manual"
        let notes        = $src.notes?            | default ""
        let last_checked = $src.last_checked?     | default ""

        let latest = fetch-latest $src
        let staleness = classify-staleness $current $latest
        let version_stale = $staleness == "yes" or $staleness == "unset"

        let date_stale = if $latest == "internal" { false } else { is-date-stale $last_checked $days }

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
                notes:        $notes
                last_checked: $last_checked
                _sort_key:    (priority-weight $priority)
            }
        } else {
            null
        }
    } | where { |r| $r != null }
}

# Delegates the shared classify-staleness/classify-fetch-error case table to
# sources-lib.nu (claude-skills-211), then runs this script's own
# version_stale derivation cases — the one piece of self-test logic that is
# genuinely specific to sources-stale.nu.
def run-self-test [] {
    let shared = (sources-lib run-self-test)
    mut failed = $shared.failed

    # version_stale derivation cases — this script's specific "does this need
    # an update" boolean, not the raw classify-staleness sentinel.
    let version_stale_cases = [
        {label: "unset counts as version_stale" staleness: "unset" want: true}
        {label: "yes counts as version_stale" staleness: "yes" want: true}
        {label: "no-pin does NOT count as version_stale" staleness: "no-pin" want: false}
        {label: "manual does NOT count as version_stale" staleness: "manual" want: false}
        {label: "no-releases does NOT count as version_stale" staleness: "no-releases" want: false}
    ]
    for c in $version_stale_cases {
        let got = ($c.staleness == "yes" or $c.staleness == "unset")
        if $got != $c.want {
            print $"(ansi red_bold)❌ version_stale derivation: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    if $failed {
        exit 1
    }
    let total = $shared.count + ($version_stale_cases | length)
    print $"(ansi green_bold)✅ sources-stale self-test passed \(($total) cases\)(ansi reset)"
    exit 0
}

def main [--days: int = 30, --plugin: string = "", --self-test] {
    if $self_test {
        run-self-test
    }

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

    let sorted = $stale_rows | sort-by _sort_key | select plugin skill source current latest priority reason notes last_checked

    print $"(ansi yellow_bold)Found ($sorted | length) stale source\(s\):(ansi reset)"
    print ""
    $sorted
}
