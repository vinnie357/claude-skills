#!/usr/bin/env nu
# POSIX-ish command-line scanner for claude-skills-340. Consumed by
# block-forbidden-merge-writes.nu's decision rules (source this file, then
# call scan-posix-command directly -- see that file for why).
#
# Deliberately narrow: this is not a full POSIX/bash grammar, and it is not
# meant to become one. It implements exactly the contract frozen in
# test/validate-git-hook.nu's scanner unit tests (claude-skills-340 AC "The
# scanner" section) -- segmentation, quoting, LIVE-expansion detection,
# comment handling, and fail-open-on-unreadable-line parse semantics.
# claude-skills-340's CRITICAL "TOKENIZER" note records why this is
# hand-written nushell rather than a dependency: no nushell 0.113.1
# builtin and no mise-installable CLI emits a quote-aware POSIX token list.
#
# Contract: scan-posix-command [cmd: string] -> {parse_ok: bool, segments:
# list<list<record<value: string, live: bool>>>}.
#
# - segments: an unquoted `;`, `&&`, `||`, `|`, `&`, or newline ends a
#   segment. A separator INSIDE single or double quotes, a backtick span,
#   or a `$( ... )` span is literal, not a boundary.
# - token.value: the fully DEQUOTED token text (quote characters removed;
#   escaped characters resolved to the literal character they escape).
# - token.live: true iff the token carries an expansion the shell would
#   run -- a backtick, `$(`, `<(`, or a bare `$` -- outside single quotes
#   and not backslash-escaped. A `$` inside single quotes is never live.
# - parse_ok is false ONLY for an unterminated `'`, `"`, backtick, or
#   `$(`. The tokens completed before the failure point are still
#   returned; the in-progress (unterminated) token itself is discarded.
#   A trailing backslash is a literal backslash, not a failure.
# - An unquoted `#` at the start of a word begins a comment that runs to
#   the next newline (or end of input) and ends the segment; a `#`
#   mid-word is literal. Comment text is skipped RAW -- it does not
#   re-enter the quote/backtick/`$(` state machine, so a stray quote
#   character inside a comment (`... #'`) cannot itself trigger a parse
#   failure or otherwise resurrect on the next segment.
export def scan-posix-command [cmd: string] {
    let chars = ($cmd | split chars)
    let n = ($chars | length)

    mut i = 0
    mut segments = []
    mut cur_segment = []
    mut cur_value = ""
    mut cur_live = false
    mut token_active = false
    mut in_single = false
    mut in_double = false
    mut in_backtick = false
    mut dollar_depth = 0
    mut parse_ok = true

    while $i < $n {
        let c = ($chars | get $i)

        if $dollar_depth > 0 {
            # Opaque nesting-depth tracking inside a $( ... ) span -- AC:
            # "`$(` tracks nesting depth so a nested substitution stays
            # one token." Contents are not otherwise interpreted.
            if $c == "\\" and ($i + 1) < $n {
                $cur_value = $cur_value + $c + ($chars | get ($i + 1))
                $i = $i + 2
            } else if $c == "(" {
                $cur_value = $cur_value + $c
                $dollar_depth = $dollar_depth + 1
                $i = $i + 1
            } else if $c == ")" {
                $cur_value = $cur_value + $c
                $dollar_depth = $dollar_depth - 1
                $i = $i + 1
            } else {
                $cur_value = $cur_value + $c
                $i = $i + 1
            }
        } else if $in_backtick {
            if $c == "\\" and ($i + 1) < $n {
                $cur_value = $cur_value + $c + ($chars | get ($i + 1))
                $i = $i + 2
            } else if $c == "`" {
                $cur_value = $cur_value + $c
                $in_backtick = false
                $i = $i + 1
            } else {
                $cur_value = $cur_value + $c
                $i = $i + 1
            }
        } else if $in_single {
            if $c == "'" {
                $in_single = false
                $i = $i + 1
            } else {
                $cur_value = $cur_value + $c
                $i = $i + 1
            }
        } else if $in_double {
            if $c == "\\" and ($i + 1) < $n {
                $cur_value = $cur_value + ($chars | get ($i + 1))
                $i = $i + 2
            } else if $c == "\\" {
                $cur_value = $cur_value + $c
                $i = $i + 1
            } else if $c == "\"" {
                $in_double = false
                $i = $i + 1
            } else if $c == "$" and ($i + 1) < $n and ($chars | get ($i + 1)) == "(" {
                $cur_value = $cur_value + "$("
                $cur_live = true
                $dollar_depth = 1
                $i = $i + 2
            } else if $c == "$" {
                $cur_value = $cur_value + $c
                $cur_live = true
                $i = $i + 1
            } else if $c == "`" {
                $cur_value = $cur_value + $c
                $cur_live = true
                $in_backtick = true
                $i = $i + 1
            } else {
                $cur_value = $cur_value + $c
                $i = $i + 1
            }
        } else {
            # Top-level (unquoted) state.
            if $c == " " or $c == "\t" {
                if $token_active {
                    $cur_segment = ($cur_segment | append {value: $cur_value, live: $cur_live})
                    $cur_value = ""
                    $cur_live = false
                    $token_active = false
                }
                $i = $i + 1
            } else if $c == "\n" or $c == ";" {
                if $token_active {
                    $cur_segment = ($cur_segment | append {value: $cur_value, live: $cur_live})
                    $cur_value = ""
                    $cur_live = false
                    $token_active = false
                }
                if ($cur_segment | length) > 0 {
                    $segments = ($segments | append [$cur_segment])
                    $cur_segment = []
                }
                $i = $i + 1
            } else if $c == "&" or $c == "|" {
                let doubled = (($i + 1) < $n and ($chars | get ($i + 1)) == $c)
                if $token_active {
                    $cur_segment = ($cur_segment | append {value: $cur_value, live: $cur_live})
                    $cur_value = ""
                    $cur_live = false
                    $token_active = false
                }
                if ($cur_segment | length) > 0 {
                    $segments = ($segments | append [$cur_segment])
                    $cur_segment = []
                }
                $i = (if $doubled { $i + 2 } else { $i + 1 })
            } else if $c == "'" {
                $in_single = true
                $token_active = true
                $i = $i + 1
            } else if $c == "\"" {
                $in_double = true
                $token_active = true
                $i = $i + 1
            } else if $c == "\\" and ($i + 1) < $n {
                $cur_value = $cur_value + ($chars | get ($i + 1))
                $token_active = true
                $i = $i + 2
            } else if $c == "\\" {
                $cur_value = $cur_value + $c
                $token_active = true
                $i = $i + 1
            } else if $c == "$" and ($i + 1) < $n and ($chars | get ($i + 1)) == "(" {
                $cur_value = $cur_value + "$("
                $cur_live = true
                $token_active = true
                $dollar_depth = 1
                $i = $i + 2
            } else if $c == "$" {
                $cur_value = $cur_value + $c
                $cur_live = true
                $token_active = true
                $i = $i + 1
            } else if $c == "`" {
                $cur_value = $cur_value + $c
                $cur_live = true
                $token_active = true
                $in_backtick = true
                $i = $i + 1
            } else if $c == "<" and ($i + 1) < $n and ($chars | get ($i + 1)) == "(" {
                $cur_value = $cur_value + "<("
                $cur_live = true
                $token_active = true
                $i = $i + 2
            } else if $c == "#" and not $token_active {
                if ($cur_segment | length) > 0 {
                    $segments = ($segments | append [$cur_segment])
                    $cur_segment = []
                }
                while $i < $n and ($chars | get $i) != "\n" {
                    $i = $i + 1
                }
            } else {
                $cur_value = $cur_value + $c
                $token_active = true
                $i = $i + 1
            }
        }
    }

    if $in_single or $in_double or $in_backtick or $dollar_depth > 0 {
        $parse_ok = false
        if ($cur_segment | length) > 0 {
            $segments = ($segments | append [$cur_segment])
        }
    } else {
        if $token_active {
            $cur_segment = ($cur_segment | append {value: $cur_value, live: $cur_live})
        }
        if ($cur_segment | length) > 0 {
            $segments = ($segments | append [$cur_segment])
        }
    }

    {parse_ok: $parse_ok, segments: $segments}
}
