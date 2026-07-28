# Skill Sources

Source attribution for skills in the beads plugin.

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
