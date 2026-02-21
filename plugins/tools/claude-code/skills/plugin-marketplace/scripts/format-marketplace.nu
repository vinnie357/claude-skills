#!/usr/bin/env nu

# Format and sort marketplace.json file
#
# Usage: nu format-marketplace.nu <path-to-marketplace.json>

def main [
  marketplace_path: string  # Path to marketplace.json file
] {
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

  # Sort plugins by name
  let sorted_plugins = if ($marketplace | get -i plugins) != null {
    $marketplace.plugins | sort-by name
  } else {
    []
  }

  # Rebuild marketplace with sorted plugins
  let formatted = {
    name: $marketplace.name
    owner: $marketplace.owner
    metadata: (if ($marketplace | get -i metadata) != null {
      $marketplace.metadata
    } else {
      null
    })
    plugins: $sorted_plugins
  }

  # Remove null metadata if present
  let final = if ($formatted.metadata == null) {
    $formatted | reject metadata
  } else {
    $formatted
  }

  # Write formatted JSON
  $final | to json -i 2 | save -f $marketplace_path

  print $"(ansi green_bold)✓ Formatted:(ansi reset) ($marketplace_path)"
  print $"  Plugins sorted alphabetically: (($sorted_plugins | length))"
}
