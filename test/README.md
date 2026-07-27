# Test Suite

Validation scripts for the claude-skills marketplace and plugins.

## Usage

### Run All Tests

Validates marketplace.json and all plugin.json files, plus the skill quality
gate:

```bash
mise run ci
# or
mise test
```

`mise run ci` is the canonical CI gate (matches the workspace-wide convention);
it depends on `test`, which depends on `test:claude`, `test:marketplace`,
`test:plugins`, `test:skills-quality`, `test:core-list`, and `test:disclosure`.

`test:version-bumps` is deliberately **not** a dependency of `test` — it
needs a real base ref to diff against, which is only meaningful with the
correct PR base branch. It runs as its own dedicated CI job
(`check-version-bumps` in `.github/workflows/validate.yml`, comparing against
`origin/<base_ref>`). Run it locally with `mise run test:version-bumps <base>`.

### Test Marketplace Only

Validates only marketplace.json, including the static plugin.json ↔
marketplace.json version-sync check:

```bash
mise test:marketplace
```

### Test All Plugins

Validates all plugin.json files:

```bash
mise test:plugins
```

### Test Specific Plugin

Validates a single plugin:

```bash
mise test:plugin elixir
```

### Test Claude Native Validation

Runs `claude plugin validate .` via the mise-managed Claude CLI:

```bash
mise test:claude
```

Locally, a missing mise-managed `claude` binary is a warning (skip). Under
CI (`$env.CI` set), a missing binary is a hard failure.

### Test Core Skill List

Checks that the mandatory core skill list has not drifted: every satellite
file's operative load list (located via a per-file anchor line) matches the
canonical block in `agent-loop/SKILL.md`, every other list in those files
agrees too, and no unregistered `.md`/`.sh` file carries a near-complete
copy of the list. Runs its own fixture suite first:

```bash
mise test:core-list
# or directly
nu test/validate-core-list.nu --self-test
nu test/validate-core-list.nu
```

### Test Version Bumps

Checks that every plugin with changed files also bumped its version in both
`plugin.json` and `marketplace.json`:

```bash
mise run test:version-bumps main
```

Fails loudly (non-zero exit, diagnostic message) if the base ref does not
exist — it no longer silently reports "no files changed" on a bad `--base`.

### Direct Script Usage

You can also run the Nushell scripts directly. `test:marketplace` and
`test:claude` are inline `mise.toml` tasks with no standalone script
equivalent:

```bash
# Specific plugin
nu test/validate-plugin.nu elixir

# Skill quality scorecard
nu test/validate-skills-quality.nu

# Version bump check (requires a base ref)
nu test/check-version-bumps.nu --base main
```

### List All Plugins

```bash
mise list-plugins
```

## What Gets Validated

### Marketplace Validation

- Required fields: `name`, `owner`, `plugins`
- Plugin entries have required fields: `name`, `source`
- Plugins array is valid JSON array
- All plugin entries are well-formed
- Every local plugin's `plugin.json` version matches its `marketplace.json`
  entry version (includes the `all-skills` root `plugin.json`, source `./`)

### Plugin Validation

**Required Fields:**
- `name` (must match directory name and be kebab-case)

**Invalid Fields (marketplace-only):**
- `dependencies`, `category`, `strict`, `source`, `tags`

**Recommended Fields (warnings if missing):**
- `version`, `description`, `license`

**Additional Checks:**
- Name matches directory name
- Name is kebab-case format
- Skill paths exist if specified

## Skill Quality Checks

`mise test:skills-quality` runs four passes — 17 static checks per skill, an
agents/commands/hooks surface pass per plugin, one corpus-wide
duplicate-block scan, and a syntax-vs-usage vocabulary cross-check —
enforcing all four against the same ratchet baseline
(`test/quality-baseline.json`):

- A failing check **not** in the baseline fails the run — new violations cannot land.
- A baseline entry that now **passes** fails the run until the entry is removed —
  the baseline only shrinks (ratchet).

Baseline entries are `plugin/skill:check` strings (or `plugin/agents/<file>:check`,
`plugin/commands/<file>:check`, `plugin/hooks/hooks.json:check` for the
agents/commands/hooks surfaces, `dupe/<hash>:duplicate_block` for the
duplicate-block pass, and `syntax/<format>:vocab_disjoint` for the
syntax-vs-usage pass). Every key ends in `:<check-name>`, which is how the
baseline schema and ratchet identify the check. When you fix a baselined
violation, regenerate the baseline:

```bash
nu test/validate-skills-quality.nu --update-baseline
```

`--update-baseline` is **shrink-only**: it intersects the currently-failing
keys with the existing baseline and errors (non-zero, naming the keys) if
regenerating would add any new key. Fix the skill instead of baselining a
new violation. A deliberate net-new debt acknowledgment requires editing
`test/quality-baseline.json` by hand and stating why in the PR.

### Per-skill checks (17)

| Key | Meaning |
|-----|---------|
| `desc` | Description non-empty, ≤1024 chars |
| `use_when` | Description contains "Use when" |
| `third_person` | Description has no "I can"/"You can"/"I will"/"You will" |
| `kebab` | Frontmatter `name` matches `^[a-z0-9]+(-[a-z0-9]+)*$` |
| `name_len` | Frontmatter `name` is 1–64 characters |
| `reserved` | Frontmatter `name` does not contain "anthropic" or "claude" |
| `lines` | SKILL.md is ≤500 lines |
| `examples` | Contains a code fence or a "## Example" header |
| `ref_depth` | `references/*.md` do not themselves link into `references/` (one level deep only) |
| `anti_fab` | Anti-fabrication rules present inline or referenced (`core:anti-fabrication`) |
| `source` | Skill is documented in the plugin's `skills/sources.md` |
| `allowed_tools` | Frontmatter does not set `allowed-tools` (tool allowlists belong on agents) |
| `name_dir` | Frontmatter `name` matches the skill's directory name |
| `links` | Every `references/`, `agents/`, `scripts/`, `templates/`, `hooks/` path mentioned in prose exists on disk |
| `orphans` | Every file under `references/` and `agents/` is mentioned at least once in SKILL.md |
| `invocations` | Every `/plugin:skill` token resolves to a real skill or command of a local plugin (external namespaces skipped) |
| `version_pin` | A "Current stable: X" / "Currently at version X" claim matches an "X (current)" entry in `sources.md` |

### Duplicate-block check

Runs once over the whole corpus rather than per skill: git-tracked `.md` and
`.sh` files under `plugins/`, plus the root `CLAUDE.md`. Files under `test/`
and `.github/` are out of scope — the check targets authored skill content.

It reports any run of **8 or more normalised lines** appearing in two or more
files. Normalisation trims each line, strips leading bullet (`-`/`*`/`+`) and
ordered (`N.`) markers and backticks, and collapses whitespace; blank,
punctuation-only, and fence-delimiter lines are dropped. Single-word lines are
deliberately **kept** — dropping them hides list-shaped duplication such as the
mandatory core-skill list, which is the pattern this check exists to find.

Findings are grouped by the **set of files** a run spans, so one duplicated
section is one entry rather than one per overlapping window. The baseline key
is `dupe/<hash-of-sorted-file-set>:duplicate_block`, and `detail_count` is the
number of shared windows, so a waived group that **grows** still fails. The
member paths are always printed — the hash alone is not actionable.

Three exemptions, each absorbing duplication that is intentional:

| Exemption | Reason |
|-----------|--------|
| Every member path contains `/templates/` | Version-pinned upstream doc snapshots are deliberately preserved copies |
| All members belong to one skill | A worked example shared between a skill's own references is intentional |
| The file set is owned by `validate-core-list.nu` | That script drift-checks the core-skill list with per-file anchors; one concern, one owner |

The third exemption derives its file list by parsing `validate-core-list.nu`
rather than restating it — a second hardcoded copy would be exactly the
duplication this check reports. It defers to that script; it does not skip the
content silently.

### Agents/commands/hooks surface checks

Runs once per plugin (not per skill), covering the plugin's top-level
`agents/` and `commands/` directories, any skill-level nested `agents/`
directories, and `hooks/hooks.json`:

| Key | Surface | Meaning |
|-----|---------|---------|
| `missing_name` | agent | Frontmatter has no `name:` |
| `missing_desc` | agent, command | Frontmatter has no `description:` |
| `bad_model` | agent | Frontmatter `model:` is present but not one of `haiku`, `sonnet`, `opus` |
| `bad_invocations` | agent, command | An `/plugin:skill` token in the file does not resolve |
| `bad_wrapper` | hooks | `hooks/hooks.json` is not valid JSON, or has no top-level `hooks` object |
| `bad_event` | hooks | A hook event name is not one of `PreToolUse`, `PostToolUse`, `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `Stop`, `SubagentStop`, `PreCompact`, `Notification` |

Use `/benchmark-skills` for a more detailed analysis with category classification and quality assessment.

### Syntax-vs-usage vocabulary check

For each format this repo both documents and contains, the check extracts the
**documented** token vocabulary (from the documenting skill's `SKILL.md` plus
`references/*.md` — prose and tables included, never just fenced blocks) and
the **real** vocabulary (from the repo's own instances), and fires when the
sets are disjoint or the doc carries a foreign-family token. The baseline key
is `syntax/<format>:vocab_disjoint`; `detail_count` is the size of the
disjoint documented set. Both vocabularies are printed on failure.

| Format | Documenting skill | Real instances | Foreign family |
|--------|-------------------|----------------|----------------|
| `commands` | `claude-commands` | `plugins/**/commands/*.md` | Handlebars-style `{{...}}` |
| `agents` | `claude-agents` | frontmatter keys of `plugins/**/agents/*.md` | — |
| `hooks` | `claude-hooks` | `hooks` keys of `plugins/**/hooks/hooks.json` | — |

**This is a tripwire, not a net.** The real vocabularies are tiny — 1 command
token (`$ARGUMENTS`), 1 hook event (`SessionStart`), 5 agent frontmatter keys —
so the check effectively asks "does the doc mention any token reality uses,
and does it avoid foreign-family syntax". That is exactly the one observed
defect class (a rewrite of `claude-commands/SKILL.md` replaced fabricated
Handlebars syntax that never mentioned `$ARGUMENTS`), not a general guarantee
of doc accuracy. Documented-but-unused tokens are deliberately NOT flagged:
correct reference docs cover features this repo does not exercise.

Two asymmetric guards:

- An **empty documented vocabulary is a hard error** (extractor canary, not a
  baselineable finding): the three skills are known to document tokens, so
  extracting none means the extractor broke — silence would hide the format
  forever. An empty **real** vocabulary stays silent.
- The **foreign-family rule fires regardless of intersection**: since the real
  command vocabulary is a single token, pure disjointness has a one-token
  margin — a doc full of fabricated brace syntax plus one `$ARGUMENTS` mention
  would otherwise pass.

The real side never runs a general `\$[a-z_]+` regex — real command files
carry plain bash (`$USER`, `$SESSION_ID`, `$BUILD_DIR`) in example scripts.
A named-arg token counts only when the file declares `arguments:` in its
frontmatter; both sides normalise named args to one `$name` family marker.

## Scripts

- **validate-plugin.nu** — Validates a specific plugin (name, kebab-case, invalid fields, skill paths)
- **validate-skills-quality.nu** — Skill quality scorecard plus agents/commands/hooks surface pass, duplicate-block scan, and syntax-vs-usage vocabulary check, all ratchet-baseline enforced (`--update-baseline` to regenerate, shrink-only)
- **validate-core-list.nu** — Verifies the mandatory core skill list is identical across the canonical block and all anchored satellite load lists, and sweeps for unregistered files carrying a near-complete copy (`--self-test` runs its fixtures)
- **check-version-bumps.nu** — Verifies every plugin with changed files bumped `plugin.json` and `marketplace.json` versions against a base ref; hard-fails on a missing/invalid base ref

`quality-baseline.json` is the ratchet baseline data file consumed by `validate-skills-quality.nu` — not a script, but tracked here since it gates CI.

## Exit Codes

- `0` - All validations passed
- `1` - Validation failed

## Integration

These tests are integrated with mise via `mise.toml`:

```toml
[tasks.ci]
depends = ["test"]

[tasks.test]
depends = ["test:claude", "test:marketplace", "test:plugins", "test:skills-quality"]

[tasks."test:claude"]
# Runs `claude plugin validate .` via the mise-managed Claude CLI

[tasks."test:marketplace"]
# Validates marketplace.json + plugin.json/marketplace.json version sync

[tasks."test:plugins"]
# Validates all plugin.json files

[tasks."test:plugin"]
# Validates a specific plugin

[tasks."test:skills-quality"]
# Skill quality scorecard + agents/commands/hooks surfaces + duplicate-block + syntax-vs-usage, ratchet-baseline enforced

[tasks."test:version-bumps"]
# NOT a dependency of test — run directly or via the dedicated CI job
```

### Task Hierarchy

```
ci
└── test
    ├── test:claude          (claude plugin validate . via mise-managed CLI)
    ├── test:marketplace     (marketplace.json + version-sync validation)
    ├── test:plugins         (all plugin.json files)
    └── test:skills-quality  (skill quality scorecard + surfaces + duplicates + syntax-vs-usage)

test:plugin <name>       (validates a specific plugin, standalone)
test:version-bumps <base> (standalone — also runs as a dedicated CI job on PRs)
```

## Example Output

```
🔍 Validating all plugins...

✅ plugin: claude-code
✅ plugin: core
✅ plugin: elixir
✅ plugin: rust

📊 Local: 24, External: 1

✨ All plugins are valid!
```
