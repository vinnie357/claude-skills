# Claude Code Plugin Sources

This file documents the sources used to create the claude-code plugin skills.

## Agent Skills Documentation

### Agent Skills Concept
- **URL**: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- **Purpose**: Understanding what Claude skills are, how they work, and best practices for creating them
- **Date Accessed**: 2025-11-15
- **Key Concepts**: Progressive disclosure, skill structure, modular expertise packages
- **Used In**: skills/skills/SKILL.md

### Example Skills Repository
- **URL**: https://github.com/anthropics/skills/tree/main
- **Purpose**: Reference implementations and examples of various Claude skills
- **Categories**: Creative & Design, Development & Technical, Enterprise & Communication, Meta Skills, Document Skills
- **Used In**: skills/skills/SKILL.md

### Skill Creator Guide
- **URL**: https://github.com/anthropics/skills/blob/main/skill-creator/SKILL.md
- **Purpose**: Best practices and guidelines for creating effective Claude skills
- **Key Points**:
  - SKILL.md structure with YAML frontmatter
  - Progressive disclosure architecture
  - Imperative/infinitive form for instructions
  - Resource organization strategies
- **Used In**: skills/skills/SKILL.md

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
- **Used In**: skills/skills/SKILL.md

### Agent Skills Specification
- **URL**: https://github.com/anthropics/skills/blob/main/agent_skills_spec.md
- **Purpose**: Official specification for Agent Skills format and structure
- **Date Accessed**: 2025-11-15
- **Used In**: skills/skills/SKILL.md

## Claude Code Plugin Development

### Claude Code Plugins Documentation
- **URL**: https://code.claude.com/docs/en/plugins
- **Purpose**: Understanding how Claude Code plugins work and how to create them
- **Date Accessed**: 2025-11-15
- **Key Features**:
  - Plugin architecture and components
  - Commands, agents, skills, hooks structure
  - Plugin manifest (plugin.json) format
  - Installation and distribution
- **Used In**: skills/plugin/SKILL.md

### Claude Code Commands Documentation
- **URL**: https://code.claude.com/docs/en/commands
- **Purpose**: Guide for creating custom slash commands
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - Command file structure
  - Argument handling
  - Command workflows
- **Used In**: skills/commands/SKILL.md

### Claude Code Agents Documentation
- **URL**: https://code.claude.com/docs/en/agents
- **Purpose**: Creating specialized agents with custom behaviors
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - Agent configuration
  - Tool restrictions
  - Model selection
  - Task delegation
- **Used In**: skills/agents/SKILL.md

### Claude Code Hooks Documentation
- **URL**: https://code.claude.com/docs/en/hooks
- **Purpose**: Creating event-driven automations with hooks
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - Hook types and configuration
  - Tool call hooks
  - Lifecycle hooks
  - Variable substitution
- **Used In**: skills/hooks/SKILL.md

## Plugin Marketplace Skill

### Claude Code Plugin Marketplace Schema
- **URL**: https://code.claude.com/docs/en/plugin-marketplaces
- **Purpose**: Official specification for creating plugin marketplaces
- **Date Accessed**: 2025-11-15
- **Key Specifications**:
  - Marketplace file location: `.claude-plugin/marketplace.json`
  - Required fields: `name`, `owner`, `plugins` array
  - Optional metadata: `description`, `version`, `pluginRoot`
  - Plugin entry requirements: `name` and `source` (relative path, GitHub repo, or git URL)
  - Strict mode control: `strict: true` (default) requires plugin.json; `strict: false` allows marketplace as complete manifest
  - Environment variables: `${CLAUDE_PLUGIN_ROOT}` for dynamic path resolution
  - Standard metadata fields: description, version, author, homepage, repository, license, keywords, category, tags
  - Component configuration: commands, agents, hooks, mcpServers
- **Used In**: skills/plugin-marketplace/SKILL.md

### Advanced Plugin Entry Features
- **URL**: https://code.claude.com/docs/en/plugin-marketplaces#advanced-plugin-entries
- **Purpose**: Advanced marketplace configuration options
- **Date Accessed**: 2025-11-15
- **Key Features**:
  - Inline plugin definitions: Comprehensive configuration directly in marketplace.json
  - Component override: Custom paths for commands, agents, hooks, MCP servers
  - Dynamic path resolution: Use `${CLAUDE_PLUGIN_ROOT}` in paths to adapt to installation directory
  - Manifest supplementation: Marketplace fields can override or supplement plugin.json values
  - Manifest-free distribution: `strict: false` enables plugin distribution without plugin.json
  - Complex source configurations: Structured objects for GitHub, git URLs, or relative paths
  - Metadata enrichment: Add discovery metadata not present in plugin manifests
- **Used In**: skills/plugin-marketplace/SKILL.md

## Plugin Skill

### Plugin JSON Schema
- **Created**: 2025-11-15
- **Purpose**: Complete schema specification for plugin.json files
- **Key Fields**:
  - Required: `name` (kebab-case)
  - Recommended: `version` (semver), `description`, `license` (SPDX)
  - Optional: `author`, `homepage`, `repository`, `keywords`
  - Component paths: `skills`, `commands`, `agents`, `hooks`, `mcpServers`
  - Invalid in plugin.json: `dependencies`, `category`, `strict`, `source`, `tags` (marketplace-only)
- **Used In**: skills/plugin/SKILL.md

## Validation Scripts

### Nushell Validation Scripts
- **Created**: 2025-11-15
- **Purpose**: Automated validation tools for marketplace.json and plugin.json
- **Scripts Developed**:
  - `validate-marketplace.nu`: Complete marketplace schema validation
  - `validate-dependencies.nu`: Dependency graph and circular dependency detection
  - `init-marketplace.nu`: Interactive marketplace template generation
  - `analyze-plugins.nu`: Existing plugin structure analysis
  - `format-marketplace.nu`: JSON formatting and plugin sorting
  - `validate-plugin.nu`: Plugin.json schema validation with invalid field detection
  - `init-plugin.nu`: Interactive plugin.json template generation
  - `format-plugin.nu`: Plugin.json formatting and sorting
- **Language**: Nushell
- **Location**: skills/plugin-marketplace/scripts/ and skills/plugin/scripts/

## Project Context

### Overall Goals

Create a modular Claude Code plugin marketplace that:
- Provides Claude Code component creation guides (commands, agents, skills, hooks)
- Provides plugin and marketplace management tools
- Enables schema validation and compliance checking
- Supports automated template generation
- Uses tiered architecture with separate, focused plugins
- Enables users to selectively install plugin combinations

### Implementation Approach

- **Plugin Structure**: Modular plugins with focused purposes
- **Skill Organization**: Grouped by domain and functionality
- **Distribution**: Git-based with marketplace support
- **Validation**: Automated Nushell scripts for schema compliance

## Plugin Information

- **Name**: claude-code
- **Version**: 0.1.0
- **Description**: Claude Code-specific skills for plugin marketplace management, validation, and component creation
- **Skills**: 6 skills covering all aspects of Claude Code plugin development
  - plugin-marketplace: Marketplace.json validation and management
  - plugin: Plugin.json validation and management
  - commands: Creating custom slash commands
  - agents: Creating specialized agents
  - skills: Creating Agent Skills (general guide)
  - hooks: Creating event-driven hooks
- **Created**: 2025-11-15
- **Key Capabilities**:
  - Complete Claude Code plugin development guide
  - Marketplace and plugin validation
  - Schema compliance checking
  - Automated template generation
  - Nushell-based validation scripts
