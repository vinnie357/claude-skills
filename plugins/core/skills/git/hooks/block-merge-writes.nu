#!/usr/bin/env nu

# PreToolUse hook for claude-skills-340 (merge-write gate). Backstops the
# forbidden-writes list in /core:git's "Merge authorization" / "Forbidden"
# section by blocking the matching gh/glab invocations at the Bash tool
# boundary.
#
# CRITICAL — this is a cheap deterministic gate, not a security boundary
# (operator decision, 2026-09-05, claude-skills-340; do not re-litigate).
# It exists for the same reason a linter exists: to catch the everyday
# mistake and enforce a direction cheaply. It does not stop an agent
# actively trying to get around it, and it is not judged on whether it
# could. Evasion via `$( )`, a shell alias, `bash -c`, a variable-held
# command name, a subshell or brace group, `!`/`time`/`then`/`do`
# prefixes, or an emptied `--match-head-commit=` is OUT OF SCOPE BY
# DESIGN, not a gap to close — see /core:git for the same statement.
#
# claude-skills-331 coordination: this hook establishes the shape (a
# scanner module exporting one tokenizer, a PreToolUse entrypoint reading
# the harness's JSON payload, and `hooks:` frontmatter wiring in the
# owning skill's SKILL.md) for a later, separate hook over a different
# rule set. 331 is blocked on claude-skills-281 and adopts this shape when
# it lands; this file does not build a shared framework for a hook that
# does not exist yet.
#
# Exit 2 blocks — per /claude-code:claude-hooks, exit 2 is the ONLY code
# that blocks a PreToolUse tool call; exit 1, a missing script, a
# non-executable script, and a timeout are all non-blocking. Exit 0
# allows: a non-Bash tool_name, malformed/absent/empty stdin, and any
# command the rules below do not block. Never echoes the command text
# back on stderr — this hook is not a security boundary, but stderr
# should not be silent either.

use scan-merge-writes.nu *

def is-assignment-word [t: string]: nothing -> bool {
    $t =~ '^[A-Za-z_][A-Za-z0-9_]*='
}

# Finds a `gh api` method token among `rest` (tokens after "api"):
# `--method X`, `--method=X`, `-X X`, or joined `-XVALUE`. Returns the
# value string, or null when no method token is present.
def find-method [rest: list<string>] {
    let n = ($rest | length)
    mut i = 0
    mut found = null
    while $i < $n {
        let t = ($rest | get $i)
        if $t == "--method" and ($i + 1) < $n {
            $found = ($rest | get ($i + 1))
            break
        } else if ($t | str starts-with "--method=") {
            $found = ($t | str substring 9..)
            break
        } else if $t == "-X" and ($i + 1) < $n {
            $found = ($rest | get ($i + 1))
            break
        } else if ($t | str starts-with "-X") and ($t | str length) > 2 {
            $found = ($t | str substring 2..)
            break
        }
        $i = $i + 1
    }
    $found
}

# Decides whether one segment's dequoted tokens match a forbidden gh/glab
# merge-write pattern. See claude-skills-340 "Decision rules — per
# segment, on dequoted tokens" for the spec each branch below implements.
def decide-segment [tokens: list<string>]: nothing -> bool {
    if ($tokens | is-empty) {
        return false
    }

    let n = ($tokens | length)

    # Skip leading NAME=value assignment words (e.g. `GH_TOKEN=x gh ...`).
    mut idx = 0
    while $idx < $n and (is-assignment-word ($tokens | get $idx)) {
        $idx = $idx + 1
    }
    if $idx >= $n {
        return false
    }

    let cmd_token = ($tokens | get $idx)
    if $cmd_token != "gh" and $cmd_token != "glab" {
        return false
    }
    $idx = $idx + 1

    # Skip global flags and their values to find the subcommand — a flag
    # carrying `=` (`--repo=o/r`) is one token and consumes no following
    # token; `-R`/`--repo`/`--hostname` given as a separate word consume
    # the next token as their value.
    while $idx < $n {
        let t = ($tokens | get $idx)
        if $t == "-R" or $t == "--repo" or $t == "--hostname" {
            $idx = $idx + 2
        } else if ($t | str starts-with "--repo=") or ($t | str starts-with "--hostname=") {
            $idx = $idx + 1
        } else {
            break
        }
    }

    # Any segment carrying --help or -h passes, whatever else it matches.
    if ($tokens | any {|t| $t == "--help" or $t == "-h" }) {
        return false
    }

    if $idx >= $n {
        return false
    }

    let subcommand1 = ($tokens | get $idx)
    let subcommand2 = if ($idx + 1) < $n { $tokens | get ($idx + 1) } else { "" }

    if $cmd_token == "gh" and $subcommand1 == "pr" and $subcommand2 == "merge" {
        let rest = ($tokens | skip ($idx + 2))
        let has_auto = ($rest | any {|t| $t == "--auto" })
        let has_admin = ($rest | any {|t| $t == "--admin" })
        let has_match = ($rest | any {|t|
            $t == "--match-head-commit" or ($t | str starts-with "--match-head-commit=")
        })
        return ($has_auto or $has_admin or (not $has_match))
    }

    if $cmd_token == "glab" and $subcommand1 == "mr" and $subcommand2 == "merge" {
        let rest = ($tokens | skip ($idx + 2))
        let has_auto_merge_false = ($rest | any {|t| $t == "--auto-merge=false" })
        return (not $has_auto_merge_false)
    }

    if $cmd_token == "gh" and $subcommand1 == "api" {
        let rest = ($tokens | skip ($idx + 1))
        if $subcommand2 == "graphql" {
            return ($rest | any {|t| $t | str contains "mutation" })
        }
        let method = (find-method $rest)
        let non_get = if $method != null {
            (($method | str downcase) != "get")
        } else {
            # gh api switches to POST when parameters are supplied, with
            # no explicit method token.
            ($rest | any {|t|
                $t == "-f" or $t == "-F" or $t == "--raw-field" or $t == "--field" or $t == "--input"
            })
        }
        if not $non_get {
            return false
        }
        # /issues/comments/ is the deletion shape; /issues/<n>/comments
        # (posting a Gate 3 record) does not match this and passes.
        return ($rest | any {|t| ($t | str contains "/pulls/") or ($t | str contains "/issues/comments/") })
    }

    false
}

def command-blocked [command: string]: nothing -> bool {
    # Early-out: the common case on every Bash call, so it must cost one
    # substring test — see claude-skills-340 "Performance budget".
    if not (($command | str contains "gh") or ($command | str contains "glab")) {
        return false
    }
    let segments = (tokenize-command $command)
    $segments | any {|tokens| decide-segment $tokens }
}

def main [] {
    # `$in` is empty for piped stdin inside `def main` in a nu script;
    # reading via an external command is the faithful way to observe both
    # a real payload and truly absent/empty stdin identically.
    let raw = (^cat)
    if ($raw | is-empty) {
        exit 0
    }

    let parsed = (try {
        let payload = ($raw | from json)
        {
            tool_name: ($payload | get -o tool_name | default ""),
            command: ($payload | get -o tool_input | get -o command | default "")
        }
    } catch {
        {tool_name: "", command: ""}
    })

    if $parsed.tool_name != "Bash" {
        exit 0
    }
    if ($parsed.command | is-empty) {
        exit 0
    }

    if (command-blocked $parsed.command) {
        print -e "blocked: forbidden gh/glab merge-write pattern (claude-skills-340) — see /core:git \"Forbidden\" and \"Merge authorization\". This is a cheap gate, not a security boundary."
        exit 2
    }

    exit 0
}
