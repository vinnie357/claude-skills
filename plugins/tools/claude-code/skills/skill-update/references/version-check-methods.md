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
def get-github-latest [repo: string] -> string {
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
def get-hex-latest [package: string] -> string {
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
def get-crates-latest [crate_name: string] -> string {
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
def get-npm-latest [package: string] -> string {
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

Queries the Docker Hub Hub API v2 tags list for an image, sorted by most-recently-updated.

| Property | Value |
|---|---|
| Endpoint | `https://hub.docker.com/v2/repositories/{namespace}/{repository}/tags?page_size=1&ordering=last_updated` |
| Auth | None required (public repos) |
| Rate limit | Not documented for Hub API reads (distinct from the image-pull rate limit) |
| Required field | `docker_image = "namespace/repository"` (e.g. `library/node`) |

**Response parsing**: Extract `.results[0].name`. **`ordering=last_updated` (no leading `-`) is NEWEST-first** — verified live; do not "correct" this to `-last_updated`, which is oldest-first and the opposite of what this check needs.

```nushell
# Query the most-recently-updated tag for a Docker Hub image
def get-docker-hub-latest [image: string] -> string {
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
def get-endoflife-latest [product: string] -> string {
    let url = $"https://endoflife.date/api/($product).json"
    let cycles = (http get $url | default [])
    if ($cycles | is-empty) { "unknown" } else { $cycles | first | get -o latest | default "unknown" }
}

# Example
let latest = get-endoflife-latest "nodejs"
# Returns: "26.6.0" (verified live 2026-08-04)
```

**Notes**:
- Reports the newest cycle's latest patch UNCONDITIONALLY, even when that cycle is itself past its own `eol` date (a fully-EOL product like `centos` still returns its last cycle's last patch). This matches every other check_method here — none of them filter by "is this still supported", only "is a newer version available to pin". A future caller wanting "is this product line still supported" would build that as a separate check against each cycle's `eol` field, not fold it into this one
- The product slug must match endoflife.date's URL scheme exactly (check the product's page URL, e.g. `endoflife.date/nodejs` → `nodejs`)

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
