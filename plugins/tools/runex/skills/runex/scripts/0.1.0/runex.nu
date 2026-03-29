#!/usr/bin/env nu

# Runex API client
# Supports: health, runs, run, submit, steps, workflows, workflow

def main [
    command: string   # Subcommand: health, runs, run, submit, steps, workflows, workflow
    ...args: string   # Additional arguments passed to the command
] {
    match $command {
        "health" => { cmd-health }
        "runs" => { cmd-runs }
        "run" => { cmd-run $args }
        "submit" => { cmd-submit $args }
        "steps" => { cmd-steps $args }
        "workflows" => { cmd-workflows }
        "workflow" => { cmd-workflow $args }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown command '($command)'"
            print "Available: health, runs, run, submit, steps, workflows, workflow"
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
    let result = if ($headers | is-empty) {
        do { http get $"($host)($path)" } | complete
    } else {
        do { http get -H $headers $"($host)($path)" } | complete
    }
    if $result.exit_code != 0 {
        print $"(ansi red)Error:(ansi reset) Request to ($path) failed"
        print $result.stderr
        exit 1
    }
    $result.stdout
}

def api-post [path: string, body: record] {
    let host = (get-host)
    let headers = (get-headers)
    let result = if ($headers | is-empty) {
        do { http post -t application/json $"($host)($path)" $body } | complete
    } else {
        do { http post -t application/json -H $headers $"($host)($path)" $body } | complete
    }
    if $result.exit_code != 0 {
        print $"(ansi red)Error:(ansi reset) Request to ($path) failed"
        print $result.stderr
        exit 1
    }
    $result.stdout
}

# GET /api/health — liveness probe
def cmd-health [] {
    let resp = (api-get "/api/health")
    $resp
}

# GET /api/runs — list recent runs
def cmd-runs [] {
    let resp = (api-get "/api/runs")
    $resp | get data
}

# GET /api/runs/:id — show run detail
def cmd-run [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Run ID required"
        print "Usage: runex.nu run <id>"
        exit 1
    }
    let id = ($args | first)
    let resp = (api-get $"/api/runs/($id)")
    $resp | get data
}

# POST /api/runs — submit a workflow
def cmd-submit [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Workflow path required"
        print "Usage: runex.nu submit <workflow_path> [--params '{\"K\":\"V\"}']"
        exit 1
    }
    let workflow_path = ($args | first)
    let params_idx = ($args | enumerate | where { |it| $it.item == "--params" } | get index | first | default -1)
    let params = if $params_idx >= 0 and ($args | length) > ($params_idx + 1) {
        $args | get ($params_idx + 1) | from json
    } else {
        {}
    }
    let body = {workflow_path: $workflow_path, params: $params}
    let resp = (api-post "/api/runs" $body)
    $resp | get data
}

# GET /api/runs/:id/steps — list step runs
def cmd-steps [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Run ID required"
        print "Usage: runex.nu steps <run_id>"
        exit 1
    }
    let id = ($args | first)
    let resp = (api-get $"/api/runs/($id)/steps")
    $resp | get data
}

# GET /api/workflows — list workflows
def cmd-workflows [] {
    let resp = (api-get "/api/workflows")
    $resp | get data
}

# GET /api/workflows/:id — show workflow detail
def cmd-workflow [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Workflow ID required"
        print "Usage: runex.nu workflow <id>"
        exit 1
    }
    let id = ($args | first)
    let resp = (api-get $"/api/workflows/($id)")
    $resp | get data
}
