# Marketplace Validation Errors and Troubleshooting

> Reference file for the `plugin-marketplace` skill. Run the validator first — it names the
> offending field and value precisely. This page explains what each message means and covers the
> runtime failures no script can detect.

## Table of Contents

- [What the validator reports](#what-the-validator-reports)
- [Migrating existing plugins to a marketplace](#migrating-existing-plugins-to-a-marketplace)
- [Renaming or removing a plugin](#renaming-or-removing-a-plugin)
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

## Renaming or removing a plugin

A plugin's `name` is its identifier. Users reference it in `/plugin install`, in `enabledPlugins`, and in `pluginConfigs`. Changing it breaks every existing install unless the marketplace carries a `renames` map. Keep `name` stable, and set `displayName` in plugin.json to change only the label users see.

Add a top-level `renames` map to `marketplace.json`. Map each former name to its current name, or to `null` when the plugin is gone.

```json
{
  "renames": {
    "formatter": "code-formatter",
    "legacy-linter": null
  }
}
```

- **Renamed entry.** The plugin loads under the new name, and Claude Code rewrites the old key in `enabledPlugins` and `pluginConfigs`.
- **`null` entry.** Claude Code drops the old key and tells the user the plugin was removed.
- **Append-only.** Keep old entries after everyone migrates. Add a second entry for a second rename, because Claude Code follows the chain from the oldest name.
- **Validation.** `claude plugin validate .` rejects a chain that cycles or ends anywhere except `null` or a name in `plugins`: `renames.<name>: chain does not resolve`. Verified 2026-10-05 on Claude Code 2.1.289 with a target that is not in `plugins`.
- **Managed settings.** Claude Code cannot rewrite managed settings. The rename notice recurs until an administrator updates `enabledPlugins` there.
- **Git or URL marketplaces.** A user runs `/plugin install <new-name>@<marketplace>` once after a rename.

Rename a plugin for a reserved name with this procedure. See `claude-plugins` ("Reserved names") for the rule.

Source: https://code.claude.com/docs/en/plugins/host-marketplace (section "Migrate users with a renames map"), accessed 2026-10-05.

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
