---
name: slidev-styles
description: Guide for brand discovery, theme generation, and style validation for Slidev presentations. Use when extracting brand tokens from websites, creating Slidev themes from brand guidelines, validating slide compliance with brand standards, or configuring colors, fonts, and spacing.
---

# Slidev Styles

Brand discovery, theme generation, and style validation for Slidev presentations.

## When to Use This Skill

Activate when:
- Extracting brand tokens (colors, fonts, spacing) from a website using Playwright MCP
- Creating a Slidev theme from brand guidelines or a style guide URL
- Validating slides for brand compliance or WCAG contrast requirements
- Configuring UnoCSS theme shortcuts and CSS variables for a presentation
- Applying a logo, custom font, or color palette to existing slides
- Working from a manual brand brief when no website is available

## Brand Discovery Pipeline Overview

The full brand discovery workflow has four stages:

1. **Navigate** to the brand site using Playwright MCP tools
2. **Extract** CSS variables and computed styles via `browser_evaluate`
3. **Parse** extracted values into a brand config JSON object
4. **Generate** the Slidev theme from the brand config

For step-by-step Playwright extraction details, see `references/discovery-pipeline.md`.
For theme generation details, see `references/theme-generation.md`.
For validation details, see `references/validation-checklist.md`.

## Playwright MCP Tools

Use these tools during brand extraction:

| Tool | Purpose |
|------|---------|
| `browser_navigate` | Open the brand site URL |
| `browser_evaluate` | Run JavaScript to extract CSS vars and computed styles |
| `browser_take_screenshot` | Capture rendered slides or pages for visual validation |
| `browser_snapshot` | Get accessibility tree snapshot for structural inspection |
| `browser_close` | Close the browser session when extraction is complete |

Always call `browser_close` after extraction to release resources.

## Brand Config JSON Schema

Produce a brand config JSON object after extraction. All fields are optional; populate what is available.

```json
{
  "colors": {
    "primary": "#hex",
    "secondary": "#hex",
    "accent": "#hex",
    "background": "#hex",
    "text": "#hex",
    "error": "#hex",
    "success": "#hex"
  },
  "fonts": {
    "heading": "Font Name",
    "body": "Font Name",
    "code": "Monospace Font"
  },
  "spacing": {
    "slide-padding": "value",
    "section-gap": "value"
  },
  "logo": {
    "url": "path/to/logo",
    "position": "top-left|top-right"
  }
}
```

Save the brand config as `brand-config.json` in the project root before proceeding to theme generation.

## Theme Generation Overview

Convert the brand config to a Slidev theme by:

1. Creating `styles/index.css` with CSS custom properties mapped from brand config colors and spacing
2. Configuring UnoCSS theme extensions in `uno.config.ts` (or `vite.config.ts`) with brand colors and font stacks
3. Adding UnoCSS shortcut classes for common slide patterns (headings, callouts, code blocks)
4. Loading fonts via Google Fonts import in `styles/index.css` or placing font files in `public/fonts/`
5. Creating a global `components/Logo.vue` component for logo placement

For complete theme generation with code examples, see `references/theme-generation.md`.

## Validation Overview

After applying a theme, validate compliance by:

1. Taking screenshots of rendered slides with `browser_take_screenshot`
2. Running contrast ratio checks using the WCAG AA formula via `browser_evaluate`
3. Verifying rendered font families match the brand spec
4. Checking all colors against the brand palette within a tolerance of ±5 hex units per channel
5. Confirming logo placement and sizing

WCAG 2.1 AA requirements (per `core:accessibility`):
- Normal text (< 18pt): minimum contrast ratio **4.5:1**
- Large text (≥ 18pt or ≥ 14pt bold): minimum contrast ratio **3:1**
- UI components and graphical objects: minimum contrast ratio **3:1**

For the full validation workflow and automated checks, see `references/validation-checklist.md`.

## Manual Brand Input

When no website is available, gather brand information using this questionnaire:

```
Brand Color Questionnaire
--------------------------
1. Primary brand color (main CTA, headings): ___
2. Secondary brand color (accents, highlights): ___
3. Background color (slides): ___
4. Body text color: ___
5. Accent/success color (callouts): ___
6. Error/warning color: ___

Font Questionnaire
------------------
7. Heading font (name and weight): ___
8. Body text font: ___
9. Code/monospace font: ___
10. Are fonts hosted on Google Fonts, or do you have local files?

Spacing Questionnaire
---------------------
11. Slide padding (distance from edge to content): ___
12. Gap between major sections: ___

Logo Questionnaire
------------------
13. Logo file URL or local path: ___
14. Logo placement: top-left / top-right / none
```

Populate the brand config JSON from questionnaire answers, then proceed to theme generation.

## Integration with core:accessibility

Load `core:accessibility` when:
- Validating contrast ratios for slide text and UI components
- Reviewing color combinations for color-blindness considerations
- Checking that information is not conveyed by color alone

Key WCAG requirements that apply to slide presentations:
- Text on slide backgrounds must meet 4.5:1 contrast ratio (AA)
- Heading text at large sizes must meet 3:1 contrast ratio
- Charts and diagrams must have text labels or patterns, not only color
- Slide transitions and animations must not flash more than 3 times per second

## Slidev Theme File Structure

A self-contained brand theme lives in a `slidev-theme-brand/` directory:

```
slidev-theme-brand/
├── package.json          # Theme package with name "slidev-theme-brand"
├── styles/
│   └── index.css         # CSS custom properties and base styles
├── uno.config.ts         # UnoCSS theme extensions and shortcuts
└── components/
    └── Logo.vue          # Global logo component for all slides
```

Reference the theme from the presentation frontmatter:

```yaml
---
theme: ./slidev-theme-brand
---
```

## References

- `references/discovery-pipeline.md` — Step-by-step Playwright MCP extraction workflow with JavaScript snippets
- `references/theme-generation.md` — Converting brand config to UnoCSS theme and CSS variables
- `references/validation-checklist.md` — Contrast validation, font verification, and compliance checklist
