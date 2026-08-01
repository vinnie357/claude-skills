# Agent Patterns and Best Practices

Writing style, and worked examples for the patterns and security guidance summarized in `claude-agents`'s SKILL.md.

## Agent Writing Style

Effective agents use direct, imperative language.

### Opening Statement

- **Do**: "You are a [role]. Your role is to [primary function]."
- **Don't**: "I am a specialized [role] focused on..."

### Workflow Steps

- **Do**: Numbered steps with specific commands
- **Don't**: Bullet lists describing capabilities

### Guidelines Section

- **Do**: Single-word bold labels with brief explanations
- **Don't**: Verbose explanations of best practices

## Best Practices

### Clear Purpose

Each agent has a specific, well-defined purpose:

```markdown
---
name: migration-helper
description: Assists with database schema migrations
---

# Database Migration Agent

Specialized in creating and validating database migrations.
```

### Appropriate Tool Access

Only grant necessary tools:

```markdown
---
# Analysis agent - read-only
tools: Read, Grep, Glob
---
```

```markdown
---
# Implementation agent - can modify
tools: Read, Write, Edit, Glob, Grep
---
```

### Clear Instructions

Provide explicit behavior guidelines grounded in the project's own conventions rather than an invented number:

```markdown
# Testing Agent

## Mandatory Requirements

- Generate tests for ALL public methods
- Match the project's existing coverage conventions — read its CI config
  or test task rather than assuming a target percentage
- Include edge cases and error scenarios
- Use project's testing framework conventions

## Constraints

- Do not modify source code
- Follow existing test file naming patterns
- Use appropriate assertions
```

## Security Examples

### Tool Restrictions

Limit dangerous operations:

```markdown
---
# Don't give Bash access to untrusted agents
tools:
  - Read
  - Write  # Safer than arbitrary shell commands
---
```

### Input Validation

Validate agent inputs:

```markdown
# Deployment Agent

Before deploying:
1. Verify target environment is valid
2. Check deployment permissions
3. Validate configuration
4. Confirm destructive operations
```

### Sensitive Data

Never hardcode:
- Credentials
- API keys
- Private URLs
- Access tokens
