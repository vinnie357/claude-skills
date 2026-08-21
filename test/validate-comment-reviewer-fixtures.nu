#!/usr/bin/env nu

# Gate A validator for the comment-reviewer eval fixture set
# (test/fixtures/comment-reviewer/, claude-skills-291).
#
# This is NOT a live-agent test — it cannot invoke the comment-reviewer
# agent in CI (no API key), so it does not judge whether the agent's actual
# verdicts match `expected.json`. It only checks that the fixture set and
# its manifest are internally consistent: a live-inference eval run
# (outside CI) is the thing that actually exercises the agent against these
# nine snippets and diffs its verdicts against `expected.json`.
#
# Six checks, each independently reportable so a broken manifest names every
# problem in one run instead of failing fast on the first:
#
#   1. `expected.json` parses as valid JSON and `contract_version` is 1.
#   2. Bijection: every file in snippets/ has exactly one manifest entry,
#      and every manifest entry names a file that exists in snippets/.
#   3. Every `category` is in the declared closed set; every `verdict` is
#      exactly "FLAG" or "NO-FLAG" (no other casing/spelling).
#   4. FLAG entries never carry category "none"; NO-FLAG entries always do.
#      Catches an entry whose verdict and category disagree about whether
#      there's a finding.
#   5. At least one FLAG and one NO-FLAG entry exist — catches a degenerate
#      all-one-verdict manifest that would trivially "pass" any diff.
#   6. The manifest's own `categories` array matches the fixed six-category
#      list below exactly (order-independent) — drift check for someone
#      editing the closed set without updating the fixtures that declare it.
#
# `why` and `example_replacement` are advisory prose, not checked here.
#
# Usage:
#   nu test/validate-comment-reviewer-fixtures.nu
#   nu test/validate-comment-reviewer-fixtures.nu --self-test   # pure-function fixtures, no filesystem

const FIXTURE_DIR = "test/fixtures/comment-reviewer"
const EXPECTED_CATEGORIES = ["restates-code" "over-explains" "missing-purpose" "missing-inputs" "contradicts-code" "none"]
const VALID_VERDICTS = ["FLAG" "NO-FLAG"]

# ---- Pure checks (no I/O) ----------------------------------------------

# Check 1 (contract_version half): true only when the manifest declares
# contract_version == 1.
def check-contract-version [manifest: record]: nothing -> bool {
  ($manifest | get -o contract_version) == 1
}

# Check 2: bijection between snippet filenames on disk and `file` entries in
# the manifest. Returns { missing_entries: [...], missing_files: [...] } —
# missing_entries are snippets with no manifest row, missing_files are
# manifest rows naming a snippet that does not exist.
def check-bijection [snippet_files: list<string>, fixture_entries: list<string>]: nothing -> record {
  {
    missing_entries: ($snippet_files | where { |f| $f not-in $fixture_entries } | sort)
    missing_files: ($fixture_entries | where { |f| $f not-in $snippet_files } | sort)
  }
}

# Check 3: for each fixture, is its category in the closed set and its
# verdict exactly "FLAG" or "NO-FLAG"? Returns a list of error strings,
# empty when clean.
def check-verdict-category-shape [fixtures: list<record>]: nothing -> list<string> {
  mut errors = []
  for fx in $fixtures {
    if ($fx.category not-in $EXPECTED_CATEGORIES) {
      $errors = ($errors | append $"($fx.file): category '($fx.category)' is not in the closed set \(($EXPECTED_CATEGORIES | str join ', ')\)")
    }
    if ($fx.verdict not-in $VALID_VERDICTS) {
      $errors = ($errors | append $"($fx.file): verdict '($fx.verdict)' must be exactly 'FLAG' or 'NO-FLAG'")
    }
  }
  $errors
}

# Check 4: FLAG entries must not carry category "none"; NO-FLAG entries must
# carry category "none" exactly. Returns a list of error strings.
def check-flag-none-consistency [fixtures: list<record>]: nothing -> list<string> {
  mut errors = []
  for fx in $fixtures {
    if $fx.verdict == "FLAG" and $fx.category == "none" {
      $errors = ($errors | append $"($fx.file): verdict FLAG but category is 'none' — a flagged entry must name a real category")
    }
    if $fx.verdict == "NO-FLAG" and $fx.category != "none" {
      $errors = ($errors | append $"($fx.file): verdict NO-FLAG but category is '($fx.category)', expected 'none'")
    }
  }
  $errors
}

# Check 5: at least one FLAG and at least one NO-FLAG entry exist. Returns
# a list of error strings (0, 1, or 2 depending on which side is missing).
def check-verdict-diversity [fixtures: list<record>]: nothing -> list<string> {
  mut errors = []
  if ($fixtures | where verdict == "FLAG" | is-empty) {
    $errors = ($errors | append "no FLAG entries in the manifest — degenerate all-NO-FLAG set")
  }
  if ($fixtures | where verdict == "NO-FLAG" | is-empty) {
    $errors = ($errors | append "no NO-FLAG entries in the manifest — degenerate all-FLAG set")
  }
  $errors
}

# Check 6: the manifest's declared `categories` array matches the fixed
# six-category list, order-independent, both directions.
def check-categories-closed-set [declared: list<string>]: nothing -> list<string> {
  let missing = ($EXPECTED_CATEGORIES | where { |c| $c not-in $declared })
  let extra = ($declared | where { |c| $c not-in $EXPECTED_CATEGORIES })
  mut errors = []
  if ($missing | is-not-empty) {
    $errors = ($errors | append $"categories missing from manifest declaration — ($missing | str join ', ')")
  }
  if ($extra | is-not-empty) {
    $errors = ($errors | append $"categories declared that are not in the fixed set — ($extra | str join ', ')")
  }
  $errors
}

# ---- Orchestration (I/O) ------------------------------------------------

def main [--self-test] {
  if $self_test {
    self-test
    return
  }

  let repo_root = (git rev-parse --show-toplevel | str trim)
  cd $repo_root

  let manifest_path = ([$FIXTURE_DIR "expected.json"] | path join)
  let snippets_dir = ([$FIXTURE_DIR "snippets"] | path join)

  if not ($manifest_path | path exists) {
    print $"(ansi red_bold)❌ manifest not found: ($manifest_path)(ansi reset)"
    exit 1
  }

  if not ($snippets_dir | path exists) {
    print $"(ansi red_bold)❌ snippets dir not found: ($snippets_dir)(ansi reset)"
    exit 1
  }

  let manifest = try {
    open $manifest_path
  } catch { |err|
    print $"(ansi red_bold)❌ ($manifest_path) failed to parse as JSON:(ansi reset)"
    print $"  ($err.msg)"
    exit 1
  }

  mut errors = []

  # Check 1
  if not (check-contract-version $manifest) {
    $errors = ($errors | append $"contract_version must be 1, got ($manifest | get -o contract_version)")
  }

  let fixtures = ($manifest | get -o fixtures | default [])
  let snippet_files = (ls $snippets_dir | get name | each { |p| $p | path basename } | sort)
  let fixture_entries = ($fixtures | get -o file | default [] | sort)

  # Check 2
  let bijection = (check-bijection $snippet_files $fixture_entries)
  if ($bijection.missing_entries | is-not-empty) {
    $errors = ($errors | append $"snippet\(s\) with no manifest entry — ($bijection.missing_entries | str join ', ')")
  }
  if ($bijection.missing_files | is-not-empty) {
    $errors = ($errors | append $"manifest entr\(y|ies\) naming a snippet that does not exist — ($bijection.missing_files | str join ', ')")
  }

  # Check 3
  $errors = ($errors | append (check-verdict-category-shape $fixtures))

  # Check 4
  $errors = ($errors | append (check-flag-none-consistency $fixtures))

  # Check 5
  $errors = ($errors | append (check-verdict-diversity $fixtures))

  # Check 6
  let declared_categories = ($manifest | get -o categories | default [])
  $errors = ($errors | append (check-categories-closed-set $declared_categories))

  if ($errors | is-not-empty) {
    print $"(ansi red_bold)❌ comment-reviewer fixture validation failed \(($errors | length) issue\(s\)\):(ansi reset)\n"
    for e in $errors {
      print $"  • ($e)"
    }
    exit 1
  }

  print $"(ansi green_bold)✅ comment-reviewer fixtures consistent \(($fixtures | length) fixtures, ($declared_categories | length) categories\)(ansi reset)"
  exit 0
}

# ---- Self-test ------------------------------------------------------------

def self-test [] {
  mut failures = []

  # check-contract-version
  if (check-contract-version { contract_version: 1 }) != true {
    $failures = ($failures | append "check-contract-version: expected true for contract_version=1")
  }
  if (check-contract-version { contract_version: 2 }) != false {
    $failures = ($failures | append "check-contract-version: expected false for contract_version=2")
  }
  if (check-contract-version {}) != false {
    $failures = ($failures | append "check-contract-version: expected false when field is absent")
  }

  # check-bijection
  let bij_clean = (check-bijection ["a.py" "b.py"] ["a.py" "b.py"])
  if ($bij_clean.missing_entries | is-not-empty) or ($bij_clean.missing_files | is-not-empty) {
    $failures = ($failures | append $"check-bijection: expected clean bijection, got ($bij_clean | to nuon)")
  }
  let bij_dirty = (check-bijection ["a.py" "b.py" "c.py"] ["a.py" "d.py"])
  if $bij_dirty.missing_entries != ["b.py" "c.py"] {
    $failures = ($failures | append $"check-bijection: expected missing_entries [b.py, c.py], got ($bij_dirty.missing_entries)")
  }
  if $bij_dirty.missing_files != ["d.py"] {
    $failures = ($failures | append $"check-bijection: expected missing_files [d.py], got ($bij_dirty.missing_files)")
  }

  # check-verdict-category-shape
  let shape_clean = (check-verdict-category-shape [{file: "f01.py" verdict: "FLAG" category: "restates-code"}])
  if ($shape_clean | is-not-empty) {
    $failures = ($failures | append $"check-verdict-category-shape: expected clean, got ($shape_clean)")
  }
  let shape_bad_category = (check-verdict-category-shape [{file: "f01.py" verdict: "FLAG" category: "bogus-category"}])
  if ($shape_bad_category | is-empty) {
    $failures = ($failures | append "check-verdict-category-shape: expected an error for a category not in the closed set")
  }
  let shape_bad_verdict = (check-verdict-category-shape [{file: "f01.py" verdict: "maybe" category: "none"}])
  if ($shape_bad_verdict | is-empty) {
    $failures = ($failures | append "check-verdict-category-shape: expected an error for a verdict that is not FLAG/NO-FLAG")
  }

  # check-flag-none-consistency
  let consistency_clean = (check-flag-none-consistency [
    {file: "f01.py" verdict: "FLAG" category: "restates-code"}
    {file: "f04.rs" verdict: "NO-FLAG" category: "none"}
  ])
  if ($consistency_clean | is-not-empty) {
    $failures = ($failures | append $"check-flag-none-consistency: expected clean, got ($consistency_clean)")
  }
  let consistency_flag_none = (check-flag-none-consistency [{file: "f01.py" verdict: "FLAG" category: "none"}])
  if ($consistency_flag_none | is-empty) {
    $failures = ($failures | append "check-flag-none-consistency: expected an error for FLAG with category=none")
  }
  let consistency_noflag_category = (check-flag-none-consistency [{file: "f04.rs" verdict: "NO-FLAG" category: "restates-code"}])
  if ($consistency_noflag_category | is-empty) {
    $failures = ($failures | append "check-flag-none-consistency: expected an error for NO-FLAG with a real category")
  }

  # check-verdict-diversity
  let diversity_clean = (check-verdict-diversity [
    {file: "f01.py" verdict: "FLAG" category: "restates-code"}
    {file: "f04.rs" verdict: "NO-FLAG" category: "none"}
  ])
  if ($diversity_clean | is-not-empty) {
    $failures = ($failures | append $"check-verdict-diversity: expected clean, got ($diversity_clean)")
  }
  let diversity_all_flag = (check-verdict-diversity [{file: "f01.py" verdict: "FLAG" category: "restates-code"}])
  if ($diversity_all_flag | is-empty) {
    $failures = ($failures | append "check-verdict-diversity: expected an error for an all-FLAG set")
  }
  let diversity_all_noflag = (check-verdict-diversity [{file: "f04.rs" verdict: "NO-FLAG" category: "none"}])
  if ($diversity_all_noflag | is-empty) {
    $failures = ($failures | append "check-verdict-diversity: expected an error for an all-NO-FLAG set")
  }

  # check-categories-closed-set
  if (check-categories-closed-set $EXPECTED_CATEGORIES) != [] {
    $failures = ($failures | append "check-categories-closed-set: expected clean for the exact fixed list")
  }
  if (check-categories-closed-set ($EXPECTED_CATEGORIES | where $it != "none")) == [] {
    $failures = ($failures | append "check-categories-closed-set: expected an error when 'none' is missing")
  }
  if (check-categories-closed-set ($EXPECTED_CATEGORIES | append "bogus")) == [] {
    $failures = ($failures | append "check-categories-closed-set: expected an error for an extra undeclared category")
  }

  if ($failures | is-not-empty) {
    print $"(ansi red_bold)❌ comment-reviewer fixture validator self-test failed:(ansi reset)"
    for f in $failures { print $"  • ($f)" }
    exit 1
  }

  print $"(ansi green_bold)✅ comment-reviewer fixture validator self-test passed(ansi reset)"
}
