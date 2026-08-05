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
- `commands` — string or array of `.md` files or directories, replacing the default `commands/` scan (see `claude-commands`)
- `agents` — string or array of files, replacing the default `agents/` scan (see `claude-agents`)
- `workflows` — string or array of workflow script files or directories, replacing the default `workflows/` scan
- `hooks` — string path to a hooks.json, or an inline hooks object (see `claude-hooks`)
- `mcpServers` — string path to an MCP config, or an inline object
- `outputStyles` — string or array of output-style files/directories, replacing the default `output-styles/` scan (see `claude-output-styles`)
- `lspServers` — string, array, or inline object of LSP (Language Server Protocol) configs for code intelligence (go-to-definition, find-references). Defaults to a `.lsp.json` file at the plugin root when the field is absent.

`output-styles/` is discovered by convention when `outputStyles` is unset; setting the field replaces that default scan rather than adding to it (see `claude-output-styles`).

### Metadata and dependency fields

- `displayName` — human-readable name shown in the `/plugin` picker and other UI surfaces. Falls back to `name` when omitted. Unlike `name`, may contain spaces and any casing; not used for namespacing or lookup.
- `defaultEnabled` — boolean, whether the plugin starts enabled when the user has not set a preference. Defaults to `true`. Set `false` to ship a plugin that installs disabled (e.g. one that adds cost or connects to an external service) until the user opts in with `claude plugin enable <plugin>`.
- `userConfig` — object declaring values Claude Code prompts the user for at enable time (`type`, `title`, `description` required per key; `sensitive`, `required`, `default`, `multiple`, `min`/`max` optional). Substituted as `${user_config.KEY}` in MCP/LSP configs and hook commands.
- `channels` — array of message-channel declarations (Telegram/Slack/Discord-style injection). Each entry's `server` field must match a key in the plugin's `mcpServers`.
- `dependencies` — array of other plugins this plugin requires. Each entry is either a bare plugin-name string, or an object with a required `name` and optional semver `version` constraint:

```json
{
  "dependencies": [
    "helper-lib",
    { "name": "secrets-vault", "version": "~2.1.0" }
  ]
}
```

This is a **plugin.json field**, not a marketplace-only one — do not confuse it with `category`/`strict`/`source`/`tags` below, which upstream documents as marketplace-entry-specific and which this manifest schema does not include. (`dependencies` may also be echoed inside a marketplace entry, since a marketplace entry can carry any field from the plugin manifest schema — but its home is plugin.json.)

The `version` field is a **range**, not an exact version — upstream (see [Constrain plugin dependency versions](https://code.claude.com/docs/en/plugin-dependencies)): "The version field accepts any expression supported by Node's semver package, including caret, tilde, hyphen, and comparator ranges." Documented examples: `~2.1.0` (tilde), `^2.0` (caret, partial), `>=1.4` (comparator, partial), `=2.1.0` (exact pin), `1.2.3 - 2.3.4` (hyphen range), and `||`-joined alternatives (e.g. `1.2.7 || >=1.2.9 <2.0.0`). `validate-plugin.nu` validates `version` against this range grammar, not the exact-version grammar used elsewhere in this manifest (`plugin.json`'s own top-level `version` field) — a range string like `~2.1.0` is correctly REJECTED by an exact-version check and correctly ACCEPTED by the range check the validator applies here.

The check also accepts every additional form node's own `semver.validRange` accepts (verified against the actual `semver` npm package, current published version 7.8.5 — `npm view semver version`), not just the documented examples verbatim: whitespace between an operator and its version (`>= 1.2.3`), a LOWERCASE `v` prefix only (`v1.2.3` — uppercase `V1.2.3` is REJECTED, node does not case-fold it), `~>` as a tilde-range alias, and an empty or whitespace-only string as equivalent to `*` (any version). An x-range wildcard (`x`/`X`/`*`) is valid only in TRAILING position (`1.2.x` accepted, `x.1.2` and `1.x.3` rejected) — enforced structurally, not just by regex. See the comment above `is-version-partial` in `scripts/validate-plugin.nu` for the full list of these decisions and why each one is deliberate rather than accidental.

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

Verified against `validate-plugin.nu`'s `invalid_fields` denylist (`category`, `strict`, `source`, `tags`): none of `outputStyles`/`lspServers`/`experimental`, nor `dependencies`/`displayName`/`defaultEnabled`/`workflows`/`userConfig`/`channels`, are on it. The `complete_manifest_all_documented_fields_recognized` case in `scripts/validate-plugin.nu`'s `--self-test` suite carries all nine fields in one fixture manifest and asserts it passes with zero errors and zero warnings (`nu <CLAUDE_SKILL_DIR>/scripts/validate-plugin.nu --self-test`).

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

The validator rejects these with `Invalid field '<field>' - this belongs in marketplace.json, not plugin.json`. Upstream's marketplace-entries schema documents them as marketplace-specific fields, distinct from the plugin manifest schema (see `plugin-marketplace`):

- `category` — marketplace-level metadata
- `strict` — controls marketplace behavior, not the plugin definition
- `source` — a plugin's location is declared by the marketplace, not by itself
- `tags` — use `keywords`

`dependencies` is NOT on this list — see "Metadata and dependency fields" above. It is a documented plugin.json field, not marketplace-only.

### Unrecognized fields warn, not fail

Any other top-level field the validator doesn't recognize produces a **warning** (`Unrecognized field '<field>' - not a known plugin.json field`), never a hard failure — matching upstream's own `claude plugin validate`, which treats unrecognized fields as warnings so a manifest can double as another tool's config (an npm `package.json`, a VS Code extension manifest) without breaking. A typo'd field name is now visible instead of silently passing.

Pass `--strict` to promote those warnings to a failing result, mirroring upstream's own `claude plugin validate --strict` ("Pass `--strict` to treat warnings as errors. Use it in CI to catch a misspelled field name or a field left over from another tool's manifest before publishing, even though the plugin would load at runtime."). `mise run test:plugins` runs every local plugin with `--strict` — all 30 are warning-free as of this change, so a new warning now fails CI instead of only logging. `--strict` never invents new warnings; a manifest with zero warnings passes identically with or without the flag.

## Validation

Scripts are bundled with this skill, under its own directory:

```bash
nu <CLAUDE_SKILL_DIR>/scripts/validate-plugin.nu .claude-plugin/plugin.json
nu <CLAUDE_SKILL_DIR>/scripts/validate-plugin.nu .claude-plugin/plugin.json --strict
nu <CLAUDE_SKILL_DIR>/scripts/init-plugin.nu
nu <CLAUDE_SKILL_DIR>/scripts/validate-plugin.nu --self-test   # fixture suite for the validator itself
```

`validate-plugin.nu` checks JSON syntax (rejecting both unparseable content and valid-but-non-object JSON, such as a bare scalar or array — claude-skills-243), `name` presence and casing, field types, path accessibility, `dependencies` shape and version-range syntax, and invalid-field detection, plus a warn-on-unrecognized-field pass (promoted to a failure under `--strict`). Add `--verbose` for per-field output.

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
