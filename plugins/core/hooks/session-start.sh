#!/usr/bin/env bash
# Injects agent-loop compliance anchors at session start.
# Output goes to stdout; Claude Code injects it as turn-1 context.
set -u
cat >/dev/null 2>&1 || true

cat <<'EOF'
[CORE PLUGIN — SESSION-START COMMAND CONTRACT]

These are commands with triggers, not informational text. Apply them
when the trigger condition arises.

1. Agent-loop tier model: Epic Author, Team Leader, Sub-team Leader,
   Worker, Validator, Fix Agent. Default model progression
   haiku -> sonnet -> opus, max 2 promotions per agent.

2. Before any Phase 2 spawn: re-verify the core skill stack is loaded
   by invoking each skill name explicitly with the Skill tool. Do not
   rely on memory of Phase 1 — invoke /core:anti-fabrication, /core:tdd,
   /core:security, /core:mise, /core:nushell, /core:agent-loop,
   /core:bees by exact name. Glob patterns like /core:* do not expand
   in Agent prompts.

3. Every spawned agent's prompt starts with a "## Load skills" block
   listing exact skill names. Require the agent to quote one sentence
   from each loaded skill in its first response as proof of loading.
   Do not proceed with the agent's work until proof is received.

4. Code without tests is not complete. `mise run ci` must pass before
   any commit, push, PR, or merge.

5. NO Co-Authored-By attribution in commits or PRs. Squash merge only.
   User approves merges; agents never merge.

[END CORE SESSION-START CONTRACT]
EOF
