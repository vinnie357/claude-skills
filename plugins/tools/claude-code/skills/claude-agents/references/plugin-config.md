# Plugin Wiring, Invocation, and Troubleshooting

Plugin configuration, invocation mechanics, and diagnostic checklist for `claude-agents`.

## Agent Plugin Configuration

### In plugin.json

```json
{
  "agents": [
    "./agents/code-reviewer.md",
    "./agents/test-generator.md",
    "./agents/security-analyzer.md"
  ]
}
```

### Directory-Based Loading

```json
{
  "agents": "./agents"
}
```

Loads all `.md` files in `agents/` directory.

## Invoking Agents

Agents are launched via the Agent tool (`Task` remains a deprecated alias, renamed in v2.1.63):

```python
# In parent Claude conversation
Agent(
    subagent_type="code-reviewer",
    description="Review authentication module",
    prompt="""
    Review the authentication module for:
    - Security vulnerabilities
    - Error handling
    - Input validation
    - Best practices
    """
)
```

## Agent Communication

### Input to Agent

- Task description
- Detailed prompt
- Access to conversation history (if configured)

### Output from Agent

- Final report/result
- No ongoing dialogue
- One-time execution

## Troubleshooting

### Agent Not Found

- Verify agent file location matches plugin.json
- Check file naming (kebab-case, .md extension)
- Ensure plugin is properly installed

### Tool Access Denied

- Check tools allowlist in frontmatter
- Verify tool names match exactly
- Ensure parent context permits delegation

### Unexpected Behavior

- Review agent instructions for clarity
- Check model selection appropriateness
- Verify iteration limits aren't too restrictive
- Test with verbose output
