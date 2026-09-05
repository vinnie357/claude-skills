# Scanner for claude-skills-340 (merge-write PreToolUse gate).
#
# Splits a shell command string into POSIX-ish segments and dequoted
# tokens, so block-merge-writes.nu can run its gh/glab decision rules on
# stable token boundaries instead of pattern-matching the raw string. This
# is a CHEAP DETERMINISTIC GATE, not a security boundary — see the header
# comment in block-merge-writes.nu for the full scope statement.
#
# Only one exported function. No LIVE flag, no unreadability field in the
# return shape — both existed in an earlier, superseded revision of
# claude-skills-340 to defeat evasion and are deliberately absent here.
#
# Performance shape: a command containing no quote character and no
# backslash anywhere skips the regex-based classifier entirely and uses
# native `split row` (segments on the six separators, tokens on
# whitespace) — the fast path. A command carrying a quote or backslash
# falls back to the slower quote-aware classifier below, which is only
# ever asked to walk the small number of pieces a quoted/escaped
# argument actually produces. Measured (mise run test:git-hook, this
# machine): a 64KB single quoted token ~4.5ms; a ~21,000-token unquoted
# command ~18ms. Both are min-of-three, hook-as-subprocess measurements
# well inside the 200ms budget.

# Classifies one command string into an ordered list of pieces, each a
# {kind, value} record. kind is one of: "bad" (a quote character that
# never closes), "cont" (a backslash-newline continuation — contributes
# nothing), "sep" (an unquoted segment separator — contributes nothing),
# "ws" (an unquoted whitespace run — contributes nothing), or "word" (a
# dequoted content-bearing piece: a plain run, an escaped character, or
# the stripped/unescaped content of a quoted span). Used only by the slow
# path; the fast path never calls this.
def classify-pieces [command: string] {
    let pattern = r#'(?<cont>\\\n)|(?<sq>'[^']*')|(?<dq>"(?:\\.|[^"\\])*")|(?<esc>\\.)|(?<bad>['"])|(?<sep2>&&|\|\|)|(?<sep1>[;|&\n])|(?<ws>[ \t]+)|(?<plain>[^ \t\n;&|\\'"]+)'#

    ($command | parse --regex $pattern) | each {|p|
        if $p.bad != null {
            {kind: "bad", value: ""}
        } else if $p.cont != null {
            {kind: "cont", value: ""}
        } else if $p.sq != null {
            # Single quotes suppress everything to the next single quote —
            # no escape processing on the content.
            {kind: "word", value: ($p.sq | str substring 1..<-1)}
        } else if $p.dq != null {
            # Double quotes suppress the special meaning of a single quote
            # but a backslash still escapes the next character within them.
            let inner = ($p.dq | str substring 1..<-1)
            let unescaped = (
                $inner
                | parse --regex '(?<esc>\\.)|(?<plain>[^\\]+)'
                | each {|q| if $q.esc != null { $q.esc | str substring 1.. } else { $q.plain } }
                | str join ""
            )
            {kind: "word", value: $unescaped}
        } else if $p.esc != null {
            # A backslash outside single quotes escapes the next character;
            # the escaped character loses any special meaning, including as
            # a word-boundary space.
            {kind: "word", value: ($p.esc | str substring 1..)}
        } else if $p.sep2 != null {
            {kind: "sep", value: ""}
        } else if $p.sep1 != null {
            {kind: "sep", value: ""}
        } else if $p.ws != null {
            {kind: "ws", value: ""}
        } else {
            {kind: "word", value: $p.plain}
        }
    }
}

# Slow, quote-aware path: used only when the command contains a `'`, `"`,
# or `\` somewhere. Handles adjacent-quote concatenation (two word pieces
# in a row simply concatenate, since nothing separates them), line
# continuation, and unterminated-quote recovery.
def tokenize-slow [command: string]: nothing -> list<list<string>> {
    let all_pieces = (classify-pieces $command)

    # On an unterminated quote, drop the in-progress token (everything
    # from the nearest preceding ws/sep boundary through the end) and keep
    # whatever completed before that boundary. Never throws.
    let bad_rows = ($all_pieces | enumerate | where item.kind == "bad")
    let pieces = if ($bad_rows | is-empty) {
        $all_pieces
    } else {
        let bad_idx = ($bad_rows | first | get index)
        let before = ($all_pieces | first $bad_idx | enumerate)
        let boundary_rows = ($before | where {|r| $r.item.kind == "ws" or $r.item.kind == "sep"})
        if ($boundary_rows | is-empty) {
            []
        } else {
            let boundary = ($boundary_rows | last | get index)
            $all_pieces | first ($boundary + 1)
        }
    }

    if ($pieces | is-empty) {
        return []
    }

    let segments_of_pieces = ($pieces | split list {|p| $p.kind == "sep"})

    $segments_of_pieces | each {|seg_pieces|
        let token_groups = ($seg_pieces | split list {|p| $p.kind == "ws"})
        $token_groups
            | where ($it | length) > 0
            | each {|tg| $tg | each {|p| $p.value} | str join ""}
    }
}

# Fast path: no quote or backslash anywhere in the command, so segment and
# token boundaries are exactly the unquoted-separator and whitespace runs
# — a plain native `split row` handles both without any per-piece nu-level
# branching. This is what keeps the ~21,000-token latency fixture inside
# budget (no regex classifier, no closures over individual tokens).
def tokenize-fast [command: string]: nothing -> list<list<string>> {
    let raw_segments = ($command | split row -r '(?:&&|\|\||;|\||&|\n)')
    $raw_segments | each {|seg|
        $seg | split row -r '[ \t]+' | where ($it | is-not-empty)
    }
}

# Splits `command` into SEGMENTS on an unquoted `;`, `&&`, `||`, `|`, `&`,
# or newline. Each segment is a list of dequoted token strings, in order.
# Never throws — an unterminated quote returns whatever completed before
# the failure (see tokenize-slow).
export def tokenize-command [command: string]: nothing -> list<list<string>> {
    if ($command | is-empty) {
        return []
    }

    let has_quote_or_backslash = (
        ($command | str contains "'")
        or ($command | str contains '"')
        or ($command | str contains "\\")
    )

    if $has_quote_or_backslash {
        tokenize-slow $command
    } else {
        tokenize-fast $command
    }
}
