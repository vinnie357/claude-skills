# Subagents (Task Tool)

Subagents are specialized agents that handle focused tasks within a single session. Each runs in its own context window with a custom system prompt and specific tool access, then returns results to the parent.

**Source**: https://code.claude.com/docs/en/sub-agents

## How Subagents Work

When Claude encounters a task matching a subagent's description, it delegates via the Task tool. The subagent works independently and returns a summary to the parent's context.

Key characteristics:
- Own context window (results summarized back to parent)
- Report to the parent agent only (no peer-to-peer communication)
- Parent manages all coordination
- Lower token cost than Agent Teams

## Built-in Subagents

| Agent | Model | Purpose |
|-------|-------|---------|
| **Explore** | Haiku | Fast, read-only codebase search and analysis |
| **Plan** | Inherited | Research agent used during plan mode |
| **General-purpose** | Inherited | Full-capability agent for multi-step tasks |
| **Bash** | Inherited | Command execution specialist |

## Creating Custom Subagents

Subagents are Markdown files with YAML frontmatter:

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. Analyze code and provide
specific, actionable feedback on quality, security, and best practices.
```

### Storage Locations (by priority)

1. `--agents` CLI flag (session-only, highest priority)
2. `.claude/agents/` (project-level)
3. `~/.claude/agents/` (user-level)
4. Plugin's `agents/` directory (lowest priority)

## Subagent Features

### Isolation via Worktrees

Run a subagent in a temporary git worktree for an isolated copy of the repository:

```yaml
---
name: experimental-refactor
description: Tests refactoring approaches in isolation
tools: Read, Write, Edit, Bash, Glob, Grep
isolation: worktree
---
```

The worktree is automatically cleaned up if the subagent makes no changes.

### Persistent Memory

Subagents can retain knowledge across sessions:

```yaml
---
name: project-analyst
description: Analyzes project patterns and remembers findings
tools: Read, Glob, Grep
memory: project
---
```

Memory scopes: `user`, `project`, `local`

### Skills Injection

Preload skill content into a subagent's context:

```yaml
---
name: phoenix-reviewer
description: Reviews Phoenix application code
tools: Read, Glob, Grep
skills:
  - elixir:phoenix
  - elixir:testing
---
```

### Hook Support

Define hooks in subagent frontmatter:

```yaml
---
name: safe-writer
description: Writes code with validation hooks
tools: Read, Write, Edit
hooks:
  PostToolUse:
    - matcher: Write
      command: "echo 'File written: $TOOL_INPUT'"
---
```

### Restricting Subagent Spawning

Control which subagent types an agent can delegate to:

```yaml
---
name: coordinator
description: Coordinates work across specialized agents
tools: Task(worker, researcher), Read, Bash
---
```

## Foreground vs Background

Subagents run in the foreground by default. Press `Ctrl+B` to background a running task and continue working.

Background subagents prompt for tool permissions upfront to run without interruption.

## Resuming Subagents

Subagents can be resumed to continue where they left off with full conversation history, using the agent ID returned from a previous invocation.

## Subagent Invocation

Invoke via the Task tool:

```
Use the Task tool with subagent_type: "code-reviewer" to review the authentication module.
```

Or programmatically via the Agent SDK (see `references/agent-sdk.md`).
