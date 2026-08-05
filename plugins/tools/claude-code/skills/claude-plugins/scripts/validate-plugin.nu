#!/usr/bin/env nu

# Validate Claude Code plugin.json file
#
# Usage:
#   nu validate-plugin.nu <path-to-plugin.json> [--verbose]
#   nu validate-plugin.nu <plugin-name> --marketplace <marketplace-path> [--verbose]
#
# Modes:
#   Direct:      Validate a plugin.json file directly
#   Marketplace: Validate a plugin by name from marketplace (supports external plugins)

def main [
  target?: string              # Path to plugin.json OR plugin name (when using --marketplace)
  --marketplace: string       # Path to marketplace.json (enables name-based lookup)
  --verbose                   # Show detailed validation output
  --self-test                 # Run the fixture-based self-test suite and exit
  --strict                    # Treat warnings as errors, mirroring upstream's `claude plugin validate --strict`
                               # (https://code.claude.com/docs/en/plugins-reference: "Pass --strict to treat
                               # warnings as errors. Use it in CI to catch a misspelled field name...")
] {
  if $self_test {
    self-test
    return
  }

  if ($target | is-empty) {
    print $"(ansi red_bold)Error:(ansi reset) target is required unless --self-test is passed"
    exit 1
  }

  # Determine mode based on --marketplace flag
  if ($marketplace | is-not-empty) {
    validate-from-marketplace $target $marketplace $verbose $strict
  } else {
    validate-plugin-file $target $verbose $strict
  }
}

# Validate a plugin by name from marketplace
def validate-from-marketplace [plugin_name: string, marketplace_path: string, verbose: bool, strict: bool] {
  print $"(ansi green_bold)Validating plugin:(ansi reset) ($plugin_name)\n"

  # Load marketplace
  if not ($marketplace_path | path exists) {
    print $"(ansi red_bold)Error:(ansi reset) Marketplace not found: ($marketplace_path)"
    exit 1
  }

  # claude-skills-244 Gate 3 round 3 — a THIRD instance of the same crash
  # class #223/#224 already fixed for agents/skills, and the simplest to
  # trigger: `path exists` is true for directories too, and the `open`
  # below has no try/catch (unlike the two other `open $plugin_path` call
  # sites in this file, which ARE wrapped and verified to catch
  # is_a_directory cleanly). A plain CLI typo — `--marketplace` pointed at
  # a directory instead of marketplace.json — crashed with an uncaught
  # nu::shell::io::is_a_directory, reproduced with zero mutation and no
  # plugin.json involved at all. `path expand` before `path type` for the
  # same symlink-safety reason as the agents/skills guards above.
  if ($marketplace_path | path expand | path type) != "file" {
    print $"(ansi red_bold)Error:(ansi reset) Marketplace path is not a file: ($marketplace_path)"
    exit 1
  }

  # claude-skills-247 — two more crash shapes on this same file, both
  # reproduced with zero mutation before this fix: (1) nu's `from json`
  # leniency (claude-skills-243's exact defect, in this THIRD `open` call
  # site — #227's record guards only covered the two `open $plugin_path`
  # sites, not this marketplace one) — a malformed marketplace.json that
  # parses to a bare scalar crashes `$marketplace.plugins` with
  # `incompatible_path_access: string doesn't support cell paths`; (2) a
  # syntactically valid marketplace.json missing the `plugins` key
  # entirely crashes with `column_not_found`, since `.plugins` is a bare
  # cell-path access, not a `get -o`.
  let marketplace = try {
    open $marketplace_path
  } catch {
    print $"(ansi red_bold)Error:(ansi reset) Failed to parse marketplace.json: ($marketplace_path)"
    exit 1
  }
  if not ($marketplace | describe | str starts-with "record") {
    print $"(ansi red_bold)Error:(ansi reset) Failed to parse marketplace.json: ($marketplace_path)"
    exit 1
  }
  let marketplace_dir = ($marketplace_path | path dirname | path dirname)

  # Find plugin entry. `get -o plugins | default []` rather than the bare
  # `.plugins` cell-path access above — a marketplace.json missing the key
  # entirely now falls through to the existing "not found in marketplace"
  # branch below instead of crashing on `column_not_found`.
  #
  # claude-skills-247 Gate 3 — a `plugins` key that's PRESENT but
  # wrong-typed crashes in (at least) three distinct sub-shapes, all
  # reproduced with zero mutation before fixing:
  #   1. `{"plugins": "hi"}` — describe "string", crashes piped into
  #      `where` (only_supports_this_input_type).
  #   2. `{"plugins": [42, "x"]}` — passes the list-type check, but
  #      crashes on the first non-record entry
  #      (incompatible_path_access: int doesn't support cell paths).
  #   3. `{"plugins": [{"foo": 1}]}` — a genuine RECORD, but missing the
  #      `name` column. This one is NOT caught by filtering to records
  #      alone: nushell's `where name == ...` does not silently skip a
  #      record lacking the compared column, it raises
  #      column_not_found — verified directly and independently of the
  #      shape-1/shape-2 cases above, which is why an earlier version of
  #      this guard's own comment (and this PR's body) claiming "a
  #      malformed entry is tolerated (skipped)" was WRONG for this
  #      specific sub-shape: a pre-filter that only checks "is this a
  #      record" does not protect the subsequent `.name` access at all.
  # Two guards: reject a non-list/table `plugins` outright (closes shape
  # 1), then a SINGLE closure that checks record-ness AND safely reads
  # `name` via `get -o` (not bare `.name`) before comparing — closes
  # shapes 2 and 3 together, since `get -o` returns null rather than
  # raising for a missing column.
  let plugins_value = ($marketplace | get -o plugins | default [])
  let plugins_type = ($plugins_value | describe)
  if not (($plugins_type | str starts-with "list") or ($plugins_type | str starts-with "table")) {
    print $"(ansi red_bold)Error:(ansi reset) Marketplace 'plugins' must be an array: ($marketplace_path)"
    exit 1
  }
  let plugin_entry = ($plugins_value | where {|p| (($p | describe | str starts-with "record") and (($p | get -o name) == $plugin_name)) } | first)
  if ($plugin_entry | is-empty) {
    print $"(ansi red_bold)Error:(ansi reset) Plugin '($plugin_name)' not found in marketplace"
    exit 1
  }

  let source = ($plugin_entry | get -o source | default "./")
  let source_type = ($source | describe)
  let is_external = ($source_type | str starts-with "record")

  # Set up validation context
  let validation_context = if $is_external {
    setup-external-plugin $source $plugin_name
  } else {
    { plugin_root: $marketplace_dir, temp_dir: "", is_external: false }
  }

  let plugin_root = $validation_context.plugin_root
  let temp_dir = $validation_context.temp_dir
  let is_ext = $validation_context.is_external

  # Derive source_dir from source field (strip leading ./)
  let source_dir = if $is_ext {
    $plugin_name
  } else {
    ($source | str replace --regex '^\./' '')
  }

  # Determine plugin.json path
  let plugin_path = if $plugin_name == "all-skills" {
    ($plugin_root | path join ".claude-plugin" "plugin.json")
  } else if $is_ext {
    ($plugin_root | path join ".claude-plugin" "plugin.json")
  } else {
    ($plugin_root | path join $source_dir ".claude-plugin" "plugin.json")
  }

  # Check if plugin.json exists
  if not ($plugin_path | path exists) {
    print $"(ansi red_bold)Error:(ansi reset) plugin.json not found at ($plugin_path)"
    cleanup-temp $temp_dir $is_ext
    exit 1
  }

  # Run validation
  # Compare description/keywords against the marketplace entry only for local
  # (non-external) sources — a GitHub-object source has no local plugin.json
  # to compare against the clone's, so that comparison is skipped entirely.
  let result = if $is_ext {
    validate-plugin-content $plugin_path $plugin_root $plugin_name $source_dir $is_ext $verbose $strict
  } else {
    validate-plugin-content $plugin_path $plugin_root $plugin_name $source_dir $is_ext $verbose $strict --has-marketplace-context --mkt-description ($plugin_entry | get -o description | default "") --mkt-keywords ($plugin_entry | get -o keywords | default [])
  }

  # Cleanup temp directory
  cleanup-temp $temp_dir $is_ext

  # Handle result
  if $result.success {
    print $"\n(ansi green_bold)✓ Plugin '($plugin_name)' is valid!(ansi reset)"
    exit 0
  } else {
    exit 1
  }
}

# Validate a plugin.json file directly
def validate-plugin-file [plugin_path: string, verbose: bool, strict: bool] {
  print $"(ansi green_bold)Validating plugin:(ansi reset) ($plugin_path)\n"

  if not ($plugin_path | path exists) {
    print $"(ansi red_bold)Error:(ansi reset) File not found: ($plugin_path)"
    exit 1
  }

  let plugin_dir = ($plugin_path | path dirname)
  let plugin_root = ($plugin_dir | path dirname)

  # Try to determine plugin name from the JSON
  let plugin = try {
    open $plugin_path
  } catch {
    print $"(ansi red_bold)Error:(ansi reset) Invalid JSON syntax in ($plugin_path)"
    exit 1
  }

  # claude-skills-243 — nu's `from json` (what `open` calls for a .json
  # extension) parses JSON5-style bare scalars leniently instead of
  # raising: a bare string, number, bool, or list all come back as that
  # scalar type rather than triggering the catch above (verified directly:
  # `"not valid json {{{" | from json | describe` => "string", `"42" |
  # from json | describe` => "int", `"true"` => "bool", `"[1, 2, 3]"` =>
  # "list<int>"). Downstream code assumes a record and crashes with
  # `nu::shell::only_supports_this_input_type` instead of ever printing
  # this message. Reject anything that isn't a record here, routed into
  # the SAME message/exit as the catch above per the existing
  # cli_invalid_json_exit_1 fixture's compatibility constraint — not a
  # restructure of the catch, an addition after it.
  if not ($plugin | describe | str starts-with "record") {
    print $"(ansi red_bold)Error:(ansi reset) Invalid JSON syntax in ($plugin_path)"
    exit 1
  }

  let plugin_name = ($plugin | get -o name | default "unknown")

  let result = validate-plugin-content $plugin_path $plugin_root $plugin_name $plugin_name false $verbose $strict

  if $result.success {
    print $"\n(ansi green_bold)✓ Plugin is valid!(ansi reset)"
    exit 0
  } else {
    exit 1
  }
}

# Set up external plugin (clone from GitHub)
def setup-external-plugin [source: any, plugin_name: string] {
  # Handle object-style source (e.g., {source: "github", repo: "owner/repo"})
  let source_kind = ($source | describe)
  let is_github = if ($source_kind | str starts-with "record") {
    ($source | get -o source) == "github"
  } else {
    ($source | str starts-with "github:")
  }
  let repo_path = if ($source_kind | str starts-with "record") {
    ($source | get -o repo | default "")
  } else {
    ($source | str replace "github:" "")
  }

  if $is_github and ($repo_path | str length) > 0 {
    let github_url = $"https://github.com/($repo_path).git"

    let temp_clone_dir = (mktemp -d)
    print $"(ansi cyan)📥 Fetching external plugin from ($github_url)...(ansi reset)"

    let clone_result = (do { git clone --depth 1 --quiet $github_url $temp_clone_dir } | complete)
    if $clone_result.exit_code != 0 {
      print $"(ansi red_bold)Error:(ansi reset) Failed to clone ($github_url)"
      print $clone_result.stderr
      rm -rf $temp_clone_dir
      exit 1
    }

    print $"   Cloned to temp directory for validation\n"
    { plugin_root: $temp_clone_dir, temp_dir: $temp_clone_dir, is_external: true }
  } else {
    print $"(ansi red_bold)Error:(ansi reset) Unsupported external source format: ($source)"
    print "   Supported formats: github:owner/repo"
    exit 1
  }
}

# Clean up temporary directory
def cleanup-temp [temp_dir: string, is_ext: bool] {
  if $is_ext and ($temp_dir | str length) > 0 {
    rm -rf $temp_dir
  }
}

# Core validation logic
def validate-plugin-content [
  plugin_path: string
  plugin_root: string
  plugin_name: string
  source_dir: string
  is_external: bool
  verbose: bool
  strict: bool                     # claude-skills-234 — mirrors upstream's `--strict`: promote
                                    # warnings to a failing result without reclassifying them as
                                    # errors in the printed list (so the distinction stays visible).
  --mkt-description: string = ""   # marketplace.json entry's description, for local sources only
  --mkt-keywords: list<string> = [] # marketplace.json entry's keywords, for local sources only
  --has-marketplace-context        # true only when the caller has an actual marketplace entry to
                                    # compare against (validate-from-marketplace's local-source
                                    # branch). Direct-file mode (validate-plugin-file) and the
                                    # external/GitHub-object branch of validate-from-marketplace
                                    # omit this flag on purpose — they have no marketplace entry at
                                    # all, and --mkt-description/--mkt-keywords defaulting to
                                    # ""/[] is indistinguishable from "marketplace entry deleted
                                    # the field" without this flag. Without it, claude-skills-170's
                                    # deletion-is-a-failure fix fired on those defaults and broke
                                    # both non-marketplace invocation modes.
] {
  let plugin = try {
    open $plugin_path
  } catch {
    print $"(ansi red_bold)Error:(ansi reset) Failed to parse plugin.json"
    return { success: false, errors: ["Failed to parse plugin.json"], warnings: [] }
  }

  # claude-skills-243 — the SECOND instance of the lenient-scalar guard
  # hole: this function has its own try/catch and its own message, reached
  # directly from validate-from-marketplace (bypassing validate-plugin-
  # file's copy of this same guard entirely). Same leniency, same fix
  # shape, this function's own message per the compatibility constraint.
  if not ($plugin | describe | str starts-with "record") {
    print $"(ansi red_bold)Error:(ansi reset) Failed to parse plugin.json"
    return { success: false, errors: ["Failed to parse plugin.json"], warnings: [] }
  }

  mut errors = []
  mut warnings = []

  # Check required fields
  print $"(ansi cyan)Checking required fields...(ansi reset)"

  if ($plugin | get -o name) == null {
    $errors = ($errors | append "Missing required field: 'name'")
  } else {
    let name = $plugin.name

    # Validate kebab-case
    if not (is-kebab-case $name) {
      $errors = ($errors | append $"Invalid name format: '($name)' \(must be kebab-case\)")
    }

    # Verify name matches expected
    if $name != $plugin_name {
      $errors = ($errors | append $"Name mismatch - expected '($plugin_name)', got '($name)'")
    } else if $verbose {
      print $"  ✓ name: ($name)"
    }
  }

  # Check for invalid fields (marketplace-entry-only — confirmed against
  # upstream's marketplace-entries schema, which lists these as
  # "marketplace-specific fields" distinct from the plugin manifest schema:
  # https://code.claude.com/docs/en/plugin-marketplaces#plugin-entries).
  # `dependencies` was removed from this list (claude-skills-218) — upstream
  # documents it as a valid plugin.json field (array of plugin names and/or
  # {name, version} objects): https://code.claude.com/docs/en/plugins-reference#plugin-manifest-schema
  print $"\n(ansi cyan)Checking for invalid fields...(ansi reset)"
  let invalid_fields = ["category", "strict", "source", "tags"]
  for field in $invalid_fields {
    if ($plugin | get -o $field) != null {
      $errors = ($errors | append $"Invalid field '($field)' - this belongs in marketplace.json, not plugin.json")
    }
  }

  if $verbose {
    print "  ✓ No invalid fields found"
  }

  # Warn (never hard-fail) on any top-level field this validator doesn't
  # recognize (claude-skills-219). Upstream's own `claude plugin validate`
  # treats unrecognized fields as warnings, not errors, specifically so a
  # manifest can double as another tool's manifest (npm package.json, a VS
  # Code extension manifest) without failing:
  # https://code.claude.com/docs/en/plugins-reference#unrecognized-fields
  # This list is every field currently documented for plugin.json — keep it
  # in sync with the field tables in SKILL.md when upstream adds one.
  let known_fields = [
    "name", "$schema", "displayName", "version", "description", "author",
    "homepage", "repository", "license", "keywords", "defaultEnabled",
    "skills", "commands", "agents", "workflows", "hooks", "mcpServers",
    "outputStyles", "lspServers", "experimental", "userConfig", "channels",
    "dependencies"
  ]
  for field in ($plugin | columns) {
    if ($field not-in $known_fields) and ($field not-in $invalid_fields) {
      $warnings = ($warnings | append $"Unrecognized field '($field)' - not a known plugin.json field \(see the claude-plugins skill for the current schema; may be intentional metadata for another tool\)")
    }
  }

  # Validate `dependencies` shape: an array of plugin names (string) and/or
  # {name, version} objects, per upstream's example
  # `["helper-lib", { "name": "secrets-vault", "version": "~2.1.0" }]`.
  if ($plugin | get -o dependencies) != null {
    let deps_type = ($plugin.dependencies | describe)
    # A homogeneous array of records/objects (e.g. every dependency entry
    # using the {name, version} shape) describes as "table<...>" in
    # nushell, not "list<...>" — a plain array of strings describes as
    # "list<string>". Accept both; a genuinely non-array value (string,
    # record, etc.) matches neither prefix.
    if not (($deps_type | str starts-with "list") or ($deps_type | str starts-with "table")) {
      $errors = ($errors | append $"'dependencies' must be an array, got ($deps_type)")
    } else {
      for dep in $plugin.dependencies {
        let dep_type = ($dep | describe)
        if $dep_type == "string" {
          # valid: bare plugin name
        } else if ($dep_type | str starts-with "record") {
          if ($dep | get -o name) == null {
            $errors = ($errors | append $"dependencies entry missing required 'name' field: ($dep | to nuon)")
          }
          # claude-skills-235: validate `version` as a node-semver RANGE
          # expression, not an exact version — upstream: "The version field
          # accepts any expression supported by Node's semver package,
          # including caret, tilde, hyphen, and comparator ranges"
          # (https://code.claude.com/docs/en/plugin-dependencies). Reusing
          # is-semver here would wrongly reject upstream's own documented
          # example (~2.1.0), which is a range, not an exact version.
          let dep_version = ($dep | get -o version)
          if ($dep_version != null) and not (is-semver-range $dep_version) {
            let dep_label = ($dep | get -o name | default "?")
            $errors = ($errors | append $"dependencies entry '($dep_label)' has a malformed version constraint: '($dep_version)' \(expected a node-semver range like ~2.1.0, ^2.0, >=1.4, =2.1.0, or 1.2.3 - 2.3.4 — see https://code.claude.com/docs/en/plugin-dependencies\)")
          }
        } else {
          $errors = ($errors | append $"dependencies entry must be a string or object, got ($dep_type)")
        }
      }
    }
  }

  # Check recommended fields
  if ($plugin | get -o version) == null {
    $warnings = ($warnings | append "Missing recommended field: version")
  } else {
    if not (is-semver $plugin.version) {
      $warnings = ($warnings | append $"version should use semantic versioning: ($plugin.version)")
    } else if $verbose {
      print $"  ✓ version: ($plugin.version)"
    }
  }

  if ($plugin | get -o description) == null {
    $warnings = ($warnings | append "Missing recommended field: description")
  } else if $verbose {
    print $"  ✓ description: ($plugin.description)"
  }

  # Description agreement with the marketplace entry — plugin.json is
  # authoritative, the marketplace entry is the copy, and only when the
  # caller actually has a marketplace entry to compare against (see
  # --has-marketplace-context above and the caller for the gate). Within
  # that scope, gated on plugin.json defining the field, not on the
  # marketplace side: when plugin.json HAS a description, the marketplace
  # entry omitting it is itself a failure (Level 1 discovery text silently
  # disappearing from the marketplace listing), not a valid "both sides
  # agree to omit it" state — a bare deletion of the marketplace field used
  # to pass this check silently (claude-skills-170). plugin.json omitting
  # the field entirely stays a soft warning above; nothing here.
  # NOTE: `mise update-all-skills` does NOT maintain the all-skills
  # description, so that one entry can drift again after this check passes.
  if $has_marketplace_context {
    let pj_description = ($plugin | get -o description)
    if ($pj_description | is-not-empty) {
      if ($mkt_description | is-empty) {
        $errors = ($errors | append $"marketplace.json entry is missing 'description' that plugin.json defines: '($pj_description)'")
      } else if ($pj_description != $mkt_description) {
        let regen_note = if ($plugin | get -o name) == "all-skills" {
          " \(mise update-all-skills does not maintain this description, so it can drift again\)"
        } else { "" }
        $errors = ($errors | append $"description mismatch — plugin.json is authoritative: plugin.json='($pj_description)' marketplace.json='($mkt_description)'($regen_note)")
      }
    }
  }

  if ($plugin | get -o license) == null {
    $warnings = ($warnings | append "Missing recommended field: license")
  } else if $verbose {
    print $"  ✓ license: ($plugin.license)"
  }

  # Validate author
  if ($plugin | get -o author) != null {
    let author = $plugin.author
    if ($author | get -o name) != null and $verbose {
      print $"  ✓ author.name: ($author.name)"
    }
    if ($author | get -o email) != null and $verbose {
      print $"  ✓ author.email: ($author.email)"
    }
    if ($author | get -o url) != null and $verbose {
      print $"  ✓ author.url: ($author.url)"
    }
  }

  # Check for skills/sources.md (recommended for plugins with skills).
  # all-skills is exempt: it's the meta-plugin that aggregates every other
  # plugin's skill paths (see `skills` field), so it has no repo-root
  # `skills/sources.md` of its own — each aggregated skill's owning plugin
  # already carries and is checked against its own sources.md when that
  # plugin is validated directly. Checking for a nonexistent repo-root file
  # here was a claude-skills-234 discovery: it warned unconditionally.
  if not $is_external and $plugin_name != "all-skills" and ($plugin | get -o skills) != null {
    let sources_path = ($plugin_root | path join $source_dir "skills" "sources.md")
    if not ($sources_path | path exists) {
      $warnings = ($warnings | append "Missing recommended file: skills/sources.md")
    } else if $verbose {
      print "  ✓ skills/sources.md exists"
    }
  }

  # Validate skills paths
  if ($plugin | get -o skills) != null {
    print $"\n(ansi cyan)Validating skills...(ansi reset)"

    let skills_type = ($plugin.skills | describe)
    # claude-skills-245 — no `$skills_type == "nothing"` branch here on
    # purpose: this whole block is already gated by `($plugin | get -o
    # skills) != null` above, and a JSON `null` loads through nu's `open`
    # as `nothing`, so `nothing == null` is true and the outer guard skips
    # this block entirely before any inner check runs. A branch here for
    # that case was unreachable dead code — verified directly with a real
    # on-disk manifest (`"skills": null`) through the actual CLI: 0 errors,
    # "✓ Plugin is valid!". Deleted rather than fixtured, since a fixture
    # for unreachable code would pass for a reason unrelated to what it
    # claims to test.
    if not ($skills_type | str starts-with "list") {
      $errors = ($errors | append $"skills must be an array, got ($skills_type)")
    } else {
      for skill in $plugin.skills {
        let skill_path = if $plugin_name == "all-skills" {
          ($plugin_root | path join $skill)
        } else if $is_external {
          ($plugin_root | path join $skill)
        } else {
          ($plugin_root | path join $source_dir $skill)
        }

        if not ($skill_path | path exists) {
          $warnings = ($warnings | append $"Skill path not found: ($skill)")
        } else {
          let skill_md = ($skill_path | path join "SKILL.md")
          # claude-skills-244 Gate 3 rounds 2-4 — validate-skill-md's `open
          # $skill_md_path --raw` crashes with an uncaught nu shell I/O
          # error whenever this code believes SKILL.md is a readable file
          # but it isn't. Two DISTINCT unsafe shapes, both reproduced with
          # ZERO mutation on real pre-fix code (not just under a contrived
          # mutation):
          #   1. SKILL.md is a directory (e.g. `mkdir .../SKILL.md`) — the
          #      original `not (path exists)` guard alone is TRUE-passing
          #      (a directory exists), so it falls straight into `open` and
          #      crashes. No mutation needed — round 4's Gate 3 finding.
          #   2. A guard MUTATED to check the wrong thing (e.g. skill_md's
          #      dirname, which is skill_path itself, already confirmed to
          #      exist by the outer branch) makes a bare `not (path
          #      exists)` guard permanently inert for every genuinely
          #      missing SKILL.md — round 2's finding.
          # Both are covered by requiring `path type == "file"` (after
          # `path expand`, for symlink-safety — round 3's finding: bare
          # `path type` reports "symlink" regardless of target, so a
          # symlinked SKILL.md that `open` reads fine would be
          # false-positive rejected without the expand) BEFORE calling
          # validate-skill-md, structured as two checks on purpose rather
          # than one `!= "file"` branch: the outer `not (path exists)`
          # keeps the existing "missing SKILL.md file" message for the
          # common case (genuinely absent), and the inner type check is a
          # SEPARATE, more specific "is a directory" message — reported
          # distinct on purpose (team-lead's Gate 3 round 4 finding: a
          # vaguer shared message sends someone looking for an absent file
          # when the real problem is a directory). The inner check also
          # means this is safe in depth: even a mutated outer guard still
          # can't reach `open` with a non-file path, because `path expand |
          # path type` on a path that doesn't really exist resolves to
          # empty (not "file"), same as it does for a genuine directory.
          # A broken/dangling symlink IS caught here, but by THIS check
          # specifically, not by the type check below (correction to an
          # earlier draft of this comment, which wrongly attributed it to
          # the type check — that claim was accurate for a prior, single-
          # condition version of this guard, not this one). Bare `path
          # exists` (unlike `path expand | path type`) follows a symlink to
          # its target and reports whether the TARGET exists, so a dangling
          # SKILL.md symlink makes `not ($skill_md | path exists)` true —
          # verified directly. It lands here as "missing SKILL.md file",
          # never reaching the `path expand | path type` branch at all;
          # don't "fix" that as a gap.
          if not ($skill_md | path exists) {
            $errors = ($errors | append $"Skill directory '($skill)' missing SKILL.md file")
          } else if ($skill_md | path expand | path type) != "file" {
            let skill_md_type = ($skill_md | path expand | path type)
            let type_desc = if $skill_md_type == "dir" { "a directory" } else { $"an unexpected path type \(($skill_md_type)\)" }
            $errors = ($errors | append $"Skill directory '($skill)' has a SKILL.md that is ($type_desc), not a file")
          } else {
            # Validate SKILL.md content
            let validation = (validate-skill-md $skill_md $skill $verbose)
            $errors = ($errors | append $validation.errors)
            $warnings = ($warnings | append $validation.warnings)
          }
        }
      }

      if $verbose {
        print $"  Total skills: (($plugin.skills | length))"
      }
    }
  }

  # Validate commands
  let commands_value = ($plugin | get -o commands)
  if $commands_value != null {
    let commands_type = ($commands_value | describe)
    # claude-skills-245 — same unreachable-dead-code shape as skills above:
    # this block is gated by `$commands_value != null`, so a `nothing` type
    # (JSON null) never reaches an inner check. Deleted, verified directly.
    if $commands_type == "string" {
      # claude-skills-246 Gate 3 (team-lead's reviewer, corrected against
      # the actual upstream docs — verified directly at
      # code.claude.com/docs/en/plugins-reference before writing this:
      # the manifest field table documents `commands`/`agents` as
      # `string | array`, with bare-string examples, and "Replaces the
      # default: commands, agents..." for the string form). Existence-
      # check the string as a single path, exactly like an array entry's
      # path — NOT via the array-entry loop below, which enforces "must
      # be a file" and calls into content validation. The string form may
      # legitimately be a directory (it replaces the default commands/
      # scan), and this validator does not implement directory-content
      # scanning — that's the Claude Code loader's job at install time,
      # not this validator's at author time. Naively coercing the string
      # into a one-element list and reusing the array-entry loop would
      # wrongly flag a valid directory as an invalid single file entry —
      # the exact defect class claude-skills-244 fixed elsewhere.
      let command_path = if $plugin_name == "all-skills" {
        ($plugin_root | path join $commands_value)
      } else if $is_external {
        ($plugin_root | path join $commands_value)
      } else {
        ($plugin_root | path join $source_dir $commands_value)
      }
      if not ($command_path | path exists) {
        $warnings = ($warnings | append $"Command path not found: ($commands_value)")
      } else if $verbose {
        print $"  ✓ ($commands_value)"
      }
    } else if not ($commands_type | str starts-with "list") {
      $errors = ($errors | append $"commands must be a string or an array, got ($commands_type)")
    } else {
      print $"\n(ansi cyan)Validating commands...(ansi reset)"
      for command in $plugin.commands {
        let command_path = if $plugin_name == "all-skills" {
          ($plugin_root | path join $command)
        } else if $is_external {
          ($plugin_root | path join $command)
        } else {
          ($plugin_root | path join $source_dir $command)
        }

        if not ($command_path | path exists) {
          $warnings = ($warnings | append $"Command path not found: ($command)")
        } else if $verbose {
          print $"  ✓ ($command)"
        }
      }
    }
  }

  # Validate agents
  let agents_value = ($plugin | get -o agents)
  if $agents_value != null {
    let agents_type = ($agents_value | describe)
    # claude-skills-245 — same unreachable-dead-code shape as skills/
    # commands above: this block is gated by `$agents_value != null`, so a
    # `nothing` type (JSON null) never reaches an inner check. Deleted,
    # verified directly.
    if $agents_type == "string" {
      # claude-skills-246 — same string|array acceptance as commands
      # above, same reasoning: existence-check only, no file-type
      # enforcement and no content validation for the string form (it may
      # legitimately be a directory this validator does not scan).
      let agent_path = if $plugin_name == "all-skills" {
        ($plugin_root | path join $agents_value)
      } else if $is_external {
        ($plugin_root | path join $agents_value)
      } else {
        ($plugin_root | path join $source_dir $agents_value)
      }
      if not ($agent_path | path exists) {
        $warnings = ($warnings | append $"Agent path not found: ($agents_value)")
      } else if $verbose {
        print $"  ✓ ($agents_value)"
      }
    } else if not ($agents_type | str starts-with "list") {
      $errors = ($errors | append $"agents must be a string or an array, got ($agents_type)")
    } else {
      print $"\n(ansi cyan)Validating agents...(ansi reset)"
      for agent in $plugin.agents {
        let agent_path = if $plugin_name == "all-skills" {
          ($plugin_root | path join $agent)
        } else if $is_external {
          ($plugin_root | path join $agent)
        } else {
          ($plugin_root | path join $source_dir $agent)
        }

        if not ($agent_path | path exists) {
          $warnings = ($warnings | append $"Agent path not found: ($agent)")
        } else if ($agent_path | path expand | path type) != "file" {
          # claude-skills-244 Gate 3 — validate-agent-md calls `open
          # $agent_path --raw`, which crashes the WHOLE self-test (and a
          # real `claude plugin validate` run) with an uncaught
          # nu::shell::io::is_a_directory error when an agents array entry
          # resolves to a directory instead of a file. Reproduced with zero
          # mutation: {agents: ["agents"]} against an on-disk "agents/"
          # directory. Report a clean error instead of crashing — a crash
          # here would suppress every already-recorded failure and every
          # remaining self-test case, since failures are accumulated and
          # printed only at the end.
          # Guards on `!= "file"` rather than `== "dir"` on purpose: `path
          # type` returns EMPTY (neither "dir" nor "file", no error) for a
          # path that `path exists` claimed was there but isn't actually a
          # file — the shape a broken/mutated existence check produces, not
          # just a genuine directory. `!= "file"` catches both without a
          # second crash-prone branch.
          # `path expand` BEFORE `path type` on purpose (Gate 3 round 3):
          # bare `path type` reports "symlink" for a symlink regardless of
          # what it points at, so a symlinked agent file that `open` reads
          # perfectly well would be false-positive rejected without the
          # expand — verified against all 6 relevant states before applying
          # this. A broken/dangling symlink never reaches this branch —
          # `path exists` above is already `false` for it, caught as "not
          # found", not "wrong type"; don't "fix" that as a gap.
          let agent_path_type = ($agent_path | path expand | path type)
          let type_desc = if $agent_path_type == "dir" { "a directory" } else { $"an unexpected path type \(($agent_path_type)\)" }
          $errors = ($errors | append $"Agent path is ($type_desc), not a file: ($agent)")
        } else {
          # Validate agent file content
          let validation = (validate-agent-md $agent_path $agent $verbose)
          $errors = ($errors | append $validation.errors)
          $warnings = ($warnings | append $validation.warnings)
        }
      }
    }
  }

  # Validate keywords
  if ($plugin | get -o keywords) != null {
    let keywords_type = ($plugin.keywords | describe)
    if not ($keywords_type | str starts-with "list") {
      $errors = ($errors | append "'keywords' must be an array")
    } else if $verbose {
      print $"\n(ansi cyan)Keywords:(ansi reset) (($plugin.keywords | length)) entries"
    }
  }

  # Keywords agreement with the marketplace entry — same authority rule, same
  # marketplace-context gate, and same deletion-is-a-failure rule as
  # description, above (claude-skills-170): gated on plugin.json defining
  # keywords, not on the marketplace side, so a bare deletion of the
  # marketplace field can no longer pass silently.
  # Compared as SORTED LISTS, not as sets: `sort` doesn't dedupe, so a
  # repeated keyword still has to be repeated on both sides to match — this
  # is stricter than a true set comparison, in the safe direction. The
  # intent is the same either way: the two arrays are meant to carry the
  # same discovery keywords, and reordering them (e.g. an alphabetize pass)
  # changes no meaning, so an order-only difference is not a genuine
  # mismatch — it previously produced a "mismatch" error message that was
  # misleading about what actually differed (claude-skills-170).
  if $has_marketplace_context {
    let pj_keywords = ($plugin | get -o keywords)
    if ($pj_keywords | is-not-empty) {
      if ($mkt_keywords | is-empty) {
        $errors = ($errors | append $"marketplace.json entry is missing 'keywords' that plugin.json defines: ($pj_keywords)")
      } else if ($pj_keywords | sort) != ($mkt_keywords | sort) {
        $errors = ($errors | append $"keywords mismatch — plugin.json is authoritative: plugin.json=($pj_keywords) marketplace.json=($mkt_keywords)")
      }
    }
  }

  # Print results
  print $"\n(ansi cyan_bold)Validation Results:(ansi reset)"
  print $"  Errors: (($errors | length))"
  print $"  Warnings: (($warnings | length))"

  if ($errors | length) > 0 {
    print $"\n(ansi red_bold)Errors:(ansi reset)"
    for error in $errors {
      print $"  ✗ ($error)"
    }
  }

  if ($warnings | length) > 0 {
    print $"\n(ansi yellow_bold)Warnings:(ansi reset)"
    for warning in $warnings {
      print $"  ⚠ ($warning)"
    }
  }

  if ($errors | length) > 0 {
    print $"\n(ansi red_bold)✗ Validation failed with (($errors | length)) errors(ansi reset)"
    { success: false, errors: $errors, warnings: $warnings }
  } else if ($warnings | length) > 0 and $strict {
    # claude-skills-234: mirror upstream's --strict — warnings become blocking.
    # They stay in `warnings`, not `errors`, so the printed list above keeps
    # calling them warnings; only the pass/fail verdict changes.
    print $"\n(ansi red_bold)✗ Validation failed \(--strict\): (($warnings | length)) warnings treated as errors(ansi reset)"
    { success: false, errors: $errors, warnings: $warnings }
  } else if ($warnings | length) > 0 {
    print $"\n(ansi yellow_bold)⚠ Validation passed with (($warnings | length)) warnings(ansi reset)"
    { success: true, errors: $errors, warnings: $warnings }
  } else {
    { success: true, errors: $errors, warnings: $warnings }
  }
}

# Validate SKILL.md content (frontmatter)
def validate-skill-md [skill_md_path: string, skill_name: string, verbose: bool] {
  # Read file content (file existence already checked by caller)
  let content = (open $skill_md_path --raw)

  # Parse YAML frontmatter (between first two ---)
  let lines = ($content | lines)
  if ($lines | length) < 3 or ($lines | first) != "---" {
    return { errors: [$"SKILL.md missing YAML frontmatter: ($skill_name)"], warnings: [] }
  }

  # Find closing ---
  let end_idx = ($lines | skip 1 | enumerate | where item == "---" | first | get -o index)
  if $end_idx == null {
    return { errors: [$"SKILL.md missing closing --- in frontmatter: ($skill_name)"], warnings: [] }
  }

  # Extract frontmatter YAML
  let yaml_lines = ($lines | skip 1 | take $end_idx | str join "\n")
  # claude-skills-247 — the fourth instance of this file's unguarded-parse
  # defect class, found by sweeping for the CLASS (any operation assuming
  # well-formed content) rather than the function name ('open') the
  # earlier sweep used. Two distinct unsafe shapes, both reproduced with
  # zero mutation on a real on-disk SKILL.md before this fix:
  #   1. Genuinely malformed YAML (e.g. `name: [unclosed`) raises a
  #      catchable error from `from yaml` — was completely unguarded.
  #   2. Valid-but-scalar YAML (e.g. frontmatter body is just `hello`, no
  #      key: value structure) does NOT raise — `from yaml` returns a bare
  #      string — so `$frontmatter | get -o name` below crashed instead.
  #      This is claude-skills-243's exact lenient-parse defect, in YAML:
  #      a try/catch alone is insufficient, the result also needs a
  #      record-type check.
  let frontmatter = try {
    $yaml_lines | from yaml
  } catch {
    return { errors: [$"SKILL.md has malformed YAML frontmatter: ($skill_name)"], warnings: [] }
  }
  if not ($frontmatter | describe | str starts-with "record") {
    return { errors: [$"SKILL.md has malformed YAML frontmatter: ($skill_name)"], warnings: [] }
  }

  mut errors = []
  mut warnings = []

  # Validate name field
  let name = ($frontmatter | get -o name)
  if $name == null {
    $errors = ($errors | append $"SKILL.md missing 'name' field: ($skill_name)")
  } else {
    let name_len = ($name | str length)
    if $name_len > 64 {
      $errors = ($errors | append $"SKILL.md 'name' exceeds 64 characters: ($skill_name) - ($name_len) chars")
    }
    if not (is-kebab-case $name) {
      $errors = ($errors | append $"SKILL.md 'name' must be kebab-case: ($skill_name)")
    }
  }

  # Validate description field
  let description = ($frontmatter | get -o description)
  if $description == null {
    $errors = ($errors | append $"SKILL.md missing 'description' field: ($skill_name)")
  } else {
    let desc_len = ($description | str length)

    # Check length (max 1024 chars per Anthropic spec)
    if $desc_len > 1024 {
      $errors = ($errors | append $"SKILL.md 'description' exceeds 1024 characters: ($skill_name) - ($desc_len) chars")
    }

    # Check for "Use when" or "Activate when" pattern
    let has_trigger = ($description | str contains "Use when") or ($description | str contains "Activate when")
    if not $has_trigger {
      $warnings = ($warnings | append $"SKILL.md 'description' missing 'Use when' trigger: ($skill_name)")
    }

    if $verbose {
      print $"  ✓ ($skill_name) - ($desc_len) chars"
    }
  }

  # Reject 'allowed-tools' — skills keep frontmatter minimal (name, description, optional license).
  # Tool filtering applies to agents (via the agent's `tools:` frontmatter field), not skills.
  if ($frontmatter | get -o allowed-tools) != null {
    $errors = ($errors | append $"SKILL.md must not set 'allowed-tools': ($skill_name) — skills use name/description/license only. Declare tool allowlists on the invoking agent's `tools:` field instead.")
  }

  { errors: $errors, warnings: $warnings }
}

# Validate agent .md file content (frontmatter)
def validate-agent-md [agent_path: string, agent_name: string, verbose: bool] {
  # Read file content
  let content = (open $agent_path --raw)

  # Parse YAML frontmatter (between first two ---)
  let lines = ($content | lines)
  if ($lines | length) < 3 or ($lines | first) != "---" {
    return { errors: [$"Agent missing YAML frontmatter: ($agent_name)"], warnings: [] }
  }

  # Find closing ---
  let end_idx = ($lines | skip 1 | enumerate | where item == "---" | first | get -o index)
  if $end_idx == null {
    return { errors: [$"Agent missing closing --- in frontmatter: ($agent_name)"], warnings: [] }
  }

  # Extract frontmatter YAML
  let yaml_lines = ($lines | skip 1 | take $end_idx | str join "\n")
  # claude-skills-247 — same unguarded-parse defect as validate-skill-md
  # above: genuinely malformed YAML raises (previously unguarded), and
  # valid-but-scalar YAML doesn't raise but isn't a record either
  # (claude-skills-243's lenient-parse defect, in YAML).
  let frontmatter = try {
    $yaml_lines | from yaml
  } catch {
    return { errors: [$"Agent has malformed YAML frontmatter: ($agent_name)"], warnings: [] }
  }
  if not ($frontmatter | describe | str starts-with "record") {
    return { errors: [$"Agent has malformed YAML frontmatter: ($agent_name)"], warnings: [] }
  }

  mut errors = []
  mut warnings = []

  # Validate name field
  let name = ($frontmatter | get -o name)
  if $name == null {
    $errors = ($errors | append $"Agent missing 'name' field: ($agent_name)")
  } else {
    if not (is-kebab-case $name) {
      $errors = ($errors | append $"Agent 'name' must be kebab-case: ($agent_name)")
    }
  }

  # Validate description field
  let description = ($frontmatter | get -o description)
  if $description == null {
    $errors = ($errors | append $"Agent missing 'description' field: ($agent_name)")
  }

  # Validate tools field format (must be string, not array)
  let tools = ($frontmatter | get -o tools)
  if $tools != null {
    let tools_type = ($tools | describe)
    if ($tools_type | str starts-with "list") {
      $errors = ($errors | append $"Agent 'tools' must be comma-separated string, not YAML array: ($agent_name)")
    } else if $tools_type != "string" {
      $errors = ($errors | append $"Agent 'tools' must be a string: ($agent_name)")
    }
  }

  # Validate model field if present. Per claude-agents SKILL.md's frontmatter
  # table (source: https://code.claude.com/docs/en/sub-agents), `model`
  # accepts the four short names, `inherit` (the default), or a full model ID
  # such as `claude-opus-4-8`. The short-name list alone (claude-skills-234
  # Gate 3 review) was already stale — it was missing `fable` and `inherit`,
  # both of which this repo's own agent files use — and under --strict a
  # stale allowlist turns a documented, correct value into a hard CI failure
  # with no recourse for the author. Full model IDs are open-ended, so this
  # accepts anything shaped like one (`claude-` followed by lowercase
  # alphanumeric segments) rather than trying to enumerate every release.
  let model = ($frontmatter | get -o model)
  if $model != null {
    let valid_short_models = ["haiku", "sonnet", "opus", "fable", "inherit"]
    let looks_like_full_model_id = ($model =~ '^claude-[a-z0-9]+(-[a-z0-9]+)*$')
    if not ($model in $valid_short_models) and not $looks_like_full_model_id {
      $warnings = ($warnings | append $"Agent 'model' should be one of: haiku, sonnet, opus, fable, inherit, or a full model ID like claude-opus-4-8 - got: ($model)")
    }
  }

  if $verbose and ($errors | length) == 0 {
    print $"  ✓ ($agent_name)"
  }

  { errors: $errors, warnings: $warnings }
}

# Check if string is kebab-case
def is-kebab-case [name: string] {
  $name =~ '^[a-z0-9]+(-[a-z0-9]+)*$'
}

# Check if string is semantic version
def is-semver [version: string] {
  $version =~ '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$'
}

# claude-skills-235: validate a plugin.json `dependencies[].version` string as
# a node-semver RANGE expression — a different, looser grammar than an exact
# version (is-semver above). Upstream (https://code.claude.com/docs/en/plugin-dependencies):
# "The version field accepts any expression supported by Node's semver
# package, including caret, tilde, hyphen, and comparator ranges", with
# documented examples ~2.1.0, ^2.0, >=1.4, =2.1.0, and the range-conflict
# error's mention of "||" chains. This is a restraint-scoped approximation of
# the full node-semver grammar (rung 7 — the minimum that works), not a
# reimplementation of node-semver itself: it accepts every documented example
# and operator plus every additional form node's own `semver.validRange`
# accepts, and rejects garbage. It DOES model leading-zero rejection in
# numeric identifiers (`01.2.3` is rejected, same as real node-semver) — that
# is not a gap.
#
# Verified against the actual `semver` npm package, not assumed from docs or
# memory: npm's own bundled copy on this machine is 7.8.1, but `npm view
# semver version` reports 7.8.5 as the current published release (7.8.1 is a
# stale bundle) — 7.8.5 is what's cited below as "node-semver" throughout,
# since that is the version a fresh `npm install semver` resolves today and
# the one upstream's own docs implicitly mean by "Node's semver package".
# 7.8.1 and 7.8.5 disagree on x-range wildcard placement (see below) — this
# was caught by testing both, not by assuming a single version is timeless.
#
# Deliberate, upstream-matching decisions worth calling out explicitly rather
# than leaving as silent behavior:
#   - An empty or whitespace-only constraint is ACCEPTED, equivalent to `*`
#     (any version) — this is what `semver.validRange("")` returns in node.
#   - A `||`-joined range with an empty branch (e.g. "1.2.3 || ") is ACCEPTED
#     — the empty branch is itself `*`, so a manifest that constrains nothing
#     on one side of an OR is not malformed.
#   - Whitespace between a comparator operator and its version (">= 1.2.3",
#     "= 2.1.0", "^ 1.2.3", "~ 1.2.3", "~> 1.2.3") is ACCEPTED, including tabs
#     as the AND-group separator (">=1.2.3\t<2.0.0") — node's tokenizer is
#     whitespace-insensitive here.
#   - A LOWERCASE `v` version prefix ("v1.2.3") is ACCEPTED — node strips it.
#     UPPERCASE `V` is REJECTED (`semver.validRange("V1.2.3")` returns null)
#     — node does not case-fold this prefix, so `is-version-partial` must not
#     either.
#   - `~>` (Ruby/Bundler-style "twiddle-wakka") is ACCEPTED as a tilde-range
#     alias — confirmed against node-semver's own range grammar, not assumed
#     from Ruby conventions.
#   - An x-range wildcard (`x`, `X`, `*`) is ONLY valid in TRAILING position —
#     `1.2.x` and `1.x` are ACCEPTED, but `x.1.2` and `1.x.3` are REJECTED
#     (`semver.validRange` returns null for both on 7.8.5, even though the
#     older bundled 7.8.1 accepted them). Once a component is a wildcard, or
#     the dotted core simply ends, no further component may be a concrete
#     number — enforced by is-x-range-core below, not by the regex alone.

# One dotted-core component: a concrete numeric identifier (no leading
# zeros, same as real semver) or an x-range wildcard (x, X, *).
def is-x-range-component [p: string] {
  ($p in ["x", "X", "*"]) or ($p =~ '^(0|[1-9][0-9]*)$')
}

# Enforces node-semver's trailing-only wildcard rule across a dotted core
# (1 to 3 components, split on '.'): once a wildcard component is seen,
# every remaining component to its right must not be a concrete number —
# there is none, because a wildcard-then-concrete core is rejected outright.
def is-x-range-core [parts: list<string>] {
  if (($parts | length) < 1) or (($parts | length) > 3) {
    false
  } else {
    mut wildcard_seen = false
    mut ok = true
    for p in $parts {
      if $wildcard_seen {
        $ok = false
      } else if ($p in ["x", "X", "*"]) {
        $wildcard_seen = true
      } else if not (is-x-range-component $p) {
        $ok = false
      }
    }
    $ok
  }
}

# One dotted version component: an optional LOWERCASE-ONLY `v` prefix, then
# an x-range core (1-3 dot-separated parts, wildcard trailing-only — see
# is-x-range-core), then an optional prerelease/build suffix. The suffix is
# split off before the core is dot-split, since '-'/'+' only ever appear
# after the numeric/wildcard core, never inside it.
def is-version-partial [v0: string] {
  let v = ($v0 | str trim)
  if ($v | is-empty) {
    false
  } else {
    let stripped = ($v | str replace --regex '^v' '')
    if ($stripped | is-empty) {
      false
    } else {
      let m = ($stripped | parse -r '^(?<core>[^-+]+)(?<rest>[-+].*)?$')
      if ($m | is-empty) {
        false
      } else {
        let rest = $m.0.rest
        let rest_ok = ($rest | is-empty) or ($rest =~ '^(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$')
        $rest_ok and (is-x-range-core ($m.0.core | split row '.'))
      }
    }
  }
}

# The comparator operators node-semver recognizes as a range-token prefix.
# Order matters for the regex alternation below: `~>` must be tried before
# `~`, and `>=`/`<=` before `>`/`<`, so the longer operator wins the match.
def is-bare-operator [t: string] {
  $t in ["^", "~>", "~", ">=", "<=", ">", "<", "="]
}

# One comparator token: an optional operator prefix followed directly by a
# version-partial (no space between them — is-semver-range-group merges an
# operator separated from its version by whitespace before tokens reach
# here). A bare version-partial (no operator) is also valid — e.g. the
# left/right sides of a hyphen range, or a bare pin written without `=`.
def is-comparator-token [tok: string] {
  let t = ($tok | str trim)
  if ($t | is-empty) {
    false
  } else {
    let m = ($t | parse -r '^(?<op>\^|~>|~|>=|<=|>|<|=)?(?<ver>.+)$')
    if ($m | is-empty) {
      false
    } else {
      is-version-partial $m.0.ver
    }
  }
}

# A hyphen range: "VERSION - VERSION" (single space required around the
# hyphen after whitespace normalization, per node-semver's documented
# hyphen-range syntax, e.g. "1.2.3 - 2.3.4").
def is-hyphen-range [group: string] {
  let parts = ($group | split row ' - ')
  if ($parts | length) != 2 {
    false
  } else {
    (is-version-partial $parts.0) and (is-version-partial $parts.1)
  }
}

# node-semver tokenizes ">= 1.2.3" the same as ">=1.2.3" — a bare operator
# token (nothing attached) absorbs the token that follows it. Applied AFTER
# whitespace-collapse + AND-group splitting, so this only has to handle the
# "operator by itself" case; an operator already glued to its version (the
# common case, e.g. ">=1.2.3") passes through untouched.
def merge-operator-tokens [tokens: list<string>] {
  mut result = []
  mut pending_op = null
  for t in $tokens {
    if $pending_op != null {
      $result = ($result | append $"($pending_op)($t)")
      $pending_op = null
    } else if (is-bare-operator $t) {
      $pending_op = $t
    } else {
      $result = ($result | append $t)
    }
  }
  if $pending_op != null {
    # trailing bare operator with nothing to attach to — kept as-is so
    # is-comparator-token rejects it (ver would be empty, matched by nothing)
    $result = ($result | append $pending_op)
  }
  $result
}

# One AND-group: either a hyphen range, or one-or-more whitespace-separated
# comparator tokens (e.g. ">=1.2.7 <1.3.0"). Whitespace (including tabs and
# repeated spaces) is collapsed to single spaces first, so a group is
# equivalent under any whitespace node-semver itself treats as equivalent.
# An empty group (blank string, or whitespace-only) is valid — see the
# empty-constraint-means-"*" decision documented above `is-version-partial`.
def is-semver-range-group [group: string] {
  let g = ($group | str replace --all --regex '\s+' ' ' | str trim)
  if ($g | is-empty) {
    true
  } else if ($g | str contains ' - ') {
    is-hyphen-range $g
  } else {
    let raw_tokens = ($g | split row ' ' | where {|t| ($t | str trim | is-not-empty) })
    let tokens = (merge-operator-tokens $raw_tokens)
    ($tokens | all {|t| is-comparator-token $t })
  }
}

# Full range: one or more AND-groups joined by "||" (OR), per node-semver. An
# entirely empty/whitespace constraint delegates to is-semver-range-group's
# own empty-group handling (equivalent to `*`) rather than special-casing it
# here — `split row '||'` on an empty string yields a single empty group.
def is-semver-range [constraint: string] {
  let groups = ($constraint | split row '||')
  ($groups | all {|g| is-semver-range-group $g })
}

# Fixture-based self-test suite for claude-skills-218 / claude-skills-219.
# Builds a temp plugin.json per case and calls validate-plugin-content
# directly (no --marketplace context) so the assertions run against the
# same logic the real CLI path uses. Each case names what would have
# regressed silently before this fix: dependencies wrongly rejected,
# unknown fields silently accepted, marketplace-only fields no longer
# caught, the 5 newly-documented fields not recognized.
def self-test [] {
  mut failures = []

  let cases = [
    {
      name: "dependencies_array_of_bare_names_accepted"
      why: "claude-skills-218 — upstream documents plain plugin-name strings as a valid dependencies entry"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: ["helper-lib"] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_array_of_version_objects_accepted"
      why: "claude-skills-218 — upstream's own example: [{ name: secrets-vault, version: ~2.1.0 }]"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "secrets-vault", version: "~2.1.0" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_entry_missing_name_errors"
      why: "a dependency object without 'name' is malformed regardless of the upstream shape fix"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ version: "~2.1.0" }] }
      expect_errors: 1
      expect_warnings: 0
    }
    {
      name: "dependencies_not_an_array_errors"
      why: "a lone string instead of an array is a type error, not a shape variant"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: "helper-lib" }
      expect_errors: 1
      expect_warnings: 0
    }
    {
      name: "marketplace_only_fields_still_rejected"
      why: "category/strict/source/tags stay marketplace-entry-only per upstream's plugin-entries schema — the fix must not weaken this"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", category: "productivity", strict: true, source: "./plugins/my-plugin", tags: ["a"] }
      expect_errors: 4
      expect_warnings: 0
    }
    {
      name: "unknown_field_warns_not_errors"
      why: "claude-skills-219 — an invented field must not pass silently, but must WARN not hard-fail (matches upstream's own claude plugin validate behavior)"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", notARealField: "garbage" }
      expect_errors: 0
      expect_warnings: 1
    }
    {
      name: "complete_manifest_all_documented_fields_recognized"
      why: "claude-skills-218 — every field this skill documents as valid (the pre-existing outputStyles/lspServers/experimental trio from PR 205, plus dependencies and the 5 newly-documented fields) must coexist in one manifest with zero errors and zero warnings. This is the fixture the SKILL.md 'Verified against...' sentence cites — keep the two in sync"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", outputStyles: "./styles/", lspServers: "./.lsp.json", experimental: { themes: "./themes/", monitors: "./monitors.json" }, dependencies: ["helper-lib"], displayName: "My Plugin", defaultEnabled: false, workflows: "./workflows/", userConfig: {}, channels: [] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "missing_required_name_still_errors"
      why: "the allowlist/warn changes must not weaken the pre-existing required-field check"
      plugin: {}
      expect_errors: 1
      expect_warnings: 1  # "Missing recommended field: version" etc. are warnings; name is the only error case here besides those — see assertion below which checks error substring instead of exact count
    }
    {
      name: "strict_mode_unknown_field_fails"
      why: "claude-skills-234 — upstream's --strict treats warnings as errors; an unknown field must flip success to false under --strict even though the warning count itself is unchanged"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", notARealField: "garbage" }
      strict: true
      expect_errors: 0
      expect_warnings: 1
      expect_success: false
    }
    {
      name: "default_mode_unknown_field_still_passes"
      why: "claude-skills-234 — default (non-strict) mode must be unaffected: a manifest with only warnings still exits success"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", notARealField: "garbage" }
      expect_errors: 0
      expect_warnings: 1
      expect_success: true
    }
    {
      name: "strict_mode_clean_manifest_passes"
      why: "claude-skills-234 — --strict must not fail a manifest with zero warnings; it only promotes existing warnings, it never invents new ones"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT" }
      strict: true
      expect_errors: 0
      expect_warnings: 0
      expect_success: true
    }
    {
      name: "dependencies_version_caret_partial_accepted"
      why: "claude-skills-235 — upstream's own table row documents ^2.0 as a valid caret partial-version range"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "^2.0" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_gte_partial_accepted"
      why: "claude-skills-235 — upstream's own table row documents >=1.4 as a valid comparator range"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: ">=1.4" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_exact_accepted"
      why: "claude-skills-235 — upstream's own table row documents =2.1.0 as a valid exact-pin range"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "=2.1.0" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_hyphen_range_accepted"
      why: "claude-skills-235 — node-semver hyphen ranges (upstream: 'the version field accepts any expression supported by Node's semver package, including caret, tilde, hyphen, and comparator ranges')"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "1.2.3 - 2.3.4" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_or_range_accepted"
      why: "claude-skills-235 — node-semver OR-chains ('||'), referenced by upstream's range-conflict error guidance ('simplify long || chains')"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "1.2.7 || >=1.2.9 <2.0.0" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_malformed_rejected"
      why: "claude-skills-235 — {name: x, version: not-a-semver!!!} must be rejected; this is the exact case verified accepted-with-zero-errors before the fix"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "x", version: "not-a-semver!!!" }] }
      expect_errors: 1
      expect_warnings: 0
    }
    {
      name: "dependencies_version_space_after_operator_accepted"
      why: "claude-skills-234 Gate 3 review — node's semver.validRange(\">= 1.2.3\") accepts whitespace between a comparator operator and its version; the pre-review grammar falsely rejected this"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: ">= 1.2.3" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_v_prefix_accepted"
      why: "claude-skills-234 Gate 3 review — node accepts a LOWERCASE v version prefix (v1.2.3); the pre-review grammar falsely rejected it"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "v1.2.3" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_empty_string_accepted"
      why: "claude-skills-234 Gate 3 review — node's semver.validRange(\"\") returns '*' (any version); an empty constraint is a documented accept, not an accidental one"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_tilde_wakka_accepted"
      why: "claude-skills-234 Gate 3 review — node accepts ~> (Ruby/Bundler-style twiddle-wakka) as a tilde-range alias; the pre-review grammar falsely rejected it"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "~>1.2.3" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_tab_separated_and_accepted"
      why: "claude-skills-234 Gate 3 review — node's tokenizer is whitespace-insensitive between AND-group comparators, including tabs (>=1.2.3<TAB><2.0.0); the pre-review grammar only collapsed literal single spaces"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: ">=1.2.3\t<2.0.0" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_bare_operator_rejected"
      why: "claude-skills-234 Gate 3 review — a comparator operator with nothing attached (>= alone) has no version to constrain and must be rejected, not silently merged into an adjacent unrelated token"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: ">=" }] }
      expect_errors: 1
      expect_warnings: 0
    }
    {
      name: "dependencies_version_incomplete_hyphen_rejected"
      why: "claude-skills-234 Gate 3 review — a hyphen range missing its right-hand side (1.2.3 -) is malformed, not a valid range with an implicit *"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "1.2.3 -" }] }
      expect_errors: 1
      expect_warnings: 0
    }
    {
      name: "dependencies_version_embedded_newline_rejected"
      why: "claude-skills-234 Gate 3 review — accepting any whitespace as an AND-group separator (including newlines) must not let an embedded newline smuggle garbage past validation"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "1.2.3\ngarbage" }] }
      expect_errors: 1
      expect_warnings: 0
    }
    {
      name: "dependencies_version_uppercase_v_prefix_rejected"
      why: "claude-skills-234 Gate 3 nit — semver.validRange(\"V1.2.3\") returns null on real node-semver 7.8.5; node does not case-fold the v prefix, so accepting uppercase V (as an earlier grammar iteration did) was a false accept"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "V1.2.3" }] }
      expect_errors: 1
      expect_warnings: 0
    }
    {
      name: "dependencies_version_trailing_wildcard_accepted"
      why: "claude-skills-234 Gate 3 nit — a trailing x-range wildcard (1.2.x) is the documented, common case and must stay accepted after the trailing-only-wildcard fix"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "1.2.x" }] }
      expect_errors: 0
      expect_warnings: 0
    }
    {
      name: "dependencies_version_leading_wildcard_rejected"
      why: "claude-skills-234 Gate 3 nit — semver.validRange(\"x.1.2\") returns null on real node-semver 7.8.5 (wildcard only valid in trailing position); an earlier grammar iteration accepted a wildcard in any position, a false accept"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "x.1.2" }] }
      expect_errors: 1
      expect_warnings: 0
    }
    {
      name: "dependencies_version_mid_wildcard_rejected"
      why: "claude-skills-234 Gate 3 nit — semver.validRange(\"1.x.3\") returns null on real node-semver 7.8.5; a wildcard followed by a concrete number is malformed, not just a leading-wildcard special case"
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", dependencies: [{ name: "db-migrate", version: "1.x.3" }] }
      expect_errors: 1
      expect_warnings: 0
    }
    {
      name: "top_level_version_malformed_warns"
      why: "claude-skills-238 — is-semver (the plugin.json top-level 'version' field, distinct from the dependency RANGE check above) had zero fixture coverage; mutating it to always-true passed the pre-fix 34-case suite unchanged"
      plugin: { name: "my-plugin", version: "not-a-version", description: "test fixture", license: "MIT" }
      expect_errors: 0
      expect_warnings: 1
    }
    {
      name: "top_level_version_v_prefixed_warns"
      why: "claude-skills-238 — is-semver is the EXACT-version grammar, not the dependency range grammar; a v-prefixed string like 'v1.0.0' is valid as a RANGE but not as this exact top-level field, so it must still warn here — this is also the SKILL.md-documented example ('version': 'v1.0.0' // warned)"
      plugin: { name: "my-plugin", version: "v1.0.0", description: "test fixture", license: "MIT" }
      expect_errors: 0
      expect_warnings: 1
    }
    {
      name: "top_level_version_two_segment_warns"
      why: "claude-skills-238 Gate 3 (team-lead's independent review) — a stub is-semver reading '^[0-9]' (starts-with-digit) survived the pre-fix 66-case suite unchanged, because both existing reject fixtures ('not-a-version', 'v1.0.0') start with a non-digit and every accept fixture is a full 'X.Y.Z'. A two-segment version like '1.0' starts with a digit (so the stub wrongly accepts it) but is missing the required patch component (so the real check must still warn) — this is the one dimension ('has three dot-separated numeric segments', not merely 'starts with a digit') the prior fixtures never isolated"
      plugin: { name: "my-plugin", version: "1.0", description: "test fixture", license: "MIT" }
      expect_errors: 0
      expect_warnings: 1
    }
    {
      name: "plugin_name_bad_kebab_case_errors"
      why: "claude-skills-238 — is-kebab-case (the plugin.json top-level 'name' field) had zero fixture coverage of the reject direction; every existing case uses a valid kebab-case name. Also exercises the is-kebab-case helper now that it's wired into this call site instead of a duplicated inline regex"
      plugin: { name: "My_Plugin", version: "1.0.0", description: "test fixture", license: "MIT" }
      expect_errors: 2  # invalid name format, AND name mismatch (fixture always passes plugin_name="my-plugin" as expected — see the loop below)
      expect_warnings: 0
    }
    {
      name: "plugin_name_snake_case_errors"
      why: "claude-skills-238 Gate 3 (team-lead's independent review) — a stub is-kebab-case reading '^[a-z0-9_]+(-[a-z0-9_]+)*\$' (accepting underscores) survived the pre-fix 66-case suite unchanged, because the only reject fixture, 'My_Plugin', carries BOTH an uppercase letter AND an underscore — the uppercase alone is enough to fail it under the stub too, so the fixture never isolated which rule actually rejected it. 'my_plugin' is lowercase (so the stub's uppercase-tolerant claim is moot) and differs from valid kebab-case in exactly the underscore dimension"
      plugin: { name: "my_plugin", version: "1.0.0", description: "test fixture", license: "MIT" }
      expect_errors: 2  # invalid name format, AND name mismatch (same shape as plugin_name_bad_kebab_case_errors above — fixture always passes plugin_name="my-plugin" as expected)
      expect_warnings: 0
    }
  ]

  let temp_dir = (mktemp -d)

  for c in $cases {
    let plugin_path = ($temp_dir | path join $"($c.name).json")
    $c.plugin | save --force $plugin_path

    let strict = ($c | get -o strict | default false)
    let result = (validate-plugin-content $plugin_path $temp_dir "my-plugin" "my-plugin" false false $strict)

    if $c.name == "missing_required_name_still_errors" {
      if not ($result.errors | any {|e| $e | str contains "Missing required field: 'name'" }) {
        $failures = ($failures | append $"($c.name): expected a missing-name error, got errors=($result.errors | to nuon)")
      }
    } else {
      if ($result.errors | length) != $c.expect_errors {
        $failures = ($failures | append $"($c.name): expected ($c.expect_errors) errors, got (($result.errors | length)): ($result.errors | to nuon) -- ($c.why)")
      }
      if ($result.warnings | length) != $c.expect_warnings {
        $failures = ($failures | append $"($c.name): expected ($c.expect_warnings) warnings, got (($result.warnings | length)): ($result.warnings | to nuon) -- ($c.why)")
      }
      let expect_success = ($c | get -o expect_success)
      if ($expect_success != null) and ($result.success != $expect_success) {
        $failures = ($failures | append $"($c.name): expected success=($expect_success), got ($result.success) -- ($c.why)")
      }
    }
  }

  # Fixture-based coverage for validate-agent-md's `model` field
  # (claude-skills-234 Gate 3 review): the plugin.json fixtures above never
  # exercise validate-agent-md at all, so the pre-review narrow allowlist
  # (["haiku","sonnet","opus"]) had zero test coverage — a mutation that
  # reverted the widened list back to the narrow one passed the self-test
  # suite unchanged. These cases close that gap directly.
  let agent_model_cases = [
    { model: "opus", expect_warnings: 0, why: "pre-existing short name — must still pass after widening" }
    { model: "fable", expect_warnings: 0, why: "documented in claude-agents SKILL.md but was missing from the pre-review allowlist" }
    { model: "inherit", expect_warnings: 0, why: "documented default value; was missing from the pre-review allowlist" }
    { model: "claude-opus-4-8", expect_warnings: 0, why: "documented full-model-ID example from claude-agents SKILL.md" }
    { model: "gpt-4", expect_warnings: 1, why: "not a documented value in any form — must still warn" }
  ]
  let agent_temp_dir = (mktemp -d)
  for c in $agent_model_cases {
    let agent_path = ($agent_temp_dir | path join $"model-($c.model | str replace -a '.' '-').md")
    $"---\nname: fixture-agent\ndescription: test fixture\nmodel: ($c.model)\n---\n\nbody\n" | save --force $agent_path
    let result = (validate-agent-md $agent_path "fixture-agent" false)
    if ($result.errors | length) != 0 {
      $failures = ($failures | append $"agent_model_($c.model): expected 0 errors, got (($result.errors | length)): ($result.errors | to nuon) -- ($c.why)")
    }
    if ($result.warnings | length) != $c.expect_warnings {
      $failures = ($failures | append $"agent_model_($c.model): expected ($c.expect_warnings) warnings, got (($result.warnings | length)): ($result.warnings | to nuon) -- ($c.why)")
    }
  }
  rm -rf $agent_temp_dir

  # claude-skills-238: validate-skill-md had ZERO fixture coverage before this
  # — no case in $cases above carries a `skills` entry, so a mutation
  # replacing the whole function body with an unconditional error (or with
  # `{ errors: [], warnings: [] }`, the always-pass direction the bee is
  # actually about) passed the pre-fix 34-case suite unchanged. Called
  # directly against real temp SKILL.md files, the same pattern as
  # agent_model_cases above, rather than threaded through a full plugin.json
  # + skills-array + on-disk-directory round trip — that indirection buys
  # nothing extra here since validate-skill-md takes a file path directly.
  let skill_md_cases = [
    {
      name: "valid"
      content: "---\nname: my-skill\ndescription: Use when testing skill validation.\n---\n\nbody\n"
      expect_errors: 0
      expect_warnings: 0
      why: "baseline: a correct SKILL.md must pass cleanly — this is also the regression guard for the reject-direction cases below"
    }
    {
      name: "missing_frontmatter"
      content: "no frontmatter here\njust plain text\n"
      expect_errors: 1
      expect_warnings: 0
      why: "no opening '---' — must be rejected, not silently treated as a bodiless skill"
    }
    {
      name: "missing_closing_delimiter"
      content: "---\nname: my-skill\ndescription: Use when testing.\n"
      expect_errors: 1
      expect_warnings: 0
      why: "opens '---' but never closes it — the frontmatter parser must not run off the end of the file"
    }
    {
      name: "missing_name_field"
      content: "---\ndescription: Use when testing.\n---\n\nbody\n"
      expect_errors: 1
      expect_warnings: 0
      why: "SKILL.md missing 'name' field must error"
    }
    {
      name: "name_bad_kebab_case"
      content: "---\nname: My_Skill\ndescription: Use when testing.\n---\n\nbody\n"
      expect_errors: 1
      expect_warnings: 0
      why: "SKILL.md 'name' must be kebab-case — also exercises is-kebab-case's reject direction from this call site"
    }
    {
      name: "name_too_long"
      content: $"---\nname: (('a' | fill -c 'a' -w 65))\ndescription: Use when testing.\n---\n\nbody\n"
      expect_errors: 1
      expect_warnings: 0
      why: "SKILL.md 'name' exceeds 64 characters — a single 65-char run of 'a' is still valid kebab-case, so only the length check fires, isolating this specific error"
    }
    {
      name: "missing_description_field"
      content: "---\nname: my-skill\n---\n\nbody\n"
      expect_errors: 1
      expect_warnings: 0
      why: "SKILL.md missing 'description' field must error"
    }
    {
      name: "description_missing_trigger_phrase"
      content: "---\nname: my-skill\ndescription: does something without the required trigger phrase.\n---\n\nbody\n"
      expect_errors: 0
      expect_warnings: 1
      why: "missing 'Use when'/'Activate when' is a warning, not an error"
    }
    {
      name: "allowed_tools_present"
      content: "---\nname: my-skill\ndescription: Use when testing.\nallowed-tools: Bash, Read\n---\n\nbody\n"
      expect_errors: 1
      expect_warnings: 0
      why: "skills must not set allowed-tools — tool allowlists belong on the invoking agent, not the skill"
    }
    # claude-skills-247 — the malformed/scalar-YAML-frontmatter reject
    # cases are deliberately NOT here. validate-skill-md is called
    # DIRECTLY (same process as this self-test run), so a mutation that
    # reintroduces either pre-fix crash shape crashes the WHOLE self-test
    # script here rather than failing one case cleanly — confirmed
    # directly while developing this fixture, and it happens BEFORE
    # cli_cases (which has real subprocess isolation) ever runs, since
    # skill_md_cases executes first. Covered instead by
    # cli_scalar_yaml_skill_exit_1 and cli_malformed_yaml_skill_exit_1
    # below, reached through the full CLI + skills-array path, where a
    # reverted guard fails by clean stdout-assertion mismatch in the
    # PARENT self-test process instead of crashing it.
  ]
  let skill_md_temp_dir = (mktemp -d)
  for c in $skill_md_cases {
    let skill_md_path = ($skill_md_temp_dir | path join $"($c.name).md")
    $c.content | save --force $skill_md_path
    let result = (validate-skill-md $skill_md_path "fixture-skill" false)
    if ($result.errors | length) != $c.expect_errors {
      $failures = ($failures | append $"skill_md_($c.name): expected ($c.expect_errors) errors, got (($result.errors | length)): ($result.errors | to nuon) -- ($c.why)")
    }
    if ($result.warnings | length) != $c.expect_warnings {
      $failures = ($failures | append $"skill_md_($c.name): expected ($c.expect_warnings) warnings, got (($result.warnings | length)): ($result.warnings | to nuon) -- ($c.why)")
    }
    let expect_error_contains = ($c | get -o expect_error_contains)
    if ($expect_error_contains != null) and not ($result.errors | any {|e| $e | str contains $expect_error_contains }) {
      $failures = ($failures | append $"skill_md_($c.name): expected an error containing '($expect_error_contains)', got: ($result.errors | to nuon) -- ($c.why)")
    }
  }
  rm -rf $skill_md_temp_dir

  # claude-skills-238: validate-agent-md's NON-MODEL checks had zero
  # reject-direction fixture coverage — the agent_model_cases block above
  # only varies `model`, on manifests that are otherwise always valid.
  let agent_md_cases = [
    {
      name: "valid"
      content: "---\nname: my-agent\ndescription: test fixture\ntools: Bash, Read\nmodel: opus\n---\n\nbody\n"
      expect_errors: 0
      why: "baseline: a correct agent frontmatter must pass cleanly"
    }
    {
      name: "missing_frontmatter"
      content: "no frontmatter here\n"
      expect_errors: 1
      why: "no opening '---' — must be rejected"
    }
    {
      name: "missing_closing_delimiter"
      content: "---\nname: my-agent\ndescription: test fixture\n"
      expect_errors: 1
      why: "opens '---' but never closes it"
    }
    {
      name: "missing_name_field"
      content: "---\ndescription: test fixture\n---\n\nbody\n"
      expect_errors: 1
      why: "Agent missing 'name' field must error"
    }
    {
      name: "name_bad_kebab_case"
      content: "---\nname: My_Agent\ndescription: test fixture\n---\n\nbody\n"
      expect_errors: 1
      why: "Agent 'name' must be kebab-case — also exercises is-kebab-case's reject direction from this call site"
    }
    {
      name: "missing_description_field"
      content: "---\nname: my-agent\n---\n\nbody\n"
      expect_errors: 1
      why: "Agent missing 'description' field must error"
    }
    {
      name: "tools_as_yaml_list"
      content: "---\nname: my-agent\ndescription: test fixture\ntools:\n  - Bash\n  - Read\n---\n\nbody\n"
      expect_errors: 1
      expect_error_contains: "comma-separated string, not YAML array"
      why: "tools must be a comma-separated string, not a YAML array — the bee's own 'tools given as a YAML list' example. Message-specificity is pinned (not just the count) because the list branch and the wrong-type branch below both error, so an error-count-only assertion can't tell them apart — a claude-skills-238 Gate 3 finding on this exact PR (team-lead's independent review): neutering the list branch to `if false` left this case's count-only assertion green since the else-if wrong-type fallback still fired"
    }
    {
      name: "tools_wrong_type"
      content: "---\nname: my-agent\ndescription: test fixture\ntools: 42\n---\n\nbody\n"
      expect_errors: 1
      why: "tools must be a string; a bare number is neither the list-shape nor the string-shape branch"
    }
    # claude-skills-247 — same reasoning as skill_md_cases above: the
    # malformed/scalar-YAML reject cases are covered by
    # cli_malformed_yaml_agent_exit_1 and cli_scalar_yaml_agent_exit_1
    # instead, not here, since a direct call to validate-agent-md would
    # crash this WHOLE self-test script under a reverted guard rather than
    # failing one case cleanly.
  ]
  let agent_md_temp_dir = (mktemp -d)
  for c in $agent_md_cases {
    let agent_md_path = ($agent_md_temp_dir | path join $"($c.name).md")
    $c.content | save --force $agent_md_path
    let result = (validate-agent-md $agent_md_path "fixture-agent" false)
    if ($result.errors | length) != $c.expect_errors {
      $failures = ($failures | append $"agent_md_($c.name): expected ($c.expect_errors) errors, got (($result.errors | length)): ($result.errors | to nuon) -- ($c.why)")
    }
    let expect_error_contains = ($c | get -o expect_error_contains)
    if ($expect_error_contains != null) and not ($result.errors | any {|e| $e | str contains $expect_error_contains }) {
      $failures = ($failures | append $"agent_md_($c.name): expected an error containing '($expect_error_contains)', got: ($result.errors | to nuon) -- ($c.why)")
    }
  }
  rm -rf $agent_md_temp_dir

  # claude-skills-238: cleanup-temp is a pure filesystem helper with zero
  # fixture coverage — a mutation that always removes (or never removes)
  # would pass every existing case silently, since none of them call it
  # with an assertion on the resulting directory state.
  let cleanup_temp_cases = [
    { is_ext: true, expect_removed: true, why: "external plugin's temp clone dir must be removed after use" }
    { is_ext: false, expect_removed: false, why: "a non-external validation never allocated a temp dir — cleanup must be a no-op, not delete an unrelated path" }
  ]
  for c in $cleanup_temp_cases {
    let probe_dir = (mktemp -d)
    cleanup-temp $probe_dir $c.is_ext
    let still_exists = ($probe_dir | path exists)
    let was_removed = not $still_exists
    if $was_removed != $c.expect_removed {
      $failures = ($failures | append $"cleanup_temp_is_ext_($c.is_ext): expected removed=($c.expect_removed), got removed=($was_removed) -- ($c.why)")
    }
    if not $was_removed {
      rm -rf $probe_dir
    }
  }

  # claude-skills-244: the skills/commands/agents array-type checks and the
  # path-existence / recommended-file checks below them had ZERO
  # reject-direction fixture coverage — a Gate 3 mutation sweep on PR #221
  # found all 11 of them always-pass-neuterable. Two on-disk roots isolate
  # the path-existence pair per team-lead's independent-review guidance: a
  # fixture whose path is both MISSING and MALFORMED proves nothing about
  # which rule fired. root_b's "present-without-md" directory genuinely
  # EXISTS (so "Skill path not found" can't be what's firing) but lacks
  # SKILL.md (so the missing-SKILL.md check is what's isolated); the
  # "does-not-exist" skill entry genuinely does NOT exist (so the opposite
  # check is isolated). Both roots also carry (or omit) skills/sources.md
  # deliberately, so the sources.md-missing warning doesn't leak into cases
  # that aren't testing it.
  let array_path_temp_dir = (mktemp -d)

  # root_a: no skills/sources.md, one skill dir that's fully valid (exists,
  # has a well-formed SKILL.md) — used only to isolate the sources.md warning.
  let root_a = ($array_path_temp_dir | path join "root-a")
  mkdir ($root_a | path join "my-plugin" "skills" "present-with-md")
  "---\nname: present-with-md\ndescription: Use when testing.\n---\n\nbody\n" | save --force ($root_a | path join "my-plugin" "skills" "present-with-md" "SKILL.md")

  # root_b: skills/sources.md present (suppresses that warning here), one
  # skill dir that exists but has no SKILL.md — used to isolate the
  # missing-SKILL.md error and the skill-path-not-found warning (the latter
  # via a skill entry that deliberately doesn't exist under this root).
  # Also doubles as the root for the command/agent path-not-found cases
  # (that check doesn't reference sources.md at all, so reuse is harmless)
  # and for the array-type and missing-recommended-field cases (none of
  # which reach path-resolution code, so the on-disk layout is inert noise
  # for them).
  let root_b = ($array_path_temp_dir | path join "root-b")
  mkdir ($root_b | path join "my-plugin" "skills" "present-without-md")
  "# Sources\n" | save --force ($root_b | path join "my-plugin" "skills" "sources.md")
  # commands/ and agents/ PARENT dirs exist but the specific referenced file
  # inside each does not — a non-equivalent mutation that checks
  # `$command_path | path dirname | path exists` instead of `$command_path |
  # path exists` (same bug shape for agents) coincidentally produced the
  # same not-found result when the parent dir ALSO didn't exist, so this
  # split is required to distinguish "the file is missing" from "the whole
  # directory is missing" — found and killed during claude-skills-244's own
  # non-equivalent mutation pass.
  mkdir ($root_b | path join "my-plugin" "commands")
  mkdir ($root_b | path join "my-plugin" "agents")

  # claude-skills-244 Gate 3 round 4 — a skill whose "SKILL.md" is itself a
  # DIRECTORY, not just absent. This is the regression guard #223 had (via
  # agent_path_is_directory_errors) but this file's skills branch lacked:
  # team-lead's reviewer proved `skill_dir_exists_no_skill_md_errors` above
  # (SKILL.md simply absent) passes under BOTH the pre-#224 `not (path
  # exists)` guard AND the fixed guard — reverting the fix left the whole
  # 83-case suite green, because that fixture never distinguished which
  # guard shape was running. This one does: a directory literally named
  # "SKILL.md" passes `path exists` under the OLD guard (a directory
  # exists) and crashes on real, unmutated pre-fix code with zero
  # mutation — reproduced directly against the merged pre-#224 file before
  # writing this fixture, same as the agents twin.
  mkdir ($root_b | path join "my-plugin" "skills" "skill-md-is-dir" "SKILL.md")

  # claude-skills-244 Gate 3 round 3 — regression fixtures for the symlink
  # false-positive team-lead's reviewer flagged: bare `path type` reports
  # "symlink" regardless of what it points at, so a symlinked SKILL.md or
  # agent file that `open` reads perfectly well would have been wrongly
  # rejected as missing/not-a-file by the pre-`path expand` guards. Real
  # on-disk symlinks, not mutations — these prove the ACCEPT direction,
  # complementing the reject-direction fixtures the rest of this block
  # covers. A broken/dangling symlink is deliberately NOT covered here — it
  # never reaches the type guard at all, since `path exists` is already
  # `false` for it (verified separately; see the guards' own comments).
  mkdir ($root_b | path join "my-plugin" "skills" "symlink-target")
  "---\nname: symlink-target\ndescription: Use when testing.\n---\n\nbody\n" | save --force ($root_b | path join "my-plugin" "skills" "symlink-target" "SKILL.md")
  mkdir ($root_b | path join "my-plugin" "skills" "symlinked-skill")
  ^ln -sf ($root_b | path join "my-plugin" "skills" "symlink-target" "SKILL.md") ($root_b | path join "my-plugin" "skills" "symlinked-skill" "SKILL.md")

  mkdir ($root_b | path join "my-plugin" "agents-real-target")
  "---\nname: symlinked-agent\ndescription: test fixture\ntools: Bash\nmodel: opus\n---\n\nbody\n" | save --force ($root_b | path join "my-plugin" "agents-real-target" "real-agent.md")
  ^ln -sf ($root_b | path join "my-plugin" "agents-real-target" "real-agent.md") ($root_b | path join "my-plugin" "agents" "symlinked-agent.md")

  let array_path_cases = [
    {
      name: "keywords_not_array_errors"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", keywords: "not-an-array" }
      expect_errors: 1
      expect_warnings: 0
      expect_error_contains: "'keywords' must be an array"
      why: "claude-skills-244 — 'keywords' must be an array had zero reject-direction coverage; a string value isolates the type-check dimension alone. plugin-schema.md documents keywords as array-only, so no doc divergence here (unlike commands/agents below)"
    }
    {
      name: "skills_not_array_errors"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", skills: "not-an-array" }
      expect_errors: 1
      expect_warnings: 0
      expect_error_contains: "skills must be an array"
      why: "claude-skills-244 — skills must be an array had zero reject-direction coverage. (The sibling 'skills field must be an array or omitted entirely (not null)' null-branch this comment used to distinguish itself from was deleted in claude-skills-245 as unreachable dead code — the outer `!= null` guard already skips it for any file-loaded manifest.) plugin-schema.md documents skills as array-only, so no doc divergence here (unlike commands/agents below)"
    }
    {
      name: "commands_string_form_accepted"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", commands: "not-an-array" }
      expect_errors: 0
      expect_warnings: 1
      expect_warning_contains: "Command path not found: not-an-array"
      why: "claude-skills-244/246/Gate-3 history: this fixture (formerly commands_not_array_errors) originally asserted a bare string errors. claude-skills-246 tried narrowing the docs to array-only to match that behavior — WRONG per Gate 3's independent upstream verification (code.claude.com/docs/en/plugins-reference documents commands/agents as string|array, with bare-string examples, and explicitly: a string 'Replaces the default: commands, agents...'). Reversed: the validator now ACCEPTS a string, existence-checked as a single path (not coerced into the array-entry loop, which would wrongly demand it be a file). 'not-an-array' is a syntactically valid but non-resolving path, so this proves acceptance-as-a-type (0 errors) with the expected not-found warning, not a clean pass — see commands_string_form_resolves_cleanly below for that"
    }
    {
      name: "agents_string_form_accepted"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", agents: "not-an-array" }
      expect_errors: 0
      expect_warnings: 1
      expect_warning_contains: "Agent path not found: not-an-array"
      why: "claude-skills-246/Gate-3 — same reversal as commands_string_form_accepted above, for agents (formerly agents_not_array_errors)"
    }
    {
      name: "commands_string_form_resolves_cleanly"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", commands: "commands" }
      expect_errors: 0
      expect_warnings: 0
      why: "claude-skills-246 Gate 3 — the actual restored feature: a string pointing at a real, existing directory (root_b/my-plugin/commands, already on disk from the path-not-found fixtures above) must pass cleanly with zero errors/warnings, proving the string form isn't just type-accepted but genuinely usable"
    }
    {
      name: "agents_string_form_resolves_cleanly"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", agents: "agents" }
      expect_errors: 0
      expect_warnings: 0
      why: "claude-skills-246 Gate 3 — same as commands_string_form_resolves_cleanly above, for agents (root_b/my-plugin/agents already exists on disk)"
    }
    {
      name: "commands_wrong_type_errors"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", commands: 42 }
      expect_errors: 1
      expect_warnings: 0
      expect_error_contains: "commands must be a string or an array"
      why: "claude-skills-246 Gate 3 — with strings now accepted, the type check needs a value invalid under BOTH accepted shapes to isolate the reject direction; a bare number is neither a string nor a list/table"
    }
    {
      name: "agents_wrong_type_errors"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", agents: 42 }
      expect_errors: 1
      expect_warnings: 0
      expect_error_contains: "agents must be a string or an array"
      why: "claude-skills-246 Gate 3 — same reasoning as commands_wrong_type_errors above, for agents"
    }
    {
      name: "missing_description_warns"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", license: "MIT" }
      expect_errors: 0
      expect_warnings: 1
      expect_warning_contains: "Missing recommended field: description"
      why: "claude-skills-244 — 'Missing recommended field: description' had zero reject-direction coverage in isolation (existing missing-name fixture drops 3 fields at once and doesn't assert warning counts)"
    }
    {
      name: "missing_license_warns"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture" }
      expect_errors: 0
      expect_warnings: 1
      expect_warning_contains: "Missing recommended field: license"
      why: "claude-skills-244 — 'Missing recommended field: license' had zero reject-direction coverage in isolation"
    }
    {
      name: "skill_dir_exists_no_skill_md_errors"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", skills: ["skills/present-without-md"] }
      expect_errors: 1
      expect_warnings: 0
      expect_error_contains: "missing SKILL.md file"
      why: "claude-skills-244 — 'Skill directory ... missing SKILL.md file' had zero coverage; skills/present-without-md genuinely EXISTS under root_b (so the path-not-found warning can't be what's firing) but has no SKILL.md, and root_b carries sources.md so that warning doesn't leak in"
    }
    {
      name: "skill_md_is_directory_errors"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", skills: ["skills/skill-md-is-dir"] }
      expect_errors: 1
      expect_warnings: 0
      expect_error_contains: "SKILL.md that is a directory, not a file"
      why: "claude-skills-244 Gate 3 round 4 — team-lead's reviewer found skill_dir_exists_no_skill_md_errors above passes under BOTH the pre-#224 `not (path exists)` guard and the fixed one, so it never pinned the fix: reverting the fix left the whole 83-case suite green. This fixture distinguishes them: skills/skill-md-is-dir/SKILL.md (created above) is a real on-disk DIRECTORY, which DOES pass a bare `path exists` check, so the old guard would fall straight into `open` and crash with zero mutation — reproduced directly against the merged pre-#224 file. Also pins the message-wording fix (team-lead's nit): a directory gets a distinct 'is a directory, not a file' message instead of the generic 'missing SKILL.md file', matching the agents branch's existing wording. Verified BOTH revert directions directly: fully reverting to bare `not (path exists)` (no type check at all) crashes this case with an uncaught nu::shell::io::is_a_directory, exit 1; reverting only the message split (keeping the `!= 'file'` type check but the old generic message) fails this case by an ordinary self-test assertion mismatch — expected an error containing 'SKILL.md that is a directory, not a file', got 'missing SKILL.md file' — exit 0 for the suite run itself but a reported self-test failure. Neither revert direction passes silently"
    }
    {
      name: "skill_path_missing_warns"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", skills: ["skills/does-not-exist"] }
      expect_errors: 0
      expect_warnings: 1
      expect_warning_contains: "Skill path not found"
      why: "claude-skills-244 — 'Skill path not found' had zero coverage; skills/does-not-exist genuinely does NOT exist under root_b, isolating this from the missing-SKILL.md case above which points at a path that DOES exist"
    }
    {
      name: "sources_md_missing_warns"
      root: $root_a
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", skills: ["skills/present-with-md"] }
      expect_errors: 0
      expect_warnings: 1
      expect_warning_contains: "Missing recommended file: skills/sources.md"
      why: "claude-skills-244 — 'Missing recommended file: skills/sources.md' had zero coverage; root_a's skills/present-with-md genuinely exists with a fully valid SKILL.md (no errors/warnings of its own), isolating the sources.md-missing warning alone"
    }
    {
      name: "command_path_missing_warns"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", commands: ["commands/does-not-exist.md"] }
      expect_errors: 0
      expect_warnings: 1
      expect_warning_contains: "Command path not found: commands/does-not-exist.md"
      why: "claude-skills-244 — 'Command path not found' had zero coverage. Substring pins the FULL message (including the path), not just severity+count, per Gate 3's 'right check, wrong report' finding: a mutation at line 472 that swapped the literal to 'Agent path not found: ($command)' kept the same warning count and passed 79/79 until this assertion was added"
    }
    {
      name: "agent_path_missing_warns"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", agents: ["agents/does-not-exist.md"] }
      expect_errors: 0
      expect_warnings: 1
      expect_warning_contains: "Agent path not found: agents/does-not-exist.md"
      why: "claude-skills-244 — 'Agent path not found' had zero coverage. Substring pins the full message for the same 'right check, wrong report' reason as command_path_missing_warns above"
    }
    {
      name: "agent_path_is_directory_errors"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", agents: ["agents"] }
      expect_errors: 1
      expect_warnings: 0
      expect_error_contains: "Agent path is a directory, not a file"
      why: "claude-skills-244 Gate 3 finding — reachable with ZERO mutation on real production code: an agents array entry resolving to a directory (root_b/my-plugin/agents, empty, created above) hit validate-agent-md's `open $agent_path --raw` and crashed the entire self-test run with an uncaught nu::shell::io::is_a_directory error, silently discarding every already-recorded failure and every case queued after it. Fixed with a `path type` guard reporting a clean error instead of crashing; this fixture is the regression guard for that fix, not just a coverage gap"
    }
    {
      name: "skill_symlink_to_real_file_accepts"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", skills: ["skills/symlinked-skill"] }
      expect_errors: 0
      expect_warnings: 0
      why: "claude-skills-244 Gate 3 round 3 — regression guard for the symlink false-positive team-lead's reviewer found: skills/symlinked-skill/SKILL.md (created above) is a REAL on-disk symlink pointing at a real, valid SKILL.md. Before the `path expand` fix, bare `path type` reported 'symlink' (not 'file') and this would have been wrongly rejected as missing. Must accept cleanly with zero errors/warnings — proves the ACCEPT direction the reject-direction fixtures above don't cover. If the `path expand` guard is reverted to bare `path type`, this case fails by an ordinary assertion mismatch (expected 0 errors, got 1), not a crash — verified directly"
    }
    {
      name: "agent_symlink_to_real_file_accepts"
      root: $root_b
      plugin: { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT", agents: ["agents/symlinked-agent.md"] }
      expect_errors: 0
      expect_warnings: 0
      why: "claude-skills-244 Gate 3 round 3 — same regression guard as skill_symlink_to_real_file_accepts, for the agents path. agents/symlinked-agent.md (created above) is a REAL on-disk symlink to a valid agent .md file. Same revert behavior verified: reverting to bare `path type` fails this case by ordinary assertion mismatch, not a crash"
    }
  ]

  for c in $array_path_cases {
    let plugin_path = ($array_path_temp_dir | path join $"($c.name).json")
    $c.plugin | save --force $plugin_path
    let result = (validate-plugin-content $plugin_path $c.root "my-plugin" "my-plugin" false false false)
    if ($result.errors | length) != $c.expect_errors {
      $failures = ($failures | append $"array_path_($c.name): expected ($c.expect_errors) errors, got (($result.errors | length)): ($result.errors | to nuon) -- ($c.why)")
    }
    let expect_error_contains = ($c | get -o expect_error_contains)
    if ($expect_error_contains != null) and not ($result.errors | any {|e| $e | str contains $expect_error_contains }) {
      $failures = ($failures | append $"array_path_($c.name): expected an error containing '($expect_error_contains)', got: ($result.errors | to nuon) -- ($c.why)")
    }
    let expect_warning_contains = ($c | get -o expect_warning_contains)
    if ($expect_warning_contains != null) and not ($result.warnings | any {|w| $w | str contains $expect_warning_contains }) {
      $failures = ($failures | append $"array_path_($c.name): expected a warning containing '($expect_warning_contains)', got: ($result.warnings | to nuon) -- ($c.why)")
    }
    if ($result.warnings | length) != $c.expect_warnings {
      $failures = ($failures | append $"array_path_($c.name): expected ($c.expect_warnings) warnings, got (($result.warnings | length)): ($result.warnings | to nuon) -- ($c.why)")
    }
  }
  rm -rf $array_path_temp_dir

  # claude-skills-238: main, validate-plugin-file, validate-from-marketplace,
  # and setup-external-plugin's non-network branch are entirely unreached by
  # every case above, because all of them call `exit` on at least one path —
  # invoking them in-process would kill the self-test run itself on the
  # first hit. The only safe way to exercise them is a subprocess: spawn
  # `nu <this-script> <args>` and assert on its exit code (`^nu ... | complete`
  # captures the exit code instead of propagating it into this process).
  # Scope boundary, stated explicitly per claude-skills-238's own request
  # rather than left implicit: setup-external-plugin's actual `git clone`
  # success and failure paths are NOT covered here. Reaching them needs a
  # live network call, and self-test must stay network-free — every other
  # network-touching script in this repo (sources-check.nu, sources-report.nu,
  # sources-stale.nu, fence-freshness.nu) keeps live calls out of --self-test
  # for the same reason. The one setup-external-plugin branch that requires
  # no network — "source is an object but not github, or a github source with
  # an empty repo path" — IS covered below (cli_marketplace_unsupported_external_source_exit_1).
  let self_path = $env.CURRENT_FILE
  let cli_temp_dir = (mktemp -d)

  # A minimal valid plugin.json for the direct-file and marketplace-local
  # success cases below.
  let cli_plugin_dir = ($cli_temp_dir | path join "my-plugin")
  mkdir ($cli_plugin_dir | path join ".claude-plugin")
  { name: "my-plugin", version: "1.0.0", description: "test fixture", license: "MIT" } | save --force ($cli_plugin_dir | path join ".claude-plugin" "plugin.json")

  # claude-skills-247 — skill_md_cases' "scalar_yaml_frontmatter" case
  # above calls validate-skill-md directly (same process as this self-test
  # run), so a MUTATION that reintroduces the pre-fix crash there crashes
  # this WHOLE self-test script rather than failing that one case cleanly
  # — confirmed directly while writing this fixture. Reaching the same
  # guard through the full CLI (subprocess + `complete`, the same
  # isolation `cli_cases` already relies on for the marketplace guards
  # above) means a reverted guard fails THIS case by assertion instead,
  # without risking the rest of the suite's report.
  # Direct-file CLI mode derives BOTH plugin_root (the plugin's own
  # directory) AND source_dir (= plugin_name) from the target, so paths
  # inside the skills array resolve as plugin_root/plugin_name/<entry> —
  # a doubled directory-name nesting, verified directly by computing it
  # before placing this fixture (the first attempt at this fixture put
  # SKILL.md one level too shallow and silently produced a "Skill path
  # not found" warning instead of reaching the guard under test at all).
  let cli_scalar_yaml_plugin_dir = ($cli_temp_dir | path join "scalar-yaml-plugin")
  mkdir ($cli_scalar_yaml_plugin_dir | path join ".claude-plugin")
  { name: "scalar-yaml-plugin", version: "1.0.0", description: "test fixture", license: "MIT", skills: ["skills/bad-skill"] } | save --force ($cli_scalar_yaml_plugin_dir | path join ".claude-plugin" "plugin.json")
  mkdir ($cli_scalar_yaml_plugin_dir | path join "scalar-yaml-plugin" "skills" "bad-skill")
  "---\nhello\n---\n\nbody\n" | save --force ($cli_scalar_yaml_plugin_dir | path join "scalar-yaml-plugin" "skills" "bad-skill" "SKILL.md")

  # Same doubled-nesting layout as scalar-yaml-plugin above, for the
  # remaining three YAML-guard shapes (skill malformed, agent scalar,
  # agent malformed).
  let cli_malformed_yaml_skill_plugin_dir = ($cli_temp_dir | path join "malformed-yaml-skill-plugin")
  mkdir ($cli_malformed_yaml_skill_plugin_dir | path join ".claude-plugin")
  { name: "malformed-yaml-skill-plugin", version: "1.0.0", description: "test fixture", license: "MIT", skills: ["skills/bad-skill"] } | save --force ($cli_malformed_yaml_skill_plugin_dir | path join ".claude-plugin" "plugin.json")
  mkdir ($cli_malformed_yaml_skill_plugin_dir | path join "malformed-yaml-skill-plugin" "skills" "bad-skill")
  "---\nname: [unclosed\n---\n\nbody\n" | save --force ($cli_malformed_yaml_skill_plugin_dir | path join "malformed-yaml-skill-plugin" "skills" "bad-skill" "SKILL.md")

  let cli_scalar_yaml_agent_plugin_dir = ($cli_temp_dir | path join "scalar-yaml-agent-plugin")
  mkdir ($cli_scalar_yaml_agent_plugin_dir | path join ".claude-plugin")
  { name: "scalar-yaml-agent-plugin", version: "1.0.0", description: "test fixture", license: "MIT", agents: ["agents/bad-agent.md"] } | save --force ($cli_scalar_yaml_agent_plugin_dir | path join ".claude-plugin" "plugin.json")
  mkdir ($cli_scalar_yaml_agent_plugin_dir | path join "scalar-yaml-agent-plugin" "agents")
  "---\nhello\n---\n\nbody\n" | save --force ($cli_scalar_yaml_agent_plugin_dir | path join "scalar-yaml-agent-plugin" "agents" "bad-agent.md")

  let cli_malformed_yaml_agent_plugin_dir = ($cli_temp_dir | path join "malformed-yaml-agent-plugin")
  mkdir ($cli_malformed_yaml_agent_plugin_dir | path join ".claude-plugin")
  { name: "malformed-yaml-agent-plugin", version: "1.0.0", description: "test fixture", license: "MIT", agents: ["agents/bad-agent.md"] } | save --force ($cli_malformed_yaml_agent_plugin_dir | path join ".claude-plugin" "plugin.json")
  mkdir ($cli_malformed_yaml_agent_plugin_dir | path join "malformed-yaml-agent-plugin" "agents")
  "---\nname: [unclosed\n---\n\nbody\n" | save --force ($cli_malformed_yaml_agent_plugin_dir | path join "malformed-yaml-agent-plugin" "agents" "bad-agent.md")

  let cli_invalid_json_path = ($cli_temp_dir | path join "invalid.json")
  # "not valid json {{{" is NOT actually invalid per nu's own `from json`,
  # which accepts a JSON5-style bare "quoteless string" and returns it
  # unchanged (`"not valid json {{{" | from json | describe` => "string") —
  # verified directly, this made the try/catch in validate-plugin-file a
  # silent no-op and the case failed on the wrong assertion. A truncated
  # object is genuinely unparseable to nu's JSON parser (verified: raises
  # `nu::shell::error` / "EOF while parsing an object").
  "{\"name\": \"broken\"" | save --force $cli_invalid_json_path

  # claude-skills-243 — the flip side of cli_invalid_json_path above: these
  # ARE genuinely valid JSON (a bare string, number, bool, and array are
  # all legal top-level JSON values, not just nu leniency), but none of
  # them is a plugin.json OBJECT, so the pre-fix code crashed trying to
  # treat the parsed scalar as a record. Content verified to actually
  # parse leniently before use, not assumed: `"not valid json {{{" | from
  # json | describe` => "string", `"42"` => "int", `"true"` => "bool",
  # `"[1, 2, 3]"` => "list<int>".
  let cli_scalar_string_path = ($cli_temp_dir | path join "scalar-string.json")
  "not valid json {{{" | save --force $cli_scalar_string_path
  let cli_scalar_number_path = ($cli_temp_dir | path join "scalar-number.json")
  "42" | save --force $cli_scalar_number_path
  let cli_scalar_bool_path = ($cli_temp_dir | path join "scalar-bool.json")
  "true" | save --force $cli_scalar_bool_path
  let cli_scalar_list_path = ($cli_temp_dir | path join "scalar-list.json")
  "[1, 2, 3]" | save --force $cli_scalar_list_path

  # claude-skills-243 — the SECOND instance of the same guard hole, in
  # validate-plugin-content's own try/catch, reached only via the
  # marketplace path (validate-from-marketplace bypasses validate-plugin-
  # file's copy of this guard entirely). One shape is enough to prove this
  # second, structurally-identical guard is also fixed; the four shapes
  # above already cover the AC's "each scalar shape" against the primary,
  # more commonly hit validate-plugin-file guard.
  let cli_scalar_marketplace_plugin_dir = ($cli_temp_dir | path join "scalar-plugin")
  mkdir ($cli_scalar_marketplace_plugin_dir | path join ".claude-plugin")
  "42" | save --force ($cli_scalar_marketplace_plugin_dir | path join ".claude-plugin" "plugin.json")

  # claude-skills-238 Gate 3 review — the description/keywords marketplace-
  # agreement check itself (validate-plugin.nu's has_marketplace_context
  # blocks, claude-skills-170's deletion-is-a-failure rule) had ZERO
  # reject-direction fixture coverage: neutering either block to `if false`
  # left the pre-fix suite green. cli_marketplace_valid_local_plugin_exit_0
  # above only exercises the AGREE direction. Two dedicated plugin dirs
  # (rather than reusing my-plugin) keep these isolated from a compounding
  # "Name mismatch" error, since plugin.json's own 'name' must equal the
  # marketplace entry's lookup name for that error to stay silent here.
  let cli_desc_mismatch_dir = ($cli_temp_dir | path join "desc-mismatch-plugin")
  mkdir ($cli_desc_mismatch_dir | path join ".claude-plugin")
  { name: "desc-mismatch-plugin", version: "1.0.0", description: "test fixture", keywords: ["alpha", "beta"], license: "MIT" } | save --force ($cli_desc_mismatch_dir | path join ".claude-plugin" "plugin.json")

  let cli_keywords_mismatch_dir = ($cli_temp_dir | path join "keywords-mismatch-plugin")
  mkdir ($cli_keywords_mismatch_dir | path join ".claude-plugin")
  { name: "keywords-mismatch-plugin", version: "1.0.0", description: "test fixture", keywords: ["alpha", "beta"], license: "MIT" } | save --force ($cli_keywords_mismatch_dir | path join ".claude-plugin" "plugin.json")

  let cli_marketplace_dir = ($cli_temp_dir | path join ".claude-plugin")
  mkdir $cli_marketplace_dir
  let cli_marketplace_path = ($cli_marketplace_dir | path join "marketplace.json")
  {
    name: "fixture-marketplace"
    owner: { name: "fixture" }
    plugins: [
      # description here must match the plugin.json fixture's description
      # above ("test fixture") — validate-plugin-content's marketplace-context
      # check treats plugin.json as authoritative and errors when the
      # marketplace entry omits a description plugin.json defines
      # (claude-skills-170's deletion-is-a-failure rule). Omitting it here
      # was the actual cause of this case's exit-1 failure, not a defect in
      # validate-from-marketplace's local-source success path.
      { name: "my-plugin", source: "./my-plugin", description: "test fixture" }
      { name: "external-plugin", source: { source: "npm", package: "not-github" } }
      # Deliberately WRONG description — plugin.json says "test fixture",
      # keywords agree, so only the description-mismatch branch fires.
      { name: "desc-mismatch-plugin", source: "./desc-mismatch-plugin", description: "a totally different description", keywords: ["alpha", "beta"] }
      # Deliberately WRONG keywords — description agrees, so only the
      # keywords-mismatch branch fires.
      { name: "keywords-mismatch-plugin", source: "./keywords-mismatch-plugin", description: "test fixture", keywords: ["gamma", "delta"] }
      # claude-skills-243 — scalar-plugin's on-disk plugin.json (created
      # above) is the bare integer 42, reaching validate-plugin-content's
      # OWN try/catch guard directly through this marketplace path.
      { name: "scalar-plugin", source: "./scalar-plugin" }
    ]
  } | save --force $cli_marketplace_path

  let cli_empty_marketplace_path = ($cli_temp_dir | path join "empty-marketplace.json")
  { name: "fixture-marketplace", owner: { name: "fixture" }, plugins: [] } | save --force $cli_empty_marketplace_path

  # claude-skills-247 — several more crash shapes for
  # validate-from-marketplace, each reproduced with zero mutation against
  # pre-fix code before being written here.
  #
  # "not json {{{" parses LENIENTLY to a bare string (verified:
  # `"not json {{{" | from json | describe` => "string") — it exercises
  # ONLY the record-type check, never the try/catch's raise path. Gate 3
  # caught that neutering just the try/catch (leaving the record check
  # intact) left the suite green with only this fixture in place —
  # genuinely malformed content that `from json` cannot parse leniently
  # at all is needed too (`{"name": }` — verified directly: raises
  # `nu::shell::error`, "found a punctuator character when expecting a
  # quoteless string").
  let cli_malformed_marketplace_path = ($cli_temp_dir | path join "malformed-marketplace.json")
  "not json {{{" | save --force $cli_malformed_marketplace_path
  let cli_unparseable_marketplace_path = ($cli_temp_dir | path join "unparseable-marketplace.json")
  "{\"name\": }" | save --force $cli_unparseable_marketplace_path

  # A syntactically valid marketplace.json missing the 'plugins' key
  # entirely (bare `.plugins` cell-path access crashed with
  # column_not_found). Carries `owner` matching the valid fixtures above
  # so it differs from them in exactly the one dimension under test
  # (Gate 3 nit — the first version of this fixture omitted `owner` too,
  # a second, inert difference).
  let cli_no_plugins_key_marketplace_path = ($cli_temp_dir | path join "no-plugins-key-marketplace.json")
  { name: "fixture-marketplace", owner: { name: "fixture" } } | save --force $cli_no_plugins_key_marketplace_path

  # claude-skills-247 Gate 3 — a fifth shape, found on the exact line this
  # PR rewrote: a `plugins` key that IS present but wrong-typed. Both
  # sub-shapes reproduced with zero mutation before this fix:
  # `{"plugins": "hi"}` crashes when the string is piped into `where`;
  # `{"plugins": [42, "x"]}` passes the list-type check but crashes
  # inside `where name == ...` on the first non-record entry (verified
  # directly: `where` raises on the first element it can't apply the
  # comparison to, it does not silently skip mistyped entries).
  let cli_plugins_wrong_type_marketplace_path = ($cli_temp_dir | path join "plugins-wrong-type-marketplace.json")
  { name: "fixture-marketplace", owner: { name: "fixture" }, plugins: "hi" } | save --force $cli_plugins_wrong_type_marketplace_path
  let cli_plugins_non_record_entries_marketplace_path = ($cli_temp_dir | path join "plugins-non-record-entries-marketplace.json")
  { name: "fixture-marketplace", owner: { name: "fixture" }, plugins: [42, "x"] } | save --force $cli_plugins_non_record_entries_marketplace_path

  # claude-skills-247 Gate 3 round 2 — a SIXTH shape, found on the exact
  # line the round-1 fix rewrote: a `plugins` entry that IS a record but
  # has no `name` key. Filtering to "is this a record" alone (round 1's
  # guard) does NOT protect against this — nushell's `where name == ...`
  # raises column_not_found on a record missing the compared column
  # rather than skipping it, verified directly and independently of the
  # non-record shapes above. Two fixtures: the nameless-record-alone case
  # (must not crash, falls through to not-found), and a nameless record
  # FOLLOWED BY a valid, matching entry (proves the filter genuinely
  # skips the bad entry and keeps evaluating, rather than aborting the
  # whole list on the first bad one).
  let cli_plugins_nameless_record_marketplace_path = ($cli_temp_dir | path join "plugins-nameless-record-marketplace.json")
  { name: "fixture-marketplace", owner: { name: "fixture" }, plugins: [{ foo: 1 }] } | save --force $cli_plugins_nameless_record_marketplace_path

  # `cli_plugins_nameless_then_valid_marketplace_path` needs a REAL local
  # source lookup to succeed, unlike the other marketplace fixtures above
  # (which all fail before ever reaching source resolution). marketplace
  # source resolution derives marketplace_dir as
  # `dirname(dirname(marketplace_path))`, expecting the file at
  # `<root>/.claude-plugin/marketplace.json` — a flat file directly under
  # $cli_temp_dir (like the other marketplace fixtures) resolves
  # marketplace_dir one level too high and the lookup silently fails. Self-
  # contained subtree, mirroring cli_marketplace_dir/cli_plugin_dir's own
  # structure, to avoid that trap (caught directly: this fixture initially
  # used a flat path and failed with "not found" for the wrong reason).
  let cli_nameless_then_valid_root = ($cli_temp_dir | path join "nameless-then-valid-mkt")
  let cli_nameless_then_valid_marketplace_dir = ($cli_nameless_then_valid_root | path join ".claude-plugin")
  mkdir $cli_nameless_then_valid_marketplace_dir
  let cli_plugins_nameless_then_valid_marketplace_path = ($cli_nameless_then_valid_marketplace_dir | path join "marketplace.json")
  { name: "fixture-marketplace", owner: { name: "fixture" }, plugins: [{ foo: 1 }, { name: "target-plugin", source: "./target-plugin", description: "test fixture" }] } | save --force $cli_plugins_nameless_then_valid_marketplace_path
  let cli_nameless_then_valid_plugin_dir = ($cli_nameless_then_valid_root | path join "target-plugin")
  mkdir ($cli_nameless_then_valid_plugin_dir | path join ".claude-plugin")
  { name: "target-plugin", version: "1.0.0", description: "test fixture", license: "MIT" } | save --force ($cli_nameless_then_valid_plugin_dir | path join ".claude-plugin" "plugin.json")

  let cli_cases = [
    {
      name: "cli_valid_plugin_file_exit_0"
      args: [($cli_plugin_dir | path join ".claude-plugin" "plugin.json")]
      expect_exit: 0
      why: "validate-plugin-file's success path — main + validate-plugin-file together"
    }
    {
      name: "cli_scalar_yaml_skill_exit_1"
      args: [($cli_scalar_yaml_plugin_dir | path join ".claude-plugin" "plugin.json")]
      expect_exit: 1
      expect_output_contains: "malformed YAML frontmatter"
      why: "claude-skills-247 — subprocess-isolated regression guard for validate-skill-md's record-type check, reached through the full CLI + skills-array path rather than a direct function call, so a reverted guard fails THIS case by clean assertion (stdout mismatch) instead of crashing the whole self-test — verified directly by reverting the guard and observing the crash happens in the CHILD process only"
    }
    {
      name: "cli_malformed_yaml_skill_exit_1"
      args: [($cli_malformed_yaml_skill_plugin_dir | path join ".claude-plugin" "plugin.json")]
      expect_exit: 1
      expect_output_contains: "malformed YAML frontmatter"
      why: "claude-skills-247 — subprocess-isolated regression guard for validate-skill-md's try/catch (genuinely malformed YAML, an unclosed flow sequence), same isolation reasoning as cli_scalar_yaml_skill_exit_1 above"
    }
    {
      name: "cli_scalar_yaml_agent_exit_1"
      args: [($cli_scalar_yaml_agent_plugin_dir | path join ".claude-plugin" "plugin.json")]
      expect_exit: 1
      expect_output_contains: "malformed YAML frontmatter"
      why: "claude-skills-247 — subprocess-isolated regression guard for validate-agent-md's record-type check, agents-array path, same isolation reasoning as the skill cases above"
    }
    {
      name: "cli_malformed_yaml_agent_exit_1"
      args: [($cli_malformed_yaml_agent_plugin_dir | path join ".claude-plugin" "plugin.json")]
      expect_exit: 1
      expect_output_contains: "malformed YAML frontmatter"
      why: "claude-skills-247 — subprocess-isolated regression guard for validate-agent-md's try/catch, agents-array path, same isolation reasoning as the skill cases above"
    }
    {
      name: "cli_missing_file_exit_1"
      args: [($cli_temp_dir | path join "does-not-exist.json")]
      expect_exit: 1
      expect_output_contains: "File not found"
      why: "validate-plugin-file's file-not-found branch"
    }
    {
      name: "cli_invalid_json_exit_1"
      args: [$cli_invalid_json_path]
      expect_exit: 1
      expect_output_contains: "Invalid JSON syntax"
      why: "validate-plugin-file's JSON-parse-failure branch"
    }
    {
      name: "cli_scalar_string_json_exit_1"
      args: [$cli_scalar_string_path]
      expect_exit: 1
      expect_output_contains: "Invalid JSON syntax"
      why: "claude-skills-243 — a bare string parses leniently instead of raising, so the try/catch above never fires; the record-type check after it must still reject this and route into the same message"
    }
    {
      name: "cli_scalar_number_json_exit_1"
      args: [$cli_scalar_number_path]
      expect_exit: 1
      expect_output_contains: "Invalid JSON syntax"
      why: "claude-skills-243 — a bare number ('42') is genuinely valid top-level JSON, not just nu leniency, and parses to an int; must still be rejected as not-a-plugin-manifest"
    }
    {
      name: "cli_scalar_bool_json_exit_1"
      args: [$cli_scalar_bool_path]
      expect_exit: 1
      expect_output_contains: "Invalid JSON syntax"
      why: "claude-skills-243 — a bare bool ('true') is valid top-level JSON and parses to a bool; must still be rejected"
    }
    {
      name: "cli_scalar_list_json_exit_1"
      args: [$cli_scalar_list_path]
      expect_exit: 1
      expect_output_contains: "Invalid JSON syntax"
      why: "claude-skills-243 — a JSON array is a valid top-level JSON value and parses to a list, not a record; must still be rejected"
    }
    {
      name: "cli_marketplace_scalar_plugin_exit_1"
      args: ["scalar-plugin", "--marketplace", $cli_marketplace_path]
      expect_exit: 1
      expect_output_contains: "Failed to parse plugin.json"
      why: "claude-skills-243 — the SECOND guard instance, in validate-plugin-content's own try/catch, reached only via the marketplace path (validate-from-marketplace never goes through validate-plugin-file's copy of this guard). Different message than the direct-file cases above on purpose, per the compatibility constraint: this function's existing 'Failed to parse plugin.json' message, not a shared one"
    }
    {
      name: "cli_no_target_exit_1"
      args: []
      expect_exit: 1
      expect_output_contains: "target is required"
      why: "main's missing-target branch, with neither a target nor --self-test"
    }
    {
      name: "cli_marketplace_missing_exit_1"
      args: ["somename", "--marketplace", ($cli_temp_dir | path join "does-not-exist-marketplace.json")]
      expect_exit: 1
      expect_output_contains: "Marketplace not found"
      why: "validate-from-marketplace's marketplace-file-missing branch"
    }
    {
      name: "cli_marketplace_path_is_directory_exit_1"
      args: ["somename", "--marketplace", $cli_plugin_dir]
      expect_exit: 1
      expect_output_contains: "Marketplace path is not a file"
      why: "claude-skills-244 Gate 3 round 3 finding — a THIRD reachable open() crash, found by sweeping every `open` call site in this file after #223/#224 fixed the first two. `path exists` is true for directories, and this open() had no try/catch (unlike the two safe `open $plugin_path` sites, verified separately to catch is_a_directory via try/catch). Reused cli_plugin_dir (already a real directory from the earlier fixtures) as the --marketplace argument — reproduces with zero mutation and no plugin.json involved: a plain CLI typo pointing --marketplace at a directory instead of marketplace.json"
    }
    {
      name: "cli_marketplace_malformed_json_exit_1"
      args: ["somename", "--marketplace", $cli_malformed_marketplace_path]
      expect_exit: 1
      expect_output_contains: "Failed to parse marketplace.json"
      why: "claude-skills-247 — a FOURTH instance of the lenient-scalar-parse defect (claude-skills-243), in this third `open` call site that #227's record guards never covered. 'not json {{{' parses leniently to a bare string (verified: `\"not json {{{\" | from json | describe` => \"string\"), and the pre-fix code's bare `$marketplace.plugins` cell-path access crashed with incompatible_path_access instead of ever reaching this message"
    }
    {
      name: "cli_marketplace_unparseable_json_exit_1"
      args: ["somename", "--marketplace", $cli_unparseable_marketplace_path]
      expect_exit: 1
      expect_output_contains: "Failed to parse marketplace.json"
      why: "claude-skills-247 Gate 3 — the try/catch's actual raise path, distinct from cli_marketplace_malformed_json_exit_1 above which only exercises the record-type check. '{\"name\": }' genuinely cannot be parsed leniently (verified: raises nu::shell::error, 'found a punctuator character when expecting a quoteless string'). Gate 3 found that neutering ONLY the try/catch (keeping the record check) left the suite green with just the lenient-scalar fixture in place — this one closes that gap"
    }
    {
      name: "cli_marketplace_no_plugins_key_exit_1"
      args: ["somename", "--marketplace", $cli_no_plugins_key_marketplace_path]
      expect_exit: 1
      expect_output_contains: "not found in marketplace"
      why: "claude-skills-247 — a syntactically valid marketplace.json missing the 'plugins' key entirely crashed with column_not_found on the pre-fix bare `.plugins` access. `get -o plugins | default []` routes this into the EXISTING plugin-not-found message rather than a new one — reproduced against pre-fix code before writing this fixture"
    }
    {
      name: "cli_marketplace_plugins_wrong_type_exit_1"
      args: ["somename", "--marketplace", $cli_plugins_wrong_type_marketplace_path]
      expect_exit: 1
      expect_output_contains: "Marketplace 'plugins' must be an array"
      why: "claude-skills-247 Gate 3 — a fifth crash shape found on the exact line this PR rewrote: {\"plugins\": \"hi\"} crashed the pre-fix `where` filter with only_supports_this_input_type. Reproduced directly before writing this fixture"
    }
    {
      name: "cli_marketplace_plugins_non_record_entries_exit_1"
      args: ["somename", "--marketplace", $cli_plugins_non_record_entries_marketplace_path]
      expect_exit: 1
      expect_output_contains: "not found in marketplace"
      why: "claude-skills-247 Gate 3 — {\"plugins\": [42, \"x\"]} passes the list-type check but the pre-fix code crashed inside `where name == ...` on the first non-record entry (verified directly: incompatible_path_access, int doesn't support cell paths). The single closure (record-check AND safe `get -o name` read, combined) tolerates non-record entries by short-circuiting the `and` before ever reading `.name` on them — falls through to the same 'not found in marketplace' message as an empty plugins list, since no record matches"
    }
    {
      name: "cli_marketplace_plugins_nameless_record_exit_1"
      args: ["somename", "--marketplace", $cli_plugins_nameless_record_marketplace_path]
      expect_exit: 1
      expect_output_contains: "not found in marketplace"
      why: "claude-skills-247 Gate 3 ROUND 2 — a SIXTH crash shape, found on the exact line round 1 rewrote: {\"plugins\": [{\"foo\": 1}]} is a genuine RECORD (round 1's record-only filter would have let it through), but has no 'name' key. Verified directly, independent of the non-record shapes: `[{foo: 1}] | where name == \"x\"` raises column_not_found — nushell does NOT silently skip a record missing the compared column. The fix reads `name` via `get -o` (returns null, doesn't raise) INSIDE the same closure that checks record-ness, so a nameless record is excluded by the comparison itself rather than by a separate pre-filter that only checked the wrong thing"
    }
    {
      name: "cli_marketplace_plugins_nameless_then_valid_exit_0"
      args: ["target-plugin", "--marketplace", $cli_plugins_nameless_then_valid_marketplace_path]
      expect_exit: 0
      why: "claude-skills-247 Gate 3 round 2 — proves the filter genuinely SKIPS the nameless record and keeps evaluating the rest of the list, rather than aborting on the first bad entry: a nameless record ({foo: 1}) is followed by a valid, matching target-plugin entry (self-contained fixture, own plugin dir), and the whole marketplace lookup must still succeed end to end"
    }
    {
      name: "cli_marketplace_plugin_not_found_exit_1"
      args: ["missing-plugin", "--marketplace", $cli_empty_marketplace_path]
      expect_exit: 1
      expect_output_contains: "not found in marketplace"
      why: "validate-from-marketplace's plugin-not-in-marketplace branch"
    }
    {
      name: "cli_marketplace_valid_local_plugin_exit_0"
      args: ["my-plugin", "--marketplace", $cli_marketplace_path]
      expect_exit: 0
      why: "validate-from-marketplace's local-source success path, end to end through main"
    }
    {
      name: "cli_marketplace_description_mismatch_exit_1"
      args: ["desc-mismatch-plugin", "--marketplace", $cli_marketplace_path]
      expect_exit: 1
      expect_output_contains: "description mismatch"
      why: "claude-skills-238 Gate 3 finding — the description-agreement check (claude-skills-170, validate-plugin.nu's has_marketplace_context block around the pj_description comparison) had zero reject-direction coverage; neutering that block to `if false` left the pre-fix suite green"
    }
    {
      name: "cli_marketplace_keywords_mismatch_exit_1"
      args: ["keywords-mismatch-plugin", "--marketplace", $cli_marketplace_path]
      expect_exit: 1
      expect_output_contains: "keywords mismatch"
      why: "claude-skills-238 Gate 3 finding — same gap for the keywords-agreement check's has_marketplace_context block"
    }
    {
      name: "cli_marketplace_unsupported_external_source_exit_1"
      args: ["external-plugin", "--marketplace", $cli_marketplace_path]
      expect_exit: 1
      expect_output_contains: "Unsupported external source format"
      why: "setup-external-plugin's non-github-object branch — the one setup-external-plugin path reachable without a live git clone"
    }
  ]

  for c in $cli_cases {
    let result = (do { ^nu $self_path ...$c.args } | complete)
    if $result.exit_code != $c.expect_exit {
      $failures = ($failures | append $"($c.name): expected exit ($c.expect_exit), got ($result.exit_code) -- ($c.why)")
    }
    let expect_contains = ($c | get -o expect_output_contains)
    if ($expect_contains != null) and not ($result.stdout | str contains $expect_contains) {
      $failures = ($failures | append $"($c.name): expected stdout to contain '($expect_contains)', got: ($result.stdout) -- ($c.why)")
    }
  }

  rm -rf $cli_temp_dir

  rm -rf $temp_dir

  if ($failures | length) > 0 {
    print $"(ansi red_bold)❌ validate-plugin.nu self-test failed:(ansi reset)"
    for f in $failures {
      print $"  - ($f)"
    }
    exit 1
  }

  let total_cases = ($cases | length) + ($agent_model_cases | length) + ($skill_md_cases | length) + ($agent_md_cases | length) + ($cleanup_temp_cases | length) + ($array_path_cases | length) + ($cli_cases | length)
  print $"(ansi green_bold)✅ validate-plugin.nu self-test passed \(($total_cases) cases\)(ansi reset)"
}
