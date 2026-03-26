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
