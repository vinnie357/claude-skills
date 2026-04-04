# Playwright MCP Tools Reference

Full catalog of tools provided by the Playwright MCP server, organized by category. Core tools are always available. Optional tools require the `--caps` flag.

## Table of Contents

- [Navigation](#navigation)
- [Interaction](#interaction)
- [Input](#input)
- [Inspection](#inspection)
- [JavaScript](#javascript)
- [Tabs](#tabs)
- [Page Control](#page-control)
- [Network (--caps network)](#network)
- [Storage (--caps storage)](#storage)
- [DevTools (--caps devtools)](#devtools)
- [Vision (--caps vision)](#vision)
- [PDF (--caps pdf)](#pdf)
- [Testing (--caps testing)](#testing)

---

## Navigation

| Tool | Description |
|------|-------------|
| `browser_navigate` | Navigate to a URL. Parameters: `url` (required). |
| `browser_navigate_back` | Go back to the previous page in history. |
| `browser_navigate_forward` | Go forward to the next page in history. |

## Interaction

| Tool | Description |
|------|-------------|
| `browser_click` | Click an element on the page. Parameters: `element` (accessibility snapshot ref), `modifiers` (optional array of modifier keys). |
| `browser_hover` | Hover over an element. Parameters: `element` (accessibility snapshot ref). |
| `browser_drag` | Drag an element to a target location. Parameters: `startElement`, `endElement`. |
| `browser_select_option` | Select an option from a dropdown. Parameters: `element`, `values` (array of values to select). |

## Input

| Tool | Description |
|------|-------------|
| `browser_type` | Type text into a focused element. Parameters: `text` (required), `submit` (optional, press Enter after typing). |
| `browser_press_key` | Press a keyboard key or key combination. Parameters: `key` (e.g., `Enter`, `Control+c`, `ArrowDown`). |
| `browser_file_upload` | Upload files to a file input. Parameters: `paths` (array of absolute file paths). |
| `browser_handle_dialog` | Accept or dismiss a browser dialog (alert, confirm, prompt). Parameters: `accept` (boolean), `promptText` (optional). |

## Inspection

| Tool | Description |
|------|-------------|
| `browser_snapshot` | Capture the accessibility tree of the current page. Returns structured text representation of all visible elements with their refs. Primary tool for understanding page content. |
| `browser_take_screenshot` | Take a screenshot of the current page. Returns a base64-encoded image. Use for visual verification. |
| `browser_console_messages` | Retrieve console messages (log, warn, error) from the browser. |
| `browser_network_requests` | List network requests made by the page. |

## JavaScript

| Tool | Description |
|------|-------------|
| `browser_evaluate` | Execute JavaScript in the browser context. Parameters: `expression` (JavaScript code to evaluate). Returns the result as JSON. |

## Tabs

| Tool | Description |
|------|-------------|
| `browser_tab_new` | Open a new browser tab. Parameters: `url` (optional, navigate to URL after opening). |
| `browser_tab_list` | List all open browser tabs with their titles and URLs. |
| `browser_tab_select` | Switch to a specific tab. Parameters: `index` (tab index from tab_list). |
| `browser_tab_close` | Close a specific tab. Parameters: `index` (optional, closes current tab if omitted). |

## Page Control

| Tool | Description |
|------|-------------|
| `browser_close` | Close the browser and end the session. |
| `browser_resize` | Resize the browser viewport. Parameters: `width`, `height`. |
| `browser_wait_for` | Wait for a condition before proceeding. Parameters: `time` (ms to wait), `selector` (CSS selector to wait for), `state` (visible, hidden, attached, detached). |
| `browser_install` | Install a browser engine for Playwright. Parameters: `browser` (chromium, firefox, webkit). |

## Network

Requires `--caps network`.

| Tool | Description |
|------|-------------|
| `browser_network_state_set` | Enable or disable network. Parameters: `offline` (boolean). |
| `browser_route` | Set up a route to intercept network requests. Parameters: `url` (URL pattern), `response` (mock response object). |
| `browser_route_list` | List all active network routes. |
| `browser_unroute` | Remove a previously set network route. Parameters: `url` (URL pattern to remove). |

## Storage

Requires `--caps storage`.

| Tool | Description |
|------|-------------|
| `browser_cookies_get` | Get cookies for the current page or specified URLs. Parameters: `urls` (optional array). |
| `browser_cookies_set` | Set cookies. Parameters: `cookies` (array of cookie objects with name, value, domain, path, etc.). |
| `browser_cookies_clear` | Clear all cookies. Parameters: `domain` (optional, clear only for domain). |
| `browser_cookies_delete` | Delete specific cookies. Parameters: `name`, `domain` (optional). |
| `browser_local_storage_get` | Get localStorage values. Parameters: `key` (optional, returns all if omitted). |
| `browser_local_storage_set` | Set a localStorage value. Parameters: `key`, `value`. |
| `browser_local_storage_delete` | Delete a localStorage entry. Parameters: `key`. |
| `browser_session_storage_get` | Get sessionStorage values. Parameters: `key` (optional). |
| `browser_session_storage_set` | Set a sessionStorage value. Parameters: `key`, `value`. |
| `browser_session_storage_delete` | Delete a sessionStorage entry. Parameters: `key`. |
| `browser_storage_state` | Get the full storage state (cookies + localStorage) for saving. |
| `browser_set_storage_state` | Restore a previously saved storage state. Parameters: `state` (storage state object). |

## DevTools

Requires `--caps devtools`.

| Tool | Description |
|------|-------------|
| `browser_start_tracing` | Start collecting a performance trace. Parameters: `name` (optional trace name). |
| `browser_stop_tracing` | Stop tracing and return the trace data. |
| `browser_start_video` | Start recording a video of the browser. Parameters: `dir` (output directory). |
| `browser_stop_video` | Stop video recording. Returns the video file path. |
| `browser_video_chapter` | Add a chapter marker to the current video. Parameters: `title`. |
| `browser_resume` | Resume page execution after pausing (e.g., after a breakpoint). |

## Vision

Requires `--caps vision`. Uses pixel coordinates instead of accessibility tree refs.

| Tool | Description |
|------|-------------|
| `browser_mouse_click_xy` | Click at specific coordinates. Parameters: `x`, `y`, `button` (left, right, middle). |
| `browser_mouse_move_xy` | Move mouse to coordinates. Parameters: `x`, `y`. |
| `browser_mouse_drag_xy` | Drag from one coordinate to another. Parameters: `startX`, `startY`, `endX`, `endY`. |
| `browser_mouse_button` | Press or release a mouse button. Parameters: `button`, `action` (press, release). |
| `browser_mouse_wheel` | Scroll the mouse wheel. Parameters: `deltaX`, `deltaY`. |

## PDF

Requires `--caps pdf`.

| Tool | Description |
|------|-------------|
| `browser_pdf_save` | Save the current page as a PDF file. Parameters: `path` (output file path), `format` (e.g., A4, Letter), `landscape` (boolean). |

## Testing

Requires `--caps testing`. Tools for generating locators and verifying page state.

| Tool | Description |
|------|-------------|
| `browser_generate_locator` | Generate a Playwright locator for an element. Parameters: `element` (accessibility snapshot ref). Returns a locator string. |
| `browser_verify_element_visible` | Assert that an element matching a locator is visible. Parameters: `locator` (Playwright locator string). |
| `browser_verify_text_visible` | Assert that specific text is visible on the page. Parameters: `text`, `locator` (optional, scope to element). |
| `browser_verify_list_visible` | Assert that a list of text values are all visible. Parameters: `expected` (array of strings), `locator` (optional). |
| `browser_verify_value` | Assert that an input has a specific value. Parameters: `locator`, `value` (expected value). |
