#!/usr/bin/env nu

# Validate plugin dependencies in marketplace.json
#
# Usage: nu validate-dependencies.nu <path-to-marketplace.json>

def main [
  marketplace_path: string  # Path to marketplace.json file
] {
  print $"(ansi green_bold)Validating dependencies:(ansi reset) ($marketplace_path)"
  print ""

  if not ($marketplace_path | path exists) {
    print $"(ansi red_bold)Error:(ansi reset) File not found: ($marketplace_path)"
    exit 1
  }

  let marketplace = try {
    open $marketplace_path
  } catch {
    print $"(ansi red_bold)Error:(ansi reset) Invalid JSON syntax"
    exit 1
  }

  if ($marketplace | get -i plugins) == null {
    print $"(ansi red_bold)Error:(ansi reset) No plugins array found"
    exit 1
  }

  mut errors = []
  mut warnings = []

  # Build plugin name set
  let plugin_names = $marketplace.plugins | each { |p| $p.name } | uniq

  # Check each plugin's dependencies
  for plugin in $marketplace.plugins {
    if ($plugin | get -i dependencies) == null {
      continue
    }

    for dep in $plugin.dependencies {
      # Parse namespace:plugin-name format
      let parts = $dep | split row ":"
      let dep_name = if ($parts | length) > 1 {
        $parts.1
      } else {
        $dep
      }

      # Check if dependency exists
      if $dep_name not-in $plugin_names {
        $errors = ($errors | append $"Plugin '($plugin.name)' depends on '($dep)' which is not in marketplace")
      }
    }
  }

  # Check for circular dependencies
  print $"(ansi cyan)Checking for circular dependencies...(ansi reset)"

  for plugin in $marketplace.plugins {
    if ($plugin | get -i dependencies) != null {
      let circular = find-circular-deps $marketplace.plugins $plugin.name []
      if ($circular | length) > 0 {
        $errors = ($errors | append $"Circular dependency detected: ($circular | str join ' -> ')")
      }
    }
  }

  # Print results
  print ""
  print $"(ansi cyan_bold)Dependency Validation Results:(ansi reset)"
  print $"  Total plugins: (($plugin_names | length))"
  print $"  Errors: (($errors | length))"
  print $"  Warnings: (($warnings | length))"

  if ($errors | length) > 0 {
    print ""
    print $"(ansi red_bold)Errors:(ansi reset)"
    for error in $errors {
      print $"  ✗ ($error)"
    }
    exit 1
  }

  if ($warnings | length) > 0 {
    print ""
    print $"(ansi yellow_bold)Warnings:(ansi reset)"
    for warning in $warnings {
      print $"  ⚠ ($warning)"
    }
  }

  print ""
  print $"(ansi green_bold)✓ Dependencies are valid!(ansi reset)"
}

# Find circular dependencies recursively
def find-circular-deps [
  plugins: list
  current: string
  visited: list
]: list {
  if $current in $visited {
    return ($visited | append $current)
  }

  let plugin = $plugins | where name == $current | first

  if ($plugin | get -i dependencies) == null {
    return []
  }

  let new_visited = $visited | append $current

  for dep in $plugin.dependencies {
    let parts = $dep | split row ":"
    let dep_name = if ($parts | length) > 1 { $parts.1 } else { $dep }

    let circular = find-circular-deps $plugins $dep_name $new_visited
    if ($circular | length) > 0 {
      return $circular
    }
  }

  []
}
