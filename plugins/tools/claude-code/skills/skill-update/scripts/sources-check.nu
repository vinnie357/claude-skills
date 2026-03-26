#!/usr/bin/env nu

# Check all tracked sources for version updates
# Reads sources.toml files across all plugins and queries upstream APIs
#
# Usage: nu sources-check.nu [--plugin <name>]
#
# Output: table with columns: plugin | skill | source | current | latest | stale | priority

# Resolve the repo root relative to this script's location
def repo-root [] {
    $env.FILE_PWD | path join ".." ".." ".." ".." ".." ".." ".." | path expand
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
        _ => { "unknown-method" }
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
        let skill     = $src.skill?    | default ""
        let name      = $src.name?     | default ""
        let current   = $src.current_version? | default "unset"
        let priority  = $src.update_priority? | default "medium"
        let method    = $src.check_method? | default "manual"
        let last_checked = $src.last_checked? | default ""

        print $"  Checking ($plugin_name)/($skill)/($name) via ($method)..."

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
            plugin:   $plugin_name
            skill:    $skill
            source:   $name
            current:  $current
            latest:   $latest
            stale:    $stale
            priority: $priority
            method:   $method
            last_checked: $last_checked
        }
    }
}

def main [--plugin: string = ""] {
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
    $all_rows | select plugin skill source current latest stale priority
}
