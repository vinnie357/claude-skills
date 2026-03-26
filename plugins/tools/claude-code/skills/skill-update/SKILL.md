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
| `mise sources:check` | Compare current vs latest for all plugins |
| `mise sources:stale` | List only stale sources |
| `mise sources:validate` | Validate sources.toml schema in all plugins |
| `mise sources:report` | Full freshness report with priorities |
| `mise sources:init <plugin>` | Bootstrap sources.toml for a plugin |

## sources.toml Schema

Each plugin's `skills/sources.toml` tracks upstream dependencies. See `templates/sources.toml` for the complete annotated template.

| Field | Values | Required | Description |
|---|---|---|---|
| `skill` | string | yes | Skill directory name |
| `name` | string | yes | Human-readable source identifier |
| `url` | string | yes | Primary source URL |
| `releases_url` | string | no | Release tracking URL |
| `check_method` | see table below | yes | How to query latest version |
| `github_repo` | `owner/repo` | conditional | Required for `github-releases` |
| `hex_package` | string | conditional | Required for `hex-pm` |
| `crate_name` | string | conditional | Required for `crates-io` |
| `current_version` | string | yes | Currently documented version |
| `version_constraint` | `pre-1.0` \| `semver` \| `rolling` \| `stable` | yes | Version stability model |
| `last_checked` | `YYYY-MM-DD` | yes | Date of last check |
| `update_priority` | `high` \| `medium` \| `low` | yes | Update urgency |
| `breaking_changes_likely` | bool | no | Minor bumps may break (default: false) |
| `notes` | string | no | Free-form context |

## Check Method API Endpoints

| `check_method` | Endpoint | Auth | Rate Limit |
|---|---|---|---|
| `github-releases` | `https://api.github.com/repos/{owner}/{repo}/releases/latest` | Optional `GITHUB_TOKEN` | 60/hr unauth, 5000/hr auth |
| `hex-pm` | `https://hex.pm/api/packages/{package}` | None | 100/min |
| `crates-io` | `https://crates.io/api/v1/crates/{crate}` | `User-Agent` header required | 1/sec |
| `manual` | N/A | N/A | N/A — check `releases_url` manually |

See `references/version-check-methods.md` for Nushell parsing examples.

---

## Phase 1: Discovery

Run `mise sources:check` to produce a staleness table:

```
plugin        | skill       | source          | current | latest  | stale | priority
claude-code   | container   | apple-container | 0.10.0  | 0.11.0  | yes   | high
elixir        | tidewave    | tidewave        | 0.5.6   | 0.5.6   | no    | medium
```

If `sources.toml` does not exist for a plugin, run `mise sources:init <plugin>` first.

**Anti-fabrication**: Do not report version numbers without executing `mise sources:check` or querying the upstream API directly. Mark unknown versions as `"requires-check"`.

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
4. Determine if a versioned template is needed (e.g., `templates/0.11.0/commands.md`)

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

1. Update `sources.toml`: set `current_version` and `last_checked`
2. Update `sources.md`: add release entry with date and summary
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
| SKILL.md length | `wc -l SKILL.md` | Under 500 lines |
| Sources valid | `mise sources:validate` | No schema errors |
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

1. Run `mise sources:init <plugin>` to generate a skeleton
2. Fill in all `[[sources]]` entries for each skill
3. Set `current_version` by reading the skill's current SKILL.md
4. Set `last_checked` to today's date
5. Run `mise sources:validate` to confirm schema
6. Commit: `chore(<plugin>): add sources.toml for version tracking`
