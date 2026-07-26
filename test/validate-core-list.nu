#!/usr/bin/env nu

# Validate that the mandatory core skill list has not drifted.
#
# The canonical copy lives in plugins/core/skills/agent-loop/SKILL.md under
# the "## Core Skills (Mandatory)" heading. Every satellite file must carry
# the same set of names in an actual LOAD LIST, not merely somewhere in its
# prose. (Substring presence over the whole file was the original check; when
# the list was trimmed from 10 names to 8, five satellites passed while their
# real load lists were stale, because the removed names lingered in prose.)
#
# Structure of the check, per satellite:
#
#   1. GRAMMAR — a load-list line is a names-only line: after stripping list
#      markers, whitespace and backticks, the line is one or more skill-shaped
#      names separated by commas. A contiguous RUN of such lines carrying 2+
#      /core: names is a load list; anything else (prose, annotated bullets,
#      fence delimiters) is not.
#
#   2. EVERY RUN MUST MATCH — each run is compared to the canonical set
#      independently, both directions (missing canonical name / extra /core:
#      name). A file-wide union admitted silent false passes: a stale worked
#      example or a prose bullet elsewhere in the file patched a deleted name
#      back into the union. leader-spawn-example.md exists to carry worked
#      examples, so this is a live risk, not hypothetical.
#
#   3. ANCHOR — each satellite registers a regex for the lead-in line that
#      sits directly above its operative load list. The anchor must match
#      exactly once, and the first line after it that is neither blank nor a
#      fence delimiter must BEGIN a qualifying run. Without this, the check
#      only proved "at least one canonical run exists and no visible run
#      disagrees" — the operative list could be deleted outright, or
#      annotated into invisibility (em-dash bullets fail the grammar), and
#      CI stayed green. Anchoring is ADDITIVE: rule 2 still applies to every
#      run, anchored or not.
#
#   4. SWEEP — every git-tracked .md/.sh file NOT registered as a satellite
#      fails if it carries a run with EXPECTED_COUNT - 2 or more CANONICAL
#      names. A file carrying (nearly) the full stack is a de-facto ninth
#      satellite and must be registered, or it drifts unchecked. Overlap with
#      the canonical set is the discriminator — several files legitimately
#      list 5 non-canonical or partial /core: stacks and must stay silent.
#
# Known limits, all loud or deliberate:
#   - A blank line inside one logical list splits it into two runs and the
#     partial runs are rejected — a false FAIL that surfaces explicitly,
#     never a silent pass.
#   - Prose mentions are ignored by design; restraint/SKILL.md may discuss
#     /core:tdd freely.
#   - Files carrying a deliberate SUBSET of the stack (fewer than
#     EXPECTED_COUNT - 2 canonical names) are invisible to the sweep.
#     Whether per-tier subsets are legitimate at all is claude-skills-125;
#     today references/fix-agent.md (4 names) relies on this, and
#     references/validator.md's inline numbered list (3 names) is a form the
#     grammar does not parse at all.
#
# Usage:
#   nu test/validate-core-list.nu
#   nu test/validate-core-list.nu --self-test

const CANONICAL_FILE = "plugins/core/skills/agent-loop/SKILL.md"
const CANONICAL_HEADING = "## Core Skills (Mandatory)"
const EXPECTED_COUNT = 10

# One definition of each name shape, shared by the canonical extractor and
# the grammar. Keeping these separate previously let them disagree on case
# and digits, so a name like /core:s3-tools parsed in a satellite but was
# dropped from the canonical block, surfacing as a confusing count mismatch.
const CORE_NAME = '^/core:[a-z][a-z0-9-]*$'
const SKILL_NAME = '^/[a-z][a-z0-9-]*:[a-z][a-z0-9-]*$'

# Each satellite pairs the file with the anchor regex for the line DIRECTLY
# above its operative load list (blank lines and fence delimiters may sit
# between). If a lead-in is reworded, the check fails naming the expected
# regex — update the wording here in the same change.
const SATELLITES = [
  # The canonical block lives in this file and parses as a load list, so the
  # missing-name direction is vacuous here (canonical is always a subset of
  # itself). Its entry earns its place on the EXTRA direction and the anchor.
  { path: "plugins/core/skills/agent-loop/SKILL.md"
    anchor: "Every agent at every tier loads these before any work" }
  { path: "plugins/core/skills/agent-loop/references/team-leader.md"
    anchor: "Load core skills" }
  { path: "plugins/core/skills/agent-loop/references/sub-team-leader.md"
    anchor: "Load core skills" }
  { path: "plugins/core/skills/agent-loop/references/agent-worker.md"
    anchor: "Load core skills" }
  { path: "plugins/core/skills/agent-loop/references/leader-spawn-example.md"
    anchor: "## Load skills" }
  { path: "plugins/core/commands/work.md"
    anchor: "Invoke the Skill tool for each by exact name" }
  { path: "plugins/core/hooks/session-start.sh"
    anchor: "invoke each of these by exact name" }
  { path: "plugins/tools/claude-code/templates/CLAUDE.md"
    anchor: "instruct team members/tasks to always load these core skills first" }
]

def main [--self-test] {
  if $self_test {
    self-test
    return
  }

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
    let path = ($repo_root | path join $satellite.path)
    if not ($path | path exists) {
      $failures = ($failures | append { file: $satellite.path, errors: ["file not found"], missing: [], extra: [], lists: [] })
      continue
    }

    let result = (check-satellite (open --raw $path | lines) $satellite.anchor $canonical_names)

    if (($result.errors | is-not-empty) or ($result.missing | is-not-empty) or ($result.extra | is-not-empty)) {
      $failures = ($failures | append ($result | insert file $satellite.path))
    } else {
      print $"  ✓ ($satellite.path)"
    }
  }

  let sweep_violations = (sweep-unregistered $canonical_names)

  if (($failures | length) > 0) or (($sweep_violations | length) > 0) {
    if ($failures | length) > 0 {
      print $"\n(ansi red_bold)❌ Core list drift detected:(ansi reset)\n"
      for failure in $failures {
        for err in $failure.errors {
          print $"  • ($failure.file): ($err)"
        }
        if ($failure.missing | is-not-empty) {
          print $"  • ($failure.file): missing from load list — ($failure.missing | str join ', ')"
        }
        if ($failure.extra | is-not-empty) {
          print $"  • ($failure.file): extra in load list — ($failure.extra | str join ', ')"
        }
        if ($failure.lists | is-not-empty) {
          print $"    ($failure.lists | length) separate lists parsed in this file; every one must match canonical — ($failure.lists | str join ' and ')"
        }
      }
    }
    if ($sweep_violations | length) > 0 {
      print $"\n(ansi red_bold)❌ Unregistered file\(s\) carry a near-complete core load list:(ansi reset)\n"
      for v in $sweep_violations {
        print $"  • ($v.file): ($v.names | str join ', ')"
      }
      print $"\nRegister the file in SATELLITES \(with an anchor\) in test/validate-core-list.nu, or trim the list."
    }
    print $"\nThe canonical block is ($CANONICAL_FILE) under \"($CANONICAL_HEADING)\"."
    exit 1
  }

  print $"\n(ansi green_bold)✅ Core list is consistent across all satellite load lists(ansi reset)"
  exit 0
}

# Extract the /core:* names listed in the canonical block of the given file,
# between the canonical heading and the closing fence of the first fenced
# block after it. (Terminating at the next "## " heading was wrong: "### ..."
# subheadings do not match it, and the parsed block absorbed bare names from
# the following subsection.)
def extract-canonical-names [file: string] {
  let lines = (open --raw $file | lines)
  let heading_idx = ($lines | enumerate | where { |it| $it.item == $CANONICAL_HEADING } | get -o 0.index)

  if $heading_idx == null {
    print $"(ansi red_bold)❌ Canonical heading '($CANONICAL_HEADING)' not found in ($file)(ansi reset)"
    exit 1
  }

  let rest = ($lines | skip ($heading_idx + 1))
  let fence_open = ($rest | enumerate | where { |it| ($it.item | str trim) | str starts-with "```" } | get -o 0.index)

  if $fence_open == null {
    print $"(ansi red_bold)❌ No fenced block found after '($CANONICAL_HEADING)' in ($file)(ansi reset)"
    exit 1
  }

  let after_fence = ($rest | skip ($fence_open + 1))
  let fence_close = ($after_fence | enumerate | where { |it| ($it.item | str trim) | str starts-with "```" } | get -o 0.index)

  if $fence_close == null {
    print $"(ansi red_bold)❌ Unterminated fenced block after '($CANONICAL_HEADING)' in ($file)(ansi reset)"
    exit 1
  }

  let names = ($after_fence
    | first $fence_close
    | each { |line| $line | str trim }
    | where { |line| $line =~ $CORE_NAME })

  # A duplicate is a defect, not padding. Without this, dropping one name and
  # duplicating another holds EXPECTED_COUNT steady while the real stack shrinks
  # — the exact trim this guard exists to force intent on.
  if ($names | length) != ($names | uniq | length) {
    let dupes = ($names | uniq -d)
    print $"(ansi red_bold)❌ Duplicate name\(s\) in the canonical block of ($file): ($dupes | str join ', ')(ansi reset)"
    exit 1
  }

  $names
}

# Validate one satellite's content: anchor uniqueness, run adjacency to the
# anchor, and every-run-must-match. Returns
# { errors: [...], missing: [...], extra: [...], lists: [...] }.
# `errors` carries the anchor/adjacency hard failures; missing/extra carry the
# per-run drift, aggregated.
def check-satellite [lines: list<string>, anchor: string, canonical: list<string>] {
  let runs = (find-load-list-runs $lines)

  mut errors = []

  let anchor_hits = ($lines | enumerate | where { |it| $it.item =~ $anchor })

  if ($anchor_hits | is-empty) {
    $errors = ($errors | append $"anchor not found — no line matches '($anchor)'. The operative load list is anchored to that lead-in; if it was reworded, update SATELLITES in test/validate-core-list.nu in the same change")
  } else if ($anchor_hits | length) > 1 {
    let at = ($anchor_hits | each { |it| $it.index + 1 } | str join ', ')
    $errors = ($errors | append $"anchor '($anchor)' matched ($anchor_hits | length) lines \(($at)\); it must match exactly one so a copied lead-in cannot steal the anchor")
  } else {
    let anchor_idx = ($anchor_hits | get 0.index)
    # Adjacency: skip ONLY blank lines and fence delimiters after the anchor;
    # the first remaining line must begin a qualifying run. "Somewhere after"
    # would relocate the gap — an em-dash-annotated operative list plus a
    # distant canonical fence would pass.
    let adjacent = ($lines
      | enumerate
      | skip ($anchor_idx + 1)
      | where { |it|
          let t = ($it.item | str trim)
          not (($t | is-empty) or ($t | str starts-with "```"))
        }
      | get -o 0.index)

    if ($adjacent == null) or (not ($runs | any { |r| $r.start == $adjacent })) {
      $errors = ($errors | append $"no load list directly after the anchor '($anchor)' — the first non-blank, non-fence line after it must begin a names-only load list \(annotated bullets do not parse as one\)")
    }
  }

  # EVERY qualifying run must match the canonical set, anchored or not. A
  # satellite may hold more than one list — leader-spawn-example.md exists to
  # carry worked examples — and a second correct list is not a defect. What
  # this forbids is a run that DISAGREES with canonical hiding behind one
  # that agrees.
  mut missing = []
  mut extra = []

  for run in $runs {
    $missing = ($missing | append ($canonical | where { |name| $name not-in $run.names }))
    $extra = ($extra | append ($run.names | where { |name| $name not-in $canonical }))
  }

  {
    errors: $errors
    missing: ($missing | uniq | sort)
    extra: ($extra | uniq | sort)
    lists: (if ($runs | length) > 1 { $runs | each { |r| $"[($r.names | str join ', ')]" } } else { [] })
  }
}

# Coverage sweep: a git-tracked .md/.sh file that is not a registered
# satellite must not carry a run with EXPECTED_COUNT - 2 or more CANONICAL
# names — that is a de-facto satellite drifting unchecked. Overlap with the
# canonical set is the discriminator: a threshold on any /core: names would
# false-positive on files listing 5 non-canonical names today.
def sweep-unregistered [canonical: list<string>] {
  let threshold = $EXPECTED_COUNT - 2
  let registered = ($SATELLITES | get path)
  let tracked = (git ls-files
    | lines
    | where { |f| ($f | str ends-with ".md") or ($f | str ends-with ".sh") }
    | where { |f| $f not-in $registered })

  mut violations = []

  for file in $tracked {
    let raw = (open --raw $file)
    if not ($raw | str contains "/core:") { continue }

    for run in (find-load-list-runs ($raw | lines)) {
      let overlap = ($run.names | where { |name| $name in $canonical })
      if ($overlap | length) >= $threshold {
        $violations = ($violations | append { file: $file, names: $overlap })
      }
    }
  }

  $violations
}

# Find the load LISTS in the given lines, as contiguous runs of names-only
# list lines. A run is a maximal sequence of consecutive lines that each
# parse under the grammar; runs carrying fewer than 2 /core: names are
# ignored — that is what keeps a lone prose bullet or a one-name example
# from counting as a list.
#
# Returns a list of { start: <0-based line index>, names: <sorted /core: names> }.
def find-load-list-runs [lines: list<string>] {
  mut runs = []
  mut current = []
  mut start = 0

  for it in ($lines | enumerate) {
    # Fence delimiters are excluded from the grammar explicitly rather than
    # relying on "```" happening to fail the name shape; like any other
    # non-list line, they end the current run. (claude-skills-134)
    let is_fence = (($it.item | str trim) | str starts-with "```")
    let hits = (if $is_fence { [] } else { names-only-line $it.item })

    if ($hits | is-empty) {
      # Run ended. Keep it only if it looks like a list rather than a mention.
      if ($current | length) >= 2 {
        $runs = ($runs | append { start: $start, names: ($current | uniq | sort) })
      }
      $current = []
    } else {
      if ($current | is-empty) { $start = $it.index }
      $current = ($current | append $hits)
    }
  }

  if ($current | length) >= 2 {
    $runs = ($runs | append { start: $start, names: ($current | uniq | sort) })
  }

  $runs
}

# The grammar: the entire line, after stripping list markers, whitespace and
# backticks, is one or more skill-shaped names separated by commas. Covers
# the canonical fenced block, the comma-separated fences in the tier
# references, the mixed /core: + /elixir: block in leader-spawn-example.md,
# the bullets in commands/work.md and the operator CLAUDE.md template, and
# the session-start hook's one-name-per-line list. Annotated bullets do NOT
# parse — a load-list entry is a name, and annotations live in prose below
# the list. Returns the /core: subset, or [] when the line does not parse.
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

# Regression fixtures. Every run-finder case is a real defect or a real idiom
# found by review — three separate reviewers each found one silent false pass
# in this parser, and every round was fixed by editing the parser with no test
# added, which is why the next round found another. These are that test.
def self-test [] {
  mut failures = []

  let cases = [
    {
      name: "names_only_fence"
      why: "canonical block shape: one name per line inside a fence"
      content: "# Doc\n\n```\n/core:aa\n/core:bb\n/core:cc\n```\n"
      expect: [[/core:aa /core:bb /core:cc]]
    }
    {
      name: "comma_separated_fence"
      why: "tier references wrap a comma-separated list across lines"
      content: "1. Load core skills:\n   ```\n   /core:aa, /core:bb,\n   /core:cc\n   ```\n"
      expect: [[/core:aa /core:bb /core:cc]]
    }
    {
      name: "annotated_bullets_do_not_parse"
      why: "a paren-annotated bullet is not a load-list entry; the annotation could NEGATE the instruction. Names-only lines are the grammar; annotations live in prose below the list (was gap F1, claude-skills-135)"
      content: "- `/core:aa`\n- `/core:bb`\n- `/core:cc` (NOT loaded by default; skip for doc-only work)\n"
      expect: [[/core:aa /core:bb]]
    }
    {
      name: "all_bullets_annotated_no_run"
      why: "annotated entries never join a run, so a list of them yields nothing — the anchor check is what makes that loud at the satellite level"
      content: "- `/core:aa` (always)\n- `/core:bb` (the tracker)\n- `/core:cc` (carries Forge)\n"
      expect: []
    }
    {
      name: "lone_em_dash_prose_bullet_ignored"
      why: "a prose bullet ABOUT a skill is not a load list; under 2 names anyway"
      content: "Some prose.\n\n- `/core:aa` — standing discipline, not pulled\n\nMore prose.\n"
      expect: []
    }
    {
      name: "prose_sentence_with_names_ignored"
      why: "restraint/README.md:3 says 'Loaded alongside `/core:tdd` and ...' in prose"
      content: "A principle: stop early. Loaded alongside `/core:aa` and `/core:bb`, threaded throughout.\n"
      expect: []
    }
    {
      name: "two_complete_lists_both_kept"
      why: "leader-spawn-example.md exists to hold a worked example; both must be checked"
      content: "```\n/core:aa\n/core:bb\n/core:cc\n```\n\nAnd again:\n\n```\n/core:aa\n/core:bb\n/core:cc\n```\n"
      expect: [[/core:aa /core:bb /core:cc] [/core:aa /core:bb /core:cc]]
    }
    {
      name: "masking_paren_bullet_invisible"
      why: "PoC A: name deleted from the list, re-added as a detached annotated bullet — the bullet no longer parses at all, so it cannot patch anything"
      content: "- `/core:aa`\n- `/core:bb`\n\nLater, unrelated:\n\n- `/core:cc` (standing discipline)\n"
      expect: [[/core:aa /core:bb]]
    }
    {
      name: "masking_fenced_example_separate_run"
      why: "PoC B: a worked example elsewhere in the file must not patch the real list"
      content: "- `/core:aa`\n- `/core:bb`\n\nExample:\n\n```\n/core:cc\n/core:aa\n```\n"
      expect: [[/core:aa /core:bb] [/core:aa /core:cc]]
    }
    {
      name: "single_name_run_below_threshold"
      why: "a one-name run is a mention, not a list"
      content: "```\n/core:aa\n```\n"
      expect: []
    }
    {
      name: "em_dash_annotated_list_invisible_to_grammar"
      why: "an operative list annotated with em-dashes parses as nothing — by design the grammar cannot see it; the ANCHOR check (was gap F3, claude-skills-135) is what makes this loud"
      content: "- `/core:aa` — always\n- `/core:bb` — the tracker\n- `/core:cc` — carries Forge\n"
      expect: []
    }
  ]

  for c in $cases {
    let got = (find-load-list-runs ($c.content | lines) | each { |r| $r.names })
    if $got != $c.expect {
      $failures = ($failures | append $"($c.name): expected ($c.expect | to nuon), got ($got | to nuon)")
    }
  }

  # Satellite-level fixtures: anchor + adjacency + every-run-must-match, the
  # composition main runs per file. `error` is a substring the errors list
  # must contain (empty = errors must be empty).
  let canonical = [/core:aa /core:bb /core:cc]

  let satellite_cases = [
    {
      name: "anchored_canonical_run_passes"
      why: "the healthy shape: anchor, blank, fence, canonical names"
      content: "Load these first:\n\n```\n/core:aa\n/core:bb\n/core:cc\n```\n"
      anchor: "Load these first"
      error: ""
      missing: []
      extra: []
    }
    {
      name: "anchor_missing_is_error"
      why: "was gap F3: delete the operative list (and its lead-in) and the file passed; now the absent anchor is loud"
      content: "Prose only.\n\n```\n/core:aa\n/core:bb\n/core:cc\n```\n"
      anchor: "Load these first"
      error: "anchor not found"
      missing: []
      extra: []
    }
    {
      name: "em_dash_adjacent_list_is_error"
      why: "was gap F3: annotate the operative list into grammar-invisibility; adjacency now fails because no run begins after the anchor"
      content: "Load these first:\n- `/core:aa` — always\n- `/core:bb` — the tracker\n- `/core:cc` — carries Forge\n"
      anchor: "Load these first"
      error: "no load list directly after the anchor"
      missing: []
      extra: []
    }
    {
      name: "divergent_later_run_still_fails"
      why: "anchoring is ADDITIVE: a canonical anchored run does not excuse a divergent run elsewhere — every run must match"
      content: "Load these first:\n\n```\n/core:aa\n/core:bb\n/core:cc\n```\n\nExample:\n\n```\n/core:aa\n/core:bb\n```\n"
      anchor: "Load these first"
      error: ""
      missing: [/core:cc]
      extra: []
    }
    {
      name: "anchor_matched_twice_is_error"
      why: "first-match-silently-wins would let a copied lead-in in an earlier example steal the anchor"
      content: "Load these first:\n\n```\n/core:aa\n/core:bb\n/core:cc\n```\n\nLoad these first, again:\n"
      anchor: "Load these first"
      error: "matched 2 lines"
      missing: []
      extra: []
    }
    {
      name: "anchored_run_missing_name_reported"
      why: "teeth: the anchored run itself dropping a name surfaces through the existing missing direction"
      content: "Load these first:\n\n```\n/core:aa\n/core:bb\n```\n"
      anchor: "Load these first"
      error: ""
      missing: [/core:cc]
      extra: []
    }
  ]

  for c in $satellite_cases {
    let got = (check-satellite ($c.content | lines) $c.anchor $canonical)
    let error_ok = (if ($c.error | is-empty) {
      $got.errors | is-empty
    } else {
      $got.errors | any { |e| $e | str contains $c.error }
    })
    if not $error_ok {
      $failures = ($failures | append $"($c.name): expected errors matching '($c.error)', got ($got.errors | to nuon)")
    }
    if $got.missing != $c.missing {
      $failures = ($failures | append $"($c.name): expected missing ($c.missing | to nuon), got ($got.missing | to nuon)")
    }
    if $got.extra != $c.extra {
      $failures = ($failures | append $"($c.name): expected extra ($c.extra | to nuon), got ($got.extra | to nuon)")
    }
  }

  let total = (($cases | length) + ($satellite_cases | length))

  if ($failures | is-not-empty) {
    print $"(ansi red_bold)❌ Core-list self-test failed:(ansi reset)"
    for f in $failures { print $"  • ($f)" }
    exit 1
  }

  print $"(ansi green_bold)✅ Core-list self-test passed \(($total) cases\)(ansi reset)"
}
