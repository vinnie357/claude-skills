#!/usr/bin/env nu

# Check all tracked sources for version updates
# Reads sources.toml files across all plugins and queries upstream APIs
#
# Usage: nu sources-check.nu [--plugin <name>]
#        nu sources-check.nu --self-test
#
# Output: table with columns: plugin | skill | source | current | latest | stale | priority | notes
#
# On-demand, network-dependent operator tool (claude-skills-176). Deliberately
# NOT wired into `mise test`/`mise run ci` — CI has no credentials and must
# pass with zero external dependencies. Run manually via `mise sources:check`.

# Resolve the repo root relative to this script's location
def repo-root [] {
    $env.FILE_PWD | path join ".." ".." ".." ".." ".." ".." | path expand
}

# Load marketplace.json and return plugins list
def load-marketplace [repo: string] {
    let mp_path = $"($repo)/.claude-plugin/marketplace.json"
    if not ($mp_path | path exists) {
        error make { msg: $"marketplace.json not found at ($mp_path)" }
    }
    open $mp_path
}

# Resolve a plugin's source path to an absolute directory path
def resolve-plugin-path [repo: string, source: any] {
    if ($source | describe) == "string" {
        # e.g. "./plugins/core" -> absolute path
        let rel = $source | str replace -r '^\./' ''
        $"($repo)/($rel)"
    } else {
        # External source object — not a local path, skip
        null
    }
}

# Find all sources.toml files for a given plugin directory
def find-sources-toml [plugin_dir: string] {
    let toml_path = $"($plugin_dir)/skills/sources.toml"
    if ($toml_path | path exists) {
        [$toml_path]
    } else {
        []
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
        [Authorization $"Bearer ($token)" User-Agent "sources-check.nu/1.0"]
    } else {
        [User-Agent "sources-check.nu/1.0"]
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
    let headers = [User-Agent "sources-check.nu/1.0 (claude-skills)"]
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

# Classify (current, latest) into a staleness sentinel. Pure function,
# self-tested below — no network, no I/O.
#
# claude-skills-176: `current_version = "unknown"` is a documented schema
# placeholder (test/validate-sources.nu's VERSION_SHAPE_RE accepts it as a
# literal) meaning "no pin recorded to compare against upstream", not a real
# version. Comparing it against `latest` made every such entry (152 in the
# corpus today) report false-positive drift. It classifies as "no-pin",
# distinct from "unset" (field genuinely absent) and "yes" (a real pin is
# behind).
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

# Process a single sources.toml file and return rows
def process-sources-toml [toml_path: string, plugin_name: string] {
    let data = try {
        open $toml_path
    } catch {
        print $"(ansi yellow)Warning: could not parse ($toml_path)(ansi reset)"
        return []
    }

    let sources = $data.sources? | default []
    if ($sources | is-empty) {
        return []
    }

    $sources | each { |src|
        let skill     = $src.skills? | default [] | str join ","
        let name      = $src.name?     | default ""
        let current   = $src.current_version? | default "unset"
        let priority  = $src.update_priority? | default "medium"
        let method    = $src.check_method? | default "manual"
        let notes     = $src.notes? | default ""
        let last_checked = $src.last_checked? | default ""

        print $"  Checking ($plugin_name)/($skill)/($name) via ($method)..."

        let latest = fetch-latest $src
        let stale = classify-staleness $current $latest

        {
            plugin:   $plugin_name
            skill:    $skill
            source:   $name
            current:  $current
            latest:   $latest
            stale:    $stale
            priority: $priority
            method:   $method
            notes:    $notes
            last_checked: $last_checked
        }
    }
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
    print $"(ansi green_bold)✅ sources-check self-test passed \(($staleness_cases | length) + ($fetch_error_cases | length) cases\)(ansi reset)"
    exit 0
}

def main [--plugin: string = "", --self-test] {
    if $self_test {
        run-self-test
    }

    let repo = repo-root

    print $"(ansi cyan_bold)Sources Version Check(ansi reset)"
    print $"Repo root: ($repo)"
    print ""

    let marketplace = load-marketplace $repo
    let plugins = $marketplace.plugins? | default []

    let filtered_plugins = if ($plugin | is-empty) {
        $plugins
    } else {
        $plugins | where name == $plugin
    }

    if ($filtered_plugins | is-empty) {
        if not ($plugin | is-empty) {
            print $"(ansi red)No plugin found with name: ($plugin)(ansi reset)"
            exit 1
        }
        print $"(ansi yellow)No plugins found in marketplace.(ansi reset)"
        exit 0
    }

    mut all_rows = []

    for pl in $filtered_plugins {
        let pl_name = $pl.name
        let pl_dir  = resolve-plugin-path $repo $pl.source

        if $pl_dir == null {
            continue
        }

        let toml_files = find-sources-toml $pl_dir

        if ($toml_files | is-empty) {
            continue
        }

        print $"(ansi green)Plugin: ($pl_name)(ansi reset)"

        for toml_file in $toml_files {
            let rows = process-sources-toml $toml_file $pl_name
            $all_rows = ($all_rows | append $rows)
        }
    }

    print ""

    if ($all_rows | is-empty) {
        print $"(ansi yellow)No sources.toml files found. Run sources-init.nu to bootstrap them.(ansi reset)"
        exit 0
    }

    # Render results table
    $all_rows | select plugin skill source current latest stale priority notes
}
