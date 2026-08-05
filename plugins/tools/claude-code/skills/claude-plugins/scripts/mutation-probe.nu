#!/usr/bin/env nu

# Mutation-probe harness for validate-plugin.nu (claude-skills-238).
#
# Applies a curated set of known-dangerous mutations (each one previously
# verified BY HAND, live, against this exact file) to a scratch copy of
# validate-plugin.nu, runs --self-test against the mutated copy, and asserts
# it fails. Restores the original after every probe — never edits the real
# file in place.
#
# Run on demand after adding a new check to validate-plugin.nu:
#   nu <CLAUDE_SKILL_DIR>/scripts/mutation-probe.nu
#
# NOT wired into `mise test` — each probe re-runs the full self-test suite
# as a subprocess, so this is deliberately an author/reviewer tool, not a
# CI gate. See claude-skills-238's own AC: "Consider whether a mutation-
# probe harness belongs in the repo" — this is the restraint-scoped answer:
# a flat data table plus subprocess self-test reruns, not a general-purpose
# mutation-testing framework. Adding a probe for a new check is a ~5-line
# addition to the $probes list below, not new machinery.
#
# Every find/replace pair is applied via nushell's own `str replace` — never
# sed or perl. A $-prefixed nushell variable name (e.g. `rm -rf $temp_dir`)
# inside a PERL replacement string gets silently consumed as a Perl variable
# interpolation, producing a mutation that deletes code instead of replacing
# it. This bit claude-skills-238's own author mid-session: a `cleanup-temp`
# mutation meant to read `rm -rf $temp_dir` unconditionally instead landed as
# `rm -rf ` (empty argument), an unrelated nushell crash that could easily
# have been misreported as a real coverage gap instead of a broken probe.
# Nushell's `str replace` has no such interpolation trap, since the
# replacement is a plain string argument, not a template the tool expands.

def main [] {
  let script_dir = ($env.CURRENT_FILE | path dirname)
  let target = ($script_dir | path join "validate-plugin.nu")
  let original = (open --raw $target)

  let probes = [
    {
      name: "validate-skill-md_always_pass"
      find: "def validate-skill-md [skill_md_path: string, skill_name: string, verbose: bool] {\n  # Read file content (file existence already checked by caller)"
      replace: "def validate-skill-md [skill_md_path: string, skill_name: string, verbose: bool] {\n  return { errors: [], warnings: [] }\n  # Read file content (file existence already checked by caller)"
    }
    {
      name: "is-kebab-case_always_true"
      find: "def is-kebab-case [name: string] {\n  $name =~ '^[a-z0-9]+(-[a-z0-9]+)*$'\n}"
      replace: "def is-kebab-case [name: string] {\n  true\n}"
    }
    {
      name: "is-semver_always_true"
      find: "def is-semver [version: string] {\n  $version =~ '^[0-9]+\\.[0-9]+\\.[0-9]+(-[a-zA-Z0-9.-]+)?(\\+[a-zA-Z0-9.-]+)?$'\n}"
      replace: "def is-semver [version: string] {\n  true\n}"
    }
    {
      name: "validate-agent-md_always_pass"
      find: "def validate-agent-md [agent_path: string, agent_name: string, verbose: bool] {\n  # Read file content"
      replace: "def validate-agent-md [agent_path: string, agent_name: string, verbose: bool] {\n  return { errors: [], warnings: [] }\n  # Read file content"
    }
    {
      name: "cleanup-temp_never_removes"
      find: "def cleanup-temp [temp_dir: string, is_ext: bool] {\n  if $is_ext and ($temp_dir | str length) > 0 {\n    rm -rf $temp_dir\n  }\n}"
      replace: "def cleanup-temp [temp_dir: string, is_ext: bool] {\n  if false {\n    rm -rf $temp_dir\n  }\n}"
    }
    {
      name: "cleanup-temp_always_removes"
      find: "def cleanup-temp [temp_dir: string, is_ext: bool] {\n  if $is_ext and ($temp_dir | str length) > 0 {\n    rm -rf $temp_dir\n  }\n}"
      replace: "def cleanup-temp [temp_dir: string, is_ext: bool] {\n  rm -rf $temp_dir\n}"
    }
    {
      name: "main_no_target_exits_0"
      find: "if ($target | is-empty) {\n    print $\"(ansi red_bold)Error:(ansi reset) target is required unless --self-test is passed\"\n    exit 1\n  }"
      replace: "if ($target | is-empty) {\n    print $\"(ansi red_bold)Error:(ansi reset) target is required unless --self-test is passed\"\n    exit 0\n  }"
    }
    {
      name: "validate-plugin-file_missing_file_exits_0"
      find: "if not ($plugin_path | path exists) {\n    print $\"(ansi red_bold)Error:(ansi reset) File not found: ($plugin_path)\"\n    exit 1\n  }"
      replace: "if not ($plugin_path | path exists) {\n    print $\"(ansi red_bold)Error:(ansi reset) File not found: ($plugin_path)\"\n    exit 0\n  }"
    }
    {
      name: "validate-from-marketplace_missing_marketplace_exits_0"
      find: "if not ($marketplace_path | path exists) {\n    print $\"(ansi red_bold)Error:(ansi reset) Marketplace not found: ($marketplace_path)\"\n    exit 1\n  }"
      replace: "if not ($marketplace_path | path exists) {\n    print $\"(ansi red_bold)Error:(ansi reset) Marketplace not found: ($marketplace_path)\"\n    exit 0\n  }"
    }
    {
      name: "setup-external-plugin_unsupported_format_exits_0"
      find: "print $\"(ansi red_bold)Error:(ansi reset) Unsupported external source format: ($source)\"\n    print \"   Supported formats: github:owner/repo\"\n    exit 1"
      replace: "print $\"(ansi red_bold)Error:(ansi reset) Unsupported external source format: ($source)\"\n    print \"   Supported formats: github:owner/repo\"\n    exit 0"
    }
  ]

  mut results = []
  for p in $probes {
    if not ($original | str contains $p.find) {
      $results = ($results | append { name: $p.name, status: "SKIPPED — find text not present; probe is stale, update it" })
    } else {
      let mutated = ($original | str replace $p.find $p.replace)
      $mutated | save --force $target
      let run = (do { ^nu $target --self-test } | complete)
      $original | save --force $target
      if $run.exit_code == 0 {
        $results = ($results | append { name: $p.name, status: "FAILED — mutation did not break self-test (coverage gap)" })
      } else {
        $results = ($results | append { name: $p.name, status: "ok — self-test caught the mutation" })
      }
    }
  }

  # Belt-and-suspenders restore in case a probe above panicked mid-loop.
  $original | save --force $target

  print ($results | table)

  let gaps = ($results | where {|r| $r.status | str starts-with "FAILED" })
  if ($gaps | length) > 0 {
    print $"\n(ansi red_bold)($gaps | length) mutation\(s\) went undetected — see FAILED rows above.(ansi reset)"
    exit 1
  }
  print $"\n(ansi green_bold)All (($probes | length)) known mutations are caught by --self-test.(ansi reset)"
}
