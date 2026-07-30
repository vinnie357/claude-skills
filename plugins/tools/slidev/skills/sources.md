# Slidev Plugin Sources

This file documents the sources used to create the slidev plugin skills.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there. Entries: `slidev-syntax-guide`, `slidev-builtin-layouts`, `slidev-slot-sugar`, `slidev-block-frontmatter`, `slidev-draggable-elements` (Slidev Syntax section below); `slidev-code-blocks`, `slidev-code-line-numbers`, `slidev-code-max-height`, `slidev-code-groups`, `slidev-monaco-editor`, `slidev-import-snippets`, `slidev-latex`, `slidev-mermaid`, `slidev-plantuml` (Slidev Code Blocks section below); `slidev-exporting-guide`, `slidev-cli-reference` (Slidev Export section below); `pyramid-principle`, `kawasaki-10-20-30`, `assertion-evidence-design`, `duarte-resonate`, `presentation-zen`, `rule-of-three` (Presentation Strategy section below); `playwright-mcp-browser-tools`, `wcag-contrast-requirements`, `slidev-unocss-theming` (Brand Discovery and Styles section below); `vue3-composition-api`, `slidev-custom-components`, `slidev-iframe-layouts` (Interactive Demos section below).

Two skills have no section of their own because they draw on sources cited elsewhere in this file. The `slidev` overview skill uses `slidev-syntax-guide` (frontmatter quick start) and `slidev-cli-reference` (the `npm init slidev@latest` / `npx slidev` commands). The `troubleshooting` skill uses `slidev-syntax-guide`, `slidev-code-groups`, `slidev-monaco-editor`, `slidev-exporting-guide`, and `slidev-cli-reference` — the export flags (`--timeout`, `--wait`, `--omit-background`), the `mdc: true` code-group requirement, and the Monaco-not-appearing case each trace back to those pages. `sources.toml` records both attributions in its `skills` arrays.

## Slidev Syntax

### Slidev Syntax Guide
- **URL**: https://sli.dev/guide/syntax
- **Purpose**: Slide separators, frontmatter, and markdown syntax
- **Date Accessed**: 2026-02-21
- **Key Topics**: Slide structure, YAML frontmatter, headmatter configuration, block frontmatter

### Slidev Built-in Layouts
- **URL**: https://sli.dev/builtin/layouts
- **Purpose**: Complete catalog of 19 built-in layouts with props and slots
- **Date Accessed**: 2026-02-21
- **Key Topics**: Layout names, props (image, url, class), named slots (two-cols, two-cols-header)

### Slidev Slot Sugar
- **URL**: https://sli.dev/features/slot-sugar
- **Purpose**: Named slot syntax for layouts
- **Date Accessed**: 2026-02-21
- **Key Topics**: ::name:: syntax, default slot, slot reordering

### Slidev Block Frontmatter
- **URL**: https://sli.dev/features/block-frontmatter
- **Purpose**: Alternative YAML code fence frontmatter syntax
- **Date Accessed**: 2026-02-21
- **Key Topics**: Block frontmatter vs traditional, editor support

## Slidev Code Blocks

### Slidev Code Blocks
- **URL**: https://sli.dev/features/code-blocks
- **Purpose**: Shiki highlighting, line highlighting, click-based highlighting
- **Date Accessed**: 2026-02-21
- **Key Topics**: Line ranges, click animations, at/finally, placeholder syntax

### Slidev Code Line Numbers
- **URL**: https://sli.dev/features/code-block-line-numbers
- **Purpose**: Line number display in code blocks
- **Date Accessed**: 2026-02-21
- **Key Topics**: Global and per-block line numbers, startLine

### Slidev Code Block Max Height
- **URL**: https://sli.dev/features/code-block-max-height
- **Purpose**: Scrollable code blocks
- **Date Accessed**: 2026-02-21
- **Key Topics**: maxHeight property, scroll behavior

### Slidev Code Groups
- **URL**: https://sli.dev/features/code-groups
- **Purpose**: Tabbed code block groups
- **Date Accessed**: 2026-02-21
- **Key Topics**: MDC syntax, tab labels, icon matching

### Slidev Monaco Editor
- **URL**: https://sli.dev/features/monaco-editor
- **Purpose**: Interactive VS Code editor in slides
- **Date Accessed**: 2026-02-21
- **Key Topics**: Monaco syntax, diff mode, height configuration

### Slidev Import Snippets
- **URL**: https://sli.dev/features/import-snippet
- **Purpose**: Importing external code files
- **Date Accessed**: 2026-02-21
- **Key Topics**: <<< syntax, VS Code regions, language override

### Slidev LaTeX
- **URL**: https://sli.dev/features/latex
- **Purpose**: Mathematical notation in slides
- **Date Accessed**: 2026-02-21
- **Key Topics**: KaTeX, inline math, block math, chemical equations

### Slidev Mermaid
- **URL**: https://sli.dev/features/mermaid
- **Purpose**: Text-based diagram support
- **Date Accessed**: 2026-02-21
- **Key Topics**: Mermaid syntax, theme configuration

### Slidev PlantUML
- **URL**: https://sli.dev/features/plantuml
- **Purpose**: PlantUML diagram support
- **Date Accessed**: 2026-02-21
- **Key Topics**: PlantUML syntax, server configuration

## Slidev Export

### Slidev Exporting Guide
- **URL**: https://sli.dev/guide/exporting
- **Purpose**: Export to PDF, PPTX, PNG, and build SPA
- **Date Accessed**: 2026-02-21
- **Key Topics**: Export formats, CLI flags, Playwright dependency, dark mode, click animations

### Slidev CLI Reference
- **URL**: https://sli.dev/builtin/cli
- **Purpose**: Complete CLI command reference
- **Date Accessed**: 2026-02-21
- **Key Topics**: dev, build, export, format commands with all flags and defaults

### Slidev Draggable Elements
- **URL**: https://sli.dev/features/draggable
- **Purpose**: Draggable element positioning
- **Date Accessed**: 2026-02-21
- **Key Topics**: v-drag directive, v-drag component, dragPos frontmatter

## Presentation Strategy

### Pyramid Principle (Barbara Minto)
- **URL**: https://www.barbaraminto.com/
- **Purpose**: Lead-with-the-answer communication framework
- **Date Accessed**: 2026-04-04
- **Key Topics**: SCQA (Situation-Complication-Question-Answer), top-down communication, grouping arguments

### Guy Kawasaki 10/20/30 Rule
- **URL**: https://guykawasaki.com/the_102030_rule/
- **Purpose**: Slide count, duration, and font size constraints
- **Date Accessed**: 2026-04-04
- **Key Topics**: 10 slides maximum, 20 minutes, 30pt minimum font

### Assertion-Evidence Slide Design
- **URL**: https://www.assertion-evidence.com/
- **Purpose**: Slide structure methodology replacing bullet-point slides
- **Date Accessed**: 2026-04-04
- **Key Topics**: Assertion headers, visual evidence bodies, ~20 words per slide

### Nancy Duarte - Resonate
- **URL**: https://www.duarte.com/resources/books/resonate/
- **Purpose**: Storytelling framework for presentations
- **Date Accessed**: 2026-04-04
- **Key Topics**: Sparkline narrative arc, "what is" vs "what could be", audience as hero

### Presentation Zen (Garr Reynolds)
- **URL**: https://presentationzen.com/
- **Purpose**: Minimalist presentation design principles
- **Date Accessed**: 2026-04-04
- **Key Topics**: Simplicity, clarity, restraint, harmony, connection

### Rule of Three in Presentations
- **URL**: https://ethos3.com/the-rule-of-three-for-presentations/
- **Purpose**: Cognitive basis for three-point structures
- **Date Accessed**: 2026-04-04
- **Key Topics**: Three key messages, three-act narrative, audience retention

## Brand Discovery and Styles

### Playwright MCP Browser Tools
- **URL**: https://github.com/anthropics/claude-code/tree/main/packages/mcp-server-playwright
- **Purpose**: Browser automation for brand token extraction
- **Date Accessed**: 2026-04-04
- **Key Topics**: browser_navigate, browser_evaluate, browser_take_screenshot, CSS extraction

### WCAG 2.1 Contrast Requirements
- **URL**: https://www.w3.org/WAI/WCAG21/quickref/#contrast-minimum
- **Purpose**: Accessibility contrast ratio requirements for slide validation
- **Date Accessed**: 2026-04-04
- **Key Topics**: 4.5:1 normal text, 3:1 large text, 3:1 UI components

### Slidev UnoCSS Theming
- **URL**: https://sli.dev/custom/config-unocss
- **Purpose**: UnoCSS configuration for Slidev themes
- **Date Accessed**: 2026-04-04
- **Key Topics**: Theme shortcuts, CSS variables, custom rules

## Interactive Demos

### Vue 3 Composition API
- **URL**: https://vuejs.org/api/composition-api-setup.html
- **Purpose**: Reactive state management for interactive slide components
- **Date Accessed**: 2026-04-04
- **Key Topics**: ref(), reactive(), computed(), watch(), lifecycle hooks

### Slidev Custom Components
- **URL**: https://sli.dev/custom/vue-context
- **Purpose**: Vue component integration in Slidev slides
- **Date Accessed**: 2026-04-04
- **Key Topics**: $slidev context, useSlideContext(), v-click integration, auto-import from components/

### Slidev Iframe Layouts
- **URL**: https://sli.dev/builtin/layouts#iframe
- **Purpose**: Embedding external content in slides
- **Date Accessed**: 2026-04-04
- **Key Topics**: iframe, iframe-left, iframe-right layouts, URL property
