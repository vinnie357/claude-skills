#!/usr/bin/env nu

# Generate a full markdown update report for all tracked sources
# Suitable for pasting into a GitHub issue body
#
# Usage: nu sources-report.nu [--plugin <name>]
#        nu sources-report.nu --self-test
#
# Output: markdown to stdout (redirect to a file or pipe to pbcopy)
#
# On-demand, network-dependent operator tool (claude-skills-176). Deliberately
# NOT wired into `mise test`/`mise run ci` — CI has no credentials and must
# pass with zero external dependencies. Run manually via `mise sources:report`.

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
# and fetch-latest live in sources-lib.nu (claude-skills-211) — imported
# above via `use sources-lib.nu *`.

# Render a stale indicator emoji for markdown
def stale-badge [stale: string] {
    match $stale {
        "yes"          => "🔴 stale"
        "no"           => "🟢 current"
        "manual"       => "🔵 manual"
        "internal"     => "⚪ no upstream"
        "no-pin"       => "❔ no pin to compare"
        "no-releases"  => "⚫ no releases feed"
        "rate-limited" => "🟠 rate-limited/unauthenticated"
        "unknown"      => "❔ upstream has no releases"
        "error"        => "⚠️ error"
        "unset"        => "❓ unset"
        _              => $stale
    }
}

# classify-staleness lives in sources-lib.nu (claude-skills-211) — imported
# above via `use sources-lib.nu *`.

# Process a sources.toml and return enriched rows
def process-sources-toml [toml_path: string, plugin_name: string] {
    let data = try {
        open $toml_path
    } catch {
        return []
    }

    let sources = $data.sources? | default []

    $sources | each { |src|
        let skill    = $src.skills? | default [] | str join ","
        let name     = $src.name?            | default ""
        let current  = $src.current_version? | default "unset"
        let priority = $src.update_priority?  | default "medium"
        let method   = $src.check_method?    | default "manual"
        let url      = $src.url?             | default ""
        let notes    = $src.notes?           | default ""
        let last_checked = $src.last_checked? | default "unknown"

        let latest = fetch-latest $src
        let stale = classify-staleness $current $latest

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
            notes:        $notes
            last_checked: $last_checked
        }
    }
}

# sanitize-notes-cell lives in sources-lib.nu (claude-skills-211) — imported
# above via `use sources-lib.nu *`.

# Render markdown table row
def md-row [r: record] {
    let badge = stale-badge $r.stale
    let link = if not ($r.url | is-empty) {
        $"[($r.source)]\(($r.url)\)"
    } else {
        $r.source
    }
    let notes_cell = sanitize-notes-cell $r.notes 80
    $"| ($r.plugin) | ($r.skill) | ($link) | ($r.current) | ($r.latest) | ($badge) | ($r.priority) | ($notes_cell) |"
}

# Delegates to sources-lib.nu's shared case table (claude-skills-211) — this
# script has no cases of its own beyond what the shared module covers
# (classify-staleness, classify-fetch-error, and sanitize-notes-cell — the
# md-row/notes-cell rendering used only by this script — are all shared).
def run-self-test [] {
    let result = (sources-lib run-self-test)
    if $result.failed {
        exit 1
    }
    print $"(ansi green_bold)✅ sources-report self-test passed \(($result.count) cases\)(ansi reset)"
    exit 0
}

def main [--plugin: string = "", --self-test] {
    if $self_test {
        run-self-test
    }

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
    mut plugin_meta = []

    for pl in $filtered {
        let pl_name = $pl.name
        let pl_dir  = resolve-plugin-path $repo $pl.source

        if $pl_dir == null { continue }

        let toml_path = $"($pl_dir)/skills/sources.toml"
        if not ($toml_path | path exists) { continue }

        print -e $"  Processing ($pl_name)..."
        let rows = process-sources-toml $toml_path $pl_name
        $all_rows = ($all_rows | append $rows)

        let meta = (try { open $toml_path | get -o meta } catch { null })
        if $meta != null {
            $plugin_meta = ($plugin_meta | append {
                plugin: $pl_name
                reviewed_at: ($meta.reviewed_at_plugin_version? | default "unknown")
                plugin_version: ($pl.version? | default "unknown")
                last_full_check: ($meta.last_full_check? | default "unknown")
            })
        }
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

    let total        = $all_rows | length
    let current      = $all_rows | where stale == "no"           | length
    let stale        = $all_rows | where stale == "yes"          | length
    let manual       = $all_rows | where stale == "manual"       | length
    let no_pin       = $all_rows | where stale == "no-pin"       | length
    let no_releases  = $all_rows | where stale == "no-releases"  | length
    let rate_limited = $all_rows | where stale == "rate-limited" | length
    let errored      = $all_rows | where stale == "error"        | length

    print $"| Metric | Count |"
    print $"| ------ | ----- |"
    print $"| Total sources tracked | ($total) |"
    print $"| Up to date | ($current) |"
    print $"| Stale \(needs update\) | ($stale) |"
    print $"| Manual check required | ($manual) |"
    print $"| No pin recorded \(current_version = unknown\) | ($no_pin) |"
    print $"| No upstream releases feed | ($no_releases) |"
    print $"| Rate-limited / unauthenticated | ($rate_limited) |"
    print $"| Check errors | ($errored) |"
    print ""

    if $stale_count > 0 {
        print $"## Stale Sources"
        print ""
        print $"> The following ($stale_count) source\(s\) have newer versions available."
        print ""
        print "| Plugin | Skill | Source | Current | Latest | Status | Priority | Notes |"
        print "| ------ | ----- | ------ | ------- | ------ | ------ | -------- | ----- |"
        for r in ($all_rows | where stale == "yes" | sort-by priority) {
            print (md-row $r)
        }
        print ""
    }

    # ─── All sources table ─────────────────────────────────────────────────────
    print "## All Tracked Sources"
    print ""
    print "| Plugin | Skill | Source | Current | Latest | Status | Priority | Notes |"
    print "| ------ | ----- | ------ | ------- | ------ | ------ | -------- | ----- |"
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
        let meta_row = ($plugin_meta | where plugin == $pl_name)
        if ($meta_row | is-not-empty) {
            let m = ($meta_row | first)
            let pending = if $m.reviewed_at != $m.plugin_version { " **Review pending.**" } else { "" }
            print $"> Sources reviewed at plugin version ($m.reviewed_at); plugin.json is now ($m.plugin_version). Last full check: ($m.last_full_check).($pending)"
            print ""
        }
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
