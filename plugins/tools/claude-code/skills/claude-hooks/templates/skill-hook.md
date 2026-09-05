Hooks in skills and agents
In addition to settings files and plugins, hooks can be defined directly in skills and subagents using frontmatter. Subagent hooks are scoped to the subagent's lifecycle and only run while it is active. Skill hooks differ: Claude Code registers them when you or Claude invoke the skill and keeps running them for the rest of the session, on turns after the skill's own turn as well.
Supported events: PreToolUse, PostToolUse, and Stop
Example in a Skill:
---
name: secure-operations
description: Perform operations with security checks
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---