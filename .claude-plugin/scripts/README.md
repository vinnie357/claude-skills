# Claude Skills Marketplace Scripts

Scripts for managing the claude-skills marketplace.

## update-claudio.nu

Updates the root `claudio` plugin.json with all skills and commands from all plugins in the marketplace.

### Usage

```bash
# Update plugin.json with all skills
nu .claude-plugin/scripts/update-claudio.nu

# Preview changes without writing (dry-run mode)
nu .claude-plugin/scripts/update-claudio.nu --dry-run

# Show detailed output
nu .claude-plugin/scripts/update-claudio.nu --verbose

# Combine flags
nu .claude-plugin/scripts/update-claudio.nu --dry-run --verbose
```

### Via mise

```bash
# Update plugin.json
mise update-claudio

# Dry-run mode
mise update-claudio --dry-run

# Verbose mode
mise update-claudio --verbose

# Both flags
mise update-claudio --dry-run --verbose
```

### What It Does

1. Reads `.claude-plugin/marketplace.json` to find all plugins
2. For each plugin (except `claudio`):
   - Reads the plugin's `plugin.json`
   - Collects all `skills` paths
   - Collects all `commands` paths (if present)
3. Converts relative paths to be relative from repository root
4. Updates `.claude-plugin/plugin.json` with all collected skills and commands

This ensures the `claudio` meta-plugin always includes all skills from all other plugins.

### When to Run

Run this script whenever you:
- Add a new skill to any plugin
- Remove a skill from any plugin
- Add a new plugin to the marketplace
- Add or remove commands from any plugin

Always run `mise test` after updating to validate the changes.
