#!/usr/bin/env nu
# Validate a specific plugin

def main [plugin_name: string] {
    print $"🔍 Validating plugin: ($plugin_name)...\n"

    # Get repo root (parent of test/ directory)
    let script_dir = ($env.CURRENT_FILE | path dirname)
    let repo_root = ($script_dir | path dirname)

    # Handle claudio (root plugin) differently
    let plugin_path = if $plugin_name == "claudio" {
        ($repo_root | path join ".claude-plugin" "plugin.json")
    } else {
        ($repo_root | path join $plugin_name ".claude-plugin" "plugin.json")
    }

    # Check if plugin.json exists
    if not ($plugin_path | path exists) {
        print $"❌ Error: plugin.json not found at ($plugin_path)"
        exit 1
    }

    try {
        let plugin = (open $plugin_path)

        # Check required fields
        if ($plugin | get -o name) == null {
            print "❌ Error: Missing required field: name"
            exit 1
        }

        # Verify name matches directory
        if $plugin.name != $plugin_name {
            print $"❌ Error: Name mismatch - expected '($plugin_name)', got '($plugin.name)'"
            exit 1
        }

        # Check for invalid fields (marketplace-only)
        let invalid_fields = ["dependencies", "category", "strict", "source", "tags"]
        for field in $invalid_fields {
            if ($plugin | get -o $field) != null {
                print $"❌ Error: Invalid field '($field)' found (this is a marketplace-only field)"
                exit 1
            }
        }

        # Validate kebab-case name
        if not ($plugin.name =~ '^[a-z0-9]+(-[a-z0-9]+)*$') {
            print "❌ Error: Name must be kebab-case (lowercase alphanumeric and hyphens only)"
            exit 1
        }

        # Check recommended fields
        mut warnings = []

        if ($plugin | get -o version) == null {
            $warnings = ($warnings | append "Missing recommended field: version")
        }

        if ($plugin | get -o description) == null {
            $warnings = ($warnings | append "Missing recommended field: description")
        }

        if ($plugin | get -o license) == null {
            $warnings = ($warnings | append "Missing recommended field: license")
        }

        # Print warnings
        if ($warnings | length) > 0 {
            print "⚠️  Warnings:"
            for warning in $warnings {
                print $"   - ($warning)"
            }
            print ""
        }

        # Validate skills paths if present
        if ($plugin | get -o skills) != null {
            print "📁 Checking skill paths..."
            for skill in $plugin.skills {
                # For claudio, skills are already relative from root
                # For other plugins, need to join with plugin name
                let skill_path = if $plugin_name == "claudio" {
                    ($repo_root | path join $skill)
                } else {
                    ($repo_root | path join $plugin_name $skill)
                }

                if not ($skill_path | path exists) {
                    print $"   ⚠️  Warning: Skill path not found: ($skill)"
                } else {
                    print $"   ✅ ($skill)"
                }
            }
            print ""
        }

        print $"✅ Plugin '($plugin_name)' is valid!"
        exit 0

    } catch {
        print "❌ Error: Failed to parse plugin.json or validation error"
        exit 1
    }
}
