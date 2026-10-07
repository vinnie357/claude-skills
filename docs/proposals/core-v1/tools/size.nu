# Review gate: size a diff, pick how much review it gets, fail when it is too big to review.
# Tokens are estimated as bytes / 4 (approximate; no tokenizer).
#   nu size.nu --base origin/main
#
# Tiers (starting points to tune by experiment, not measured thresholds):
#   gates  ≤ REVIEW_GATES_TOKENS (500), no risky path: passing gates are the review
#   light  ≤ REVIEW_LIGHT_TOKENS (4000), no risky path: one reviewer, diff only, low effort
#   full   anything larger, or any path matching REVIEW_RISK_PATHS: diff plus touched code
#   split  over REVIEW_WINDOW × REVIEW_SHARE: not reviewed; split the issue
# REVIEW_RISK_PATHS is a project setting: regexes separated by '|', for example
#   'auth|secret|migrations/|\.github/workflows/|mise\.toml'

# Token estimate for a diff and the budget it must fit.
export def budget [diff_bytes: int, window: int, share: float]: nothing -> record {
  let tokens = $diff_bytes // 4
  let limit = ($window * $share | into int)
  {tokens: $tokens, limit: $limit, ok: ($tokens <= $limit)}
}

# Review tier for a diff of `tokens` touching `files`.
export def tier [tokens: int, files: list<string>, limit: int, gates: int, light: int, risk: string]: nothing -> record {
  let risky = if ($risk | is-empty) { [] } else { $files | where {|f| $f =~ $risk } }
  let t = if $tokens > $limit { "split" } else if not ($risky | is-empty) { "full" } else if $tokens <= $gates { "gates" } else if $tokens <= $light { "light" } else { "full" }
  {tier: $t, risky: $risky}
}

def main [
  --base: string = "origin/main"   # compare HEAD against this ref
  --json
] {
  let window = ($env.REVIEW_WINDOW? | default "200000" | into int)  # smallest reviewer context
  let share = ($env.REVIEW_SHARE? | default "0.1" | into float)     # part of it a diff may use
  let gates = ($env.REVIEW_GATES_TOKENS? | default "500" | into int)
  let light = ($env.REVIEW_LIGHT_TOKENS? | default "4000" | into int)
  let risk = ($env.REVIEW_RISK_PATHS? | default "")
  let diff = (^git diff $"($base)...HEAD" | complete)
  if $diff.exit_code != 0 { print $"ERROR size git diff failed: ($diff.stderr | str trim)"; exit 2 }
  let b = (budget ($diff.stdout | str length --utf-8-bytes) $window $share)
  let files = (^git diff --name-only $"($base)...HEAD" | lines)
  let r = (tier $b.tokens $files $b.limit $gates $light $risk)
  let status = if $r.tier == "split" { "FAIL" } else { "PASS" }
  if $json {
    $b | insert files ($files | length) | insert review $r.tier | insert risky $r.risky | insert status $status | to json -r | print
  } else {
    print $"($status) size ~($b.tokens) tokens / ($b.limit) budget, ($files | length) files, review: ($r.tier)"
    if not ($r.risky | is-empty) { print $"  risky: ($r.risky | str join ', ')" }
    if $r.tier == "split" { print "  split the change: one issue, one focused diff" }
  }
  exit (if $r.tier == "split" { 1 } else { 0 })
}
