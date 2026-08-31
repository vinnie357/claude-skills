---
name: claude-agents
description: Guide for creating custom agents (subagents) for Claude Code. Use when writing agents/*.md files, choosing agent frontmatter (tools, model, skills, permissionMode, maxTurns), restricting a subagent tool allowlist, preloading skills into an agent, or troubleshooting agent invocation.
---

# Claude Code Agents

Guide for creating custom agents that provide specialized behaviors and tool access for specific tasks.

## When spawning as part of a team

Invoke `/core:agent-loop` for the 4-phase / 6-tier execution model.
Invoke `/claude-code:claude-teams` if the agent joins a multi-agent team.
Invoke `/core:anti-fabrication` always — every claim about a tool, file, or test result requires tool execution.

Glob patterns like `/core:*` do not expand in Agent prompts. List skill names explicitly.

## What Are Agents?

Agents are specialized Claude instances with:
- **Specific tool access**: Limited or specialized tool sets
- **Defined behaviors**: Pre-configured instructions and constraints
- **Task focus**: Optimized for particular workflows
- **Autonomous operation**: Can execute multi-step tasks independently

## Agents vs Skills

| Feature | Agents | Skills |
|---------|--------|--------|
| **Activation** | Explicitly launched via Agent tool | Auto-activated based on context |
| **Tool Access** | Configurable, can be restricted | Inherit from parent context |
| **State** | Independent, isolated | Share parent context |
| **Use Case** | Complex multi-step tasks | Knowledge and guidelines |
| **Persistence** | Single execution | Always available when loaded |

## Agent File Structure

### Location

Agents are defined in markdown files located in:
- Plugin: `<plugin-root>/agents/`
- User-level: `.claude/agents/`

### File Naming

- Use kebab-case: `code-reviewer.md`
- File name becomes the agent type
- Be descriptive about the agent's purpose

## Basic Agent Format

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Grep, Glob
model: sonnet
---

You are a code reviewer. Analyze code for quality, security, and best practices.

## Workflow

1. **Find files**: Glob to locate target files
2. **Read code**: Examine contents
3. **Check patterns**: Grep for anti-patterns
4. **Report**: Provide prioritized feedback

## Guidelines

- **Specific**: Reference file:line locations
- **Actionable**: Suggest concrete fixes
- **Prioritized**: Critical issues first
```

Writing style: direct, imperative language. Open with "You are a [role]. Your role is to [primary function]" rather than "I am a specialized [role]...". Use numbered workflow steps with specific commands, not bullet lists describing capabilities. Full style guidance and worked best-practice examples: `references/patterns.md`.

## Agent Configuration

### YAML Frontmatter

Complete field reference (source: https://code.claude.com/docs/en/sub-agents):

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | Unique identifier, lowercase letters and hyphens. Hooks receive this value as `agent_type`. The filename does not need to match. |
| `description` | yes | When Claude delegates to this subagent. |
| `tools` | no | Tool allowlist. Omit to inherit all tools. To preload skill content use `skills` — never list `Skill` here. |
| `disallowedTools` | no | Denylist removed from the inherited or specified tool set. |
| `model` | no | `sonnet`, `opus`, `haiku`, `fable`, a full model ID (e.g. `claude-opus-4-8`), or `inherit`. Defaults to `inherit`. |
| `permissionMode` | no | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`, or `manual` (alias of `default`, v2.1.200+). Ignored for plugin subagents. |
| `maxTurns` | no | Maximum agentic turns before the subagent stops. |
| `skills` | no | Skills preloaded into context at startup. See Preloading Skills below. |
| `mcpServers` | no | MCP servers available to this subagent (name reference or inline config). Ignored for plugin subagents. |
| `hooks` | no | Lifecycle hooks scoped to this subagent. Ignored for plugin subagents. |
| `memory` | no | Persistent memory scope: `user`, `project`, or `local`. |
| `background` | no | `true` forces background execution. Unset lets Claude choose; defaults to background as of v2.1.198. |
| `effort` | no | `low`, `medium`, `high`, `xhigh`, or `max` (model-dependent). |
| `isolation` | no | `worktree` runs the subagent in a temporary git worktree, auto-cleaned if the subagent makes no changes. |
| `color` | no | `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan`. |
| `initialPrompt` | no | Auto-submitted first user turn when run as a main-session agent (`--agent`). |

**Model selection**: match the model to task complexity — `haiku` for simple/repetitive tasks, `sonnet` for standard tasks, `opus`/`fable` for complex reasoning, `inherit` (default) to match the parent session's model.

### Preloading Skills

The `skills` field preloads full skill content into the subagent's context at startup — not just the description shown during discovery. Use the namespaced form for plugin skills:

```markdown
---
name: phoenix-reviewer
description: Reviews Phoenix application code
tools: Read, Glob, Grep
skills:
  - elixir:phoenix
  - elixir:testing
---
```

Skills not listed in `skills` remain invocable through the Skill tool during the run — `skills` only controls what loads automatically at startup. Never list `Skill` in `tools:` to enable this; `skills` is the dedicated field.

## Agent Spawning Naming Convention

Build the `name` parameter from four segments: `<issue>-<role>-<model>-<n>`. Every segment is a placeholder. None of the four is a literal.

| Segment | What goes there |
|---|---|
| `<issue>` | The number of the tracker issue this agent's team works on — `318` for `claude-skills-318`. With no tracker issue, use a short task slug (`audit-ci`). |
| `<role>` | The agent's job on that team (`test-author`, `impl`, `ci`, `review`). |
| `<model>` | The model tier the agent runs on (`haiku`, `sonnet`, `opus`, `fable`). |
| `<n>` | The session-global spawn counter. |

Join the segments with hyphens. The assembled name must match `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`. Keep every segment kebab-case, and never use a space.

A session that works issue 318 and then moves to 317 names its agents in this order:

- `318-test-author-sonnet-1`
- `318-impl-sonnet-2`
- `318-ci-haiku-3`
- `317-plan-fable-4`

Read `318-ci-haiku-3` as the CI runner on issue 318's team, running haiku, third agent spawned this session. Each segment answers one question without opening the agent: the issue groups one team under a shared prefix, the role says what the agent does, and the model shows which tier it activated with.

Example spawning:

```
Agent({
  name: '318-impl-sonnet-2',
  description: 'Implement feature endpoint',
  prompt: '...'
})
```

The counter is ONE GLOBAL SERIES PER SESSION. The first agent spawned takes `1`, the second takes `2`, whatever its issue, role, or model tier. The trailing number therefore gives both a unique name and the agent's spawn order. Assign the counter at spawn time. Never reset it mid-session, and never carry it into another session. This is a prompt-discipline convention, not an enforced mechanism.

### The Agent tool's `name` parameter changes report delivery

Passing the Agent tool's `name` parameter (the convention above) converts the spawned agent into a teammate rather than a plain subagent. This changes how its report reaches the lead: a teammate's plain final text is never delivered — only a `SendMessage` call reaches the lead. Every spawn prompt built from this convention must instruct the agent to call `SendMessage` with its full report on completion.

**Term collision.** This file uses `name` for two different things. The frontmatter `name:` field in an `agents/*.md` file is an agent-type identifier — it does NOT create a teammate. The Agent tool's `name` parameter at spawn time is the one that does. Say "the Agent tool's `name` parameter" whenever meaning the latter; conflating the two implies every agent file has broken reporting, which is false.

**Escalation re-spawns take a fresh name.** When the escalation ladder (haiku → sonnet → opus, per `/core:agent-loop` "Model Escalation") promotes a failed agent, spawn it under a new name carrying the new model tier and the next counter value — never resume the failed agent under its own name as its escalation. Resuming revives the original agent on its original model while its name still advertises the old tier.

**Enforcement backstop.** No agent frontmatter field controls report delivery. The `TeammateIdle` hook (see `/claude-code:claude-teams` `references/agent-teams.md`) is the available mechanism for enforcing that a teammate reports before going idle.

## Common Agent Patterns

Four recurring shapes, each with a runnable template:

- **Read-only analysis** (security scans, code reviews, audits): restrict `tools` to `Read, Grep, Glob`. Template: `templates/read-only-analyzer.md`
- **Write-capable** (generating tests, docs, code): add `Write`. Template: `templates/write-capable-agent.md`
- **Full-access** (refactoring, migrations, complex modifications): omit `tools` entirely for no restrictions. Template: `templates/full-access-agent.md`
- **MCP-enabled** (browser automation, external APIs): mix core tools with MCP tool names. Template: `templates/mcp-agent.md`

Minimal starting point: `templates/basic-agent.md`. Best-practice worked examples (clear purpose, appropriate tool access, explicit instructions): `references/patterns.md`. Plugin wiring, invocation mechanics, and troubleshooting: `references/plugin-config.md`.

## Security

Grant only the tools an agent's task requires — a read-only analyzer never needs `Bash` or `Write`. Never hardcode credentials, API keys, private URLs, or access tokens in agent files; agent bodies are prompts checked into repos and plugins. Worked tool-restriction and input-validation examples: `references/patterns.md`.

## References

- `templates/basic-agent.md` — official minimal example
- `templates/read-only-analyzer.md` — security analysis pattern
- `templates/write-capable-agent.md` — test generation pattern
- `templates/full-access-agent.md` — refactoring pattern (no tool restrictions)
- `templates/mcp-agent.md` — MCP tools pattern (browser automation)
- `references/patterns.md` — writing style, common patterns, and worked best-practice/security examples
- `references/plugin-config.md` — plugin.json wiring, invoking agents, agent communication, troubleshooting
- Claude Code Agents: https://code.claude.com/docs/en/agents
- Subagents (Agent Tool): https://code.claude.com/docs/en/sub-agents
