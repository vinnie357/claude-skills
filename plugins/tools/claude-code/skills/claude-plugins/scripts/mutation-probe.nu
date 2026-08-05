#!/usr/bin/env nu

# Mutation-probe harness for validate-plugin.nu.
#
# Applies a curated set of known-dangerous mutations to a TEMP COPY of
# validate-plugin.nu, runs --self-test against the copy as a subprocess,
# and asserts self-test's own controlled-failure banner appears in stdout
# AND names the specific fixture case each mutation is expected to break —
# not just that self-test failed for some reason. The real file next to
# this script is opened read-only and never written.
#
# Run on demand after adding a new check to validate-plugin.nu:
#   nu <CLAUDE_SKILL_DIR>/scripts/mutation-probe.nu
#
# NOT wired into `mise test` — each probe reruns the full self-test suite
# as a subprocess against a temp copy, so this is deliberately an
# author/reviewer tool, not a CI gate.
#
# Three defects found in an earlier version of this script, each
# independently reproduced before being fixed here:
#
# F1 — the real file was mutated IN PLACE. `target` pointed at the sibling
# validate-plugin.nu, mutated content was written directly over it, and it
# was restored only if the probe loop ran to completion — despite this
# docstring and the introducing PR's body both asserting a "scratch copy"
# that never touched the real file. Reproduced live: `nu mutation-probe.nu &`
# followed by SIGINT ~4s in left validate-skill-md permanently neutered to
# always-pass on disk (sha256 18c31e97... before, bf92cc5e... after — the
# injected `return { errors: [], warnings: [] }` confirmed present). This
# script runs from inside the installed plugin cache when invoked as
# documented, where there is no git status to reveal the damage, and every
# later validator run from the loaded skill would silently use the
# neutered copy — a tool meant to prove checks work could leave them not
# working. Fixed by mutating a `mktemp -d` copy exclusively; self-test is
# location-independent (verified: identical results run from any
# directory), so nothing is lost by never touching the real file, and there
# is no interrupt window because the real file is opened for reading only.
#
# F2 — a probe whose `find` text no longer matches anything (this file has
# been touched by seven merged PRs in one day at points in its history —
# probe staleness is the steady state, not the exception) correctly showed
# SKIPPED in the results table, but SKIPPED did not affect the exit code or
# the final "All N caught" summary line. A caller checking exit 0 alone —
# scripted or agent-driven — read silent rot as success. Reproduced live
# with a single always-absent probe: table showed SKIPPED, next line still
# printed "All 1 known mutations are caught by --self-test." at exit 0.
# Fixed: any SKIPPED now fails the run.
#
# F3 — exit-code-only detection cannot distinguish self-test's own
# controlled failure (which prints a specific banner before its `exit 1`)
# from an outright interpreter crash (a parse error or a call to an
# undefined command, which also exits nonzero but runs zero of the queued
# fixture cases). Reproduced live: mutating is-kebab-case to call a
# nonexistent external command crashed on the very first fixture case
# (nu::shell::external_command) and was still reported "ok — caught".
# Fixed: require the self-test failure banner in stdout, not just a
# nonzero exit; anything else with a nonzero exit is reported CRASHED, and
# also fails the run — a crash proves nothing about whether any fixture
# caught the mutation.
#
# Kill attribution: each probe also names the specific self-test case
# substring it expects to see among the printed failures — not just that
# self-test failed for SOME reason, which could be a different, unrelated
# fixture masking the real gap. Every substring below was read directly out
# of the corresponding fixture block in validate-plugin.nu (the `name:`
# field plus whatever prefix its own failure-message template adds — e.g.
# skill_md_cases prepends "skill_md_", cli_cases uses the bare name), not
# guessed or carried over from an earlier, unrelated draft of this file.
#
# Every find/replace pair is applied via nushell's own `str replace` — never
# sed or perl. A $-prefixed nushell variable name inside a PERL replacement
# string gets silently consumed as a Perl variable interpolation, producing
# a mutation that deletes code instead of replacing it — this bit this
# script's own author mid-session, independently of F1/F2/F3 above.

def main [] {
  let script_dir = ($env.CURRENT_FILE | path dirname)
  let real_target = ($script_dir | path join "validate-plugin.nu")
  let original = (open --raw $real_target)
  let failure_banner = "self-test failed:"

  let probes = [
    {
      name: "validate-skill-md_always_pass"
      find: "def validate-skill-md [skill_md_path: string, skill_name: string, verbose: bool] {\n  # Read file content (file existence already checked by caller)"
      replace: "def validate-skill-md [skill_md_path: string, skill_name: string, verbose: bool] {\n  return { errors: [], warnings: [] }\n  # Read file content (file existence already checked by caller)"
      expect_case_substring: "skill_md_missing_frontmatter"
    }
    {
      name: "is-kebab-case_always_true"
      find: "def is-kebab-case [name: string] {\n  $name =~ '^[a-z0-9]+(-[a-z0-9]+)*$'\n}"
      replace: "def is-kebab-case [name: string] {\n  true\n}"
      expect_case_substring: "plugin_name_bad_kebab_case_errors"
    }
    {
      name: "is-semver_always_true"
      find: "def is-semver [version: string] {\n  $version =~ '^[0-9]+\\.[0-9]+\\.[0-9]+(-[a-zA-Z0-9.-]+)?(\\+[a-zA-Z0-9.-]+)?$'\n}"
      replace: "def is-semver [version: string] {\n  true\n}"
      expect_case_substring: "top_level_version_malformed_warns"
    }
    {
      name: "validate-agent-md_always_pass"
      find: "def validate-agent-md [agent_path: string, agent_name: string, verbose: bool] {\n  # Read file content"
      replace: "def validate-agent-md [agent_path: string, agent_name: string, verbose: bool] {\n  return { errors: [], warnings: [] }\n  # Read file content"
      expect_case_substring: "agent_md_missing_frontmatter"
    }
    {
      name: "cleanup-temp_never_removes"
      find: "def cleanup-temp [temp_dir: string, is_ext: bool] {\n  if $is_ext and ($temp_dir | str length) > 0 {\n    rm -rf $temp_dir\n  }\n}"
      replace: "def cleanup-temp [temp_dir: string, is_ext: bool] {\n  if false {\n    rm -rf $temp_dir\n  }\n}"
      expect_case_substring: "cleanup_temp_is_ext_true"
    }
    {
      name: "cleanup-temp_always_removes"
      find: "def cleanup-temp [temp_dir: string, is_ext: bool] {\n  if $is_ext and ($temp_dir | str length) > 0 {\n    rm -rf $temp_dir\n  }\n}"
      replace: "def cleanup-temp [temp_dir: string, is_ext: bool] {\n  rm -rf $temp_dir\n}"
      expect_case_substring: "cleanup_temp_is_ext_false"
    }
    {
      name: "main_no_target_exits_0"
      find: "if ($target | is-empty) {\n    print $\"(ansi red_bold)Error:(ansi reset) target is required unless --self-test is passed\"\n    exit 1\n  }"
      replace: "if ($target | is-empty) {\n    print $\"(ansi red_bold)Error:(ansi reset) target is required unless --self-test is passed\"\n    exit 0\n  }"
      expect_case_substring: "cli_no_target_exit_1"
    }
    {
      name: "validate-plugin-file_missing_file_exits_0"
      find: "if not ($plugin_path | path exists) {\n    print $\"(ansi red_bold)Error:(ansi reset) File not found: ($plugin_path)\"\n    exit 1\n  }"
      replace: "if not ($plugin_path | path exists) {\n    print $\"(ansi red_bold)Error:(ansi reset) File not found: ($plugin_path)\"\n    exit 0\n  }"
      expect_case_substring: "cli_missing_file_exit_1"
    }
    {
      name: "validate-from-marketplace_missing_marketplace_exits_0"
      find: "if not ($marketplace_path | path exists) {\n    print $\"(ansi red_bold)Error:(ansi reset) Marketplace not found: ($marketplace_path)\"\n    exit 1\n  }"
      replace: "if not ($marketplace_path | path exists) {\n    print $\"(ansi red_bold)Error:(ansi reset) Marketplace not found: ($marketplace_path)\"\n    exit 0\n  }"
      expect_case_substring: "cli_marketplace_missing_exit_1"
    }
    {
      name: "setup-external-plugin_unsupported_format_exits_0"
      find: "print $\"(ansi red_bold)Error:(ansi reset) Unsupported external source format: ($source)\"\n    print \"   Supported formats: github:owner/repo\"\n    exit 1"
      replace: "print $\"(ansi red_bold)Error:(ansi reset) Unsupported external source format: ($source)\"\n    print \"   Supported formats: github:owner/repo\"\n    exit 0"
      expect_case_substring: "cli_marketplace_unsupported_external_source_exit_1"
    }
  ]

  mut results = []
  for p in $probes {
    if not ($original | str contains $p.find) {
      $results = ($results | append { name: $p.name, ok: false, status: "SKIPPED — find text not present; probe is stale, update it" })
    } else {
      # Mutate a throwaway temp copy only. The real file (`$original`) is
      # never opened for writing anywhere in this script — see F1 above.
      let probe_dir = (mktemp -d)
      let temp_target = ($probe_dir | path join "validate-plugin.nu")
      ($original | str replace $p.find $p.replace) | save --force $temp_target
      # No timeout here: a mutation that makes --self-test hang (rather
      # than fail or crash) would hang this harness indefinitely too.
      # Accepted for a curated, on-demand, human-run tool — not worth
      # timeout machinery for a failure mode none of the 10 probes below
      # exhibit. If this ever hangs, that IS the finding: Ctrl+C, then look
      # at what the most recently added/changed probe touches.
      let run = (do { ^nu $temp_target --self-test } | complete)
      rm -rf $probe_dir

      let has_banner = ($run.stdout | str contains $failure_banner)
      let has_case = ($run.stdout | str contains $p.expect_case_substring)

      if $run.exit_code == 0 {
        $results = ($results | append { name: $p.name, ok: false, status: "FAILED — mutation did not break self-test (coverage gap)" })
      } else if not $has_banner {
        $results = ($results | append { name: $p.name, ok: false, status: "CRASHED — nonzero exit but no self-test failure banner in stdout; the interpreter crashed rather than a fixture catching it (proves nothing — see F3)" })
      } else if not $has_case {
        $results = ($results | append { name: $p.name, ok: false, status: $"WRONG CASE — self-test failed, but not on the expected case '($p.expect_case_substring)'; a different fixture may be masking this gap" })
      } else {
        $results = ($results | append { name: $p.name, ok: true, status: "ok — self-test caught the mutation via the expected case" })
      }
    }
  }

  # Real file was only ever read (`$original`, above) — nothing to restore.
  if ($original != (open --raw $real_target)) {
    print $"(ansi red_bold)INTERNAL ERROR:(ansi reset) the real validate-plugin.nu changed during this run despite never being opened for writing. Investigate before trusting any result above."
    exit 1
  }

  print ($results | select name status | table)

  let gaps = ($results | where ok == false)
  if ($gaps | length) > 0 {
    print $"\n(ansi red_bold)($gaps | length) of (($probes | length)) probes did not cleanly confirm coverage — see non-ok rows above.(ansi reset)"
    exit 1
  }
  print $"\n(ansi green_bold)All (($probes | length)) known mutations are caught by --self-test, each via its expected case.(ansi reset)"
}
