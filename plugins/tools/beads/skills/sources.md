# Skill Sources

Source attribution for skills in the beads plugin.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there.

## Beads Skill

### Beads Documentation
- **URL**: https://beads.gascity.com/
- **Purpose**: Official Beads documentation for the distributed git-backed graph issue tracker. Repo and docs relocated from steveyegge/beads; the old https://steveyegge.github.io/beads/ URL 404s. This URL is also the GitHub-declared repo homepage.
- **Date Accessed**: 2026-08-04
- **Key Topics**: Task creation, dependency management, JSON output, sync modes, AI agent integration

### Beads GitHub Repository
- **URL**: https://github.com/gastownhall/beads
- **Purpose**: Source code and installation instructions. `github.com/steveyegge/beads` now 301-redirects here; released Go modules still declare the steveyegge path for compatibility.
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
