#!/usr/bin/env nu
# wait-bound.nu — poll a SandboxClaim until status.phase == Bound or timeout.
#
# On success: prints the bound pod name on stdout, exit 0.
# On timeout: prints the latest controller condition on stderr, exit 1.
# On phase: Failed / similar terminal: exit 2.
#
# No bare `main` at end of file (Nushell auto-invokes def main).

def main [
  --session-id: string          # required: session id (renders to claim name session-<id>)
  --timeout: int = 120          # seconds to wait
  --interval: int = 2           # seconds between polls
  --namespace: string = ""      # optional namespace
] {
  if ($session_id | is-empty) {
    print --stderr "error: --session-id required"
    exit 2
  }

  let claim_name = $"session-($session_id)"
  let ns_flag = if ($namespace | is-empty) { [] } else { ["-n" $namespace] }

  let deadline = ((date now) + ($timeout * 1sec))

  mut last_phase = "Unknown"

  loop {
    let result = (
      do --ignore-errors {
        ^kubectl get sandboxclaim $claim_name ...$ns_flag -o json
      } | complete
    )

    if $result.exit_code != 0 {
      if (date now) >= $deadline {
        print --stderr $"timeout: claim ($claim_name) not observed; last kubectl error:"
        print --stderr $result.stderr
        exit 1
      }
      sleep ($interval * 1sec)
      continue
    }

    let claim = ($result.stdout | from json)
    let phase = ($claim | get -o status.phase | default "Pending")
    $last_phase = $phase

    if $phase == "Bound" {
      let pod = ($claim | get -o status.boundSandbox.name | default ($claim | get -o status.sandboxName | default ""))
      if ($pod | is-empty) {
        print --stderr "claim is Bound but no bound pod name in status; check API version (v1alpha1 vs v1beta1 field naming)"
        exit 1
      }
      print $pod
      return
    }

    if $phase in ["Failed" "Terminating"] {
      let conditions = ($claim | get -o status.conditions | default [])
      print --stderr $"claim ($claim_name) reached terminal phase ($phase). Conditions:"
      $conditions | each { |c| print --stderr $"  ($c.type): ($c.status) — ($c | get -o message | default '')" }
      exit 2
    }

    if (date now) >= $deadline {
      print --stderr $"timeout: claim ($claim_name) stuck in phase ($last_phase) after ($timeout)s"
      let conditions = ($claim | get -o status.conditions | default [])
      $conditions | each { |c| print --stderr $"  ($c.type): ($c.status) — ($c | get -o message | default '')" }
      exit 1
    }

    sleep ($interval * 1sec)
  }
}
