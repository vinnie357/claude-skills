# Theme Generation

Converting a brand config JSON into a Slidev theme using UnoCSS and CSS custom properties.

## Table of Contents

1. [Directory Structure](#directory-structure)
2. [CSS Custom Properties](#css-custom-properties)
3. [UnoCSS Theme Configuration](#unocsso-theme-configuration)
4. [Font Loading](#font-loading)
5. [Logo Component](#logo-component)
6. [Package Structure for Reusable Themes](#package-structure-for-reusable-themes)
7. [Complete Example](#complete-example)

---

## Directory Structure

Create the following files in the presentation project root:

```
presentation/
├── slides.md
├── brand-config.json
├── styles/
│   └── index.css         # CSS variables and base overrides
├── uno.config.ts         # UnoCSS theme extensions
├── components/
│   └── Logo.vue          # Global logo component
└── public/
    └── fonts/            # Local font files (if not using Google Fonts)
```

Slidev automatically loads `styles/index.css` and `uno.config.ts` when present.

---

## CSS Custom Properties

Map brand config values to CSS custom properties in `styles/index.css`:

```css
/* styles/index.css */

/* Google Fonts import — replace with local @font-face if using local files */
@import url('https://fonts.googleapis.com/css2?family=Google+Sans:wght@400;500;700&family=Roboto:wght@400;500&family=Roboto+Mono&display=swap');

:root {
  /* Brand colors */
  --brand-primary: #1a73e8;
  --brand-secondary: #5f6368;
  --brand-accent: #fbbc04;
  --brand-background: #ffffff;
  --brand-text: #202124;
  --brand-error: #d93025;
  --brand-success: #1e8e3e;

  /* Slidev color overrides */
  --slidev-theme-primary: var(--brand-primary);
  --slidev-theme-background: var(--brand-background);

  /* Spacing */
  --slide-padding: 3rem;
  --section-gap: 2rem;
}

/* Apply brand fonts to slide content */
.slidev-layout {
  font-family: 'Roboto', sans-serif;
  color: var(--brand-text);
  background-color: var(--brand-background);
  padding: var(--slide-padding);
}

.slidev-layout h1,
.slidev-layout h2,
.slidev-layout h3 {
  font-family: 'Google Sans', sans-serif;
  color: var(--brand-primary);
}

/* Code blocks */
.slidev-layout code,
.slidev-layout pre {
  font-family: 'Roboto Mono', monospace;
}
```

Replace font names and hex values with those from the actual brand config.

---

## UnoCSS Theme Configuration

Extend the UnoCSS theme in `uno.config.ts` to make brand colors available as utility classes:

```typescript
// uno.config.ts
import { defineConfig } from 'unocss';

export default defineConfig({
  theme: {
    colors: {
      brand: {
        primary: '#1a73e8',
        secondary: '#5f6368',
        accent: '#fbbc04',
        background: '#ffffff',
        text: '#202124',
        error: '#d93025',
        success: '#1e8e3e'
      }
    },
    fontFamily: {
      heading: ['Google Sans', 'sans-serif'],
      body: ['Roboto', 'sans-serif'],
      code: ['Roboto Mono', 'monospace']
    }
  },
  shortcuts: {
    // Slide section headings
    'slide-heading': 'font-heading text-brand-primary font-bold',
    // Callout boxes
    'callout': 'bg-brand-accent/20 border-l-4 border-brand-accent px-4 py-2 rounded',
    'callout-error': 'bg-brand-error/10 border-l-4 border-brand-error px-4 py-2 rounded',
    'callout-success': 'bg-brand-success/10 border-l-4 border-brand-success px-4 py-2 rounded',
    // Two-column layout helpers
    'col-content': 'flex-1 px-4',
    // Code block wrapper
    'code-panel': 'font-code bg-gray-50 rounded-lg p-4 text-sm'
  }
});
```

Replace color hex values with those from `brand-config.json`. The shortcut classes become available in slide markdown and Vue components.

---

## Font Loading

### Google Fonts (Recommended)

Add the `@import` at the top of `styles/index.css` (shown above). Use the exact font names from the brand config.

For multiple weights:

```css
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono&display=swap');
```

### Local Fonts

Place font files in `public/fonts/` and declare them with `@font-face`:

```css
/* styles/index.css */
@font-face {
  font-family: 'BrandFont';
  src: url('/fonts/BrandFont-Regular.woff2') format('woff2'),
       url('/fonts/BrandFont-Regular.woff') format('woff');
  font-weight: 400;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: 'BrandFont';
  src: url('/fonts/BrandFont-Bold.woff2') format('woff2');
  font-weight: 700;
  font-style: normal;
  font-display: swap;
}
```

Declare all weights and styles before using the family name in other rules.

---

## Logo Component

Create `components/Logo.vue` to display the brand logo on every slide:

```vue
<!-- components/Logo.vue -->
<script setup>
// Position driven by brand config logo.position value
const props = defineProps({
  position: {
    type: String,
    default: 'top-left'   // 'top-left' | 'top-right'
  }
});

const positionClass = {
  'top-left': 'top-4 left-6',
  'top-right': 'top-4 right-6'
};
</script>

<template>
  <div
    class="fixed z-10"
    :class="positionClass[position] || positionClass['top-left']"
  >
    <img
      src="/logo.svg"
      alt="Brand logo"
      class="h-8 w-auto"
    />
  </div>
</template>
```

Place the logo file at `public/logo.svg` (or `public/logo.png`). Slidev serves files from `public/` at the root path.

Reference the component in `slides.md` frontmatter to apply it globally:

```yaml
---
theme: default
title: My Presentation
layout: cover
---
```

Slidev auto-discovers Vue components in the `components/` directory. The `Logo.vue` component renders on every slide.

---

## Package Structure for Reusable Themes

To share a theme across multiple presentations, create a standalone theme package:

```
slidev-theme-brand/
├── package.json
├── README.md
├── styles/
│   └── index.css
├── uno.config.ts
└── components/
    └── Logo.vue
```

**`package.json`**:

```json
{
  "name": "slidev-theme-brand",
  "version": "0.1.0",
  "keywords": ["slidev-theme"],
  "exports": {
    ".": "./styles/index.css"
  },
  "slidev": {
    "colorSchema": "light",
    "highlighter": "shiki"
  }
}
```

The `keywords` array must include `"slidev-theme"` for Slidev to recognize the package.

Reference the local package in a presentation:

```yaml
---
theme: ./slidev-theme-brand
---
```

Or publish to npm and reference by package name:

```yaml
---
theme: slidev-theme-brand
---
```

---

## Complete Example

Starting from this brand config:

```json
{
  "colors": {
    "primary": "#1a73e8",
    "background": "#ffffff",
    "text": "#202124",
    "accent": "#fbbc04"
  },
  "fonts": {
    "heading": "Google Sans",
    "body": "Roboto",
    "code": "Roboto Mono"
  },
  "spacing": {
    "slide-padding": "3rem",
    "section-gap": "2rem"
  },
  "logo": {
    "url": "https://acme.example.com/static/logo.svg",
    "position": "top-left"
  }
}
```

**Result**: `styles/index.css` defines `--brand-primary: #1a73e8` and imports Roboto from Google Fonts. `uno.config.ts` adds `text-brand-primary` and `slide-heading` shortcut classes. `components/Logo.vue` renders the logo at the top-left corner of every slide. Slides use `class="slide-heading"` on headings to apply the brand font and color automatically.
