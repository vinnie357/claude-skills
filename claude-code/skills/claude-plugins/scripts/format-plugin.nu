#!/usr/bin/env nu

# Format and sort plugin.json file
#
# Usage: nu format-plugin.nu <path-to-plugin.json>

def main [
  plugin_path: string  # Path to plugin.json file
] {
  if not ($plugin_path | path exists) {
    print $"(ansi red_bold)Error:(ansi reset) File not found: ($plugin_path)"
    exit 1
  }

  let plugin = try {
    open $plugin_path
  } catch {
    print $"(ansi red_bold)Error:(ansi reset) Invalid JSON syntax"
    exit 1
  }

  # Sort keywords and skills alphabetically
  let sorted_keywords = if ($plugin | get -o keywords) != null {
    $plugin.keywords | sort
  } else {
    null
  }

  let sorted_skills = if ($plugin | get -o skills) != null {
    $plugin.skills | sort
  } else {
    null
  }

  # Rebuild plugin with sorted arrays
  let formatted = {
    name: $plugin.name
    version: (if ($plugin | get -o version) != null { $plugin.version } else { null })
    description: (if ($plugin | get -o description) != null { $plugin.description } else { null })
    author: (if ($plugin | get -o author) != null { $plugin.author } else { null })
    homepage: (if ($plugin | get -o homepage) != null { $plugin.homepage } else { null })
    repository: (if ($plugin | get -o repository) != null { $plugin.repository } else { null })
    license: (if ($plugin | get -o license) != null { $plugin.license } else { null })
    keywords: $sorted_keywords
    commands: (if ($plugin | get -o commands) != null { $plugin.commands } else { null })
    agents: (if ($plugin | get -o agents) != null { $plugin.agents } else { null })
    hooks: (if ($plugin | get -o hooks) != null { $plugin.hooks } else { null })
    mcpServers: (if ($plugin | get -o mcpServers) != null { $plugin.mcpServers } else { null })
    skills: $sorted_skills
  }

  # Remove null fields
  let final = $formatted | reject -i version description author homepage repository license keywords commands agents hooks mcpServers skills
    | merge (if $formatted.version != null { { version: $formatted.version } } else { {} })
    | merge (if $formatted.description != null { { description: $formatted.description } } else { {} })
    | merge (if $formatted.author != null { { author: $formatted.author } } else { {} })
    | merge (if $formatted.homepage != null { { homepage: $formatted.homepage } } else { {} })
    | merge (if $formatted.repository != null { { repository: $formatted.repository } } else { {} })
    | merge (if $formatted.license != null { { license: $formatted.license } } else { {} })
    | merge (if $formatted.keywords != null { { keywords: $formatted.keywords } } else { {} })
    | merge (if $formatted.commands != null { { commands: $formatted.commands } } else { {} })
    | merge (if $formatted.agents != null { { agents: $formatted.agents } } else { {} })
    | merge (if $formatted.hooks != null { { hooks: $formatted.hooks } } else { {} })
    | merge (if $formatted.mcpServers != null { { mcpServers: $formatted.mcpServers } } else { {} })
    | merge (if $formatted.skills != null { { skills: $formatted.skills } } else { {} })

  # Write formatted JSON
  $final | to json -i 2 | save -f $plugin_path

  print $"(ansi green_bold)✓ Formatted:(ansi reset) ($plugin_path)"
  if $sorted_keywords != null {
    print $"  Keywords sorted: (($sorted_keywords | length))"
  }
  if $sorted_skills != null {
    print $"  Skills sorted: (($sorted_skills | length))"
  }
}
