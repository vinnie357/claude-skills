---
name: skill-update
description: Repeatable process for keeping skills up-to-date with upstream sources and versions. Use when checking for stale skills, updating a skill for a new upstream version, auditing source freshness, or bootstrapping version tracking for a plugin.
license: MIT
---

# Skill Update

Structured workflow for keeping skills current with upstream sources. Execute all phases in order.

## Quick Reference

| Command | Purpose |
|---|---|
| `mise sources:check` | Compare current vs latest for all plugins; `eol` column flags an end-of-life release line for `endoflife-date` sources (claude-skills-237) |
| `mise sources:stale` | List only stale sources |
| `mise sources:validate [plugin] [line\|json\|table]` | Validate that all source URLs resolve (HTTP HEAD, GET fallback on 405); default `line` format is one grep-able row per URL, `json` pipes straight to `jq` |
| `mise test:sources` | Validate sources.toml schema + plugin.json/sources.md agreement |
| `mise sources:report` | Full freshness report with priorities |
| `mise sources:init <plugin>` | Print a DRAFT sources.toml for a plugin (never trusted; `--write` to save) |
| `mise sources:fence-check` | Freshness report for version literals pinned INSIDE code fences (claude-skills-176) |
| `mise test:fenced-literals` | Validate fenced-literals.toml schema + doc-content agreement (network-free) |

## sources.toml Schema

Each plugin's `skills/sources.toml` tracks upstream dependencies. See `templates/sources.toml` for the complete annotated template.

`[meta]` — three required keys: `plugin` (must equal `plugin.json` `name`), `reviewed_at_plugin_version` (the `plugin.json` version at the last ACTUAL sources review, or `"unknown"` — never advanced by a version-bump commit, only by a review), `last_full_check` (`YYYY-MM-DD` or `"unknown"`).

| Field | Values | Required | Description |
|---|---|---|---|
| `skills` | `list<string>` | yes | Skill DIRECTORY names covered by this source — a non-empty list, not a scalar |
| `name` | string | yes | Human-readable source identifier |
| `url` | string | yes unless `check_method = "none"` | Primary source URL |
| `releases_url` | string | no | Release tracking URL |
| `check_method` | see table below | yes | How to query latest version |
| `github_repo` | `owner/repo` | conditional | Required for `github-releases` |
| `hex_package` | string | conditional | Required for `hex-pm` |
| `crate_name` | string | conditional | Required for `crates-io` |
| `npm_package` | string | conditional | Required for `npm` (registry package name, `@scope/name` included) |
| `docker_image` | `namespace/repository` | conditional | Required for `docker-hub` (e.g. `library/node`) |
| `docker_tag` | string | conditional | Optional for `docker-hub` (e.g. `13-slim`) — when set, switches the check to the per-tag content digest of that exact pin instead of the newest tag's name (claude-skills-225); `current_version` then holds a `sha256:<64 hex>` digest, accepted by `b3_version_shape` only for entries that set this field |
| `eol_product` | string | conditional | Required for `endoflife-date` (the endoflife.date product slug, e.g. `nodejs`) |
| `current_version` | QUOTED shape-checked version string \| `unknown` | yes unless `none` | The upstream version this skill content was last verified/documented against |
| `version_constraint` | `pre-1.0` \| `semver` \| `rolling` \| `stable` | yes unless `none` | Version stability model — NOT valid values for `current_version` itself; a rolling/stable source with no discrete version records `current_version = "unknown"` (the convention 117 of 119 `rolling` entries and 8 of 12 `stable` entries already follow) |
| `last_checked` | `YYYY-MM-DD` \| `unknown` | yes | Date of last check |
| `update_priority` | `high` \| `medium` \| `low` | yes unless `none` | Update urgency |
| `breaking_changes_likely` | bool | no | Minor bumps may break (default: false) |
| `notes` | string | no in general, yes when `check_method = "none"` | Free-form context |

Record `unknown` for `current_version` or `last_checked` when the real value can't be established — a guessed date or version is fabrication; `unknown` is the sanctioned way to say so. The two are established differently: `last_checked` is the date the check ran, so a live upstream query settles it. `current_version` is the version the skill content was **verified against**, which a live query does not establish — finding 0.9.31 upstream tells you the pin has drifted, not that the content matches 0.9.31. Record the drift in `notes` and leave the pin where verification actually happened. Both are format-checked: `last_checked` by `test/validate-sources.nu` rule `b3_date` (`YYYY-MM-DD` or the literal `unknown`, rejecting anything else); `current_version` by rule `b3_version_shape` (`unknown`, or a shape-based match — not strict semver — of an optional short alpha prefix like `v` or `OTP` with an optional `-`/`.` separator, one to five dot-separated numeric groups, and an optional `-prerelease` or `+build` suffix: `^[A-Za-z]{0,10}[-.]?\d+((\.\d+){1,4}([-+][0-9A-Za-z.-]+)?|([-+][0-9A-Za-z.]+)?)$`). A hyphenated suffix (`-alpha-1`, `-rc-2`) is legal only when the base has at least one dot-group — semver itself requires a dotted numeric base before a prerelease/build suffix, so a bare-integer base has no business carrying one. This accepts CalVer (`v2026.3.15`), OTP-style (`OTP-29.0.4`), bare majors (`3`), and pre-release/build suffixes including a hyphenated segment like `1.0.0-alpha-1` (claude-skills-196), while rejecting bare calendar dates and hyphenated junk like `2024-01-01`, `10-11-2025`, and `1-800-flowers` (claude-skills-196/197, PR #188 Gate 3), plus embedded whitespace, pasted URLs, and prose like `banana` or `see changelog`.

`current_version` must be a **quoted TOML string**, not a bare number — `test/validate-sources.nu` rejects any non-string type before the shape check runs (claude-skills-197). An unquoted `current_version = 1.10` parses as a TOML float and silently records `"1.1"`, a different version than what was typed, with no diagnostic; quoting it (`current_version = "1.10"`) is unaffected by TOML's numeric coercion and passes.

Two version shapes are deliberately rejected, not merely unsupported yet (claude-skills-196):

- **PEP 440 separator-less suffixes** (`3.13.0rc1`, `2.0b1`, `1.0.post1`) — widening the shape regex to accept these also admits 6 of 31 measured adversarial junk strings, the sharpest being `1.x` (a version *constraint*, not a version — exactly what this rule exists to block). No tracked upstream in this repo uses PEP 440: there is no `pypi` `check_method`, and 0 corpus entries name a Python/CPython upstream.
- **Dual `-prerelease`+`+build` suffixes** (`1.0.0-rc.1+build.5`) — rejected by strict `SEMVER_RE` itself, which permits only one suffix group. Accepting it in the shape-based `current_version` check alone would make that check wider than strict semver in a direction semver itself forbids.

If either need becomes real (a tracked PyPI upstream, a source that genuinely emits dual suffixes), widen both regexes together as its own decision — don't reopen this quietly.

`check_method = "none"` is for skills with no external upstream (first-party doctrine authored in this repo): `notes` is required (state why there is no upstream), and `url` / `current_version` / `version_constraint` / `update_priority` are forbidden.

## sources.md index convention

Every `sources.toml` entry `name` must appear in `sources.md` **prose** — `test:sources` rule `c2_md_no_mention` strips scheme-prefixed URLs before matching, so a name sitting only inside its own `- **URL**:` field does not count. Naming an entry after what the prose already calls it needs no extra text — that is the default and what `mise sources:init` produces. When prose doesn't already name it, append one `Entries:` sentence to the `Structured tracking:` pointer line (same line, not a new one), backticked names, comma-separated:

```
Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there. Entries: `name-one`, `name-two` (the Foo Skill section below).
```

## Check Method API Endpoints

| `check_method` | Endpoint | Auth | Rate Limit |
|---|---|---|---|
| `github-releases` | `https://api.github.com/repos/{owner}/{repo}/releases/latest` | Optional `GITHUB_TOKEN` | 60/hr unauth, 5000/hr auth |
| `hex-pm` | `https://hex.pm/api/packages/{package}` | None | 100/min |
| `crates-io` | `https://crates.io/api/v1/crates/{crate}` | `User-Agent` header required | 1/sec |
| `npm` | `https://registry.npmjs.org/{package}` — reads `.dist-tags.latest` | None | No published anonymous limit found |
| `docker-hub` | `https://hub.docker.com/v2/repositories/{namespace}/{repository}/tags?page_size=1&ordering=last_updated` — reads the newest tag's `name` | None (public repos) | Not documented for Hub API reads (distinct from the image-pull rate limit) |
| `endoflife-date` | `https://endoflife.date/api/{product}.json` — reads the first (newest) cycle's `latest` | None | Not documented |
| `manual` | N/A | N/A | N/A — check `releases_url` manually |
| `none` | N/A | N/A | N/A — no external upstream exists |

Docker Hub tags are not semver in general — `check-docker-hub` reports "is a newer tag available" (string equality against the most-recently-updated tag name), not "is there a newer semver release." A specific pinned tag that isn't itself version-shaped (e.g. `16-buster-slim`) belongs in `notes`, not `current_version` — `current_version = "unknown"` with `version_constraint = "rolling"` is the schema-compliant way to track it (see `templates/sources.toml`).

Setting `docker_tag` switches the check to `check-docker-hub-tag`, which queries the per-tag endpoint (`https://hub.docker.com/v2/repositories/{namespace}/{repository}/tags/{tag}/` — reads that tag's own `digest` field) instead of the newest-tag-name endpoint above. This answers a narrower, genuinely answerable question for a realistically pinned image: has THIS exact tag been re-pushed since I last checked, not merely does a differently-named tag exist. `current_version` stores the last-observed digest; drift means the base image was rebuilt (security patch, layer update) under the same tag name. See `plugins/tools/agent-sandboxing/skills/sources.toml`'s `debian-13-slim-base-image` entry for a worked, live example (claude-skills-225).

`check-endoflife-status` (in `scripts/sources-lib.nu`) is the EOL-aware counterpart to the `endoflife-date` check_method above: one call to the same `https://endoflife.date/api/{product}.json` endpoint returns the newest cycle's `latest` patch, that cycle's own `eol` state, and its `cycle` identifier, rather than only the string `fetch-latest`/`classify-staleness` consume. `check-endoflife-date` (the schema-facing function) calls it and returns just `.latest`, preserving `current_version`/`stale` semantics unchanged (claude-skills-226). `mise sources:check` now surfaces the sentinel automatically as a separate `eol` column (yes/no/unknown/n/a), kept distinct from `stale` per claude-skills-174's "behind latest is not itself a finding" policy — no manual call needed (claude-skills-237).

See `references/version-check-methods.md` for Nushell parsing examples.

---

## Phase 1: Discovery

Run `mise sources:check` to produce a staleness table. Live run against this repo's own corpus, 2026-08-01 — `plugin`/`skill`/`source`/`current`/`latest`/`stale`/`priority` are copied verbatim from the run; `notes` is a short paraphrase, not a literal quote (real `notes` values run 700–1100+ characters):

```
plugin | skill   | source     | current    | latest    | stale  | priority | notes (paraphrased)
core   | mise    | mise       | v2026.3.15 | 2026.7.18 | yes    | medium   | pinned version is months behind upstream
core   | nushell | nushell    | 0.113.1    | 0.114.1   | yes    | high     | pinned version is one minor behind upstream
github | act     | nektos-act | unknown    | 0.2.89    | no-pin | medium   | current_version was never pinned — not drift
```

`sources:check` / `sources:stale` / `sources:report` are on-demand, network-dependent operator tools — deliberately NOT part of `mise test`/`mise run ci` (CI has zero external dependencies). `stale` is one of: `yes` (real drift), `no` (current), `no-pin` (`current_version = "unknown"` — nothing recorded to compare, not drift), `manual`/`internal` (check_method doesn't query an API), `no-releases` (upstream has no GitHub Releases feed — a 404, not an error; six sources.toml entries across five plugins document a live 404 today, e.g. `actions-toolkit`, and all six sit on `check_method = "manual"` for exactly that reason, so this state currently only fires if an entry is later flipped to `github-releases` without re-checking the feed first), `rate-limited` (403/unauthenticated GitHub response — retry with `GITHUB_TOKEN` set), `unknown` (hex-pm/crates-io package exists with zero published releases), `unset` (no `current_version` recorded at all), `error` (fetch failed for another reason). The `notes` column surfaces whatever free-text rationale a toml entry already carries — if an entry existed to track an upstream-documented default as intentionally pinned, that rationale would live in `notes` rather than a new schema field; see the coverage gap below for why act's own such case has no entry to carry one yet.

**Known gap — this tool answers "is a tracked pin stale", not "is every version literal in skill content stale".** `sources.toml` tracks freshness per SKILL, not per literal — a fenced Docker tag or CLI version pin inside a doc has no connection to `current_version` unless someone deliberately wires one. claude-skills-210 closed the SCHEMA half of this (added `npm`, `docker-hub`, and `endoflife-date` check_methods so a fenced literal like a Docker image tag CAN be expressed), but extending `sources.toml`'s coverage to every fenced literal was explicitly rejected as the fix — see claude-skills-176 below for why, and for the tool that actually closes it.

**Resolved (claude-skills-176):** a version literal inside a markdown code fence (or a non-markdown template like a Dockerfile) is invisible to BOTH `version_pin` (test/validate-skills-quality.nu check 17, which only parses "Current stable: X" PROSE claims) and `sources.toml` (which tracks one upstream per skill, not per literal). Extending `version_pin`'s sources.md-agreement check to also cover fences was considered and rejected: agreement is not freshness — the corpus already proves it, since the mise skill's own prose pin passes `version_pin` via sources.md agreement while sitting months behind upstream. The fix is a separate, explicitly-manual tool: `fenced-literals.toml` registers each literal (file, exact pinned string, upstream identity, and a `policy` of `track` or `intentional-pin`), and `mise sources:fence-check` queries upstream live and reports drift — honest about the network dependency, never wired into `mise test`/`mise run ci`. See "fenced-literals.toml Schema" below.

The three scripts' comparison/classification logic (`classify-staleness`, `classify-fetch-error`) is pure and self-tested independent of the network boundary: `nu <script> --self-test`. This proves the parsing/comparison logic; a live run against the real corpus is the only way to exercise the HTTP calls themselves.

If `sources.toml` does not exist for a plugin, run `mise sources:init <plugin>` first.

## fenced-literals.toml Schema

`plugins/tools/claude-code/skills/skill-update/fenced-literals.toml` registers version literals pinned INSIDE markdown code fences and non-markdown templates (claude-skills-176) — the class of pin `version_pin` and `sources.toml` cannot see.

| Field | Values | Required | Description |
|---|---|---|---|
| `file` | repo-relative path | yes | The file containing the pin |
| `literal` | string | yes | The EXACT pinned string, verbatim — must appear in `file`'s content (checked by `mise test:fenced-literals`) |
| `context` | string | no | One-line description of what the pin is for |
| `check_method` | `github-releases` \| `docker-hub` \| `manual` | yes | How to check whether the exact pin still resolves upstream |
| `github_repo` | `owner/repo` | conditional | Required for `github-releases` |
| `docker_image` | `namespace/repository` | conditional | Required for `docker-hub` |
| `pinned_tag` | string | conditional | Required for `github-releases`/`docker-hub` — the exact tag to check existence of (NOT "latest") |
| `eol_product` | string | no | endoflife.date product slug, for EOL cross-check |
| `eol_cycle` | string | no | The cycle string to look up (e.g. `"16"`, `"3.24"`) — required if `eol_product` is set |
| `policy` | `track` \| `intentional-pin` | yes | See policy below |
| `notes` | string | no in general, yes when `policy = "intentional-pin"` | Rationale for the exemption — same convention as `sources.toml`'s `check_method = "none"` requiring notes; no new schema field is reserved for "intentionally pinned" (claude-skills-180's explicit instruction) |
| `occurrences` | positive integer | no (default: 1) | How many times `literal` is expected to appear verbatim in `file`. See "Occurrence count" below. |

**Occurrence count (claude-skills-233):** the drift check is a substring match, so it only proves `literal` exists SOMEWHERE in `file` — a real pin can drift while an unrelated mention of the old string (a comment, a second unrelated example) survives elsewhere and keeps the bare-`contains` check green. `occurrences` closes this: `mise test:fenced-literals` counts the literal's actual occurrences in the file and fails if the count doesn't match. Most entries pin a single example and never set the field (default expectation: exactly 1). Set `occurrences` explicitly when a literal is legitimately repeated in one file — e.g. `wasi:io/streams@0.2.0` recurs across several examples in `wit/SKILL.md` (`occurrences = 4`). A mismatch (found count != expected) reports `c2_occurrence_mismatch`; a literal missing entirely still reports the original `c1_literal_drift`.

**Encoded policy (claude-skills-176, carrying forward claude-skills-174's rule explicitly):** a literal needs a fix when EITHER it is past its documented end-of-life, OR it no longer resolves upstream at all (the doc's own example would fail). A literal that is simply not the newest available, while still supported and still resolving, is deliberately left alone — "in-support-but-not-latest" is not a fix. `policy = "intentional-pin"` suppresses the EOL half of that rule (with `notes` explaining why) but NOT the broken half — a deleted upstream target produces code that cannot run no matter how deliberately the pin was chosen. `mise sources:fence-check` implements this via `classify-fence-status`, self-tested at `nu fence-freshness.nu --self-test` (network-free — the policy logic is pure; only the existence/EOL lookups touch the network).

**Named exception, encoded not narrated:** `github/skills/act/references/setup-and-config.md`'s `node:16-buster-slim` is `policy = "intentional-pin"` — act's own current docs still present that exact image as the micro-image example, so it stays pinned even though Node 16 is EOL (2023-09-11, confirmed live). This is claude-skills-176's own named case.

**Known limitation, not silently covered over:** for `node:16-buster-slim` specifically, `docker-hub`'s per-tag existence check is the only signal this tool can give — claude-skills-225 established that the "newest tag" comparator sources-lib.nu's `check-docker-hub` provides is degenerate for a deliberately-pinned tag (schema-compliant `current_version = "unknown"` usage reads `no-pin` forever; a version-shaped pin reads stale forever against a high-churn alias). `fence-freshness.nu` therefore checks existence via the Hub API's per-tag endpoint (`/v2/repositories/{image}/tags/{tag}/`) rather than reusing `check-docker-hub` — existence and EOL-status context are answerable today; genuine drift detection for a pinned Docker tag is not, until claude-skills-225 lands.

Run `mise test:fenced-literals` (network-free: schema + does the literal still appear in `file`) before every commit that touches this registry. Run `mise sources:fence-check` (network, manual) to see live drift.

**Anti-fabrication**: Do not report version numbers without executing `mise sources:check` or querying the upstream API directly. Mark unknown versions as `"unknown"`.

---

## Phase 2: Triage

Classify each stale source before updating:

| Condition | Classification | Action |
|---|---|---|
| `pre-1.0` + `breaking_changes_likely = true` + major bump | Critical | Full migration checklist |
| `semver` + major version bump | Breaking | Breaking changes review required |
| `semver` + minor/patch bump | Standard | Light-touch update |
| `rolling` or `stable` | Docs | Documentation refresh only |

**Priority order**: high → medium → low. Within same priority: breaking changes first.

---

## Phase 3: Research

For each update target, collect before writing any changes:

1. Fetch release notes from `releases_url`
2. Identify: breaking changes, new features, deprecations, bug fixes
3. Compare against skill's currently documented features
4. Determine if a versioned template is needed (a `templates/<version>/` snapshot of that version's commands)

**Anti-fabrication requirements**:
- Read actual release notes before claiming any feature exists in a new version
- Use `WebFetch` or equivalent to retrieve changelog content
- Mark any feature as "requires verification" if release notes are unavailable
- Never assume a command or flag exists — verify against official docs or release notes

---

## Phase 4: Update

Apply changes following the type-specific checklist in `references/update-checklist.md`.

### Skill Type Lookup

| Skill type | Examples | Checklist section |
|---|---|---|
| CLI tool | container, bees, beads | CLI Tools |
| Library package | tidewave, wasmex, phoenix | Library Packages |
| Language/runtime | rust, zig | Language/Runtime |
| Documentation-based | git, accessibility, twelve-factor | Documentation-Based |

### Versioned Templates

When a CLI tool has breaking command changes across versions, create a versioned template:

```
skills/<skill-name>/
└── templates/
    └── <new-version>/
        └── commands.md     # Commands snapshot for this version
```

Reference the old version template in the migration section of SKILL.md.

---

## Phase 5: Bookkeeping

Complete in this order after every update:

1. Update `sources.toml`: set `current_version` and `last_checked`. If this update constitutes an actual sources review, also set `meta.reviewed_at_plugin_version` and `meta.last_full_check`.
2. Extend the narrative entry in `sources.md` — never re-add version or date fields there; `test:sources` invariant C3 rejects a `- **Version**:` bullet.
3. Bump plugin version in `<plugin>/.claude-plugin/plugin.json`
4. Bump matching version in `.claude-plugin/marketplace.json`
5. Run `mise update-all-skills`
6. Run `mise test`

Use patch bumps (e.g., `0.5.6` → `0.5.7`) unless the skill itself has breaking changes.

---

## Phase 6: Validation

| Check | Command | Pass Criteria |
|---|---|---|
| Schema | `mise test` | All plugins pass |
| SKILL.md length | `wc -l SKILL.md` | Under 500 lines (the `lines` check in `test/validate-skills-quality.nu`) |
| Sources schema | `mise test:sources` | No invariant failures |
| Source URLs | `mise sources:validate` | No dead links |
| Commit format | — | Conventional commit, no attribution |

Commit format: `chore(<plugin>): update <skill> to <version>`

Example: `chore(claude-code): update container to 0.11.0`

Create PR with minimal format (title + bullet list, no attribution, no boilerplate sections).

---

## Agent Team Pattern

For batch updates across multiple plugins, spawn agents per plugin:

```
Orchestrator (sonnet)
├── Plugin checker (haiku) — runs mise sources:check for one plugin
├── Plugin checker (haiku) — runs mise sources:check for another plugin
└── ...

For each stale source:
├── Standard update (haiku)    — minor/patch semver, docs-based
└── Breaking update (sonnet)   — major semver, pre-1.0 breaking, CLI tools
```

Promote model if an agent fails the same task twice: haiku → sonnet → opus.

---

## Bootstrapping a New Plugin

When a plugin has no `sources.toml`:

1. Run `mise sources:init <plugin>` to print a DRAFT (it only prints — pass `--write` to save). The draft is NOT trusted: it emits `NEEDS-JUDGMENT` markers on every `skills = [...]` entry that must be resolved by hand against the plugin's real skill directories.
2. Resolve every `NEEDS-JUDGMENT` marker and fill in all `[[sources]]` entries for each skill
3. Set `current_version` by reading the skill's current SKILL.md
4. Set `last_checked` to today's date
5. Run `mise test:sources` to confirm schema
6. Commit: `chore(<plugin>): add sources.toml for version tracking`
