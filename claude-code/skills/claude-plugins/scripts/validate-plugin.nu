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
  target: string              # Path to plugin.json OR plugin name (when using --marketplace)
  --marketplace: string       # Path to marketplace.json (enables name-based lookup)
  --verbose                   # Show detailed validation output
] {
  # Determine mode based on --marketplace flag
  if ($marketplace | is-not-empty) {
    validate-from-marketplace $target $marketplace $verbose
  } else {
    validate-plugin-file $target $verbose
  }
}

# Validate a plugin by name from marketplace
def validate-from-marketplace [plugin_name: string, marketplace_path: string, verbose: bool] {
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
  let is_external = not (($source | str starts-with "./") or ($source == "./"))

  # Set up validation context
  let validation_context = if $is_external {
    setup-external-plugin $source $plugin_name
  } else {
    { plugin_root: $marketplace_dir, temp_dir: "", is_external: false }
  }

  let plugin_root = $validation_context.plugin_root
  let temp_dir = $validation_context.temp_dir
  let is_ext = $validation_context.is_external

  # Determine plugin.json path
  let plugin_path = if $plugin_name == "all-skills" {
    ($plugin_root | path join ".claude-plugin" "plugin.json")
  } else if $is_ext {
    ($plugin_root | path join ".claude-plugin" "plugin.json")
  } else {
    ($plugin_root | path join $plugin_name ".claude-plugin" "plugin.json")
  }

  # Check if plugin.json exists
  if not ($plugin_path | path exists) {
    print $"(ansi red_bold)Error:(ansi reset) plugin.json not found at ($plugin_path)"
    cleanup-temp $temp_dir $is_ext
    exit 1
  }

  # Run validation
  let result = validate-plugin-content $plugin_path $plugin_root $plugin_name $is_ext $verbose

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
def validate-plugin-file [plugin_path: string, verbose: bool] {
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

  let result = validate-plugin-content $plugin_path $plugin_root $plugin_name false $verbose

  if $result.success {
    print $"\n(ansi green_bold)✓ Plugin is valid!(ansi reset)"
    exit 0
  } else {
    exit 1
  }
}

# Set up external plugin (clone from GitHub)
def setup-external-plugin [source: string, plugin_name: string] {
  if ($source | str starts-with "github:") {
    let repo_path = ($source | str replace "github:" "")
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
  is_external: bool
  verbose: bool
] {
  let plugin = try {
    open $plugin_path
  } catch {
    print $"(ansi red_bold)Error:(ansi reset) Failed to parse plugin.json"
    return { success: false }
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
    if not ($name =~ '^[a-z0-9]+(-[a-z0-9]+)*$') {
      $errors = ($errors | append $"Invalid name format: '($name)' (must be kebab-case)")
    }

    # Verify name matches expected
    if $name != $plugin_name {
      $errors = ($errors | append $"Name mismatch - expected '($plugin_name)', got '($name)'")
    } else if $verbose {
      print $"  ✓ name: ($name)"
    }
  }

  # Check for invalid fields (marketplace-only)
  print $"\n(ansi cyan)Checking for invalid fields...(ansi reset)"
  let invalid_fields = ["dependencies", "category", "strict", "source", "tags"]
  for field in $invalid_fields {
    if ($plugin | get -o $field) != null {
      $errors = ($errors | append $"Invalid field '($field)' - this belongs in marketplace.json, not plugin.json")
    }
  }

  if $verbose {
    print "  ✓ No invalid fields found"
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

  # Check for skills/sources.md (recommended for plugins with skills)
  if not $is_external and ($plugin | get -o skills) != null {
    let sources_path = if $plugin_name == "all-skills" {
      ($plugin_root | path join "skills" "sources.md")
    } else {
      ($plugin_root | path join $plugin_name "skills" "sources.md")
    }
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
          ($plugin_root | path join $plugin_name $skill)
        }

        if not ($skill_path | path exists) {
          $warnings = ($warnings | append $"Skill path not found: ($skill)")
        } else {
          let skill_md = ($skill_path | path join "SKILL.md")
          if not ($skill_md | path exists) {
            $errors = ($errors | append $"Skill directory '($skill)' missing SKILL.md file")
          } else if $verbose {
            print $"  ✓ ($skill)"
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
          ($plugin_root | path join $plugin_name $command)
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
          ($plugin_root | path join $plugin_name $agent)
        }

        if not ($agent_path | path exists) {
          $warnings = ($warnings | append $"Agent path not found: ($agent)")
        } else if $verbose {
          print $"  ✓ ($agent)"
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
    { success: false }
  } else if ($warnings | length) > 0 {
    print $"\n(ansi yellow_bold)⚠ Validation passed with (($warnings | length)) warnings(ansi reset)"
    { success: true }
  } else {
    { success: true }
  }
}

# Check if string is kebab-case
def is-kebab-case [name: string] {
  $name =~ '^[a-z0-9]+(-[a-z0-9]+)*$'
}

# Check if string is semantic version
def is-semver [version: string] {
  $version =~ '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$'
}
