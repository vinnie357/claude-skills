#!/usr/bin/env nu

# Shared fetch/classify logic for sources-check.nu, sources-stale.nu, and
# sources-report.nu (claude-skills-211).
#
# PR #197 fixed a real bug in this logic (unknown pins reported as drift)
# and had to apply the fix three times. The classify-fetch-error /
# classify-staleness bodies WERE byte-identical across the three scripts
# (confirmed by the reviewer diffing all three against this module); the
# next bug needed fixing three times again — this module is the fix for
# that: one copy, imported by all three scripts.
#
# Correction (claude-skills-211 Gate 3): "byte-identical copies" does NOT
# describe check-github-releases/check-crates-io — each script embedded its
# own per-script User-Agent string ("sources-check.nu/1.0",
# "sources-stale.nu/1.0", "sources-report.nu/1.0 (claude-skills)", ...).
# This module unifies all of them to one constant, $USER_AGENT below — a
# deliberate, documented behavior change: upstream APIs now see one client
# identity instead of three. Benign (User-Agent affects only what a request
# identifies itself as, not response content), but it IS a behavior change
# and was previously mis-reported as none.
#
# Import via `use sources-lib.nu *` from a sibling script. Nushell resolves
# a static relative `use`/`source` path against the IMPORTING FILE's own
# directory, not the process's current working directory — verified
# empirically against nu 0.113.1 before extraction (claude-skills-211 AC),
# both for a repo-root-relative invocation (`nu "plugins/.../sources-check.nu"`
# from repo root, the shape every `mise sources:*` task uses) and an
# absolute-path invocation from an unrelated cwd. Both resolved the sibling
# module correctly; this is why extraction was safe to do at all — the plan
# left "record a decision that triplication is accepted" as the fallback
# specifically for the case where the import pattern didn't resolve.
#
# Zero network calls in the classify-*/sanitize-*/catch-http-error functions
# — only the check-* functions and fetch-latest's dispatch hit the network.
# `run-self-test` below exercises every pure function with zero network
# calls; each importing script's own `--self-test` flag calls it.

# ---- classification (pure, no network) -------------------------------------

# Classify a caught HTTP error's text into a specific latest-version sentinel.
#
# claude-skills-176: a dead/404 release feed and a rate-limited/
# unauthenticated GitHub response both used to collapse into a generic
# "error" — no way to tell "this source will never have a releases feed"
# from "try again with a token".
#
# claude-skills-176 Gate 3 (F3): match `(404)`/`(403)` WITH the parens, not
# bare digits. nushell's HTTP error text always wraps a parenthesised status
# as `(404):`/`(403):` for those two codes specifically (verified against
# real nu 0.113.1 — see the self-test fixtures below, copied from actual
# caught errors); a byte-offset span (`Span[160039..160404]`) never renders
# digits inside parens, so requiring them is structural, not just narrower.
#
# claude-skills-212: GitHub's 429 (secondary rate limit) does NOT render
# with parens — empirically verified against nu 0.113.1 hitting a live
# 429-returning endpoint, the shape is `... Error is "429 Too Many
# Requests"` (401 and 500 take the same bare, no-parens shape). Matching the
# literal phrase "Too Many Requests" is structural in the same sense the
# parenthesised-digit match is: a byte-offset span contains only digits and
# `..`, never that phrase, so it can't collide the way a bare `str contains
# "429"` would.
#
# claude-skills-212: hex-pm, crates-io, npm, and Docker Hub all go through
# this same function via catch-http-error below — verified empirically that
# a 404 against hex.pm renders with the identical `(404)` parenthesised
# shape nushell uses for github.com (same underlying HTTP client), so no
# per-method classification is needed.
export def classify-fetch-error [err_text: string]: nothing -> string {
    let is_rate_limited = (
        ($err_text | str contains "(403)")
        or ($err_text | str contains "Too Many Requests")
        or ($err_text | str downcase | str contains "rate limit")
    )
    if ($err_text | str contains "(404)") {
        "no-releases"
    } else if $is_rate_limited {
        "rate-limited"
    } else {
        "error"
    }
}

# Shared catch-block body for every check-* function below. nushell's `http
# get` catch always exposes the failure text as `$err.debug` or, absent
# that, `$err.msg` — every check-* function used to repeat this exact
# fallback chain inline (three copies before extraction); this is the single
# place it lives now, which is also what makes hex-pm/crates-io/npm/
# docker-hub/endoflife-date classifiable on the same axes as github-releases
# (claude-skills-212) — they all funnel through it.
export def catch-http-error [err: record]: nothing -> string {
    classify-fetch-error ($err.debug? | default ($err.msg? | default ""))
}

# Classify (current, latest) into a staleness sentinel.
#
# claude-skills-176: `current_version = "unknown"` is a documented schema
# placeholder (test/validate-sources.nu's VERSION_SHAPE_RE accepts it as a
# literal) meaning "no pin recorded to compare against upstream", not a real
# version. Comparing it against `latest` made every such entry (152 in the
# corpus today) report false-positive drift. It classifies as "no-pin",
# distinct from "unset" (field genuinely absent) and "yes" (a real pin is
# behind).
#
# claude-skills-176 Gate 3 (F4): the equality check strips a leading `v` from
# BOTH sides before comparing — only for the comparison, the displayed
# `current`/`latest` values are untouched. `check-github-releases` already
# strips `v` from the upstream tag, but `current_version` in sources.toml is
# free text and sometimes keeps it (e.g. "v0.0.0"), so "v0.0.0" vs "0.0.0"
# compared unequal and reported false-positive drift for an entry that is
# actually current.
export def classify-staleness [current: string, latest: string]: nothing -> string {
    if $latest == "internal" {
        "no"
    } else if $latest == "manual" {
        "manual"
    } else if $latest == "no-releases" {
        "no-releases"
    } else if $latest == "rate-limited" {
        "rate-limited"
    } else if $latest == "unknown" {
        "unknown"
    } else if $latest == "error" {
        "error"
    } else if $current == "unset" {
        "unset"
    } else if $current == "unknown" {
        "no-pin"
    } else if ($current | str replace -r '^v' '') != ($latest | str replace -r '^v' '') {
        "yes"
    } else {
        "no"
    }
}

# Sanitize a notes string for embedding as ONE markdown table cell (used by
# sources-report.nu).
#
# claude-skills-176 Gate 3 (F1): GFM only continues a table across ADJACENT
# `|`-prefixed lines — a non-table line breaks it. A `|` or newline INSIDE
# the cell is just as fatal (unescaped `|` reads as a new column boundary, a
# raw newline ends the row), so both must be neutralized before the value
# goes anywhere near a `| ... |` line.
export def sanitize-notes-cell [notes: string, max_len: int]: nothing -> string {
    let flat = ($notes | str replace --all "|" "\\|" | str replace --all --regex '\s+' " " | str trim)
    if ($flat | str length) > $max_len {
        ($flat | str substring 0..($max_len - 1)) + "…"
    } else {
        $flat
    }
}

# ---- network boundary -------------------------------------------------

# claude-skills-220: exported so sources-validate-urls.nu can send the same
# identity on its HEAD/GET checks instead of nushell's unadorned default
# (the literal string "nushell" — verified live against httpbin.org/headers,
# 2026-08-04), which crates.io's API rejects as insufficiently informative.
export const USER_AGENT = "claude-skills-sources/1.0 (github.com/vinnie357/claude-skills)"

# Check latest version via github-releases API
export def check-github-releases [repo: string] {
    let url = $"https://api.github.com/repos/($repo)/releases/latest"
    let token = $env.GITHUB_TOKEN? | default ""
    let headers = if ($token | is-not-empty) {
        [Authorization $"Bearer ($token)" User-Agent $USER_AGENT]
    } else {
        [User-Agent $USER_AGENT]
    }
    try {
        let response = http get -H $headers $url
        let tag = $response.tag_name? | default ""
        $tag | str replace -r '^v' ''
    } catch {|err|
        catch-http-error $err
    }
}

# Check latest version via hex.pm API
export def check-hex-pm [package: string] {
    let url = $"https://hex.pm/api/packages/($package)"
    try {
        let response = http get $url
        let releases = $response.releases? | default []
        if ($releases | length) > 0 {
            $releases | first | get version? | default "unknown"
        } else {
            "unknown"
        }
    } catch {|err|
        catch-http-error $err
    }
}

# Check latest version via crates.io API
export def check-crates-io [crate_name: string] {
    let url = $"https://crates.io/api/v1/crates/($crate_name)"
    let headers = [User-Agent $USER_AGENT]
    try {
        let response = http get -H $headers $url
        $response.crate?.max_version? | default "unknown"
    } catch {|err|
        catch-http-error $err
    }
}

# Parse the npm registry's package-metadata response into a latest-version
# string. Pure, self-tested below against a captured response fixture.
#
# claude-skills-210 Gate 3 BLOCKER: the original inline implementation used
# `get -o "dist-tags.latest"` — a QUOTED string. nushell's `get` treats a
# quoted string argument as ONE flat column name, not a dotted cell path; it
# is only the UNQUOTED bareword form (`get dist-tags.latest`) that nushell's
# cell-path grammar splits on the dot. The real response has no flat column
# literally named "dist-tags.latest" (it is nested: `{"dist-tags": {"latest":
# ...}}`), so the quoted form silently missed on every call and always fell
# through to "unknown" — verified live against registry.npmjs.org/express
# both ways before and after the fix. This function existing separately from
# check-npm's network call is what makes that a self-testable fact instead of
# something only a live call could have caught: a fixture record proves the
# parse logic without touching the network.
export def parse-npm-latest [response: record]: nothing -> string {
    $response | get -o dist-tags.latest | default "unknown"
}

# Check latest version via the npm registry API (claude-skills-210).
# `package` is an npm package name (scoped names like "@scope/name" work
# unmodified — the registry accepts the literal name in the URL path).
export def check-npm [package: string] {
    let url = $"https://registry.npmjs.org/($package)"
    try {
        let response = http get $url
        parse-npm-latest $response
    } catch {|err|
        catch-http-error $err
    }
}

# Parse a Docker Hub Hub API tags-list response into a latest-tag string.
# Pure, self-tested below against a captured response fixture.
export def parse-docker-hub-latest [response: record]: nothing -> string {
    let results = ($response.results? | default [])
    if ($results | is-empty) {
        "unknown"
    } else {
        $results | first | get -o name | default "unknown"
    }
}

# Check latest version via the Docker Hub Hub API tags list, sorted by
# last_updated (claude-skills-210). `image` is "namespace/repository", e.g.
# "library/node" for an official image. Reports the most-recently-updated
# tag's name as "latest" — Docker Hub tags are not semver in general (a
# pinned tag like "16-buster-slim" has no single successor the way a GitHub
# release does), so this answers "is a newer tag available" rather than "is
# there a newer semver release"; classify-staleness's plain string
# comparison still applies (equal tag names are "no", anything else is
# "yes"), same as every other check_method.
#
# `ordering=last_updated` (no leading `-`) is NEWEST-first — verified live
# against the Hub API (library/node returns the just-published tag at
# index 0). This is non-obvious: Hub's own docs use `-field` for descending
# on some other endpoints, which reads like it SHOULD be `-last_updated`
# here too. It is not — `-last_updated` returns OLDEST-first (the opposite
# of what this function needs). Do not "fix" this to add the minus sign.
export def check-docker-hub [image: string] {
    let url = $"https://hub.docker.com/v2/repositories/($image)/tags?page_size=1&ordering=last_updated"
    try {
        let response = http get $url
        parse-docker-hub-latest $response
    } catch {|err|
        catch-http-error $err
    }
}

# Parse a Docker Hub per-tag response (the /tags/{tag}/ endpoint, not the
# tags-list endpoint) into that tag's content digest. Pure, self-tested
# below against a captured response fixture.
export def parse-docker-hub-tag-digest [response: record]: nothing -> string {
    $response | get -o digest | default "unknown"
}

# Check whether a SPECIFIC pinned Docker Hub tag's content has changed,
# via the per-tag endpoint (claude-skills-225). `image` is
# "namespace/repository" (e.g. "library/node"), `tag` is the exact pinned
# tag (e.g. "16-buster-slim").
#
# claude-skills-225: check-docker-hub above compares the NEWEST tag's NAME
# against current_version, which is degenerate for a realistically pinned
# image — current_version="unknown"/rolling (the schema's own prescribed
# usage) never transitions because "unknown" is never compared, and a
# version-shaped pin never transitions either because the newest tag on a
# high-churn alias (e.g. "lts-trixie-slim") never equals a stable pin like
# "16-buster-slim". Neither state can report drift.
#
# This function answers a different, narrower, but genuinely answerable
# question instead: has THIS exact tag been re-pushed since I last checked?
# Docker Hub's per-tag `digest` is a content hash of the tag's current
# manifest — verified live (2026-08-04) that /tags/{tag}/ returns a `digest`
# field distinct from `name`. Comparing the last-observed digest
# (current_version) against a freshly-fetched digest (latest) via the
# existing classify-staleness equality check transitions correctly in both
# directions: unchanged tag -> same digest -> "no"; re-pushed tag (patched
# base image, rebuilt binary, etc.) -> different digest -> "yes". A deleted
# tag 404s and is classified "no-releases" by the existing
# catch-http-error path, same as every other check_method.
#
# Used by fetch-latest when a source sets the optional `docker_tag` field
# (see templates/sources.toml); check-docker-hub above remains the
# behavior when `docker_tag` is absent, unchanged for backward
# compatibility.
export def check-docker-hub-tag [image: string, tag: string]: nothing -> string {
    let url = $"https://hub.docker.com/v2/repositories/($image)/tags/($tag)/"
    try {
        let response = http get $url
        parse-docker-hub-tag-digest $response
    } catch {|err|
        catch-http-error $err
    }
}

# Parse one endoflife.date release-cycle record's own `eol` field into a
# tri-state: true (past EOL), false (not EOL / no EOL date set), or
# "unknown" (an eol date string that fails to parse). Pure, self-tested
# below against captured cycle fixtures (centos "8" — a past ISO date — and
# nodejs "26" — a future ISO date).
#
# endoflife.date renders `eol` as either a boolean `false` (no EOL date
# scheduled) or an ISO date string (past or future) — verified against both
# the centos and nodejs feeds (2026-08-04). A boolean `true` would be
# unusual but is handled the same way fence-freshness.nu's check-eol-status
# already handles it, for consistency between the two EOL-parsing call
# sites.
export def parse-endoflife-cycle-eol [cycle: record]: nothing -> any {
    let eol_val = ($cycle.eol? | default false)
    if ($eol_val | describe) == "bool" {
        $eol_val
    } else if ($eol_val | describe) == "string" and ($eol_val | is-not-empty) {
        try { ($eol_val | into datetime) < (date now) } catch { "unknown" }
    } else {
        false
    }
}

# Parse an endoflife.date product-cycles response into the newest cycle's
# latest-version string, its own eol state, and its cycle identifier. Pure,
# self-tested below against captured response fixtures.
export def parse-endoflife-status [cycles: list]: nothing -> record<latest: string, eol: any, cycle: string> {
    let c = ($cycles | default [])
    if ($c | is-empty) {
        {latest: "unknown", eol: "unknown", cycle: "unknown"}
    } else {
        let newest = ($c | first)
        {
            latest: ($newest | get -o latest | default "unknown"),
            eol: (parse-endoflife-cycle-eol $newest),
            cycle: ($newest | get -o cycle | default "unknown" | into string)
        }
    }
}

# Parse an endoflife.date product-cycles response into a latest-version
# string. Pure, self-tested below against a captured response fixture.
export def parse-endoflife-latest [cycles: list]: nothing -> string {
    (parse-endoflife-status $cycles).latest
}

# Check the newest release cycle's latest patch version AND whether that
# cycle is itself past its own end-of-life date (claude-skills-226).
# `product` is the endoflife.date product slug (e.g. "nodejs"). One network
# call serves both check-endoflife-date (below, unchanged string contract)
# and any caller that wants the EOL sentinel — verified empirically against
# the real nodejs.json (not EOL) and centos.json (EOL, confirming the exact
# behavior claude-skills-226 reported: "8 (2111)" with eol=true) feeds
# (2026-08-04).
export def check-endoflife-status [product: string]: nothing -> record<latest: string, eol: any, cycle: string> {
    let url = $"https://endoflife.date/api/($product).json"
    try {
        let response = http get $url
        parse-endoflife-status $response
    } catch {|err|
        {latest: (catch-http-error $err), eol: "unknown", cycle: "unknown"}
    }
}

# Check latest version via the endoflife.date API (claude-skills-210).
# `product` is the endoflife.date product slug (e.g. "nodejs"). The API
# returns release cycles newest-first; the first entry's `latest` field is
# that cycle's newest patch version — verified empirically against the real
# nodejs.json feed (2026-08-04).
#
# Deliberate scope decision (Gate 3, carried forward by claude-skills-226):
# this reports the newest cycle's latest patch UNCONDITIONALLY, even when
# that cycle is itself past its own `eol` date (e.g. a fully-EOL product
# like centos still returns its last cycle's last patch as "latest"). Every
# other check_method in this file has the same shape — github-releases
# reports the newest tag whether or not the repo is archived, hex-pm/
# crates-io report the newest publish whether or not the maintainer still
# supports it. This check_method answers "is a newer version available to
# pin", the same question the others answer, not "is this product line
# still supported". claude-skills-226 added check-endoflife-status above as
# the separate, explicit EOL check this comment used to say was future
# work — call that function instead when the EOL sentinel is needed; this
# function's string-only contract stays unchanged for fetch-latest/
# classify-staleness callers.
export def check-endoflife-date [product: string] {
    (check-endoflife-status $product).latest
}

# Dispatch version check by method
export def fetch-latest [source: record] {
    let method = $source.check_method? | default "manual"
    match $method {
        "github-releases" => {
            let repo = $source.github_repo? | default ""
            if ($repo | is-empty) { "error" } else { check-github-releases $repo }
        }
        "hex-pm" => {
            let pkg = $source.hex_package? | default ""
            if ($pkg | is-empty) { "error" } else { check-hex-pm $pkg }
        }
        "crates-io" => {
            let crate_name = $source.crate_name? | default ""
            if ($crate_name | is-empty) { "error" } else { check-crates-io $crate_name }
        }
        "npm" => {
            let pkg = $source.npm_package? | default ""
            if ($pkg | is-empty) { "error" } else { check-npm $pkg }
        }
        "docker-hub" => {
            let image = $source.docker_image? | default ""
            let tag = $source.docker_tag? | default ""
            if ($image | is-empty) {
                "error"
            } else if ($tag | is-not-empty) {
                check-docker-hub-tag $image $tag
            } else {
                check-docker-hub $image
            }
        }
        "endoflife-date" => {
            let product = $source.eol_product? | default ""
            if ($product | is-empty) { "error" } else { check-endoflife-date $product }
        }
        "manual" => { "manual" }
        "none" => { "internal" }
        _ => { "unknown-method" }
    }
}

# ---- self-test (shared cases; no network) ----------------------------------

# Runs every pure-function case shared across the three importing scripts.
# Returns {failed: bool, count: int} so a caller can fold in its own
# script-specific cases (sources-stale.nu has a few) and report one combined
# total, matching the pre-extraction per-script "N cases" output shape.
export def run-self-test []: nothing -> record<failed: bool, count: int> {
    mut failed = false
    mut count = 0

    let staleness_cases = [
        {label: "unknown pin is no-pin, not drift" current: "unknown" latest: "9.9.9" want: "no-pin"}
        {label: "unset pin is unset" current: "unset" latest: "9.9.9" want: "unset"}
        {label: "matching pins are current" current: "1.0.0" latest: "1.0.0" want: "no"}
        {label: "mismatched pins are stale" current: "1.0.0" latest: "1.1.0" want: "yes"}
        {label: "manual check_method never compared" current: "1.0.0" latest: "manual" want: "manual"}
        {label: "none check_method is internal, always current" current: "unknown" latest: "internal" want: "no"}
        {label: "dead/404 release feed is no-releases, not error" current: "1.0.0" latest: "no-releases" want: "no-releases"}
        {label: "rate-limited/unauthenticated is distinct from error" current: "1.0.0" latest: "rate-limited" want: "rate-limited"}
        {label: "hex-pm/crates-io package with zero releases" current: "1.0.0" latest: "unknown" want: "unknown"}
        {label: "generic fetch failure still reported as error" current: "1.0.0" latest: "error" want: "error"}
        {label: "unknown pin plus no-releases feed: feed status wins" current: "unknown" latest: "no-releases" want: "no-releases"}
        {label: "v-prefixed pin matching a v-stripped latest is current, not stale" current: "v0.0.0" latest: "0.0.0" want: "no"}
        {label: "v-prefixed pin genuinely behind is still stale" current: "v0.0.0" latest: "0.1.0" want: "yes"}
    ]
    for c in $staleness_cases {
        $count += 1
        let got = classify-staleness $c.current $c.latest
        if $got != $c.want {
            print $"(ansi red_bold)❌ classify-staleness: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    let fetch_error_cases = [
        {label: "404 body classifies as no-releases" text: "Requested file not found (404): \"https://api.github.com/repos/x/y/releases/latest\"" want: "no-releases"}
        {label: "hex.pm 404 body classifies as no-releases (same axes as github-releases)" text: "Requested file not found (404): \"https://hex.pm/api/packages/does-not-exist\"" want: "no-releases"}
        {label: "403 status classifies as rate-limited" text: "Client error (403): API rate limit exceeded" want: "rate-limited"}
        {label: "rate limit phrase without 403 digits still matches" text: "GitHub secondary rate limit hit, retry later" want: "rate-limited"}
        {label: "429 Too Many Requests (no parens) classifies as rate-limited" text: "Cannot make request to \"https://api.github.com/repos/x/y/releases/latest\". Error is \"429 Too Many Requests\"" want: "rate-limited"}
        {label: "unrelated network failure falls through to error" text: "Could not resolve host: api.github.com" want: "error"}
        {label: "empty error text falls through to error" text: "" want: "error"}
        {label: "bare digits in a byte-offset span do NOT collide with a real (404)" text: "NetworkFailure { msg: \"Could not resolve host: api.github.com\", span: Span[160039..160404] }" want: "error"}
        {label: "bare digits spelling 403 in a span do NOT collide with a real (403)" text: "NetworkFailure { msg: \"connection reset\", span: Span[140033..140403] }" want: "error"}
        {label: "bare digits spelling 429 in a span do NOT collide with a real 429" text: "NetworkFailure { msg: \"connection reset\", span: Span[142933..142900] }" want: "error"}
        {label: "401 (no parens, same shape as 429) does not classify as rate-limited" text: "Cannot make request to \"https://api.github.com/x\". Error is \"401 Unauthorized\"" want: "error"}
    ]
    for c in $fetch_error_cases {
        $count += 1
        let got = classify-fetch-error $c.text
        if $got != $c.want {
            print $"(ansi red_bold)❌ classify-fetch-error: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    # catch-http-error (claude-skills-212): the shared debug/msg fallback
    # every check-* function's catch block delegates to. This is what makes
    # "classify hex-pm and crates-io errors on the same axes as
    # github-releases" true — they all call this same wrapper.
    let catch_cases = [
        {label: "debug field preferred over msg" err: {debug: "Requested file not found (404): \"x\""} want: "no-releases"}
        {label: "falls back to msg when debug absent" err: {msg: "Access forbidden (403) to \"x\""} want: "rate-limited"}
        {label: "empty record falls through to error" err: {} want: "error"}
    ]
    for c in $catch_cases {
        $count += 1
        let got = catch-http-error $c.err
        if $got != $c.want {
            print $"(ansi red_bold)❌ catch-http-error: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    # F1 (Gate 3, claude-skills-176): a pipe or newline inside a notes value
    # is fatal to a markdown table cell.
    let notes_cases = [
        {label: "plain text passes through unchanged" notes: "no external upstream" max_len: 80 want: "no external upstream"}
        {label: "pipe is escaped, not left to break the column" notes: "a | b" max_len: 80 want: "a \\| b"}
        {label: "embedded newline collapses to a space" notes: "line one\nline two" max_len: 80 want: "line one line two"}
        {label: "over-length text truncates with an ellipsis" notes: "0123456789" max_len: 5 want: "01234…"}
        {label: "exactly max_len does not truncate" notes: "01234" max_len: 5 want: "01234"}
        {label: "leading/trailing whitespace is trimmed" notes: "  padded  " max_len: 80 want: "padded"}
    ]
    for c in $notes_cases {
        $count += 1
        let got = sanitize-notes-cell $c.notes $c.max_len
        if $got != $c.want {
            print $"(ansi red_bold)❌ sanitize-notes-cell: ($c.label): want '($c.want)', got '($got)'(ansi reset)"
            $failed = true
        }
    }

    # parse-npm-latest / parse-docker-hub-latest / parse-endoflife-latest
    # (claude-skills-210 Gate 3): fixtures shaped from CAPTURED real
    # responses (registry.npmjs.org/express, hub.docker.com library/node
    # tags, endoflife.date/api/nodejs.json — captured 2026-08-04), not
    # invented shapes. This is the test that would have caught the original
    # quoted-path bug in parse-npm-latest: it exercises the actual parse
    # against real response shape, not just "did we call the right URL".
    let parse_cases = [
        {label: "npm: dist-tags.latest extracted from a real-shaped response" fn: "npm" input: {"dist-tags": {latest: "5.2.1" "latest-4": "4.22.2"}} want: "5.2.1"}
        {label: "npm: missing dist-tags falls through to unknown" fn: "npm" input: {name: "some-package"} want: "unknown"}
        {label: "docker-hub: first result's name extracted from a real-shaped response" fn: "docker-hub" input: {count: 8992 results: [{name: "lts-trixie-slim" last_updated: "2026-08-01T00:00:00Z"}]} want: "lts-trixie-slim"}
        {label: "docker-hub: empty results falls through to unknown" fn: "docker-hub" input: {count: 0 results: []} want: "unknown"}
        {label: "endoflife-date: newest cycle's latest extracted from a real-shaped response" fn: "endoflife-date" input: [{cycle: "26" latest: "26.6.0" eol: "2029-04-30"} {cycle: "25" latest: "25.9.0" eol: "2026-06-01"}] want: "26.6.0"}
        {label: "endoflife-date: empty cycles list falls through to unknown" fn: "endoflife-date" input: [] want: "unknown"}
        # claude-skills-225: fixture shaped from the real per-tag response
        # captured live against hub.docker.com/v2/repositories/library/node/
        # tags/24-alpine/ (2026-08-04).
        {label: "docker-hub-tag-digest: digest extracted from a real per-tag response" fn: "docker-hub-tag-digest" input: {name: "24-alpine" last_updated: "2026-08-03T23:38:54.128466Z" digest: "sha256:d32cdf619f63fe0471182d08996dd516c6275bb5fd31ae06e55a570bd9e1ad43"} want: "sha256:d32cdf619f63fe0471182d08996dd516c6275bb5fd31ae06e55a570bd9e1ad43"}
        {label: "docker-hub-tag-digest: missing digest field falls through to unknown" fn: "docker-hub-tag-digest" input: {name: "24-alpine"} want: "unknown"}
    ]
    for c in $parse_cases {
        $count += 1
        let got = match $c.fn {
            "npm" => (parse-npm-latest $c.input)
            "docker-hub" => (parse-docker-hub-latest $c.input)
            "endoflife-date" => (parse-endoflife-latest $c.input)
            "docker-hub-tag-digest" => (parse-docker-hub-tag-digest $c.input)
        }
        if $got != $c.want {
            print $"(ansi red_bold)❌ ($c.fn) parse: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    # claude-skills-226: parse-endoflife-cycle-eol / parse-endoflife-status
    # fixtures shaped from CAPTURED real responses (endoflife.date/api/
    # centos.json's cycle "8" — a fully-EOL product, matching the exact bug
    # report: "8 (2111)" reported with no EOL sentinel — and
    # endoflife.date/api/nodejs.json's cycle "26" — not EOL — both captured
    # 2026-08-04), not invented shapes.
    let eol_cycle_cases = [
        {label: "centos cycle 8: past ISO eol date classifies as EOL" cycle: {cycle: "8" eol: "2021-12-31" latest: "8 (2111)"} want: true}
        {label: "nodejs cycle 26: future ISO eol date classifies as not EOL" cycle: {cycle: "26" eol: "2029-04-30" latest: "26.6.0"} want: false}
        {label: "boolean eol=false classifies as not EOL" cycle: {cycle: "x" eol: false latest: "1.0.0"} want: false}
        {label: "boolean eol=true classifies as EOL" cycle: {cycle: "x" eol: true latest: "1.0.0"} want: true}
        {label: "unparseable eol string classifies as unknown, not a crash" cycle: {cycle: "x" eol: "not-a-date" latest: "1.0.0"} want: "unknown"}
    ]
    for c in $eol_cycle_cases {
        $count += 1
        let got = parse-endoflife-cycle-eol $c.cycle
        if $got != $c.want {
            print $"(ansi red_bold)❌ parse-endoflife-cycle-eol: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    let eol_status_cases = [
        {label: "centos: fully-EOL product surfaces eol=true alongside latest (the exact claude-skills-226 report)" cycles: [{cycle: "8" eol: "2021-12-31" latest: "8 (2111)"} {cycle: "7" eol: "2024-06-30" latest: "7 (2009)"}] want: {latest: "8 (2111)" eol: true cycle: "8"}}
        {label: "nodejs: supported product surfaces eol=false" cycles: [{cycle: "26" eol: "2029-04-30" latest: "26.6.0"}] want: {latest: "26.6.0" eol: false cycle: "26"}}
        {label: "empty cycles list is unknown across all three fields" cycles: [] want: {latest: "unknown" eol: "unknown" cycle: "unknown"}}
    ]
    for c in $eol_status_cases {
        $count += 1
        let got = parse-endoflife-status $c.cycles
        if $got != $c.want {
            print $"(ansi red_bold)❌ parse-endoflife-status: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    # fetch-latest dispatch (claude-skills-210): the empty-identity-field
    # path never touches the network, so it's testable here directly. Also
    # covers the pre-existing methods' empty-field path, previously
    # untested.
    let dispatch_cases = [
        {label: "github-releases with empty github_repo returns error" source: {check_method: "github-releases"} want: "error"}
        {label: "hex-pm with empty hex_package returns error" source: {check_method: "hex-pm"} want: "error"}
        {label: "crates-io with empty crate_name returns error" source: {check_method: "crates-io"} want: "error"}
        {label: "npm with empty npm_package returns error" source: {check_method: "npm"} want: "error"}
        {label: "docker-hub with empty docker_image returns error" source: {check_method: "docker-hub"} want: "error"}
        {label: "docker-hub with docker_tag set but docker_image empty still returns error before touching the network" source: {check_method: "docker-hub" docker_image: "" docker_tag: "16-buster-slim"} want: "error"}
        {label: "endoflife-date with empty eol_product returns error" source: {check_method: "endoflife-date"} want: "error"}
        {label: "manual never calls the network" source: {check_method: "manual"} want: "manual"}
        {label: "none is always internal" source: {check_method: "none"} want: "internal"}
        {label: "unrecognized check_method reports unknown-method, not a crash" source: {check_method: "bogus"} want: "unknown-method"}
    ]
    for c in $dispatch_cases {
        $count += 1
        let got = fetch-latest $c.source
        if $got != $c.want {
            print $"(ansi red_bold)❌ fetch-latest dispatch: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    {failed: $failed, count: $count}
}

def main [--self-test] {
    if $self_test {
        let result = run-self-test
        if $result.failed {
            exit 1
        }
        print $"(ansi green_bold)✅ sources-lib self-test passed \(($result.count) cases\)(ansi reset)"
        exit 0
    }
    print "sources-lib.nu is a shared module — import it with `use sources-lib.nu *`, or run with --self-test."
}
