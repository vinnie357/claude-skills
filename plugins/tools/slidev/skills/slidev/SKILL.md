---
name: slidev
description: Guide for Slidev markdown-based presentation framework. Use when creating slide decks, setting up Slidev projects, or needing an overview of Slidev development workflows.
---

# Slidev Presentation Framework

Entry point for Slidev development. Provides an overview and routes to focused skills.

## When to Use This Skill

Activate when:
- Starting a new Slidev presentation project
- Needing a general overview of Slidev capabilities
- Unsure which specific Slidev skill to load

## Available Skills

This plugin provides focused skills for specific Slidev topics:

- **slidev:syntax** - Slide separators, frontmatter, layouts, MDC syntax, presenter notes, clicks, transitions
- **slidev:code** - Code blocks: Shiki highlighting, line highlighting, Monaco editor, Magic Move, TwoSlash, code groups
- **slidev:export** - Export to PDF, PPTX, PNG, SPA build, CLI flags
- **slidev:troubleshooting** - Common errors, export failures, font issues, configuration debugging

## Quick Start

```bash
# Create a new Slidev project
npm init slidev@latest

# Or start from an existing markdown file
npx slidev slides.md
```

### Minimal Slide Deck

```markdown
---
theme: default
title: My Presentation
---

# Welcome

First slide content

---

# Second Slide

More content here

---
layout: center
---

# Centered Slide

This slide uses the center layout
```

### Project Structure

```
my-presentation/
├── slides.md          # Main slide content
├── package.json       # Dependencies
├── components/        # Custom Vue components (auto-imported)
├── layouts/           # Custom layouts
├── pages/             # Additional slide files
├── public/            # Static assets
├── styles/            # Custom CSS/UnoCSS
└── snippets/          # External code snippets
```

## Key Concepts

- **Markdown-first**: Write slides in Markdown with YAML frontmatter for configuration
- **Vue 3 powered**: Use Vue components directly in slides
- **Vite-based**: Hot module replacement for instant preview updates
- **Theme ecosystem**: Install themes via npm packages (`slidev-theme-*`)
- **Code-focused**: Built-in syntax highlighting, Monaco editor, and animated code transitions
- **Presenter mode**: Dual-window mode with notes, timer, and slide navigation

## Configuration

Global configuration goes in the first slide's frontmatter:

```yaml
---
theme: default
title: My Talk
info: |
  Description of the presentation
author: Your Name
download: true
exportFilename: my-talk
highlighter: shiki
lineNumbers: true
drawings:
  persist: false
transition: slide-left
mdc: true
---
```

See `templates/mise.toml` for project task definitions.
