---
name: claude-plugins
description: Guide for creating and validating Claude Code plugin.json files. Use when creating plugins, validating plugin schemas, or troubleshooting plugin configuration.
license: MIT
---

# Claude Code Plugin

Guide for creating, validating, and managing `plugin.json` manifests for Claude Code plugins.

Per `core:anti-fabrication`: run the validation scripts and read the manifest before claiming a plugin.json is valid or that a component path exists. The validator names the offending field and value; that output is the authority, not this page.

## Manifest schema

A manifest lives at `.claude-plugin/plugin.json` inside the plugin directory.

```json
{
  "name": "plugin-name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": { "name": "Author Name", "email": "author@example.com", "url": "https://github.com/author" },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "commands": ["./custom/commands/special.md"],
  "agents": "./custom/agents/",
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "skills": ["./skills/skill-one", "./skills/skill-two"]
}
```

**`name` is the only required field.** Everything else is optional, though `version`, `description`, `license`, `keywords`, `repository`, and `author` are worth setting: they are what a user sees before installing, and `author` is how they reach you with a bug report or a contribution.

### Field rules

| Field | Rule |
|---|---|
| `name` | kebab-case, `^[a-z0-9]+(-[a-z0-9]+)*$`. Match the directory name, and be specific rather than generic. Valid: `my-plugin`, `core-skills`. Invalid: `myPlugin`, `my_plugin`, `My-Plugin`, `plugin-` |
| `version` | semver, `^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$`. Valid: `1.0.0`, `1.0.0-beta.1`, `1.0.0+build.123`. Invalid: `1.0`, `v1.0.0`, `1.0.0.0` |
| `license` | SPDX identifier — `MIT`, `Apache-2.0`, `GPL-3.0`, `BSD-3-Clause`, `ISC`. See https://spdx.org/licenses/ |
| `keywords` | array of lowercase, specific, domain-bearing strings |

### Component paths

Relative to the plugin root, `./`-prefixed. Each has a dedicated skill for its own file format:

- `skills` — array of directories, each containing a `SKILL.md` (see `claude-skills`)
- `commands` — string or array of `.md` files or directories (see `claude-commands`)
- `agents` — string directory or array of files (see `claude-agents`)
- `hooks` — string path to a hooks.json, or an inline hooks object (see `claude-hooks`)
- `mcpServers` — string path to an MCP config, or an inline object
- `outputStyles` — string or array of output-style files/directories, replacing the default `output-styles/` scan (see `claude-output-styles`)
- `lspServers` — string, array, or inline object of LSP (Language Server Protocol) configs for code intelligence (go-to-definition, find-references). Defaults to a `.lsp.json` file at the plugin root when the field is absent.

`output-styles/` is discovered by convention when `outputStyles` is unset; setting the field replaces that default scan rather than adding to it (see `claude-output-styles`).

### `experimental` field

`experimental` is an object holding components whose manifest schema may still change between releases: `experimental.themes` (string or array — color theme files/directories, replacing the default `themes/` scan) and `experimental.monitors` (string or array — background monitor configs that start automatically while the plugin is active, replacing the default `monitors/monitors.json`). Both keys also work unnested at the top level (`"themes": ...`, `"monitors": ...`) today, but `claude plugin validate` already warns on the unnested form, and a future release will require nesting under `experimental` — use the nested form for new plugins rather than relying on the still-working top-level fallback.

```json
{
  "outputStyles": "./styles/",
  "lspServers": "./.lsp.json",
  "experimental": {
    "themes": "./themes/",
    "monitors": "./monitors.json"
  }
}
```

Verified against `validate-plugin.nu`'s fixed `invalid_fields` denylist (`dependencies`, `category`, `strict`, `source`, `tags`): none of these three fields are on it, and a fixture plugin.json carrying all three passes validation with zero errors and zero warnings.

Both `hooks` and `mcpServers` accept either a path or an inline object. Inline, they use each component's own schema — hooks are **event-keyed**, not lifecycle-keyed:

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "<CLAUDE_PLUGIN_ROOT>/scripts/format.sh" }] }
    ]
  },
  "mcpServers": { "filesystem": { "command": "mcp-server-filesystem", "args": ["./workspace"] } }
}
```

`CLAUDE_PLUGIN_ROOT` is written in angle brackets above, but a real hooks value wraps it as a **quoted brace expansion** — the harness expands it at hook runtime, which is correct in a JSON config. It is shown angle-bracketed here, not braced, because the braced form expands when *this skill* loads, replacing it with one machine's absolute path before any reader sees it — the same reason script commands on this page use `<CLAUDE_SKILL_DIR>` angle-bracketed rather than braced (see `/claude-code:claude-skills` "Dynamic context and substitutions" for the full notation convention). For the copyable braced form, see `/claude-code:claude-hooks`, whose reference files are read as raw bytes and can carry it safely.

## Fields that must NOT appear in plugin.json

The validator rejects these with `Invalid field '<field>' - this belongs in marketplace.json, not plugin.json`:

- `dependencies` — dependencies belong to marketplace entries, not manifests
- `category` — marketplace-level metadata
- `strict` — controls marketplace behavior, not the plugin definition
- `source` — a plugin's location is declared by the marketplace, not by itself
- `tags` — use `keywords`

## Validation

Scripts are bundled with this skill, under its own directory:

```bash
nu <CLAUDE_SKILL_DIR>/scripts/validate-plugin.nu .claude-plugin/plugin.json
nu <CLAUDE_SKILL_DIR>/scripts/init-plugin.nu
```

`validate-plugin.nu` checks JSON syntax, `name` presence and casing, field types, path accessibility, and invalid-field detection. Add `--verbose` for per-field output.

With `--marketplace`, it also checks that `description` and `keywords` agree with the plugin's marketplace entry, when that entry's `source` is a local path. **`plugin.json` is authoritative.** Entries whose `source` is a GitHub object are skipped — there is no local manifest to compare. When plugin.json defines a field, the marketplace entry must carry it too: an entry that omits `description` or `keywords` while plugin.json defines them is flagged as missing, not treated as agreement (`marketplace.json entry is missing '<field>' that plugin.json defines`). A field plugin.json itself omits is not compared at all. `keywords` compares as a sorted list, so reordering the array alone is not a mismatch — only a genuine difference in members is.

What each message means, and the install-time failures no script detects, is in `references/validation-and-troubleshooting.md`.

## Creating a plugin

1. `mkdir -p my-plugin/.claude-plugin my-plugin/skills`
2. From the plugin directory, run `nu <CLAUDE_SKILL_DIR>/scripts/init-plugin.nu` — or write the manifest by hand with `name`, `version`, `description`, `author`, `license`, `keywords`, and an empty `skills` array.
3. Add each skill as a directory containing `SKILL.md`, and list its path in `skills`.
4. Validate, then install through a marketplace that lists the plugin (see `plugin-marketplace`): `/plugin install <plugin-name>@<marketplace-name>`.

**Recommended layout:**

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── skill-one/
│   └── skill-two/
├── commands/
├── agents/
└── output-styles/
```

## Versioning

Semver, with the usual major/minor/patch split and pre-release tags such as `1.0.0-beta.1` for betas. **Keep a plugin's version in step between its `plugin.json` and its marketplace entry** — a mismatch is what breaks update detection for installed users. The bundled validator does NOT check this; it only checks semver format. Cross-manifest version agreement is enforced by a marketplace's own CI, if at all.

## Scripts

Bundled in this skill's `scripts/` directory, run as `nu <CLAUDE_SKILL_DIR>/scripts/<name>.nu [args]`:

| Script | Purpose |
|---|---|
| `validate-plugin.nu` | Complete plugin.json validation |
| `init-plugin.nu` | Generate a plugin.json template |
| `format-plugin.nu` | Format and sort plugin.json |

## References

- `references/plugin-schema.md` — the complete JSON schema specification
- `references/validation-and-troubleshooting.md` — what each validator message means, and runtime failures no script reports
