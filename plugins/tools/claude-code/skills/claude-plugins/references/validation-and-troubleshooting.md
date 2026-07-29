# plugin.json Validation Errors and Troubleshooting

> Reference file for the `claude-plugins` skill. Run the validator first — it names the offending
> field and value precisely. This page explains what each message means and covers the runtime
> failures no script can detect.

## Table of Contents

- [What the validator reports](#what-the-validator-reports)
- [Runtime troubleshooting](#runtime-troubleshooting)

## What the validator reports

`nu <CLAUDE_SKILL_DIR>/scripts/validate-plugin.nu .claude-plugin/plugin.json` emits these. Errors
fail validation; warnings do not.

### Error — `Invalid name format: '<name>' (must be kebab-case)`

Lowercase alphanumeric and hyphens only, matching `^[a-z0-9]+(-[a-z0-9]+)*$`. The same rule and the same
message apply to marketplace names, via the `plugin-marketplace` skill.

### Error — `Invalid field '<field>' - this belongs in marketplace.json, not plugin.json`

Raised for `dependencies`, `category`, `strict`, `source`, and `tags`. The skill body lists why each
one is marketplace-level.

```json
// Invalid
{ "name": "my-plugin", "dependencies": ["other-plugin"] }

// Valid
{ "name": "my-plugin", "keywords": ["tool", "utility"] }
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
compare. A field absent from either side is not a mismatch.

## Runtime troubleshooting

No script detects these — they are install-time and load-time failures.

**Plugin not loading.** Confirm `plugin.json` sits at `.claude-plugin/plugin.json`, its JSON parses,
and `name` is present and kebab-case.

**Skills not found.** Skill paths must match real directories, each containing `SKILL.md`, expressed
relative to the plugin root (`./skills/name`).

**Commands not appearing.** Command paths must exist and be `.md` files, or directories containing
`.md` files, relative to the plugin root.
