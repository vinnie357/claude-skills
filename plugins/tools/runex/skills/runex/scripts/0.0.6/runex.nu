#!/usr/bin/env nu

# Runex API client
# Supports: info, health, runs, run, submit, steps, workflows, workflow,
#           heartbeat, agent-runs, agent-run, submit-agent,
#           federation-nodes, federation-runs, federation-run

def main [
    command: string   # Subcommand: info, health, runs, run, submit, steps, workflows, workflow, heartbeat, agent-runs, agent-run, submit-agent, federation-nodes, federation-runs, federation-run
    ...args: string   # Additional arguments passed to the command
] {
    match $command {
        "info" => { cmd-info }
        "health" => { cmd-health }
        "runs" => { cmd-runs }
        "run" => { cmd-run $args }
        "submit" => { cmd-submit $args }
        "steps" => { cmd-steps $args }
        "workflows" => { cmd-workflows }
        "workflow" => { cmd-workflow $args }
        "heartbeat" => { cmd-heartbeat $args }
        "agent-runs" => { cmd-agent-runs }
        "agent-run" => { cmd-agent-run $args }
        "submit-agent" => { cmd-submit-agent $args }
        "federation-nodes" => { cmd-federation-nodes }
        "federation-runs" => { cmd-federation-runs }
        "federation-run" => { cmd-federation-run $args }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown command '($command)'"
            print "Available: info, health, runs, run, submit, steps, workflows, workflow, heartbeat, agent-runs, agent-run, submit-agent, federation-nodes, federation-runs, federation-run"
            exit 1
        }
    }
}

def get-host [] {
    $env.RUNEX_HOST? | default "http://localhost:4000"
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

def api-post [path: string, body: record] {
    let host = (get-host)
    let headers = (get-headers)
    try {
        if ($headers | is-empty) {
            http post -t application/json $"($host)($path)" $body
        } else {
            http post -t application/json -H $headers $"($host)($path)" $body
        }
    } catch { |err|
        print $"(ansi red)Error:(ansi reset) Request to ($path) failed"
        print $"($err.msg)"
        exit 1
    }
}

# GET /api/info — server build info
def cmd-info [] {
    let resp = (api-get "/api/info")
    $resp
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
        print "Usage: runex.nu submit <workflow_path> [params_json]"
        exit 1
    }
    let workflow_path = ($args | first)
    let params = if ($args | length) > 1 {
        try {
            $args | get 1 | from json
        } catch {
            print $"(ansi red)Error:(ansi reset) Invalid JSON in params argument"
            print "Params must be a valid JSON object, e.g. '{\"KEY\":\"val\"}'"
            exit 1
        }
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

# POST /api/runs/:run_id/steps/:step_id/heartbeat — extend step timeout
def cmd-heartbeat [args: list<string>] {
    if ($args | length) < 2 {
        print $"(ansi red)Error:(ansi reset) Run ID and step ID required"
        print "Usage: runex.nu heartbeat <run_id> <step_id> [extension_ms]"
        exit 1
    }
    let run_id = ($args | first)
    let step_id = ($args | get 1)
    let body = if ($args | length) > 2 {
        let ext = ($args | get 2 | into int)
        {extension_ms: $ext}
    } else {
        {}
    }
    let resp = (api-post $"/api/runs/($run_id)/steps/($step_id)/heartbeat" $body)
    $resp
}

# GET /api/agent_runs — list agent runs
def cmd-agent-runs [] {
    let resp = (api-get "/api/agent_runs")
    $resp | get data
}

# GET /api/agent_runs/:id — show agent run detail
def cmd-agent-run [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Agent run ID required"
        print "Usage: runex.nu agent-run <id>"
        exit 1
    }
    let id = ($args | first)
    let resp = (api-get $"/api/agent_runs/($id)")
    $resp | get data
}

# POST /api/agent_runs — submit a workflow as an agent run
def cmd-submit-agent [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Workflow path required"
        print "Usage: runex.nu submit-agent <workflow_path> [params_json]"
        exit 1
    }
    let workflow_path = ($args | first)
    let params = if ($args | length) > 1 {
        try {
            $args | get 1 | from json
        } catch {
            print $"(ansi red)Error:(ansi reset) Invalid JSON in params argument"
            print "Params must be a valid JSON object, e.g. '{\"KEY\":\"val\"}'"
            exit 1
        }
    } else {
        {}
    }
    let body = {workflow_path: $workflow_path, params: $params}
    let resp = (api-post "/api/agent_runs" $body)
    $resp | get data
}

# GET /api/federation/nodes — list federation nodes
def cmd-federation-nodes [] {
    let resp = (api-get "/api/federation/nodes")
    $resp
}

# GET /api/federation/runs — list federation runs
def cmd-federation-runs [] {
    let resp = (api-get "/api/federation/runs")
    $resp
}

# GET /api/federation/runs/:id — show federation run detail
def cmd-federation-run [args: list<string>] {
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Federation run ID required"
        print "Usage: runex.nu federation-run <id>"
        exit 1
    }
    let id = ($args | first)
    let resp = (api-get $"/api/federation/runs/($id)")
    $resp
}
