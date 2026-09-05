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
# Performance shape: THREE paths, not two.
#   1. No quote or backslash anywhere: native `split row` on separators
#      then whitespace (`tokenize-fast`) — no regex classifier at all.
#   2. A quote/backslash is present but every quote closes: `tokenize-fast`
#      still does the splitting, but first every well-formed special span
#      (a line continuation, a closed single- or double-quoted span, a
#      standalone backslash-escape) is resolved to its literal content in
#      ONE native `str replace --all --regex` pass over the whole command
#      (`resolve-wellformed`), with any character that content contains
#      that would otherwise be re-interpreted by the native split — space,
#      tab, newline, `;`, `&`, `|` — swapped for a NUL-prefixed placeholder
#      (`protect-specials`). A NUL byte cannot appear on a real bash
#      command line (argv is NUL-terminated), but the JSON payload this
#      hook actually reads is not bash argv — a JSON string can carry a
#      literal NUL via the six-character escape `\u0000`. If a payload
#      token happens to equal one of these placeholders, the placeholder
#      is treated as a real boundary and the command is split there —
#      failing closed (a stricter, more conservative tokenization) rather
#      than unsafe.
#      `tokenize-fast` then runs on the resolved string, and the resulting
#      tokens are restored to their real characters in a SINGLE vectorised
#      `str replace --all` pass over the whole flat token list
#      (`unprotect-list` — `str replace` accepts `list<string>` directly,
#      so this is one native call, not one nu-level closure per token).
#      Cost here is proportional to the number of SPECIAL SPANS (quotes,
#      escapes), not to the number of tokens: a command with 21,000 plain
#      tokens and ONE quoted token pays for one quote, not 21,000 pieces.
#   3. A quote never closes: routes to `tokenize-slow`, the original
#      piece-by-piece `parse --regex` walk, which is the only path that
#      needs to reconstruct "everything completed before the failure".
#      This shape is rare (malformed input) and paying its per-piece cost
#      there is acceptable — it is no longer paid on every quoted command.
#
# An earlier revision of this file routed EVERY command containing any
# quote or backslash through `tokenize-slow`, and claimed that path was
# "only ever asked to walk the small number of pieces a quoted/escaped
# argument actually produces". That claim was FALSE: `tokenize-slow` walks
# a piece for every whitespace run and every plain word in the ENTIRE
# command, quoted or not, so one quote anywhere sent a 21,000-token command
# through ~42,000 nu-level closure invocations. Measured (mise run
# test:git-hook, this machine, min-of-three, hook as subprocess): a
# ~21,000-token command with no quotes took 95ms; the identical command
# with a single `'x'` token added took 1030ms on the old single-path
# implementation — a 10.8x blowup from one quote. Path 2 above exists
# specifically to remove that blowup: the same fixture now measures ~48ms
# for the tokenizer itself. All budget rows are measured under the 500ms
# per-run ceiling, taking the MINIMUM of three runs — a single wall-clock
# sample on a shared runner measures scheduling delay, not the hook, and
# the ~21,000-token row is ~3.3x slower on the GitHub 2-vCPU runner than on
# this machine, so 500ms (not 200ms) is the figure that survives there.

# Regex matching ONLY complete, well-formed specials: a backslash-newline
# line continuation, a fully-closed single-quoted span, a fully-closed
# double-quoted span (itself honoring a backslash-newline continuation and
# any other backslash-escape inside it), or a standalone backslash-escape
# outside quotes. Deliberately excludes the unterminated-quote case — a
# stray `'` or `"` left over after every well-formed span is stripped is
# exactly what `has-unterminated-quote` below tests for, and routes that
# rare shape to `tokenize-slow` instead.
const WELLFORMED_SPECIALS = r#'(?<cont>\\\n)|(?<sq>'[^']*')|(?<dq>"(?:\\\n|\\.|[^"\\])*")|(?<esc>\\.)'#

# True when the command contains a quote character that never closes.
# Stripping every well-formed special span in one native regex pass and
# checking for a leftover bare quote character is a single call, versus
# walking the command piece by piece just to answer this yes/no question.
def has-unterminated-quote [command: string]: nothing -> bool {
    let stripped = ($command | str replace --all --regex $WELLFORMED_SPECIALS "")
    ($stripped | str contains "'") or ($stripped | str contains '"')
}

# Unescapes the inner content of a double-quoted span. Per POSIX, inside
# double quotes a backslash is special only before `$`, a backtick, `"`,
# `\`, or a newline: a backslash-newline is a LINE CONTINUATION and both
# characters are removed (not kept as a literal newline); any other
# backslash-escape keeps its escaped character; everything else is
# literal. Shared by `classify-pieces` (the slow path) and
# `resolve-wellformed` (the fast path) so this rule is defined once.
#
# Two-part fast path, added for claude-skills-340's fourth (double-quoted
# span COUNT) budget row: the previous body ran `parse --regex` (builds a
# row per piece) then `each` (one nu-level closure per row) then `str join`
# — three separate nu-level stages PER SPAN, paid even for a span with no
# backslash at all (the common case: `"a"`, `"foo"`). Measured at ~6,000
# such spans: 883ms, over the 800ms budget.
#   1. A span with no backslash needs no unescaping at all — `str contains`
#      is one native call versus the whole parse/each/join pipeline, so
#      check it first and return the content unchanged.
#   2. A span that DOES carry a backslash still resolves in one native
#      `str replace --all --regex` call with a per-match closure (same
#      alternation, same cont-before-esc priority, so the same leftmost,
#      non-overlapping, sequential-consumption semantics as the original
#      parse — this is NOT two independent global passes: a separate
#      standalone `\\\n`-then-`\\.` pass would let the first pass match a
#      `\n` that a preceding escaped backslash (`\\\\` then a real
#      newline) already consumed, silently dropping the newline. One
#      combined pattern with one left-to-right scan avoids that.
def unescape-dq-inner [inner: string]: nothing -> string {
    if not ($inner | str contains "\\") {
        return $inner
    }
    $inner | str replace --all --regex '(?<cont>\\\n)|(?<esc>\\.)' {|cont?, esc?|
        if $cont != null {
            ""
        } else {
            $esc | str substring 1..
        }
    }
}

# Swaps the six characters that the later native split treats as special
# (whitespace and the segment separators) for a NUL-prefixed 2-hex-digit
# placeholder. A NUL byte cannot appear on a real bash command line (argv
# is NUL-terminated), but this hook reads a JSON payload, not bash argv,
# and a JSON string can carry a literal NUL via the six-character escape
# `\u0000`. That is not unsafe: if a payload token happens to collide with
# one of these placeholders, `unprotect-list` still restores every OTHER
# occurrence correctly, and the colliding token is simply read back as
# whatever real character that placeholder stands for — a deterministic,
# fail-closed outcome, not a crash or a silent bypass.
def protect-specials [s: string]: nothing -> string {
    $s
    | str replace --all "\t" "\u{0}09"
    | str replace --all "\n" "\u{0}0A"
    | str replace --all ";" "\u{0}3B"
    | str replace --all "&" "\u{0}26"
    | str replace --all "|" "\u{0}7C"
    | str replace --all " " "\u{0}20"
}

# Reverses protect-specials across a WHOLE flat token list in one native
# call (`str replace` accepts `list<string>` input directly) rather than
# one nu-level closure per token — this is what keeps path 2 linear in the
# number of special spans instead of the number of tokens.
def unprotect-list [tokens: list<string>]: nothing -> list<string> {
    $tokens
    | str replace --all "\u{0}09" "\t"
    | str replace --all "\u{0}0A" "\n"
    | str replace --all "\u{0}3B" ";"
    | str replace --all "\u{0}26" "&"
    | str replace --all "\u{0}7C" "|"
    | str replace --all "\u{0}20" " "
}

# Resolves every well-formed special span in ONE native regex pass over the
# whole command. Only called after `has-unterminated-quote` has confirmed
# every quote closes, so no "bad" handling is needed here.
def resolve-wellformed [command: string]: nothing -> string {
    $command | str replace --all --regex $WELLFORMED_SPECIALS {|cont?, sq?, dq?, esc?|
        if $cont != null {
            ""
        } else if $sq != null {
            protect-specials ($sq | str substring 1..<-1)
        } else if $dq != null {
            protect-specials (unescape-dq-inner ($dq | str substring 1..<-1))
        } else if $esc != null {
            protect-specials ($esc | str substring 1..)
        } else {
            ""
        }
    }
}

# Classifies one command string into an ordered list of pieces, each a
# {kind, value} record. kind is one of: "bad" (a quote character that
# never closes), "cont" (a backslash-newline continuation — contributes
# nothing), "sep" (an unquoted segment separator — contributes nothing),
# "ws" (an unquoted whitespace run — contributes nothing), or "word" (a
# dequoted content-bearing piece: a plain run, an escaped character, or
# the stripped/unescaped content of a quoted span). Used only by the slow
# path (a genuinely unterminated quote); the fast paths never call this.
def classify-pieces [command: string] {
    let pattern = r#'(?<cont>\\\n)|(?<sq>'[^']*')|(?<dq>"(?:\\\n|\\.|[^"\\])*")|(?<esc>\\.)|(?<bad>['"])|(?<sep2>&&|\|\|)|(?<sep1>[;|&\n])|(?<ws>[ \t]+)|(?<plain>[^ \t\n;&|\\'"]+)'#

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
            # but a backslash still escapes the next character within them
            # (see unescape-dq-inner for the line-continuation rule).
            {kind: "word", value: (unescape-dq-inner ($p.dq | str substring 1..<-1))}
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

# Slow, quote-aware path: used only when the command carries a quote that
# never closes. Handles adjacent-quote concatenation (two word pieces
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

# Splits `command` into a flat, sentinel-delimited token list: the
# segment-separator pattern is first replaced, in a single native regex
# substitution, with a whitespace-surrounded sentinel token that cannot
# occur in real input (a NUL-prefixed marker — see `protect-specials`
# below for why NUL is a safe choice of prefix); the WHOLE command is then
# split on whitespace ONCE. Each of those two steps is a single native
# call over the whole command, not a closure invoked once per segment —
# this is what keeps a command with many SEGMENTS as fast as one with many
# TOKENS. Shared by `tokenize-fast` (splits the flat list into segments
# immediately) and `tokenize-resolved` (which must unprotect the flat list
# before splitting it into segments — see there for why the order
# matters), so this pass is paid once, not once per caller.
def flat-tokens-with-sentinel [command: string]: nothing -> record<flat: list<string>, sentinel: string> {
    let sentinel = "\u{0}SEG"
    let sep_pattern = '(?:&&|\|\||;|\||&|\n)'
    let marked = ($command | str replace --all --regex $sep_pattern $" ($sentinel) ")
    let flat = ($marked | split row -r '[ \t]+' | where ($it | is-not-empty))
    {flat: $flat, sentinel: $sentinel}
}

# Fast path: no quote or backslash anywhere in the command, so segment and
# token boundaries are exactly the unquoted-separator and whitespace runs.
# `split list` recovers segment boundaries from the sentinel-marked flat
# list built by `flat-tokens-with-sentinel`.
#
# An earlier revision of this function DID nest an `each` over segments
# purely to run a second, per-segment `split row` — no `append`, so not
# the accumulator-copy defect below, but a real per-segment closure cost
# all the same: measured ~350ms at 8,000 `;`-separated segments, versus
# ~26ms for the single-pass version here at the same segment count.
def tokenize-fast [command: string]: nothing -> list<list<string>> {
    let r = (flat-tokens-with-sentinel $command)
    $r.flat | split list {|x| $x == $r.sentinel }
}

# Fast path for a command carrying only well-formed quotes/escapes:
# resolves every special span once (`resolve-wellformed`), then unprotects
# the WHOLE flat token list in ONE native call before splitting it into
# segments — not `each {|seg| unprotect-list $seg }` over already-split
# segments, which pays one `unprotect-list` invocation per segment instead
# of one for the whole command. Re-measured at claude-skills-340's
# recalibrated ~4,000-segment fixture (halved from an earlier 8,000, this
# machine, min-of-three, hook as subprocess): the per-segment form (Rev 2)
# measured ~145ms (144-148ms across repeated runs); unprotecting once and
# splitting after (this revision) measured ~102.5ms (102.4-102.8ms across
# repeated runs) — still faster at this smaller fixture, so the
# single-call form is kept.
#
# Two earlier revisions were both quadratic, in two different dimensions,
# from the same underlying mechanism — growing a list inside a loop:
#   - Rev 1 reshaped a flattened, already-unprotected token list back into
#     segments with `$out = ($out | append [...])` inside a `for` loop over
#     segment lengths. `append` copies the accumulator on every call, so
#     that reshape was quadratic in SEGMENT COUNT — Gate 3 measured 465ms /
#     1337ms / 4654ms at 2,000 / 4,000 / 8,000 `;`-separated segments (a
#     single quoted argument elsewhere in the command), and an everyday
#     5,000-line command with one quoted argument regressed from 1.6s to
#     6.05s.
#   - Rev 2 removed the accumulator (`each {|seg| unprotect-list $seg }` —
#     linear, not quadratic) but still measured too close to the 500ms
#     budget once `tokenize-fast`'s OWN per-segment nested `each` (see
#     above, ~350ms at 8,000 segments) was added on top. That cost was in
#     `tokenize-fast`, not here — fixing `tokenize-fast`'s own per-segment
#     loop (above) is what actually restored the margin.
#   - This revision (Rev 3) replaces Rev 2's per-segment `unprotect-list`
#     with the single-call form above, per the re-measurement noted there.
def tokenize-resolved [command: string]: nothing -> list<list<string>> {
    let r = (flat-tokens-with-sentinel $command)
    (unprotect-list $r.flat) | split list {|x| $x == $r.sentinel }
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

    if not $has_quote_or_backslash {
        return (tokenize-fast $command)
    }

    if (has-unterminated-quote $command) {
        return (tokenize-slow $command)
    }

    tokenize-resolved (resolve-wellformed $command)
}
