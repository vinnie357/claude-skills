# plugin.json Validation Errors and Troubleshooting

> Reference file for the `claude-plugins` skill. Run the validator first — it names the offending
> field and value precisely. This page explains what each message means and covers the runtime
> failures no script can detect.

## Table of Contents

- [What the validator reports](#what-the-validator-reports)
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
wildcards (`1.2.x`, `1.x`, `*`), hyphen ranges (`1.2.3 - 2.3.4`), and `||`-joined alternatives
(`1.2.7 || >=1.2.9 <2.0.0`). A string outside this grammar — `not-a-semver!!!`, for example — is
rejected.

```json
// Invalid
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": "not-a-semver!!!" }] }

// Valid — upstream's own documented example
{ "name": "my-plugin", "dependencies": [{ "name": "secrets-vault", "version": "~2.1.0" }] }
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

## Runtime troubleshooting

No script detects these — they are install-time and load-time failures.

**Plugin not loading.** Confirm `plugin.json` sits at `.claude-plugin/plugin.json`, its JSON parses,
and `name` is present and kebab-case.

**Skills not found.** Skill paths must match real directories, each containing `SKILL.md`, expressed
relative to the plugin root (`./skills/name`).

**Commands not appearing.** Command paths must exist and be `.md` files, or directories containing
`.md` files, relative to the plugin root.
