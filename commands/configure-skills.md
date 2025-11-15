# Configure Claude Skills

Configure which skill sets are active for your project.

## Available Skill Sets

### Language-Specific Skills

**Elixir Development:**
- `elixir/anti-patterns` - Identify and refactor Elixir anti-patterns
- `elixir/phoenix` - Phoenix framework development guidance
- `elixir/otp` - OTP and concurrency patterns
- `elixir/testing` - ExUnit testing best practices

**Rust Development:**
- `rust` - Rust language, ownership, async, and best practices

### Development Tools

- `git` - Git operations, workflows, and conventions
- `mise` - Development environment management with mise
- `nushell` - Modern shell with structured data pipelines

### Workflow Orchestration

**Dagu:**
- `dagu/workflows` - Authoring Dagu workflow YAML files
- `dagu/webui` - Using the Dagu web interface
- `dagu/rest-api` - Dagu REST API integration

### General Development

- `documentation` - Writing technical documentation
- `code-review` - Code review best practices

## Current Configuration

All skills are currently active by default. Skills are loaded on-demand by Claude based on the task context.

## Customization

To customize which skills are available:

1. Edit `.claude-plugin/plugin.json`
2. Modify the `skills` array to include only desired skill paths
3. Reload Claude Code or restart the editor

Example - only Elixir and Git skills:

```json
{
  "skills": [
    "skills/elixir/anti-patterns",
    "skills/elixir/phoenix",
    "skills/elixir/otp",
    "skills/elixir/testing",
    "skills/git"
  ]
}
```

## Skill Organization

Skills are organized hierarchically:
- `skills/language/topic` - Language-specific skills
- `skills/tool` - Tool-specific skills
- `skills/general` - General development skills

## Adding Custom Skills

To add your own skills:

1. Create a new directory under `skills/`
2. Add a `SKILL.md` file with frontmatter:
   ```yaml
   ---
   name: my-skill
   description: Description of what the skill does
   ---
   ```
3. Add the skill path to `plugin.json`
4. Optionally add reference files in `references/` subdirectory

See [Claude Skills Documentation](https://github.com/anthropics/skills) for details on creating effective skills.

## Feedback

Found a skill useful or have suggestions? Open an issue or contribute improvements!
