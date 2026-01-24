Plugin hooks
Plugins can provide hooks that integrate seamlessly with your user and project hooks. Plugin hooks are automatically merged with your configuration when plugins are enabled.
How plugin hooks work:
Plugin hooks are defined in the plugin’s hooks/hooks.json file or in a file given by a custom path to the hooks field.
When a plugin is enabled, its hooks are merged with user and project hooks
Multiple hooks from different sources can respond to the same event
Plugin hooks use the ${CLAUDE_PLUGIN_ROOT} environment variable to reference plugin files
Example plugin hook configuration:
{
  "description": "Automatic code formatting",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }