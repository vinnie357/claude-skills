---
name: plugin-marketplace
description: Guide for creating and managing Claude Code plugin marketplaces. Use when setting up a marketplace, validating marketplace.json, or distributing plugins.
license: MIT
---

# Claude Code Plugin Marketplace

Guide for creating, validating, and managing plugin marketplaces for Claude Code.

Per `core:anti-fabrication`: verify schema fields and source paths with the validation scripts before claiming an entry is valid — never assert validation results without running them. The validator names the offending field and value; that output is the authority, not this page.

## Marketplace schema

A marketplace lives at `.claude-plugin/marketplace.json` in the repository root.

**Required:** `name` (kebab-case), `owner` (object; `name` required, `email` optional), `plugins` (array, may be empty).

**Optional `metadata`:** `description`, `version`, and `pluginRoot` — a base directory that relative plugin `source` paths resolve against.

### Plugin entry schema

Plugin entries use the **plugin manifest schema with every field optional**, plus the marketplace-only fields `source`, `strict`, `category`, and `tags`. Any field valid in a `plugin.json` is therefore valid in an entry — see `/claude-code:claude-plugins` for the manifest schema and for which fields must never appear in a `plugin.json`.

Each entry requires `name` (kebab-case) and `source`. Beyond those:

- **Metadata:** `description`, `version`, `author`, `homepage`, `repository`, `license` (SPDX), `keywords`, `category`, `tags`
- **Component paths:** `commands`, `agents`, `hooks`, `mcpServers`, `skills`
- **Dependencies:** `dependencies`, an array of `"namespace:plugin-name"` strings

### Strict mode

`strict` defaults to `true`.

- `true` — the plugin must ship its own `plugin.json`; marketplace fields supplement it.
- `false` — the marketplace entry *is* the complete manifest; no `plugin.json` needed.

**Choose `strict: false`** for simple self-contained plugins whose configuration all lives in marketplace.json, when centralized management is the goal and the plugin is unlikely to be distributed independently.

**Choose `strict: true`** when the plugin has complex configuration, may be distributed separately, has its own versioning lifecycle, or when the marketplace is only adding metadata to a manifest that already exists.

This is the one genuine judgment call in a marketplace entry; everything else is schema.

## Source formats

```json
"source": "./plugins/my-plugin"
```

With `"metadata": { "pluginRoot": "./plugins" }`, a bare `"source": "my-plugin"` resolves to `./plugins/my-plugin`.

```json
"source": { "source": "github", "repo": "owner/plugin-repo", "path": "optional/subdir", "branch": "main" }
"source": { "source": "url", "url": "https://gitlab.com/team/plugin.git", "branch": "main" }
```

## Path variables — a load-time trap

Two different variables, and mixing them up breaks the file:

- **`CLAUDE_PLUGIN_ROOT`** resolves to the plugin's installation directory. Use it as a brace expansion inside `skills`/`commands`/`agents`/`hooks`/`mcpServers` **values in marketplace.json and plugin.json**, so paths survive relocation.
- **`CLAUDE_SKILL_DIR`** resolves to an individual skill's directory — *not* the plugin root. Bundled scripts live under it.

Both names are written bare on this page on purpose. **The braced form expands when a skill loads**, so a braced variable inside a skill body is replaced with one machine's absolute path before any reader sees it. That is correct behavior for a JSON config value the harness expands at runtime, and wrong for a command written in a skill body. Copyable braced examples live in `references/marketplace-examples.md`, where `Read` returns raw bytes.

## Advanced entries

- **Inline definitions** — `strict: false` with a full manifest in the entry. See `references/marketplace-examples.md` ("Inline Plugin Definitions").
- **Component path override** — point `commands`/`agents`/`hooks`/`mcpServers` at custom locations. Same reference ("Component Path Override").
- **Metadata supplementation** — with `strict: true`, add `category`, `keywords`, or `homepage` that the plugin's own manifest omits:

```json
{
  "name": "existing-plugin",
  "source": "./plugins/existing",
  "strict": true,
  "category": "development",
  "keywords": ["added", "from", "marketplace"]
}
```

## Validation

Scripts are bundled with this skill, under its own directory:

```bash
nu <CLAUDE_SKILL_DIR>/scripts/validate-marketplace.nu .claude-plugin/marketplace.json
nu <CLAUDE_SKILL_DIR>/scripts/validate-dependencies.nu .claude-plugin/marketplace.json
```

`validate-marketplace.nu` checks JSON syntax, required fields, kebab-case naming, field types, and relative-source accessibility. `validate-dependencies.nu` checks the dependency graph for cycles and missing entries. Add `--verbose` for per-field output.

Read the script's message rather than guessing: it names the field and the value. What each message means, plus the install-time and load-time failures no script detects, is in `references/validation-and-troubleshooting.md`.

## Creating a marketplace

1. `mkdir -p .claude-plugin`, then generate a skeleton with `nu <CLAUDE_SKILL_DIR>/scripts/init-marketplace.nu`.
2. Add an entry per plugin, deciding strict mode for each. A complete entry with a `CLAUDE_PLUGIN_ROOT` skills path is in `references/marketplace-examples.md` ("Creating a marketplace — Step 3").
3. Validate, then install from it: `/plugin marketplace add <owner>/<repo>` followed by `/plugin install <plugin-name>@<marketplace-name>`.

Converting an existing set of plugins into a marketplace is a different procedure — see `references/validation-and-troubleshooting.md` ("Migrating existing plugins").

## Conventions

- **Marketplace name** — a GitHub username or organization.
- **Plugin names** — descriptive kebab-case (`elixir-phoenix`, `rust-tools`).
- **Categories** — standardize across the marketplace rather than inventing per entry: `development`, `language`, `tools`, `frontend`, `backend`, `meta`.
- **Versions** — semver for both marketplace and plugins. Bump the marketplace when adding or removing a plugin, a plugin when its skills or configuration change, and note breaking changes in the plugin's description. **Keep a plugin's version in step between its `plugin.json` and its marketplace entry.** The bundled validator does not check this — it validates semver format only. Enforce agreement in the marketplace repository's CI.
- **Dependencies** — declare them, keep chains shallow, prefix with the namespace, and consider a meta-plugin that bundles a related set.

## Scripts

Bundled in this skill's `scripts/` directory, run as `nu <CLAUDE_SKILL_DIR>/scripts/<name>.nu [args]`:

| Script | Purpose |
|---|---|
| `validate-marketplace.nu` | Full marketplace validation |
| `validate-dependencies.nu` | Dependency graph validation |
| `init-marketplace.nu` | Generate a marketplace template |
| `analyze-plugins.nu` | Analyze an existing plugin structure |
| `format-marketplace.nu` | Format and sort marketplace.json |

## References

- `references/schema-specification.md` — the complete JSON schema
- `references/marketplace-examples.md` — copyable `CLAUDE_PLUGIN_ROOT` path examples for skills, commands, agents, hooks, and mcpServers entries
- `references/validation-and-troubleshooting.md` — what each validator message means, migration procedure, and runtime failures
