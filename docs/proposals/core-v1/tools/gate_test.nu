use std/assert
use gate.nu [dedupe failures]

def --wrapped gate [...args] { ^nu ($env.FILE_PWD | path join gate.nu) --log-dir $env.LOGDIR ...$args | complete }

def main [] {
  $env.LOGDIR = (mktemp -d)

  assert equal (dedupe [a b a a c]) ["a ×3" b c]
  assert equal (failures "ok\nERROR x\nERROR x\nfine\nFAIL y" 5) ["ERROR x ×2" "FAIL y"]
  assert equal (failures "ok\nwarning: a\nerror: b") ["warning: a"]
  assert equal (failures ((1..50 | each { $"error ($in)" }) | str join "\n") 5 | length) 5

  let p = (gate pass -- nu -c "print hello")
  assert equal $p.exit_code 0
  assert ($p.stdout | str starts-with "PASS pass")
  assert ($p.stdout !~ "hello")
  assert equal (open --raw ($env.LOGDIR | path join pass.log) | str trim) "hello"

  let f = (gate bad -- nu -c "print noise; print 'error: boom'; print 'error: boom'; exit 3")
  assert equal $f.exit_code 3
  assert equal ($f.stdout | lines) [$"FAIL bad exit 3 log:($env.LOGDIR)/bad.log" "  error: boom ×2"]

  let j = (gate bad --json -- nu -c "print 'FAIL t1'; exit 1" | get stdout | from json)
  assert equal [$j.status $j.exit $j.failures] ["FAIL" 1 ["FAIL t1"]]

  assert ((gate empty).exit_code != 0)

  let e = (gate missing --json -- nu -c "exit 127" | get stdout | from json)
  assert equal $e.status "ERROR"
  rm -rf $env.LOGDIR
  print "PASS gate_test"
}
