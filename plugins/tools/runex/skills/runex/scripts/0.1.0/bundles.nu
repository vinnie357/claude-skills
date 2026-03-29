#!/usr/bin/env nu

# Runex bundle discovery and inspection
# Supports: list, show, validate

def main [
    command: string   # Subcommand: list, show, validate
    ...args: string   # Additional arguments passed to the command
] {
    match $command {
        "list" => { cmd-list $args }
        "show" => { cmd-show $args }
        "validate" => { cmd-validate $args }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown command '($command)'"
            print "Available: list, show, validate"
            exit 1
        }
    }
}

def default-bundle-paths [] {
    let home = ($env.HOME? | default "~")
    let cwd_bundles = "bundles"
    let runex_workflows = ($env.RUNEX_WORKFLOWS_DIR? | default "workflows")
    let user_dir_mac = $"($home)/Library/Application Support/Runex/workflows"
    let user_dir_linux = $"($home)/.local/share/runex/workflows"

    [$cwd_bundles $runex_workflows $user_dir_mac $user_dir_linux]
}

# List bundles found in search paths
def cmd-list [args: list<string>] {
    let search_path = if ($args | is-empty) {
        null
    } else {
        $args | first
    }

    let paths = if $search_path != null {
        [$search_path]
    } else {
        default-bundle-paths
    }

    mut found = []
    for dir in $paths {
        if ($dir | path exists) {
            let entries = (ls $dir | where type == dir)
            for entry in $entries {
                let wf_toml = $"($entry.name)/workflow.toml"
                if ($wf_toml | path exists) {
                    let content = (open $wf_toml)
                    let name = ($content | get -i workflow.name | default ($entry.name | path basename))
                    let desc = ($content | get -i workflow.description | default "")
                    $found = ($found | append {
                        name: $name
                        path: $entry.name
                        description: $desc
                    })
                }
            }
        }
    }

    if ($found | is-empty) {
        print $"(ansi yellow)No bundles found in search paths(ansi reset)"
    } else {
        $found
    }
}

# Show bundle details from workflow.toml
def cmd-show [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Bundle path required"
        print "Usage: bundles.nu show <bundle-path>"
        exit 1
    }
    let bundle_path = ($args | first)
    let wf_toml = $"($bundle_path)/workflow.toml"

    if not ($wf_toml | path exists) {
        print $"(ansi red)Error:(ansi reset) No workflow.toml found at ($wf_toml)"
        exit 1
    }

    let content = (open $wf_toml)
    let workflow = ($content | get -i workflow | default {})
    let name = ($workflow | get -i name | default "unknown")
    let description = ($workflow | get -i description | default "")
    let params = ($workflow | get -i params | default {})
    let env_vars = ($workflow | get -i env | default {})

    let steps = ($content | get -i step | default [])
    let step_names = ($steps | each { |s| $s | get -i name | default "unnamed" })

    let workflows_dir = $"($bundle_path)/workflows"
    let sub_workflows = if ($workflows_dir | path exists) {
        ls $workflows_dir | where name =~ '\.(toml|yaml|yml)$' | get name | each { |f| $f | path basename }
    } else {
        []
    }

    {
        name: $name
        description: $description
        path: $bundle_path
        params: $params
        env: $env_vars
        steps: $step_names
        sub_workflows: $sub_workflows
    }
}

# Validate bundle structure
def cmd-validate [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Bundle path required"
        print "Usage: bundles.nu validate <bundle-path>"
        exit 1
    }
    let bundle_path = ($args | first)

    mut checks = []

    # Check workflow.toml exists
    let wf_toml = $"($bundle_path)/workflow.toml"
    let wf_exists = ($wf_toml | path exists)
    $checks = ($checks | append {
        check: "workflow.toml exists"
        status: (if $wf_exists { "pass" } else { "fail" })
    })

    # Check scripts/ exists
    let scripts_dir = $"($bundle_path)/scripts"
    let scripts_exists = ($scripts_dir | path exists)
    $checks = ($checks | append {
        check: "scripts/ exists"
        status: (if $scripts_exists { "pass" } else { "warn" })
    })

    # Check mise.toml exists
    let mise_toml = $"($bundle_path)/mise.toml"
    let mise_exists = ($mise_toml | path exists)
    $checks = ($checks | append {
        check: "mise.toml exists"
        status: (if $mise_exists { "pass" } else { "warn" })
    })

    # Check workflow.toml is valid TOML with workflow section
    if $wf_exists {
        let parse_result = (do { open $wf_toml } | complete)
        if $parse_result.exit_code == 0 {
            $checks = ($checks | append {
                check: "workflow.toml parses"
                status: "pass"
            })
            let content = $parse_result.stdout
            let has_workflow = ($content | get -i workflow | is-not-empty)
            $checks = ($checks | append {
                check: "workflow section present"
                status: (if $has_workflow { "pass" } else { "fail" })
            })
        } else {
            $checks = ($checks | append {
                check: "workflow.toml parses"
                status: "fail"
            })
        }
    }

    let failures = ($checks | where status == "fail" | length)
    let warnings = ($checks | where status == "warn" | length)

    print $"(ansi cyan)Bundle validation: ($bundle_path)(ansi reset)"
    $checks | each { |c|
        let icon = match $c.status {
            "pass" => $"(ansi green)pass(ansi reset)"
            "fail" => $"(ansi red)FAIL(ansi reset)"
            "warn" => $"(ansi yellow)warn(ansi reset)"
            _ => $c.status
        }
        print $"  [($icon)] ($c.check)"
    }

    if $failures > 0 {
        print $"\n(ansi red)($failures) failure(s)(ansi reset), ($warnings) warning(s)"
        exit 1
    } else {
        print $"\n(ansi green)Valid(ansi reset) with ($warnings) warning(s)"
    }
}
