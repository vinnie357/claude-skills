#!/usr/bin/env nu
# list-claims.nu — list all SandboxClaims as a structured table.
#
# Wraps `kubectl get sandboxclaim -o json` and projects fields useful for
# at-a-glance triage: session, phase, template, bound pod, age, shutdownPolicy.
#
# No bare `main` at end of file (Nushell auto-invokes def main).

def main [
  --namespace: string = ""      # optional namespace (defaults to current context)
  --all-namespaces (-A)         # list across all namespaces
  --json                        # emit raw JSON instead of a nushell table
] {
  let ns_flag = if $all_namespaces {
    ["-A"]
  } else if ($namespace | is-empty) {
    []
  } else {
    ["-n" $namespace]
  }

  let result = (
    do --ignore-errors {
      ^kubectl get sandboxclaim ...$ns_flag -o json
    } | complete
  )

  if $result.exit_code != 0 {
    print --stderr "error: kubectl get sandboxclaim failed:"
    print --stderr $result.stderr
    exit 1
  }

  let data = ($result.stdout | from json)
  let items = ($data | get -o items | default [])

  if ($items | is-empty) {
    print "No SandboxClaims found."
    return
  }

  let now = (date now)

  let rows = ($items | each { |claim|
    let created = ($claim | get -o metadata.creationTimestamp | default "")
    let age = if ($created | is-empty) {
      "?"
    } else {
      let dt = ($created | into datetime)
      let secs = (($now - $dt) | into int) / 1_000_000_000
      format-age $secs
    }

    {
      namespace: ($claim | get -o metadata.namespace | default "default")
      name: ($claim | get -o metadata.name | default "?")
      phase: ($claim | get -o status.phase | default "Pending")
      template: ($claim | get -o spec.sandboxTemplateRef.name | default "?")
      pod: ($claim | get -o status.boundSandbox.name | default ($claim | get -o status.sandboxName | default "-"))
      shutdown: ($claim | get -o spec.lifecycle.shutdownPolicy | default "-")
      age: $age
    }
  })

  if $json {
    print ($rows | to json)
  } else {
    print $rows
  }
}

def format-age [secs: int] {
  if $secs < 60 {
    $"($secs)s"
  } else if $secs < 3600 {
    $"(($secs / 60) | math floor)m"
  } else if $secs < 86400 {
    let h = (($secs / 3600) | math floor)
    let m = ((($secs mod 3600) / 60) | math floor)
    $"($h)h($m)m"
  } else {
    let d = (($secs / 86400) | math floor)
    let h = ((($secs mod 86400) / 3600) | math floor)
    $"($d)d($h)h"
  }
}
