---
name: playwright
description: "Playwright MCP server for Claude Code browser automation. Use when configuring Playwright MCP, automating browser interactions, taking screenshots, researching web content blocked by non-browser clients, testing web UI locally, or navigating web pages from Claude Code sessions."
license: MIT
---

# Playwright MCP

The Playwright MCP server gives Claude Code agents direct browser control through 50+ tools that operate on the accessibility tree rather than screenshots. This enables fast, structured web interaction — navigating pages, clicking elements, filling forms, extracting content, and taking screenshots — without requiring vision models.

## When to Use

Activate when:
- Installing or configuring the Playwright MCP server for Claude Code
- Browsing websites that reject non-browser HTTP clients (curl/wget blocked)
- Taking screenshots of web applications or local dev servers
- Automating browser interactions (clicking, typing, form submission)
- Running local web UI tests through browser automation
- Inspecting or extracting content from rendered web pages
- Managing browser tabs, dialogs, or file uploads in automation workflows

## Installation

### Claude Code (recommended)

```bash
# Default: bunx (preferred)
claude mcp add playwright -- bunx @playwright/mcp@latest

# Fallback: npx
claude mcp add playwright -- npx @playwright/mcp@latest
```

Verify the MCP server is connected by running `/mcp` in a Claude Code session.

### Runtime Requirement

Bun or Node.js 18+ must be available. Add to your project or global `mise.toml`:

```toml
[tools]
bun = "latest"
```

See `templates/mise.toml` for the full template.

## Configuration

### Global (all sessions)

Add to `~/.claude.json` to make Playwright available in every Claude Code session:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "bunx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

### Per-Project

Add to `.mcp.json` in the project root for project-scoped configuration:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "bunx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

### Configuration Flags

Pass flags after the package name in the `args` array or on the CLI:

```bash
claude mcp add playwright -- bunx @playwright/mcp@latest --headless --browser chromium
```

| Flag | Default | Description |
|------|---------|-------------|
| `--browser` | `chrome` | Browser engine: chrome, firefox, webkit, msedge |
| `--headless` | off (headed) | Run without visible browser window |
| `--allowed-origins` | none | Semicolon-separated trusted origins |
| `--blocked-origins` | none | Semicolon-separated blocked origins |
| `--proxy-server` | none | HTTP proxy (e.g., `http://proxy:3128`) |
| `--viewport-size` | browser default | Window size (e.g., `1280x720`) |
| `--device` | none | Emulate device (e.g., `iPhone 15`) |
| `--timeout-action` | `5000` | Action timeout in ms |
| `--timeout-navigation` | `60000` | Navigation timeout in ms |
| `--user-data-dir` | none | Persistent browser profile path |
| `--isolated` | off | Use in-memory profile only |
| `--storage-state` | none | Load saved session state (cookies, localStorage) |
| `--caps` | core only | Enable optional capabilities (see below) |
| `--config` | none | Path to configuration file |
| `--cdp-endpoint` | none | Connect to existing Chrome DevTools Protocol |

All flags support environment variable alternatives (e.g., `PLAYWRIGHT_MCP_HEADLESS=true`).

## Capabilities

The MCP server provides core tools by default. Enable additional capabilities with `--caps`:

```bash
claude mcp add playwright -- bunx @playwright/mcp@latest --caps "network,vision,pdf,testing"
```

| Capability | Flag | Description |
|------------|------|-------------|
| **Core** | always on | Navigation, clicking, typing, snapshots, screenshots, tabs, dialogs |
| **Network** | `network` | Monitor requests, set up routes, intercept traffic |
| **Storage** | `storage` | Cookie/localStorage/sessionStorage CRUD, save/restore state |
| **DevTools** | `devtools` | Tracing, video recording, console access |
| **Vision** | `vision` | Coordinate-based mouse interaction (click/move/drag by x,y) |
| **PDF** | `pdf` | Save pages as PDF files |
| **Testing** | `testing` | Locator generation, element/text/value assertions |

### JSON Configuration with Capabilities

```json
{
  "mcpServers": {
    "playwright": {
      "command": "bunx",
      "args": [
        "@playwright/mcp@latest",
        "--headless",
        "--caps",
        "network,vision,pdf,testing"
      ]
    }
  }
}
```

## Common Use Cases

### Web Research

Navigate to a URL and extract content when curl or fetch would be blocked:

```
Use browser_navigate to go to the URL, then browser_snapshot to read the page content.
```

### Screenshot Capture

Take screenshots of web applications or local dev servers:

```
Use browser_navigate to the target URL, then browser_take_screenshot to capture the page.
For local dev servers, navigate to http://localhost:<port>.
```

### Form Automation

Automate login flows, data entry, or form submission:

```
Use browser_snapshot to identify form elements, browser_click to focus inputs,
browser_type to enter values, then browser_click to submit.
```

### Local Dev Testing

Connect to a running local development server for UI verification:

```
Navigate to http://localhost:3000 (or your dev server port).
Use browser_snapshot to inspect the rendered page structure.
Use testing capability tools for assertions (requires --caps testing).
```

## Tool Categories

Core tools are always available. Optional tools require `--caps` flags.

| Category | Representative Tools | Capability |
|----------|---------------------|------------|
| **Navigation** | `browser_navigate`, `browser_navigate_back`, `browser_navigate_forward` | core |
| **Interaction** | `browser_click`, `browser_type`, `browser_select_option`, `browser_hover`, `browser_drag` | core |
| **Input** | `browser_press_key`, `browser_file_upload`, `browser_handle_dialog` | core |
| **Inspection** | `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages` | core |
| **JavaScript** | `browser_evaluate` | core |
| **Tabs** | `browser_tab_new`, `browser_tab_list`, `browser_tab_select`, `browser_tab_close` | core |
| **Page** | `browser_resize`, `browser_wait_for`, `browser_close` | core |
| **Network** | `browser_network_requests`, `browser_route`, `browser_unroute` | network |
| **Storage** | cookie/localStorage/sessionStorage CRUD, `browser_storage_state` | storage |
| **DevTools** | `browser_start_tracing`, `browser_stop_tracing`, `browser_start_video`, `browser_stop_video` | devtools |
| **Vision** | `browser_mouse_click_xy`, `browser_mouse_move_xy`, `browser_mouse_drag_xy` | vision |
| **PDF** | `browser_pdf_save` | pdf |
| **Testing** | `browser_generate_locator`, `browser_verify_element_visible`, `browser_verify_text_visible` | testing |

For the full tool catalog with parameters and descriptions, see `references/tools-reference.md`.

## Troubleshooting

### Browser Not Launching

- Verify bun or node is available: `bun --version` or `node --version`
- Try `--headless` flag for environments without a display
- Check if Playwright browsers are installed: `bunx playwright install chromium`

### Connection Issues

- Run `/mcp` in Claude Code to verify the server is listed and connected
- Check the MCP server logs for errors
- Ensure the command path is correct in your configuration

### Localhost Access

- Use `--allowed-origins` to explicitly allow localhost: `--allowed-origins "http://localhost:*"`
- Verify the dev server is running before navigating

### Timeouts

- Increase `--timeout-navigation` for slow-loading pages (default: 60000ms)
- Increase `--timeout-action` for slow element interactions (default: 5000ms)

### Vision Mode vs Structured Mode

- Default structured mode uses accessibility tree (faster, deterministic)
- Vision mode (`--caps vision`) adds coordinate-based interaction for elements not in the accessibility tree
- Prefer structured mode; use vision only when selectors are insufficient

## Anti-Fabrication

- Verify MCP connection status with `/mcp` before claiming Playwright tools are available
- Do not assume browser capabilities without checking `--caps` configuration
- Report actual page content from `browser_snapshot` output, not expected content
- When reporting test results from testing capability tools, include actual pass/fail output
- Reference `core:anti-fabrication` for full validation requirements

## Usage Rules

- Prefer `--headless` for CI, automated contexts, and agent workflows
- Use `--allowed-origins` to restrict navigation scope when working with sensitive applications
- Use vision capability only when structured selectors are insufficient
- Verify MCP connection with `/mcp` before attempting browser operations
- Use `browser_snapshot` (accessibility tree) over `browser_take_screenshot` (image) when extracting text content
- Close browser sessions when done to free resources
- For persistent auth, use `--storage-state` to save and restore session cookies
