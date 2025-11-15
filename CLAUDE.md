# Claude Skills Project

This repository contains modular, self-contained skills that extend Claude's capabilities with specialized knowledge, workflows, and tools.

## What Are Agent Skills?

Agent skills are organized directories containing instructions, scripts, and resources that Claude can dynamically discover and load. They enable a single general-purpose agent to gain domain-specific expertise without requiring separate custom agents for each use case.

Skills function as composable, reusable packages that transform Claude into a domain-specific agent equipped with procedural knowledge and specialized capabilities.

## Why Skills Matter

General-purpose AI agents like Claude Code need domain-specific expertise to handle real-world work effectively. Rather than building separate custom agents for each use case, skills provide:

- **Modularity**: Self-contained packages that can be mixed and matched
- **Reusability**: Share and distribute expertise across projects and teams
- **Progressive Disclosure**: Load context only when needed, keeping interactions efficient
- **Specialization**: Deep domain knowledge without sacrificing generality

## How Skills Work

Skills operate on a principle of progressive disclosure across multiple levels:

### Level 1: Discovery
Agent system prompts include only skill names and descriptions, allowing Claude to decide when each skill is relevant based on the task at hand.

### Level 2: Activation
When Claude determines a skill applies, it loads the full `SKILL.md` file into context, gaining access to the complete procedural knowledge and guidelines.

### Level 3+: Deep Context
Additional bundled files (like references, forms, or documentation) load only when needed for specific scenarios, keeping token usage efficient.

This tiered approach maintains efficient context windows while supporting potentially unbounded skill complexity.

## Development Standards

### Scripting Language

**Nushell is the preferred scripting language** for this project. Use Nushell for:
- Validation scripts (test suite)
- mise task definitions
- Automation and tooling scripts
- Any new scripting needs

**Why Nushell:**
- Cross-platform compatibility (macOS, Linux, Windows)
- Structured data pipelines for working with JSON, TOML, and other formats
- Built-in commands for common operations
- Consistent syntax across all project scripts
- Modern error handling and type safety

**When to use other languages:**
- Only use bash/shell scripts when absolutely necessary for compatibility
- Document the reason when deviating from Nushell

## Skill Structure

### Minimal Requirements

Every skill must have:

```
skill-name/
└── SKILL.md
```

### Complete Structure

More complex skills can include additional resources:

```
skill-name/
├── SKILL.md           # Required: Core skill definition
├── scripts/           # Optional: Executable code for deterministic tasks
├── references/        # Optional: Documentation loaded on-demand
└── assets/            # Optional: Templates, images, boilerplate
```

### SKILL.md Format

Each `SKILL.md` file must begin with YAML frontmatter followed by Markdown content:

```markdown
---
name: skill-name
description: Concise explanation of when Claude should use this skill
license: MIT
---

# Skill Name

Main instructional content goes here...
```

#### Required YAML Properties

- `name`: Hyphen-case identifier matching directory name (lowercase alphanumeric and hyphens only)
- `description`: Explains the skill's purpose and when Claude should utilize it

#### Optional YAML Properties

- `license`: License name or filename reference
- `allowed-tools`: Pre-approved tools list (Claude Code support only)
- `metadata`: Key-value string pairs for client-specific properties

#### Markdown Body

The content section has no restrictions and should contain:

- When to activate the skill
- Core procedural knowledge
- Best practices and guidelines
- Examples and patterns
- References to additional resources (if any)

## Creating Skills

Follow this seven-step workflow for creating effective skills:

### 1. Understanding Through Examples

Gather concrete use cases to clarify what the skill should support. Real-world examples reveal actual needs better than theoretical requirements.

### 2. Planning Resources

Analyze examples to identify needed components:
- **Scripts**: For tasks requiring deterministic reliability or that would need repeated rewriting
- **References**: Documentation to load into context as needed
- **Assets**: Output files like templates or boilerplate (not loaded into context)

### 3. Initialization

Create the skill directory structure with the required `SKILL.md` file. Ensure the directory name matches the `name` property exactly.

### 4. Editing

Develop resource files and update `SKILL.md` with:
- Purpose and activation criteria
- Usage guidelines and best practices
- Implementation details and examples
- References to supplementary files

Use imperative/infinitive form rather than second-person instruction for clarity. Keep core procedural information in `SKILL.md` and detailed reference material in separate files.

### 5. Documentation

**Document all sources in the plugin's `sources.md` file**. For each skill created, record:
- URLs of documentation, guides, and references used
- Purpose of each source
- Key topics and concepts extracted
- Date accessed (if relevant)

This maintains traceability and helps others understand the skill's foundation. Each plugin maintains its own `sources.md` file (e.g., `elixir/sources.md`, `core/sources.md`) with clear section headers and bullet points.

### 6. Validation

Test the skill with representative scenarios to ensure:
- Claude activates it appropriately
- Instructions are clear and actionable
- Progressive disclosure works effectively
- Token usage remains efficient

### 7. Iteration

Refine based on real-world usage feedback. Monitor how Claude actually uses the skill and adjust the description and content accordingly.

## Best Practices

### Start with Evaluation

Identify specific capability gaps by testing agents on representative tasks. Build skills incrementally to address actual shortcomings rather than anticipated needs.

### Structure for Scale

Split unwieldy `SKILL.md` files into separate referenced documents:
- Keep commonly-used contexts together
- Separate mutually exclusive information to reduce token usage
- Use progressive disclosure to load details only when needed

### Consider Claude's Perspective

The skill name and description heavily influence when Claude activates it. Pay particular attention to:
- **Name**: Should be clear and reflect the domain (e.g., `git-operations`, `elixir-phoenix`)
- **Description**: Should specify both what the skill does and when to use it

Monitor real usage patterns and iterate based on actual behavior.

### Iterate Collaboratively

Work with Claude to capture successful approaches and common mistakes into reusable skill components. Ask Claude to self-reflect on what contextual information actually matters.

### Write for AI Consumption

Use clear, imperative language that Claude can follow:
- ✅ "Follow the Conventional Commits specification"
- ✅ "Use descriptive branch names with type prefixes"
- ❌ "You should try to use descriptive names when possible"

Include concrete examples wherever possible to illustrate patterns and approaches.

### Security Considerations

Install skills only from trusted sources. When evaluating unfamiliar skills:
- Thoroughly audit bundled files and scripts
- Review code dependencies
- Examine instructions directing Claude to connect with external services
- Verify the skill doesn't request sensitive information or dangerous operations

### Anti-Fabrication Requirements

All skills MUST adhere to strict anti-fabrication requirements to ensure factual, measurable content.

**Core Principles:**
- Base all outputs on actual analysis of real data using tool execution
- Execute Read, Glob, Bash, or other validation tools before making claims
- Mark uncertain information as "requires analysis", "needs validation", or "requires investigation"
- Use precise, factual language without superlatives or unsubstantiated performance claims
- Execute tests before marking tasks complete and report actual results
- Validate integration recommendations through actual framework detection using tool analysis

**Prohibited Language and Claims:**
- **Superlatives**: Avoid "excellent", "comprehensive", "advanced", "optimal", "perfect"
- **Unsubstantiated Metrics**: Never fabricate percentages, success rates, or performance numbers
- **Assumed Capabilities**: Don't claim features exist without tool verification
- **Generic Claims**: Replace vague statements with specific, measurable observations
- **Fabricated Testing**: Never report test results without actual execution

**Time and Effort Estimation Rule:**
- Never provide time estimates, effort estimates, or completion timelines without actual measurement or analysis
- If estimates are requested, execute tools to analyze scope (e.g., count files, measure complexity, assess dependencies) before providing data-backed estimates
- When estimates cannot be measured, explicitly state "timeline requires analysis of [specific factors]"
- Avoid fabricated scheduling language like "15 minutes", "2 hours", "quick task" without factual basis

**Validation Requirements:**
- **File Claims**: Use Read or Glob tools before claiming files exist or contain specific content
- **System Integration**: Use Bash or appropriate tools to verify system capabilities
- **Framework Detection**: Execute actual detection logic before claiming framework presence
- **Test Results**: Only report test outcomes after actual execution with tool verification
- **Performance Claims**: Base any performance statements on actual measurement or analysis

## Skills in This Repository

This repository is organized as a **tiered marketplace** with root-level plugins. Each plugin is independently installable and contains its own set of skills.

**Available Plugins:**
- **claudio** - Meta-plugin at root that installs all 25 skills from all other plugins
- **claude-code** - Plugin marketplace management and validation tools (6 skills)
- **core** - Essential development skills: Git, documentation, code review, accessibility (9 skills)
- **elixir** - Elixir and Phoenix development (5 skills)
- **rust** - Rust programming language (1 comprehensive skill)
- **dagu** - Workflow orchestration (3 skills)
- **ui** - UI frameworks and design (1 skill)

**Total**: 7 plugins with 25 skills covering multiple programming languages, development tools, and best practices.

**Note**: The `claudio` meta-plugin is maintained via `mise update-claudio` and automatically includes all skills from all other plugins.

Each plugin follows the Agent Skills Specification with `SKILL.md` files containing skill definitions and optional `references/` directories for detailed documentation.

See `README.md` for the complete catalog of plugins, skills, and installation instructions.

## Using the Marketplace

This repository is designed as a Claude Code plugin marketplace. Users can selectively install plugins based on their needs.

### Installation

```bash
# Add the vinnie357 marketplace
/plugin marketplace add vinnie357/claude-skills

# Install all skills (meta-plugin)
/plugin install claudio@vinnie357

# Or install individual plugins selectively
/plugin install core@vinnie357        # Essential development skills
/plugin install elixir@vinnie357      # Elixir development
/plugin install rust@vinnie357        # Rust programming
/plugin install dagu@vinnie357        # Workflow orchestration
/plugin install ui@vinnie357          # UI frameworks
/plugin install claude-code@vinnie357 # Plugin development tools
```

### Marketplace Architecture

The repository uses a tiered architecture with root-level plugins:

```
claude-skills/
├── .claude-plugin/
│   └── marketplace.json     # Marketplace definition
├── claude-code/             # Plugin development tools
├── core/                    # Essential development skills
├── dagu/                    # Workflow orchestration
├── elixir/                  # Elixir development
├── rust/                    # Rust programming
└── ui/                      # UI frameworks
```

Each plugin is independently installable and maintains its own:
- `plugin.json` - Plugin manifest
- `skills/` - Skill definitions
- `sources.md` - Source attribution

## Contributing Skills

When adding new skills to this repository:

1. **Choose the right plugin**: Add skills to the appropriate plugin (elixir, rust, core, etc.)
2. **Choose a clear name**: Use hyphen-case that reflects the domain
3. **Write a precise description**: Help Claude understand when to activate the skill
4. **Follow the structure**: Use the standard directory layout and `SKILL.md` format
5. **Include examples**: Concrete examples are more valuable than abstract guidelines
6. **Test thoroughly**: Verify Claude activates and uses the skill appropriately
7. **Document sources**: Add source attribution to the plugin's `sources.md` file
8. **Update plugin.json**: Add the skill path to the plugin's manifest
9. **Update claudio**: Run `mise update-claudio` to sync the meta-plugin
10. **Validate changes**: Run `mise test` to validate marketplace and all plugin schemas
11. **Consider scope**: Each skill should have a focused, well-defined purpose

## Testing and Validation

Before committing changes, validate the marketplace and all plugins:

```bash
mise test                    # Validate all (marketplace + 7 plugins including claudio)
mise test:plugin <name>      # Validate specific plugin
mise test:marketplace        # Validate marketplace.json only
mise test:plugins            # Validate all plugin.json files
```

Tests validate all 7 plugins (claude-code, core, dagu, elixir, rust, ui, claudio):
- Required fields and JSON structure
- Plugin names match directories (kebab-case)
- No invalid marketplace-only fields in plugin.json
- Skill paths exist (claudio has special handling as meta-plugin)

### Maintaining the Claudio Meta-Plugin

The `claudio` meta-plugin at `.claude-plugin/plugin.json` aggregates all skills from all other plugins. After adding/removing skills:

```bash
mise update-claudio          # Update claudio with all current skills
mise update-claudio --dry-run  # Preview changes first
```

Always run `mise test` after updating to validate changes.

Requires: [Nushell](https://www.nushell.sh/). See `test/README.md` for details.

## Skill Architecture Principles

### Atomic and Focused

Each skill should address a specific domain or capability:
- ✅ Separate skills for `git-operations` and `code-review`
- ❌ One giant skill for "all development practices"

### Self-Contained

Skills should be independently usable without requiring other skills:
- Include all necessary context in the skill itself
- Reference external resources explicitly
- Don't assume other skills are loaded

### Iteratively Refined

Skills improve through real-world usage:
- Start with minimal viable content
- Add detail based on actual usage patterns
- Remove unused or ineffective content
- Adjust activation criteria based on when Claude actually needs the skill

## Technical Specification

This project follows the **Agent Skills Specification v1.0** (2025-10-16).

### Directory Naming Rules

- Lowercase alphanumeric characters and hyphens only
- Must exactly match the `name` property in `SKILL.md`
- Use descriptive, domain-specific names

### YAML Frontmatter Requirements

- Must be valid YAML at the start of `SKILL.md`
- Must include `name` and `description`
- Optional properties should use clear, standard values
- Metadata keys should use reasonably unique naming to prevent conflicts

### Content Guidelines

- Markdown body has no structural restrictions
- Use GitHub-flavored Markdown for consistency
- Include code blocks with appropriate syntax highlighting
- Organize with clear headings and sections
- Link to supplementary files using relative paths

## Examples from Other Domains

Skills can be created for any domain where Claude needs specialized knowledge:

- **Programming Languages**: Python patterns, Rust safety, Go idioms
- **Frameworks**: React hooks, Django ORM, Rails conventions
- **Tools**: Docker compose, Kubernetes manifests, Terraform modules
- **Domains**: Security testing, API design, Database optimization
- **Workflows**: CI/CD pipelines, Release management, Incident response
- **Standards**: Accessibility guidelines, API specifications, Code style

The key is identifying areas where having deep, specialized knowledge improves Claude's effectiveness on real tasks.

## Practical Learning with the Skills Cookbook

The [Claude Skills Cookbook](https://github.com/anthropics/claude-cookbooks/tree/main/skills) provides hands-on learning resources for creating and using skills with production-ready examples.

### Built-in Document Skills

Claude includes specialized built-in skills for document generation:

| Skill | ID | Capability |
|-------|-----|-----------|
| Excel | `xlsx` | Create workbooks with formulas, charts, and formatting |
| PowerPoint | `pptx` | Generate professional presentations with slides and layouts |
| PDF | `pdf` | Produce formatted PDF documents |
| Word | `docx` | Create rich-formatted Word documents |

These skills demonstrate how specialized capabilities can be packaged and activated on-demand.

### Cookbook Learning Modules

The cookbook includes three progressive Jupyter notebooks:

1. **Introduction**: API setup, basic document creation with Excel/PowerPoint/PDF skills
2. **Financial Applications**: Building dashboards, portfolio analysis, cross-format workflows
3. **Custom Development**: Creating domain-specific skills with real business logic

Each module includes production-ready code that can be adapted for immediate deployment.

### Working with Skill-Generated Files

Skills that create files (like the document skills) reference outputs using `file_id`. The workflow is:

```
Skill creates file → Returns file_id → Use Files API → Download to local storage
```

Important considerations:
- Files are stored temporarily on Anthropic's servers
- Use the Files API to download generated content
- Save files locally promptly as temporary storage is time-limited

### API Configuration for Skills

When using skills programmatically via the API, enable these beta headers:

```python
client = anthropic.Anthropic(
    api_key=os.environ.get("ANTHROPIC_API_KEY"),
)

# Enable Skills features
headers = {
    "anthropic-beta": "code-execution-2025-08-25,files-api-2025-04-14,skills-2025-10-02"
}
```

- `code-execution-2025-08-25`: Executes skill code
- `files-api-2025-04-14`: Downloads generated files
- `skills-2025-10-02`: Activates Skills feature

### Performance Optimization

The cookbook demonstrates several optimization strategies:

- **Progressive Disclosure**: Load context only when needed to minimize token usage
- **Batch Operations**: Process multiple files in single conversations
- **Skill Composition**: Combine multiple skills for complex workflows
- **Container Reuse**: Cache loaded skills across conversations

### Common Use Cases from the Cookbook

**Financial Reporting**:
- Automated quarterly reports with data analysis
- Budget variance analysis with visualizations
- Investment portfolio dashboards

**Data Analysis**:
- Excel analytics with complex formulas
- Automated pivot table generation
- Statistical visualization across formats

**Document Automation**:
- Branded presentation generation
- Multi-source report compilation
- Format conversion workflows

### Custom Skill Development Framework

The cookbook provides a template-based framework for custom skills:

```
custom_skill/
├── SKILL.md           # Required Claude instructions
├── scripts/           # Optional executable code
└── resources/         # Optional templates and data
```

This structure aligns with the Agent Skills Specification while adding cookbook-specific patterns for business applications.

## Plugin Development

The `claude-code` plugin provides comprehensive tools for building your own Claude Code plugins and marketplaces:

### Skills
- **plugin-marketplace** - Marketplace.json schema, validation, and management
- **plugin** - Plugin.json schema, validation, and creation
- **commands** - Creating custom slash commands
- **agents** - Creating specialized agents
- **skills** - Creating Agent Skills (complete guide)
- **hooks** - Event-driven hooks and automations

### Validation Tools

The plugin includes Nushell scripts for automated validation:
- `validate-marketplace.nu` - Complete marketplace schema validation
- `validate-plugin.nu` - Plugin.json schema validation
- `validate-dependencies.nu` - Dependency graph analysis
- `init-marketplace.nu` - Interactive marketplace template generation
- `init-plugin.nu` - Interactive plugin.json generation
- `format-marketplace.nu` - JSON formatting and plugin sorting
- `format-plugin.nu` - Plugin.json formatting

Install the plugin to build your own plugins:

```bash
/plugin install claude-code@vinnie357
```

## Additional Resources

- **Official Anthropic Skills Repository**: https://github.com/anthropics/skills
- **Claude Skills Cookbook**: https://github.com/anthropics/claude-cookbooks/tree/main/skills
- **Skill-Creator Skill**: https://github.com/anthropics/skills/tree/main/skill-creator
- **Agent Skills Blog Post**: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- **Agent Skills Specification**: https://github.com/anthropics/skills/blob/main/agent_skills_spec.md
- **Claude Code Plugins**: https://code.claude.com/docs/en/plugins
- **Plugin Marketplaces**: https://code.claude.com/docs/en/plugin-marketplaces

## License

Skills in this repository should include license information in their YAML frontmatter. Refer to individual skill directories for specific licensing terms.
