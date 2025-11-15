# Claude Skills Collection

A comprehensive plugin providing modular skills for Claude Code, covering multiple programming languages, development tools, workflow orchestration, and software development best practices.

## Overview

This plugin equips Claude with specialized knowledge across:

- **Programming Languages**: Elixir (Phoenix, OTP, testing, anti-patterns), Rust
- **Development Tools**: Git, mise (runtime manager), Nushell (modern shell)
- **Workflow Orchestration**: Dagu (workflows, Web UI, REST API)
- **UI Development & Design**: daisyUI, Web Accessibility, Material Design 3
- **Development Practices**: Technical documentation, code review

## Installation

Add this repository as a marketplace source and install:

```
/plugin marketplace add vinnie357/claude-skills
/plugin install claude-skills
```

Verify the installation:

```
/plugin list
```

### Manual Installation (Alternative)

If you prefer to install manually or use a local version:

```bash
git clone https://github.com/vinnie357/claude-skills.git ~/.claude/plugins/claude-skills
```

Then restart Claude Code or reload the window.

## Usage

Skills are automatically available once the plugin is installed. Claude will activate relevant skills based on your task context.

## Available Skills

### Elixir Development

- **elixir/anti-patterns** - Identify and refactor Elixir code smells and anti-patterns based on official Elixir documentation
- **elixir/phoenix** - Phoenix web framework development including LiveView, contexts, channels, and best practices
- **elixir/otp** - OTP behaviors (GenServer, Supervisor, Task, Agent) and concurrency patterns
- **elixir/testing** - ExUnit testing, property-based testing, mocks, and test organization
- **elixir/config** - Elixir configuration best practices, runtime vs compile-time config, Config module usage

### Rust Development

- **rust** - Comprehensive Rust language guidance covering ownership, borrowing, lifetimes, error handling, async programming, traits, and best practices

### Development Tools

- **git** - Git operations, branching strategies, commit conventions, conflict resolution, and GitHub/GitLab workflows
- **mise** - Development environment management, tool version control, environment variables, and task automation
- **nushell** - Modern shell with structured data pipelines, cross-platform scripting, and data transformations

### Workflow Orchestration

- **dagu/workflows** - Authoring Dagu workflow definitions with YAML, scheduling, dependencies, and error handling
- **dagu/webui** - Using the Dagu web interface for workflow management and monitoring
- **dagu/rest-api** - Programmatic workflow control via Dagu's REST API

### UI Development & Design

- **daisyui** - daisyUI component library for Tailwind CSS with pre-built UI components and theming
- **accessibility** - Web accessibility standards, WCAG guidelines, ARIA, and inclusive design
- **material-design** - Material Design 3 (Material You) design system, components, and best practices

### General Development

- **documentation** - Writing technical documentation, README files, API docs, and inline documentation
- **code-review** - Code review best practices covering correctness, security, performance, and maintainability
- **twelve-factor-app** - Twelve-Factor App methodology for building modern, scalable, maintainable applications
- **anti-fabrication** - Ensure factual accuracy by validating claims through tool execution, avoiding superlatives and unsubstantiated metrics

## Available Commands

This plugin includes slash commands for common workflows:

- **/configure-skills** - View and configure plugin settings and available skill sets
- **/gcms** - Generate conventional commit message suggestions based on current git changes
- **/research** - Research topics and create comprehensive planning documentation in `research/` directory
- **/research-skill** - Research topics and create Agent Skills following the Agent Skills Specification

### Examples

**Working with Elixir:**
- "Review this GenServer implementation for anti-patterns"
- "Help me write tests for this Phoenix LiveView"
- "What's the best way to structure this context in Phoenix?"

**Git Operations:**
- "Create a conventional commit message for these changes"
- "How do I rebase my feature branch?"
- "Help me resolve this merge conflict"

**Rust Development:**
- "Explain this lifetime error"
- "How do I handle errors with Result in this function?"
- "Review this code for Rust best practices"

**Documentation:**
- "Help me write a README for this project"
- "Document this API endpoint"
- "Create docstrings for these functions"

**Workflow Orchestration:**
- "Create a Dagu workflow for this ETL pipeline"
- "How do I trigger this workflow via the API?"
- "Add retry logic to this workflow step"

**UI Development:**
- "Create a card component with daisyUI"
- "Make this form accessible for screen readers"
- "Apply Material Design 3 principles to this interface"

## Configuration

### Customize Active Skills

Edit `.claude-plugin/plugin.json` to control which skills are loaded:

```json
{
  "skills": [
    "skills/elixir/anti-patterns",
    "skills/git",
    "skills/documentation"
  ]
}
```

### Using the Configure Command

Run `/configure-skills` in Claude Code to see available skill sets and customization options.

## Skill Structure

Skills follow the progressive disclosure pattern:

```
skills/
  ├── topic/
  │   ├── SKILL.md          # Core skill definition
  │   └── references/       # Detailed reference materials
  │       ├── guide.md
  │       └── examples.md
```

- **SKILL.md**: Concise skill definition with activation criteria and core guidance
- **references/**: Detailed documentation loaded on-demand when needed

## Creating Custom Skills

You can add your own skills to this plugin:

1. Create a new directory under `skills/`:
   ```bash
   mkdir -p skills/my-topic
   ```

2. Create `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: my-skill
   description: Brief description of what this skill helps with
   ---

   # Skill content here
   ```

3. Add to `plugin.json`:
   ```json
   {
     "skills": [
       "skills/my-topic",
       ...
     ]
   }
   ```

4. Optionally add reference materials in `skills/my-topic/references/`

See the [Claude Skills Documentation](https://github.com/anthropics/skills) for best practices.

## Sources and Attribution

This plugin is built on official documentation from:

- **Elixir**: [HexDocs](https://hexdocs.pm/elixir/)
- **Phoenix**: [Phoenix Framework](https://www.phoenixframework.org/)
- **Rust**: [The Rust Programming Language](https://doc.rust-lang.org/stable/)
- **mise**: [mise Documentation](https://mise.jdx.dev/)
- **Nushell**: [Nushell Book](https://www.nushell.sh/book/)
- **Dagu**: [Dagu Documentation](https://docs.dagu.cloud/)

See `promptlog/sources.md` for complete source documentation.

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Add or improve skills
4. Submit a pull request

### Contribution Guidelines

- Follow the progressive disclosure pattern (lean SKILL.md, detailed references/)
- Use imperative/infinitive form in skill instructions
- Test skills with real-world scenarios
- Update `plugin.json` when adding new skills
- Document sources in `promptlog/sources.md`

## Development

### Project Structure

```
claude-skills/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── commands/
│   └── configure-skills.md  # Configuration command
├── skills/
│   ├── elixir/             # Elixir skills
│   ├── rust/               # Rust skills
│   ├── git/                # Git skills
│   ├── mise/               # mise skills
│   ├── nushell/            # Nushell skills
│   ├── dagu/               # Dagu skills
│   ├── documentation/      # Documentation skills
│   └── code-review/        # Code review skills
├── promptlog/
│   └── sources.md          # Source documentation
├── LICENSE                 # MIT License
└── README.md              # This file
```

### Testing Skills

Test skills by:
1. Using them in real development scenarios
2. Asking Claude to apply the skill to sample code
3. Verifying skill activation based on context
4. Checking that references load correctly when needed

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Anthropic](https://www.anthropic.com/) for Claude and the Skills framework
- [Claude Code](https://claude.com/claude-code) for the plugin system
- Open source communities maintaining Elixir, Rust, Git, mise, Nushell, and Dagu

## Support

- **Issues**: [GitHub Issues](https://github.com/vinnie/claude-skills/issues)
- **Discussions**: [GitHub Discussions](https://github.com/vinnie/claude-skills/discussions)
- **Documentation**: [Claude Skills Guide](https://github.com/anthropics/skills)

## Roadmap

Future skill additions:
- Python development skills
- TypeScript/JavaScript skills
- Docker and containerization
- Kubernetes orchestration
- CI/CD pipelines
- Database design and optimization
- API design and REST conventions
- Security best practices

## Version History

### 0.1.0 (Initial Release)
- Elixir skills (anti-patterns, Phoenix, OTP, testing)
- Rust language skills
- Development tools (Git, mise, Nushell)
- Dagu workflow orchestration
- UI development (daisyUI, accessibility, Material Design 3)
- Documentation and code review skills
