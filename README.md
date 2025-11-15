# Claude Skills Marketplace

A curated collection of modular, self-contained skills that extend Claude's capabilities with specialized knowledge across multiple programming languages, development tools, workflow orchestration, and software development best practices.

## Quick Start

### Installation

Add the marketplace and install plugins:

```bash
# Add the vinnie357 marketplace
/plugin marketplace add vinnie357/claude-skills

# Install all skills (meta-plugin)
/plugin install claudio@vinnie357

# Or install individual plugins selectively:
/plugin install core@vinnie357        # Git, documentation, code review, accessibility
/plugin install elixir@vinnie357      # Elixir, Phoenix, OTP, testing
/plugin install rust@vinnie357        # Rust language features
/plugin install dagu@vinnie357        # Workflow orchestration
/plugin install ui@vinnie357          # daisyUI, accessibility, Material Design
/plugin install claude-code@vinnie357 # Plugin marketplace management tools
```

Verify installation:

```bash
/plugin list
```

## Available Plugins

### `claudio` - Complete Bundle

Meta-plugin that installs all available skills from all other plugins. Install this for the full experience.

**Keywords**: all, complete, bundle

### `core` - Essential Development Skills

Fundamental development tools and best practices.

**Skills:**
- **git** - Git operations, conventional commits, branching, conflict resolution
- **mise** - Development environment and tool version management
- **nushell** - Modern shell with structured data pipelines
- **documentation** - Technical writing, README files, API documentation
- **code-review** - Code review best practices for security and maintainability
- **accessibility** - Web accessibility standards (WCAG, ARIA)
- **material-design** - Material Design 3 design system
- **twelve-factor-app** - Cloud-native application design principles
- **anti-fabrication** - Ensure factual accuracy through tool validation

**Keywords**: git, documentation, code-review, tools

### `elixir` - Elixir Development

Comprehensive Elixir and Phoenix development skills.

**Skills:**
- **anti-patterns** - Identify and refactor Elixir code smells and anti-patterns
- **phoenix** - Phoenix framework with LiveView, contexts, and channels
- **otp** - OTP behaviors (GenServer, Supervisor, Task, Agent)
- **testing** - ExUnit testing, property-based testing, mocks
- **config** - Runtime vs compile-time configuration best practices

**Keywords**: elixir, phoenix, otp, beam

### `rust` - Rust Programming

Rust language features and best practices.

**Skills:**
- **rust** - Ownership, borrowing, lifetimes, error handling, async programming

**Keywords**: rust, systems-programming, memory-safety

### `dagu` - Workflow Orchestration

Dagu workflow orchestration and automation.

**Skills:**
- **workflows** - YAML workflow authoring, scheduling, dependencies
- **webui** - Dagu web interface for workflow management
- **rest-api** - Programmatic workflow control via REST API

**Keywords**: dagu, workflow, orchestration

### `ui` - UI Development

UI framework and component library skills.

**Skills:**
- **daisyui** - daisyUI component library with Tailwind CSS theming

**Keywords**: ui, daisyui, tailwind

### `claude-code` - Plugin Development Tools

Claude Code plugin marketplace management and validation.

**Skills:**
- **plugin-marketplace** - Marketplace.json schema, validation, management
- **plugin** - Plugin.json schema, validation, creation
- **commands** - Creating custom slash commands
- **agents** - Creating specialized agents
- **skills** - Creating Agent Skills (complete guide)
- **hooks** - Event-driven hooks and automations

**Includes Nushell Scripts:**
- Marketplace validation and initialization
- Plugin validation and formatting
- Dependency graph analysis
- Schema compliance checking

**Keywords**: claude-code, marketplace, validation

## Usage

Skills are automatically activated by Claude based on task context once plugins are installed.

### Examples

**Elixir Development:**
```
"Review this GenServer implementation for anti-patterns"
"Help me write tests for this Phoenix LiveView"
"What's the best way to structure this context?"
```

**Git Operations:**
```
"Create a conventional commit message for these changes"
"How do I rebase my feature branch?"
"Help me resolve this merge conflict"
```

**Rust Development:**
```
"Explain this lifetime error"
"How do I handle errors with Result?"
"Review this code for Rust best practices"
```

**Workflow Orchestration:**
```
"Create a Dagu workflow for this ETL pipeline"
"How do I trigger this workflow via the API?"
"Add retry logic to this workflow step"
```

**UI Development:**
```
"Create a card component with daisyUI"
"Make this form accessible for screen readers"
"Apply Material Design 3 principles to this interface"
```

## Plugin Architecture

The marketplace uses a tiered architecture with root-level plugins:

```
claude-skills/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace definition
├── claude-code/            # Plugin development tools
├── core/                   # Essential development skills
├── dagu/                   # Workflow orchestration
├── elixir/                 # Elixir development
├── rust/                   # Rust programming
└── ui/                     # UI frameworks
```

Each plugin contains:
```
plugin-name/
├── .claude-plugin/
│   └── plugin.json        # Plugin manifest
├── skills/                # Skill definitions
│   ├── skill-1/
│   │   ├── SKILL.md
│   │   ├── references/    # Detailed docs (optional)
│   │   └── scripts/       # Executable scripts (optional)
│   └── skill-2/
└── sources.md             # Source attribution
```

## Selective Installation

Install only the plugins you need:

```bash
# Frontend developer
/plugin install core@vinnie357
/plugin install ui@vinnie357

# Elixir developer
/plugin install core@vinnie357
/plugin install elixir@vinnie357

# Rust developer
/plugin install core@vinnie357
/plugin install rust@vinnie357

# DevOps/Platform engineer
/plugin install core@vinnie357
/plugin install dagu@vinnie357

# Plugin developer
/plugin install claude-code@vinnie357
```

## What Are Agent Skills?

Agent Skills are organized directories containing instructions, scripts, and resources that Claude can dynamically discover and load. They enable a single general-purpose agent to gain domain-specific expertise without requiring separate custom agents for each use case.

### Key Benefits

- **Modularity**: Self-contained packages that can be mixed and matched
- **Reusability**: Share and distribute expertise across projects and teams
- **Progressive Disclosure**: Load context only when needed, keeping interactions efficient
- **Specialization**: Deep domain knowledge without sacrificing generality

### How Skills Work

Skills operate on progressive disclosure across multiple levels:

1. **Discovery**: Agent prompts include only skill names and descriptions
2. **Activation**: Claude loads the full SKILL.md when the skill is relevant
3. **Deep Context**: Additional files load only when needed for specific scenarios

This tiered approach maintains efficient context windows while supporting complex skill requirements.

## Creating Custom Skills

You can contribute skills to existing plugins or create new ones:

### Adding to Existing Plugins

1. Create a new skill directory:
   ```bash
   mkdir -p elixir/skills/my-skill
   ```

2. Create `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: my-skill
   description: Brief description of what this skill helps with
   license: MIT
   ---

   # My Skill

   Instructions and guidance...
   ```

3. Update the plugin's `plugin.json`:
   ```json
   {
     "skills": [
       "./skills/my-skill"
     ]
   }
   ```

4. Document sources in the plugin's `sources.md`

See the [Agent Skills Specification](https://github.com/anthropics/skills/blob/main/agent_skills_spec.md) for complete guidelines.

## Plugin Development

The `claude-code` plugin provides comprehensive tools for plugin and marketplace development:

- Complete schema documentation for marketplace.json and plugin.json
- Nushell validation scripts for automated compliance checking
- Skills for creating commands, agents, skills, and hooks
- Template generation and formatting tools

Install it to build your own Claude Code plugins:

```bash
/plugin install claude-code@vinnie357
```

## Testing

The repository includes automated validation tests for the marketplace and all 7 plugins (including the claudio meta-plugin).

### Requirements

- [Nushell](https://www.nushell.sh/) - Modern shell for running validation scripts
- [mise](https://mise.jdx.dev/) - Development tool manager (optional, for running tasks)

### Quick Start

```bash
# Install mise (if not already installed)
curl https://mise.run | sh

# Run all tests (validates marketplace + all 7 plugins)
mise test

# Test specific plugin
mise test:plugin elixir
mise test:plugin claudio  # Test the meta-plugin

# Test marketplace only
mise test:marketplace

# Test all plugins
mise test:plugins
```

### What Gets Tested

- **Marketplace validation**: Required fields, plugin entries, JSON structure
- **Plugin validation** (all 7 plugins including claudio):
  - Name matches directory (or root for claudio)
  - No invalid marketplace-only fields
  - Kebab-case naming
  - Skill paths exist

### Maintaining the Meta-Plugin

The `claudio` meta-plugin aggregates all skills from all other plugins. When you add or remove skills:

```bash
# Update claudio plugin.json with all current skills
mise update-claudio

# Preview changes first
mise update-claudio --dry-run

# See detailed output
mise update-claudio --verbose
```

This automatically collects all skills from all plugins and updates `.claude-plugin/plugin.json`.

### Without mise

You can run the Nushell scripts directly:

```bash
# All tests
nu test/validate-all.nu

# Specific plugin
nu test/validate-plugin.nu elixir

# Update claudio
nu .claude-plugin/scripts/update-claudio.nu
```

See [test/README.md](test/README.md) for complete testing documentation.

## Sources and Attribution

Each plugin maintains its own `sources.md` file documenting the official documentation, guides, and resources used to create the skills.

Primary sources include:
- **Elixir**: [HexDocs](https://hexdocs.pm/elixir/), [Phoenix Framework](https://www.phoenixframework.org/)
- **Rust**: [The Rust Programming Language](https://doc.rust-lang.org/stable/)
- **mise**: [mise Documentation](https://mise.jdx.dev/)
- **Nushell**: [Nushell Book](https://www.nushell.sh/book/)
- **Dagu**: [Dagu Documentation](https://docs.dagu.cloud/)
- **Claude Code**: [Official Plugins Documentation](https://code.claude.com/docs/en/plugins)

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Add or improve skills following the Agent Skills Specification
4. Document sources in the appropriate plugin's `sources.md`
5. Submit a pull request

### Contribution Guidelines

- Follow progressive disclosure pattern (lean SKILL.md, detailed references/)
- Use imperative/infinitive form in skill instructions
- Test skills with real-world scenarios
- Update plugin.json when adding new skills
- Include proper YAML frontmatter with name, description, and license

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Additional Resources

- **Official Anthropic Skills Repository**: https://github.com/anthropics/skills
- **Claude Skills Cookbook**: https://github.com/anthropics/claude-cookbooks/tree/main/skills
- **Agent Skills Blog Post**: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- **Agent Skills Specification**: https://github.com/anthropics/skills/blob/main/agent_skills_spec.md
- **Claude Code Plugins**: https://code.claude.com/docs/en/plugins
- **Plugin Marketplaces**: https://code.claude.com/docs/en/plugin-marketplaces

## Support

- **Issues**: [GitHub Issues](https://github.com/vinnie357/claude-skills/issues)
- **Discussions**: [GitHub Discussions](https://github.com/vinnie357/claude-skills/discussions)

## Version History

### 1.0.0 (Current)
- Tiered marketplace architecture with selective plugin installation
- 7 plugins: claudio (meta), claude-code, core, elixir, rust, dagu, ui
- 25+ skills covering multiple programming languages and development tools
- Comprehensive plugin development tools with Nushell validation scripts
