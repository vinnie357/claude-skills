# Marketplace Config Examples

Copy-paste `marketplace.json` fragments for `plugin-marketplace`. `${CLAUDE_PLUGIN_ROOT}` in these
blocks is the literal brace-expansion syntax — copy it as-is; Claude Code expands it at plugin-load
time to the plugin's installation directory. (This file is delivered byte-exact via `Read`, unlike
the skill body, so the token survives here.)

## Environment Variables — path usage

```json
{
  "skills": [
    "${CLAUDE_PLUGIN_ROOT}/skills/my-skill"
  ],
  "commands": [
    "${CLAUDE_PLUGIN_ROOT}/commands"
  ]
}
```

This ensures paths work correctly regardless of installation location.

## Inline Plugin Definitions

Use `strict: false` to define complete plugin manifests inline without requiring plugin.json:

```json
{
  "name": "my-plugin",
  "source": "./plugins/my-plugin",
  "strict": false,
  "description": "Complete plugin definition inline",
  "version": "1.0.0",
  "author": {
    "name": "Developer Name"
  },
  "skills": [
    "${CLAUDE_PLUGIN_ROOT}/skills/skill-one",
    "${CLAUDE_PLUGIN_ROOT}/skills/skill-two"
  ]
}
```

## Component Path Override

Customize component locations:

```json
{
  "name": "custom-paths",
  "source": "./plugins/custom",
  "strict": false,
  "commands": ["${CLAUDE_PLUGIN_ROOT}/custom-commands"],
  "agents": ["${CLAUDE_PLUGIN_ROOT}/custom-agents"],
  "hooks": {
    "onInstall": "${CLAUDE_PLUGIN_ROOT}/hooks/install.sh"
  },
  "mcpServers": "${CLAUDE_PLUGIN_ROOT}/mcp-config.json"
}
```

## Creating a marketplace — Step 3: Add Plugin Entries

For each plugin, decide on strict mode and add entry:

```json
{
  "name": "marketplace-name",
  "owner": {
    "name": "Your Name",
    "email": "you@example.com"
  },
  "metadata": {
    "description": "Your marketplace description",
    "version": "1.0.0",
    "pluginRoot": "./plugins"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "source": "plugin-name",
      "strict": false,
      "description": "Plugin description",
      "version": "1.0.0",
      "author": {
        "name": "Your Name"
      },
      "license": "MIT",
      "category": "development",
      "skills": [
        "${CLAUDE_PLUGIN_ROOT}/skills/skill-one"
      ]
    }
  ]
}
```
