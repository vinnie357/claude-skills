# Test Suite

Validation scripts for the claude-skills marketplace and plugins.

## Usage

### Run All Tests

Validates marketplace.json and all plugin.json files:

```bash
mise test
# or
mise test:all
```

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

## Scripts

- **validate-all.nu** - Runs all validations (marketplace + all plugins)
- **validate-plugin.nu** - Validates a specific plugin

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
