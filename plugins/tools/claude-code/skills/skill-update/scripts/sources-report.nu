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

# Classify a caught HTTP error's text into a specific latest-version sentinel.
# Pure function (string -> string), self-tested below — the network call
# stays at the boundary in check-github-releases; this only interprets the
# text nushell's `http get` catch already produced.
#
# claude-skills-176: a dead/404 release feed (repo has no GitHub Releases,
# e.g. a monorepo or unreleased tool) and a rate-limited/unauthenticated
# GitHub response both used to collapse into a generic "error", which reads
# identically to "the request itself failed" — no way to tell "this source
# will never have a releases feed" from "try again with a token". Six
# sources.toml entries across 5 plugins document a live 404 on
# `releases/latest` today (grep `notes` fields for "404" — allium's
# juxt-allium, github's actions-toolkit, claude-code's
# example-skills-repository and skills-cookbook, tweag's JSON-Schema-to-
# Nickel tool, runex's private-repo entry). All six are check_method=manual,
# so none reach this classifier live — the schema already routes 404-prone
# repos away from github-releases specifically to avoid this failure mode.
# This branch is proven only by the self-test below, not by live traffic;
# it exists for the day an entry is flipped to github-releases without
# re-checking the feed first.
def classify-fetch-error [err_text: string]: nothing -> string {
    if ($err_text | str contains "404") {
        "no-releases"
    } else if ($err_text | str contains "403") or ($err_text | str downcase | str contains "rate limit") {
        "rate-limited"
    } else {
        "error"
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
    } catch {|err|
        classify-fetch-error ($err.debug? | default ($err.msg? | default ""))
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
        "none" => { "internal" }
        _ => { "unknown-method" }
    }
}

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

# Classify (current, latest) into a staleness sentinel. Pure function,
# self-tested below — no network, no I/O.
#
# claude-skills-176: `current_version = "unknown"` is a documented schema
# placeholder (see test/validate-sources.nu's VERSION_SHAPE_RE — "unknown" is
# an accepted literal, not a missing value) meaning "no pin recorded to
# compare against upstream". Treating it as a real version made every one of
# these entries compare unequal to whatever `latest` resolved to and report
# false-positive drift. It must classify as "no-pin", distinct from "unset"
# (the field is genuinely absent) and from "yes" (a real pin is behind).
def classify-staleness [current: string, latest: string]: nothing -> string {
    if $latest == "internal" {
        "no"
    } else if $latest == "manual" {
        "manual"
    } else if $latest == "no-releases" {
        "no-releases"
    } else if $latest == "rate-limited" {
        "rate-limited"
    } else if $latest == "unknown" {
        "unknown"
    } else if $latest == "error" {
        "error"
    } else if $current == "unset" {
        "unset"
    } else if $current == "unknown" {
        "no-pin"
    } else if $current != $latest {
        "yes"
    } else {
        "no"
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

# Self-test for the pure classify-staleness / classify-fetch-error logic.
# Follows the house case-table pattern (run-self-test in
# test/validate-sources.nu): records with named fields, one got != want
# comparison per case. No network — proves the parsing/comparison logic
# independent of the HTTP boundary (classify-staleness never calls http get).
def run-self-test [] {
    mut failed = false

    let staleness_cases = [
        {label: "unknown pin is no-pin, not drift" current: "unknown" latest: "9.9.9" want: "no-pin"}
        {label: "unset pin is unset" current: "unset" latest: "9.9.9" want: "unset"}
        {label: "matching pins are current" current: "1.0.0" latest: "1.0.0" want: "no"}
        {label: "mismatched pins are stale" current: "1.0.0" latest: "1.1.0" want: "yes"}
        {label: "manual check_method never compared" current: "1.0.0" latest: "manual" want: "manual"}
        {label: "none check_method is internal, always current" current: "unknown" latest: "internal" want: "no"}
        {label: "dead/404 release feed is no-releases, not error" current: "1.0.0" latest: "no-releases" want: "no-releases"}
        {label: "rate-limited/unauthenticated is distinct from error" current: "1.0.0" latest: "rate-limited" want: "rate-limited"}
        {label: "hex-pm/crates-io package with zero releases" current: "1.0.0" latest: "unknown" want: "unknown"}
        {label: "generic fetch failure still reported as error" current: "1.0.0" latest: "error" want: "error"}
        {label: "unknown pin plus no-releases feed: feed status wins" current: "unknown" latest: "no-releases" want: "no-releases"}
    ]
    for c in $staleness_cases {
        let got = classify-staleness $c.current $c.latest
        if $got != $c.want {
            print $"(ansi red_bold)❌ classify-staleness: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    let fetch_error_cases = [
        {label: "404 body classifies as no-releases" text: "Requested file not found (404): \"https://api.github.com/repos/x/y/releases/latest\"" want: "no-releases"}
        {label: "403 status classifies as rate-limited" text: "Client error (403): API rate limit exceeded" want: "rate-limited"}
        {label: "rate limit phrase without 403 digits still matches" text: "GitHub secondary rate limit hit, retry later" want: "rate-limited"}
        {label: "unrelated network failure falls through to error" text: "Could not resolve host: api.github.com" want: "error"}
        {label: "empty error text falls through to error" text: "" want: "error"}
    ]
    for c in $fetch_error_cases {
        let got = classify-fetch-error $c.text
        if $got != $c.want {
            print $"(ansi red_bold)❌ classify-fetch-error: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ sources-report self-test passed \(($staleness_cases | length) + ($fetch_error_cases | length) cases\)(ansi reset)"
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
        print "| Plugin | Skill | Source | Current | Latest | Status | Priority |"
        print "| ------ | ----- | ------ | ------- | ------ | ------ | -------- |"
        for r in ($all_rows | where stale == "yes" | sort-by priority) {
            print (md-row $r)
            if not ($r.notes | is-empty) {
                print $"  - Notes: ($r.notes)"
            }
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
