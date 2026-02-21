#!/usr/bin/env nu
# Update the all-skills (root) plugin.json with all skills from all plugins

def main [
    --dry-run (-d)     # Preview changes without writing
    --verbose (-v)     # Show detailed output
] {
    let repo_root = ($env.CURRENT_FILE | path dirname | path dirname | path dirname)
    let plugin_json_path = ($repo_root | path join ".claude-plugin" "plugin.json")
    let marketplace_path = ($repo_root | path join ".claude-plugin" "marketplace.json")

    if $verbose {
        print $"📁 Repository root: ($repo_root)"
        print $"📄 Plugin.json: ($plugin_json_path)"
        print $"📦 Marketplace: ($marketplace_path)"
        print ""
    }

    # Read marketplace to get all plugins
    let marketplace = (open $marketplace_path)
    let plugins = ($marketplace.plugins | where name != "all-skills")

    if $verbose {
        print "📋 Found plugins:"
        for plugin in $plugins {
            print $"   - ($plugin.name)"
        }
        print ""
    }

    # Collect all skills from all plugins
    mut all_skills = []
    mut all_commands = []

    for plugin in $plugins {
        let plugin_name = $plugin.name
        let source = ($plugin | get -o source | default "./")

        # Skip external plugins (source is an object, not a string)
        let source_type = ($source | describe)
        if ($source_type | str starts-with "record") {
            if $verbose {
                print $"⚠️  Skipping ($plugin_name): external plugin"
            }
            continue
        }

        # Derive directory from source field (strip leading ./)
        let source_dir = ($source | str replace --regex '^\./' '')
        let plugin_dir = ($repo_root | path join $source_dir)
        let plugin_manifest_path = ($plugin_dir | path join ".claude-plugin" "plugin.json")

        if not ($plugin_manifest_path | path exists) {
            if $verbose {
                print $"⚠️  Skipping ($plugin_name): no plugin.json found"
            }
            continue
        }

        let plugin_manifest = (open $plugin_manifest_path)

        # Collect skills
        if ($plugin_manifest | get -o skills) != null {
            for skill in $plugin_manifest.skills {
                # Remove leading "./" and build proper path using source_dir
                let clean_skill = ($skill | str replace --regex '^\./' '')
                let skill_path = $"./($source_dir)/($clean_skill)"
                $all_skills = ($all_skills | append $skill_path)
            }
        }

        # Collect commands
        if ($plugin_manifest | get -o commands) != null {
            for command in $plugin_manifest.commands {
                # Remove leading "./" and build proper path using source_dir
                let clean_command = ($command | str replace --regex '^\./' '')
                let command_path = $"./($source_dir)/($clean_command)"
                $all_commands = ($all_commands | append $command_path)
            }
        }
    }

    if $verbose {
        print $"✅ Collected ($all_skills | length) skills from ($plugins | length) plugins"
        if ($all_commands | length) > 0 {
            print $"✅ Collected ($all_commands | length) commands from ($plugins | length) plugins"
        }
        print ""
    }

    # Read current plugin.json
    let current_plugin = (open $plugin_json_path)

    # Create updated plugin.json
    mut updated_plugin = ($current_plugin | upsert skills $all_skills)

    # Only include commands if there are any (omit field entirely otherwise)
    if ($all_commands | length) > 0 {
        $updated_plugin = ($updated_plugin | upsert commands $all_commands)
    } else {
        # Remove commands field if it exists and there are no commands
        $updated_plugin = ($updated_plugin | reject --optional commands)
    }

    # Show changes
    print "📊 Summary of changes:"
    print $"   Skills: ($all_skills | length) total"
    if ($all_commands | length) > 0 {
        print $"   Commands: ($all_commands | length) total"
    }
    print ""

    if $verbose {
        print "📝 Skills:"
        for skill in $all_skills {
            print $"   - ($skill)"
        }
        if ($all_commands | length) > 0 {
            print ""
            print "📝 Commands:"
            for command in $all_commands {
                print $"   - ($command)"
            }
        }
        print ""
    }

    # Write or preview
    if $dry_run {
        print "🔍 DRY RUN - No changes written"
        print ""
        print "Preview of updated plugin.json:"
        print "================================"
        print ($updated_plugin | to json --indent 2)
    } else {
        $updated_plugin | save --force $plugin_json_path
        print $"✅ Updated ($plugin_json_path)"
        print ""
        print "Run 'mise test' to validate the changes"
    }
}
