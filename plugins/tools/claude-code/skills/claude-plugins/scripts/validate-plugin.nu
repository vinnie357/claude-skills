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

  let marketplace = (open $marketplace_path)
  let marketplace_dir = ($marketplace_path | path dirname | path dirname)

  # Find plugin entry
  let plugin_entry = ($marketplace.plugins | where name == $plugin_name | first)
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
    if $skills_type == "nothing" {
      $errors = ($errors | append "skills field must be an array or omitted entirely (not null)")
    } else if not ($skills_type | str starts-with "list") {
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
          if not ($skill_md | path exists) {
            $errors = ($errors | append $"Skill directory '($skill)' missing SKILL.md file")
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
    if $commands_type == "nothing" {
      $errors = ($errors | append "commands field must be an array or omitted entirely (not null)")
    } else if not ($commands_type | str starts-with "list") {
      $errors = ($errors | append $"commands must be an array, got ($commands_type)")
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
    if $agents_type == "nothing" {
      $errors = ($errors | append "agents field must be an array or omitted entirely (not null)")
    } else if not ($agents_type | str starts-with "list") {
      $errors = ($errors | append $"agents must be an array, got ($agents_type)")
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
  let frontmatter = ($yaml_lines | from yaml)

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
  let frontmatter = ($yaml_lines | from yaml)

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
      name: "plugin_name_bad_kebab_case_errors"
      why: "claude-skills-238 — is-kebab-case (the plugin.json top-level 'name' field) had zero fixture coverage of the reject direction; every existing case uses a valid kebab-case name. Also exercises the is-kebab-case helper now that it's wired into this call site instead of a duplicated inline regex"
      plugin: { name: "My_Plugin", version: "1.0.0", description: "test fixture", license: "MIT" }
      expect_errors: 2  # invalid name format, AND name mismatch (fixture always passes plugin_name="my-plugin" as expected — see the loop below)
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
      why: "tools must be a comma-separated string, not a YAML array — the bee's own 'tools given as a YAML list' example"
    }
    {
      name: "tools_wrong_type"
      content: "---\nname: my-agent\ndescription: test fixture\ntools: 42\n---\n\nbody\n"
      expect_errors: 1
      why: "tools must be a string; a bare number is neither the list-shape nor the string-shape branch"
    }
  ]
  let agent_md_temp_dir = (mktemp -d)
  for c in $agent_md_cases {
    let agent_md_path = ($agent_md_temp_dir | path join $"($c.name).md")
    $c.content | save --force $agent_md_path
    let result = (validate-agent-md $agent_md_path "fixture-agent" false)
    if ($result.errors | length) != $c.expect_errors {
      $failures = ($failures | append $"agent_md_($c.name): expected ($c.expect_errors) errors, got (($result.errors | length)): ($result.errors | to nuon) -- ($c.why)")
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

  let cli_invalid_json_path = ($cli_temp_dir | path join "invalid.json")
  # "not valid json {{{" is NOT actually invalid per nu's own `from json`,
  # which accepts a JSON5-style bare "quoteless string" and returns it
  # unchanged (`"not valid json {{{" | from json | describe` => "string") —
  # verified directly, this made the try/catch in validate-plugin-file a
  # silent no-op and the case failed on the wrong assertion. A truncated
  # object is genuinely unparseable to nu's JSON parser (verified: raises
  # `nu::shell::error` / "EOF while parsing an object").
  "{\"name\": \"broken\"" | save --force $cli_invalid_json_path

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
    ]
  } | save --force $cli_marketplace_path

  let cli_empty_marketplace_path = ($cli_temp_dir | path join "empty-marketplace.json")
  { name: "fixture-marketplace", owner: { name: "fixture" }, plugins: [] } | save --force $cli_empty_marketplace_path

  let cli_cases = [
    {
      name: "cli_valid_plugin_file_exit_0"
      args: [($cli_plugin_dir | path join ".claude-plugin" "plugin.json")]
      expect_exit: 0
      why: "validate-plugin-file's success path — main + validate-plugin-file together"
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

  let total_cases = ($cases | length) + ($agent_model_cases | length) + ($skill_md_cases | length) + ($agent_md_cases | length) + ($cleanup_temp_cases | length) + ($cli_cases | length)
  print $"(ansi green_bold)✅ validate-plugin.nu self-test passed \(($total_cases) cases\)(ansi reset)"
}
