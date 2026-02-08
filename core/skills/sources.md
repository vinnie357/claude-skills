# Core Plugin Sources

This file documents the sources used to create the core plugin skills.

## Git Skill

### Git Documentation
- **URL**: https://git-scm.com/doc
- **Purpose**: Official Git documentation and best practices
- **Date Accessed**: 2025-11-15
- **Key Topics**: Git operations, branching, rebasing, conflict resolution

### Conventional Commits
- **URL**: https://www.conventionalcommits.org/
- **Purpose**: Commit message convention and best practices
- **Key Topics**: Commit message format, types, scopes, breaking changes

## Mise Skill

### mise Documentation
- **URL**: https://mise.jdx.dev/
- **Purpose**: Development environment management and tool version control
- **Date Accessed**: 2025-11-15
- **Key Topics**: Runtime management, environment configuration, task running

## Nushell Skill

### Nushell Book
- **URL**: https://www.nushell.sh/book/
- **Purpose**: Modern, structured data shell with pipeline support
- **Date Accessed**: 2025-11-15
- **Key Topics**: Shell commands, data pipelines, structured data handling

## Documentation Skill

### Technical Writing Best Practices
- **URL**: https://developers.google.com/tech-writing
- **Purpose**: Guide for writing clear, comprehensive technical documentation
- **Key Topics**: README files, API docs, guides, inline documentation

## Code Review Skill

### Code Review Best Practices
- **URL**: https://google.github.io/eng-practices/review/
- **Purpose**: Best practices for conducting thorough code reviews
- **Key Topics**: Correctness, security, performance, maintainability

## Anti-Fabrication Skill

### Internal Development
- **Created**: 2025-11-15
- **Purpose**: Ensure factual accuracy by validating claims through tool execution
- **Key Principles**:
  - Base outputs on actual analysis of real data
  - Execute tools before making claims
  - Mark uncertain information appropriately
  - Avoid superlatives and unsubstantiated metrics

## Accessibility Skill

### W3C Web Accessibility Initiative (WAI)
- **URL**: https://www.w3.org/WAI/fundamentals/accessibility-principles/
- **Purpose**: Foundation for accessibility skill - comprehensive web accessibility principles
- **Date Accessed**: 2025-11-15
- **Key Topics**: WCAG guidelines, POUR principles (Perceivable, Operable, Understandable, Robust)
- **Key Concepts**:
  - Text alternatives for non-text content
  - Keyboard accessibility
  - Readable and understandable text
  - Robust content compatible with assistive technologies
  - ARIA (Accessible Rich Internet Applications)

## Material Design Skill

### Material Design 3 Documentation
- **URL**: https://m3.material.io/
- **Purpose**: Foundation for Material Design skill - Google's latest design system
- **Date Accessed**: 2025-11-15
- **Key Resources**:
  - Typography: https://m3.material.io/styles/typography/overview
  - Color System: https://m3.material.io/styles/color/system/overview
  - Layout: https://m3.material.io/foundations/layout/understanding-layout/overview
  - Foundations: https://m3.material.io/foundations
- **Key Topics**:
  - Dynamic color system with HCT color space
  - Typography scales and responsive text
  - Layout grids and breakpoints
  - Material You personalization
  - Component specifications
  - Motion and animation principles
  - Accessibility-first design

### Material Design 3 Guide
- **URL**: https://oritop.co/google-material-design-a-complete-breakdown-of-material-design-3/
- **Purpose**: Supplementary resource for Material Design 3 overview
- **Key Topics**: MD2 vs MD3 comparison, dynamic color, enhanced components

## Twelve-Factor App Skill

### 12-Factor App Methodology
- **URL**: https://12factor.net/
- **Purpose**: Foundation for cloud-native application design principles
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - 12 core factors: Codebase, Dependencies, Config, Backing Services, Build/Release/Run, Processes, Port Binding, Concurrency, Disposability, Dev/Prod Parity, Logs, Admin Processes
  - Modern extensions: API First, Telemetry, Security
  - Kubernetes implementation patterns
  - Docker containerization best practices
  - CI/CD integration
  - Configuration management

## Security Skill

### Gitleaks
- **URL**: https://github.com/gitleaks/gitleaks
- **Purpose**: Secret detection tool for scanning git repositories
- **Date Accessed**: 2026-01-24
- **Key Topics**: Secret scanning, credential detection, pre-commit hooks, CI/CD integration

### Gitleaks Docker Image
- **URL**: https://hub.docker.com/r/zricethezav/gitleaks
- **Purpose**: Official container image for running gitleaks
- **Key Topics**: Container-based scanning, CI/CD integration

### Apple Container CLI (macOS 26+)
- **Documentation**: Built-in macOS 26 container runtime
- **Purpose**: Native container support for macOS
- **Key Topics**: Container runtime, Docker-compatible CLI

## Beads Skill

### Beads Documentation
- **URL**: https://steveyegge.github.io/beads/
- **Purpose**: Official Beads documentation for the distributed git-backed graph issue tracker
- **Date Accessed**: 2026-01-24
- **Key Topics**: Task creation, dependency management, JSON output, sync modes, AI agent integration

### Beads GitHub Repository
- **URL**: https://github.com/steveyegge/beads
- **Purpose**: Source code and installation instructions
- **Key Topics**: Installation methods (npm, brew, go), CLI commands, storage format

### VS Code Extensions
- **URL**: https://marketplace.visualstudio.com/items?itemName=planet57.vscode-beads
- **Purpose**: Core beads integration for VS Code (task sidebar, syntax highlighting, autocompletion)

- **URL**: https://marketplace.visualstudio.com/items?itemName=DavidCForbes.beads-kanban
- **Purpose**: Visual kanban board for beads tasks (drag-and-drop, dependency visualization)

### Key Concepts Extracted
- Hash-based task IDs for collision resistance in multi-agent/multi-branch workflows
- Dependency-aware querying (`bd ready`) for task prioritization
- JSON output (`--json`) for programmatic AI agent access
- Git-native storage (JSONL files in `.beads/`, SQLite cache)
- Three sync modes: full, stealth (local-only), contributor (pull-only)
- VS Code extensions for visual task management and IDE integration

## Container Skill

### Apple Container CLI
- **URL**: https://github.com/apple/container
- **Purpose**: macOS-native tool for running Linux containers as lightweight VMs on Apple silicon
- **Date Accessed**: 2026-02-08
- **Key Topics**: OCI containers, Virtualization.framework, Apple silicon, container lifecycle, image management, networking, volumes

### Apple Container Command Reference
- **URL**: https://github.com/apple/container/blob/main/docs/command-reference.md
- **Purpose**: CLI command documentation for all container subcommands and flags
- **Key Topics**: Container run/stop/exec, image pull/push/build, network/volume management, system service

### Apple Container Releases
- **URL**: https://github.com/apple/container/releases
- **Purpose**: Version tracking, breaking changes between releases, installation packages
- **Date Accessed**: 2026-02-08
- **Key Topics**: Version 0.4.1 to 0.5.0 migration, breaking changes, new features, CVE fixes

## Plugin Information

- **Name**: core
- **Version**: 0.1.9
- **Description**: Essential development skills: Git, documentation, code review, accessibility, security
- **Skills**: 12 skills covering fundamental development tools and best practices
- **Created**: 2025-11-15
