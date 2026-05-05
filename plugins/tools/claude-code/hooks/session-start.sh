#!/usr/bin/env bash
# Injects skill-authoring and agent/team triad anchors at session start.
# Output goes to stdout; Claude Code injects it as turn-1 context.
set -u
cat >/dev/null 2>&1 || true

cat <<'EOF'
[CLAUDE-CODE PLUGIN — SESSION-START COMMAND CONTRACT]

These are commands with triggers, not informational text. Apply them
when the trigger condition arises.

1. When editing any SKILL.md in this session, these are binding:
   - NO `allowed-tools` field in frontmatter. Tool filtering belongs
     on agents (`tools:` field), not skills. Enforced by
     `test/validate-plugin.nu`.
   - Description field uses third person and contains a
     `Use when ...` trigger pattern.
   - Body under 300 lines. Split into `references/` once exceeded.
   - Zero hedging verbs. Banned: should, may, might, consider, try to,
     offer to, it would be good to. Use imperative verbs instead.
   - References one level deep only (SKILL.md -> reference, not
     reference -> reference).

2. When spawning agents or forming teams, invoke this triad by EXACT
   name with the Skill tool: /core:agent-loop,
   /claude-code:claude-agents, /claude-code:claude-teams. Glob patterns
   like /core:* do not expand in Agent prompts — list names explicitly.

3. Load /core:anti-fabrication before any factual claim about a file,
   function, test result, or system state. No claim without a tool
   call to validate it.

4. Plugin hooks live at `<plugin-root>/hooks/hooks.json` with wrapper
   format `{ "description": "...", "hooks": { "<EventName>": [...] } }`.
   Valid event names: PreToolUse, PostToolUse, SessionStart, SessionEnd,
   UserPromptSubmit, Stop, SubagentStop, PreCompact, Notification.
   Use `${CLAUDE_PLUGIN_ROOT}` for paths in commands.

[END CLAUDE-CODE SESSION-START CONTRACT]
EOF
