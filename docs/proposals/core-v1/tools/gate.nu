# Run a command as a gate: one status line, failures only, deduplicated, full log kept on disk.
#   nu gate.nu test -- mise run test
#   nu gate.nu test --json -- mise run test

const PATTERN = '(?i)(error|fail|panic|fatal|assert|exception|expected)'

# Collapse repeated lines into "<line> ×N", keeping first-seen order.
export def dedupe [lines: list<string>]: nothing -> list<string> {
  $lines
  | each { str trim }
  | reduce --fold [] {|l, acc|
      let i = ($acc | enumerate | where item.line == $l | get index.0?)
      if $i == null { $acc | append {line: $l, n: 1} } else { $acc | update $i {|r| $r | update n ($r.n + 1) } }
    }
  | each {|r| if $r.n > 1 { $"($r.line) ×($r.n)" } else { $r.line } }
}

# Keep the lines that look like failures, deduplicated, capped.
export def failures [output: string, max: int = 20]: nothing -> list<string> {
  dedupe ($output | lines | where {|l| $l =~ $PATTERN }) | first $max
}

def main [
  name: string             # gate name, used for the log file
  ...cmd: string           # command to run
  --json                   # emit a record instead of text
  --log-dir: string = ".gates"
  --max: int = 20          # failure lines to show
] {
  if ($cmd | is-empty) { error make {msg: "no command given; usage: gate.nu <name> -- <cmd...>"} }
  mkdir $log_dir
  let log = ($log_dir | path join $"($name).log")
  let start = (date now)
  let r = (run-external ($cmd | first) ...($cmd | skip 1) | complete)
  let secs = ((date now) - $start | into int) / 1_000_000_000 | math round --precision 1
  $"($r.stdout)($r.stderr)" | save -f $log
  let ok = $r.exit_code == 0
  let lines = if $ok { [] } else { failures $"($r.stdout)\n($r.stderr)" $max }
  if $json {
    {gate: $name, status: (if $ok { "PASS" } else { "FAIL" }), exit: $r.exit_code, secs: $secs, log: $log, failures: $lines} | to json -r | print
  } else if $ok {
    print $"PASS ($name) ($secs)s"
  } else {
    print $"FAIL ($name) exit ($r.exit_code) log:($log)"
    $lines | each {|l| print $"  ($l)" } | ignore
  }
  exit $r.exit_code
}
