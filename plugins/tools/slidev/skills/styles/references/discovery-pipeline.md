# Brand Discovery Pipeline

Step-by-step workflow for extracting brand tokens from a website using Playwright MCP tools.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Navigate to the Brand Site](#step-1-navigate-to-the-brand-site)
3. [Step 2: Extract CSS Custom Properties](#step-2-extract-css-custom-properties)
4. [Step 3: Extract Font Stacks](#step-3-extract-font-stacks)
5. [Step 4: Extract Colors from Key Elements](#step-4-extract-colors-from-key-elements)
6. [Step 5: Extract Spacing Patterns](#step-5-extract-spacing-patterns)
7. [Step 6: Extract Logo URL](#step-6-extract-logo-url)
8. [Handling Multiple URLs](#handling-multiple-urls)
9. [Fallback Strategies](#fallback-strategies)
10. [Parsing into Brand Config](#parsing-into-brand-config)
11. [Full Extraction Example](#full-extraction-example)

---

## Prerequisites

Ensure the Playwright MCP server is running and `browser_navigate`, `browser_evaluate`, `browser_take_screenshot`, `browser_snapshot`, and `browser_close` tools are available.

---

## Step 1: Navigate to the Brand Site

```
browser_navigate(url: "https://example.com")
```

Wait for the page to fully load before running extraction scripts. If the site uses a heavy JavaScript framework, add a brief pause or navigate to a stable page (style guide, about page).

Prefer style guide URLs over the homepage when available:
- `https://example.com/brand`
- `https://example.com/styleguide`
- `https://brand.example.com`

---

## Step 2: Extract CSS Custom Properties

Use `browser_evaluate` to read all CSS custom properties defined on `:root`:

```javascript
// Extract all CSS custom properties from :root
(() => {
  const styles = getComputedStyle(document.documentElement);
  const props = {};
  for (const sheet of document.styleSheets) {
    try {
      for (const rule of sheet.cssRules) {
        if (rule.selectorText === ':root') {
          const text = rule.cssText;
          const matches = text.matchAll(/--([\w-]+)\s*:\s*([^;]+)/g);
          for (const m of matches) {
            props[`--${m[1]}`] = styles.getPropertyValue(`--${m[1]}`).trim();
          }
        }
      }
    } catch (e) {
      // Cross-origin stylesheet — skip
    }
  }
  return props;
})()
```

The result is an object of custom property names to their computed values. Look for patterns like `--color-primary`, `--brand-blue`, `--font-heading`.

If no CSS custom properties are found, proceed to computed style extraction in the fallback section.

---

## Step 3: Extract Font Stacks

Extract the font families applied to headings and body text:

```javascript
// Extract font families from headings and body
(() => {
  const h1 = document.querySelector('h1');
  const h2 = document.querySelector('h2');
  const body = document.body;
  const p = document.querySelector('p');
  const code = document.querySelector('code, pre');

  const get = (el) => el
    ? getComputedStyle(el).fontFamily
    : null;

  return {
    h1Font: get(h1),
    h2Font: get(h2),
    bodyFont: get(body),
    pFont: get(p),
    codeFont: get(code)
  };
})()
```

Parse the returned font stack strings. The first family before the comma is the primary font. Strip quote characters. Example: `"Inter", sans-serif` → `Inter`.

---

## Step 4: Extract Colors from Key Elements

Extract colors from buttons, links, backgrounds, and primary text:

```javascript
// Extract colors from key UI elements
(() => {
  const button = document.querySelector(
    'button, a.btn, .button, [class*="btn"], [class*="button"]'
  );
  const link = document.querySelector('a:not([class])');
  const heading = document.querySelector('h1, h2');
  const bodyEl = document.body;

  const get = (el, prop) => el
    ? getComputedStyle(el)[prop]
    : null;

  return {
    buttonBg: get(button, 'backgroundColor'),
    buttonText: get(button, 'color'),
    linkColor: get(link, 'color'),
    headingColor: get(heading, 'color'),
    bodyBg: get(bodyEl, 'backgroundColor'),
    bodyText: get(bodyEl, 'color')
  };
})()
```

Convert `rgb(r, g, b)` values to hex using this helper:

```javascript
// RGB to hex converter — run in browser_evaluate or apply locally
const rgbToHex = (rgb) => {
  const m = rgb.match(/\d+/g);
  if (!m || m.length < 3) return null;
  return '#' + m.slice(0, 3)
    .map(n => parseInt(n).toString(16).padStart(2, '0'))
    .join('');
};
```

---

## Step 5: Extract Spacing Patterns

Extract padding and gap values from the page layout:

```javascript
// Extract spacing from main layout containers
(() => {
  const main = document.querySelector(
    'main, [role="main"], .container, .wrapper, section'
  );
  const section = document.querySelector('section');

  const get = (el, prop) => el
    ? getComputedStyle(el)[prop]
    : null;

  return {
    mainPadding: get(main, 'padding'),
    mainPaddingLeft: get(main, 'paddingLeft'),
    sectionGap: get(section, 'marginBottom') || get(section, 'paddingBottom')
  };
})()
```

Use these values as starting points. Adjust for slide context — slide padding is typically 2–4rem.

---

## Step 6: Extract Logo URL

Locate the brand logo image:

```javascript
// Find logo URL from common selectors
(() => {
  const candidates = [
    'header img',
    'nav img',
    '.logo img',
    '[class*="logo"] img',
    'a[href="/"] img',
    'img[alt*="logo" i]',
    'img[src*="logo" i]'
  ];

  for (const sel of candidates) {
    const el = document.querySelector(sel);
    if (el && el.src) return el.src;
  }

  // Try SVG logos
  const svg = document.querySelector(
    'header svg, nav svg, .logo svg, [class*="logo"] svg'
  );
  if (svg) {
    const title = svg.querySelector('title');
    return title ? `SVG: ${title.textContent}` : 'SVG logo found (no src)';
  }

  return null;
})()
```

If a full URL is returned, use it directly in the brand config. If a relative path is returned, prepend the site origin.

---

## Handling Multiple URLs

When a single page does not contain all brand information, extract from multiple pages:

1. Navigate to the homepage → extract primary colors and logo
2. Navigate to the style guide or brand page → extract secondary colors and font specs
3. Navigate to a documentation or blog page → verify body text rendering and spacing

Merge results, preferring values from the dedicated style guide page over the homepage.

---

## Fallback Strategies

When CSS custom properties are not available:

### Computed Style Extraction (full page scan)

```javascript
// Extract colors from all elements by frequency
(() => {
  const counts = {};
  for (const el of document.querySelectorAll('*')) {
    const s = getComputedStyle(el);
    for (const prop of ['color', 'backgroundColor', 'borderColor']) {
      const v = s[prop];
      if (v && v !== 'rgba(0, 0, 0, 0)' && v !== 'transparent') {
        counts[v] = (counts[v] || 0) + 1;
      }
    }
  }
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .map(([color, count]) => ({ color, count }));
})()
```

The most frequent colors are likely the brand palette. Manually classify: the dominant background color maps to `background`, the most frequent text color maps to `text`, the most frequent non-neutral color maps to `primary`.

### Screenshot Review

If JavaScript extraction fails (CSP restrictions, heavy SSR):

1. `browser_take_screenshot` of the homepage
2. Visually identify the primary color from the screenshot
3. Use `browser_snapshot` for the accessibility tree to find alt text and ARIA labels that may name colors

---

## Parsing into Brand Config

After running all extraction steps, classify the raw values into the brand config schema:

```javascript
// Mapping guide (apply manually after extraction)
const brandConfig = {
  colors: {
    primary: buttonBg || cssVars['--color-primary'] || cssVars['--brand-primary'],
    secondary: cssVars['--color-secondary'] || cssVars['--brand-secondary'],
    accent: cssVars['--color-accent'] || linkColor,
    background: bodyBg || cssVars['--color-background'] || '#ffffff',
    text: bodyText || cssVars['--color-text'] || headingColor,
    error: cssVars['--color-error'] || cssVars['--color-danger'],
    success: cssVars['--color-success'] || cssVars['--color-positive']
  },
  fonts: {
    heading: h1Font?.split(',')[0].replace(/"/g, '').trim(),
    body: pFont?.split(',')[0].replace(/"/g, '').trim(),
    code: codeFont?.split(',')[0].replace(/"/g, '').trim()
  },
  spacing: {
    'slide-padding': '3rem',   // Adjust from mainPaddingLeft or use default
    'section-gap': '2rem'      // Adjust from sectionGap or use default
  },
  logo: {
    url: logoUrl,
    position: 'top-left'
  }
};
```

Omit any field where no value was found. Save the completed object as `brand-config.json`.

---

## Full Extraction Example

Example extraction from a hypothetical brand site at `https://acme.example.com`:

**Step 1** — Navigate:
```
browser_navigate(url: "https://acme.example.com/brand")
```

**Step 2** — CSS vars result:
```json
{
  "--color-primary": "#1a73e8",
  "--color-text": "#202124",
  "--color-background": "#ffffff",
  "--font-heading": "Google Sans",
  "--font-body": "Roboto"
}
```

**Step 3** — Font extraction result:
```json
{
  "h1Font": "\"Google Sans\", sans-serif",
  "bodyFont": "\"Roboto\", sans-serif",
  "codeFont": "\"Roboto Mono\", monospace"
}
```

**Step 4** — Color extraction result:
```json
{
  "buttonBg": "rgb(26, 115, 232)",
  "bodyBg": "rgb(255, 255, 255)",
  "bodyText": "rgb(32, 33, 36)"
}
```

**Step 6** — Logo result:
```
"https://acme.example.com/static/logo.svg"
```

**Parsed brand config**:
```json
{
  "colors": {
    "primary": "#1a73e8",
    "background": "#ffffff",
    "text": "#202124"
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

Save as `brand-config.json`, then proceed to `references/theme-generation.md`.
