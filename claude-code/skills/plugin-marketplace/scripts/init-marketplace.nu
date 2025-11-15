#!/usr/bin/env nu

# Initialize a new marketplace.json file with template
#
# Usage: nu init-marketplace.nu [--force]

def main [
  --force  # Overwrite existing marketplace.json
] {
  let marketplace_path = ".claude-plugin/marketplace.json"

  if ($marketplace_path | path exists) and not $force {
    print $"(ansi red_bold)Error:(ansi reset) ($marketplace_path) already exists"
    print "Use --force to overwrite"
    exit 1
  }

  # Create directory if needed
  mkdir .claude-plugin

  # Prompt for marketplace details
  print $"(ansi green_bold)Creating new marketplace.json(ansi reset)"
  print ""

  let name = input "Marketplace name (kebab-case): "
  let owner_name = input "Owner name: "
  let owner_email = input "Owner email (optional): "
  let description = input "Description: "

  # Build marketplace object
  let marketplace = {
    name: $name
    owner: (if ($owner_email | is-empty) {
      { name: $owner_name }
    } else {
      { name: $owner_name, email: $owner_email }
    })
    metadata: {
      description: $description
      version: "1.0.0"
      pluginRoot: "./plugins"
    }
    plugins: []
  }

  # Write file
  $marketplace | to json -i 2 | save -f $marketplace_path

  print ""
  print $"(ansi green_bold)✓ Created:(ansi reset) ($marketplace_path)"
  print ""
  print "Next steps:"
  print "  1. Create plugin directories in ./plugins/"
  print "  2. Add plugin entries to the 'plugins' array"
  print "  3. Run validation: nu validate-marketplace.nu ($marketplace_path)"
}
