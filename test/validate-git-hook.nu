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

    # --- Two latency rows (also PASSING rows #14/#15 of the matrix) ---
    # Both built as DATA via fixture-* helpers above, never as literals in
    # this file. Both asserted under 200ms taking the MINIMUM of three runs,
    # measured with the hook as a real subprocess (nu startup included, the
    # same cost the harness pays on every Bash call).
    print "--- hook: latency rows (PASSING #14/#15, min-of-3 < 200ms) ---"

    let large_token_cmd = (fixture-large-quoted-token)
    let large_token_payload = ({tool_name: "Bash", tool_input: {command: $large_token_cmd}} | to json -r)
    let large_token_timing = (min-of-three-ms $hook $large_token_payload)
    if not (check-hook "PASSING #14: 64KB single quoted token (defeats gh-substring early-out) exits 0" {exit_code: $large_token_timing.exit_code stdout: "" stderr: $large_token_timing.stderr} 0) {
        $failed = true
    }
    if not (check $"PASSING #14 latency: min-of-3 ($large_token_timing.min_ms)ms < 500ms" ($large_token_timing.min_ms < 500.0)) {
        $failed = true
    }

    let many_tokens_cmd = (fixture-many-tokens)
    let many_tokens_payload = ({tool_name: "Bash", tool_input: {command: $many_tokens_cmd}} | to json -r)
    let many_tokens_timing = (min-of-three-ms $hook $many_tokens_payload)
    if not (check-hook "PASSING #15: ~21,000-token command ending in `gh pr merge --help` exits 0" {exit_code: $many_tokens_timing.exit_code stdout: "" stderr: $many_tokens_timing.stderr} 0) {
        $failed = true
    }
    if not (check $"PASSING #15 latency: min-of-3 ($many_tokens_timing.min_ms)ms < 500ms" ($many_tokens_timing.min_ms < 500.0)) {
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

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ merge-write gate: scanner and hook verified(ansi reset)"
}
