# Agent SDK

The Claude Agent SDK provides programmatic multi-agent orchestration in Python and TypeScript, using the same tools that power Claude Code.

**Source**: https://platform.claude.com/docs/en/agent-sdk/overview

## Installation

```bash
# TypeScript
npm install @anthropic-ai/claude-agent-sdk

# Python
pip install claude-agent-sdk
```

## Defining Subagents

### Python

```python
import asyncio
from claude_agent_sdk import query, ClaudeAgentOptions, AgentDefinition

async def main():
    async for message in query(
        prompt="Review the authentication module for security issues",
        options=ClaudeAgentOptions(
            allowed_tools=["Read", "Grep", "Glob", "Task"],
            agents={
                "code-reviewer": AgentDefinition(
                    description="Expert code review specialist.",
                    prompt="Analyze code quality and suggest improvements.",
                    tools=["Read", "Glob", "Grep"],
                    model="sonnet",
                ),
                "test-runner": AgentDefinition(
                    description="Runs and analyzes test suites.",
                    prompt="Run tests and provide clear analysis of results.",
                    tools=["Bash", "Read", "Grep"],
                ),
            },
        ),
    ):
        if hasattr(message, "result"):
            print(message.result)

asyncio.run(main())
```

### TypeScript

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";

for await (const message of query({
  prompt: "Review the authentication module for security issues",
  options: {
    allowedTools: ["Read", "Grep", "Glob", "Task"],
    agents: {
      "code-reviewer": {
        description: "Expert code review specialist.",
        prompt: "Analyze code quality and suggest improvements.",
        tools: ["Read", "Glob", "Grep"],
        model: "sonnet"
      }
    }
  }
})) {
  if ("result" in message) console.log(message.result);
}
```

## AgentDefinition Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | `string` | Yes | When to use this agent |
| `prompt` | `string` | Yes | System prompt defining role and behavior |
| `tools` | `string[]` | No | Allowed tool names (inherits all if omitted) |
| `model` | `string` | No | `sonnet`, `opus`, `haiku`, or `inherit` |

## Session Management

Resume sessions to maintain context across queries:

```python
session_id = None

# First query: capture the session ID
async for message in query(
    prompt="Read the authentication module",
    options=ClaudeAgentOptions(allowed_tools=["Read", "Glob"]),
):
    if hasattr(message, "subtype") and message.subtype == "init":
        session_id = message.session_id

# Resume with full context from the first query
async for message in query(
    prompt="Now find all places that call it",
    options=ClaudeAgentOptions(resume=session_id),
):
    if hasattr(message, "result"):
        print(message.result)
```

## Detecting Subagent Invocation

Subagents are invoked via the Task tool. Check for `tool_use` blocks with `name: 'Task'`. Messages from within a subagent's context include a `parent_tool_use_id` field for tracking.

## Dynamic Agent Configuration

Create agents dynamically at runtime:

```python
def create_security_agent(security_level: str) -> AgentDefinition:
    is_strict = security_level == "strict"
    return AgentDefinition(
        description="Security code reviewer",
        prompt=f"You are a {'strict' if is_strict else 'balanced'} security reviewer...",
        tools=["Read", "Grep", "Glob"],
        model="opus" if is_strict else "sonnet",
    )
```

## Constraints

- Subagents cannot spawn their own subagents (do not include `Task` in a subagent's `tools` array)
- Each query starts a new context unless resumed via session ID
- Tool permissions must be declared upfront in `allowed_tools`
