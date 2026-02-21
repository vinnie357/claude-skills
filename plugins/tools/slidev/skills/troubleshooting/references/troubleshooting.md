# Slidev Troubleshooting Reference

## Export Issues

### PDF/PNG Export Fails or Hangs

**Symptom**: Export command hangs or times out.

**Solutions**:
1. Increase timeout for large presentations:
   ```bash
   slidev export --timeout 60000
   ```
2. Add wait time for slow-loading content:
   ```bash
   slidev export --wait 2000
   ```
3. Verify `playwright-chromium` is installed:
   ```bash
   npm i -D playwright-chromium
   npx playwright install chromium
   ```

### Missing Content in Exported PDF

**Symptom**: Slides appear incomplete, animations cut off, or elements missing.

**Solutions**:
1. Add explicit wait time:
   ```bash
   slidev export --wait 1000
   ```
2. Check `--wait-until` setting (default: `networkidle`). For presentations with delayed content:
   ```bash
   slidev export --wait-until load --wait 2000
   ```
3. Verify slides render correctly in the dev server before exporting.

### Broken Emojis in Export

**Symptom**: Emojis appear as squares or missing characters in PDF/PNG export.

**Solution**: Install emoji fonts on the system:

```bash
# Linux / CI
curl -L --output NotoColorEmoji.ttf \
  https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf
sudo mv NotoColorEmoji.ttf /usr/local/share/fonts/
fc-cache -fv
```

macOS includes emoji fonts by default and does not require this fix.

### PPTX Text Not Selectable

**Expected behavior**: PPTX export renders slides as images. Text selection is not supported in PPTX output. Use PDF export if selectable text is needed.

### Transparent Background in PNG Export

**Symptom**: PNG export has a white background even with `--omit-background`.

**Solution**: Add CSS alongside the flag:

```bash
slidev export --format png --omit-background
```

```css
/* Add to your slides or global styles */
* { background: transparent !important; }
```

## Font Issues

### Custom Fonts Not Loading

**Symptom**: Fonts fall back to system defaults.

**Solutions**:
1. Configure Google Fonts in headmatter:
   ```yaml
   ---
   fonts:
     sans: Inter
     serif: Merriweather
     mono: Fira Code
   ---
   ```
2. For local fonts, load them via CSS in `styles/` directory.
3. In CI/export environments, ensure fonts are available on the system or use web fonts.

### Fonts Different in Export vs Dev

**Symptom**: Exported PDF uses different fonts than the dev server.

**Solution**: Export uses a headless Chromium browser. Ensure fonts are installed on the export system. Use Google Fonts configuration in headmatter for consistent results across environments.

## Build and Development Errors

### Port Already in Use

**Symptom**: `Error: listen EADDRINUSE :::3030`

**Solution**: Use a different port:
```bash
slidev --port 3031
```

### Module Not Found

**Symptom**: `Cannot find module '@slidev/cli'` or similar.

**Solutions**:
1. Reinstall dependencies:
   ```bash
   rm -rf node_modules && npm install
   ```
2. Verify `@slidev/cli` is in `package.json` dependencies.
3. Clear Vite cache:
   ```bash
   slidev --force
   ```

### Theme Not Found

**Symptom**: `Theme "theme-name" not found`

**Solutions**:
1. Install the theme package:
   ```bash
   npm i slidev-theme-<name>
   ```
2. Use the full package name in headmatter:
   ```yaml
   ---
   theme: slidev-theme-seriph
   ---
   ```
3. For local themes, verify the path is correct.

## Configuration Mistakes

### Frontmatter Not Recognized

**Symptom**: YAML frontmatter is rendered as text instead of being parsed.

**Solutions**:
1. Ensure `---` separators are on their own lines with no trailing spaces.
2. Verify YAML syntax is valid (proper indentation, coloring after keys).
3. Headmatter must be at the very start of the file (no blank lines before it).

### MDC Syntax Not Working

**Symptom**: `::component::` syntax renders as text.

**Solution**: Enable MDC in headmatter:
```yaml
---
mdc: true
---
```

### Code Groups Not Rendering

**Symptom**: Code group tabs not appearing, code blocks render separately.

**Solution**: Code groups require MDC syntax enabled:
```yaml
---
mdc: true
---
```

### Monaco Editor Not Appearing

**Symptom**: Code block renders as static code instead of an editor.

**Solutions**:
1. Verify Monaco is enabled (default: `true`):
   ```yaml
   ---
   monaco: true
   ---
   ```
2. Monaco only works in dev server and SPA build, not in PDF/PPTX export.
3. Check that the code block uses `{monaco}` syntax:
   ````markdown
   ```ts {monaco}
   // Interactive editor
   ```
   ````

### Transitions Not Working

**Symptom**: Slides change without animation.

**Solutions**:
1. Verify transition name is valid: `fade`, `fade-out`, `slide-left`, `slide-right`, `slide-up`, `slide-down`.
2. Check frontmatter syntax:
   ```yaml
   ---
   transition: slide-left
   ---
   ```
3. Custom transitions require Vue transition component setup.

## Presenter Mode Issues

### Presenter Window Not Opening

**Solution**: Navigate to `http://localhost:3030/presenter` manually, or click the presenter icon in the navigation bar.

### Notes Not Showing in Presenter Mode

**Solutions**:
1. Verify notes use HTML comment syntax:
   ```markdown
   <!--
   Speaker notes here
   -->
   ```
2. Notes must be at the end of the slide content, after all other elements.

## CI/CD Export

### Headless Environment Setup

For CI pipelines, install Playwright browsers:

```bash
npx playwright install --with-deps chromium
```

The `--with-deps` flag installs system dependencies required by Chromium.

### GitHub Actions Example

```yaml
- name: Install dependencies
  run: npm ci
- name: Install Playwright
  run: npx playwright install --with-deps chromium
- name: Export slides
  run: npx slidev export --timeout 60000
```

### Docker Export

Use a container with Chromium pre-installed, or install Playwright deps:

```dockerfile
RUN npx playwright install --with-deps chromium
```
