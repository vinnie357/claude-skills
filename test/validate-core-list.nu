#!/usr/bin/env nu

# Validate that the mandatory core skill list has not drifted.
#
# The canonical copy lives in plugins/core/skills/agent-loop/SKILL.md under
# the "## Core Skills (Mandatory)" heading. Every satellite file must carry
# the same set of names in an actual LOAD LIST, not merely somewhere in its
# prose.
#
# Why structural, not substring: an earlier version checked
# `$content | str contains $name` over the whole file. When the mandatory
# list was trimmed from 10 names to 8, five satellites passed that check
# while their real load lists were stale, because the removed names still
# appeared in explanatory prose. Substring presence is not list membership.
#
# Two load-list grammars are recognised:
#
#   G1  names-only line — the whole line, after stripping list markers,
#       whitespace and backticks, is one or more skill-shaped names
#       separated by commas. Covers the canonical fenced block, the
#       comma-separated fences in the tier references, the mixed
#       /core: + /elixir: block in leader-spawn-example.md, the indented
#       bullets in the operator CLAUDE.md template, and the session-start
#       hook's one-name-per-line list.
#
#   G2  bullet whose FIRST token is a /core: name — covers commands/work.md,
#       whose bullets carry trailing annotations. The first-token rule is
#       what stops prose bullets (e.g. "- **Tracker state:** a repo tracked
#       by beads loads `/core:beads` ...") from being read as load lists.
#
# Lists are compared per contiguous RUN of list lines, not as a file-wide
# union of names. The union design admitted silent false passes: with a name
# deleted from the real list, a paren-annotated prose bullet or a fenced
# worked example elsewhere in the file put the name back into the union and
# the file passed. A run carrying fewer than 2 /core: names is ignored, which
# is what lets a lone prose mention exist without counting as a list. More
# than one qualifying run in a satellite is reported as ambiguous rather than
# guessed at.
#
# Both drift directions are checked against that single run: a canonical name
# MISSING from it, and an EXTRA /core: name present in it but absent from the
# canonical block.
#
# What this still cannot see:
#   - A load list written in a form neither grammar recognises. validator.md:7
#     is such a case (inline numbered item), acceptable only because it is an
#     excluded partial — see EXCLUDED_PARTIAL.
#   - A satellite whose real list and a worked example both match the canonical
#     set exactly. That passes, and correctly so — both are right.
#   - Prose mentions, by design, so restraint/SKILL.md and restraint/README.md
#     may discuss /core:tdd freely.
#
# Usage:
#   nu test/validate-core-list.nu

const CANONICAL_FILE = "plugins/core/skills/agent-loop/SKILL.md"
const CANONICAL_HEADING = "## Core Skills (Mandatory)"
const EXPECTED_COUNT = 10

# One definition of each name shape, shared by the canonical extractor and
# both grammars. Keeping these separate previously let them disagree on case
# and digits, so a name like /core:s3-tools parsed in a satellite but was
# dropped from the canonical block, surfacing as a confusing count mismatch.
const CORE_NAME = '^/core:[a-z][a-z0-9-]*$'
const SKILL_NAME = '^/[a-z][a-z0-9-]*:[a-z][a-z0-9-]*$'

const SATELLITES = [
  # The canonical block lives in this file and parses as a load list, so the
  # missing-name direction is vacuous here (canonical is always a subset of
  # itself). Its entry earns its place on the EXTRA direction and on the
  # single-run rule.
  "plugins/core/skills/agent-loop/SKILL.md"
  "plugins/core/skills/agent-loop/references/team-leader.md"
  "plugins/core/skills/agent-loop/references/sub-team-leader.md"
  "plugins/core/skills/agent-loop/references/agent-worker.md"
  "plugins/core/skills/agent-loop/references/leader-spawn-example.md"
  "plugins/core/commands/work.md"
  "plugins/core/hooks/session-start.sh"
  "plugins/tools/claude-code/templates/CLAUDE.md"
]

# Files that carry a deliberate SUBSET of the core stack, so the
# missing-name direction does not apply to them. Whether per-tier subsets
# are legitimate at all is claude-skills-125; until that lands, list them
# here with the reason rather than silently omitting them.
const EXCLUDED_PARTIAL = [
  "plugins/core/skills/agent-loop/references/validator.md"   # 3 names, inline numbered item
  "plugins/core/skills/agent-loop/references/fix-agent.md"   # 4 names
]

def main [] {
  let repo_root = (git rev-parse --show-toplevel | str trim)
  cd $repo_root

  let canonical_names = (extract-canonical-names $CANONICAL_FILE)

  if ($canonical_names | length) != $EXPECTED_COUNT {
    print $"(ansi red_bold)❌ Expected ($EXPECTED_COUNT) canonical core skill names, found ($canonical_names | length)(ansi reset)"
    print $"  Found: ($canonical_names | str join ', ')"
    exit 1
  }

  print $"🔍 Canonical core list \(($canonical_names | length) names\): ($canonical_names | str join ', ')\n"

  mut failures = []

  for satellite in $SATELLITES {
    let path = ($repo_root | path join $satellite)
    if not ($path | path exists) {
      $failures = ($failures | append { file: $satellite, missing: ["<file not found>"], extra: [], ambiguous: [] })
      continue
    }

    let runs = (find-load-list-runs $path)

    if ($runs | is-empty) {
      $failures = ($failures | append { file: $satellite, missing: ["<no load list recognised>"], extra: [], ambiguous: [] })
      continue
    }

    # Exactly one load list per satellite. A second one is ambiguous: the
    # check cannot know which is authoritative, and tolerating extras is what
    # let a worked example mask the real list.
    if ($runs | length) > 1 {
      $failures = ($failures | append {
        file: $satellite,
        missing: [],
        extra: [],
        ambiguous: ($runs | each { |r| $"[($r | str join ', ')]" })
      })
      continue
    }

    let found = ($runs | first)
    let missing = ($canonical_names | where { |name| $name not-in $found })
    let extra = ($found | where { |name| $name not-in $canonical_names })

    if (($missing | length) > 0) or (($extra | length) > 0) {
      $failures = ($failures | append { file: $satellite, missing: $missing, extra: $extra, ambiguous: [] })
    } else {
      print $"  ✓ ($satellite)"
    }
  }

  if ($failures | length) > 0 {
    print $"\n(ansi red_bold)❌ Core list drift detected:(ansi reset)\n"
    for failure in $failures {
      if ($failure.missing | is-not-empty) {
        print $"  • ($failure.file): missing from load list — ($failure.missing | str join ', ')"
      }
      if ($failure.extra | is-not-empty) {
        print $"  • ($failure.file): extra in load list — ($failure.extra | str join ', ')"
      }
      if ($failure.ambiguous | is-not-empty) {
        print $"  • ($failure.file): ($failure.ambiguous | length) separate load lists found, expected 1 — ($failure.ambiguous | str join ' and ')"
        print $"    A worked example or a prose bullet run alongside the real list is ambiguous; the check cannot tell which is authoritative."
      }
    }
    print $"\nThe canonical block is ($CANONICAL_FILE) under \"($CANONICAL_HEADING)\"."
    exit 1
  }

  print $"\n(ansi green_bold)✅ Core list is consistent across all satellite load lists(ansi reset)"
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
  | where { |line| $line =~ $CORE_NAME }
}

# Find the load LISTS in a file, as contiguous runs of list lines.
#
# Comparing a file-wide UNION of names was the original design and it admitted
# silent false passes: with a name deleted from the real list, any second
# occurrence elsewhere in the file restored it to the union and the file
# passed. Both a paren-annotated prose bullet and a fenced worked example are
# natural idioms that did this. Runs fix it — a name has to appear in the list
# itself, not merely somewhere in the file.
#
# A run is a maximal sequence of consecutive lines that each parse as a list
# line under G1 or G2. Runs carrying fewer than 2 /core: names are ignored:
# that is what keeps a lone prose bullet or a one-name example from counting
# as a list.
#
# Returns a list of runs, each a sorted list of /core: names.
def find-load-list-runs [file: string] {
  let lines = (open --raw $file | lines)

  mut runs = []
  mut current = []

  for line in $lines {
    let hits = ([...(names-only-line $line) ...(bullet-leading-name $line)] | uniq)

    if ($hits | is-empty) {
      # Run ended. Keep it only if it looks like a list rather than a mention.
      if ($current | length) >= 2 {
        $runs = ($runs | append [($current | uniq | sort)])
      }
      $current = []
    } else {
      $current = ($current | append $hits)
    }
  }

  if ($current | length) >= 2 {
    $runs = ($runs | append [($current | uniq | sort)])
  }

  $runs
}

# G1: the entire line is one or more skill-shaped names, comma-separated.
# Returns the /core: subset, or [] when the line is not a names-only line.
def names-only-line [line: string] {
  let bare = ($line
    | str trim
    | str replace -r '^[-*]\s+' ''
    | str trim
    | str replace -a '`' ''
    | str trim
    | str replace -r ',$' ''
    | str trim)

  if ($bare | is-empty) { return [] }

  let tokens = ($bare | split row "," | each { |t| $t | str trim } | where { |t| $t | is-not-empty })

  if ($tokens | is-empty) { return [] }

  # Every token must be skill-shaped for this to be a load list. A mixed
  # /core: + /elixir: block qualifies; a code-fence info string or a prose
  # fragment does not.
  let all_skill_shaped = ($tokens | all { |t| $t =~ $SKILL_NAME })

  if not $all_skill_shaped { return [] }

  $tokens | where { |t| $t | str starts-with "/core:" }
}

# G2: a bullet whose FIRST token is a /core: name, allowing a parenthesised
# annotation after it. Returns that single name, or [].
#
# The remainder after the name must be empty or start with "(" — that is what
# separates a load-list entry from a prose bullet ABOUT a skill. Real
# annotated entries in commands/work.md are paren-shaped ("- `/core:bees`
# (the tracker)"), while documentation bullets use an em-dash ("- `/core:tdd`
# — standing discipline, not pulled"). Without this test, any future prose
# bullet in that idiom would be counted as a load-list entry, which could
# MASK a genuinely missing name — the same false-pass class this check exists
# to remove.
def bullet-leading-name [line: string] {
  let trimmed = ($line | str trim)

  if not ($trimmed =~ '^[-*]\s') { return [] }

  let after_marker = ($trimmed | str replace -r '^[-*]\s+' '' | str trim | str replace -a '`' '' | str trim)
  let tokens = ($after_marker | split row " ")
  let first_token = ($tokens | get -o 0 | default "" | str trim | str replace -r '[,.]$' '')

  if not ($first_token =~ $CORE_NAME) { return [] }

  let remainder = ($tokens | skip 1 | str join " " | str trim)

  if ($remainder | is-empty) or ($remainder | str starts-with "(") {
    [$first_token]
  } else {
    []
  }
}
