# plugin.json Validation Errors and Troubleshooting

> Reference file for the `claude-plugins` skill. Run the validator first — it names the offending
> field and value precisely. This page explains what each message means and covers the runtime
> failures no script can detect.

## Table of Contents

- [What the validator reports](#what-the-validator-reports)
- [Reserved plugin names](#reserved-plugin-names)
- [Runtime troubleshooting](#runtime-troubleshooting)

## What the validator reports

`nu <CLAUDE_SKILL_DIR>/scripts/validate-plugin.nu .claude-plugin/plugin.json` emits these. Errors
fail validation; warnings do not — unless `--strict` is passed (claude-skills-234), which promotes
any warnings into a failing result. `mise run test:plugins` runs every local plugin with `--strict`.

### Error — `Invalid name format: '<name>' (must be kebab-case)`

Lowercase alphanumeric and hyphens only, matching `^[a-z0-9]+(-[a-z0-9]+)*$`. The same rule and the same
message apply to marketplace names, via the `plugin-marketplace` skill.

### Error — `Invalid field '<field>' - this belongs in marketplace.json, not plugin.json`

Raised for `category`, `strict`, `source`, and `tags`. The skill body lists why each one is
marketplace-level. `dependencies` is NOT one of these — it's a valid plugin.json field (see the
skill body's "Metadata and dependency fields" section); claude-skills-218 removed it from this
error after confirming against upstream that plugin.json documents it directly.

```json
// Invalid
{ "name": "my-plugin", "category": "productivity" }

// Valid
{ "name": "my-plugin", "keywords": ["tool", "utility"] }
{ "name": "my-plugin", "dependencies": ["other-plugin", { "name": "secrets-vault", "version": "~2.1.0" }] }
```

### Warning — `Unrecognized field '<field>' - not a known plugin.json field`

Any top-level field that is neither a known plugin.json field nor one of the four marketplace-only
fields above produces this warning (claude-skills-219) — never a hard failure, so a manifest that
doubles as another tool's config (npm's `package.json`, a VS Code extension manifest) still passes.
Treat it as a nudge to check for a typo, not proof the field is wrong.

```json
// Warns: "Unrecognized field 'dependancies' - not a known plugin.json field ..."
{ "name": "my-plugin", "dependancies": ["other-plugin"] }
```

### Error — `dependencies entry '<name>' has a malformed version constraint: '<value>'`

The `version` field on a `dependencies` object entry (claude-skills-235) is validated as a
[node-semver range](https://code.claude.com/docs/en/plugin-dependencies), not an exact version —
upstream: "The version field accepts any expression supported by Node's semver package, including
caret, tilde, hyphen, and comparator ranges." Accepted forms: bare version (`2.1.0`), tilde
(`~2.1.0`), caret (`^2.0`), comparator (`>=1.4`, `>1.4`, `<2.0`, `<=2.0`, `=2.1.0`), x-range
wildcards, but ONLY in trailing position (`1.2.x`, `1.x`, `*` accepted; `x.1.2` and `1.x.3`
rejected — see below), hyphen ranges (`1.2.3 - 2.3.4`), and `||`-joined alternatives
(`1.2.7 || >=1.2.9 <2.0.0`). Also accepted, matching real node-semver (`semver.validRange`, verified
against the actual `semver` npm package — current published version 7.8.5, `npm view semver
version` — not just upstream's docs, claude-skills-234 Gate 3 review): whitespace between an
operator and its version (`>= 1.2.3`), a LOWERCASE `v` version prefix (`v1.2.3` — uppercase
`V1.2.3` is REJECTED; node does not case-fold this prefix), `~>` as a tilde-range alias, and an
empty or whitespace-only string as equivalent to `*` (any version). A string outside this grammar —
`not-a-semver!!!`, a bare operator with nothing attached (`>=`), an incomplete hyphen range
(`1.2.3 -`), an uppercase `V` prefix, or a non-trailing wildcard (`x.1.2`, `1.x.3`), for example —
is rejected.

```json
// Invalid
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": "not-a-semver!!!" }] }
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": ">=" }] }
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": "V1.2.3" }] }
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": "x.1.2" }] }

// Valid — upstream's own documented example
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": "~2.1.0" }] }

// Valid — accepted forms node-semver allows beyond the documented examples
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": ">= 1.2.3" }] }
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": "v1.2.3" }] }
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": "1.2.x" }] }
```

### Error — skill path missing or has no SKILL.md

Each entry in `skills` must be a directory containing `SKILL.md`. A path that resolves to a
directory without one fails.

```json
"skills": ["./skills/nonexistent"]   // fails
"skills": ["./skills/my-skill"]      // resolves, contains SKILL.md
```

### Warning — `version should use semantic versioning: <value>`

Reported as a **warning**, not an error, as is `Missing recommended field: version`.

```json
"version": "1.0"        // warned
"version": "v1.0.0"     // warned
"version": "1.0.0"      // accepted
"version": "2.1.3-beta.1"
```

### Warning — `Agent 'model' should be one of: haiku, sonnet, opus, fable, inherit, or a full model ID like claude-opus-4-8`

Checked against the agent frontmatter's `model` field for every agent `.md` file a plugin lists.
Follows `claude-agents` SKILL.md's frontmatter table (source:
https://code.claude.com/docs/en/sub-agents), which documents `model` as one of the four short
names, `inherit` (the default), or a full model ID. Full model IDs are open-ended, so anything
shaped like `claude-` followed by lowercase alphanumeric segments (`claude-opus-4-8`) is accepted
without enumerating every release. This allowlist was narrower before claude-skills-234's Gate 3
review (`haiku`/`sonnet`/`opus` only) — under `--strict`, that stale list would have turned
`fable`, `inherit`, or a full model ID into a hard CI failure for a value the repo's own
documentation says is correct.

```yaml
model: fable            # accepted
model: inherit          # accepted
model: claude-opus-4-8  # accepted — full model ID
model: gpt-4            # warned — not a documented value in any form
```

### Description and keywords agreement

Invoked with `--marketplace`, the validator compares `description` and `keywords` against the
plugin's marketplace entry when that entry's `source` is a local path. `plugin.json` is
authoritative. Entries whose `source` is a GitHub object are skipped — there is no local manifest to
compare (direct-file mode, `nu validate-plugin.nu <path-to-plugin.json>`, skips the comparison for
the same reason: no marketplace entry exists to compare against).

When plugin.json defines a field, the marketplace entry must carry it too. An entry that omits
`description` or `keywords` while plugin.json defines them is flagged as missing, not treated as
agreement:

```
marketplace.json entry is missing 'description' that plugin.json defines: '<plugin.json value>'
marketplace.json entry is missing 'keywords' that plugin.json defines: [<plugin.json values>]
```

A field plugin.json itself omits is not compared at all — only a warning fires, from the separate
"Missing recommended field" check above. When both sides define the field but the values differ:

```
description mismatch — plugin.json is authoritative: plugin.json='<a>' marketplace.json='<b>'
keywords mismatch — plugin.json is authoritative: plugin.json=[<a>] marketplace.json=[<b>]
```

`keywords` compares as a sorted list, not order-sensitively — reordering the array alone is not a
mismatch, only a genuine difference in members is.

## Reserved plugin names

`claude plugin validate` checks that a plugin name does not pass as one of Anthropic's own. The bundled `validate-plugin.nu` does not run this check. The repository task `mise run test:plugin-names` (`test/validate-plugin-names.nu`) applies the same rule offline.

The check ignores case and treats any run of separators as one. The table lists each rule.

| Name | Result |
|---|---|
| Starts with `claude-`, `anthropic-`, `anthropics-`, or `cc-plugin-` | Error |
| Equals `claude`, `anthropic`, `anthropics`, `claude-code`, or `claude-mods` | Error |
| Puts `official` beside `claude` or `anthropic`, such as `official-claude-tools` | Error |
| Has `claude`, `anthropic`, or `anthropics` as a whole word anywhere else, such as `mcp-for-claude` | Warning |

The error reads `Plugin name "<name>" is reserved: it passes as one of Anthropic's own`. The warning reads `Plugin name "<name>" reads as one of Anthropic's own`.

- **Scope of the check.** Only `claude plugin validate`, `claude plugin init`, and `claude plugin tag` check the name. `init` and `tag` refuse a name that draws the error. Claude Code still installs and loads such a plugin.
- **Marketplaces.** The check applies to the plugin name wherever it is listed. A marketplace namespace (`plugin@marketplace`) does not exempt a name, so a name that collides with a reserved name is rejected under any marketplace. Verified 2026-10-05 on Claude Code 2.1.289: a marketplace entry named `mcp-for-claude` drew the warning, and a plugin.json named `claude-code` drew the error.
- **Version boundary.** The check began failing in Claude Code 2.1.287. Versions 2.1.286 and earlier passed such names. This boundary was reported by the maintainer on 2026-10-05; the docs page and the changelog do not state it. Validate on a current release.
- **Fix.** Rename the plugin to say what it does (`claude-code` became `extras-cc` in this repository). Then follow the `renames` procedure in `plugin-marketplace` so installed users migrate.

Source: https://code.claude.com/docs/en/plugins/manifest-reference (section `name`), accessed 2026-10-05.

## Runtime troubleshooting

No script detects these — they are install-time and load-time failures.

**Plugin not loading.** Confirm `plugin.json` sits at `.claude-plugin/plugin.json`, its JSON parses,
and `name` is present and kebab-case.

**Skills not found.** Skill paths must match real directories, each containing `SKILL.md`, expressed
relative to the plugin root (`./skills/name`).

**Commands not appearing.** Command paths must exist and be `.md` files, or directories containing
`.md` files, relative to the plugin root.
