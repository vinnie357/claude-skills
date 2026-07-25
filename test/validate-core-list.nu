#!/usr/bin/env nu

# Validate that the mandatory core skill list has not drifted.
#
# The canonical copy lives in plugins/core/skills/agent-loop/SKILL.md under
# the "## Core Skills (Mandatory)" heading. Every other site that lists the
# mandatory core stack (spawn-prompt templates, the session-start hook, the
# operator CLAUDE.md template) must still mention every name from that
# canonical list somewhere in its own text.
#
# Known limitation: this only catches a satellite that is MISSING a
# canonical name (drift by omission). It does not catch a satellite that
# has grown EXTRA `/core:*` names beyond the canonical set (drift by
# addition) — that direction is not checked here.
#
# Usage:
#   nu test/validate-core-list.nu

const CANONICAL_FILE = "plugins/core/skills/agent-loop/SKILL.md"
const CANONICAL_HEADING = "## Core Skills (Mandatory)"

const SATELLITES = [
  "plugins/core/skills/agent-loop/SKILL.md"
  "plugins/core/skills/agent-loop/references/team-leader.md"
  "plugins/core/skills/agent-loop/references/sub-team-leader.md"
  "plugins/core/skills/agent-loop/references/agent-worker.md"
  "plugins/core/skills/agent-loop/references/leader-spawn-example.md"
  "plugins/core/commands/work.md"
  "plugins/core/hooks/session-start.sh"
  "plugins/tools/claude-code/templates/CLAUDE.md"
]

def main [] {
  let repo_root = (git rev-parse --show-toplevel | str trim)
  cd $repo_root

  let canonical_names = (extract-canonical-names $CANONICAL_FILE)

  if ($canonical_names | length) != 10 {
    print $"(ansi red_bold)❌ Expected 10 canonical core skill names, found ($canonical_names | length)(ansi reset)"
    print $"  Found: ($canonical_names | str join ', ')"
    exit 1
  }

  print $"🔍 Canonical core list \(($canonical_names | length) names\): ($canonical_names | str join ', ')\n"

  mut failures = []

  for satellite in $SATELLITES {
    let path = ($repo_root | path join $satellite)
    if not ($path | path exists) {
      $failures = ($failures | append { file: $satellite, missing: ["<file not found>"] })
      continue
    }

    let content = (open --raw $path)
    let missing = ($canonical_names | where { |name| not ($content | str contains $name) })

    if ($missing | length) > 0 {
      $failures = ($failures | append { file: $satellite, missing: $missing })
    } else {
      print $"  ✓ ($satellite)"
    }
  }

  if ($failures | length) > 0 {
    print $"\n(ansi red_bold)❌ Core list drift detected:(ansi reset)\n"
    for failure in $failures {
      print $"  • ($failure.file): missing ($failure.missing | str join ', ')"
    }
    exit 1
  }

  print $"\n(ansi green_bold)✅ Core list is consistent across all satellites(ansi reset)"
  exit 0
}

# Extract the /core:* names listed in the canonical block of the given file,
# between the canonical heading and the next level-2 (## ) heading.
def extract-canonical-names [file: string] {
  let lines = (open --raw $file | lines)
  let heading_idx = ($lines | enumerate | where { |it| $it.item == $CANONICAL_HEADING } | get -o 0.index)

  if $heading_idx == null {
    print $"(ansi red_bold)❌ Canonical heading '($CANONICAL_HEADING)' not found in ($file)(ansi reset)"
    exit 1
  }

  let rest = ($lines | skip ($heading_idx + 1))
  let next_heading_offset = ($rest | enumerate | where { |it| $it.item | str starts-with "## " } | get -o 0.index)
  let block = if $next_heading_offset == null { $rest } else { $rest | first $next_heading_offset }

  $block
  | each { |line| $line | str trim }
  | where { |line| $line =~ '^/core:[a-zA-Z-]+$' }
}
