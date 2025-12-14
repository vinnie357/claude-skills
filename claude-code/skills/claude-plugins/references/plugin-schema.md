# Plugin JSON Schema Specification

Complete JSON schema for Claude Code plugin.json files.

## Schema Definition

```json
{
  "name": "string (required, kebab-case)",
  "version": "string (optional, semver recommended)",
  "description": "string (optional)",
  "author": {
    "name": "string (optional)",
    "email": "string (optional)",
    "url": "string (optional, URL)"
  },
  "homepage": "string (optional, URL)",
  "repository": "string (optional, URL)",
  "license": "string (optional, SPDX identifier)",
  "keywords": ["array of strings (optional)"],
  "commands": "string | array (optional, paths)",
  "agents": "string | array (optional, paths)",
  "hooks": "string | object (optional, path or config)",
  "mcpServers": "string | object (optional, path or config)",
  "skills": ["array of strings (optional, paths)"]
}
```

## Field Specifications

### name (Required)
- **Type**: String
- **Format**: kebab-case
- **Pattern**: `^[a-z0-9]+(-[a-z0-9]+)*$`
- **Description**: Unique identifier for the plugin
- **Examples**: `core-skills`, `elixir-phoenix`, `rust-tools`

### version (Recommended)
- **Type**: String
- **Format**: Semantic versioning
- **Pattern**: `^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$`
- **Description**: Plugin version following semver
- **Examples**: `1.0.0`, `2.1.3-beta.1`, `1.0.0+build.123`

### description (Optional)
- **Type**: String
- **Description**: Brief explanation of plugin purpose and functionality
- **Recommendations**: Keep under 200 characters, be specific

### author (Optional)
- **Type**: Object
- **Properties**:
  - `name` (string): Author's full name or username
  - `email` (string): Contact email address
  - `url` (string): Personal website or GitHub profile URL

### homepage (Optional)
- **Type**: String (URL)
- **Description**: Link to plugin documentation or project page
- **Examples**: `https://docs.example.com/plugin`, `https://github.com/user/plugin`

### repository (Optional)
- **Type**: String (URL)
- **Description**: Source code repository URL
- **Examples**: `https://github.com/user/plugin`, `https://gitlab.com/team/plugin.git`

### license (Optional)
- **Type**: String
- **Format**: SPDX license identifier
- **Common Values**: `MIT`, `Apache-2.0`, `GPL-3.0`, `BSD-3-Clause`, `ISC`
- **Reference**: https://spdx.org/licenses/

### keywords (Optional)
- **Type**: Array of strings
- **Description**: Tags for discoverability and categorization
- **Recommendations**: Use lowercase, be specific, 3-10 keywords ideal

### skills (Optional)
- **Type**: Array of strings
- **Description**: Paths to skill directories (relative to plugin root)
- **Format**: Each path should point to a directory containing SKILL.md
- **Examples**: `["./skills/git", "./skills/documentation"]`

### commands (Optional)
- **Type**: String or Array of strings
- **Description**: Paths to command files or directories
- **Formats**:
  - String: `"./commands"` (directory containing .md files)
  - Array: `["./commands/cmd1.md", "./commands/cmd2.md"]`

### agents (Optional)
- **Type**: String or Array of strings
- **Description**: Paths to agent files or directories
- **Formats**:
  - String: `"./agents"` (directory)
  - Array: `["./agents/agent1.md", "./agents/agent2.md"]`

### hooks (Optional)
- **Type**: String or Object
- **Description**: Hooks configuration or path to hooks file
- **Formats**:
  - String: `"./hooks.json"` (path to hooks config)
  - Object: Inline hooks configuration

**Inline hooks example:**
```json
{
  "hooks": {
    "onInstall": "./scripts/install.sh",
    "onUninstall": "./scripts/uninstall.sh"
  }
}
```

### mcpServers (Optional)
- **Type**: String or Object
- **Description**: MCP server configuration or path to config file
- **Formats**:
  - String: `"./mcp-config.json"` (path to MCP config)
  - Object: Inline MCP server configuration

**Inline MCP servers example:**
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "mcp-server-filesystem",
      "args": ["./workspace"]
    }
  }
}
```

## Invalid Fields

These fields are **NOT valid** in plugin.json (they belong in marketplace.json):

- `dependencies`: Plugin dependencies (marketplace-level)
- `category`: Plugin categorization (marketplace-level)
- `strict`: Strict mode control (marketplace-level)
- `source`: Plugin source location (marketplace-level)
- `tags`: Use `keywords` instead

## Validation Rules

1. **JSON Syntax**: Must be valid JSON
2. **Required Fields**: Only `name` is required
3. **Kebab-case Naming**: `name` must be kebab-case
4. **Semantic Versioning**: `version` should follow semver
5. **Path Validity**: All paths should be relative and exist
6. **SPDX License**: `license` should use SPDX identifiers
7. **URL Format**: `homepage`, `repository`, `author.url` must be valid URLs

## Complete Example

```json
{
  "name": "elixir-phoenix",
  "version": "1.0.0",
  "description": "Elixir development skills: Phoenix, OTP, testing, configuration, and anti-patterns",
  "author": {
    "name": "Developer Name",
    "email": "dev@example.com",
    "url": "https://github.com/developer"
  },
  "homepage": "https://github.com/developer/elixir-phoenix",
  "repository": "https://github.com/developer/elixir-phoenix",
  "license": "MIT",
  "keywords": ["elixir", "phoenix", "otp", "beam", "erlang"],
  "skills": [
    "./skills/anti-patterns",
    "./skills/phoenix",
    "./skills/otp",
    "./skills/testing",
    "./skills/config"
  ],
  "commands": ["./commands"],
  "hooks": {
    "onInstall": "./scripts/setup.sh"
  }
}
```

## Minimal Example

```json
{
  "name": "my-plugin"
}
```

## Validation Checklist

- [ ] Valid JSON syntax
- [ ] `name` field is present
- [ ] `name` is kebab-case
- [ ] `version` uses semantic versioning (if present)
- [ ] No invalid fields (dependencies, category, strict, source, tags)
- [ ] All skill paths exist and contain SKILL.md
- [ ] All command paths exist
- [ ] All agent paths exist
- [ ] License uses SPDX identifier (if present)
- [ ] URLs are valid (homepage, repository, author.url)
