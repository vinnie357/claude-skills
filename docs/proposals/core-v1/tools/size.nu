# Review budget gate: fail when a diff is too large for a reviewer to hold in context.
# Tokens are estimated as bytes / 4 (approximate; no tokenizer).
#   nu size.nu --base origin/main
#   REVIEW_WINDOW=200000 REVIEW_SHARE=0.1 nu size.nu

# Token estimate for a diff and the budget it must fit.
export def budget [diff_bytes: int, window: int, share: float]: nothing -> record {
  let tokens = $diff_bytes // 4
  let limit = ($window * $share | into int)
  {tokens: $tokens, limit: $limit, ok: ($tokens <= $limit)}
}

def main [
  --base: string = "origin/main"   # compare HEAD against this ref
  --json
] {
  let window = ($env.REVIEW_WINDOW? | default "200000" | into int)  # smallest reviewer context
  let share = ($env.REVIEW_SHARE? | default "0.1" | into float)     # part of it a diff may use
  let diff = (^git diff $"($base)...HEAD" | complete)
  if $diff.exit_code != 0 { print $"ERROR size git diff failed: ($diff.stderr | str trim)"; exit 2 }
  let b = (budget ($diff.stdout | str length --utf-8-bytes) $window $share)
  let files = (^git diff --name-only $"($base)...HEAD" | lines | length)
  let status = if $b.ok { "PASS" } else { "FAIL" }
  if $json {
    $b | insert files $files | insert status $status | to json -r | print
  } else {
    print $"($status) size ~($b.tokens) tokens / ($b.limit) budget, ($files) files"
    if not $b.ok { print "  split the change: one issue, one focused diff" }
  }
  exit (if $b.ok { 0 } else { 1 })
}
