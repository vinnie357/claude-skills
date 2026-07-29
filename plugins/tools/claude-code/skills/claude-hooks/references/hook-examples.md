# Hook Configuration Examples

Copy-paste `hooks.json` and hook-definition examples for `claude-hooks`. `${CLAUDE_PLUGIN_ROOT}` in
these blocks is the literal brace-expansion syntax — copy it as-is into a real `hooks.json`; Claude
Code expands it at plugin-load time to the plugin's installation directory. (This file is delivered
byte-exact via `Read`, unlike the skill body, so the token survives here.)

## Plugin hooks.json wrapper format

```json
{
  "description": "Brief explanation of what these hooks do",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/check.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## Command hook

```json
{
  "type": "command",
  "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh",
  "timeout": 60
}
```

## SessionStart — plugin example (`plugins/example/hooks/hooks.json`)

```json
{
  "description": "Inject project conventions at session start",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## PreToolUse — block force-push to main

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/guard-push.sh"
          }
        ]
      }
    ]
  }
}
```

## PostToolUse — auto-format after edits

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/format.sh"
          }
        ]
      }
    ]
  }
}
```
