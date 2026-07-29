# Marketplace Validation Errors and Troubleshooting

> Reference file for the `plugin-marketplace` skill. Run the validator first — it names the
> offending field and value precisely. This page explains what each message means and covers the
> runtime failures no script can detect.

## Table of Contents

- [What the validator reports](#what-the-validator-reports)
- [Migrating existing plugins to a marketplace](#migrating-existing-plugins-to-a-marketplace)
- [Runtime troubleshooting](#runtime-troubleshooting)

## What the validator reports

`nu <CLAUDE_SKILL_DIR>/scripts/validate-marketplace.nu .claude-plugin/marketplace.json` emits these.
Errors fail validation; warnings do not.

### Error — `Invalid name format: '<name>' (must be kebab-case)`

Lowercase alphanumeric and hyphens only. Applies to the marketplace `name` and every plugin `name`.

```json
// Invalid
"name": "myPlugin"
"name": "my_plugin"
"name": "My-Plugin"

// Valid
"name": "my-plugin"
"name": "core-skills"
```

### Error — `Missing required field: 'owner'` / `'owner.name'`

`owner` is an object and `owner.name` is mandatory; `owner.email` is optional.

```json
// Invalid — no owner
{ "name": "marketplace" }

// Valid
{ "name": "marketplace", "owner": { "name": "Developer Name" } }
```

### Error — circular dependencies

`validate-dependencies.nu` reports the cycle as a path, e.g. `plugin-a -> plugin-b -> plugin-a`.

```json
{
  "plugins": [
    { "name": "plugin-a", "dependencies": ["namespace:plugin-b"] },
    { "name": "plugin-b", "dependencies": ["namespace:plugin-a"] }
  ]
}
```

### Warning — source path not found

A relative `source` that does not resolve is reported as a **warning**, not an error, because the
path may exist only on the machine that installs the plugin.

```json
"source": "./plugins/nonexistent"   // warned
"source": "./plugins/core"          // resolves
```

Resolution depends on `metadata.pluginRoot` when set: with `"pluginRoot": "./plugins"`, a `source`
of `"core"` resolves to `./plugins/core`.

## Migrating existing plugins to a marketplace

1. **Identify plugins** — list every `plugin.json` in the repository.
2. **Decide strict mode per plugin** — see the Strict Mode Decision guidance in the skill body.
3. **Create marketplace.json** with an entry per plugin.
4. **Test each plugin** installs correctly.
5. **Declare dependencies** where one plugin requires another.

`nu <CLAUDE_SKILL_DIR>/scripts/analyze-plugins.nu .` scans for `plugin.json` files and suggests a
marketplace.json structure to start from.

## Runtime troubleshooting

No script detects these — they are install-time and load-time failures.

**Plugin not found after installation.** Check the `source` path, and `metadata.pluginRoot` if the
source is relative. Confirm the plugin directory exists at the resolved location.

**Skills not loading.** Confirm each skill directory contains a `SKILL.md`, and that skill paths in
the entry (or in the plugin's own `plugin.json`) point at directories that exist. Paths that must
survive relocation use `CLAUDE_PLUGIN_ROOT` as a brace expansion; the skill body names where the
copyable form lives.

**Dependency resolution fails.** Dependency names must match exactly, including the namespace
prefix, and every dependency must itself be listed in the marketplace.
