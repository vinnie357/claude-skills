#!/usr/bin/env nu

# Check that modified plugins have version bumps
#
# Usage:
#   nu check-version-bumps.nu [--base main]
#   nu check-version-bumps.nu --self-test
#
# Compares current branch to base branch and ensures any plugin
# with file changes also has a version bump in both:
#   - <plugin-dir>/.claude-plugin/plugin.json
#   - .claude-plugin/marketplace.json
#
# `all-skills` (root .claude-plugin/plugin.json, source "./") aggregates every
# skill path from every other plugin. Its content never diffs on its own —
# only its version line moves — so it cannot be detected by the directory-
# prefix matching every other plugin uses (claude-skills-207). It is handled
# as a special case: in scope whenever any other tracked plugin's content
# changed, OR its own version line differs from base even with no other
# plugin touched (covers a bare all-skills-only version edit).
#
# Every in-scope plugin must have a version STRICTLY GREATER than base's
# current value — equal is treated as an error, not a warning. main is a
# moving target in a serialized merge queue: a version equal to main at
# branch-open time can already be taken by a PR that merged first, and a
# version merely "different" from base (the pre-fix check only tested `!=`)
# does not catch a decrease. An untouched plugin (no content change, no
# version-line change) is never required to differ — that's the
# false-positive guard the AC calls out explicitly.

# Parse a version string into {major, minor, patch}, or null if it doesn't
# match MAJOR.MINOR.PATCH. Pure — no I/O.
def parse-semver [version: string] {
  let matches = ($version | parse -r '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$')
  if ($matches | is-empty) {
    null
  } else {
    let r = ($matches | first)
    { major: ($r.major | into int), minor: ($r.minor | into int), patch: ($r.patch | into int) }
  }
}

# Compare two version strings. Returns "gt", "eq", "lt", or "malformed" if
# either fails to parse as semver. Pure — no I/O.
def semver-compare [current: string, base: string] {
  let c = (parse-semver $current)
  let b = (parse-semver $base)
  if $c == null or $b == null {
    "malformed"
  } else if $c.major != $b.major {
    if $c.major > $b.major { "gt" } else { "lt" }
  } else if $c.minor != $b.minor {
    if $c.minor > $b.minor { "gt" } else { "lt" }
  } else if $c.patch != $b.patch {
    if $c.patch > $b.patch { "gt" } else { "lt" }
  } else {
    "eq"
  }
}

# Decide whether a single plugin.json version is a valid bump, given its
# current and base values and whether the plugin's directory content
# changed on this branch. Pure — no I/O, no git, no filesystem. This is the
# function the self-test fixtures exercise directly.
#
# Returns { status: "pass" | "fail" | "skip", reason: string }
def classify-bump [
  current: string  # version currently on disk / in the working tree
  base: any         # version at the base ref, or null if the plugin is new
  content_changed: bool  # did files under the plugin's directory change?
] {
  if $base == null {
    return { status: "skip", reason: "new plugin — no base version to compare" }
  }

  let version_line_changed = ($current != $base)
  let in_scope = ($content_changed or $version_line_changed)

  if not $in_scope {
    return { status: "skip", reason: "untouched — content and version both match base" }
  }

  let cmp = (semver-compare $current $base)

  if $cmp == "malformed" {
    return { status: "fail", reason: $"cannot compare versions \(current=($current), base=($base)\) — malformed semver" }
  }

  if $cmp != "gt" {
    return { status: "fail", reason: $"version not increased \(($base) -> ($current)\)" }
  }

  { status: "pass", reason: $"($base) -> ($current)" }
}

def main [
  --base: string = "main"  # Base branch to compare against
  --self-test               # Run the pure-function fixture suite and exit
] {
  if $self_test {
    self-test
    return
  }

  let base_check = (do { git rev-parse --verify $"($base)^{commit}" } | complete)
  if $base_check.exit_code != 0 {
    print $"(ansi red_bold)❌ Base ref '($base)' does not exist or is not a commit(ansi reset)"
    print $"  ($base_check.stderr | str trim)"
    exit 1
  }

  print $"🔍 Checking version bumps against ($base)...\n"

  # Get list of changed files (committed, unstaged, and staged)
  let committed = (git diff --name-only $"($base)...HEAD" | lines | where { |f| ($f | str length) > 0 })
  let uncommitted = (git diff --name-only | lines | where { |f| ($f | str length) > 0 })
  let staged = (git diff --cached --name-only | lines | where { |f| ($f | str length) > 0 })
  let changed_files = ($committed | append $uncommitted | append $staged | uniq)

  if ($changed_files | length) == 0 {
    print "✅ No files changed"
    exit 0
  }

  # Build plugin mapping from marketplace.json (name → dir), excluding
  # all-skills — its root source "./" cannot use directory-prefix matching
  # (every file would match a "" prefix). all-skills is handled separately.
  let repo_root = (git rev-parse --show-toplevel | str trim)
  let marketplace = (open ($repo_root | path join ".claude-plugin" "marketplace.json"))
  let plugin_map = ($marketplace.plugins
    | where name != "all-skills"
    | each { |p|
      let source = ($p | get -o source | default "./")
      let source_type = ($source | describe)
      if ($source_type | str starts-with "record") {
        null
      } else {
        let dir = ($source | str replace --regex '^\./' '')
        { name: $p.name, dir: $dir }
      }
    }
    | compact
  )

  # Identify which plugins have changes
  let plugins = get-modified-plugins $changed_files $plugin_map

  if ($plugins | length) > 0 {
    print $"📦 Modified plugins: ($plugins | each { |p| $p.name } | str join ', ')\n"
  }

  # Check each plugin for version bump
  mut errors = []

  for plugin in $plugins {
    let result = check-plugin-version-bump $plugin.name $plugin.dir $base true
    if not $result.bumped {
      $errors = ($errors | append $result.error)
    }
  }

  # all-skills special case: in scope whenever any other plugin's content
  # changed on this branch (it aggregates every plugin's skills), or when its
  # own version line was edited even absent any other plugin change.
  let has_all_skills = (($marketplace.plugins | where name == "all-skills" | length) > 0)
  if $has_all_skills {
    let content_changed_elsewhere = (($plugins | length) > 0)
    let result = check-plugin-version-bump "all-skills" "." $base $content_changed_elsewhere
    if not $result.bumped {
      $errors = ($errors | append $result.error)
    }
  }

  # Check marketplace version bump if plugin list changed
  let marketplace_result = (check-marketplace-version-bump $base)
  if not $marketplace_result.bumped {
    $errors = ($errors | append $marketplace_result.error)
  }

  # Report results
  if ($errors | length) > 0 {
    print $"\n(ansi red_bold)❌ Version bump check failed:(ansi reset)\n"
    for error in $errors {
      print $"  • ($error)"
    }
    print $"\n(ansi yellow)Hint: Bump the version in:(ansi reset)"
    print "  1. <plugin-dir>/.claude-plugin/plugin.json"
    print "  2. .claude-plugin/marketplace.json → plugin entry version"
    print "  3. .claude-plugin/marketplace.json → metadata.version (when adding/removing plugins)"
    exit 1
  }

  print $"\n(ansi green_bold)✅ All modified plugins have version bumps(ansi reset)"
  exit 0
}

# Extract modified plugins by matching changed file paths against plugin directories
def get-modified-plugins [changed_files: list<string>, plugin_map: list<record>] {
  mut modified = []

  for file in $changed_files {
    for plugin in $plugin_map {
      if ($file | str starts-with $"($plugin.dir)/") {
        if not ($plugin.name in ($modified | each { |m| $m.name })) {
          $modified = ($modified | append $plugin)
        }
      }
    }
  }

  $modified
}

# Fetch a plugin.json version at a given git ref. Returns null if the file
# or the version field doesn't exist at that ref (new plugin).
def get-ref-version [plugin_json_path: string, ref: string] {
  try {
    git show $"($ref):($plugin_json_path)" | from json | get version
  } catch {
    null
  }
}

# Check if a plugin has a valid version bump compared to base. `dir` is "."
# for the all-skills root plugin, or a subdirectory for every other plugin.
# `content_changed` tells classify-bump whether this plugin's own directory
# had file changes on this branch — callers pass it explicitly rather than
# relying on a default, since the all-skills call site computes it from
# whether OTHER plugins changed (it aggregates them, so its own directory
# never diffs on its own — claude-skills-207). classify-bump additionally
# treats a bare version-line edit as in-scope even when content_changed is
# false, so an all-skills-only bump (or a regression) is still caught.
def check-plugin-version-bump [
  plugin_name: string
  plugin_dir: string
  base: string
  content_changed: bool
] {
  let plugin_json_path = ($plugin_dir | path join ".claude-plugin" "plugin.json")
  let marketplace_path = ".claude-plugin/marketplace.json"

  let base_plugin_version = (get-ref-version $plugin_json_path $base)

  let current_plugin_version = try {
    open $plugin_json_path | get version
  } catch {
    return { bumped: false, error: $"($plugin_name): Cannot read plugin.json version" }
  }

  let classification = (classify-bump $current_plugin_version $base_plugin_version $content_changed)

  if $classification.status == "skip" {
    return { bumped: true, error: "" }
  }

  if $classification.status == "fail" {
    return { bumped: false, error: $"($plugin_name): plugin.json ($classification.reason)" }
  }

  # plugin.json passed — cross-check marketplace.json entry matches and also
  # increased from base (it must equal plugin.json's current version, which
  # already forces the increase, but a missing/stale marketplace entry is
  # still a distinct failure worth naming).
  let base_marketplace_version = try {
    let marketplace = (git show $"($base):($marketplace_path)" | from json)
    $marketplace.plugins | where name == $plugin_name | first | get version
  } catch {
    null
  }

  let current_marketplace_version = try {
    let marketplace = (open $marketplace_path)
    $marketplace.plugins | where name == $plugin_name | first | get version
  } catch {
    return { bumped: false, error: $"($plugin_name): Cannot find in marketplace.json" }
  }

  if $base_marketplace_version != null and $current_marketplace_version == $base_marketplace_version {
    return {
      bumped: false,
      error: $"($plugin_name): marketplace.json version not bumped \(still ($base_marketplace_version)\)"
    }
  }

  if $current_plugin_version != $current_marketplace_version {
    return {
      bumped: false,
      error: $"($plugin_name): Version mismatch - plugin.json=($current_plugin_version), marketplace.json=($current_marketplace_version)"
    }
  }

  print $"  ✓ ($plugin_name): ($classification.reason)"
  { bumped: true, error: "" }
}

# Check if marketplace metadata.version was bumped when the plugin list changes
def check-marketplace-version-bump [base: string] {
  let marketplace_path = ".claude-plugin/marketplace.json"

  # Get base plugin names
  let base_names = try {
    let m = (git show $"($base):($marketplace_path)" | from json)
    $m.plugins | get name | sort
  } catch {
    # No base marketplace — first time, skip
    return { bumped: true, error: "" }
  }

  # Get current plugin names
  let current_names = try {
    let m = (open $marketplace_path)
    $m.plugins | get name | sort
  } catch {
    return { bumped: false, error: "marketplace: Cannot read current marketplace.json" }
  }

  # If plugin list unchanged, no marketplace version bump needed
  if $base_names == $current_names {
    return { bumped: true, error: "" }
  }

  # Plugin list changed — verify metadata.version was bumped
  let base_version = try {
    git show $"($base):($marketplace_path)" | from json | get metadata.version
  } catch {
    return { bumped: true, error: "" }
  }

  let current_version = try {
    open $marketplace_path | get metadata.version
  } catch {
    return { bumped: false, error: "marketplace: Cannot read metadata.version" }
  }

  if $current_version == $base_version {
    return {
      bumped: false,
      error: $"marketplace: metadata.version not bumped \(still ($base_version)\) — plugin list changed"
    }
  }

  print $"  ✓ marketplace: ($base_version) → ($current_version)"
  { bumped: true, error: "" }
}

# Regression fixtures for the pure decision functions (semver-compare,
# classify-bump). No git, no filesystem — every case is an in-memory input.
# These are the failure modes from claude-skills-207: an all-skills version
# equal to or below main passed green because the check never looked at it
# and never verified direction, only inequality.
def self-test [] {
  mut failures = []

  let semver_cases = [
    { name: "gt_patch", a: "0.4.104", b: "0.4.103", expect: "gt" }
    { name: "gt_minor", a: "0.5.0", b: "0.4.103", expect: "gt" }
    { name: "gt_major", a: "1.0.0", b: "0.4.103", expect: "gt" }
    { name: "eq", a: "0.4.103", b: "0.4.103", expect: "eq" }
    { name: "lt_patch", a: "0.4.102", b: "0.4.103", expect: "lt" }
    { name: "lt_minor_despite_higher_patch", a: "0.3.999", b: "0.4.0", expect: "lt" }
    { name: "malformed_current", a: "abc", b: "0.4.103", expect: "malformed" }
    { name: "malformed_base", a: "0.4.103", b: "not-a-version", expect: "malformed" }
    { name: "malformed_both", a: "x", b: "y", expect: "malformed" }
  ]

  for c in $semver_cases {
    let got = (semver-compare $c.a $c.b)
    if $got != $c.expect {
      $failures = ($failures | append $"semver-compare/($c.name): expected ($c.expect), got ($got)")
    }
  }

  # classify-bump cases — these are the five scenarios named in claude-skills-207.
  let bump_cases = [
    {
      name: "all_skills_equal_to_main_must_be_caught"
      current: "0.4.103", base: "0.4.103", content_changed: true
      expect_status: "fail"
    }
    {
      name: "all_skills_below_main_must_be_caught"
      current: "0.4.102", base: "0.4.103", content_changed: true
      expect_status: "fail"
    }
    {
      name: "modified_plugin_equal_to_main_must_be_caught"
      current: "0.2.50", base: "0.2.50", content_changed: true
      expect_status: "fail"
    }
    {
      name: "untouched_plugin_equal_to_main_is_not_flagged"
      current: "0.2.50", base: "0.2.50", content_changed: false
      expect_status: "skip"
    }
    {
      name: "correct_strictly_greater_bump_passes"
      current: "0.2.51", base: "0.2.50", content_changed: true
      expect_status: "pass"
    }
    {
      name: "version_changed_but_content_did_not_still_checked"
      # all-skills' own scenario: no directory content diff, but its version
      # line moved — AC requires this stays in scope even though
      # content_changed is false.
      current: "0.4.104", base: "0.4.103", content_changed: false
      expect_status: "pass"
    }
    {
      name: "version_decreased_with_no_content_change_still_caught"
      current: "0.4.100", base: "0.4.103", content_changed: false
      expect_status: "fail"
    }
    {
      name: "new_plugin_has_no_base_and_always_passes"
      current: "0.1.0", base: null, content_changed: true
      expect_status: "skip"
    }
    {
      name: "malformed_current_version_reported_not_crashed"
      current: "not-semver", base: "0.4.103", content_changed: true
      expect_status: "fail"
    }
  ]

  for c in $bump_cases {
    let got = (classify-bump $c.current $c.base $c.content_changed)
    if $got.status != $c.expect_status {
      $failures = ($failures | append $"classify-bump/($c.name): expected status=($c.expect_status), got status=($got.status) reason=($got.reason)")
    }
  }

  if ($failures | is-not-empty) {
    print $"(ansi red_bold)❌ check-version-bumps self-test failed:(ansi reset)"
    for f in $failures { print $"  • ($f)" }
    exit 1
  }

  let total = (($semver_cases | length) + ($bump_cases | length))
  print $"(ansi green_bold)✅ check-version-bumps self-test passed \(($total) cases\)(ansi reset)"
}
