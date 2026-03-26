#!/usr/bin/env nu

# Validate all source URLs in sources.toml files are accessible
# Uses HTTP HEAD requests and reports status per URL
#
# Usage: nu sources-validate-urls.nu [--plugin <name>]
#
# Output: table with columns: plugin | skill | source | url | status | notes

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

# Classify HTTP status code into a human-readable status
def classify-status [code: int] {
    if $code >= 200 and $code < 300 {
        "pass"
    } else if $code >= 300 and $code < 400 {
        "redirect"
    } else {
        "fail"
    }
}

# Perform an HTTP HEAD check on a URL and return a result record
def check-url [plugin: string, skill: string, source_name: string, url: string] {
    if ($url | is-empty) {
        return null
    }

    let result = try {
        # http head returns headers as a record; a successful return means 2xx
        http head $url
        {
            plugin: $plugin
            skill:  $skill
            source: $source_name
            url:    $url
            status: "pass"
            notes:  "OK"
        }
    } catch { |err|
        let msg = $err.msg? | default "request failed"
        let status = if ($msg | str contains "redirect") {
            "redirect"
        } else if ($msg | str contains "404") or ($msg | str contains "not found") {
            "fail"
        } else {
            "error"
        }
        {
            plugin: $plugin
            skill:  $skill
            source: $source_name
            url:    $url
            status: $status
            notes:  ($msg | str substring 0..80)
        }
    }

    $result
}

# Process a single sources.toml file and return URL check results
def process-sources-toml [toml_path: string, plugin_name: string] {
    let data = try {
        open $toml_path
    } catch {
        print $"(ansi yellow)Warning: could not parse ($toml_path)(ansi reset)"
        return []
    }

    let sources = $data.sources? | default []
    mut rows = []

    for src in $sources {
        let skill       = $src.skill?         | default ""
        let name        = $src.name?          | default ""
        let url         = $src.url?           | default ""
        let releases_url = $src.releases_url? | default ""

        if not ($url | is-empty) {
            print $"  HEAD ($url)"
            let row = check-url $plugin_name $skill $name $url
            if $row != null {
                $rows = ($rows | append $row)
            }
        }

        if not ($releases_url | is-empty) {
            print $"  HEAD ($releases_url)"
            let row = check-url $plugin_name $skill $"($name) [releases]" $releases_url
            if $row != null {
                $rows = ($rows | append $row)
            }
        }
    }

    $rows
}

def main [--plugin: string = ""] {
    let repo = repo-root

    print $"(ansi cyan_bold)Source URL Validation(ansi reset)"
    print $"Repo root: ($repo)"
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

    mut all_rows = []

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

        print $"(ansi green)Plugin: ($pl_name)(ansi reset)"
        let rows = process-sources-toml $toml_path $pl_name
        $all_rows = ($all_rows | append $rows)
    }

    print ""

    if ($all_rows | is-empty) {
        print $"(ansi yellow)No sources.toml files found with URL entries.(ansi reset)"
        exit 0
    }

    # Summary counts
    let total    = $all_rows | length
    let passing  = $all_rows | where status == "pass"     | length
    let redirect = $all_rows | where status == "redirect" | length
    let failing  = $all_rows | where status == "fail"     | length
    let errors   = $all_rows | where status == "error"    | length

    print $"(ansi cyan_bold)Summary:(ansi reset) ($total) URLs checked — (ansi green)($passing) pass(ansi reset) | (ansi yellow)($redirect) redirect(ansi reset) | (ansi red)($failing) fail  ($errors) error(ansi reset)"
    print ""

    # Full table
    $all_rows | select plugin skill source url status notes
}
