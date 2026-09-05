#!/usr/bin/env nu

# Regression test for claude-skills-340 (merge-write PreToolUse gate).
# Written by the test author (P2) BEFORE any implementation exists (P3
# implements next, forbidden from editing this file). This commit is
# EXPECTED TO BE RED: neither file below exists yet. That red is the spec,
# not a bug in this test — see /core:tdd and the issue's own note that the
# test-author commit is the one place `mise run ci` is expected to fail.
#
# claude-skills-340's own CRITICAL section is binding on this test too:
# this hook is a CHEAP DETERMINISTIC GATE, not a security boundary. Do NOT
# add cases hunting evasion ($( ), aliases, bash -c, subshells, brace
# groups, `!`/`time`/`then`/`do` prefixes, an emptied --match-head-commit=)
# — the issue names those out of scope BY DESIGN. Every case below traces
# to a rule or a test-matrix row stated in the issue; none hunt bypasses.
#
# ============================================================================
# FROZEN INTERFACE (chosen by this test author; document per claude-skills-340
# "You fix the interface" — the implementer must match this exactly)
# ============================================================================
#
# File 1 — scanner module:
#   plugins/core/skills/git/hooks/scan-merge-writes.nu
#
#   export def tokenize-command [command: string]: nothing -> list<list<string>>
#
#   Splits `command` into SEGMENTS on an UNQUOTED `;`, `&&`, `||`, `|`, `&`,
#   or newline. Returns a list of segments; each segment is a list of
#   dequoted token strings, in order.
#
#   Three quoting mechanisms while tokenizing a segment:
#     - a backslash outside single quotes escapes the next character
#       (the escaped character loses any special meaning, including as a
#       word-boundary space)
#     - double quotes suppress the special meaning of `'`
#     - single quotes suppress everything up to the next `'`
#   Adjacent quoted segments concatenate into ONE token (no gap between
#   them). A backslash immediately before a newline is a LINE CONTINUATION:
#   both characters are removed and tokenization continues — this is NOT a
#   segment split, unlike a bare (unescaped) newline.
#
#   On an unterminated quote, the function returns whatever segments/tokens
#   completed before the failure — it NEVER throws. A token still being
#   built when the unterminated quote is hit is dropped, not returned
#   partially.
#
#   No other exported function. No LIVE flag, no unreadability field in the
#   return shape — both existed in an earlier, superseded revision of this
#   issue to defeat evasion and are deliberately absent here (per the
#   issue's CRITICAL section and "You fix the interface" instruction to keep
#   the return shape to only what the rules need).
#
# File 2 — PreToolUse hook entrypoint:
#   plugins/core/skills/git/hooks/block-merge-writes.nu
#
#   Reads the Claude Code PreToolUse JSON payload from stdin — the same
#   shape the harness delivers: {"tool_name": "...", "tool_input":
#   {"command": "..."}}. Exits 2 (writing a reason to stderr, never the
#   command text back — this hook is not a security boundary but stderr
#   still shouldn't be silent) when the claude-skills-340 decision rules
#   block the command. Exits 0 otherwise: a non-Bash tool_name, malformed
#   or absent/empty stdin, and any command the decision rules do not block.
#   Applies the "neither `gh` nor `glab` anywhere in the raw command"
#   early-out before tokenizing, for the performance budget below.
#
# claude-skills-331 coordination: this issue establishes the shape: 331
# adopts it later. This test intentionally does not build a framework for
# 331's hook.
#
# ============================================================================
# How scanner unit tests call tokenize-command (a nushell `use` gotcha)
# ============================================================================
# `use` requires a PARSE-TIME-CONSTANT module path in nushell — a runtime
# variable (`use $module_path *`) is rejected with "Value is not a parse-time
# constant" (confirmed directly against nushell 0.113.1 while writing this
# test). So each scanner unit test writes a tiny one-shot nu script to a
# temp file with the module path substituted as plain text (this test
# script's own `$scanner` value, known before the child process starts —
# not runtime-computed INSIDE that child), then runs it as a subprocess and
# reads its stdout. The command string under test never gets embedded as a
# literal in that generated script — it travels through an environment
# variable instead, so quotes/backslashes/newlines under test never need
# escaping into nu string-literal syntax.
#
# Usage: nu test/validate-git-hook.nu

def scanner-path []: nothing -> string {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    $repo_root | path join "plugins" "core" "skills" "git" "hooks" "scan-merge-writes.nu"
}

def hook-path []: nothing -> string {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    $repo_root | path join "plugins" "core" "skills" "git" "hooks" "block-merge-writes.nu"
}

# Runs tokenize-command(command) in a fresh nu subprocess against the
# scanner module at `scanner`, returning {stdout, stderr, exit_code} via
# `complete`. Never throws even when `scanner` does not exist (RED case) —
# `nu $tmp | complete` reports a non-zero exit_code instead of aborting
# this script, the same shape validate-security-hook.nu relies on for
# `bash $hook | complete`.
def call-tokenize [scanner: string, command: string]: nothing -> record {
    let tmp = (mktemp --suffix .nu)
    let script = (
        "use \"" + $scanner + "\" *\n" +
        "let result = (tokenize-command $env.SCANNER_TEST_INPUT)\n" +
        "print ($result | to json -r)\n"
    )
    $script | save --force $tmp
    let out = (with-env {SCANNER_TEST_INPUT: $command} { nu $tmp | complete })
    rm -f $tmp
    $out
}

# Runs the real hook (Claude Code PreToolUse payload shape) with `command`
# in tool_input.command, tool_name "Bash". Returns {stdout, stderr,
# exit_code}.
def run-hook [hook: string, command: string]: nothing -> record {
    let payload = ({tool_name: "Bash", tool_input: {command: $command}} | to json -r)
    ($payload | nu $hook | complete)
}

# Sends `raw` verbatim as stdin — for malformed/absent-stdin robustness
# cases, where the input is deliberately not a valid PreToolUse payload.
def run-hook-raw [hook: string, raw: string]: nothing -> record {
    ($raw | nu $hook | complete)
}

# A well-formed PreToolUse payload for a DIFFERENT tool (not Bash) — for
# the tool_name robustness case.
def run-hook-wrong-tool [hook: string, command: string]: nothing -> record {
    let payload = ({tool_name: "Write", tool_input: {file_path: "/tmp/x", content: $command}} | to json -r)
    ($payload | nu $hook | complete)
}

def check [label: string, ok: bool]: nothing -> bool {
    if $ok {
        print $"(ansi green_bold)✅ ($label)(ansi reset)"
        true
    } else {
        print $"(ansi red_bold)❌ ($label)(ansi reset)"
        false
    }
}

def check-tokenize [scanner: string, label: string, command: string, want: list<list<string>>]: nothing -> bool {
    let result = (call-tokenize $scanner $command)
    if $result.exit_code != 0 {
        print $"(ansi red_bold)❌ ($label): scanner subprocess exited ($result.exit_code)(ansi reset)"
        print $"   stdout: ($result.stdout)"
        print $"   stderr: ($result.stderr)"
        false
    } else {
        let want_json = ($want | to json -r)
        let got_json = ($result.stdout | str trim)
        if $got_json == $want_json {
            print $"(ansi green_bold)✅ ($label)(ansi reset)"
            true
        } else {
            print $"(ansi red_bold)❌ ($label): want ($want_json), got ($got_json)(ansi reset)"
            false
        }
    }
}

def check-hook [label: string, result: record, want_exit: int]: nothing -> bool {
    if $result.exit_code != $want_exit {
        print $"(ansi red_bold)❌ ($label): want exit ($want_exit), got ($result.exit_code)(ansi reset)"
        print $"   stdout: ($result.stdout)"
        print $"   stderr: ($result.stderr)"
        false
    } else {
        print $"(ansi green_bold)✅ ($label)(ansi reset)"
        true
    }
}

# Builds a 64KB-scale single quoted token as DATA (never a literal in this
# file) that defeats the "neither gh nor glab anywhere" early-out: the
# filler surrounds a real `gh pr merge --admin` substring, but the whole
# thing is ONE argument to `git commit -m`, so the decision rules must
# still find "git" (not "gh"/"glab") as the segment's first token and PASS.
# `fill` is nu's built-in pad/repeat primitive (see references/language
# gotchas in /core:nushell) — chosen over a per-character loop specifically
# because claude-skills-340's own CRITICAL section measured a per-character
# accumulator at 65.8s for 64KB and a `fill`-built single 64KB token at 3ms.
def fixture-large-quoted-token []: nothing -> string {
    let filler = ("" | fill -c "a" -w 65536)
    let inner = $"($filler)gh pr merge --admin"
    "git commit -m \"" + $inner + "\""
}

# Builds ~21,000 space-separated two-character tokens (~62KB) ending in a
# real `gh pr merge --help` — as DATA, never a literal. Exercises the
# tokenizer's TOKEN-count scaling specifically (the issue's own budget note:
# "the single-token row cannot see a loop that is quadratic in TOKEN count").
def fixture-many-tokens []: nothing -> string {
    let word_count = 21000
    let words = (1..$word_count | each { "ab" } | str join " ")
    $"($words) gh pr merge --help"
}

# Gate 3 regression fixture: the same ~21,000 unquoted tokens as
# fixture-many-tokens, PLUS one quoted token, ending in a command that
# should PASS — as DATA, never a literal. Gate 3 measured directly on this
# machine, min-of-three, hook as subprocess: fixture-many-tokens (no
# quotes at all) took 95ms; the identical command with a single 'x' token
# added took 1030ms — a 10.8x blowup from ONE quote. The shipped scanner
# has a fast path and a slow path, and any quote anywhere in the command
# routes the WHOLE command through the slow one. Neither existing latency
# row can see this: PASSING #14 is a single 64KB quoted token with no bulk
# of surrounding tokens to blow up, and PASSING #15 has 21,000 tokens but
# no quote to trigger the slow path at all. This row exists specifically
# to catch a LONG command that merely CONTAINS a quoted argument — an
# entirely ordinary shape (`gh pr merge 286 --squash --body "..."`, any
# command with a quoted path).
def fixture-many-tokens-with-quote []: nothing -> string {
    let word_count = 21000
    let words = (1..$word_count | each { "ab" } | str join " ")
    $"($words) 'x' gh pr merge --help"
}

# Gate 3 regression fixture, THIRD dimension: SEGMENT count — as DATA,
# never a literal. Row #14 varies payload size and row #15 and the
# quoted-bulk row above vary TOKEN count; none of the three varies the
# number of SEGMENTS, which is exactly how a per-segment quadratic shipped
# undetected (the fix for the per-token quadratic grew a list with
# `append` inside a `for` loop over segments instead). Gate 3 measured
# directly on this machine, min-of-three, hook as subprocess, using `a;`
# repeated N times plus one quoted argument: 465ms at 2,000 segments,
# 1337ms at 4,000, 4654ms at 8,000 — clearly quadratic, and an everyday
# 5,000-line heredoc-shaped command with one quoted argument regressed
# from 1.6s on the old (per-token-quadratic) path to 6.05s on this one.
# Roughly 4,000 `;`-separated single-token segments plus one quoted
# argument, ending in a command that should PASS. Halved from an earlier
# 8,000 (claude-skills-340 recalibration): a segment-count quadratic still
# measures ~3.1s on the runner at 4,000 — nearly 4x over budget — while a
# correct linear implementation lands near 415ms there, so 4,000 catches
# the same defect at a smaller, cheaper fixture size.
def fixture-many-segments-with-quote []: nothing -> string {
    let segment_count = 4000
    let filler = (1..$segment_count | each { "a" } | str join ";")
    $"($filler);'x';gh pr merge --help"
}

# Gate 3 regression fixture, FOURTH dimension: DOUBLE-QUOTED SPAN COUNT —
# as DATA, never a literal. Neither of the three existing budget rows
# scales the number of double-quoted spans (`"a"`-shaped), and Gate 3
# found the cost there concentrated in the resolve step running one
# closure — `parse --regex` + `each` + `str join` — per span. Measured by
# the reviewer, min-of-three, on a quiet machine, a command built from
# repeated `"a"` spans: 16KB (~4,000 spans) 515ms, 32KB 970ms, 64KB 2.31s
# — linear-ish (1.9-2.4x per doubling) but past the 800ms budget by
# roughly 32KB, and about 6s on the runner at 64KB. Built from DOUBLE
# quotes specifically: Gate 3 also measured the single-quote series and
# found it non-monotonic (701ms at 64KB, 371ms at 96KB, reproduced twice,
# not understood) — double-quoted spans give the clean, monotonic scaling
# this row needs.
#
# On THIS machine, ~4,000 spans (16KB) measured 604.738ms — under this
# file's 800ms budget, unlike the reviewer's quieter environment where the
# same size was closer to the edge. Bumped to 6,000 spans (~24KB, measured
# 878.259ms here) so this row is a confirmed, genuine local RED rather
# than one that only fails on a different machine or the runner — the
# same environment-variance lesson the segment-count row's 500ms/8,000
# history already taught this suite. Still the same dimension (span
# COUNT) the AC's fourth row asks for, just carried one step further to
# survive local measurement.
def fixture-many-dq-spans []: nothing -> string {
    let span_count = 6000
    let spans = (1..$span_count | each { "\"a\"" } | str join " ")
    $"($spans) gh pr merge --help"
}

# Runs the hook 3 times against the same payload, returns the MINIMUM
# elapsed milliseconds (per claude-skills-340: "taking the MINIMUM of three
# runs" — a single wall-clock sample on a shared runner measures scheduling
# delay, not the hook) plus the exit_code/stderr from the last run (all 3
# runs are expected to agree on exit_code since the hook is deterministic).
def min-of-three-ms [hook: string, payload_json: string]: nothing -> record {
    mut best_ms = -1.0
    mut last_exit = -1
    mut last_stderr = ""
    for i in 1..3 {
        let t0 = (date now)
        let result = ($payload_json | nu $hook | complete)
        let t1 = (date now)
        let elapsed_ms = (($t1 - $t0) / 1ms)
        if $best_ms < 0.0 or $elapsed_ms < $best_ms {
            $best_ms = $elapsed_ms
        }
        $last_exit = $result.exit_code
        $last_stderr = $result.stderr
    }
    {min_ms: $best_ms, exit_code: $last_exit, stderr: $last_stderr}
}

def main [] {
    let scanner = (scanner-path)
    let hook = (hook-path)
    mut failed = false

    if not ($scanner | path exists) {
        print $"(ansi yellow)⚠️  scanner not found at ($scanner) — claude-skills-340 not yet implemented; scanner unit tests below are EXPECTED to fail(ansi reset)"
    }
    if not ($hook | path exists) {
        print $"(ansi yellow)⚠️  hook not found at ($hook) — claude-skills-340 not yet implemented; hook end-to-end tests below are EXPECTED to fail(ansi reset)"
    }

    # ==========================================================================
    # Scanner unit tests — tokenize-command contract only. Exactly the six
    # separators, the three quoting mechanisms, adjacent-quote concatenation,
    # backslash-newline continuation, and parse-failure recovery named in
    # claude-skills-340's "The scanner — only what the rules need" section.
    # Nothing else — no evasion hunting (see header).
    # ==========================================================================
    print "--- scanner: tokenize-command ---"

    let scanner_cases = [
        {label: "segment split on ;"
         cmd: "git status; git log"
         want: [["git" "status"] ["git" "log"]]}
        {label: "segment split on &&"
         cmd: "git add . && git commit"
         want: [["git" "add" "."] ["git" "commit"]]}
        {label: "segment split on ||"
         cmd: "false || true"
         want: [["false"] ["true"]]}
        {label: "segment split on |"
         cmd: "echo hi | cat"
         want: [["echo" "hi"] ["cat"]]}
        {label: "segment split on &"
         cmd: "sleep 1 & echo done"
         want: [["sleep" "1"] ["echo" "done"]]}
        {label: "segment split on newline"
         cmd: "echo one\necho two"
         want: [["echo" "one"] ["echo" "two"]]}
        {label: "double quotes suppress the special meaning of a single quote"
         cmd: "git commit -m \"it's fine\""
         want: [["git" "commit" "-m" "it's fine"]]}
        {label: "single quotes suppress everything to the next single quote"
         cmd: "git commit -m 'a $b \"c\"'"
         want: [["git" "commit" "-m" "a $b \"c\""]]}
        {label: "backslash outside single quotes escapes the next character"
         cmd: "echo a\\ b"
         want: [["echo" "a b"]]}
        {label: "adjacent quoted segments concatenate into one token"
         cmd: "git commit -m \"foo\"'bar'"
         want: [["git" "commit" "-m" "foobar"]]}
        {label: "backslash-newline is a line continuation, not a segment split"
         cmd: "gh pr merge \\\n286 --admin"
         want: [["gh" "pr" "merge" "286" "--admin"]]}
        {label: "unterminated quote returns the tokens completed before the failure"
         cmd: "git commit -m \"unterminated"
         want: [["git" "commit" "-m"]]}
    ]

    for c in $scanner_cases {
        if not (check-tokenize $scanner $c.label $c.cmd $c.want) {
            $failed = true
        }
    }

    # ==========================================================================
    # Hook end-to-end tests — BLOCKING and PASSING rows lifted VERBATIM from
    # claude-skills-340's "Test matrix" (enumerated on `·`: 15 BLOCKING, 15
    # PASSING, confirmed by splitting the raw bees description on that
    # delimiter rather than eyeballing the list). Every command string is
    # used exactly as the issue wrote it — no paraphrasing, no "fixing" its
    # quoting.
    # ==========================================================================
    print "--- hook: BLOCKING rows (expect exit 2) ---"

    let blocking_cases = [
        "gh pr merge 286 --auto"
        "gh pr merge 286 --admin"
        "gh pr merge 286 --squash"
        "gh -R o/r pr merge 286 --admin"
        "gh --repo o/r pr merge 286 --admin"
        "cd /tmp && gh pr merge 286 --admin"
        "gh pr merge \\\n286 --admin"
        "GH_TOKEN=x gh pr merge 286 --admin"
        "gh pr merge 286 --squash --auto --match-head-commit 8b60eabcf59edad3a49784e1c1684c3d996d0d60"
        "glab mr merge 12 --squash --yes"
        "gh api -X PUT repos/o/r/pulls/1/reviews/9/dismissals -f message=x"
        "gh api repos/o/r/pulls/1/reviews/9/dismissals --raw-field message=x"
        "gh api --method DELETE repos/o/r/issues/comments/12345"
        "gh api -XPUT repos/o/r/pulls/1/reviews/9/dismissals -f message=x"
        "gh api graphql -f query='mutation { enablePullRequestAutoMerge(input:{pullRequestId:\"x\"}){clientMutationId} }'"
    ]

    for cmd in $blocking_cases {
        let result = (run-hook $hook $cmd)
        if not (check-hook $"BLOCKING: ($cmd)" $result 2) {
            $failed = true
        }
    }

    # --- Gate 3 regression (F4): an under-block on a natural spelling. The
    # joined `-R` shorthand (`-Ro/r`, no space and no `=`) is a real gh
    # invocation an agent can type without trying to evade anything — the
    # AC's global-flag skip only names `-R`/`--repo`/`--hostname` as
    # separate tokens or `flag=value`, not this joined short-flag form, so
    # today's hook walks past "gh" straight into "-Ro/r" as if it were the
    # subcommand and never finds "pr merge" at all. Careless, not evasive:
    # in scope by the AC's own distinction. EXPECTED TO FAIL until fixed.
    let f4_result = (run-hook $hook "gh -Ro/r pr merge 286 --admin")
    if not (check-hook "Gate 3 regression (F4): joined `-Ro/r` global flag still reaches `pr merge --admin`, must block" $f4_result 2) {
        $failed = true
    }

    print "--- hook: PASSING rows (expect exit 0) ---"

    let passing_cases = [
        "gh api repos/o/r/pulls"
        "gh api -X get repos/o/r/pulls/1"
        "gh api \"repos/$OWNER/$REPO/issues/286/timeline\" --paginate"
        "gh api graphql -f query='query($name: String!, $owner: String!) { repository(owner:$owner,name:$name){id} }'"
        "gh api repos/o/r/issues/286/comments -F body=@review.md"
        "gh pr merge 286 --squash --match-head-commit 8b60eabcf59edad3a49784e1c1684c3d996d0d60"
        "gh pr merge --help"
        "glab mr merge --help"
        "glab mr merge 12 --squash --yes --auto-merge=false"
        "git grep -n -- \"gh pr merge --admin\""
        "git commit -m \"docs: clarify gh pr merge --admin is forbidden\""
        "echo \"unterminated"
        ""
    ]

    for cmd in $passing_cases {
        let result = (run-hook $hook $cmd)
        if not (check-hook $"PASSING: ($cmd)" $result 0) {
            $failed = true
        }
    }

    # --- Gate 3 regression (F1): a false positive on an everyday command.
    # A real backslash-newline continuation INSIDE a double-quoted --body
    # argument (an ordinary multi-line PR body). Built as an actual
    # embedded backslash + newline, not the escaped literal `\n` text.
    # Today's hook treats the backslash-newline inside double quotes as an
    # unterminated quote, so every token after it — including
    # --match-head-commit — is dropped, which is what makes it block. Per
    # the AC's own framing this is the worst defect class: a correctly
    # pinned merge with a multi-line body is ordinary work, and a gate
    # that blocks ordinary work gets switched off. EXPECTED TO FAIL until
    # fixed.
    let f1_cmd = "gh pr merge 286 --squash --body \"line one \\\nline two\" --match-head-commit abc123"
    let f1_result = (run-hook $hook $f1_cmd)
    if not (check-hook "Gate 3 regression (F1): backslash-newline inside a double-quoted --body must not drop --match-head-commit" $f1_result 0) {
        $failed = true
    }

    # --- Two latency rows (also PASSING rows #14/#15 of the matrix) ---
    # Both built as DATA via fixture-* helpers above, never as literals in
    # this file. Both asserted under 800ms taking the MINIMUM of three runs,
    # measured with the hook as a real subprocess (nu startup included, the
    # same cost the harness pays on every Bash call). 800ms per
    # claude-skills-340's second recalibration: 500ms (itself a bump from
    # an earlier 200ms) also failed remote CI — the segment-count row
    # measured 630ms on the runner against a 500ms budget while measuring
    # 237-268ms locally, a ~2.4x runner factor that is NOT the same factor
    # every row pays (payload-size ~2.4x, token-count ~3.5x, segment-count
    # ~2.4x). 800ms sits under the one-second PreToolUse figure
    # `/claude-code:claude-hooks` documents at its Best Practices section.
    print "--- hook: latency rows (PASSING #14/#15, min-of-3 < 800ms) ---"

    let large_token_cmd = (fixture-large-quoted-token)
    let large_token_payload = ({tool_name: "Bash", tool_input: {command: $large_token_cmd}} | to json -r)
    let large_token_timing = (min-of-three-ms $hook $large_token_payload)
    if not (check-hook "PASSING #14: 64KB single quoted token (defeats gh-substring early-out) exits 0" {exit_code: $large_token_timing.exit_code stdout: "" stderr: $large_token_timing.stderr} 0) {
        $failed = true
    }
    if not (check $"PASSING #14 latency: min-of-3 ($large_token_timing.min_ms)ms < 800ms" ($large_token_timing.min_ms < 800.0)) {
        $failed = true
    }

    let many_tokens_cmd = (fixture-many-tokens)
    let many_tokens_payload = ({tool_name: "Bash", tool_input: {command: $many_tokens_cmd}} | to json -r)
    let many_tokens_timing = (min-of-three-ms $hook $many_tokens_payload)
    if not (check-hook "PASSING #15: ~21,000-token command ending in `gh pr merge --help` exits 0" {exit_code: $many_tokens_timing.exit_code stdout: "" stderr: $many_tokens_timing.stderr} 0) {
        $failed = true
    }
    if not (check $"PASSING #15 latency: min-of-3 ($many_tokens_timing.min_ms)ms < 800ms" ($many_tokens_timing.min_ms < 800.0)) {
        $failed = true
    }

    # --- Gate 3 regression row: a long, mostly-unquoted command that
    # CONTAINS a single quoted token (see fixture-many-tokens-with-quote
    # above for the measured 10.8x blowup this catches). Combines the
    # exit-code and timing checks into ONE assertion — a slow-but-correct
    # implementation and a fast-but-wrong one are both real defects here,
    # and either should fail this single row. The implementation at
    # 77d8e07 has already removed the slow path this row was written
    # against, so this row now guards against a REGRESSION of that fix
    # rather than pinning a known-still-broken defect.
    print "--- hook: Gate 3 regression row (long command with an embedded quote, min-of-3 < 800ms) ---"
    let quoted_bulk_cmd = (fixture-many-tokens-with-quote)
    let quoted_bulk_payload = ({tool_name: "Bash", tool_input: {command: $quoted_bulk_cmd}} | to json -r)
    let quoted_bulk_timing = (min-of-three-ms $hook $quoted_bulk_payload)
    if not (check $"Gate 3 regression: ~21,000 tokens + one quoted arg, exit ($quoted_bulk_timing.exit_code) \(want 0\), min-of-3 ($quoted_bulk_timing.min_ms)ms < 800ms" ($quoted_bulk_timing.exit_code == 0 and $quoted_bulk_timing.min_ms < 800.0)) {
        $failed = true
    }

    # --- Gate 3 regression row, THIRD dimension: SEGMENT count (see
    # fixture-many-segments-with-quote above for the measured quadratic —
    # 465ms/1337ms/4654ms at 2,000/4,000/8,000 segments). Neither this
    # file's payload-size row (#14) nor its token-count rows (#15, the
    # quoted-bulk row above) vary the number of `;`-separated segments, so
    # a quadratic keyed to segment count is invisible to all three of
    # them — this row exists specifically to make that dimension visible.
    # Combines exit-code and timing into ONE assertion, same rationale as
    # the token-count budget row above. The implementation at 77d8e07 has
    # already removed the per-segment `append`-in-a-loop this row was
    # written against, so this row now guards against a REGRESSION of
    # that fix rather than pinning a known-still-broken defect.
    print "--- hook: Gate 3 regression row (long command with ~4,000 segments, min-of-3 < 800ms) ---"
    let many_segments_cmd = (fixture-many-segments-with-quote)
    let many_segments_payload = ({tool_name: "Bash", tool_input: {command: $many_segments_cmd}} | to json -r)
    let many_segments_timing = (min-of-three-ms $hook $many_segments_payload)
    if not (check $"Gate 3 regression: ~4,000 `;`-separated segments + one quoted arg, exit ($many_segments_timing.exit_code) \(want 0\), min-of-3 ($many_segments_timing.min_ms)ms < 800ms" ($many_segments_timing.exit_code == 0 and $many_segments_timing.min_ms < 800.0)) {
        $failed = true
    }

    # --- Gate 3 regression row, FOURTH dimension: DOUBLE-QUOTED SPAN
    # count (see fixture-many-dq-spans above for the measured linear-ish
    # 515ms/970ms/2.31s at 16KB/32KB/64KB and why 6,000 spans, not the
    # AC's ~4,000, is what this file actually asserts). None of the other
    # three rows scales the number of double-quoted spans, which is
    # exactly how this cost stayed invisible to payload-size, token-count,
    # and segment-count. Combines exit-code and timing into ONE assertion,
    # same rationale as the other budget rows. EXPECTED TO FAIL: unlike
    # the token-count and segment-count slow paths, this one has not been
    # fixed as of this commit — this is a red test against the shipped
    # implementation, not a bug in this suite.
    print "--- hook: Gate 3 regression row (long command with ~6,000 double-quoted spans, min-of-3 < 800ms) ---"
    let many_dq_spans_cmd = (fixture-many-dq-spans)
    let many_dq_spans_payload = ({tool_name: "Bash", tool_input: {command: $many_dq_spans_cmd}} | to json -r)
    let many_dq_spans_timing = (min-of-three-ms $hook $many_dq_spans_payload)
    if not (check $"Gate 3 regression: ~6,000 double-quoted spans, exit ($many_dq_spans_timing.exit_code) \(want 0\), min-of-3 ($many_dq_spans_timing.min_ms)ms < 800ms" ($many_dq_spans_timing.exit_code == 0 and $many_dq_spans_timing.min_ms < 800.0)) {
        $failed = true
    }

    # ==========================================================================
    # Robustness: malformed stdin, absent/empty stdin, non-Bash tool_name —
    # all exit 0 without a stack trace (claude-skills-340 "Robustness").
    # ==========================================================================
    print "--- hook: robustness ---"

    # A bare unquoted string with no leading `{`/`[` is NOT guaranteed to
    # make nu's `from json` raise — confirmed directly against nushell
    # 0.113.1: `"not valid json {{{" | from json` returns that string
    # UNCHANGED (exit 0, no error) rather than failing. `"{ this is not
    # json"` (an opening brace that never closes) reliably raises a real
    # JSON parse error, which is the actual malformed-input path a
    # `try`/`catch` in the hook needs to exercise.
    let malformed_result = (run-hook-raw $hook "{ this is not json")
    if not (check-hook "robustness: malformed (unparseable) JSON stdin exits 0" $malformed_result 0) {
        $failed = true
    }

    # "Absent stdin" observed as a zero-byte pipe — the harness always
    # delivers SOME stdin to a PreToolUse hook, so a truly detached stdin
    # never occurs in production; a zero-byte read is the closest faithful
    # reproduction and is what a script reading stdin via an external
    # command (e.g. `^cat`) actually observes in both cases.
    let absent_result = (run-hook-raw $hook "")
    if not (check-hook "robustness: absent/empty stdin exits 0" $absent_result 0) {
        $failed = true
    }

    let wrong_tool_result = (run-hook-wrong-tool $hook "gh pr merge 286 --admin")
    if not (check-hook "robustness: tool_name other than Bash exits 0" $wrong_tool_result 0) {
        $failed = true
    }

    # --- Gate 3 regression (F2): a traceback where the AC requires a
    # clean exit. tool_input.command is a JSON NUMBER, not a string — a
    # malformed payload shape the AC's Robustness section covers ("exits 0
    # without a stack trace"), distinct from the unparseable-JSON and
    # empty-stdin cases above (this payload parses as valid JSON; the
    # defect is in what the hook does with a well-formed-but-wrong-typed
    # field). Asserts BOTH exit 0 AND that stderr carries no "Error:" line
    # — an implementation could exit 0 while still leaking a caught
    # traceback to stderr, which this pins as equally wrong. EXPECTED TO
    # FAIL until fixed.
    let f2_result = (run-hook-raw $hook '{"tool_name":"Bash","tool_input":{"command":42}}')
    if not (check $"Gate 3 regression \(F2\): non-string tool_input.command exits 0 with no traceback \(exit=($f2_result.exit_code)\)" ($f2_result.exit_code == 0 and not ($f2_result.stderr | str contains "Error:"))) {
        $failed = true
    }

    # ==========================================================================
    # Summary / self-check: confirm the case counts actually match
    # claude-skills-340's stated matrix (15 BLOCKING, 15 PASSING) rather than
    # trusting the literal lists above by eye.
    # ==========================================================================
    print ""
    let passing_total = ($passing_cases | length) + 2
    print $"scanner unit tests: ($scanner_cases | length)"
    print $"BLOCKING rows: ($blocking_cases | length) \(want 15\)"
    print $"PASSING rows, plain plus the 2 latency rows checked separately above: ($passing_total) \(want 15\)"
    if ($blocking_cases | length) != 15 {
        print $"(ansi red_bold)❌ BLOCKING row count drifted from the issue's matrix(ansi reset)"
        $failed = true
    }
    if $passing_total != 15 {
        print $"(ansi red_bold)❌ PASSING row count drifted from the issue's matrix(ansi reset)"
        $failed = true
    }
    print "Gate 3 regression rows (beyond the AC's 15/15 matrix): 6 — quoted-bulk (token-count) budget row, segment-count budget row, dq-span-count budget row, F1 (backslash-newline in --body), F2 (non-string command), F4 (joined -Ro/r)"

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ merge-write gate: scanner and hook verified(ansi reset)"
}
