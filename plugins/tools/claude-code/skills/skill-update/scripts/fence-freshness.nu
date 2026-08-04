#!/usr/bin/env nu

# Freshness report for version literals pinned inside markdown code fences
# and non-markdown templates (claude-skills-176).
#
# `version_pin` (test/validate-skills-quality.nu, check 17) parses PROSE
# claims ("Current stable: X") and checks them for agreement with
# sources.toml — it never looks inside a fence. Extending that agreement
# check to cover fences was explicitly rejected in claude-skills-176: it
# only relocates the rot, because agreement is not freshness — the corpus
# already proves this (the mise skill's prose pin passes version_pin via
# sources.md agreement while sitting months behind upstream). This script
# is the alternative the bee asks for instead: a manually-run report that
# queries upstream live and is honest about that network dependence —
# deliberately NOT wired into `mise test`/`mise run ci`. Run via
# `mise sources:fence-check`.
#
# Registry: plugins/tools/claude-code/skills/skill-update/fenced-literals.toml
# (schema validated network-free by test/validate-fenced-literals.nu, which
# IS wired into `mise test` — it checks the registry against the doc
# content, not against upstream).
#
# Encoded policy (claude-skills-176, carrying forward claude-skills-174's ad
# hoc rule explicitly): a literal needs a fix when EITHER (a) it is past its
# documented end-of-life, OR (b) it no longer resolves upstream at all — the
# doc's own example would fail to run. A literal that is simply not the
# newest available, while still supported and still resolving, is NOT
# flagged — "in-support-but-not-latest" pins are deliberately left alone.
# `policy = "intentional-pin"` in the registry (with notes explaining why,
# same convention as sources.toml's check_method=none) overrides the EOL
# half of that rule but NOT the broken half — an intentional pin whose
# target has been deleted upstream still produces code that cannot run,
# which is exactly the failure mode this tool exists to catch regardless of
# intent.

use sources-lib.nu [catch-http-error]

const USER_AGENT = "claude-skills-fence-freshness/1.0 (github.com/vinnie357/claude-skills)"

# ---- classification (pure, no network) -------------------------------------

# Decide the report status for one literal. Pure, self-tested below.
#
#   policy: "track" | "intentional-pin"           — from the registry
#   exists: true | false | "unknown"               — does the exact pin still
#           resolve upstream? "unknown" covers check_method=manual and any
#           network/classification failure.
#   is_eol: true | false | "unknown"                — is the pinned target
#           past its documented end-of-life? "unknown" covers literals with
#           no eol_product configured, or a cycle endoflife.date doesn't list.
#
# `exists == false` (BROKEN) wins over everything, including
# policy=intentional-pin — a deleted upstream target produces code that
# cannot run no matter how deliberately it was chosen. Below that: an
# intentional pin never gets flagged for EOL or for trailing latest (that's
# the whole point of marking it intentional). Below THAT: EOL wins over
# "just behind" — the one failure mode a freshness tool must not have is
# calling an EOL version current.
export def classify-fence-status [policy: string, exists: any, is_eol: any]: nothing -> string {
    if $exists == false {
        "broken"
    } else if $policy == "intentional-pin" {
        "intentional-pin"
    } else if $exists == "unknown" {
        "unknown"
    } else if $is_eol == true {
        "eol"
    } else {
        "ok"
    }
}

# ---- network boundary: does the exact pin still resolve? -------------------

# Shared catch-block body for both check-*-tag-exists functions below. Pure
# (given an already-caught `$err` record), self-tested with fixture err
# records — the exact seam claude-skills-210 Gate 3 named after `check-npm`
# shipped with untested parsing: a check-* function's HTTP call and its
# response/error interpretation must be separable so the interpretation is
# testable without the network.
export def existence-from-error [err: record]: nothing -> record {
    let classified = (catch-http-error $err)
    if $classified == "no-releases" {
        {exists: false, detail: "tag not found"}
    } else {
        {exists: "unknown", detail: $classified}
    }
}

# Check whether a specific GitHub release TAG exists (not "latest" — the
# exact pinned tag). Distinguishes "genuinely deleted/renamed" from "network
# hiccup" the same way sources-lib.nu's check-* functions do, via
# existence-from-error / catch-http-error.
export def check-github-tag-exists [repo: string, tag: string]: nothing -> record {
    let url = $"https://api.github.com/repos/($repo)/releases/tags/($tag)"
    let token = $env.GITHUB_TOKEN? | default ""
    let headers = if ($token | is-not-empty) {
        [Authorization $"Bearer ($token)" User-Agent $USER_AGENT]
    } else {
        [User-Agent $USER_AGENT]
    }
    try {
        let response = http get -H $headers $url
        {exists: true, detail: ($response.published_at? | default "unknown")}
    } catch {|err|
        existence-from-error $err
    }
}

# Check whether a specific Docker Hub TAG exists (per-tag endpoint — a
# different question from sources-lib.nu's check-docker-hub, which reports
# the newest tag overall. claude-skills-225 established that "newest tag"
# is a degenerate staleness signal for a deliberately pinned tag; "does this
# exact tag still exist" is a narrower but genuinely answerable question).
export def check-docker-tag-exists [image: string, tag: string]: nothing -> record {
    let url = $"https://hub.docker.com/v2/repositories/($image)/tags/($tag)/"
    try {
        let response = http get $url
        {exists: true, detail: ($response.last_updated? | default "unknown")}
    } catch {|err|
        existence-from-error $err
    }
}

# Look up whether a specific release cycle is past end-of-life via
# endoflife.date. `cycle` must match the API's cycle string exactly (e.g.
# "16", "3.24", "13" — not "16.0" or "v16").
export def check-eol-status [product: string, cycle: string]: nothing -> record {
    let url = $"https://endoflife.date/api/($product).json"
    try {
        let cycles = (http get $url | default [])
        let matches = ($cycles | where {|c| ($c.cycle? | default "" | into string) == $cycle})
        if ($matches | is-empty) {
            {is_eol: "unknown", detail: "cycle not found in endoflife.date feed"}
        } else {
            let c = ($matches | first)
            let eol_date = ($c.eol? | default "")
            let eol_bool = ($eol_date | describe) == "bool" and $eol_date == true
            if $eol_bool {
                # endoflife.date renders `eol: false` for cycles with no EOL
                # date yet — a bool `true` would be unusual but handled.
                {is_eol: true, detail: "eol"}
            } else if ($eol_date | describe) == "string" and ($eol_date | is-not-empty) {
                let is_past = (try { ($eol_date | into datetime) < (date now) } catch { false })
                {is_eol: $is_past, detail: $eol_date}
            } else {
                {is_eol: false, detail: "no eol date recorded"}
            }
        }
    } catch {|err|
        {is_eol: "unknown", detail: (catch-http-error $err)}
    }
}

# ---- report row assembly ----------------------------------------------------

def check-one-literal [entry: record] {
    let check_method = ($entry.check_method? | default "manual")

    let existence = match $check_method {
        "github-releases" => (check-github-tag-exists ($entry.github_repo? | default "") ($entry.pinned_tag? | default ""))
        "docker-hub" => (check-docker-tag-exists ($entry.docker_image? | default "") ($entry.pinned_tag? | default ""))
        _ => {exists: "unknown", detail: "check_method=manual — no automated existence check"}
    }

    let eol = if ($entry.eol_product? | default "" | is-not-empty) {
        check-eol-status $entry.eol_product ($entry.eol_cycle? | default "")
    } else {
        {is_eol: "unknown", detail: "no eol_product configured"}
    }

    let policy = ($entry.policy? | default "track")
    let status = classify-fence-status $policy $existence.exists $eol.is_eol

    {
        file: $entry.file
        literal: $entry.literal
        check_method: $check_method
        exists: $existence.exists
        exists_detail: $existence.detail
        eol: $eol.is_eol
        eol_detail: $eol.detail
        policy: $policy
        status: $status
        notes: ($entry.notes? | default "")
    }
}

# ---- self-test (pure classification only; no network) ----------------------

def run-self-test [] {
    mut failed = false
    let cases = [
        {label: "broken wins over intentional-pin — deleted target is never OK" policy: "intentional-pin" exists: false is_eol: true want: "broken"}
        {label: "broken wins over track+not-eol too" policy: "track" exists: false is_eol: false want: "broken"}
        {label: "intentional-pin suppresses EOL flag (the node:16-buster-slim case)" policy: "intentional-pin" exists: true is_eol: true want: "intentional-pin"}
        {label: "intentional-pin suppresses ok flag too — still reported as intentional-pin" policy: "intentional-pin" exists: true is_eol: false want: "intentional-pin"}
        {label: "unknown existence (manual check_method) reports unknown, not ok" policy: "track" exists: "unknown" is_eol: "unknown" want: "unknown"}
        {label: "track + exists + eol is flagged eol" policy: "track" exists: true is_eol: true want: "eol"}
        {label: "track + exists + not eol is ok (in-support-but-not-latest is NOT flagged)" policy: "track" exists: true is_eol: false want: "ok"}
        {label: "track + exists + eol unknown (no eol_product configured) is ok, not eol" policy: "track" exists: true is_eol: "unknown" want: "ok"}
    ]
    for c in $cases {
        let got = classify-fence-status $c.policy $c.exists $c.is_eol
        if $got != $c.want {
            print $"(ansi red_bold)❌ classify-fence-status: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    # existence-from-error (claude-skills-176 Gate 3 F2/F4): fixture-based
    # cases against the actual catch-block interpretation, not just the
    # policy layer above it. F2 shipped a bare-word bug (`detail: classified`
    # instead of `detail: $classified` — nushell reads a bare identifier
    # inside a record literal as the STRING "classified", not the variable)
    # that no test caught, because only classify-fence-status had fixture
    # coverage. These cases would have failed on that bug: `.detail` would
    # have been the literal string "classified" instead of a real
    # classification.
    let error_cases = [
        {label: "404 debug text -> exists false, detail names the tag" err: {debug: "Requested file not found (404): \"x\""} want_exists: false want_detail: "tag not found"}
        {label: "403 debug text -> exists unknown, detail carries the real classification" err: {debug: "Access forbidden (403) to \"x\""} want_exists: "unknown" want_detail: "rate-limited"}
        {label: "429 msg text (no debug field) -> exists unknown, detail carries rate-limited" err: {msg: "Cannot make request to \"x\". Error is \"429 Too Many Requests\""} want_exists: "unknown" want_detail: "rate-limited"}
        {label: "unrelated network failure -> exists unknown, detail carries generic error" err: {debug: "Could not resolve host: example.com"} want_exists: "unknown" want_detail: "error"}
        {label: "empty error record -> exists unknown, detail carries generic error, not the literal word 'classified'" err: {} want_exists: "unknown" want_detail: "error"}
    ]
    for c in $error_cases {
        let got = existence-from-error $c.err
        if $got.exists != $c.want_exists or $got.detail != $c.want_detail {
            print $"(ansi red_bold)❌ existence-from-error: ($c.label): want \(exists=($c.want_exists), detail=($c.want_detail)\), got \(exists=($got.exists), detail=($got.detail)\)(ansi reset)"
            $failed = true
        }
    }

    let total = ($cases | length) + ($error_cases | length)
    if $failed { exit 1 }
    print $"(ansi green_bold)✅ fence-freshness self-test passed \(($total) cases\)(ansi reset)"
    exit 0
}

def repo-root [] {
    $env.FILE_PWD | path join ".." ".." ".." ".." ".." ".." | path expand
}

def main [--self-test] {
    if $self_test {
        run-self-test
    }

    let repo = repo-root
    let toml_path = ($repo | path join "plugins" "tools" "claude-code" "skills" "skill-update" "fenced-literals.toml")
    if not ($toml_path | path exists) {
        print $"(ansi red)No fenced-literals.toml found at ($toml_path)(ansi reset)"
        exit 1
    }

    print $"(ansi cyan_bold)Fenced Literal Freshness Report(ansi reset)"
    print "On-demand, network-dependent — not part of mise test/mise run ci."
    print ""

    let entries = (open $toml_path | get -o literals | default [])
    if ($entries | is-empty) {
        print $"(ansi yellow)No literals registered.(ansi reset)"
        exit 0
    }

    mut rows = []
    for e in $entries {
        print $"  Checking ($e.file) :: ($e.literal)..."
        $rows = ($rows | append (check-one-literal $e))
    }

    # Per-row lines, not a wide table — a table this wide (file, literal,
    # status, exists, eol, policy, notes) truncates unreadably in a normal
    # terminal. One line per literal keeps every field visible.
    print ""
    for r in $rows {
        let badge = match $r.status {
            "ok" => "🟢 ok"
            "eol" => "🔴 EOL"
            "broken" => "⚫ broken"
            "intentional-pin" => "🔵 intentional-pin"
            "unknown" => "❔ unknown"
            _ => $r.status
        }
        print $"($badge)  ($r.file) :: ($r.literal)"
        print $"       exists=($r.exists) \(($r.exists_detail)\)  eol=($r.eol) \(($r.eol_detail)\)"
    }

    let needs_fix = ($rows | where {|r| $r.status in ["broken" "eol"]})
    print ""
    if ($needs_fix | is-empty) {
        print $"(ansi green_bold)✅ No literals need a fix under the encoded policy \(EOL or broken\).(ansi reset)"
    } else {
        print $"(ansi red_bold)⚠ ($needs_fix | length) literal\(s\) need a fix:(ansi reset)"
        for r in $needs_fix {
            print $"  • ($r.file) :: ($r.literal) — ($r.status): ($r.exists_detail) / ($r.eol_detail)"
        }
    }
}
