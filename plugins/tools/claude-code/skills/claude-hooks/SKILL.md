---
name: claude-hooks
description: Guide for creating event-driven hooks for Claude Code. Use when configuring SessionStart/PreToolUse/PostToolUse/Stop hooks, blocking dangerous tool calls, injecting context at turn 1, or troubleshooting plugin hook configuration.
license: MIT
---

# Claude Code Hooks

Hooks are shell commands or prompts that Claude Code executes in response to events. They are the only mechanism that can compel behavior — Claude reads memory and skills as guidance, but the harness runs hooks, not Claude.

## When to Use

- Inject binding context at session start (SessionStart)
- Validate or block tool calls before execution (PreToolUse)
- Format, lint, or log after tool calls (PostToolUse)
- Enforce completion standards before the agent stops (Stop / SubagentStop)
- Augment user prompts with project context (UserPromptSubmit)

## Hook Configuration Locations

| Scope | Path | Use case |
|---|---|---|
| User | `~/.claude/settings.json` under `hooks` | Personal automation across all projects |
| Project | `<project>/.claude/settings.json` under `hooks` | Repo-shared automation |
| Plugin | `<plugin-root>/hooks/hooks.json` | Distribute hooks via plugin install |
| Skill/Subagent | Skill or subagent frontmatter `hooks:` field | Lifecycle-scoped hooks |

Plugin hooks at `<plugin-root>/hooks/hooks.json` are auto-discovered. No registration in `plugin.json` required.

## Plugin Hook File Structure

Plugin `hooks/hooks.json` uses the wrapper format:

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

- `description` — optional, surfaced in plugin metadata
- `hooks` — required wrapper containing event arrays
- `matcher` — regex of tool names (PreToolUse/PostToolUse) or session lifecycle phases (SessionStart)
- `${CLAUDE_PLUGIN_ROOT}` — absolute path to the plugin root, expanded at runtime

## Hook Events

| Event | When it fires | Common use |
|---|---|---|
| `SessionStart` | Session start, resume, clear | Inject binding context to turn 1 |
| `SessionEnd` | Session ends | Cleanup, telemetry |
| `UserPromptSubmit` | User submits a prompt | Augment prompt, log interaction |
| `PreToolUse` | Before a tool executes | Block dangerous calls, validate input |
| `PostToolUse` | After a tool completes | Format, lint, sync, log |
| `Stop` | Agent finishes responding | Enforce completion standards |
| `SubagentStop` | Spawned subagent finishes | Subagent-specific cleanup |
| `PreCompact` | Before context compaction | Inject context to preserve |
| `Notification` | A notification fires | Custom notification routing |

## Hook Types

### Command Hooks

Execute a shell command. Deterministic, fast.

```json
{
  "type": "command",
  "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh",
  "timeout": 60
}
```

### Prompt Hooks

Send a prompt to a model for context-aware decisions. Slower but flexible.

```json
{
  "type": "prompt",
  "prompt": "Evaluate if this tool use is appropriate: $TOOL_INPUT",
  "timeout": 30
}
```

Supported events for prompt hooks: `Stop`, `SubagentStop`, `UserPromptSubmit`, `PreToolUse`.

## SessionStart — Injecting Turn-1 Context

`SessionStart` is the strongest compliance mechanism: stdout from the hook script becomes part of the model's first input. Memory and skills inform; SessionStart compels.

Plugin example (`plugins/example/hooks/hooks.json`):

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

Companion script (`plugins/example/hooks/session-start.sh`):

```bash
#!/usr/bin/env bash
set -u
cat >/dev/null 2>&1 || true   # consume stdin

cat <<'EOF'
[PLUGIN-NAME — SESSION-START COMMAND CONTRACT]

These are commands with triggers, not informational text.

1. Run mise run ci before any commit.
2. Conventional commits, no Co-Authored-By attribution.
3. ...
EOF
```

The header in the heredoc lands as turn-1 context. Keep it tight — every session pays this token cost.

## PreToolUse — Validation and Blocking

Exit code from a `PreToolUse` command hook controls whether the tool runs:

- Exit 0: continue
- Exit non-zero: block the tool, show stderr to the user

Example — block force-push to main:

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

`guard-push.sh` reads the tool input from stdin (JSON), parses with `jq`, and exits non-zero on a forbidden pattern.

## PostToolUse — Auto-Format, Lint, Sync

`PostToolUse` runs after the tool completes. Exit codes are logged but do not affect the tool result.

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

The hook reads the tool input from stdin and runs the formatter on the modified file.

## Hook Inputs and Outputs

Hook scripts receive event JSON on stdin:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": { "file_path": "...", "content": "..." }
}
```

Parse with `jq` in the hook script:

```bash
file_path=$(jq -r '.tool_input.file_path' < /dev/stdin)
```

Stdout from `SessionStart` and `UserPromptSubmit` hooks is injected into the model's context. Stdout from other events is logged but not surfaced.

## Best Practices

- **Keep hooks fast.** Hooks block the harness. Aim for under 1 second for `PreToolUse`/`PostToolUse`. Set explicit `timeout` values.
- **Use `${CLAUDE_PLUGIN_ROOT}`.** Never hardcode plugin paths.
- **Validate stdin.** Hook input is JSON; use `jq` and exit cleanly on parse failure.
- **Scope matchers narrowly.** Match `Write|Edit` over matching all tools.
- **Mark scripts executable.** `chmod +x` after creating shell scripts; the hook will fail silently otherwise.
- **Test scripts standalone.** Run `echo '{...}' | bash hooks/script.sh` before relying on the hook to fire.

## Security

- Treat all stdin fields as untrusted input. Use `jq` to parse, never eval.
- Block destructive patterns in `PreToolUse` Bash hooks (`rm -rf /`, `dd if=`, force-push to protected branches).
- Sanitize file paths with `realpath` and verify they remain inside the project root.
- Hooks run with the user's full privileges. A malicious plugin hook can do anything the user can do — review before installing.

## Anti-Fabrication

Validate hook behavior with actual execution before claiming it works. Run the hook script standalone, observe stdin parsing, exit codes, and stdout. Do not assume an event fires without verifying the hook entry in the harness logs.

## Templates

- `templates/plugin-hook.md` — plugin `hooks/hooks.json` configuration with `PostToolUse`, `Write|Edit` matcher, and `${CLAUDE_PLUGIN_ROOT}`
- `templates/skill-hook.md` — skill/subagent frontmatter hook example for `PreToolUse`, `PostToolUse`, `Stop`

## References

- Claude Code Hooks: https://code.claude.com/docs/en/hooks
- Plugin Configuration: https://code.claude.com/docs/en/plugins#hooks
