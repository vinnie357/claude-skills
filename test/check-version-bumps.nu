#!/usr/bin/env nu

# Check that modified plugins have version bumps
#
# Usage:
#   nu check-version-bumps.nu [--base main]
#
# Compares current branch to base branch and ensures any plugin
# with file changes also has a version bump in both:
#   - <plugin-dir>/.claude-plugin/plugin.json
#   - .claude-plugin/marketplace.json

def main [
  --base: string = "main"  # Base branch to compare against
] {
  print $"🔍 Checking version bumps against ($base)...\n"

  # Get list of changed files
  let changed_files = (git diff --name-only $"($base)...HEAD" | lines | where { |f| ($f | str length) > 0 })

  if ($changed_files | length) == 0 {
    print "✅ No files changed"
    exit 0
  }

  # Build plugin mapping from marketplace.json (name → dir)
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

  if ($plugins | length) == 0 {
    print "✅ No plugin directories modified"
    exit 0
  }

  print $"📦 Modified plugins: ($plugins | each { |p| $p.name } | str join ', ')\n"

  # Check each plugin for version bump
  mut errors = []

  for plugin in $plugins {
    let result = check-plugin-version-bump $plugin.name $plugin.dir $base
    if not $result.bumped {
      $errors = ($errors | append $result.error)
    }
  }

  # Report results
  if ($errors | length) > 0 {
    print $"\n(ansi red_bold)❌ Version bump check failed:(ansi reset)\n"
    for error in $errors {
      print $"  • ($error)"
    }
    print $"\n(ansi yellow)Hint: Bump the version in both:(ansi reset)"
    print "  1. <plugin-dir>/.claude-plugin/plugin.json"
    print "  2. .claude-plugin/marketplace.json"
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

# Check if a plugin has a version bump compared to base
def check-plugin-version-bump [plugin_name: string, plugin_dir: string, base: string] {
  let plugin_json_path = $"($plugin_dir)/.claude-plugin/plugin.json"
  let marketplace_path = ".claude-plugin/marketplace.json"

  # Get base version from plugin.json
  let base_plugin_version = try {
    git show $"($base):($plugin_json_path)" | from json | get version
  } catch {
    # Plugin might be new, so no base version
    return { bumped: true, error: "" }
  }

  # Get current version from plugin.json
  let current_plugin_version = try {
    open $plugin_json_path | get version
  } catch {
    return { bumped: false, error: $"($plugin_name): Cannot read plugin.json version" }
  }

  # Check plugin.json version bump
  if $current_plugin_version == $base_plugin_version {
    return {
      bumped: false,
      error: $"($plugin_name): plugin.json version not bumped \(still ($base_plugin_version)\)"
    }
  }

  # Get base marketplace version for this plugin
  let base_marketplace_version = try {
    let marketplace = (git show $"($base):($marketplace_path)" | from json)
    $marketplace.plugins | where name == $plugin_name | first | get version
  } catch {
    return { bumped: true, error: "" }  # New plugin in marketplace
  }

  # Get current marketplace version for this plugin
  let current_marketplace_version = try {
    let marketplace = (open $marketplace_path)
    $marketplace.plugins | where name == $plugin_name | first | get version
  } catch {
    return { bumped: false, error: $"($plugin_name): Cannot find in marketplace.json" }
  }

  # Check marketplace version bump
  if $current_marketplace_version == $base_marketplace_version {
    return {
      bumped: false,
      error: $"($plugin_name): marketplace.json version not bumped \(still ($base_marketplace_version)\)"
    }
  }

  # Check versions match
  if $current_plugin_version != $current_marketplace_version {
    return {
      bumped: false,
      error: $"($plugin_name): Version mismatch - plugin.json=($current_plugin_version), marketplace.json=($current_marketplace_version)"
    }
  }

  print $"  ✓ ($plugin_name): ($base_plugin_version) → ($current_plugin_version)"
  { bumped: true, error: "" }
}
