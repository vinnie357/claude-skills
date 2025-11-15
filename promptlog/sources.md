# Source Documentation

This file documents the sources used to create the Claude Skills plugin.

## Skills Documentation

### Agent Skills Concept
- **URL**: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- **Purpose**: Understanding what Claude skills are, how they work, and best practices for creating them
- **Key Concepts**: Progressive disclosure, skill structure, modular expertise packages

### Example Skills Repository
- **URL**: https://github.com/anthropics/skills/tree/main
- **Purpose**: Reference implementations and examples of various Claude skills
- **Categories**: Creative & Design, Development & Technical, Enterprise & Communication, Meta Skills, Document Skills

### Skill Creator Guide
- **URL**: https://github.com/anthropics/skills/blob/main/skill-creator/SKILL.md
- **Purpose**: Best practices and guidelines for creating effective Claude skills
- **Key Points**:
  - SKILL.md structure with YAML frontmatter
  - Progressive disclosure architecture
  - Imperative/infinitive form for instructions
  - Resource organization strategies

### Skills Cookbook
- **URL**: https://github.com/anthropics/claude-cookbooks/tree/main/skills
- **Purpose**: Practical examples and learning modules for creating and using skills with Claude
- **Key Topics**:
  - Built-in skills (Excel, PowerPoint, PDF, Word)
  - Progressive disclosure architecture
  - Financial applications and data analysis
  - Custom skill development
  - API configuration and file handling
  - Production-ready Jupyter notebooks

## Plugin Development

### Claude Code Plugins Documentation
- **URL**: https://code.claude.com/docs/en/plugins
- **Purpose**: Understanding how Claude Code plugins work and how to create them
- **Key Features**:
  - Plugin architecture and components
  - Commands, agents, skills, hooks structure
  - Marketplace and installation system
  - Plugin manifest (plugin.json) format

## Elixir-Specific Resources

### Elixir Anti-Patterns
- **URL**: https://hexdocs.pm/elixir/what-anti-patterns.html
- **Purpose**: Foundation for the Elixir anti-patterns skill
- **Categories**:
  - Code-related anti-patterns
  - Design-related anti-patterns
  - Process-related anti-patterns
  - Meta-programming-related anti-patterns

### Code-Related Anti-Patterns
- **URL**: https://hexdocs.pm/elixir/code-anti-patterns.html
- **Purpose**: Detailed code-level anti-patterns in Elixir
- **Topics**: Comments overuse, complex else clauses, dynamic atom creation, namespace trespassing, etc.

### Design-Related Anti-Patterns
- **URL**: https://hexdocs.pm/elixir/design-anti-patterns.html
- **Purpose**: Design and architectural anti-patterns in Elixir
- **Topics**: Alternative return types, boolean obsession, exceptions for control-flow, primitive obsession, etc.

### Elixir Config Module
- **URL**: https://hexdocs.pm/elixir/Config.html
- **Purpose**: Foundation for the Elixir config skill - application configuration management
- **Topics**:
  - Config module overview and migration from Mix.Config
  - config/config.exs (compile-time configuration)
  - config/runtime.exs (runtime configuration)
  - Configuration functions: config/2, config/3, config_env(), config_target()
  - import_config/1 for file imports
  - Deep-merging behavior for keyword lists
  - Library configuration limitations

### Elixir Application Module
- **URL**: https://hexdocs.pm/elixir/Application.html
- **Purpose**: Accessing application configuration at runtime vs compile-time
- **Topics**:
  - Application.compile_env/3 and Application.compile_env!/2 (compile-time)
  - Application.get_env/3 (runtime with defaults)
  - Application.fetch_env/2 and Application.fetch_env!/2 (runtime with explicit errors)
  - Runtime vs compile-time configuration trade-offs
  - Best practices for library vs application configuration
  - Configuration access patterns and anti-patterns

## Development Tools

### mise (polyglot runtime manager)
- **URL**: https://mise.jdx.dev/README.html
- **Purpose**: Development environment management and tool version control
- **Topics**: Runtime management, environment configuration, task running

### nushell (modern shell)
- **URL**: https://www.nushell.sh/book/
- **Purpose**: Modern, structured data shell with pipeline support
- **Topics**: Shell commands, data pipelines, structured data handling

## Rust Language Resources

### Rust Documentation
- **URL**: https://doc.rust-lang.org/stable/
- **Purpose**: Official Rust language documentation
- **Topics**: Rust language features, standard library, best practices, patterns

## Workflow and Orchestration Tools

### Dagu - Workflow Orchestration
- **URL**: https://docs.dagu.cloud/
- **Purpose**: Workflow orchestration tool with web UI and REST API
- **Topics**: Workflow authoring, web UI operations, REST API integration
- **Skills Created**:
  - Dagu Web UI skill
  - Dagu REST API skill
  - Dagu workflow authoring skill

## UI Frameworks and Libraries

### daisyUI - Tailwind CSS Components
- **URL**: https://daisyui.com/docs/intro/
- **Purpose**: Component library for Tailwind CSS with pre-built UI components
- **Topics**: UI components, theming, customization, responsive design

## Design and Accessibility Resources

### W3C Web Accessibility Initiative (WAI)
- **URL**: https://www.w3.org/WAI/fundamentals/accessibility-principles/
- **Purpose**: Foundation for the accessibility skill - comprehensive web accessibility principles
- **Topics**: WCAG guidelines, POUR principles (Perceivable, Operable, Understandable, Robust)
- **Key Concepts**:
  - Text alternatives for non-text content
  - Keyboard accessibility
  - Readable and understandable text
  - Robust content compatible with assistive technologies
  - ARIA (Accessible Rich Internet Applications)

### Material Design 3 Documentation
- **URL**: https://m3.material.io/
- **Purpose**: Foundation for the Material Design skill - Google's latest design system
- **Key Resources Used**:
  - **Typography**: https://m3.material.io/styles/typography/overview
  - **Color System**: https://m3.material.io/styles/color/system/overview
  - **Layout**: https://m3.material.io/foundations/layout/understanding-layout/overview
  - **Foundations**: https://m3.material.io/foundations
  - **Get Started**: https://m3.material.io/get-started
- **Topics**:
  - Dynamic color system with HCT color space
  - Typography scales and responsive text
  - Layout grids and breakpoints
  - Material You personalization
  - Component specifications (buttons, cards, chips, text fields)
  - Motion and animation principles
  - Accessibility-first design

### Material Design 3 Comprehensive Guide
- **URL**: https://oritop.co/google-material-design-a-complete-breakdown-of-material-design-3/
- **Purpose**: Supplementary resource for Material Design 3 overview and best practices
- **Topics**: MD2 vs MD3 comparison, dynamic color personalization, enhanced components, cross-platform consistency

## Software Design and Architecture

### 12-Factor App Methodology
- **Source**: Internal research document
- **Path**: `/Users/vinnie/github/claudio/research/software-design/12-factor-app-methodology.md`
- **Purpose**: Foundation for the 12-Factor App skill - cloud-native application design principles
- **Topics**:
  - 12 core factors: Codebase, Dependencies, Config, Backing Services, Build/Release/Run, Processes, Port Binding, Concurrency, Disposability, Dev/Prod Parity, Logs, Admin Processes
  - Modern extensions: API First, Telemetry, Security
  - Kubernetes implementation patterns
  - Docker containerization best practices
  - CI/CD integration
  - Microservices architecture patterns
  - Configuration management (ConfigMaps, Secrets)
  - Health checks and observability
  - Troubleshooting and anti-patterns
- **Related**: Complements the elixir-config skill for configuration best practices
- **Official Reference**: https://12factor.net/

## Project Context

The goal is to create a modular Claude Code plugin that:
- Installs sets of Claude skills for different domains
- Provides global skills (Git operations, mise, nushell)
- Provides language-specific skills (Elixir: anti-patterns, Phoenix, OTP, testing; Rust: language features, best practices)
- Provides general development skills (documentation, code review)
- Uses a hybrid approach: bundle core skills, allow pulling additional ones from remote sources
- Enables users to select which skill sets to activate

## Implementation Approach

- **Plugin Structure**: Single modular plugin with optional skill sets
- **Skill Organization**: Grouped by domain (elixir/, rust/, git/, mise/, nushell/, documentation/, code-review/)
- **Distribution**: Hybrid - core skills bundled, with ability to pull updates remotely
- **Priority Skills**: Elixir development, Rust development, Git operations, Development tools (mise, nushell), Documentation writing, Code review
