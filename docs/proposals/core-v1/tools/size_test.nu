use std/assert
use size.nu budget

def main [] {
  assert equal (budget 80000 200000 0.1) {tokens: 20000, limit: 20000, ok: true}
  assert equal (budget 80004 200000 0.1).ok false
  assert equal (budget 400000 1000000 0.1).ok true

  let repo = (mktemp -d)
  cd $repo
  ^git init -q -b main; ^git config user.email t@example.com; ^git config user.name t
  "a" | save a.txt; ^git add .; ^git commit -qm init
  ^git checkout -q -b work
  (1..2000 | each { "line of change" } | str join "\n") | save b.txt; ^git add .; ^git commit -qm big
  let me = ($env.FILE_PWD | path join size.nu)
  let small = (with-env {REVIEW_WINDOW: "1000000"} { ^nu $me --base main --json | complete })
  assert equal $small.exit_code 0
  let big = (with-env {REVIEW_WINDOW: "10000"} { ^nu $me --base main | complete })
  assert equal $big.exit_code 1
  assert ($big.stdout | str starts-with "FAIL size")
  cd /; rm -rf $repo
  print "PASS size_test"
}
