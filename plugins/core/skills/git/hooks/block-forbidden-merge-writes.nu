#!/usr/bin/env nu
# PreToolUse Bash hook for claude-skills-340. Blocks the forbidden
# MERGE-PATH writes documented in /core:git's "Merge authorization"
# section that the shipped precondition (PR #285/#286) can only detect
# AFTER the fact, never prevent: `gh pr merge --auto`, `gh pr merge
# --admin`, `glab mr merge` without `--auto-merge=false`, plain `gh pr
# merge` missing `--match-head-commit` (the merge-queue approximation),
# review-dismissal and Gate-3-comment-deletion via `gh api`, and any
# invocation carrying a LIVE (shell-expansion-bearing) token.
#
# BACKSTOP, NOT A SUBSTITUTE. This hook approximates /core:git's merge
# policy at the Bash-tool boundary; it does not replace the rule itself.
# See /core:git's "Merge-write hook (backstop, not a substitute)" section
# for the full list of named approximations, over-blocks, and
# under-blocks -- the same disclaimer /core:security carries for
# check-secrets-before-commit.sh applies here.
#
# claude-skills-331 COORDINATION (operator-recorded 2026-09-04): 331 is
# blocked by 281 and cannot proceed yet. This issue establishes the hook
# shape 331 will adopt once unblocked -- a nushell scanner (posix-scan.nu)
# plus decision rules, skill-frontmatter `hooks:` wiring rather than a
# plugin hooks.json, exit-2-to-block, and fail-open-on-an-unreadable-LINE
# (a line the scanner cannot parse at all never blocks by itself) vs.
# fail-closed-on-an-unreadable-PAYLOAD (rules 1 and 2 in gh-api-blocks
# below). Do not build a shared dispatcher or plugin framework ahead of
# 331 actually landing on this shape.
#
# Exit codes (Claude Code PreToolUse contract -- see /claude-code:claude-
# hooks): 0 allows the tool call, 2 blocks it. Exit 1, a missing or
# non-executable script, and a timeout are all non-blocking per the
# harness, so this hook must reach exit 2 explicitly on every forbidden
# case rather than relying on any other exit code to block.
#
# ALLOWLIST, NOT DENYLIST (settled -- claude-skills-340 CRITICAL section).
# The rules below match specific `gh`/`glab` invocation shapes; they do
# not enumerate forbidden command names. Three enumeration rounds each
# shipped a bypass before this shape was adopted.

source posix-scan.nu

# --- Segment-level helpers -------------------------------------------

def carries-flag [tokens: list, flag: string] {
    ($tokens | any {|t| $t.value == $flag or ($t.value | str starts-with $"($flag)=") })
}

def any-live [tokens: list] {
    ($tokens | any {|t| $t.live })
}

def gh-pr-merge-blocks [rest: list] {
    ((carries-flag $rest "--auto") or (carries-flag $rest "--admin") or (not (carries-flag $rest "--match-head-commit")) or (any-live $rest))
}

def glab-mr-merge-blocks [rest: list] {
    let has_correct_flag = ($rest | any {|t| $t.value == "--auto-merge=false" })
    (not $has_correct_flag) or (any-live $rest)
}

# `gh api` argument helpers. `args` is everything after "gh api" (position
# 2 onward of the segment).

def extract-method [args: list] {
    mut idx = 0
    let n = ($args | length)
    mut result = null
    while $idx < $n and $result == null {
        let v = ($args | get $idx | get value)
        if $v == "--method" or $v == "-X" {
            if ($idx + 1) < $n {
                $result = ($args | get ($idx + 1) | get value)
            } else {
                $idx = $n
            }
        } else if ($v | str starts-with "--method=") {
            $result = ($v | str substring 9..)
        } else if ($v | str starts-with "-X") and $v != "-X" {
            $result = ($v | str substring 2..)
        }
        $idx = $idx + 1
    }
    $result
}

# Flags that TAKE a separate value token (gh api --help, gh 2.93.0). A
# token exactly matching one of these consumes the next token as its
# value; a joined form (`-XPUT`, `--method=PUT`) does not equal any entry
# here, so it is treated as a single self-contained token instead.
const API_TAKES_VALUE = ["--cache" "-F" "--field" "-H" "--header" "--hostname" "--input" "-q" "--jq" "-X" "--method" "-p" "--preview" "-f" "--raw-field" "-t" "--template"]

def extract-path-token [args: list] {
    mut idx = 0
    let n = ($args | length)
    mut result = null
    while $idx < $n and $result == null {
        let tok = ($args | get $idx)
        if ($tok.value | str starts-with "-") {
            if ($API_TAKES_VALUE | any {|f| $tok.value == $f }) {
                $idx = $idx + 2
            } else {
                $idx = $idx + 1
            }
        } else {
            $result = $tok
        }
    }
    $result
}

def value-after-eq [s: string] {
    let idx = ($s | str index-of "=")
    if $idx >= 0 {
        ($s | str substring ($idx + 1)..)
    } else {
        $s
    }
}

# Field flag means a token equal to -f, -F, --raw-field, --field, or
# --input, or beginning with -f, -F, --raw-field=, --field=, or --input=
# (claude-skills-340 AC "Field flag"). Returns {value, live, indirect}
# for each occurrence: `value` is the associated field content (the
# dequoted token text carrying the field's key=value, with any flag
# prefix stripped for a joined form); `indirect` is true for --input (any
# value) or a -F/--field value part beginning with `@`.
def extract-field-tokens [args: list] {
    mut idx = 0
    let n = ($args | length)
    mut out = []
    while $idx < $n {
        let tok = ($args | get $idx)
        let v = $tok.value
        let is_field = (
            $v == "-f" or $v == "-F" or $v == "--raw-field" or $v == "--field" or $v == "--input"
            or ($v | str starts-with "-f") or ($v | str starts-with "-F")
            or ($v | str starts-with "--raw-field=") or ($v | str starts-with "--field=") or ($v | str starts-with "--input=")
        )
        if $is_field {
            let is_input = ($v == "--input" or ($v | str starts-with "--input="))
            let is_atflag = ($v == "-F" or ($v | str starts-with "-F") or $v == "--field" or ($v | str starts-with "--field="))
            let exact_flag = ($v == "-f" or $v == "-F" or $v == "--raw-field" or $v == "--field" or $v == "--input")
            if $exact_flag {
                if ($idx + 1) < $n {
                    let val_tok = ($args | get ($idx + 1))
                    let indirect = (if $is_input { true } else { $is_atflag and ((value-after-eq $val_tok.value) | str starts-with "@") })
                    $out = ($out | append {value: $val_tok.value, live: $val_tok.live, indirect: $indirect})
                }
                $idx = $idx + 2
            } else {
                let content = (
                    if ($v | str starts-with "--raw-field=") { ($v | str substring 12..) }
                    else if ($v | str starts-with "--field=") { ($v | str substring 8..) }
                    else if ($v | str starts-with "--input=") { ($v | str substring 8..) }
                    else if ($v | str starts-with "-F") { ($v | str substring 2..) }
                    else { ($v | str substring 2..) }
                )
                let indirect = (if $is_input { true } else { $is_atflag and ((value-after-eq $content) | str starts-with "@") })
                $out = ($out | append {value: $content, live: $tok.live, indirect: $indirect})
                $idx = $idx + 1
            }
        } else {
            $idx = $idx + 1
        }
    }
    $out
}

def gh-api-blocks [rest: list] {
    let args = ($rest | skip 2)
    let method = (extract-method $args)
    let field_tokens = (extract-field-tokens $args)
    let has_field_flag = (($field_tokens | length) > 0)
    let non_get = (
        (if $method != null { ($method | str downcase) != "get" } else { false })
        or ($method == null and $has_field_flag)
    )
    let path_tok = (extract-path-token $args)
    let path_value = (if $path_tok != null { $path_tok.value } else { "" })
    let path_live = (if $path_tok != null { $path_tok.live } else { false })
    let is_graphql = ($path_value == "graphql")

    # Rule 1: non-GET whose path token is LIVE -- fail closed on an
    # unreadable payload (claude-skills-340 CRITICAL: "exits 2 for
    # unreadability in exactly two places", this is the first).
    let rule1 = ($non_get and $path_live)
    # Rule 2: graphql call whose payload is LIVE or indirect -- the
    # second unreadability case.
    let rule2 = ($is_graphql and ($field_tokens | any {|t| $t.live or $t.indirect }))
    # Rule 3: non-GET against a literal review-dismissal or
    # comment-deletion path.
    let rule3 = ($non_get and (($path_value | str contains "/pulls/") or ($path_value | str contains "/issues/comments/")))
    # Rule 4: graphql call whose field value names a mutation.
    let rule4 = ($is_graphql and ($field_tokens | any {|t| $t.value | str contains "mutation" }))

    $rule1 or $rule2 or $rule3 or $rule4
}

def leading-skip-count [tokens: list] {
    mut idx = 0
    let n = ($tokens | length)
    mut done = false
    while $idx < $n and not $done {
        let v = ($tokens | get $idx | get value)
        if (($v | parse -r '^[A-Za-z_][A-Za-z0-9_]*=') | length) > 0 {
            $idx = $idx + 1
        } else {
            $done = true
        }
    }
    $idx
}

def segment-blocks [segment: list] {
    let skip_n = (leading-skip-count $segment)
    let rest = ($segment | skip $skip_n)
    if ($rest | length) == 0 {
        return false
    }
    let cmd0 = ($rest | get 0 | get value)
    if $cmd0 == "gh" {
        if ($rest | length) > 1 and ($rest | get 1 | get value) == "pr" {
            if (($rest | skip 2 | where value == "merge" | length) > 0) {
                return (gh-pr-merge-blocks $rest)
            }
        }
        if ($rest | length) > 1 and ($rest | get 1 | get value) == "api" {
            return (gh-api-blocks $rest)
        }
        false
    } else if $cmd0 == "glab" {
        if ($rest | length) > 1 and ($rest | get 1 | get value) == "mr" {
            if (($rest | skip 2 | where value == "merge" | length) > 0) {
                return (glab-mr-merge-blocks $rest)
            }
        }
        false
    } else {
        false
    }
}

def main [] {
    let raw_input = (^cat)
    let payload = (try { $raw_input | from json } catch { null })
    if $payload == null {
        exit 0
    }
    let tool_name = ($payload | get -o tool_name | default "")
    if $tool_name != "Bash" {
        exit 0
    }
    let command = ($payload | get -o tool_input.command | default "")

    let scanned = (scan-posix-command $command)

    # Fail-open-on-an-unreadable-LINE: a segment the scanner could not
    # finish parsing still runs the rules on whatever tokens it
    # completed (claude-skills-340 CRITICAL). parse_ok is not consulted
    # here on purpose -- posix-scan.nu already discards the incomplete
    # token, so the segments it returns are exactly "the tokens
    # completed before the failure point."
    let blocked = ($scanned.segments | any {|seg| segment-blocks $seg })

    if $blocked {
        print -e "Blocked: this command matches a forbidden merge-path write per /core:git's Merge authorization section (claude-skills-340). Use the documented precondition-checked form instead."
        exit 2
    }
    exit 0
}
