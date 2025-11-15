#!/usr/bin/env nu

# Initialize a new plugin.json file with template
#
# Usage: nu init-plugin.nu [--force]

def main [
  --force  # Overwrite existing plugin.json
] {
  let plugin_path = ".claude-plugin/plugin.json"

  if ($plugin_path | path exists) and not $force {
    print $"(ansi red_bold)Error:(ansi reset) ($plugin_path) already exists"
    print "Use --force to overwrite"
    exit 1
  }

  # Create directory if needed
  mkdir .claude-plugin

  # Prompt for plugin details
  print $"(ansi green_bold)Creating new plugin.json(ansi reset)"
  print ""

  let name = input "Plugin name (kebab-case): "
  let version = input "Version (default: 0.1.0): "
  let description = input "Description: "
  let author_name = input "Author name: "
  let author_email = input "Author email (optional): "
  let license = input "License (default: MIT): "

  # Build plugin object
  let plugin = {
    name: $name
    version: (if ($version | is-empty) { "0.1.0" } else { $version })
    description: $description
    author: (if ($author_email | is-empty) {
      { name: $author_name }
    } else {
      { name: $author_name, email: $author_email }
    })
    license: (if ($license | is-empty) { "MIT" } else { $license })
    keywords: []
    skills: []
  }

  # Write file
  $plugin | to json -i 2 | save -f $plugin_path

  print ""
  print $"(ansi green_bold)✓ Created:(ansi reset) ($plugin_path)"
  print ""
  print "Next steps:"
  print "  1. Create skills directories in ./skills/"
  print "  2. Add skill paths to the 'skills' array"
  print "  3. Run validation: nu validate-plugin.nu ($plugin_path)"
}
