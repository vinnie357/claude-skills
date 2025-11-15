#!/usr/bin/env nu

# Validate Claude Code marketplace.json file
#
# Usage: nu validate-marketplace.nu <path-to-marketplace.json> [--verbose]

def main [
  marketplace_path: string  # Path to marketplace.json file
  --verbose                 # Show detailed validation output
] {
  print $"(ansi green_bold)Validating marketplace:(ansi reset) ($marketplace_path)"
  print ""

  # Check if file exists
  if not ($marketplace_path | path exists) {
    print $"(ansi red_bold)Error:(ansi reset) File not found: ($marketplace_path)"
    exit 1
  }

  # Parse JSON
  let marketplace = try {
    open $marketplace_path
  } catch {
    print $"(ansi red_bold)Error:(ansi reset) Invalid JSON syntax in ($marketplace_path)"
    exit 1
  }

  mut errors = []
  mut warnings = []

  # Validate required top-level fields
  print $"(ansi cyan)Checking required fields...(ansi reset)"

  if ($marketplace | get -o name) == null {
    $errors = ($errors | append "Missing required field: 'name'")
  } else {
    let name = $marketplace.name
    if not (is-kebab-case $name) {
      $errors = ($errors | append $"Invalid name format: '($name)' (must be kebab-case)")
    } else if $verbose {
      print $"  ✓ name: ($name)"
    }
  }

  if ($marketplace | get -o owner) == null {
    $errors = ($errors | append "Missing required field: 'owner'")
  } else {
    let owner = $marketplace.owner
    if ($owner | get -o name) == null {
      $errors = ($errors | append "Missing required field: 'owner.name'")
    } else if $verbose {
      print $"  ✓ owner.name: ($owner.name)"
    }

    if ($owner | get -o email) != null and $verbose {
      print $"  ✓ owner.email: ($owner.email)"
    }
  }

  if ($marketplace | get -o plugins) == null {
    $errors = ($errors | append "Missing required field: 'plugins' (can be empty array)")
  } else if not (($marketplace.plugins | describe) starts-with "list") {
    $errors = ($errors | append "'plugins' must be an array")
  } else if $verbose {
    print $"  ✓ plugins: (($marketplace.plugins | length)) entries"
  }

  # Validate optional metadata
  if ($marketplace | get -o metadata) != null {
    print ""
    print $"(ansi cyan)Checking optional metadata...(ansi reset)"

    let metadata = $marketplace.metadata

    if ($metadata | get -o description) != null and $verbose {
      print $"  ✓ metadata.description: ($metadata.description)"
    }

    if ($metadata | get -o version) != null {
      if not (is-semver $metadata.version) {
        $warnings = ($warnings | append $"metadata.version should use semantic versioning: ($metadata.version)")
      } else if $verbose {
        print $"  ✓ metadata.version: ($metadata.version)"
      }
    }

    if ($metadata | get -o pluginRoot) != null and $verbose {
      print $"  ✓ metadata.pluginRoot: ($metadata.pluginRoot)"
    }
  }

  # Validate plugin entries
  if ($marketplace | get -o plugins) != null and (($marketplace.plugins | length) > 0) {
    print ""
    print $"(ansi cyan)Validating plugin entries...(ansi reset)"

    # Base dir is .claude-plugin directory, repo root is one level up
    let base_dir = $marketplace_path | path dirname
    let repo_root = $base_dir | path dirname
    let plugin_root = if ($marketplace | get -o metadata.pluginRoot) != null {
      $marketplace.metadata.pluginRoot
    } else {
      ""
    }

    for plugin in $marketplace.plugins {
      let plugin_name = if ($plugin | get -o name) != null { $plugin.name } else { "<unnamed>" }

      if $verbose {
        print $"  Checking plugin: ($plugin_name)"
      }

      # Validate required fields
      if ($plugin | get -o name) == null {
        $errors = ($errors | append $"Plugin entry missing required field: 'name'")
      } else if not (is-kebab-case $plugin.name) {
        $errors = ($errors | append $"Invalid plugin name: '($plugin.name)' (must be kebab-case)")
      }

      if ($plugin | get -o source) == null {
        $errors = ($errors | append $"Plugin '($plugin_name)' missing required field: 'source'")
      } else {
        # Validate source path if it's a string (relative path)
        if ($plugin.source | describe) == "string" {
          let source_path = if ($plugin_root | is-empty) {
            $plugin.source
          } else {
            $"($plugin_root)/($plugin.source)"
          }

          # Plugin source paths are relative to the repository root, not .claude-plugin dir
          let full_path = $"($repo_root)/($source_path)" | path expand
          if not ($full_path | path exists) {
            $warnings = ($warnings | append $"Plugin '($plugin_name)' source path not found: ($full_path)")
          } else if $verbose {
            print $"    ✓ source path exists: ($source_path)"
          }
        } else if ($plugin.source | describe) == "record" {
          # Validate source object
          let source_type = $plugin.source | get -o source
          if $source_type == null {
            $errors = ($errors | append $"Plugin '($plugin_name)' source object missing 'source' field")
          } else if $source_type not-in ["github", "url"] {
            $errors = ($errors | append $"Plugin '($plugin_name)' invalid source type: ($source_type)")
          } else if $verbose {
            print $"    ✓ source type: ($source_type)"
          }
        }
      }

      # Validate strict mode
      if ($plugin | get -o strict) != null {
        if ($plugin.strict | describe) != "bool" {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'strict' must be boolean")
        } else if $verbose {
          print $"    ✓ strict: ($plugin.strict)"
        }
      }

      # Validate marketplace-specific fields
      if ($plugin | get -o category) != null {
        if ($plugin.category | describe) != "string" {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'category' must be a string")
        } else if $verbose {
          print $"    ✓ category: ($plugin.category)"
        }
      }

      if ($plugin | get -o tags) != null {
        if not (($plugin.tags | describe) starts-with "list") {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'tags' must be an array")
        } else if $verbose {
          print $"    ✓ tags: (($plugin.tags | length)) entries"
        }
      }

      # Validate optional standard metadata fields
      if ($plugin | get -o version) != null and not (is-semver $plugin.version) {
        $warnings = ($warnings | append $"Plugin '($plugin_name)' version should use semantic versioning: ($plugin.version)")
      }

      if ($plugin | get -o author) != null {
        if ($plugin.author | describe) != "record" {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'author' must be an object")
        } else if ($plugin.author | get -o name) == null {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'author.name' is required when author is specified")
        } else if $verbose {
          print $"    ✓ author: ($plugin.author.name)"
        }
      }

      if ($plugin | get -o homepage) != null {
        if ($plugin.homepage | describe) != "string" {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'homepage' must be a string")
        } else if not (is-url $plugin.homepage) {
          $warnings = ($warnings | append $"Plugin '($plugin_name)' 'homepage' should be a valid URL: ($plugin.homepage)")
        } else if $verbose {
          print $"    ✓ homepage: ($plugin.homepage)"
        }
      }

      if ($plugin | get -o repository) != null {
        if ($plugin.repository | describe) != "string" {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'repository' must be a string")
        } else if not (is-url $plugin.repository) {
          $warnings = ($warnings | append $"Plugin '($plugin_name)' 'repository' should be a valid URL: ($plugin.repository)")
        } else if $verbose {
          print $"    ✓ repository: ($plugin.repository)"
        }
      }

      if ($plugin | get -o license) != null {
        if ($plugin.license | describe) != "string" {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'license' must be a string")
        } else if $verbose {
          print $"    ✓ license: ($plugin.license)"
        }
      }

      if ($plugin | get -o keywords) != null {
        if not (($plugin.keywords | describe) starts-with "list") {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'keywords' must be an array")
        } else if $verbose {
          print $"    ✓ keywords: (($plugin.keywords | length)) entries"
        }
      }

      # Validate component configuration fields
      if ($plugin | get -o commands) != null {
        let cmd_type = $plugin.commands | describe
        if $cmd_type != "string" and not ($cmd_type starts-with "list") {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'commands' must be a string or array")
        } else if $verbose {
          if $cmd_type starts-with "list" {
            print $"    ✓ commands: (($plugin.commands | length)) entries"
          } else {
            print $"    ✓ commands: ($plugin.commands)"
          }
        }
      }

      if ($plugin | get -o agents) != null {
        let agent_type = $plugin.agents | describe
        if $agent_type != "string" and not ($agent_type starts-with "list") {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'agents' must be a string or array")
        } else if $verbose {
          if $agent_type starts-with "list" {
            print $"    ✓ agents: (($plugin.agents | length)) entries"
          } else {
            print $"    ✓ agents: ($plugin.agents)"
          }
        }
      }

      if ($plugin | get -o hooks) != null {
        let hooks_type = $plugin.hooks | describe
        if $hooks_type not-in ["string", "record"] {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'hooks' must be a string or object")
        } else if $verbose {
          print $"    ✓ hooks: ($hooks_type)"
        }
      }

      if ($plugin | get -o mcpServers) != null {
        let mcp_type = $plugin.mcpServers | describe
        if $mcp_type not-in ["string", "record"] {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'mcpServers' must be a string or object")
        } else if $verbose {
          print $"    ✓ mcpServers: ($mcp_type)"
        }
      }

      if ($plugin | get -o dependencies) != null {
        if not (($plugin.dependencies | describe) starts-with "list") {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'dependencies' must be an array")
        } else if $verbose {
          print $"    ✓ dependencies: (($plugin.dependencies | length)) entries"
        }
      }

      # Validate skills array if present
      if ($plugin | get -o skills) != null {
        if not (($plugin.skills | describe) starts-with "list") {
          $errors = ($errors | append $"Plugin '($plugin_name)' 'skills' must be an array")
        } else if $verbose {
          print $"    ✓ skills: (($plugin.skills | length)) entries"
        }
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
    print $"(ansi green_bold)✓ Marketplace is valid!(ansi reset)"
    exit 0
  } else if ($errors | length) > 0 {
    print ""
    print $"(ansi red_bold)✗ Validation failed with (($errors | length)) error\(s\)(ansi reset)"
    exit 1
  } else {
    print ""
    let warning_text = if ($warnings | length) == 1 { "warning" } else { "warnings" }
    print $"(ansi yellow_bold)⚠ Validation passed with (($warnings | length)) ($warning_text)(ansi reset)"
    exit 0
  }
}

# Check if string is kebab-case (lowercase alphanumeric and hyphens only)
def is-kebab-case [name: string] {
  $name =~ '^[a-z0-9]+(-[a-z0-9]+)*$'
}

# Check if string is semantic version
def is-semver [version: string] {
  $version =~ '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$'
}

# Check if string is a valid URL
def is-url [url: string] {
  $url =~ '^https?://.+'
}
