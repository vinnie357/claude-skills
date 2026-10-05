#!/usr/bin/env nu

# Validate all source URLs in sources.toml files are accessible
# Uses HTTP HEAD requests (falling back to GET on a 405) and reports a
# classified status per URL.
#
# Usage: nu sources-validate-urls.nu [--plugin <name>] [--format line|json|table]
#        nu sources-validate-urls.nu --self-test
#
# Private upstream repos: a source entry with `private = true` in a plugin's
# skills/sources.toml makes every URL at or under that entry's repo report
# status `private` (an expected 404) instead of `dead`. The repo base is
# `https://github.com/<github_repo>` when the entry has a github_repo, else
# the entry's `url`. No env var or credential is involved.
#
# Output columns (all formats): plugin | skill | source | url | status | notes
#   --format line   (default) one grep-able line per row: "[status] plugin/
#                    skill source: url — notes". Fixes claude-skills-241 —
#                    nu's table auto-formatter truncates url/status/notes to
#                    "..." in non-interactive runs, and COLUMNS has no
#                    effect on it.
#   --format json    machine-consumable; progress/header/summary print to
#                    stderr so stdout carries ONLY the JSON array — pipe
#                    straight to jq (claude-skills-241 Gate 3, F1: an
#                    earlier revision left progress lines on stdout ahead
#                    of the JSON, which `jq` then failed to parse).
#   --format table   the original nu-table rendering, for interactive use.
#
# claude-skills-220: the summary line used to bucket every non-2xx/3xx result
# into one undifferentiated "error" count. Two independent agents both read
# that bucket as "pre-existing crates.io rate limiting" in one session — a
# wrong inference the tool made easy, because a genuine 404 (a dead link,
# actionable) and a generic network failure (transient, not actionable) both
# rendered identically. Root cause: nushell's http client sets $err.msg to a
# generic "Network failure" for EVERY caught error, including 404s — the
# specific status text only survives in $err.debug. This mirrors the bug
# claude-skills-176/212 fixed in sources-lib.nu's classify-fetch-error /
# catch-http-error, applied there to the check/report/stale path but never to
# this URL validator. This revision imports that same classification (see
# the `use sources-lib.nu [...]` below) instead of re-deriving it, and adds
# three validator-specific concerns sources-lib.nu has no reason to carry: a
# HEAD-to-GET fallback (some hosts, e.g. m3.material.io, reject HEAD with 405
# but serve GET fine), a private-repo relabel driven by the `private = true`
# flag in sources.toml (an unauthenticated check against a private GitHub
# repo 404s regardless of whether the content exists), and a crates.io API
# cross-check.
#
# claude-skills-220 Gate 3 (F1): an earlier revision of this file classified
# every crates.io/crates/<name> 404 as "dead". That was WRONG, not just
# imprecise — verified live (2026-08-04) that api.crates.io/api/v1/crates/
# serde returns 200 with real, current data (`{"name":"serde",
# "max_version":"1.0.229"}`) via the identical User-Agent, from the identical
# egress, at the same time the website path 404s. curl reproduces the same
# split: a bare/empty UA gets a 403 whose body names crates.io's own
# data-access policy explicitly ("in violation of our API data access
# policy"), a browser UA gets an empty-body 404 from heroku-router, and
# WebFetch gets the real SPA shell. That is bot detection reacting to
# request fingerprints the website tier applies to ALL non-browser clients —
# not evidence the crate page is gone. A validator that reports "dead" here
# is reporting its own inability to pass a bot check as if it were upstream
# link rot, which is exactly the wrong inference this file exists to
# prevent. check-url below cross-checks any crates.io/crates/<name> 404
# against the API before finalizing "dead"; a crates.io URL with no crate
# name to check (crates.io/policies has no API-shaped equivalent — verified
# crates.io/data-access also 404s the same way) relabels to "blocked"
# instead, since the host is proven unreliable to automated clients but the
# validator has no way to confirm content status either way.
use sources-lib.nu [classify-fetch-error, USER_AGENT]

# Pure: GitHub base URLs of the sources flagged `private = true`. An
# unauthenticated HTTP check against a private GitHub repo 404s regardless of
# whether the content exists (GitHub returns 404, not 403, to avoid confirming
# the repo's existence), so those URLs are expected-404, not link rot.
# Only a boolean `true` counts. The base is `https://github.com/<github_repo>`
# when github_repo is a non-empty string, else `url` minus trailing slashes;
# a flagged record with neither is skipped.
export def private-repo-bases [sources: list]: nothing -> list<string> {
    $sources
    | where {|s| (($s | get -o private) == true)}
    | each {|s|
        let repo = ($s | get -o github_repo)
        let url = ($s | get -o url)
        if (($repo | describe) == "string") and not ($repo | is-empty) {
            $"https://github.com/($repo)"
        } else if (($url | describe) == "string") and not ($url | is-empty) {
            $url | str trim --right --char "/"
        } else {
            null
        }
    }
    | compact
}

# Pure: does `url` equal one of `bases` or sit under one (`<base>/...`)?
export def is-known-private-repo-url [url: string, bases: list<string>]: nothing -> bool {
    $bases | any {|b| ($url == $b) or ($url | str starts-with $"($b)/")}
}

# Pure: does this caught error text indicate the server rejected HEAD with
# 405 Method Not Allowed? Verified live against nu 0.113.1 hitting
# m3.material.io (which HEADs 405 but GETs 200): the shape is
# `Cannot make request to "<url>". Error is "405 Method Not Allowed"` — no
# parens around the digits, matching the same no-parens shape sources-lib.nu
# documents for 401/429/500. Matching the literal phrase (not bare "405")
# avoids the byte-offset-span collision classify-fetch-error's own docs warn
# about — a Span[...] never contains this phrase.
export def needs-get-fallback [err_text: string]: nothing -> bool {
    $err_text | str contains "405 Method Not Allowed"
}

# Pure: classify a caught HEAD/GET error into a validator-specific status.
# Delegates the 404/403/429/rate-limit-text pattern matching to
# sources-lib.nu's classify-fetch-error (proven against real nu 0.113.1
# error shapes there) and relabels its three outcomes for this URL-existence
# context, where "no-releases" (a check-latest-version sentinel) doesn't fit:
#   no-releases  -> dead          (a genuine 404 — actionable link rot)
#   rate-limited -> rate-limited  (403/429/"rate limit" text — retry later)
#   error        -> error         (DNS/connection/timeout/other — not a
#                                   content judgment either way)
# A "dead" result against a URL at or under one of `bases` (the repos flagged
# `private = true` in sources.toml) is further relabeled "private" —
# GitHub's documented 404-instead-of-403 behavior for private repos means
# this specific 404 is expected, not link rot.
#
# claude-skills-220 Gate 3 (F1): this function alone is NOT the final word on
# "dead" for crates.io — see the crates.io API cross-check in check-url
# below, which can further relabel a "dead" result here to "pass" (confirmed
# live via the API) or "blocked" (host-known-unreliable from automation,
# unconfirmed either way). classify-url-error stays pure (no network) and
# reports what the HTTP layer said; the network-dependent override lives in
# check-url, the only place in this file allowed to make a second call.
export def classify-url-error [err_text: string, url: string, bases: list<string>]: nothing -> string {
    let base = classify-fetch-error $err_text
    let mapped = match $base {
        "no-releases" => "dead"
        "rate-limited" => "rate-limited"
        _ => "error"
    }
    if $mapped == "dead" and (is-known-private-repo-url $url $bases) {
        "private"
    } else {
        $mapped
    }
}

# Pure: extract the crate name from a bare crates.io crate-page URL
# (`https://crates.io/crates/<name>`), or null if `url` isn't that shape.
# Scoped deliberately narrow (no trailing slash/subpath) — every current
# sources.toml entry of this kind uses the bare form; a URL this doesn't
# match falls through to the is-crates-io-host "blocked" relabel instead of
# a false-positive crate-name extraction.
export def crates-io-crate-name [url: string]: nothing -> any {
    let prefix = "https://crates.io/crates/"
    if ($url | str starts-with $prefix) {
        let rest = ($url | str substring ($prefix | str length)..)
        if ($rest | is-empty) or ($rest | str contains "/") {
            null
        } else {
            $rest
        }
    } else {
        null
    }
}

# Pure: is this a crates.io URL at all (crate page, /policies, or anything
# else on the host)? Used to relabel a "dead" crates.io result that has no
# crate name to cross-check (e.g. crates.io/policies) as "blocked" rather
# than "dead" — see the F1 finding below.
export def is-crates-io-url [url: string]: nothing -> bool {
    ($url | str starts-with "https://crates.io/") or ($url == "https://crates.io")
}

# Pure: format one result row as a single grep/scan-able line (claude-skills-
# 241). nu's auto-rendered table truncates url/status/notes to "..." when
# stdout isn't a tty — confirmed live during PR #220 (COLUMNS had no
# effect), and both the PR author and its Gate 3 reviewer independently hit
# it and had to work around it with --plugin scoping + ANSI-stripped
# post-processing. Status leads in brackets so a specific classification is
# `grep`-able directly off raw output — `grep '^\[dead\]'` finds every dead
# link with no post-processing, satisfying the bee's acceptance criterion.
export def format-row-line [row: record]: nothing -> string {
    $"[($row.status)] ($row.plugin)/($row.skill) ($row.source): ($row.url) — ($row.notes)"
}

# Resolve the repo root relative to this script's location
def repo-root [] {
    $env.FILE_PWD | path join ".." ".." ".." ".." ".." ".." | path expand
}

# Load marketplace.json
def load-marketplace [repo: string] {
    let mp_path = $"($repo)/.claude-plugin/marketplace.json"
    if not ($mp_path | path exists) {
        error make { msg: $"marketplace.json not found at ($mp_path)" }
    }
    open $mp_path
}

# Resolve plugin source path to absolute directory
def resolve-plugin-path [repo: string, source: any] {
    if ($source | describe) == "string" {
        let rel = $source | str replace -r '^\./' ''
        $"($repo)/($rel)"
    } else {
        null
    }
}

# Pure: classify a FAILED crates.io API cross-check's caught error text into
# a final status (claude-skills-242). The catch block used to discard WHY
# the API call failed, so a genuine API 404 (affirmative evidence the crate
# does not exist) and a transient API failure (DNS, timeout, connection
# reset) both read identically as "blocked — cannot confirm either way".
# The API is proven reliable from this egress (see the F1 note above this
# function's caller) — an API 404 is real signal, not noise, and throwing it
# away under-claims. Reuses classify-fetch-error rather than re-deriving the
# (404) pattern match — same reasoning as classify-url-error above.
#
# TRADEOFF ON THE RECORD (claude-skills-242 Gate 3, F2): this call has no
# retry. A genuinely LIVE crate whose single API request happens to fail
# with a transient 404 (rare, but the website tier's own 404-to-automation
# behavior shows crates.io's edge is not always well-behaved) would be
# misread as "confirmed dead" here, because a 404 IS treated as affirmative
# with no second attempt to rule out a fluke. This is deliberate, not an
# oversight: the website check that got us here already 404d, and the
# alternative — treating every API 404 as merely transient — would silently
# revert to the pre-242 "blocked" under-claim for the one case (a truly
# dead crate) this function exists to catch. A future retry-before-dead
# would remove this tradeoff at the cost of a second network call; not done
# here per restraint (no report has hit this edge in practice yet).
export def classify-crates-io-api-failure [err_text: string, api_url: string]: nothing -> record<status: string, notes: string> {
    if (classify-fetch-error $err_text) == "no-releases" {
        { status: "dead", notes: $"crates.io website 404; API cross-check at ($api_url) ALSO 404d — API-confirmed: this crate does not exist" }
    } else {
        { status: "blocked", notes: $"crates.io website 404; API cross-check at ($api_url) also failed \(not a 404 — transient\) — cannot confirm either way" }
    }
}

# Cross-check a "dead" crates.io result before it's final (claude-skills-220
# Gate 3, F1). Returns an overriding {status, notes} record, or null when no
# override applies (leaves the caller's original classification alone).
#   - crate-name URL, API confirms it live -> pass (bypassed the bot-gated
#     website check)
#   - crate-name URL, API ALSO 404s -> dead (claude-skills-242: an affirmed
#     API 404 is real evidence the crate doesn't exist, not noise)
#   - crate-name URL, API fails for any OTHER reason -> blocked (still can't
#     confirm — crates.io's website tier is proven unreliable to automation,
#     so "dead" would overstate what a non-404 failure tells us)
#   - any other crates.io URL (e.g. /policies, no crate name to check) ->
#     blocked, same reasoning, no cross-check possible
def crates-io-dead-override [url: string, headers: list]: nothing -> any {
    let name = crates-io-crate-name $url
    if $name != null {
        let api_url = $"https://crates.io/api/v1/crates/($name)"
        try {
            let response = (http get $api_url -H $headers)
            let live_name = ($response.crate?.name? | default "")
            if $live_name == $name {
                {
                    status: "pass"
                    notes: $"OK \(crates.io website 404s automated clients; confirmed live via ($api_url)\)"
                }
            } else {
                { status: "blocked", notes: $"crates.io website 404; API cross-check returned an unexpected body from ($api_url)" }
            }
        } catch { |err|
            let api_err_text = ($err.debug? | default ($err.msg? | default ""))
            classify-crates-io-api-failure $api_err_text $api_url
        }
    } else if (is-crates-io-url $url) {
        { status: "blocked", notes: "crates.io website 404 with no crate name to cross-check via the API (e.g. a policy/docs page) — host is known-unreliable to automated clients, cannot confirm content status" }
    } else {
        null
    }
}

# Perform an HTTP check on a URL (HEAD first, falling back to GET on a 405)
# and return a classified result record. Always sends the shared
# claude-skills User-Agent (sources-lib.nu's $USER_AGENT) — nushell's
# unadorned default is the literal string "nushell", which some hosts (e.g.
# crates.io's API) treat as insufficiently informative and reject outright.
def check-url [plugin: string, skill: string, source_name: string, url: string, bases: list<string>] {
    if ($url | is-empty) {
        return null
    }

    let headers = [User-Agent $USER_AGENT]

    let head_result = try {
        http head $url -H $headers
        { ok: true }
    } catch { |err|
        { ok: false, text: ($err.debug? | default ($err.msg? | default "")) }
    }

    let result = if $head_result.ok {
        { status: "pass", notes: "OK" }
    } else if (needs-get-fallback $head_result.text) {
        # Some hosts reject HEAD (405) but serve GET fine — retry once
        # before concluding anything about reachability.
        try {
            http get $url -H $headers
            { status: "pass", notes: "OK (GET fallback after HEAD 405)" }
        } catch { |err|
            let get_text = ($err.debug? | default ($err.msg? | default ""))
            {
                status: (classify-url-error $get_text $url $bases)
                notes: ($get_text | str substring 0..80)
            }
        }
    } else {
        {
            status: (classify-url-error $head_result.text $url $bases)
            notes: ($head_result.text | str substring 0..80)
        }
    }

    let final_result = if $result.status == "dead" {
        let override = (crates-io-dead-override $url $headers)
        if $override != null { $override } else { $result }
    } else {
        $result
    }

    {
        plugin: $plugin
        skill:  $skill
        source: $source_name
        url:    $url
        status: $final_result.status
        notes:  $final_result.notes
    }
}

# Process a single sources.toml file and return URL check results
def process-sources-toml [toml_path: string, plugin_name: string] {
    let data = try {
        open $toml_path
    } catch {
        print -e $"(ansi yellow)Warning: could not parse ($toml_path)(ansi reset)"
        return []
    }

    let sources = $data.sources? | default []
    let bases = (private-repo-bases $sources)
    mut rows = []

    for src in $sources {
        let skill       = $src.skills? | default [] | str join ","
        let name        = $src.name?          | default ""
        let url         = $src.url?           | default ""
        let releases_url = $src.releases_url? | default ""

        if not ($url | is-empty) {
            print -e $"  CHECK ($url)"
            let row = check-url $plugin_name $skill $name $url $bases
            if $row != null {
                $rows = ($rows | append $row)
            }
        }

        if not ($releases_url | is-empty) {
            print -e $"  CHECK ($releases_url)"
            let row = check-url $plugin_name $skill $"($name) [releases]" $releases_url $bases
            if $row != null {
                $rows = ($rows | append $row)
            }
        }
    }

    $rows
}

def run-checks [plugin_filter: string, format: string] {
    let repo = repo-root

    # claude-skills-241 Gate 3 (F1): every print in this function that isn't
    # the actual result payload uses `-e` (stderr) so `--format json | jq`
    # sees ONLY the JSON on stdout. Verified live: before this fix, these
    # headers/progress lines printed to stdout ahead of the JSON array,
    # which is exactly what made `jq` fail with "Invalid numeric literal at
    # line 1, column 2" — the payload was there, just not alone on stdout.
    print -e $"(ansi cyan_bold)Source URL Validation(ansi reset)"
    print -e $"Repo root: ($repo)"
    print -e ""

    let marketplace = load-marketplace $repo
    let plugins = $marketplace.plugins? | default []

    let filtered = if ($plugin_filter | is-empty) {
        $plugins
    } else {
        $plugins | where name == $plugin_filter
    }

    if ($filtered | is-empty) {
        if not ($plugin_filter | is-empty) {
            print -e $"(ansi red)No plugin found with name: ($plugin_filter)(ansi reset)"
            exit 1
        }
        print -e $"(ansi yellow)No plugins found in marketplace.(ansi reset)"
        exit 0
    }

    mut all_rows = []

    for pl in $filtered {
        let pl_name = $pl.name
        let pl_dir  = resolve-plugin-path $repo $pl.source

        if $pl_dir == null {
            continue
        }

        let toml_path = $"($pl_dir)/skills/sources.toml"
        if not ($toml_path | path exists) {
            continue
        }

        print -e $"(ansi green)Plugin: ($pl_name)(ansi reset)"
        let rows = process-sources-toml $toml_path $pl_name
        $all_rows = ($all_rows | append $rows)
    }

    print -e ""

    if ($all_rows | is-empty) {
        print -e $"(ansi yellow)No sources.toml files found with URL entries.(ansi reset)"
        exit 0
    }

    # Summary counts — one bucket per classification, so "N error" can no
    # longer silently absorb dead links, rate-limiting, and expected-private
    # 404s into one homogeneous number (claude-skills-220). "blocked" (F1,
    # Gate 3) is distinct from "dead": a dead crates.io result that survived
    # the API cross-check (or had no crate name to cross-check) — host known
    # to bot-gate automated clients, content status genuinely unconfirmed
    # either way, so it must not read as actionable link rot the way "dead"
    # does.
    let total        = $all_rows | length
    let passing      = $all_rows | where status == "pass"         | length
    let dead         = $all_rows | where status == "dead"         | length
    let blocked      = $all_rows | where status == "blocked"      | length
    let rate_limited = $all_rows | where status == "rate-limited" | length
    let private      = $all_rows | where status == "private"      | length
    let errors       = $all_rows | where status == "error"        | length

    print -e $"(ansi cyan_bold)Summary:(ansi reset) ($total) URLs checked — (ansi green)($passing) pass(ansi reset) | (ansi red)($dead) dead(ansi reset) | (ansi magenta)($blocked) blocked \(unconfirmed\)(ansi reset) | (ansi yellow)($rate_limited) rate-limited(ansi reset) | (ansi cyan)($private) private \(expected\)(ansi reset) | (ansi red)($errors) error(ansi reset)"
    print -e ""

    # claude-skills-241: three output shapes. "line" is the default — one
    # scannable, ungrepped-by-nu's-table-renderer line per row, immune to
    # the non-tty truncation this bee reports (verified below: nu's table
    # formatter is never invoked on this path, so there is no width to
    # truncate). "json" is for scripts/jq. "table" keeps the original
    # nu-table rendering for anyone running this interactively and wanting
    # the auto-fit columns.
    match $format {
        "json" => { print ($all_rows | select plugin skill source url status notes | to json) }
        "table" => { $all_rows | select plugin skill source url status notes }
        _ => {
            for row in $all_rows {
                print (format-row-line $row)
            }
        }
    }
}

# ---- self-test (pure functions only; no network) ---------------------------

export def run-self-test []: nothing -> record<failed: bool, count: int> {
    mut failed = false
    mut count = 0

    # Private-repo detection is DATA: a source flagged `private = true` in a
    # sources.toml supplies the bases. Fixtures use placeholder repos only.
    let private_bases = (private-repo-bases [
        {name: "demo", url: "https://example.com", github_repo: "example-org/private-repo", private: true}
    ])

    # Fixtures below are CAPTURED live error text from real nu 0.113.1 HTTP
    # calls made while triaging claude-skills-220 (2026-08-04) — not shapes
    # invented from the implementation — except the private-repo cases, which
    # reuse the captured 404 shape with a placeholder URL.
    let classify_cases = [
        # captured: `http head "https://crates.io/crates/serde"` (nu 0.113.1)
        {
            label: "real 404 on a non-private repo is dead"
            text: "Requested file not found (404): \"https://crates.io/crates/serde\""
            url: "https://crates.io/crates/serde"
            bases: $private_bases
            want: "dead"
        }
        # 404 shape captured from `http head` with the shared UA header
        # (nu 0.113.1); GitHub's documented private-repo behavior (404, not
        # 403, to avoid confirming existence to an unauthenticated caller)
        # applies identically on this website path as on the API path.
        {
            label: "404 on a flagged-private repo's bare URL is private, not dead"
            text: "Requested file not found (404): \"https://github.com/example-org/private-repo\""
            url: "https://github.com/example-org/private-repo"
            bases: $private_bases
            want: "private"
        }
        {
            label: "404 on a path under a flagged-private repo is also private"
            text: "Requested file not found (404): \"https://github.com/example-org/private-repo/releases\""
            url: "https://github.com/example-org/private-repo/releases"
            bases: $private_bases
            want: "private"
        }
        {
            label: "a different repo under the same owner is NOT private by substring collision"
            text: "Requested file not found (404): \"https://github.com/example-org/private-repo-extra\""
            url: "https://github.com/example-org/private-repo-extra"
            bases: $private_bases
            want: "dead"
        }
        {
            label: "with empty bases the same 404 is dead (a missing flag never relabels)"
            text: "Requested file not found (404): \"https://github.com/example-org/private-repo\""
            url: "https://github.com/example-org/private-repo"
            bases: []
            want: "dead"
        }
        {
            label: "a base built from a url-only flagged record relabels a 404 under it"
            text: "Requested file not found (404): \"https://git.example.com/org/private-repo/blob/main/README.md\""
            url: "https://git.example.com/org/private-repo/blob/main/README.md"
            bases: (private-repo-bases [{name: "demo", url: "https://git.example.com/org/private-repo", private: true}])
            want: "private"
        }
        {
            label: "403 rate-limit text classifies as rate-limited, not dead"
            text: "Client error (403): API rate limit exceeded"
            url: "https://crates.io/api/v1/crates/serde"
            bases: $private_bases
            want: "rate-limited"
        }
        # captured shape from sources-lib.nu's own self-test (same nu client)
        {
            label: "429 Too Many Requests (no parens) classifies as rate-limited"
            text: "Cannot make request to \"https://molecule.readthedocs.io\". Error is \"429 Too Many Requests\""
            url: "https://molecule.readthedocs.io"
            bases: $private_bases
            want: "rate-limited"
        }
        # captured: `http head` against the dead butunclebob.com host (2026-08-04)
        {
            label: "connection-refused I/O error falls through to error"
            text: "Io(IoError { kind: Std(ConnectionRefused, Sealed), span: Span[160087..160096], path: None, additional_context: None, location: None })"
            url: "https://www.butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd"
            bases: $private_bases
            want: "error"
        }
        {
            label: "empty error text falls through to error"
            text: ""
            url: "https://example.com"
            bases: $private_bases
            want: "error"
        }
    ]
    for c in $classify_cases {
        $count += 1
        let got = classify-url-error $c.text $c.url $c.bases
        if $got != $c.want {
            print $"(ansi red_bold)❌ classify-url-error: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    let private_url_cases = [
        {label: "bare flagged-private repo URL matches" url: "https://github.com/example-org/private-repo" bases: $private_bases want: true}
        {label: "path under flagged-private repo matches" url: "https://github.com/example-org/private-repo/tree/main" bases: $private_bases want: true}
        {label: "a trailing-slash URL of the repo matches" url: "https://github.com/example-org/private-repo/" bases: $private_bases want: true}
        {label: "a different repo does not match by substring" url: "https://github.com/example-org/private-repo-extra" bases: $private_bases want: false}
        {label: "a different owner with the same repo name does not match" url: "https://github.com/someoneelse/private-repo" bases: $private_bases want: false}
        {label: "an unrelated URL does not match" url: "https://crates.io/crates/serde" bases: $private_bases want: false}
        {label: "empty bases never match" url: "https://github.com/example-org/private-repo" bases: [] want: false}
        {
            label: "any one of several bases matches"
            url: "https://github.com/example-org/private-repo-extra/releases"
            bases: ["https://github.com/example-org/private-repo" "https://github.com/example-org/private-repo-extra"]
            want: true
        }
    ]
    for c in $private_url_cases {
        $count += 1
        let got = is-known-private-repo-url $c.url $c.bases
        if $got != $c.want {
            print $"(ansi red_bold)❌ is-known-private-repo-url: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    # private-repo-bases: only a boolean `true` flag counts; base comes from
    # github_repo when non-empty, else the url minus trailing slashes.
    let bases_cases = [
        {
            label: "flagged record with github_repo yields the GitHub base"
            sources: [{name: "a", url: "https://example.com", github_repo: "example-org/private-repo", private: true}]
            want: ["https://github.com/example-org/private-repo"]
        }
        {
            label: "github_repo wins over url when both are present"
            sources: [{name: "a", url: "https://example.com/docs", github_repo: "example-org/private-repo", private: true}]
            want: ["https://github.com/example-org/private-repo"]
        }
        {
            label: "flagged record with url only (no github_repo) yields the url"
            sources: [{name: "a", url: "https://git.example.com/org/private-repo", private: true}]
            want: ["https://git.example.com/org/private-repo"]
        }
        {
            label: "an empty github_repo falls back to the url"
            sources: [{name: "a", url: "https://git.example.com/org/private-repo", github_repo: "", private: true}]
            want: ["https://git.example.com/org/private-repo"]
        }
        {
            label: "a trailing slash on the url is stripped"
            sources: [{name: "a", url: "https://git.example.com/org/private-repo/", private: true}]
            want: ["https://git.example.com/org/private-repo"]
        }
        {
            label: "private = false is ignored"
            sources: [{name: "a", url: "https://example.com", github_repo: "example-org/private-repo", private: false}]
            want: []
        }
        {
            label: "a missing private field is ignored"
            sources: [{name: "a", url: "https://example.com", github_repo: "example-org/private-repo"}]
            want: []
        }
        {
            label: "the string \"true\" is not a boolean flag and is ignored"
            sources: [{name: "a", url: "https://example.com", github_repo: "example-org/private-repo", private: "true"}]
            want: []
        }
        {
            label: "a flagged record with neither github_repo nor url is skipped"
            sources: [{name: "a", private: true}]
            want: []
        }
        {
            label: "an empty sources list yields no bases"
            sources: []
            want: []
        }
        {
            label: "output order follows input order and skips unflagged records"
            sources: [
                {name: "a", github_repo: "example-org/private-repo-extra", private: true}
                {name: "b", github_repo: "example-org/public-repo"}
                {name: "c", url: "https://git.example.com/org/private-repo/", private: true}
                {name: "d", github_repo: "example-org/private-repo", private: true}
            ]
            want: [
                "https://github.com/example-org/private-repo-extra"
                "https://git.example.com/org/private-repo"
                "https://github.com/example-org/private-repo"
            ]
        }
    ]
    for c in $bases_cases {
        $count += 1
        let got = private-repo-bases $c.sources
        if $got != $c.want {
            print $"(ansi red_bold)❌ private-repo-bases: ($c.label): want ($c.want | to nuon), got ($got | to nuon)(ansi reset)"
            $failed = true
        }
    }

    # Real-data guard: the runex plugin's sources.toml must carry the
    # `private = true` flag on its private source. Asserts the derived bases
    # without naming the repo: non-empty, every one a GitHub URL.
    $count += 1
    let runex_toml = ((repo-root) | path join "plugins" "tools" "runex" "skills" "sources.toml")
    let runex_bases = (try {
        private-repo-bases ((open $runex_toml).sources? | default [])
    } catch {|e|
        print $"(ansi red_bold)❌ runex sources.toml real-data guard: could not read ($runex_toml): ($e.msg)(ansi reset)"
        []
    })
    if ($runex_bases | is-empty) {
        print $"(ansi red_bold)❌ runex sources.toml real-data guard: no source flagged `private = true`, so no private bases derived(ansi reset)"
        $failed = true
    } else if not ($runex_bases | all {|b| $b | str starts-with "https://github.com/"}) {
        print $"(ansi red_bold)❌ runex sources.toml real-data guard: a derived base is not an https://github.com/ URL: ($runex_bases | to nuon)(ansi reset)"
        $failed = true
    }

    # claude-skills-220 Gate 3 (F1): pure URL-parsing helpers behind the
    # crates.io dead-override. crates-io-dead-override itself is NOT
    # self-tested here — it makes a live network call (the API cross-check),
    # so it's exercised by the live corpus run instead (see the PR report's
    # URL-by-URL table), matching sources-lib.nu's own convention of keeping
    # check-* network functions out of --self-test.
    let crate_name_cases = [
        {label: "bare crate URL extracts the crate name" url: "https://crates.io/crates/serde" want: "serde"}
        {label: "a hyphenated crate name extracts whole" url: "https://crates.io/crates/clap-verbosity-flag" want: "clap-verbosity-flag"}
        {label: "a trailing-slash URL does not match (scoped narrow on purpose)" url: "https://crates.io/crates/serde/" want: null}
        {label: "a versioned subpath does not match" url: "https://crates.io/crates/serde/1.0.229" want: null}
        {label: "the bare /crates/ URL with no name does not match" url: "https://crates.io/crates/" want: null}
        {label: "a non-crates.io URL does not match" url: "https://docs.rs/serde" want: null}
        {label: "the crates.io homepage does not match" url: "https://crates.io" want: null}
    ]
    for c in $crate_name_cases {
        $count += 1
        let got = crates-io-crate-name $c.url
        if $got != $c.want {
            print $"(ansi red_bold)❌ crates-io-crate-name: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    let crates_io_host_cases = [
        {label: "a crate page is a crates.io URL" url: "https://crates.io/crates/serde" want: true}
        {label: "the policies page is a crates.io URL" url: "https://crates.io/policies" want: true}
        {label: "the bare host (no path) is a crates.io URL" url: "https://crates.io" want: true}
        {label: "a lookalike host is NOT a crates.io URL" url: "https://crates.io.evil.example/crates/serde" want: false}
        {label: "an unrelated URL is NOT a crates.io URL" url: "https://docs.rs/serde" want: false}
    ]
    for c in $crates_io_host_cases {
        $count += 1
        let got = is-crates-io-url $c.url
        if $got != $c.want {
            print $"(ansi red_bold)❌ is-crates-io-url: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    # claude-skills-242: when the crates.io API cross-check ITSELF fails,
    # was the failure a real 404 (affirmative "this crate doesn't exist") or
    # something else (transient — DNS, timeout, connection reset)? Both
    # fixtures below are captured live text, not invented shapes.
    let api_failure_cases = [
        # captured: `http get
        # "https://crates.io/api/v1/crates/this-crate-definitely-does-not-exist-zz9plural"`
        # with the shared UA header (nu 0.113.1, 2026-08-04) — a name chosen
        # to be implausible as a real crate.
        {
            label: "a real API 404 for a nonexistent crate reports dead, API-confirmed"
            text: "Requested file not found (404): \"https://crates.io/api/v1/crates/this-crate-definitely-does-not-exist-zz9plural\""
            api_url: "https://crates.io/api/v1/crates/this-crate-definitely-does-not-exist-zz9plural"
            want_status: "dead"
        }
        # captured: `http head` against the dead butunclebob.com host
        # (2026-08-04) — reused as a generic non-404 failure shape;
        # classify-fetch-error's pattern matching is host-agnostic, so this
        # exercises the same "not a 404" branch a transient crates.io API
        # failure (DNS, timeout, connection reset) would take.
        {
            label: "a non-404 API failure (transient) still reports blocked, not dead"
            text: "Io(IoError { kind: Std(ConnectionRefused, Sealed), span: Span[160087..160096], path: None, additional_context: None, location: None })"
            api_url: "https://crates.io/api/v1/crates/serde"
            want_status: "blocked"
        }
        # claude-skills-241 Gate 3: constructed (not a live capture — a real
        # timeout with a controlled URL isn't reliably reproducible on
        # demand), modeled on the "Cannot make request to ... Error is ..."
        # shape sources-lib.nu's own self-test already verified live for
        # 401/429/500. Closes a mutation the delegation-only fixtures above
        # couldn't: sources-lib.nu:60-62 documents that a bare "404" can
        # appear inside a URL's crate NAME (a crate literally named "x404")
        # with no parens around it — a naive `str contains "404"` classifier
        # would misread this transient timeout as an affirmed 404 and
        # wrongly report "dead" for a crate that might well exist. Real
        # delegation to classify-fetch-error requires the PARENTHESISED
        # `(404)` form, so a bare "404" substring inside the api_url/text
        # must NOT trip the dead branch.
        {
            label: "a transient timeout whose URL happens to contain a bare '404' (no parens) stays blocked, not dead"
            text: "Cannot make request to \"https://crates.io/api/v1/crates/x404\". Error is \"timeout\""
            api_url: "https://crates.io/api/v1/crates/x404"
            want_status: "blocked"
        }
    ]
    for c in $api_failure_cases {
        $count += 1
        let got = classify-crates-io-api-failure $c.text $c.api_url
        if $got.status != $c.want_status {
            print $"(ansi red_bold)❌ classify-crates-io-api-failure: ($c.label): want ($c.want_status), got ($got.status)(ansi reset)"
            $failed = true
        }
    }

    # claude-skills-241: format-row-line is the line-per-row bypass around
    # nu's table truncation. Fixtures use real row shapes check-url produces
    # (all fields present, including a multi-skill comma-joined list and a
    # notes value carrying an em dash of its own — the exact byte the line
    # format's own separator uses, proving the format doesn't get confused
    # by a notes value that happens to look like a delimiter).
    let row_line_cases = [
        {
            label: "a passing row formats with all fields, status bracketed first"
            row: {plugin: "rust" skill: "rust" source: "serde" url: "https://crates.io/crates/serde" status: "pass" notes: "OK (crates.io website 404s automated clients; confirmed live via https://crates.io/api/v1/crates/serde)"}
            want: "[pass] rust/rust serde: https://crates.io/crates/serde — OK (crates.io website 404s automated clients; confirmed live via https://crates.io/api/v1/crates/serde)"
        }
        {
            label: "a comma-joined multi-skill list passes through unchanged"
            row: {plugin: "claude-code" skill: "claude-skills,claude-skills-benchmark" source: "improving-skill-creator-blog" url: "https://claude.com/blog/improving-skill-creator-test-measure-and-refine-agent-skills" status: "pass" notes: "OK"}
            want: "[pass] claude-code/claude-skills,claude-skills-benchmark improving-skill-creator-blog: https://claude.com/blog/improving-skill-creator-test-measure-and-refine-agent-skills — OK"
        }
        {
            label: "a notes value containing its own em dash does not break the line"
            row: {plugin: "core" skill: "tdd" source: "three-laws-of-tdd" url: "http://web.archive.org/web/20260719201717/http://www.butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd" status: "dead" notes: "host unreachable — connection refused, not a 404"}
            want: "[dead] core/tdd three-laws-of-tdd: http://web.archive.org/web/20260719201717/http://www.butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd — host unreachable — connection refused, not a 404"
        }
    ]
    for c in $row_line_cases {
        $count += 1
        let got = format-row-line $c.row
        if $got != $c.want {
            print $"(ansi red_bold)❌ format-row-line: ($c.label): want '($c.want)', got '($got)'(ansi reset)"
            $failed = true
        }
    }

    # captured: `http head "https://m3.material.io/"` (nu 0.113.1, 2026-08-04)
    let fallback_cases = [
        {label: "405 Method Not Allowed triggers a GET fallback" text: "Cannot make request to \"https://m3.material.io/\". Error is \"405 Method Not Allowed\"" want: true}
        {label: "a genuine 404 does not trigger a GET fallback" text: "Requested file not found (404): \"https://crates.io/crates/serde\"" want: false}
        {label: "a bare digit span spelling 405 does not collide (same guard sources-lib documents for 403/429)" text: "NetworkFailure { msg: \"connection reset\", span: Span[140533..140599] }" want: false}
    ]
    for c in $fallback_cases {
        $count += 1
        let got = needs-get-fallback $c.text
        if $got != $c.want {
            print $"(ansi red_bold)❌ needs-get-fallback: ($c.label): want ($c.want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    {failed: $failed, count: $count}
}

# Check every source URL in each plugin's skills/sources.toml.
#
# A source entry with `private = true` makes URLs at or under it report status
# `private` (an expected 404) instead of `dead`. Set the flag in that
# plugin's sources.toml.
def main [--plugin: string = "", --format: string = "line", --self-test] {
    if $self_test {
        let result = run-self-test
        if $result.failed {
            exit 1
        }
        print $"(ansi green_bold)✅ sources-validate-urls self-test passed \(($result.count) cases\)(ansi reset)"
        exit 0
    }
    if $format not-in ["line" "json" "table"] {
        print $"(ansi red)Unknown --format '($format)' — expected line, json, or table(ansi reset)"
        exit 1
    }
    run-checks $plugin $format
}
