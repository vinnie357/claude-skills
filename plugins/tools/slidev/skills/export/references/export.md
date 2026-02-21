# Slidev Export Reference

## Export Methods

### Browser Exporter (since v0.50.0)

Access via the "Export" button in the navigation bar or navigate to:

```
http://localhost:<port>/export
```

Supports PDF export and image capture for PPTX/zip downloads. Requires a modern Chromium-based browser.

### CLI Export

Requires `playwright-chromium` as a dev dependency:

```bash
npm i -D playwright-chromium
# or: pnpm add -D / yarn add -D / bun add -D
```

## Export Formats

### PDF (Default)

```bash
slidev export
# Output: ./slides-export.pdf
```

### PPTX

```bash
slidev export --format pptx
```

- All slides exported as **images** (text is not selectable)
- Presenter notes are included per slide
- `--with-clicks` is **enabled by default** for PPTX

### PNG

```bash
slidev export --format png
```

Exports each slide as an individual PNG image.

### Markdown (with Embedded PNGs)

```bash
slidev export --format md
```

## CLI Flags for `slidev export`

| Flag | Short | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--output` | — | string | `exportFilename` or `[entry]-export` | Output file path |
| `--format` | — | `pdf`/`png`/`pptx`/`md` | `pdf` | Output format |
| `--timeout` | — | number | `30000` | Rendering timeout in ms |
| `--range` | — | string | — | Page ranges (e.g., `1,6-8,10`) |
| `--dark` | — | boolean | `false` | Export with dark theme |
| `--with-clicks` | `-c` | boolean | `false` | Export each click step as a page |
| `--with-toc` | — | boolean | `false` | Generate PDF outline (v0.36.10+) |
| `--theme` | `-t` | string | — | Override theme |
| `--omit-background` | — | boolean | `false` | Remove default browser background |
| `--executable-path` | — | string | — | Custom Chromium executable path |
| `--wait` | — | number | — | Wait time in ms after page load |
| `--wait-until` | — | string | `networkidle` | Page load event to wait for |

### `--wait-until` Values

| Value | Description |
|-------|-------------|
| `networkidle` | (Default) No network requests for 500ms |
| `domcontentloaded` | Wait for DOMContentLoaded event |
| `load` | Wait for load event |
| `none` | Do not wait for any event |

When specifying values other than `networkidle`, verify slides render completely.

### Export Examples

```bash
# PDF with dark theme
slidev export --dark

# Export specific slides
slidev export --range 1,6-8,10

# Export with click animations as separate pages
slidev export --with-clicks

# Custom output name
slidev export --output my-presentation

# PNG with transparent background
slidev export --format png --omit-background

# Multiple files
slidev export slides1.md slides2.md
slidev export *.md

# Large presentation with extended timeout
slidev export --timeout 60000
```

### Frontmatter Export Options

```yaml
---
exportFilename: my-presentation
export:
  format: pdf
  timeout: 30000
  dark: false
  withClicks: false
---
```

## SPA Build

Build a hostable single-page application:

```bash
slidev build
# Output: ./dist/
```

### Build CLI Flags

| Flag | Short | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--out` | `-o` | string | `dist` | Output directory |
| `--base` | — | string | `/` | Base URL path |
| `--download` | — | boolean | `false` | Enable PDF download in SPA |
| `--theme` | `-t` | string | — | Override theme |
| `--without-notes` | — | boolean | `false` | Exclude speaker notes |

### Build Examples

```bash
# Build for GitHub Pages subdirectory
slidev build --base /my-repo/

# Build with PDF download button
slidev build --download

# Build without speaker notes
slidev build --without-notes
```

SPA builds preserve interactive features (animations, presenter mode). Use SPA hosting over PDF/PPTX export when interactivity is needed.

## Other CLI Commands

### Development Server

```bash
slidev [entry]
# Default: slidev slides.md
```

| Flag | Short | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--port` | `-p` | number | `3030` | Port number |
| `--open` | `-o` | boolean | `false` | Open in browser |
| `--remote` | — | string | — | Listen on public host (optional password) |
| `--bind` | — | string | `0.0.0.0` | IP for remote mode |
| `--force` | `-f` | boolean | `false` | Ignore cache |
| `--theme` | `-t` | string | — | Override theme |

### Format Slides

```bash
slidev format [entry]
```

### Eject Theme

```bash
slidev theme eject [entry]
# --dir <path>  Output directory (default: theme)
```

## Troubleshooting Export

### Missing Content or Incomplete Animations

Add a wait delay:

```bash
slidev export --wait 1000
```

### Broken Emojis (Linux/CI)

Install emoji fonts:

```bash
curl -L --output NotoColorEmoji.ttf \
  https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf
sudo mv NotoColorEmoji.ttf /usr/local/share/fonts/
fc-cache -fv
```

### Custom Chromium for Codec Support

```bash
slidev export --executable-path /path/to/chromium
```

### Transparent PNG Background

When using `--omit-background`, also add CSS:

```css
* { background: transparent !important; }
```

### CLI Convention Notes

- Values accept space or `=`: `slidev --port 8080` or `slidev --port=8080`
- Boolean flags omit `true`: `slidev --open` equals `slidev --open true`
- npm scripts need `--` separator: `npm run slidev -- --remote --port 8080`
