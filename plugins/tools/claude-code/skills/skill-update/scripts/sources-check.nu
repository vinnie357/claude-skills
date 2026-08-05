#!/usr/bin/env nu

# Check all tracked sources for version updates
# Reads sources.toml files across all plugins and queries upstream APIs
#
# Usage: nu sources-check.nu [--plugin <name>]
#        nu sources-check.nu --self-test
#
# Output: table with columns: plugin | skill | source | current | latest | stale | eol | priority | notes
#
# On-demand, network-dependent operator tool (claude-skills-176). Deliberately
# NOT wired into `mise test`/`mise run ci` — CI has no credentials and must
# pass with zero external dependencies. Run manually via `mise sources:check`.
#
# claude-skills-237: `eol` is a SEPARATE column from `stale`, deliberately.
# claude-skills-174 decided "behind latest" is not itself a finding worth
# flagging (a pin can be intentionally behind); claude-skills-226 added
# check-endoflife-status specifically to answer a different question — "is
# this release LINE still supported at all" — which claude-skills-237 exists
# to surface. Folding eol into stale would quietly reverse the 174 policy by
# making "not latest" read as a problem again. They stay two columns.

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

# classify-fetch-error, check-github-releases, check-hex-pm, check-crates-io,
# fetch-latest, and classify-staleness live in sources-lib.nu (claude-skills-211)
# — imported above via `use sources-lib.nu *`.

# Pure: render check-endoflife-status's `eol` field (bool | "unknown") into
# the display string for this script's `eol` column, or "n/a" for any
# check_method other than endoflife-date (the only method with an EOL
# concept at all — a github-releases/crates-io/etc. source was never asked
# this question, so "n/a" reads honestly as "not applicable" rather than
# silently defaulting to a value that looks like a real answer).
export def format-eol-column [method: string, eol: any]: nothing -> string {
    if $method != "endoflife-date" {
        "n/a"
    } else if ($eol | describe) == "bool" {
        if $eol { "yes" } else { "no" }
    } else {
        "unknown"
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

        # claude-skills-237: endoflife-date sources get their EOL sentinel
        # from the SAME network call fetch-latest would otherwise make via
        # check-endoflife-date (which discards it) — calling
        # check-endoflife-status directly here, instead of ALSO calling
        # fetch-latest, keeps this at one HTTP request per source, matching
        # the "one network call serves both" contract check-endoflife-status
        # documents in sources-lib.nu.
        let eol_product = $src.eol_product? | default ""
        let latest_and_eol = if $method == "endoflife-date" and ($eol_product | is-not-empty) {
            let status = check-endoflife-status $eol_product
            {latest: $status.latest, eol: $status.eol}
        } else {
            {latest: (fetch-latest $src), eol: "n/a"}
        }
        let latest = $latest_and_eol.latest
        let stale = classify-staleness $current $latest
        let eol = format-eol-column $method $latest_and_eol.eol

        {
            plugin:   $plugin_name
            skill:    $skill
            source:   $name
            current:  $current
            latest:   $latest
            stale:    $stale
            eol:      $eol
            priority: $priority
            method:   $method
            notes:    $notes
            last_checked: $last_checked
        }
    }
}

# Delegates to sources-lib.nu's shared case table (claude-skills-211) and
# folds in this script's own format-eol-column cases (claude-skills-237) —
# same pattern sources-stale.nu uses for its version_stale derivation.
def run-self-test [] {
    let shared = (sources-lib run-self-test)
    mut failed = $shared.failed
    mut count = $shared.count

    # claude-skills-237: format-eol-column cases. centos/nodejs shapes match
    # check-endoflife-status's own documented live-verified behavior
    # (centos eol=true, nodejs eol=false) — reused here as the true/false
    # fixture pair rather than re-deriving new ones.
    let eol_column_cases = [
        {label: "a fully-EOL cycle (centos-shaped) reports yes" method: "endoflife-date" eol: true want: "yes"}
        {label: "a supported cycle (nodejs-shaped) reports no" method: "endoflife-date" eol: false want: "no"}
        {label: "an unparseable eol date reports unknown, not a silent false" method: "endoflife-date" eol: "unknown" want: "unknown"}
        {label: "a non-endoflife-date method reports n/a regardless of eol value" method: "github-releases" eol: true want: "n/a"}
        {label: "a manual method reports n/a" method: "manual" eol: "unknown" want: "n/a"}
    ]
    for c in $eol_column_cases {
        $count += 1
        let got = format-eol-column $c.method $c.eol
        if $got != $c.want {
            print $"(ansi red_bold)❌ format-eol-column: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ sources-check self-test passed \(($count) cases\)(ansi reset)"
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
    $all_rows | select plugin skill source current latest stale eol priority notes
}
