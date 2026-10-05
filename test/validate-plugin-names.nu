#!/usr/bin/env nu

# Offline reserved plugin name check. Rule and source: test/plugin-names.nu.
#
# Usage:
#   nu test/validate-plugin-names.nu [--root <dir>]
#
# Exit 1 when any name is error-level, 0 otherwise.

use plugin-names.nu *

def main [--root: string] {
    let repo_root = if $root == null { git rev-parse --show-toplevel | str trim } else { $root }
    let findings = (scan-manifests $repo_root)

    for f in $findings {
        print $"($f.level | str upcase) ($f.file): ($f.name): ($f.reason)"
    }

    let errors = ($findings | where level == "error" | length)
    let warnings = ($findings | where level == "warning" | length)
    print $"($errors) errors, ($warnings) warnings"
    if $errors > 0 { exit 1 }
}
