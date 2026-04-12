#!/usr/bin/env nu

# Runex run debugging and step log inspection
# Supports: steps, log, failures, watch

def main [
    command: string   # Subcommand: steps, log, failures, watch
    ...args: string   # Additional arguments passed to the command
] {
    match $command {
        "steps" => { cmd-steps $args }
        "log" => { cmd-log $args }
        "failures" => { cmd-failures $args }
        "watch" => { cmd-watch $args }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown command '($command)'"
            print "Available: steps, log, failures, watch"
            exit 1
        }
    }
}

def get-host [] {
    $env.RUNEX_HOST? | default "http://localhost:4001"
}

def get-headers [] {
    let token = ($env.RUNEX_API_TOKEN? | default "")
    if ($token | is-empty) {
        []
    } else {
        [Authorization $"Bearer ($token)"]
    }
}

def api-get [path: string] {
    let host = (get-host)
    let headers = (get-headers)
    try {
        if ($headers | is-empty) {
            http get $"($host)($path)"
        } else {
            http get -H $headers $"($host)($path)"
        }
    } catch { |err|
        print $"(ansi red)Error:(ansi reset) Request to ($path) failed"
        print $"($err.msg)"
        exit 1
    }
}

# Show step names, statuses, and timing in a table
def cmd-steps [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Run ID required"
        print "Usage: debug.nu steps <run_id>"
        exit 1
    }
    let run_id = ($args | first)
    let resp = (api-get $"/api/runs/($run_id)/steps")
    let steps = ($resp | get data)

    if ($steps | is-empty) {
        print $"(ansi yellow)No steps found for run ($run_id)(ansi reset)"
        return
    }

    $steps | select id status started_at finished_at exit_code attempt
}

# Show full output for one step
def cmd-log [args: list<string>] {
    if ($args | length) < 2 {
        print $"(ansi red)Error:(ansi reset) Run ID and step ID required"
        print "Usage: debug.nu log <run_id> <step_id>"
        exit 1
    }
    let run_id = ($args | first)
    let step_id = ($args | get 1)
    let resp = (api-get $"/api/runs/($run_id)/steps")
    let steps = ($resp | get data)

    let matching = ($steps | where { |s| ($s.id | into string) == $step_id })
    if ($matching | is-empty) {
        print $"(ansi red)Error:(ansi reset) Step ($step_id) not found in run ($run_id)"
        exit 1
    }

    let step = ($matching | first)
    print $"(ansi cyan)Step ($step.id) — status: ($step.status)(ansi reset)"
    if ($step.output | is-not-empty) {
        print $"\n(ansi green)Output:(ansi reset)"
        print $step.output
    }
    if ($step.error | is-not-empty) {
        print $"\n(ansi red)Error:(ansi reset)"
        print $step.error
    }
}

# Show only failed steps with error output
def cmd-failures [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Run ID required"
        print "Usage: debug.nu failures <run_id>"
        exit 1
    }
    let run_id = ($args | first)
    let resp = (api-get $"/api/runs/($run_id)/steps")
    let steps = ($resp | get data)

    let failed = ($steps | where { |s| $s.exit_code != 0 and $s.exit_code != null })
    if ($failed | is-empty) {
        print $"(ansi green)No failures in run ($run_id)(ansi reset)"
        return
    }

    let fail_count = ($failed | length)
    print $"(ansi red)($fail_count) failed steps:(ansi reset)\n"
    for step in $failed {
        print $"(ansi red)Step ($step.id)(ansi reset) — exit_code: ($step.exit_code)"
        if ($step.error | is-not-empty) {
            print $step.error
        }
        if ($step.output | is-not-empty) {
            print $step.output
        }
        print ""
    }
}

# Poll until run completes, show progress
def cmd-watch [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Run ID required"
        print "Usage: debug.nu watch <run_id> [--interval <seconds>]"
        exit 1
    }
    let run_id = ($args | first)

    let interval_match = ($args | enumerate | where { |it| $it.item == "--interval" })
    let interval = if ($interval_match | is-empty) {
        2
    } else {
        let interval_idx = ($interval_match | first | get index)
        if ($args | length) > ($interval_idx + 1) {
            $args | get ($interval_idx + 1) | into int
        } else {
            2
        }
    }

    let interval_msg = $"(char lparen)interval: ($interval)s(char rparen)"
    print $"(ansi cyan)Watching run ($run_id) ($interval_msg)...(ansi reset)"

    mut done = false
    while not $done {
        let resp = (api-get $"/api/runs/($run_id)")
        let run = ($resp | get data)
        let status = $run.status

        let step_resp = (api-get $"/api/runs/($run_id)/steps")
        let steps = ($step_resp | get data)
        let completed = ($steps | where status == "completed" | length)
        let failed = ($steps | where { |s| $s.exit_code != 0 and $s.exit_code != null } | length)
        let total = ($steps | length)

        print $"  status: ($status) | steps: ($completed)/($total) completed, ($failed) failed"

        match $status {
            "success" | "completed" | "failed" | "cancelled" => {
                $done = true
                print $"\n(ansi cyan)Run ($run_id) finished: ($status)(ansi reset)"
            }
            _ => {
                sleep ($interval * 1sec)
            }
        }
    }
}
