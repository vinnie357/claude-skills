# Version Check Methods

Reference for each `check_method` value in `sources.toml`. Includes API endpoints, authentication, response parsing, rate limits, and Nushell examples.

---

## github-releases

Queries the GitHub Releases API for the latest published release.

| Property | Value |
|---|---|
| Endpoint | `https://api.github.com/repos/{owner}/{repo}/releases/latest` |
| Auth | Optional `Authorization: Bearer $GITHUB_TOKEN` |
| Rate limit (unauth) | 60 requests/hour per IP |
| Rate limit (auth) | 5,000 requests/hour |
| Required field | `github_repo = "owner/repo"` |

**Response parsing**: Extract `.tag_name`. Strip leading `v` prefix if present.

```nushell
# Query latest release for a GitHub repo
def get-github-latest [repo: string]: nothing -> string {
    let url = $"https://api.github.com/repos/($repo)/releases/latest"
    let headers = if ("GITHUB_TOKEN" in $env) {
        {Authorization: $"Bearer ($env.GITHUB_TOKEN)", "X-GitHub-Api-Version": "2022-11-28"}
    } else {
        {"X-GitHub-Api-Version": "2022-11-28"}
    }
    let response = http get --headers $headers $url
    $response.tag_name | str replace --regex '^v' ''
}

# Example
let latest = get-github-latest "apple/container"
# Returns: "0.11.0"
```

**Notes**:
- Use `GITHUB_TOKEN` to avoid rate limiting during batch checks
- The `releases/latest` endpoint skips pre-releases; use `releases` list if pre-releases must be tracked
- Some repos use `tag_name` values like `release-0.11.0` — strip non-numeric prefixes as needed

---

## hex-pm

Queries the Hex.pm package registry for Elixir/Erlang packages.

| Property | Value |
|---|---|
| Endpoint | `https://hex.pm/api/packages/{package}` |
| Auth | None required |
| Rate limit | 100 requests/minute |
| Required field | `hex_package = "package_name"` |

**Response parsing**: Extract `.latest_stable_version` or the first entry in `.releases[].version` sorted by insertion order.

```nushell
# Query latest stable version for a Hex.pm package
def get-hex-latest [package: string]: nothing -> string {
    let url = $"https://hex.pm/api/packages/($package)"
    let response = http get $url
    $response.latest_stable_version
}

# Example
let latest = get-hex-latest "tidewave"
# Returns: "0.5.6"
```

**Notes**:
- `latest_stable_version` excludes pre-release versions (rc, alpha, beta)
- To include pre-releases, inspect `$response.releases | first | get version`
- No authentication needed for public packages
- Response also contains `$response.meta.description` and `$response.meta.links` for documentation URLs

---

## crates-io

Queries the crates.io registry for Rust packages.

| Property | Value |
|---|---|
| Endpoint | `https://crates.io/api/v1/crates/{crate}` |
| Auth | None required (but `User-Agent` is mandatory) |
| Rate limit | 1 request/second |
| Required field | `crate_name = "crate_name"` |

**Response parsing**: Extract `.crate.newest_version` for the latest version (including pre-releases), or `.crate.max_stable_version` for latest stable.

```nushell
# Query latest stable version for a crates.io package
def get-crates-latest [crate_name: string]: nothing -> string {
    let url = $"https://crates.io/api/v1/crates/($crate_name)"
    # User-Agent is REQUIRED by crates.io policy
    let headers = {"User-Agent": "claude-skills/mise-sources-check (github.com/vinnie357/claude-skills)"}
    let response = http get --headers $headers $url
    $response.crate.max_stable_version
}

# Example
let latest = get-crates-latest "wasmtime"
# Returns: "28.0.0"
```

**Notes**:
- Omitting `User-Agent` results in a 403 error
- `max_stable_version` excludes pre-releases; `newest_version` includes them
- Rate limit is enforced per IP; add `sleep 1sec` between calls in batch scripts
- Response also includes `$response.crate.homepage` and `$response.crate.documentation`

---

## npm

Queries the npm registry for a package's `dist-tags.latest` version.

| Property | Value |
|---|---|
| Endpoint | `https://registry.npmjs.org/{package}` |
| Auth | None required |
| Rate limit | No published anonymous limit found |
| Required field | `npm_package = "package_name"` (`@scope/name` unmodified) |

**Response parsing**: Extract `.dist-tags.latest`. **Gotcha (claude-skills-210 Gate 3)**: nushell's `get` only splits a dotted path on the `.` when the argument is an UNQUOTED bareword (`get dist-tags.latest`). A QUOTED string (`get -o "dist-tags.latest"`) is treated as one flat column name — the response has no such flat key (it's nested, `{"dist-tags": {"latest": ...}}`), so the quoted form always misses and silently returns nothing. This shipped broken once; verify any change to this parsing against a real captured response, not just the URL.

```nushell
# Query latest dist-tag for an npm package
def get-npm-latest [package: string]: nothing -> string {
    let url = $"https://registry.npmjs.org/($package)"
    let response = http get $url
    $response | get -o dist-tags.latest | default "unknown"
}

# Example
let latest = get-npm-latest "express"
# Returns: "5.2.1" (verified live 2026-08-04)
```

**Notes**:
- A nonexistent package renders as a 404 (`Requested file not found (404): ...`), classified as `no-releases` by `classify-fetch-error` — same handling as a dead GitHub releases feed
- `dist-tags` also carries other tags (e.g. `latest-4` for an old major's maintenance line); only `latest` is queried here

---

## docker-hub

Queries the Docker Hub Hub API v2 tags list for an image, sorted by most-recently-updated. An optional `docker_tag` field switches to a per-tag digest comparison instead — see "Tracking a specific pinned tag" below.

| Property | Value |
|---|---|
| Endpoint | `https://hub.docker.com/v2/repositories/{namespace}/{repository}/tags?page_size=1&ordering=last_updated` |
| Auth | None required (public repos) |
| Rate limit | Not documented for Hub API reads (distinct from the image-pull rate limit) |
| Required field | `docker_image = "namespace/repository"` (e.g. `library/node`) |
| Optional field | `docker_tag = "tag"` — see below |

**Response parsing**: Extract `.results[0].name`. **`ordering=last_updated` (no leading `-`) is NEWEST-first** — verified live; do not "correct" this to `-last_updated`, which is oldest-first and the opposite of what this check needs.

```nushell
# Query the most-recently-updated tag for a Docker Hub image
def get-docker-hub-latest [image: string]: nothing -> string {
    let url = $"https://hub.docker.com/v2/repositories/($image)/tags?page_size=1&ordering=last_updated"
    let response = http get $url
    let results = ($response.results? | default [])
    if ($results | is-empty) { "unknown" } else { $results | first | get -o name | default "unknown" }
}

# Example
let latest = get-docker-hub-latest "library/node"
# Returns: "lts-trixie-slim" (verified live 2026-08-04)
```

**Notes**:
- Docker Hub tags are not semver in general — this answers "is a newer tag available" (string equality against the most-recently-updated tag name), not "is there a newer semver release"
- A specific pinned tag that isn't itself version-shaped (e.g. `16-buster-slim`) belongs in `notes`, not `current_version` — `current_version = "unknown"` with `version_constraint = "rolling"` is the schema-compliant way to track it (see `templates/sources.toml`)
- **claude-skills-225**: the two schema-compliant usages above never produce a transitioning staleness signal for a realistically pinned image. `current_version = "unknown"`/rolling is never compared, so it reports no-pin forever. A version-shaped `current_version` set to the pinned tag (e.g. `"16-buster-slim"`) is compared against the newest tag OVERALL (e.g. `"lts-trixie-slim"`), which never equals a stable pin, so it reports stale forever. Neither state ever changes. Set `docker_tag` (below) when a real drift signal is needed for a specific pin.

### Tracking a specific pinned tag (`docker_tag`)

When `docker_tag` is set, `check-docker-hub-tag` queries the per-tag endpoint for that exact tag and returns its content **digest** instead of the newest tag's name. `current_version` then stores the last-observed digest; a re-push of that tag (a patched base image, a rebuilt binary) changes the digest and correctly reports drift on the next check. An exact-match, unchanged tag correctly reports current. A deleted tag 404s and classifies as `no-releases`, same as every other check_method's dead-feed handling.

| Property | Value |
|---|---|
| Endpoint | `https://hub.docker.com/v2/repositories/{namespace}/{repository}/tags/{tag}/` |
| Auth | None required (public repos) |
| Required field | `docker_image` (as above) plus `docker_tag = "tag"` (e.g. `16-buster-slim`) |

```nushell
# Query a specific pinned tag's content digest
def get-docker-hub-tag-digest [image: string, tag: string]: nothing -> string {
    let url = $"https://hub.docker.com/v2/repositories/($image)/tags/($tag)/"
    let response = http get $url
    $response | get -o digest | default "unknown"
}

# Example
let latest = get-docker-hub-tag-digest "library/node" "24-alpine"
# Returns: "sha256:d32cdf619f63fe0471182d08996dd516c6275bb5fd31ae06e55a570bd9e1ad43" (verified live 2026-08-04)
```

**Notes**:
- `current_version` for a `docker_tag`-tracked source stores a digest string (e.g. `"sha256:..."`), not a semver-shaped version — `version_constraint = "rolling"` still applies, since the tag itself has no discrete version progression, only content churn
- This answers "has this exact tag's content changed since I last checked", a narrower and different question from "is a newer version available" — appropriate for a deliberately pinned, non-version-shaped tag where that is the only meaningful drift signal available

---

## endoflife-date

Queries endoflife.date's per-product release-cycle feed for the newest cycle's latest patch version.

| Property | Value |
|---|---|
| Endpoint | `https://endoflife.date/api/{product}.json` |
| Auth | None required |
| Rate limit | Not documented |
| Required field | `eol_product = "product_slug"` (e.g. `nodejs`) |

**Response parsing**: The API returns release cycles newest-first; extract `[0].latest`.

```nushell
# Query the newest release cycle's latest patch version
def get-endoflife-latest [product: string]: nothing -> string {
    let url = $"https://endoflife.date/api/($product).json"
    let cycles = (http get $url | default [])
    if ($cycles | is-empty) { "unknown" } else { $cycles | first | get -o latest | default "unknown" }
}

# Example
let latest = get-endoflife-latest "nodejs"
# Returns: "26.6.0" (verified live 2026-08-04)
```

**Notes**:
- Reports the newest cycle's latest patch UNCONDITIONALLY, even when that cycle is itself past its own `eol` date (a fully-EOL product like `centos` still returns its last cycle's last patch). This matches every other check_method here — none of them filter by "is this still supported", only "is a newer version available to pin"
- The product slug must match endoflife.date's URL scheme exactly (check the product's page URL, e.g. `endoflife.date/nodejs` → `nodejs`)

### EOL sentinel (`check-endoflife-status`)

**claude-skills-226**: the plain `get-endoflife-latest` above confidently reports an EOL version as "latest" — verified live: `centos` returns `"8 (2111)"` with no signal that cycle 8 has been end-of-life since 2021-12-31. `check-endoflife-status` (in `sources-lib.nu`) is the separate, explicit check named as future work above: it makes the SAME network call and additionally surfaces the newest cycle's own `eol` field as a tri-state (`true` / `false` / `"unknown"` when the date string fails to parse), plus the cycle identifier.

```nushell
# Query the newest cycle's latest patch AND whether that cycle is EOL
def get-endoflife-status [product: string]: nothing -> record<latest: string, eol: any, cycle: string> {
    let url = $"https://endoflife.date/api/($product).json"
    let cycles = (http get $url | default [])
    if ($cycles | is-empty) {
        {latest: "unknown", eol: "unknown", cycle: "unknown"}
    } else {
        let newest = ($cycles | first)
        let eol_val = ($newest.eol? | default false)
        let is_eol = if ($eol_val | describe) == "bool" {
            $eol_val
        } else if ($eol_val | describe) == "string" and ($eol_val | is-not-empty) {
            try { ($eol_val | into datetime) < (date now) } catch { "unknown" }
        } else {
            false
        }
        {latest: ($newest | get -o latest | default "unknown"), eol: $is_eol, cycle: ($newest | get -o cycle | default "unknown" | into string)}
    }
}

# Example
get-endoflife-status "centos"
# Returns: {latest: "8 (2111)", eol: true, cycle: "8"} (verified live 2026-08-04)
get-endoflife-status "nodejs"
# Returns: {latest: "26.6.0", eol: false, cycle: "26"} (verified live 2026-08-04)
```

**Notes**:
- `check-endoflife-date` (the plain string-returning check used by `fetch-latest`/`classify-staleness`) is unchanged and delegates to `check-endoflife-status` internally — one network call serves both
- Use `check-endoflife-status` directly when the EOL sentinel is needed; it is not wired into `mise sources:check`/`sources-report`/`sources-stale`'s output columns — those scripts still report only the plain staleness signal. Surfacing EOL status in the report output is a separate change to those three scripts, out of scope here

---

## manual

No automated API check. Requires human review of the `releases_url`.

| Property | Value |
|---|---|
| Endpoint | N/A |
| Auth | N/A |
| Rate limit | N/A |
| Required field | `releases_url` strongly recommended |

**When to use**:
- Source is documentation or a specification (no versioned releases)
- Source uses a custom release page not covered by other methods
- Source is behind authentication
- Upstream does not publish machine-readable release metadata

```nushell
# Manual sources appear in sources:check output with latest = "manual"
# The operator must visit releases_url and update current_version manually
```

**Workflow for manual sources**:
1. Open `releases_url` in a browser
2. Compare the latest posted version against `current_version` in `sources.toml`
3. If stale, follow the Phase 3 research steps manually
4. Update `current_version` and `last_checked` after verifying

---

## Batch Check Script Pattern

The `mise sources:check` task implements the following pattern across all plugins:

```nushell
# Pseudocode for mise sources:check
def check-all-sources [] {
    glob "plugins/**/skills/sources.toml"
    | each { |toml_path|
        open $toml_path
        | get sources
        | each { |source|
            let latest = match $source.check_method {
                "github-releases" => { get-github-latest $source.github_repo },
                "hex-pm"          => { get-hex-latest $source.hex_package },
                "crates-io"       => { get-crates-latest $source.crate_name },
                "manual"          => { "manual" },
                _                 => { error make { msg: $"Unknown check_method: ($source.check_method)" } }
            }
            let stale = if $latest == "manual" { false } else {
                $latest != $source.current_version
            }
            {
                plugin: $source.skill,
                source: $source.name,
                current: $source.current_version,
                latest: $latest,
                stale: $stale,
                priority: $source.update_priority
            }
        }
    }
    | flatten
    | sort-by priority stale --reverse
}
```

**Anti-fabrication**: The `mise sources:check` command must be implemented and executed before reporting version data. Do not estimate or guess version numbers.
