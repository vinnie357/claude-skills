Hooks in skills and agents
In addition to settings files and plugins, hooks can be defined directly in skills and subagents using frontmatter. These hooks are scoped to the component’s lifecycle and only run when that component is active.
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