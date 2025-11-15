# Plugin Marketplace Schema Specification

Complete JSON schema for Claude Code plugin marketplaces.

## Marketplace Schema

```json
{
  "name": "string (required, kebab-case)",
  "owner": {
    "name": "string (required)",
    "email": "string (optional)"
  },
  "metadata": {
    "description": "string (optional)",
    "version": "string (optional, semver recommended)",
    "pluginRoot": "string (optional, relative path)"
  },
  "plugins": [
    // Plugin entry array (required, can be empty)
  ]
}
```

## Plugin Entry Schema

```json
{
  "name": "string (required, kebab-case)",
  "source": "string | object (required)",
  "strict": "boolean (optional, default: true)",
  "description": "string (optional)",
  "version": "string (optional, semver recommended)",
  "author": {
    "name": "string (optional)",
    "email": "string (optional)"
  },
  "homepage": "string (optional, URL)",
  "repository": "string (optional, URL)",
  "license": "string (optional, SPDX identifier)",
  "keywords": ["array of strings (optional)"],
  "category": "string (optional)",
  "tags": ["array of strings (optional)"],
  "dependencies": ["array of strings (optional, format: namespace:plugin-name)"],
  "skills": ["array of strings (optional, paths)"],
  "commands": "string | array (optional, paths)",
  "agents": "string | array (optional, paths)",
  "hooks": "string | object (optional, paths or config)",
  "mcpServers": "string | object (optional, path or config)"
}
```

## Source Field Formats

### Relative Path (String)
```json
"source": "./plugins/my-plugin"
```

### GitHub Repository (Object)
```json
"source": {
  "source": "github",
  "repo": "owner/repository",
  "path": "optional/subdirectory",
  "branch": "main"
}
```

### Git URL (Object)
```json
"source": {
  "source": "url",
  "url": "https://gitlab.com/team/plugin.git",
  "branch": "main"
}
```

## Field Validation Rules

### name
- **Format**: kebab-case (lowercase alphanumeric and hyphens only)
- **Pattern**: `^[a-z0-9]+(-[a-z0-9]+)*$`
- **Examples**:
  - Valid: `my-plugin`, `core-skills`, `elixir-tools`
  - Invalid: `myPlugin`, `my_plugin`, `My-Plugin`, `plugin-`

### version
- **Format**: Semantic versioning recommended
- **Pattern**: `^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$`
- **Examples**:
  - Valid: `1.0.0`, `2.1.3`, `1.0.0-beta.1`, `1.0.0+build.123`
  - Invalid: `1.0`, `v1.0.0`, `1.0.0.0`

### license
- **Format**: SPDX license identifier
- **Common values**: `MIT`, `Apache-2.0`, `GPL-3.0`, `BSD-3-Clause`, `ISC`
- **Reference**: https://spdx.org/licenses/

### category
- **Recommended values**: `development`, `language`, `tools`, `frontend`, `backend`, `meta`, `documentation`, `testing`
- **Custom values allowed**

### dependencies
- **Format**: Array of strings in format `namespace:plugin-name`
- **Example**: `["claudio:core", "claudio:elixir"]`

### Environment Variables
- `${CLAUDE_PLUGIN_ROOT}`: Resolves to plugin's installation directory
- **Usage**: In paths for skills, commands, agents, hooks, mcpServers
- **Example**: `"${CLAUDE_PLUGIN_ROOT}/skills/my-skill"`

## Strict Mode Behavior

### strict: true (default)
- Plugin **must** have `.claude-plugin/plugin.json`
- Marketplace fields **supplement** plugin.json values
- Marketplace fields **override** plugin.json if conflicts exist
- Useful for: Existing plugins, complex configurations, independent distribution

### strict: false
- Plugin `.claude-plugin/plugin.json` is **optional**
- Marketplace entry serves as **complete manifest** if no plugin.json exists
- Simplifies: Small plugins, centralized management, marketplace-only distribution

## Complete Example

```json
{
  "name": "vinnie357",
  "owner": {
    "name": "Vinnie Anderson",
    "email": "vinnie@example.com"
  },
  "metadata": {
    "description": "Claude skills for development workflows",
    "version": "1.0.0",
    "pluginRoot": "./plugins"
  },
  "plugins": [
    {
      "name": "core",
      "source": "core",
      "strict": false,
      "description": "Essential development skills",
      "version": "0.1.0",
      "author": {
        "name": "Vinnie Anderson"
      },
      "repository": "https://github.com/vinnie357/claude-skills",
      "license": "MIT",
      "category": "development",
      "keywords": ["git", "documentation", "code-review"],
      "skills": [
        "${CLAUDE_PLUGIN_ROOT}/skills/git",
        "${CLAUDE_PLUGIN_ROOT}/skills/documentation",
        "${CLAUDE_PLUGIN_ROOT}/skills/code-review"
      ]
    },
    {
      "name": "elixir",
      "source": "elixir",
      "strict": false,
      "description": "Elixir development skills",
      "version": "0.1.0",
      "author": {
        "name": "Vinnie Anderson"
      },
      "license": "MIT",
      "category": "language",
      "keywords": ["elixir", "phoenix", "otp"],
      "dependencies": ["vinnie357:core"],
      "skills": [
        "${CLAUDE_PLUGIN_ROOT}/skills/phoenix",
        "${CLAUDE_PLUGIN_ROOT}/skills/otp"
      ]
    },
    {
      "name": "external-skill",
      "source": {
        "source": "github",
        "repo": "anthropics/skills",
        "path": "skill-creator"
      },
      "strict": true,
      "category": "external"
    }
  ]
}
```

## Validation Checklist

- [ ] Valid JSON syntax
- [ ] Required fields present: `name`, `owner`, `plugins`
- [ ] `owner.name` is present
- [ ] All names are kebab-case
- [ ] `plugins` is an array (can be empty)
- [ ] Each plugin entry has `name` and `source`
- [ ] Versions use semantic versioning (if specified)
- [ ] Source paths exist (for relative paths)
- [ ] No circular dependencies
- [ ] All dependency references exist in marketplace
- [ ] `${CLAUDE_PLUGIN_ROOT}` used correctly in paths
- [ ] License uses SPDX identifiers (if specified)
