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
# claude-skills-176: a dead/404 release feed and a rate-limited/
# unauthenticated GitHub response both used to collapse into a generic
# "error" — no way to tell "this source will never have a releases feed"
# from "try again with a token".
#
# claude-skills-176 Gate 3 (F3): match `(404)`/`(403)` WITH the parens, not
# bare digits. `$err.debug` embeds nushell's own `Span[<byte-offsets>]` from
# the failing call site, and a bare `str contains "404"` matches those
# offsets too — reviewer forced a DNS-failure text whose span happened to
# contain "404"/"403" as plain digits and got misclassified. nushell's HTTP
# error text always wraps the real status as `(404):`/`(403):` (see the
# self-test fixtures below, copied from an actual caught error); a byte
# offset is never rendered inside parens, so requiring them is structural,
# not just narrower. Does not fire on live traffic today, so this was
# latent, not observed.
#
# hex-pm and crates-io still fall through to a bare `catch { "error" }` —
# neither wraps a status code the same way, and GitHub's secondary
# (undocumented-shape) 429 rate limit is not classified separately from a
# generic error either. Both are known gaps, not silently assumed handled.
def classify-fetch-error [err_text: string]: nothing -> string {
    if ($err_text | str contains "(404)") {
        "no-releases"
    } else if ($err_text | str contains "(403)") or ($err_text | str downcase | str contains "rate limit") {
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
        [Authorization $"Bearer ($token)" User-Agent "sources-stale.nu/1.0"]
    } else {
        [User-Agent "sources-stale.nu/1.0"]
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
        "none" => { "internal" }
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

# Classify (current, latest) into a staleness sentinel. Pure function,
# self-tested below — no network, no I/O. Reused here only to derive the
# version_stale boolean below; this script's narrower job is "does this pin
# need an update", so no-releases/rate-limited/manual/error stay non-stale
# here — sources-check.nu and sources-report.nu surface those states for
# diagnosis instead.
#
# claude-skills-176: `current_version = "unknown"` is a documented schema
# placeholder (test/validate-sources.nu's VERSION_SHAPE_RE accepts it as a
# literal) meaning "no pin recorded to compare against upstream", not a real
# version. The prior `$current != $latest` fallthrough compared it anyway,
# reporting every one of these entries (152 in the corpus today) as
# false-positive drift.
#
# claude-skills-176 Gate 3 (F4): the equality check strips a leading `v` from
# BOTH sides before comparing — only for the comparison, the displayed
# `current`/`latest` values are untouched. `check-github-releases` already
# strips `v` from the upstream tag, but `current_version` in sources.toml is
# free text and sometimes keeps it (e.g. "v0.0.0"), so "v0.0.0" vs "0.0.0"
# compared unequal and reported false-positive drift for an entry that is
# actually current.
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
    } else if ($current | str replace -r '^v' '') != ($latest | str replace -r '^v' '') {
        "yes"
    } else {
        "no"
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

# Self-test for the pure classify-staleness / classify-fetch-error logic.
# Follows the house case-table pattern (run-self-test in
# test/validate-sources.nu). No network — proves the parsing/comparison
# logic independent of the HTTP boundary.
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
        {label: "v-prefixed pin matching a v-stripped latest is current, not stale" current: "v0.0.0" latest: "0.0.0" want: "no"}
        {label: "v-prefixed pin genuinely behind is still stale" current: "v0.0.0" latest: "0.1.0" want: "yes"}
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
        {label: "bare digits in a byte-offset span do NOT collide with a real (404)" text: "NetworkFailure { msg: \"Could not resolve host: api.github.com\", span: Span[160039..160404] }" want: "error"}
        {label: "bare digits spelling 403 in a span do NOT collide with a real (403)" text: "NetworkFailure { msg: \"connection reset\", span: Span[140033..140403] }" want: "error"}
    ]
    for c in $fetch_error_cases {
        let got = classify-fetch-error $c.text
        if $got != $c.want {
            print $"(ansi red_bold)❌ classify-fetch-error: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

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
    let total = ($staleness_cases | length) + ($fetch_error_cases | length) + ($version_stale_cases | length)
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
