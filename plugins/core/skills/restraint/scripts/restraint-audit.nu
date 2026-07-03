#!/usr/bin/env nu

# Find every `restraint:` marker across the repository.
#
# A `restraint:` marker is a deliberate-simplification breadcrumb (see the
# restraint skill's "The `restraint:` comment" section) — a comment naming a
# known shortcut and its upgrade path. This script is a grep, not a stored
# ledger: it surfaces outstanding markers on demand so a reviewer can weigh
# them against the ladder; it does not judge whether each one is still
# justified. That judgment (over-engineering review against the current
# `git diff`) is model work — see the paired `/core:restraint-audit` command.
#
# Uses only nu + git — no ripgrep, no external grep dependency.
#
# Usage:
#   nu restraint-audit.nu [--path <dir>]

const MARKER_PATTERN = '^\s*(#|//|--)\s*restraint:\s*(.*)$'

def main [
  --path: string = "."  # Directory to scan (defaults to repo root via git)
] {
  let repo_root = (git rev-parse --show-toplevel | str trim)
  let scan_root = if $path == "." { $repo_root } else { $path }

  cd $scan_root
  let files = (git ls-files | lines | where { |f| ($f | str length) > 0 })

  let hits = ($files
    | each { |file|
        let full_path = ($scan_root | path join $file)
        if not ($full_path | path exists) {
          []
        } else {
          try {
            open --raw $full_path
            | lines
            | enumerate
            | where { |it| $it.item =~ $MARKER_PATTERN }
            | each { |it| { file: $file, line: ($it.index + 1), marker: ($it.item | str trim) } }
          } catch {
            []
          }
        }
      }
    | flatten
  )

  if ($hits | length) == 0 {
    print "No restraint: markers found."
    return $hits
  }

  print $"Found ($hits | length) restraint: marker\(s\):\n"
  for hit in $hits {
    print $"  ($hit.file):($hit.line): ($hit.marker)"
  }

  $hits
}
