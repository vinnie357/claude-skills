---
name: claude-teams
description: Guide for coordinating multiple Claude Code agents as teams. Use when setting up agent teams, configuring subagents, orchestrating multi-agent workflows, or building programmatic agent systems with the Claude Agent SDK.
license: MIT
---

# Claude Teams

Coordinate multiple Claude Code agents working together on shared tasks.

## When to Use

Activate when:
- Setting up or configuring Agent Teams (experimental)
- Creating custom subagents for task delegation
- Building multi-agent workflows with the Claude Agent SDK
- Designing coordination patterns for parallel agent work
- Troubleshooting agent communication or task assignment

## Approaches

Three approaches exist for multi-agent coordination, each with different trade-offs:

| Approach | Communication | Coordination | Best For |
|----------|--------------|--------------|----------|
| **Agent Teams** | Peer-to-peer messaging + shared task list | Team lead + self-coordination | Collaborative work requiring discussion |
| **Subagents** | Report back to parent only | Parent manages all | Focused delegated tasks |
| **Agent SDK** | Programmatic message streaming | Developer-controlled | CI/CD, automation, custom apps |

## Agent Teams (Experimental)

First-party multi-agent coordination. A team lead spawns teammates that work independently with peer-to-peer messaging and a shared task list.

Enable with: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

For setup, configuration, and usage details, see `references/agent-teams.md`.

## Subagents (Task Tool)

Lightweight delegation within a single session. Subagents run in their own context window, complete a task, and return results to the parent.

For subagent types, custom agents, and isolation patterns, see `references/subagents.md`.

## Agent SDK

Programmatic multi-agent orchestration in Python and TypeScript using the same tools that power Claude Code.

For SDK setup, agent definitions, and session management, see `references/agent-sdk.md`.

## Multi-Agent Patterns

Proven patterns for file ownership, task decomposition, scaling, and quality gates.

For architecture guidance and case studies, see `references/patterns.md`.
