# Test Suite

Validation scripts for the claude-skills marketplace and plugins.

## Usage

### Run All Tests

Validates marketplace.json and all plugin.json files:

```bash
mise run ci
# or
mise test
# or
mise test:all
```

`mise run ci` is the canonical CI gate (matches the workspace-wide convention);
it depends on `test`, which runs every validation below.

This runs both `test:marketplace` and `test:plugins` in parallel.

### Test Marketplace Only

Validates only marketplace.json:

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

### Direct Script Usage

You can also run the Nushell scripts directly:

```bash
# All tests
nu test/validate-all.nu

# Specific plugin
nu test/validate-plugin.nu elixir
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

### Skill Quality Gate (ratchet baseline)

`mise test:skills-quality` runs 17 static checks per skill (description triggers,
name/directory match, 500-line cap, reference depth, link integrity, orphan
reference/agent files, cross-skill invocation resolution, version pins vs
sources.md, anti-fabrication presence, no `allowed-tools`, and more) and
enforces them against `test/quality-baseline.json`:

- A failing check **not** in the baseline fails the run — new violations cannot land.
- A baseline entry that now **passes** fails the run until the entry is removed —
  the baseline only shrinks (ratchet).

Baseline entries are `plugin/skill:check` strings. When you fix a baselined
violation, regenerate the baseline (and review the diff — it must only remove
entries):

```bash
nu test/validate-skills-quality.nu --update-baseline
```

Do not add baseline entries to make new violations pass; fix the skill instead.

## Scripts

- **validate-all.nu** - Runs all validations (marketplace + all plugins)
- **validate-plugin.nu** - Validates a specific plugin
- **validate-skills-quality.nu** - Skill quality scorecard with ratchet baseline enforcement

## Exit Codes

- `0` - All validations passed
- `1` - Validation failed

## Integration

These tests are integrated with mise via `mise.toml`:

```toml
[tools]
nushell = "latest"

[tasks.test]
alias = "test:all"

[tasks."test:all"]
depends = ["test:marketplace", "test:plugins"]

[tasks."test:marketplace"]
# Validates marketplace.json

[tasks."test:plugins"]
# Validates all plugin.json files

[tasks."test:plugin"]
# Validates a specific plugin
```

### Task Hierarchy

```
test (alias for test:all)
├── test:all
│   ├── test:marketplace  (validates marketplace.json)
│   └── test:plugins      (validates all plugin.json files)
└── test:plugin <name>    (validates specific plugin)
```

## Example Output

```
🧪 Running all validation tests...

📦 Validating marketplace.json...

🔍 Validating plugin: claude-code...
🔍 Validating plugin: core...
🔍 Validating plugin: elixir...
🔍 Validating plugin: rust...

============================================================
📊 Test Summary
============================================================
✅ marketplace.json
✅ plugin: claude-code
✅ plugin: core
✅ plugin: elixir
✅ plugin: rust

✨ All validations passed!
```
