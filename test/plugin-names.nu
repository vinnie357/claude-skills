# Offline check of the reserved plugin name rule.
#
# Rule source: the `name` field of
# https://code.claude.com/docs/en/plugins/manifest-reference
#
# Names are compared case-insensitively, with any run of `-`, `_` or `.`
# collapsed to one separator.

const ERROR_REASON = "reserved: it passes as one of Anthropic's own"
const WARNING_REASON = "reads as one of Anthropic's own"

# Returns {level: "error"|"warning"|"ok", reason: string}; reason is "" for ok.
export def reserved-name-verdict [name: string]: nothing -> record {
    let n = ($name | str replace --all --regex '[-_.]+' '-')
    let reserved = (
        ($n =~ '(?i)^(claude|anthropic|anthropics|cc-plugin)-')
        or ($n =~ '(?i)^(claude|anthropic|anthropics|claude-code|claude-mods)$')
        or ($n =~ '(?i)official-?(claude|anthropic)|(claude|anthropic)-?official')
    )
    if $reserved {
        {level: "error", reason: $ERROR_REASON}
    } else if ($n =~ '(?i)(^|-)(claude|anthropic|anthropics)(-|$)') {
        {level: "warning", reason: $WARNING_REASON}
    } else {
        {level: "ok", reason: ""}
    }
}

# Non-ok findings as {file, name, level, reason}; file is relative to repo_root.
export def scan-manifests [repo_root: string]: nothing -> list {
    let mkt = ($repo_root | path join ".claude-plugin" "marketplace.json")
    let root_plugin = ($repo_root | path join ".claude-plugin" "plugin.json")
    let nested = (glob ($repo_root | path join "plugins" "*" "*" ".claude-plugin" "plugin.json"))

    let mkt_names = (open $mkt | get plugins | get name | each { |n| {file: $mkt, name: $n} })
    let plugin_files = (
        (if ($root_plugin | path exists) { [$root_plugin] } else { [] }) | append $nested
    )
    let plugin_names = ($plugin_files | each { |f| {file: $f, name: (open $f | get name)} })

    $mkt_names | append $plugin_names | each { |e|
        let v = (reserved-name-verdict $e.name)
        {
            file: ($e.file | path relative-to $repo_root)
            name: $e.name
            level: $v.level
            reason: $v.reason
        }
    } | where level != "ok"
}
