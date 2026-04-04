---
name: slidev
description: Guide for Slidev markdown-based presentation framework. Use when creating slide decks, planning presentations, setting up Slidev projects, extracting brand styles, building interactive demos, or needing an overview of Slidev development workflows.
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

### Content Strategy
- **slidev:presentations** - Presentation strategy, problem-first framing, rule of threes, audience templates, one-pagers, assertion-evidence design
- **slidev:styles** - Brand discovery with Playwright MCP, theme generation, compliance validation, WCAG contrast checks
- **slidev:interactive** - Interactive demos, Vue components, iframe mocks, workflow animations, clickable prototypes

### Technical Reference
- **slidev:syntax** - Slide separators, frontmatter, layouts, MDC syntax, presenter notes, clicks, transitions
- **slidev:code** - Code blocks: Shiki highlighting, line highlighting, Monaco editor, Magic Move, TwoSlash, code groups
- **slidev:export** - Export to PDF, PPTX, PNG, SPA build, CLI flags
- **slidev:troubleshooting** - Common errors, export failures, font issues, configuration debugging

## Available Agents

Three agents compose into a pipeline for end-to-end presentation creation:

- **content-strategist** (haiku) - Questionnaire for audience, tone, problem framing, key messages. Outputs a content strategy brief
- **brand-discoverer** (haiku) - Extracts brand tokens (colors, fonts, spacing) from websites using Playwright MCP. Outputs brand config JSON
- **slide-builder** (sonnet) - Builds complete Slidev decks from strategy brief + brand config, applying presentation best practices

Each agent works independently or in sequence. The recommended pipeline:
1. Run `content-strategist` to define what the presentation needs
2. Run `brand-discoverer` if brand compliance is required
3. Run `slide-builder` to construct the deck from both outputs

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
