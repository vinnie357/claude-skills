---
name: claude-agents
description: Guide for creating custom agents for Claude Code. Use when creating specialized agents, configuring agent tools.
---

# Claude Code Agents

Guide for creating custom agents that provide specialized behaviors and tool access for specific tasks.

## When to Use This Skill

Activate this skill when:
- Creating custom agent types for specific workflows
- Defining agent behaviors and tool permissions
- Configuring agent capabilities
- Understanding agent vs skill differences
- Implementing domain-specific agents

## What Are Agents?

Agents are specialized Claude instances with:
- **Specific tool access**: Limited or specialized tool sets
- **Defined behaviors**: Pre-configured instructions and constraints
- **Task focus**: Optimized for particular workflows
- **Autonomous operation**: Can execute multi-step tasks independently

## Agents vs Skills

| Feature | Agents | Skills |
|---------|--------|--------|
| **Activation** | Explicitly launched via Task tool | Auto-activated based on context |
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
description: Specialized agent for conducting thorough code reviews
tools:
  - Read
  - Grep
  - Glob
model: sonnet
---

# Code Review Agent

I am a specialized code review agent focused on:

## Responsibilities

- Analyzing code for correctness and style
- Identifying security vulnerabilities
- Checking test coverage
- Ensuring documentation quality
- Suggesting improvements

## Review Process

When reviewing code, I will:

1. Read the changed files
2. Check for common anti-patterns
3. Verify error handling
4. Assess test coverage
5. Provide actionable feedback

## Guidelines

- Focus on significant issues
- Provide specific examples
- Suggest concrete improvements
- Consider project context
```

## Agent Configuration

### YAML Frontmatter

Required and optional fields:

```markdown
---
name: agent-name                    # Required: kebab-case identifier
description: Brief description      # Required: What this agent does
tools:                             # Optional: Tool allowlist
  - Read
  - Write
  - Bash
model: sonnet                      # Optional: Model to use (sonnet, opus, haiku)
max_iterations: 10                 # Optional: Maximum task iterations
timeout: 300                       # Optional: Timeout in seconds
---
```

### Tool Allowlist

Restrict agent to specific tools:

- Can read files
- Can search code
- Can find files
- Cannot use Write, Edit, Bash, etc.

Example:

```markdown
---
tools: Read, Grep, Glob     
---
```




**No tool restrictions** (access to all tools):

```markdown
---
# Omit tools field entirely
---
```

### Model Selection

Choose appropriate model for the task:

```markdown
---
model: haiku        # Fast, cost-effective for simple tasks
# model: sonnet     # Balanced (default)
# model: opus       # Most capable for complex tasks
---
```

## Common Agent Patterns

### Read-Only Analysis Agent

```markdown
---
name: security-analyzer
description: Analyzes code for security vulnerabilities
tools: Read, Grep, Glob
model: sonnet
---

# Security Analysis Agent

I perform security analysis on codebases.

## Analysis Areas

- SQL injection vulnerabilities
- XSS attack vectors
- Authentication/authorization issues
- Sensitive data exposure
- Insecure dependencies

## Process

1. Scan for common vulnerability patterns
2. Check security best practices
3. Identify potential risks
4. Provide remediation guidance
```

### Test Generation Agent

```markdown
---
name: test-generator
description: Generates comprehensive test suites
tools: Read, Write, Glob
model: sonnet
---

# Test Generation Agent

I create comprehensive test suites for your code.

## Test Types

- Unit tests
- Integration tests
- Edge case coverage
- Error scenario tests

## Approach

1. Analyze source code structure
2. Identify testable units
3. Generate test cases
4. Create test files with proper naming
5. Include setup and teardown logic
```

### Documentation Agent

```markdown
---
name: docs-generator
description: Creates and updates project documentation
tools: Read, Write, Glob, Grep
model: sonnet
---

# Documentation Agent

I create and maintain project documentation.

## Documentation Types

- README files
- API documentation
- Code comments
- Architecture docs
- User guides

## Standards

- Clear, concise language
- Practical examples
- Up-to-date with codebase
- Proper formatting (Markdown, JSDoc, etc.)
```

### Refactoring Agent

```markdown
---
name: refactorer
description: Safely refactors code while maintaining functionality
tools: Read, Write, Edit, Grep, Glob
model: sonnet
max_iterations: 20
---

# Code Refactoring Agent

I refactor code to improve quality while preserving behavior.

## Refactoring Goals

- Improve readability
- Reduce complexity
- Eliminate duplication
- Enhance maintainability
- Follow best practices

## Safety Measures

- Preserve existing functionality
- Maintain test coverage
- Document changes
- Use safe transformations
```

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

Agents are launched via the Task tool:

```python
# In parent Claude conversation
Task(
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

## Best Practices

### Clear Purpose

Each agent should have a specific, well-defined purpose:

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

### Model Selection

Match model to task complexity:

- **haiku**: Simple, repetitive tasks
- **sonnet**: Standard tasks (default)
- **opus**: Complex reasoning required

### Iteration Limits

Set appropriate limits for task complexity:

```markdown
---
max_iterations: 5   # Simple, focused task
# max_iterations: 20  # Complex, multi-step workflow
---
```

### Clear Instructions

Provide explicit behavior guidelines:

```markdown
# Testing Agent

## Mandatory Requirements

- Generate tests for ALL public methods
- Achieve minimum 80% code coverage
- Include edge cases and error scenarios
- Use project's testing framework conventions

## Constraints

- Do not modify source code
- Follow existing test file naming patterns
- Use appropriate assertions
```

## Security Considerations

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

## Agent Examples

### PR Review Agent

```markdown
---
name: pr-reviewer
description: Reviews pull requests for quality and completeness
tools: Read, Grep, Glob
model: sonnet
---

# Pull Request Review Agent

Conducting thorough PR review...

## Checklist

- [ ] Code quality and style
- [ ] Test coverage
- [ ] Documentation updates
- [ ] Breaking changes noted
- [ ] Security considerations
- [ ] Performance implications

## Review Process

1. Analyze changed files
2. Check for common issues
3. Verify tests exist
4. Review documentation
5. Provide constructive feedback
```

### Migration Agent

```markdown
---
name: code-migrator
description: Migrates code from one framework/version to another
tools: Read, Write, Edit, Glob, Grep
model: opus
max_iterations: 30
---

# Code Migration Agent

Performing framework migration...

## Migration Steps

1. Analyze current codebase
2. Identify migration patterns
3. Apply transformations
4. Update dependencies
5. Verify compatibility
6. Document changes

## Safety Checks

- Backup original code
- Incremental changes
- Validate each step
- Maintain git history
```

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

## References

claude-agents/
└── templates/
    └── basic-agent.md (example basic agent)

For more information:
- Claude Code Agents Documentation: https://code.claude.com/docs/en/agents
- Task Tool Documentation: https://code.claude.com/docs/en/tools/task
