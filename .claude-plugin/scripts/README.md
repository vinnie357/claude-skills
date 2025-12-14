# Claude Skills Marketplace Scripts

Scripts for managing the claude-skills marketplace.

## update-all-skills.nu

Updates the root `all-skills` plugin.json with all skills and commands from all plugins in the marketplace.

### Usage

```bash
# Update plugin.json with all skills
nu .claude-plugin/scripts/update-all-skills.nu

# Preview changes without writing (dry-run mode)
nu .claude-plugin/scripts/update-all-skills.nu --dry-run

# Show detailed output
nu .claude-plugin/scripts/update-all-skills.nu --verbose

# Combine flags
nu .claude-plugin/scripts/update-all-skills.nu --dry-run --verbose
```

### Via mise

```bash
# Update plugin.json
mise update-all-skills

# Dry-run mode
mise update-all-skills --dry-run

# Verbose mode
mise update-all-skills --verbose

# Both flags
mise update-all-skills --dry-run --verbose
```

### What It Does

1. Reads `.claude-plugin/marketplace.json` to find all plugins
2. For each plugin (except `all-skills`):
   - Reads the plugin's `plugin.json`
   - Collects all `skills` paths
   - Collects all `commands` paths (if present)
3. Converts relative paths to be relative from repository root
4. Updates `.claude-plugin/plugin.json` with all collected skills and commands

This ensures the `all-skills` meta-plugin always includes all skills from all other plugins.

### When to Run

Run this script whenever you:
- Add a new skill to any plugin
- Remove a skill from any plugin
- Add a new plugin to the marketplace
- Add or remove commands from any plugin

Always run `mise test` after updating to validate the changes.
