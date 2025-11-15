#!/usr/bin/env nu

# Validate Claude Code plugin.json file
#
# Usage: nu validate-plugin.nu <path-to-plugin.json> [--verbose]

def main [
  plugin_path: string  # Path to plugin.json file
  --verbose            # Show detailed validation output
] {
  print $"(ansi green_bold)Validating plugin:(ansi reset) ($plugin_path)"
  print ""

  # Check if file exists
  if not ($plugin_path | path exists) {
    print $"(ansi red_bold)Error:(ansi reset) File not found: ($plugin_path)"
    exit 1
  }

  # Parse JSON
  let plugin = try {
    open $plugin_path
  } catch {
    print $"(ansi red_bold)Error:(ansi reset) Invalid JSON syntax in ($plugin_path)"
    exit 1
  }

  mut errors = []
  mut warnings = []

  # Validate required fields
  print $"(ansi cyan)Checking required fields...(ansi reset)"

  if ($plugin | get -o name) == null {
    $errors = ($errors | append "Missing required field: 'name'")
  } else {
    let name = $plugin.name
    if not (is-kebab-case $name) {
      $errors = ($errors | append $"Invalid name format: '($name)' (must be kebab-case)")
    } else if $verbose {
      print $"  ✓ name: ($name)"
    }
  }

  # Validate optional fields
  if ($plugin | get -o version) != null {
    if not (is-semver $plugin.version) {
      $warnings = ($warnings | append $"version should use semantic versioning: ($plugin.version)")
    } else if $verbose {
      print $"  ✓ version: ($plugin.version)"
    }
  } else if $verbose {
    print $"  ⚠ version not specified (recommended)"
  }

  if ($plugin | get -o description) != null and $verbose {
    print $"  ✓ description: ($plugin.description)"
  }

  # Check for invalid fields
  print ""
  print $"(ansi cyan)Checking for invalid fields...(ansi reset)"

  let invalid_fields = ["dependencies", "category", "strict", "source", "tags"]
  for field in $invalid_fields {
    if ($plugin | get -o $field) != null {
      $errors = ($errors | append $"Invalid field '($field)' - this belongs in marketplace.json, not plugin.json")
    }
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

  # Validate skills array
  if ($plugin | get -o skills) != null {
    if ($plugin.skills | describe) != "list" {
      $errors = ($errors | append "'skills' must be an array")
    } else {
      print ""
      print $"(ansi cyan)Validating skills...(ansi reset)"

      let base_dir = $plugin_path | path dirname | path dirname
      for skill_path in $plugin.skills {
        let full_path = $"($base_dir)/($skill_path)" | path expand
        if not ($full_path | path exists) {
          $warnings = ($warnings | append $"Skill path not found: ($skill_path)")
        } else {
          let skill_md = $"($full_path)/SKILL.md"
          if not ($skill_md | path exists) {
            $errors = ($errors | append $"Skill directory '($skill_path)' missing SKILL.md file")
          } else if $verbose {
            print $"  ✓ ($skill_path)"
          }
        }
      }

      if $verbose {
        print $"  Total skills: (($plugin.skills | length))"
      }
    }
  }

  # Validate keywords
  if ($plugin | get -o keywords) != null {
    if ($plugin.keywords | describe) != "list" {
      $errors = ($errors | append "'keywords' must be an array")
    } else if $verbose {
      print ""
      print $"(ansi cyan)Keywords:(ansi reset) (($plugin.keywords | length)) entries"
    }
  }

  # Validate commands
  if ($plugin | get -o commands) != null {
    print ""
    print $"(ansi cyan)Validating commands...(ansi reset)"

    let commands = if ($plugin.commands | describe) == "string" {
      [$plugin.commands]
    } else if ($plugin.commands | describe) == "list" {
      $plugin.commands
    } else {
      $errors = ($errors | append "'commands' must be a string or array")
      []
    }

    let base_dir = $plugin_path | path dirname | path dirname
    for cmd_path in $commands {
      let full_path = $"($base_dir)/($cmd_path)" | path expand
      if not ($full_path | path exists) {
        $warnings = ($warnings | append $"Command path not found: ($cmd_path)")
      } else if $verbose {
        print $"  ✓ ($cmd_path)"
      }
    }
  }

  # Print results
  print ""
  print $"(ansi cyan_bold)Validation Results:(ansi reset)"
  print $"  Errors: (($errors | length))"
  print $"  Warnings: (($warnings | length))"

  if ($errors | length) > 0 {
    print ""
    print $"(ansi red_bold)Errors:(ansi reset)"
    for error in $errors {
      print $"  ✗ ($error)"
    }
  }

  if ($warnings | length) > 0 {
    print ""
    print $"(ansi yellow_bold)Warnings:(ansi reset)"
    for warning in $warnings {
      print $"  ⚠ ($warning)"
    }
  }

  if ($errors | length) == 0 and ($warnings | length) == 0 {
    print ""
    print $"(ansi green_bold)✓ Plugin is valid!(ansi reset)"
    exit 0
  } else if ($errors | length) > 0 {
    print ""
    print $"(ansi red_bold)✗ Validation failed with (($errors | length)) errors(ansi reset)"
    exit 1
  } else {
    print ""
    print $"(ansi yellow_bold)⚠ Validation passed with (($warnings | length)) warnings(ansi reset)"
    exit 0
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
