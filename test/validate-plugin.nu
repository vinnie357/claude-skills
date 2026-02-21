#!/usr/bin/env nu
# Validate a specific plugin
#
# This is a thin wrapper around the skill's validate-plugin.nu script.
# The comprehensive validation logic lives in claude-code/skills/claude-plugins/scripts/validate-plugin.nu

def main [plugin_name: string] {
    print $"🔍 Validating plugin: ($plugin_name)...\n"

    # Get repo root (parent of test/ directory)
    let script_dir = ($env.CURRENT_FILE | path dirname)
    let repo_root = ($script_dir | path dirname)

    let marketplace_path = ($repo_root | path join ".claude-plugin" "marketplace.json")
    let skill_script = ($repo_root | path join "plugins" "tools" "claude-code" "skills" "claude-plugins" "scripts" "validate-plugin.nu")

    # Use the skill's validate-plugin.nu with marketplace mode
    nu $skill_script $plugin_name --marketplace $marketplace_path
}
