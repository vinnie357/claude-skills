#!/usr/bin/env nu
# Validate all plugins and marketplace

def main [] {
    print "🧪 Running all validation tests...\n"

    # Get repo root (parent of test/ directory)
    let script_dir = ($env.CURRENT_FILE | path dirname)
    let repo_root = ($script_dir | path dirname)

    # Track results
    mut all_passed = true
    mut results = []

    # Validate marketplace.json
    print "📦 Validating marketplace.json..."
    let marketplace_result = (validate-marketplace $repo_root)
    $results = ($results | append $marketplace_result)
    if not $marketplace_result.passed {
        $all_passed = false
    }

    # Get all plugins from marketplace
    let marketplace = (open ($repo_root | path join ".claude-plugin" "marketplace.json"))
    let plugins = $marketplace.plugins

    # Validate each plugin
    for plugin in $plugins {
        let plugin_name = $plugin.name

        print $"\n🔍 Validating plugin: ($plugin_name)..."
        let plugin_result = (validate-plugin $repo_root $plugin_name)
        $results = ($results | append $plugin_result)
        if not $plugin_result.passed {
            $all_passed = false
        }
    }

    # Print summary
    print ""
    print "============================================================"
    print "📊 Test Summary"
    print "============================================================"

    for result in $results {
        let status = if $result.passed { "✅" } else { "❌" }
        print $"($status) ($result.name)"
        if not $result.passed {
            print $"   Error: ($result.error)"
        }
    }

    print ""
    if $all_passed {
        print "✨ All validations passed!"
        exit 0
    } else {
        print "❌ Some validations failed"
        exit 1
    }
}

# Validate marketplace.json
def validate-marketplace [repo_root: string] {
    let marketplace_path = ($repo_root | path join ".claude-plugin" "marketplace.json")

    try {
        let marketplace = (open $marketplace_path)

        # Check required fields
        if ($marketplace | get -o name) == null {
            return {
                name: "marketplace.json"
                passed: false
                error: "Missing required field: name"
            }
        }

        if ($marketplace | get -o owner) == null {
            return {
                name: "marketplace.json"
                passed: false
                error: "Missing required field: owner"
            }
        }

        if ($marketplace | get -o plugins) == null {
            return {
                name: "marketplace.json"
                passed: false
                error: "Missing required field: plugins"
            }
        }

        # Check plugins is an array
        let plugins_type = ($marketplace.plugins | describe)
        if not ($plugins_type | str contains "list") {
            return {
                name: "marketplace.json"
                passed: false
                error: "Field 'plugins' must be an array"
            }
        }

        # Validate each plugin entry
        for plugin in $marketplace.plugins {
            if ($plugin | get -o name) == null {
                return {
                    name: "marketplace.json"
                    passed: false
                    error: $"Plugin entry missing required field: name"
                }
            }

            if ($plugin | get -o source) == null {
                return {
                    name: "marketplace.json"
                    passed: false
                    error: $"Plugin '($plugin.name)' missing required field: source"
                }
            }
        }

        return {
            name: "marketplace.json"
            passed: true
            error: null
        }
    } catch {
        return {
            name: "marketplace.json"
            passed: false
            error: "Failed to parse JSON or validation error"
        }
    }
}

# Validate a specific plugin
def validate-plugin [repo_root: string, plugin_name: string] {
    # Handle all-skills (root plugin) differently
    let plugin_path = if $plugin_name == "all-skills" {
        ($repo_root | path join ".claude-plugin" "plugin.json")
    } else {
        ($repo_root | path join $plugin_name ".claude-plugin" "plugin.json")
    }

    # Check if plugin.json exists
    if not ($plugin_path | path exists) {
        return {
            name: $"plugin: ($plugin_name)"
            passed: false
            error: "plugin.json not found"
        }
    }

    try {
        let plugin = (open $plugin_path)

        # Check required fields
        if ($plugin | get -o name) == null {
            return {
                name: $"plugin: ($plugin_name)"
                passed: false
                error: "Missing required field: name"
            }
        }

        # Verify name matches directory
        if $plugin.name != $plugin_name {
            return {
                name: $"plugin: ($plugin_name)"
                passed: false
                error: $"Name mismatch: expected '($plugin_name)', got '($plugin.name)'"
            }
        }

        # Check for invalid fields (marketplace-only)
        let invalid_fields = ["dependencies", "category", "strict", "source", "tags"]
        for field in $invalid_fields {
            if ($plugin | get -o $field) != null {
                return {
                    name: $"plugin: ($plugin_name)"
                    passed: false
                    error: $"Invalid field '($field)' (marketplace-only field)"
                }
            }
        }

        # Validate kebab-case name
        if not ($plugin.name =~ '^[a-z0-9]+(-[a-z0-9]+)*$') {
            return {
                name: $"plugin: ($plugin_name)"
                passed: false
                error: "Name must be kebab-case (lowercase alphanumeric and hyphens only)"
            }
        }

        return {
            name: $"plugin: ($plugin_name)"
            passed: true
            error: null
        }
    } catch {
        return {
            name: $"plugin: ($plugin_name)"
            passed: false
            error: "Failed to parse JSON or validation error"
        }
    }
}
