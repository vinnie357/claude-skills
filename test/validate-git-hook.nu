#!/usr/bin/env nu

# Regression / spec test for claude-skills-340: a PreToolUse Bash hook that
# blocks the forbidden MERGE-PATH writes documented in /core:git's
# "Merge authorization" section (`gh pr merge --auto`/`--admin`, `glab mr
# merge` without `--auto-merge=false`, review-dismissal and Gate-3-comment-
# deletion via `gh api`) — the class of write the shipped precondition
# (PR #285/#286) can only detect AFTER the fact, never prevent.
#
# TDD SPLIT: this file is written by the test author (P2). It is FROZEN on
# commit — a separate implementer (P3) makes it pass without editing it.
# Two target files do NOT exist yet at the time this test is written:
#   plugins/core/skills/git/hooks/posix-scan.nu               (the scanner)
#   plugins/core/skills/git/hooks/block-forbidden-merge-writes.nu (the hook)
# Running this file against a repo state without those files is EXPECTED to
# fail — that red is the specification, not a defect in this test.
#
# ==========================================================================
# THE SCANNER CONTRACT this test compiles against (claude-skills-340 AC
# "The scanner" section). posix-scan.nu MUST export exactly this:
#
#   export def scan-posix-command [cmd: string] {
#       # returns a record: {parse_ok: bool, segments: list<list<record<value: string, live: bool>>>}
#   }
#
# - segments: an unquoted `;`, `&&`, `||`, `|`, `&`, or newline ends a
#   segment; each segment is itself a list of tokens.
# - token: {value: string, live: bool} — `value` is the fully DEQUOTED
#   token text; `live` is true iff the token carries an expansion the shell
#   would run (backtick, `$(`, `<(`, or a bare `$`) OUTSIDE single quotes
#   and not backslash-escaped.
# - parse_ok is false ONLY for an unterminated `'`, `"`, backtick, or `$(`;
#   the tokens completed before the failure point are still returned.
#
# This is the interface the hook end-to-end tests below exercise
# indirectly (through block-forbidden-merge-writes.nu's decision logic) and
# the scanner unit tests exercise directly. Both families are frozen
# together — the implementer builds posix-scan.nu to this exact shape.
# ==========================================================================
#
# Usage: nu test/validate-git-hook.nu

# --- Scanner invocation helper -------------------------------------------
#
# Spawns a throwaway nu script that `source`s posix-scan.nu (a *literal*
# path baked into the generated file's text, not a variable — nushell's
# `source`/`use` parser keywords require a constant expression, so passing
# $scanner as a runtime value directly to `source` would be a parse error,
# not a "file not found" runtime error) and calls scan-posix-command with
# the command-under-test passed through $env.SCAN_CMD (an environment
# variable sidesteps all nu string-interpolation/quoting hazards for
# adversarial input containing quotes, backticks, and `$(`).
#
# Returns {exit_code, stdout, stderr} from `complete`. When posix-scan.nu
# does not exist, `source` fails while nu parses the generated runner
# script and the external `nu` process exits non-zero with a "file not
# found"-shaped stderr — this is the expected RED for every scanner case
# below until the implementer creates the file.
def run-scanner [cmd: string] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let scanner = ($repo_root | path join "plugins" "core" "skills" "git" "hooks" "posix-scan.nu")
    let runner_dir = (mktemp -d)
    let runner = ($runner_dir | path join "run.nu")
    $"source \"($scanner)\"\nscan-posix-command $env.SCAN_CMD | to json\n" | save --force $runner
    let result = (with-env {SCAN_CMD: $cmd} { ^nu $runner | complete })
    rm -rf $runner_dir
    $result
}

# Runs a scanner case: decodes JSON on success, applies `predicate` (a
# closure taking the decoded record and returning bool) to the result, and
# prints pass/fail. Prints the scanner's raw stderr on invocation failure
# (missing file, parse error) so the RED reason is visible in the output —
# per claude-skills-340's instruction to "confirm the red is the right
# red" and report the verbatim failure text.
def check-scanner [label: string, cmd: string, predicate: closure] {
    let r = (run-scanner $cmd)
    if $r.exit_code != 0 {
        print $"(ansi red_bold)❌ ($label): scanner invocation failed \(exit ($r.exit_code)\)(ansi reset)"
        print $"   stderr: ($r.stderr | str trim)"
        false
    } else {
        # `complete` only accepts external-command input on nushell 0.113.1
        # ("Complete only works with external commands") — `from json` is a
        # builtin, so piping its result through `| complete` aborts the
        # WHOLE test script the moment posix-scan.nu exists and returns
        # parseable JSON, taking every remaining case (scanner AND hook
        # matrix) down with it. `try`/`catch` is the correct guard here.
        let decoded = (try { $r.stdout | from json } catch { null })
        if $decoded == null {
            print $"(ansi red_bold)❌ ($label): scanner output was not valid JSON(ansi reset)"
            print $"   stdout: ($r.stdout | str trim)"
            false
        } else {
            # A predicate indexing a short/malformed list (`get 1`, `get 2`,
            # `where ... | get 0`) raises rather than returning false under
            # a wrong implementation — wrapped so the run reports every
            # failing case instead of dying at the first structural
            # mismatch.
            if (try { do $predicate $decoded } catch { false }) {
                print $"(ansi green_bold)✅ ($label)(ansi reset)"
                true
            } else {
                print $"(ansi red_bold)❌ ($label): predicate failed against decoded scanner output(ansi reset)"
                print $"   data: ($decoded | to json)"
                false
            }
        }
    }
}

# --- Hook invocation helper -----------------------------------------------
#
# Invokes block-forbidden-merge-writes.nu the way the Claude Code harness
# invokes a PreToolUse Bash hook: a JSON payload on stdin shaped
# {"tool_name":"Bash","tool_input":{"command":"..."}}. Returns
# {exit_code, stdout, stderr} from `complete`. When the hook script does
# not exist, `^nu $hook` fails at the OS/interpreter level with a
# file-not-found error and a non-zero exit code — the expected RED for
# every hook matrix case below until the implementer creates the file.
def run-hook [hook: string, command: string] {
    let input = ({tool_name: "Bash", tool_input: {command: $command}} | to json)
    $input | ^nu $hook | complete
}

# Asserts result.exit_code == want_exit, prints pass/fail, returns a bool
# so the caller can accumulate $failed without check() mutating an outer
# variable itself. Mirrors test/validate-security-hook.nu's check().
def check [label: string, result: record, want_exit: int] {
    if $result.exit_code != $want_exit {
        print $"(ansi red_bold)❌ ($label): want exit ($want_exit), got ($result.exit_code)(ansi reset)"
        print $"   stdout: ($result.stdout | str trim)"
        print $"   stderr: ($result.stderr | str trim)"
        false
    } else {
        print $"(ansi green_bold)✅ ($label)(ansi reset)"
        true
    }
}

def main [] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let scanner = ($repo_root | path join "plugins" "core" "skills" "git" "hooks" "posix-scan.nu")
    let hook = ($repo_root | path join "plugins" "core" "skills" "git" "hooks" "block-forbidden-merge-writes.nu")

    mut failed = false

    if not ($scanner | path exists) {
        print $"(ansi yellow)⚠️  scanner not found at ($scanner) — every scanner case below is expected to fail until claude-skills-340 lands the implementation(ansi reset)"
    }
    if not ($hook | path exists) {
        print $"(ansi yellow)⚠️  hook not found at ($hook) — every hook matrix case below is expected to fail until claude-skills-340 lands the implementation(ansi reset)"
    }

    # ======================================================================
    # SCANNER UNIT TESTS — posix-scan.nu, called directly (not through the
    # hook). Each case pins one bullet from the AC's "The scanner" section.
    # ======================================================================

    # --- Segmentation: unquoted separators end a segment ---
    if not (check-scanner "Scan 1: `;` ends a segment" "gh pr merge 286 --admin; echo done" {|d|
        ($d.segments | length) == 2 and ($d.segments | get 0 | get 0 | get value) == "gh" and ($d.segments | get 1 | get 0 | get value) == "echo"
    }) { $failed = true }

    # Load-bearing example from the AC itself: position-0 anchoring WITHOUT
    # segmentation is the exact defect claude-skills-271 shipped and fixed
    # in the security hook (see gitleaks-usage.md:81) — this pins that the
    # new scanner does not repeat it. `cd` must land at segment-0 position-0
    # and `gh` at segment-1 position-0.
    if not (check-scanner "Scan 2: `&&` ends a segment (`cd ~/repo && gh pr merge --admin 286`)" "cd ~/repo && gh pr merge --admin 286" {|d|
        ($d.segments | length) == 2 and ($d.segments | get 0 | get 0 | get value) == "cd" and ($d.segments | get 1 | get 0 | get value) == "gh"
    }) { $failed = true }

    if not (check-scanner "Scan 3: `||` ends a segment" "false || gh pr merge 286 --admin" {|d|
        ($d.segments | length) == 2 and ($d.segments | get 1 | get 0 | get value) == "gh"
    }) { $failed = true }

    if not (check-scanner "Scan 4: `|` ends a segment" "gh pr list | cat" {|d|
        ($d.segments | length) == 2 and ($d.segments | get 0 | get 0 | get value) == "gh" and ($d.segments | get 1 | get 0 | get value) == "cat"
    }) { $failed = true }

    if not (check-scanner "Scan 5: `&` ends a segment" "sleep 1 & gh pr merge 286 --admin" {|d|
        ($d.segments | length) == 2 and ($d.segments | get 1 | get 0 | get value) == "gh"
    }) { $failed = true }

    if not (check-scanner "Scan 6: newline ends a segment" (r#'echo hi
gh pr merge 286 --admin'#) {|d|
        ($d.segments | length) == 2 and ($d.segments | get 1 | get 0 | get value) == "gh"
    }) { $failed = true }

    # A separator INSIDE single quotes is literal, not a segment boundary.
    if not (check-scanner "Scan 7: quoted `;` does not split the segment" (r#'echo 'a;b''#) {|d|
        ($d.segments | length) == 1 and ($d.segments | get 0 | length) == 2 and ($d.segments | get 0 | get 1 | get value) == "a;b"
    }) { $failed = true }

    if not (check-scanner "Scan 8: parse_ok is true on ordinary well-formed input" "gh pr merge 286 --admin" {|d|
        $d.parse_ok == true
    }) { $failed = true }

    # --- Quoting mechanisms ---
    if not (check-scanner "Scan 9: single quotes suppress `$` (literal, not LIVE)" (r#'echo '$HOME''#) {|d|
        let tok = ($d.segments | get 0 | get 1)
        $tok.value == "$HOME" and $tok.live == false
    }) { $failed = true }

    if not (check-scanner "Scan 10: double quotes suppress `'` but not `$`" (r#'echo "a'b $HOME"'#) {|d|
        let tok = ($d.segments | get 0 | get 1)
        $tok.value == "a'b $HOME" and $tok.live == true
    }) { $failed = true }

    if not (check-scanner "Scan 11: backslash outside quotes escapes the next char (escaped space is not a separator)" (r#'echo foo\ bar'#) {|d|
        ($d.segments | get 0 | length) == 2 and ($d.segments | get 0 | get 1 | get value) == "foo bar"
    }) { $failed = true }

    if not (check-scanner "Scan 12: adjacent quoted segments concatenate into one token" (r#'echo 'foo'"bar"'#) {|d|
        ($d.segments | get 0 | length) == 2 and ($d.segments | get 0 | get 1 | get value) == "foobar"
    }) { $failed = true }

    # --- LIVE flag ---
    if not (check-scanner "Scan 13: backtick outside quotes is LIVE" (r#'echo `date`'#) {|d|
        ($d.segments | get 0 | get 1 | get live) == true
    }) { $failed = true }

    if not (check-scanner "Scan 14: `$(` outside quotes is LIVE" (r#'echo $(date)'#) {|d|
        ($d.segments | get 0 | get 1 | get live) == true
    }) { $failed = true }

    if not (check-scanner "Scan 15: `<(` outside quotes is LIVE" (r#'diff <(a) <(b)'#) {|d|
        ($d.segments | get 0 | get 1 | get live) == true
    }) { $failed = true }

    if not (check-scanner "Scan 16: bare `$` outside quotes is LIVE" (r#'echo $FOO'#) {|d|
        ($d.segments | get 0 | get 1 | get live) == true
    }) { $failed = true }

    if not (check-scanner "Scan 17: `$` inside single quotes is NOT LIVE (single-quote suppression case)" (r#'echo '$FOO''#) {|d|
        ($d.segments | get 0 | get 1 | get live) == false
    }) { $failed = true }

    if not (check-scanner "Scan 18: backslash-escaped `\$` outside quotes is NOT LIVE" (r#'echo \$FOO'#) {|d|
        let tok = ($d.segments | get 0 | get 1)
        $tok.live == false and $tok.value == "$FOO"
    }) { $failed = true }

    # --- Parse failure: unterminated forms only ---
    if not (check-scanner "Scan 19: unterminated `'` -> parse_ok false, completed tokens still returned" (r#'echo 'oops'#) {|d|
        $d.parse_ok == false and ($d.segments | get 0 | get 0 | get value) == "echo"
    }) { $failed = true }

    if not (check-scanner "Scan 20: unterminated `\"` -> parse_ok false, completed tokens still returned" (r#'echo "oops'#) {|d|
        $d.parse_ok == false and ($d.segments | get 0 | get 0 | get value) == "echo"
    }) { $failed = true }

    if not (check-scanner "Scan 21: unterminated backtick -> parse_ok false, completed tokens still returned" (r#'echo `oops'#) {|d|
        $d.parse_ok == false and ($d.segments | get 0 | get 0 | get value) == "echo"
    }) { $failed = true }

    if not (check-scanner "Scan 22: unterminated `\$(` -> parse_ok false, completed tokens still returned" (r#'echo $(oops'#) {|d|
        $d.parse_ok == false and ($d.segments | get 0 | get 0 | get value) == "echo"
    }) { $failed = true }

    if not (check-scanner "Scan 23: a trailing backslash is a literal backslash, NOT a parse failure" (r#'echo foo\'#) {|d|
        $d.parse_ok == true
    }) { $failed = true }

    # --- Comments: `#` starts a comment only at the start of a word ---
    if not (check-scanner "Scan 24: unquoted `#` at the start of a word begins a comment and ends the segment" "gh pr merge --admin 286 #comment" {|d|
        # Five tokens precede the comment: gh, pr, merge, --admin, 286.
        ($d.segments | length) == 1 and ($d.segments | get 0 | length) == 5
    }) { $failed = true }

    if not (check-scanner "Scan 25: `#` mid-word is literal (keeps its suffix)" "gh api repos/o/r/pulls/1#frag" {|d|
        ($d.segments | get 0 | get 2 | get value) == "repos/o/r/pulls/1#frag"
    }) { $failed = true }

    # --- Defined edges ---
    if not (check-scanner "Scan 26: empty input yields zero segments" "" {|d|
        ($d.segments | length) == 0
    }) { $failed = true }

    if not (check-scanner "Scan 27: whitespace-only input yields zero segments" "   " {|d|
        ($d.segments | length) == 0
    }) { $failed = true }

    if not (check-scanner "Scan 28: an empty quoted token is emitted, not omitted" (r#'gh api ""'#) {|d|
        ($d.segments | get 0 | length) == 3 and ($d.segments | get 0 | get 2 | get value) == ""
    }) { $failed = true }

    if not (check-scanner "Scan 29: a trailing bare `\$` is LIVE" (r#'echo foo$'#) {|d|
        ($d.segments | get 0 | get 1 | get live) == true
    }) { $failed = true }

    if not (check-scanner "Scan 30: `\$(` tracks nesting depth -- a nested substitution stays one token" (r#'echo $(foo $(bar) baz)'#) {|d|
        $d.parse_ok == true and ($d.segments | get 0 | length) == 2 and ($d.segments | get 0 | get 1 | get live) == true
    }) { $failed = true }

    if not (check-scanner "Scan 31: a bare `<` not followed by `(` is NOT LIVE" (r#'echo 1 < file.txt'#) {|d|
        let toks = ($d.segments | get 0)
        ($toks | where value == "<" | get 0 | get live) == false
    }) { $failed = true }

    # ======================================================================
    # HOOK END-TO-END TESTS — block-forbidden-merge-writes.nu, invoked with
    # a PreToolUse payload on stdin. Every BLOCKING row expects exit 2;
    # every PASSING row expects exit 0. Command strings are transcribed
    # VERBATIM from the claude-skills-340 acceptance criteria's "Required
    # test matrix" — do not paraphrase or "fix" their quoting.
    # ======================================================================

    let blocking_cases = [
        {label: "Block 1: `gh pr merge 286 --auto`" cmd: (r#'gh pr merge 286 --auto'#)}
        {label: "Block 2: `gh pr merge 286 --admin`" cmd: (r#'gh pr merge 286 --admin'#)}
        {label: "Block 3: `gh pr merge 286 --squash` (missing --match-head-commit)" cmd: (r#'gh pr merge 286 --squash'#)}
        {label: "Block 4: `cd /tmp && gh pr merge 286 --admin` (compound command)" cmd: (r#'cd /tmp && gh pr merge 286 --admin'#)}
        {label: "Block 5: `gh pr merge --admin 286 #'` (comment-hiding bypass attempt)" cmd: (r#'gh pr merge --admin 286 #''#)}
        {label: "Block 6: `gh pr merge 286 --squash --match-head-commit $(git rev-parse HEAD)` (LIVE token)" cmd: (r#'gh pr merge 286 --squash --match-head-commit $(git rev-parse HEAD)'#)}
        {label: "Block 7: `glab mr merge 12 --squash --yes` (missing --auto-merge=false)" cmd: (r#'glab mr merge 12 --squash --yes'#)}
        {label: "Block 8: `gh api -X PUT \"repos/o/r/pu\"lls/... -f message=x` (split-quote path concatenation)" cmd: (r#'gh api -X PUT "repos/o/r/pu"lls/1/reviews/9/dismissals -f message=x'#)}
        {label: "Block 9: `gh api repos/.../dismissals --raw-field message=x` (long field-flag spelling)" cmd: (r#'gh api repos/o/r/pulls/1/reviews/9/dismissals --raw-field message=x'#)}
        {label: "Block 10: `gh api --method DELETE repos/o/r/issues/comments/12345` (Gate 3 comment deletion)" cmd: (r#'gh api --method DELETE repos/o/r/issues/comments/12345'#)}
        {label: "Block 11: `gh api -XPUT repos/.../dismissals -f message=x` (joined -XPUT)" cmd: (r#'gh api -XPUT repos/o/r/pulls/1/reviews/9/dismissals -f message=x'#)}
        {label: "Block 12: `gh api graphql -F query=@m.graphql` (indirect payload)" cmd: (r#'gh api graphql -F query=@m.graphql'#)}
        {label: "Block 13: `gh api graphql --input body.json` (indirect payload)" cmd: (r#'gh api graphql --input body.json'#)}
        {label: "Block 14: `gh api graphql --input -` (indirect payload from stdin)" cmd: (r#'gh api graphql --input -'#)}
        {label: "Block 15: `gh api graphql -f query=\"\$(cat m.graphql)\"` (LIVE payload)" cmd: (r#'gh api graphql -f query="$(cat m.graphql)"'#)}
        {label: "Block 16: `gh api graphql -f query=\"it's \$(cat m.graphql)\"` (LIVE payload with embedded quote)" cmd: (r#'gh api graphql -f query="it's $(cat m.graphql)"'#)}
        {label: "Block 17: `gh api graphql -f query='muta''tion { x }'` (adjacent-quote concatenation spells `mutation`)" cmd: (r#'gh api graphql -f query='muta''tion { x }''#)}
        {label: "Block 18: `gh api -X PUT \"\$P\" -f message=x` (LIVE path token)" cmd: (r#'gh api -X PUT "$P" -f message=x'#)}
        {label: "Block 19: `gh pr merge --admin 286 \"` (unterminated quote, parse-ok false, completed tokens still block)" cmd: (r#'gh pr merge --admin 286 "'#)}
        {label: "Block 20: `gh api -H \"Accept: ...\" -X PUT repos/.../dismissals -f message=x` (header-first path-token skip)" cmd: (r#'gh api -H "Accept: application/vnd.github+json" -X PUT repos/o/r/pulls/1/reviews/9/dismissals -f message=x'#)}
        {label: "Block 21: `glab mr merge ... --auto-merge=false --sha \$(git rev-parse HEAD)` (LIVE token even with --auto-merge=false present)" cmd: (r#'glab mr merge 12 --squash --yes --auto-merge=false --sha $(git rev-parse HEAD)'#)}
        {label: "Block 22: `gh api graphql --field=query=@m.graphql` (long field-flag, joined =, indirect)" cmd: (r#'gh api graphql --field=query=@m.graphql'#)}
        {label: "Block 23: `gh api graphql --input=body.json` (joined = form, indirect)" cmd: (r#'gh api graphql --input=body.json'#)}
    ]

    for c in $blocking_cases {
        if not (check $c.label (run-hook $hook $c.cmd) 2) {
            $failed = true
        }
    }

    let passing_cases = [
        {label: "Pass 1: `gh api repos/o/r/pulls` (plain GET)" cmd: (r#'gh api repos/o/r/pulls'#)}
        {label: "Pass 2: `gh api \"repos/\$OWNER/\$REPO/issues/286/timeline\" --paginate` (GET, LIVE path irrelevant off graphql/mutation rules)" cmd: (r#'gh api "repos/$OWNER/$REPO/issues/286/timeline" --paginate'#)}
        {label: "Pass 3: `gh api graphql -f query='query(...) {...}'` (gh's own documented read-only example)" cmd: (r#'gh api graphql -f query='query($name: String!, $owner: String!) { repository(owner:$owner,name:$name){id} }''#)}
        {label: "Pass 4: `gh api repos/o/r/issues/286/comments -F body=@review.md` (Gate 3 record-posting call, NOT /issues/comments/)" cmd: (r#'gh api repos/o/r/issues/286/comments -F body=@review.md'#)}
        {label: "Pass 5: `gh pr merge 286 --squash --match-head-commit <sha>` (correct precondition form)" cmd: (r#'gh pr merge 286 --squash --match-head-commit 8b60eabcf59edad3a49784e1c1684c3d996d0d60'#)}
        {label: "Pass 6: `glab mr merge 12 --squash --yes --auto-merge=false` (correct precondition form)" cmd: (r#'glab mr merge 12 --squash --yes --auto-merge=false'#)}
        {label: "Pass 7: `git grep -n -- \"gh pr merge --admin\"` (research, not an invocation -- position-0 is `git`)" cmd: (r#'git grep -n -- "gh pr merge --admin"'#)}
        {label: "Pass 8: `git grep -- \"gh pr merge --admin\" && echo ok` (same, compound form)" cmd: (r#'git grep -- "gh pr merge --admin" && echo ok'#)}
        {label: "Pass 9: `git commit -m \"docs: clarify gh pr merge --admin is forbidden\"` (documentation commit)" cmd: (r#'git commit -m "docs: clarify gh pr merge --admin is forbidden"'#)}
        {label: "Pass 10: `echo \"unterminated` (unterminated quote on a non-gh/glab command; fail-open-on-unreadable-line)" cmd: (r#'echo "unterminated'#)}
        {label: "Pass 11: empty string" cmd: ""}
    ]

    # ======================================================================
    # ADDITIONS BEYOND THE AC's MATRIX. The claude-skills-340 acceptance
    # criteria's "Required test matrix" is frozen and transcribed verbatim
    # above with no changes. These four rows are NOT from that matrix —
    # they close discriminator gaps in the matrix itself, authored by the
    # test author per Gate 3 review:
    #   - Every existing --auto/--admin BLOCKING row (Block 1, 2) also
    #     lacks --match-head-commit, so an implementation with NO
    #     --auto/--admin check at all still blocks on that ground alone and
    #     passes the whole suite. Rows 1-2 below hold --match-head-commit
    #     present and correct, isolating --auto and --admin individually.
    #   - "Skip leading NAME=value words" (decision-rule step 1) has no
    #     row anywhere in the matrix — an implementation that reads raw
    #     position 0 (landing on "GH_TOKEN=x" instead of "gh") would fail
    #     to recognize the command at all and pass every case that doesn't
    #     use a prefix. Row 3 below is the only test in this suite that
    #     would catch that.
    #   - Method case-insensitivity ("whose value is not `get` compared
    #     case-insensitively") has no row — every existing GET case in the
    #     matrix uses no -X/--method flag at all. Row 4 below pins that an
    #     explicit lowercase `get` is still recognized as GET, not treated
    #     as an unrecognized/non-GET method.
    # ======================================================================

    let extra_blocking_cases = [
        {label: "Extra 1 (gap-fill, not AC matrix): `gh pr merge 286 --squash --auto --match-head-commit <sha>` isolates --auto with a correct --match-head-commit present" cmd: (r#'gh pr merge 286 --squash --auto --match-head-commit 8b60eabcf59edad3a49784e1c1684c3d996d0d60'#)}
        {label: "Extra 2 (gap-fill, not AC matrix): `gh pr merge 286 --squash --admin --match-head-commit <sha>` isolates --admin with a correct --match-head-commit present" cmd: (r#'gh pr merge 286 --squash --admin --match-head-commit 8b60eabcf59edad3a49784e1c1684c3d996d0d60'#)}
        {label: "Extra 3 (gap-fill, not AC matrix): `GH_TOKEN=x gh pr merge 286 --admin` -- leading NAME=value word must be skipped before reading position 0" cmd: (r#'GH_TOKEN=x gh pr merge 286 --admin'#)}
    ]

    for c in $extra_blocking_cases {
        if not (check $c.label (run-hook $hook $c.cmd) 2) {
            $failed = true
        }
    }

    let extra_passing_cases = [
        {label: "Extra 4 (gap-fill, not AC matrix): `gh api -X get repos/o/r/pulls/1` -- lowercase method value is still recognized as GET (case-insensitive compare)" cmd: (r#'gh api -X get repos/o/r/pulls/1'#)}
    ]

    for c in $extra_passing_cases {
        if not (check $c.label (run-hook $hook $c.cmd) 0) {
            $failed = true
        }
    }

    for c in $passing_cases {
        if not (check $c.label (run-hook $hook $c.cmd) 0) {
            $failed = true
        }
    }

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ git forbidden-merge-write hook and scanner verified(ansi reset)"
}
