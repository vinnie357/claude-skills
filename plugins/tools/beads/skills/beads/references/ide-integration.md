# Beads IDE Integration Reference

VS Code extensions for beads: task sidebar, kanban board, and recommended
editor settings.

### VS Code Extensions

Two extensions enhance the beads experience in VS Code:

#### Beads Extension (`planet57.vscode-beads`)

Core beads integration for VS Code:
- Task list sidebar view
- Create, edit, and close tasks from the editor
- Syntax highlighting for `.beads/` files
- Task ID autocompletion in commit messages

Install via Extensions panel or:
```bash
code --install-extension planet57.vscode-beads
```

#### Beads Kanban (`DavidCForbes.beads-kanban`)

Visual kanban board for beads tasks:
- Drag-and-drop task management
- Status columns (open, in-progress, closed)
- Filter by labels and assignees
- Dependency visualization

Install via Extensions panel or:
```bash
code --install-extension DavidCForbes.beads-kanban
```

### Recommended VS Code Settings

Add to `.vscode/settings.json` for beads projects:

```json
{
  "files.associations": {
    "*.jsonl": "json"
  },
  "files.exclude": {
    ".beads.sqlite": true
  }
}
```

