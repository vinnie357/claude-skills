# GitHub Plugin Sources

This file documents all sources used to create the skills in this plugin.

## GitHub Actions

### Primary Documentation
- **URL**: https://docs.github.com/en/actions
- **Accessed**: 2025-11-15
- **Purpose**: Core concepts, components, and best practices for GitHub Actions
- **Key Topics**:
  - Action types (JavaScript, Docker, Composite)
  - Workflow triggers and events
  - Runners (GitHub-hosted, larger, self-hosted)
  - Security best practices (secrets, GITHUB_TOKEN, OIDC)
  - Workflow organization and reusability
  - Monitoring and visualization

### GitHub Actions Toolkit
- **URL**: https://github.com/actions/toolkit
- **Purpose**: Official npm packages for creating JavaScript actions
- **Key Packages**:
  - `@actions/core` - Input/output handling, logging, secrets
  - `@actions/github` - GitHub API client (Octokit) and context
  - `@actions/exec` - Command execution
  - `@actions/cache` - Cache management
  - `@actions/artifact` - Artifact upload/download

### Action Metadata
- **URL**: https://docs.github.com/en/actions/creating-actions/metadata-syntax-for-github-actions
- **Purpose**: action.yml schema and configuration
- **Key Topics**:
  - Required and optional fields
  - Input/output definitions
  - Branding configuration
  - Runs configuration (node, docker, composite)

### Marketplace Publishing
- **URL**: https://docs.github.com/en/actions/creating-actions/publishing-actions-in-github-marketplace
- **Purpose**: Publishing and versioning actions
- **Key Topics**:
  - Marketplace requirements
  - Release process
  - Semantic versioning
  - Major version tags

## GitHub Workflows

### Primary Documentation
- **URL**: https://docs.github.com/en/actions/how-tos/write-workflows
- **Accessed**: 2025-11-15
- **Purpose**: Complete guide to writing GitHub Actions workflows
- **Key Topics**:
  - Workflow syntax and structure
  - Trigger events (push, pull_request, schedule, workflow_dispatch)
  - Jobs and steps
  - Contexts and expressions
  - Secrets and environment variables
  - Artifacts and caching
  - Reusable workflows
  - Concurrency control

### Workflow Syntax
- **URL**: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
- **Purpose**: Complete YAML syntax reference
- **Key Topics**:
  - on (triggers)
  - jobs (job configuration)
  - runs-on (runner selection)
  - steps (action and command execution)
  - env (environment variables)
  - if (conditional execution)
  - strategy.matrix (matrix builds)

### Contexts
- **URL**: https://docs.github.com/en/actions/learn-github-actions/contexts
- **Purpose**: Available context objects in workflows
- **Key Contexts**:
  - github (repository, event, actor information)
  - env (environment variables)
  - job (job status)
  - steps (step outputs)
  - runner (runner environment)
  - secrets (encrypted secrets)
  - matrix (matrix values)

### Expressions
- **URL**: https://docs.github.com/en/actions/learn-github-actions/expressions
- **Purpose**: Expression syntax and functions
- **Key Topics**:
  - Operators (comparison, logical)
  - Status functions (success, failure, always, cancelled)
  - String functions (contains, startsWith, endsWith, format)
  - Object functions (toJSON, fromJSON)
  - Hash function (hashFiles)

### Events
- **URL**: https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows
- **Purpose**: All available workflow trigger events
- **Key Events**:
  - push, pull_request, pull_request_target
  - workflow_dispatch (manual)
  - schedule (cron)
  - release, issues, discussion
  - repository_dispatch (external webhooks)

## act (Local Testing)

### Primary Repository
- **URL**: https://github.com/nektos/act
- **Accessed**: 2025-11-15
- **Purpose**: Local GitHub Actions testing tool
- **Key Topics**:
  - Installation methods (Homebrew, install script, from source)
  - How act works (Docker-based execution)
  - Basic usage and commands
  - Event payloads and triggers
  - Secrets management
  - Configuration (.actrc, custom images)
  - Debugging and troubleshooting

### Installation
- **URL**: https://github.com/nektos/act#installation
- **Purpose**: Platform-specific installation instructions
- **Methods**:
  - macOS: Homebrew
  - Linux: Install script
  - Windows: Chocolatey
  - From source: Go toolchain

### Runner Images
- **URL**: https://github.com/nektos/act#runners
- **Purpose**: Docker images for simulating GitHub runners
- **Image Tiers**:
  - Micro: Minimal, fast startup
  - Medium: Recommended, better compatibility
  - Large: Full GitHub-hosted runner parity
- **Recommended Images**: catthehacker/ubuntu images

### Configuration
- **URL**: https://github.com/nektos/act#configuration
- **Purpose**: Configuring act behavior
- **Key Topics**:
  - .actrc file format
  - Custom runner images (-P flag)
  - Secrets (--secret-file, -s)
  - Environment variables (--env-file, --env)
  - Container options (--bind, --reuse)

### Limitations
- **URL**: https://github.com/nektos/act#known-issues
- **Purpose**: Differences between act and GitHub Actions
- **Key Limitations**:
  - Some GitHub-hosted runner features unavailable
  - OIDC not supported
  - Limited job summary support
  - Some API interactions don't work

## Additional References

### GitHub CLI
- **URL**: https://cli.github.com/
- **Purpose**: Command-line tool for GitHub API
- **Usage**: Workflow management, debugging

### Docker
- **URL**: https://www.docker.com/
- **Purpose**: Container runtime required by act
- **Key Topics**: Installation, Docker Desktop, daemon management

### mise
- **URL**: https://mise.jdx.dev/
- **Purpose**: Tool version management
- **Usage**: Installing and managing act versions

### Nushell
- **URL**: https://www.nushell.sh/
- **Purpose**: Cross-platform shell used for installation scripts
- **Usage**: Platform-agnostic installation automation
