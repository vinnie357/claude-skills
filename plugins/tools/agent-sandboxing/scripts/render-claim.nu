#!/usr/bin/env nu
# render-claim.nu — render a SandboxClaim YAML from the plugin's template.
#
# Reads templates/SandboxClaim.session.yaml, substitutes ${SESSION_ID}, swaps
# sandboxTemplateRef.name, and optionally adds spec.lifecycle.shutdownTime.
# Emits the final YAML to stdout. Pipe to `kubectl apply -f -`.
#
# DO NOT add a bare `main` call at the end of this file — Nushell auto-invokes
# `def main` when this script is run via `nu render-claim.nu`. A bare call
# would double-fire (see /core:nushell "Bare main call after def main").

def main [
  --session-id: string                          # required: session identifier (e.g. abc123)
  --template: string = "claude-code-kata"       # SandboxTemplate name to reference
  --shutdown-time: string = ""                  # optional RFC3339 shutdownTime
  --plugin-root: string = ""                    # plugin root; defaults to $env.CLAUDE_PLUGIN_ROOT
] {
  if ($session_id | is-empty) {
    print --stderr "error: --session-id required"
    exit 2
  }

  let root = if ($plugin_root | is-empty) {
    $env.CLAUDE_PLUGIN_ROOT? | default ""
  } else {
    $plugin_root
  }

  if ($root | is-empty) {
    print --stderr "error: --plugin-root not given and CLAUDE_PLUGIN_ROOT not set"
    exit 2
  }

  let tpl_path = ($root | path join "templates" "SandboxClaim.session.yaml")
  if not ($tpl_path | path exists) {
    print --stderr $"error: template not found at ($tpl_path)"
    exit 2
  }

  let raw = (open --raw $tpl_path)

  let with_session = ($raw | str replace --all '${SESSION_ID}' $session_id)

  let with_template = if $template == "claude-code-kata" {
    $with_session
  } else {
    $with_session | str replace "name: claude-code-kata" $"name: ($template)"
  }

  let final_yaml = if ($shutdown_time | is-empty) {
    $with_template
  } else {
    # Uncomment + populate the commented-out shutdownTime line.
    $with_template
    | str replace --regex '#\s*shutdownTime:.*' $"shutdownTime: \"($shutdown_time)\""
  }

  print $final_yaml
}
