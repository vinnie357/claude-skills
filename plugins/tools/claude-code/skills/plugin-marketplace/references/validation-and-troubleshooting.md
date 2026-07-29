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

### Error — invalid kebab-case name

Lowercase alphanumeric and hyphens only. The two levels emit **different messages**: the
marketplace-level `name` fails as `Invalid name format: '<name>' (must be kebab-case)`, while a
plugin entry's `name` fails as `Invalid plugin name: '<name>' (must be kebab-case)`.

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

A local `source` that does not resolve is appended to the warning list rather than the error list,
so it does not fail validation. The script records no reason for that choice; treat it as
non-fatal-by-design and check the path yourself. Resolution is against the **marketplace root** —
the directory containing `.claude-plugin/`, not `.claude-plugin/` itself.

```json
"source": "./plugins/nonexistent"   // warned
"source": "./plugins/core"          // resolves
```

`metadata.pluginRoot` sets a base for **bare** sources: with `"pluginRoot": "./plugins"`, a `source`
of `"core"` resolves to `./plugins/core`. A source already written `"./..."` is used as-is and is not
prefixed with `pluginRoot`. Without `pluginRoot` there is no base to resolve against, so a bare
source is an error — `local source must start with './' when metadata.pluginRoot is not set`. An
empty source is always an error.

**Upstream is self-contradictory here, and this validator picks a side.** The marketplace reference
documents `pluginRoot` as letting you write `"source": "formatter"` instead of
`"source": "./plugins/formatter"`, while its source-type table states a relative path "Must start
with `./`". This script follows the `pluginRoot` example, because that example is the specific case.
Two things therefore remain unverified against the actual Claude Code loader: whether it accepts a
bare source at all, and whether it prefixes `pluginRoot` onto `./`-relative sources too — upstream
says "prepended to relative plugin source paths", which read literally would include them. If a
marketplace using bare sources fails at install time, that is the ambiguity, not this check.

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
