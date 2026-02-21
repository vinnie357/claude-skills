#!/usr/bin/env nu

# Analyze existing plugin structure and suggest marketplace configuration
#
# Usage: nu analyze-plugins.nu <directory>

def main [
  directory: string = "."  # Directory to analyze
] {
  print $"(ansi green_bold)Analyzing plugins in:(ansi reset) ($directory)"
  print ""

  # Find all plugin.json files
  let plugin_files = glob $"($directory)/**/plugin.json"
    | where { |f| ($f | str contains ".claude-plugin") }

  if ($plugin_files | length) == 0 {
    print $"(ansi yellow)No plugin.json files found(ansi reset)"
    exit 0
  }

  print $"(ansi cyan)Found ($plugin_files | length) plugin(s):(ansi reset)"
  print ""

  mut suggested_plugins = []

  for file in $plugin_files {
    let plugin = open $file
    let plugin_dir = $file | path dirname | path dirname
    let rel_path = $plugin_dir | path relative-to $directory

    print $"  Plugin: ($plugin.name)"
    print $"    Path: ($rel_path)"
    print $"    Version: (($plugin | get -i version) // 'not specified')"

    # Count skills
    let skill_count = if ($plugin | get -i skills) != null {
      $plugin.skills | length
    } else {
      0
    }
    print $"    Skills: ($skill_count)"

    # Count commands
    let cmd_count = if ($plugin | get -i commands) != null {
      $plugin.commands | length
    } else {
      0
    }
    print $"    Commands: ($cmd_count)"
    print ""

    # Build suggested entry
    let entry = {
      name: $plugin.name
      source: $"./(($rel_path))"
      strict: true
      description: (($plugin | get -i description) // "Add description here")
      version: (($plugin | get -i version) // "1.0.0")
      category: "development"
      keywords: []
    }

    $suggested_plugins = ($suggested_plugins | append $entry)
  }

  # Generate suggested marketplace.json
  print $"(ansi cyan_bold)Suggested marketplace.json structure:(ansi reset)"
  print ""

  let suggested = {
    name: "your-marketplace-name"
    owner: {
      name: "Your Name"
      email: "you@example.com"
    }
    metadata: {
      description: "Add marketplace description"
      version: "1.0.0"
      pluginRoot: "./plugins"
    }
    plugins: $suggested_plugins
  }

  print ($suggested | to json -i 2)
  print ""
  print $"(ansi green)Save this to .claude-plugin/marketplace.json and customize as needed(ansi reset)"
}
