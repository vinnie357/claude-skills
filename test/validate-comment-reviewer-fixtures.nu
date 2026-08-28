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
# --self-test is mostly pure-function fixtures with no filesystem access,
# plus five subprocess-based cases (claude-skills-308) pinning the
# --dir/--categories parameterization that lets a second fixture set (e.g.
# the prose-reviewer's) reuse this validator instead of a copied script.
#
# Usage:
#   nu test/validate-comment-reviewer-fixtures.nu
#   nu test/validate-comment-reviewer-fixtures.nu --self-test

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
#
# `expected_categories` is accepted so a second fixture set (e.g. the
# prose-reviewer's) can supply its own closed set instead of the
# comment-reviewer's six (claude-skills-308) — threading that value into the
# check below, in place of the module-level const, is the implementer's
# job.
def check-verdict-category-shape [fixtures: list<record>, expected_categories: list<string>]: nothing -> list<string> {
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
#
# `expected_categories` is accepted for the same reason as in
# check-verdict-category-shape above (claude-skills-308) — threading it into
# the comparisons below, in place of the module-level const, is the
# implementer's job.
def check-categories-closed-set [declared: list<string>, expected_categories: list<string>]: nothing -> list<string> {
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
  $errors = ($errors | append (check-verdict-category-shape $fixtures $EXPECTED_CATEGORIES))

  # Check 4
  $errors = ($errors | append (check-flag-none-consistency $fixtures))

  # Check 5
  $errors = ($errors | append (check-verdict-diversity $fixtures))

  # Check 6
  let declared_categories = ($manifest | get -o categories | default [])
  $errors = ($errors | append (check-categories-closed-set $declared_categories $EXPECTED_CATEGORIES))

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
  let shape_clean = (check-verdict-category-shape [{file: "f01.py" verdict: "FLAG" category: "restates-code"}] $EXPECTED_CATEGORIES)
  if ($shape_clean | is-not-empty) {
    $failures = ($failures | append $"check-verdict-category-shape: expected clean, got ($shape_clean)")
  }
  let shape_bad_category = (check-verdict-category-shape [{file: "f01.py" verdict: "FLAG" category: "bogus-category"}] $EXPECTED_CATEGORIES)
  if ($shape_bad_category | is-empty) {
    $failures = ($failures | append "check-verdict-category-shape: expected an error for a category not in the closed set")
  }
  let shape_bad_verdict = (check-verdict-category-shape [{file: "f01.py" verdict: "maybe" category: "none"}] $EXPECTED_CATEGORIES)
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
  if (check-categories-closed-set $EXPECTED_CATEGORIES $EXPECTED_CATEGORIES) != [] {
    $failures = ($failures | append "check-categories-closed-set: expected clean for the exact fixed list")
  }
  if (check-categories-closed-set ($EXPECTED_CATEGORIES | where $it != "none") $EXPECTED_CATEGORIES) == [] {
    $failures = ($failures | append "check-categories-closed-set: expected an error when 'none' is missing")
  }
  if (check-categories-closed-set ($EXPECTED_CATEGORIES | append "bogus") $EXPECTED_CATEGORIES) == [] {
    $failures = ($failures | append "check-categories-closed-set: expected an error for an extra undeclared category")
  }

  # ---- claude-skills-308: --dir/--categories threading (frozen) ---------
  #
  # Pins the "parameter accepted but not threaded through" defect: main
  # can gain --dir/--categories flags while the check functions above keep
  # reading the module-level consts, and every pre-existing self-test case
  # stays green because none of them exercise a caller-supplied list that
  # disagrees with the const. Cases 1, 3, and 4 below are RED until the
  # check functions actually use their `expected_categories` parameter
  # (not just accept it) AND `main` threads `--dir`/`--categories` down to
  # them. Case 2 and case 5 are regression guards that must stay GREEN
  # throughout.

  # Case 1 (must-flag, RED until implemented): a category list that omits
  # "restates-code", checked against a fixture entry whose category IS
  # "restates-code". A caller-supplied-list-aware implementation must flag
  # it; today's implementation still consults the hardcoded const (which
  # DOES contain "restates-code"), so it reports nothing.
  let case1_result = (try {
    let categories_without_restates_code = ["over-explains" "missing-purpose" "missing-inputs" "contradicts-code" "none"]
    let errs = (check-verdict-category-shape [{file: "f01.py" verdict: "FLAG" category: "restates-code"}] $categories_without_restates_code)
    {status: "ok" errors: $errs}
  } catch { |err|
    {status: "threw" errors: [] msg: $err.msg}
  })
  if $case1_result.status != "ok" or ($case1_result.errors | is-empty) {
    $failures = ($failures | append $"claude-skills-308 case 1: expected check-verdict-category-shape to flag a category absent from the caller-supplied list \(got status=($case1_result.status), errors=($case1_result.errors)\)")
  }

  # Case 2 (regression guard, must stay GREEN): passing the
  # comment-reviewer's own six categories explicitly must not reject a
  # valid entry — guards against a fix that satisfies case 1 by rejecting
  # everything regardless of the supplied list.
  let case2_result = (try {
    let errs = (check-verdict-category-shape [{file: "f01.py" verdict: "FLAG" category: "restates-code"}] $EXPECTED_CATEGORIES)
    {status: "ok" errors: $errs}
  } catch { |err|
    {status: "threw" errors: [] msg: $err.msg}
  })
  if $case2_result.status != "ok" or ($case2_result.errors | is-not-empty) {
    $failures = ($failures | append $"claude-skills-308 case 2: expected no error for a valid entry checked against the caller-supplied comment-reviewer categories \(got status=($case2_result.status), errors=($case2_result.errors)\)")
  }

  # Case 3 (must-flag, RED until implemented): check-categories-closed-set
  # honors a caller-supplied expected list, both directions.
  #
  # 3a: a manifest declaring exactly the caller-supplied set reports no
  # error. Today's implementation still diffs against the six-category
  # const, so a two-element declared/expected pair reports missing
  # categories that aren't actually missing from what the caller asked for.
  let case3a_result = (try {
    let two_category_set = ["restates-code" "none"]
    let errs = (check-categories-closed-set $two_category_set $two_category_set)
    {status: "ok" errors: $errs}
  } catch { |err|
    {status: "threw" errors: [] msg: $err.msg}
  })
  if $case3a_result.status != "ok" or ($case3a_result.errors | is-not-empty) {
    $failures = ($failures | append $"claude-skills-308 case 3a: expected no error when the declared set exactly matches the caller-supplied expected set \(got status=($case3a_result.status), errors=($case3a_result.errors)\)")
  }

  # 3b: a manifest declaring the comment-reviewer six, checked against a
  # caller-supplied two-element expected set, reports BOTH a
  # missing-category error (for the supplied category the six doesn't
  # have) and an extra-category error (for the six's categories the
  # supplied set doesn't have). Today's implementation ignores the supplied
  # set and compares the six against itself, reporting neither.
  let case3b_result = (try {
    let two_category_set = ["restates-code" "totally-different-category"]
    let errs = (check-categories-closed-set $EXPECTED_CATEGORIES $two_category_set)
    {status: "ok" errors: $errs}
  } catch { |err|
    {status: "threw" errors: [] msg: $err.msg}
  })
  if $case3b_result.status != "ok" or (($case3b_result.errors | length) < 2) {
    $failures = ($failures | append $"claude-skills-308 case 3b: expected BOTH a missing-category and an extra-category error \(got status=($case3b_result.status), errors=($case3b_result.errors)\)")
  }

  # Case 4 (must-flag, RED until implemented): `main` accepts --dir and
  # --categories and threads them end to end. Runs the real script as a
  # subprocess (not `main` in-process) against a throwaway fixture set
  # built under mktemp -d — a category set that is NOT the
  # comment-reviewer's — because whether the flags actually reach the check
  # functions is main's decision, and only running the script proves the
  # wiring. Does not depend on test/fixtures/prose-reviewer/, which does
  # not exist yet.
  let case4_tmp_dir = (mktemp -d)
  let case4_result = (try {
    let snippets_dir = ($case4_tmp_dir | path join "snippets")
    mkdir $snippets_dir
    "# flagged snippet\ndef foo [] {}\n" | save ($snippets_dir | path join "flag01.py")
    "# clean snippet\ndef bar [] {}\n" | save ($snippets_dir | path join "noflag01.py")
    let manifest = {
      contract_version: 1
      categories: ["custom-defect" "none"]
      fixtures: [
        {file: "flag01.py" verdict: "FLAG" category: "custom-defect"}
        {file: "noflag01.py" verdict: "NO-FLAG" category: "none"}
      ]
    }
    $manifest | to json | save ($case4_tmp_dir | path join "expected.json")
    let repo_root = (^git rev-parse --show-toplevel | str trim)
    let script_path = ($repo_root | path join "test" "validate-comment-reviewer-fixtures.nu")
    let result = (^nu $script_path --dir $case4_tmp_dir --categories "custom-defect,none" | complete)
    {status: "ran" exit_code: $result.exit_code}
  } catch { |err|
    {status: "threw" exit_code: -1 msg: $err.msg}
  })
  rm -rf $case4_tmp_dir
  if $case4_result.exit_code != 0 {
    $failures = ($failures | append $"claude-skills-308 case 4: expected exit 0 running the script with --dir/--categories pointed at a throwaway non-comment-reviewer fixture set \(got status=($case4_result.status), exit_code=($case4_result.exit_code)\)")
  }

  # Case 5 (regression guard, must stay GREEN): running the script with no
  # flags at all must still validate the comment-reviewer set and exit 0 —
  # defaults stay behavior-preserving while the parameterization lands.
  let case5_result = (try {
    let repo_root = (^git rev-parse --show-toplevel | str trim)
    let script_path = ($repo_root | path join "test" "validate-comment-reviewer-fixtures.nu")
    let result = (^nu $script_path | complete)
    {status: "ran" exit_code: $result.exit_code}
  } catch { |err|
    {status: "threw" exit_code: -1 msg: $err.msg}
  })
  if $case5_result.exit_code != 0 {
    $failures = ($failures | append $"claude-skills-308 case 5: expected exit 0 running the script with no flags \(got status=($case5_result.status), exit_code=($case5_result.exit_code)\)")
  }

  if ($failures | is-not-empty) {
    print $"(ansi red_bold)❌ comment-reviewer fixture validator self-test failed:(ansi reset)"
    for f in $failures { print $"  • ($f)" }
    exit 1
  }

  print $"(ansi green_bold)✅ comment-reviewer fixture validator self-test passed(ansi reset)"
}
