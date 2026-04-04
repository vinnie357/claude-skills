# Validation Checklist

Compliance validation for Slidev presentations against brand standards and WCAG 2.1 AA contrast requirements.

## Table of Contents

1. [Screenshot Capture](#screenshot-capture)
2. [Contrast Ratio Calculation](#contrast-ratio-calculation)
3. [Font Verification](#font-verification)
4. [Color Compliance](#color-compliance)
5. [Logo Verification](#logo-verification)
6. [Automated Checks via browser_evaluate](#automated-checks-via-browser_evaluate)
7. [Manual Review Checklist](#manual-review-checklist)
8. [Integration with core:accessibility](#integration-with-coreaccessibility)

---

## Screenshot Capture

Capture rendered slides for visual review using Playwright MCP:

1. Start the Slidev dev server: `npx slidev --port 3030`
2. Navigate to each slide:
   ```
   browser_navigate(url: "http://localhost:3030/1")
   browser_take_screenshot()
   browser_navigate(url: "http://localhost:3030/2")
   browser_take_screenshot()
   ```
3. Review screenshots for visual brand compliance before running automated checks

Capture at least the cover slide, a content slide, and a code slide to cover the range of layouts.

---

## Contrast Ratio Calculation

Use `browser_evaluate` to calculate WCAG 2.1 contrast ratios programmatically.

### WCAG AA Requirements

| Content Type | Minimum Ratio |
|---|---|
| Normal text (< 18pt or < 14pt bold) | 4.5:1 |
| Large text (≥ 18pt or ≥ 14pt bold) | 3:1 |
| UI components and graphical objects | 3:1 |

### JavaScript for Contrast Calculation

```javascript
// Paste into browser_evaluate on a rendered slide page
(() => {
  // Convert sRGB component to linear
  const toLinear = (c) => {
    const v = c / 255;
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  };

  // Relative luminance from rgb string "rgb(r, g, b)"
  const luminance = (rgb) => {
    const m = rgb.match(/\d+/g);
    if (!m) return null;
    const [r, g, b] = m.map(Number);
    return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
  };

  // Contrast ratio between two luminance values
  const contrast = (l1, l2) => {
    const lighter = Math.max(l1, l2);
    const darker = Math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  };

  // Check text elements on the page
  const results = [];
  const textEls = document.querySelectorAll('h1, h2, h3, h4, p, li, td, th, span, a');

  for (const el of textEls) {
    const style = getComputedStyle(el);
    const color = style.color;
    const bg = style.backgroundColor;

    if (!color || bg === 'rgba(0, 0, 0, 0)') continue;

    const textLum = luminance(color);
    const bgLum = luminance(bg);

    if (textLum === null || bgLum === null) continue;

    const ratio = contrast(textLum, bgLum);
    const fontSize = parseFloat(style.fontSize);
    const fontWeight = style.fontWeight;
    const isLargeText = fontSize >= 24 || (fontSize >= 18.67 && parseInt(fontWeight) >= 700);
    const threshold = isLargeText ? 3 : 4.5;
    const passes = ratio >= threshold;

    if (!passes) {
      results.push({
        tag: el.tagName,
        text: el.textContent.slice(0, 40),
        color,
        background: bg,
        ratio: ratio.toFixed(2),
        required: threshold,
        passes
      });
    }
  }

  return results.length === 0
    ? 'All checked elements pass WCAG AA contrast'
    : results;
})()
```

Review the returned array. Each failing entry shows the element tag, text preview, colors, and the actual vs required ratio.

---

## Font Verification

Verify that rendered font families match the brand spec:

```javascript
// Check font families on key elements
(() => {
  const checks = [
    { selector: 'h1', expected: 'Google Sans' },
    { selector: 'h2', expected: 'Google Sans' },
    { selector: 'p',  expected: 'Roboto' },
    { selector: 'code', expected: 'Roboto Mono' }
  ];

  return checks.map(({ selector, expected }) => {
    const el = document.querySelector(selector);
    if (!el) return { selector, status: 'element not found' };

    const rendered = getComputedStyle(el).fontFamily;
    const passes = rendered.toLowerCase().includes(expected.toLowerCase());
    return { selector, expected, rendered, passes };
  });
})()
```

Replace the expected font names with those from `brand-config.json`. A `passes: false` result means the font did not load — check the import URL or font file path.

---

## Color Compliance

Verify that background and text colors match the brand palette within tolerance:

```javascript
// Check colors against brand palette with tolerance
(() => {
  const palette = {
    primary: [26, 115, 232],    // #1a73e8
    background: [255, 255, 255], // #ffffff
    text: [32, 33, 36]          // #202124
  };

  const TOLERANCE = 5; // ±5 per channel

  const withinTolerance = (actual, expected) => {
    const m = actual.match(/\d+/g);
    if (!m) return false;
    return expected.every((v, i) => Math.abs(parseInt(m[i]) - v) <= TOLERANCE);
  };

  const results = {};
  const heading = document.querySelector('h1, h2');
  const body = document.body;

  if (heading) {
    const color = getComputedStyle(heading).color;
    results.headingColor = {
      rendered: color,
      matchesPrimary: withinTolerance(color, palette.primary)
    };
  }

  const bg = getComputedStyle(body).backgroundColor;
  results.bodyBackground = {
    rendered: bg,
    matchesBackground: withinTolerance(bg, palette.background)
  };

  const p = document.querySelector('p');
  if (p) {
    const textColor = getComputedStyle(p).color;
    results.bodyText = {
      rendered: textColor,
      matchesText: withinTolerance(textColor, palette.text)
    };
  }

  return results;
})()
```

Replace the `palette` values with the RGB equivalents from `brand-config.json` hex colors.

---

## Logo Verification

Verify logo placement and visibility:

```javascript
// Check logo element presence and position
(() => {
  const logo = document.querySelector(
    'img[alt*="logo" i], img[src*="logo" i], [class*="logo"] img'
  );

  if (!logo) return { found: false };

  const rect = logo.getBoundingClientRect();
  const style = getComputedStyle(logo);

  return {
    found: true,
    src: logo.src,
    alt: logo.alt,
    width: rect.width,
    height: rect.height,
    top: rect.top,
    left: rect.left,
    visible: style.visibility !== 'hidden' && style.display !== 'none'
  };
})()
```

Confirm:
- `found: true` — logo element is present
- `visible: true` — logo is not hidden
- `alt` is non-empty — logo has descriptive alt text (accessibility requirement)
- `height` is between 24px and 64px — typical logo height range for presentations

---

## Automated Checks via browser_evaluate

Run all checks in a single `browser_evaluate` call for efficiency:

```javascript
// Combined brand validation
(() => {
  const report = { contrast: [], fonts: [], logo: null };

  // -- Contrast (abbreviated) --
  const toLinear = c => { const v = c/255; return v<=0.03928 ? v/12.92 : Math.pow((v+0.055)/1.055,2.4); };
  const luminance = rgb => { const m=rgb.match(/\d+/g); if(!m) return null; return 0.2126*toLinear(+m[0])+0.7152*toLinear(+m[1])+0.0722*toLinear(+m[2]); };
  const ratio = (l1,l2) => (Math.max(l1,l2)+0.05)/(Math.min(l1,l2)+0.05);

  for (const el of document.querySelectorAll('h1,h2,p')) {
    const s = getComputedStyle(el);
    const tl = luminance(s.color), bl = luminance(s.backgroundColor);
    if (tl!==null && bl!==null) {
      const r = ratio(tl, bl);
      report.contrast.push({ tag: el.tagName, ratio: r.toFixed(2), passes: r >= 4.5 });
    }
  }

  // -- Fonts --
  const headEl = document.querySelector('h1');
  const bodyEl = document.querySelector('p');
  if (headEl) report.fonts.push({ element: 'h1', family: getComputedStyle(headEl).fontFamily });
  if (bodyEl) report.fonts.push({ element: 'p', family: getComputedStyle(bodyEl).fontFamily });

  // -- Logo --
  const logoEl = document.querySelector('img[alt*="logo" i], img[src*="logo" i]');
  report.logo = logoEl ? { found: true, alt: logoEl.alt } : { found: false };

  return report;
})()
```

---

## Manual Review Checklist

Complete this checklist after automated checks pass:

### Brand Colors
- [ ] Heading color matches `brand-config.json` `colors.primary`
- [ ] Background color matches `colors.background`
- [ ] Body text color matches `colors.text`
- [ ] Accent color appears correctly on callout boxes
- [ ] No unauthorized colors appear in slide content

### Typography
- [ ] Heading font renders as specified in `fonts.heading`
- [ ] Body text renders as specified in `fonts.body`
- [ ] Code blocks render as specified in `fonts.code`
- [ ] Font weights are consistent (headings bold, body regular)

### Contrast
- [ ] All body text passes 4.5:1 WCAG AA contrast check
- [ ] All large headings pass 3:1 WCAG AA contrast check
- [ ] Code text on code block background passes 4.5:1
- [ ] No white text on light backgrounds

### Logo
- [ ] Logo appears on every slide in the correct position
- [ ] Logo does not overlap slide content
- [ ] Logo alt text is present and descriptive
- [ ] Logo is sized proportionally (24–64px height)

### Spacing
- [ ] Slide content does not touch the slide edges
- [ ] Padding matches `spacing.slide-padding` from brand config
- [ ] Section spacing is consistent across slides

---

## Integration with core:accessibility

Load `core:accessibility` when:
- Automated contrast checks report failures requiring remediation guidance
- Slides contain charts, diagrams, or images that may need alt text
- Reviewing keyboard navigation for interactive slide components

WCAG 2.1 AA requirements enforced by this checklist align with `core:accessibility` guidelines. For remediation steps when contrast checks fail:

1. Darken the foreground color until the ratio meets the threshold
2. Or lighten the background color until the ratio meets the threshold
3. Use the contrast calculation script above to verify after each change
4. Do not rely on color alone — add patterns, labels, or icons to convey meaning
