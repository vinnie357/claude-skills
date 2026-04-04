# Iframe and Standalone HTML5 Mock Patterns

Patterns for embedding self-contained HTML prototypes in Slidev using iframes.

## Table of Contents

1. [Directory Structure](#directory-structure)
2. [Self-Contained HTML Template](#self-contained-html-template)
3. [Slidev iframe Layouts](#slidev-iframe-layouts)
4. [Responsive Sizing](#responsive-sizing)
5. [postMessage Communication](#postmessage-communication)
6. [Loading External Mocks from URLs](#loading-external-mocks-from-urls)
7. [Click Events Within Iframes](#click-events-within-iframes)
8. [Asset Bundling Considerations](#asset-bundling-considerations)
9. [Worked Example: Standalone Dashboard Mock](#worked-example-standalone-dashboard-mock)

---

## Directory Structure

Place mocks under `public/mocks/` — Slidev serves `public/` at the root:

```
public/
└── mocks/
    ├── dashboard/
    │   ├── index.html     # Entry point
    │   ├── style.css      # Separate CSS (optional)
    │   └── app.js         # Separate JS (optional)
    ├── login-flow/
    │   └── index.html     # Self-contained (preferred for portability)
    └── settings-panel/
        └── index.html
```

Access in slides as `/mocks/<name>/index.html`.

For offline presentations, prefer self-contained HTML with inline styles and scripts — no external CDN dependencies.

---

## Self-Contained HTML Template

A minimal template with inlined CSS and JS:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Mock — Dashboard</title>
  <style>
    /* Reset and base */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      font-size: 14px;
      background: #f8fafc;
      color: #1e293b;
      /* Prevent scrollbars from appearing inside the iframe */
      overflow: hidden;
    }

    /* Layout */
    .app {
      display: grid;
      grid-template-rows: 48px 1fr;
      height: 100vh;
    }

    header {
      background: #1e293b;
      color: white;
      display: flex;
      align-items: center;
      padding: 0 1rem;
      font-weight: 600;
    }

    main {
      padding: 1rem;
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 1rem;
      align-content: start;
    }

    .card {
      background: white;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 1rem;
    }

    .card h2 { font-size: 0.75rem; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; }
    .card .value { font-size: 2rem; font-weight: 700; margin-top: 0.25rem; }

    /* Motion-safe animation */
    @media (prefers-reduced-motion: no-preference) {
      .value { transition: color 0.3s; }
      .value.updated { color: #4f46e5; }
    }
  </style>
</head>
<body>
  <div class="app" role="application" aria-label="Dashboard mock">
    <header>
      <span>Analytics Dashboard</span>
    </header>
    <main>
      <div class="card" role="region" aria-label="Requests per second">
        <h2>Requests/s</h2>
        <div class="value" id="rps" aria-live="polite" aria-atomic="true">—</div>
      </div>
      <div class="card" role="region" aria-label="Error rate">
        <h2>Error Rate</h2>
        <div class="value" id="errors" aria-live="polite" aria-atomic="true">—</div>
      </div>
      <div class="card" role="region" aria-label="P95 latency in milliseconds">
        <h2>P95 Latency</h2>
        <div class="value" id="latency" aria-live="polite" aria-atomic="true">—</div>
      </div>
    </main>
  </div>

  <script>
    const rpsEl = document.getElementById('rps')
    const errorsEl = document.getElementById('errors')
    const latencyEl = document.getElementById('latency')

    function flash(el) {
      el.classList.add('updated')
      setTimeout(() => el.classList.remove('updated'), 400)
    }

    function update() {
      rpsEl.textContent = (800 + Math.floor(Math.random() * 400)).toLocaleString()
      errorsEl.textContent = (Math.random() * 2).toFixed(2) + '%'
      latencyEl.textContent = (45 + Math.floor(Math.random() * 60)) + 'ms'
      flash(rpsEl)
      flash(errorsEl)
      flash(latencyEl)
    }

    update()
    setInterval(update, 1500)
  </script>
</body>
</html>
```

---

## Slidev iframe Layouts

### Full-Page iframe

```markdown
---
layout: iframe
url: /mocks/dashboard/index.html
---
```

The slide body is replaced entirely by the iframe. Add `class: "border-0"` to remove the default iframe border.

### iframe on the Right

```markdown
---
layout: iframe-right
url: /mocks/login-flow/index.html
---

## Login Flow

Walk the audience through each step:

1. User enters email and password
2. Client validates format before sending
3. Server returns a signed JWT (24h expiry)
4. Browser stores token in memory

Click **Send** in the demo to trigger the request.
```

### iframe on the Left

```markdown
---
layout: iframe-left
url: /mocks/settings-panel/index.html
---

## Settings Panel

The mock shows a typical settings page layout.
Note the sidebar navigation pattern — each section
is a separate route in the real application.
```

---

## Responsive Sizing

The iframe fills the layout area automatically. Design mocks to work within typical slide proportions (16:9 aspect ratio, ~900×506px effective area for the iframe half in split layouts).

Prevent overflow inside the mock:

```css
/* In mock's CSS */
html, body {
  width: 100%;
  height: 100%;
  overflow: hidden; /* Prevents scrollbars in the iframe */
}
```

For mocks that need scroll, limit the scrollable container and allow `overflow: auto` only on inner elements:

```css
body { overflow: hidden; }
.content-area { overflow-y: auto; max-height: calc(100vh - 48px); }
```

---

## postMessage Communication

### Sending from Iframe to Slide

```javascript
// Inside the mock (iframe)
function notifySlide(event, payload) {
  // Use '*' only for local development.
  // In production, replace '*' with the specific slide origin.
  window.parent.postMessage({ source: 'slidev-mock', event, payload }, '*')
}

// Example: user clicks a button in the mock
document.querySelector('#complete-btn').addEventListener('click', () => {
  notifySlide('step-complete', { step: 3, label: 'Payment' })
})
```

### Receiving in a Vue Wrapper Component

Wrap the iframe in a Vue component to handle messages:

```vue
<!-- components/IframeWithEvents.vue -->
<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const props = defineProps({
  src: { type: String, required: true },
  title: { type: String, required: true },
})

const emit = defineEmits(['mock-event'])
const lastEvent = ref(null)

function handleMessage(e) {
  if (e.data?.source !== 'slidev-mock') return
  lastEvent.value = e.data
  emit('mock-event', e.data)
}

onMounted(() => window.addEventListener('message', handleMessage))
onUnmounted(() => window.removeEventListener('message', handleMessage))
</script>

<template>
  <div class="iframe-wrapper">
    <iframe
      :src="src"
      :title="title"
      class="mock-iframe"
      sandbox="allow-scripts allow-same-origin"
    />
    <div v-if="lastEvent" class="event-log" aria-live="polite">
      Last event: {{ lastEvent.event }}
    </div>
  </div>
</template>

<style scoped>
.mock-iframe {
  width: 100%;
  height: 100%;
  border: none;
}
.iframe-wrapper {
  display: grid;
  grid-template-rows: 1fr auto;
  height: 100%;
}
.event-log {
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
  background: #f1f5f9;
  border-top: 1px solid #e2e8f0;
}
</style>
```

### Sending from Slide to Iframe

```vue
<script setup>
import { ref } from 'vue'
const iframeRef = ref(null)

function sendToMock(command, data) {
  iframeRef.value?.contentWindow?.postMessage(
    { source: 'slidev-parent', command, data },
    '*'
  )
}
</script>

<template>
  <button @click="sendToMock('reset', {})">Reset Mock</button>
  <iframe ref="iframeRef" src="/mocks/dashboard/index.html" title="Dashboard mock" />
</template>
```

```javascript
// Inside the mock, listen for parent commands
window.addEventListener('message', (e) => {
  if (e.data?.source !== 'slidev-parent') return
  if (e.data.command === 'reset') resetDashboard()
})
```

---

## Loading External Mocks from URLs

Use any publicly accessible URL as the iframe source:

```markdown
---
layout: iframe-right
url: https://example.com/demo
---

## Live Product Demo

The right panel shows the production demo environment.
```

Considerations:
- Requires network access during presentation
- The external page must allow framing (`X-Frame-Options: ALLOWALL` or no restriction)
- Behavior may change between presentation runs if the external site updates
- Prefer local mocks for conference presentations to avoid network dependency

---

## Click Events Within Iframes

Iframes are sandboxed — clicks inside do not propagate to the parent document. This means Slidev's click-to-advance (`v-click`) will not advance when clicking inside an iframe.

To advance slides from within an iframe:

```javascript
// Inside the mock — send advance command to parent
document.querySelector('#next-btn').addEventListener('click', () => {
  window.parent.postMessage({ source: 'slidev-mock', command: 'advance' }, '*')
})
```

```vue
<!-- In a Vue wrapper, listen and navigate -->
<script setup>
import { onMounted, onUnmounted } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $slidev } = useSlideContext()

function handleMessage(e) {
  if (e.data?.source === 'slidev-mock' && e.data?.command === 'advance') {
    $slidev.nav.next()
  }
}

onMounted(() => window.addEventListener('message', handleMessage))
onUnmounted(() => window.removeEventListener('message', handleMessage))
</script>
```

---

## Asset Bundling Considerations

### Fonts

Reference system fonts or bundle font files locally:

```css
/* System font stack — no network required */
font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;

/* Or copy font files into the mock directory */
@font-face {
  font-family: 'Inter';
  src: url('./fonts/Inter-Regular.woff2') format('woff2');
  font-display: swap;
}
```

### Images

Place images inside the mock directory and reference relatively:

```html
<img src="./screenshot.png" alt="Dashboard screenshot showing three metric cards" />
```

### CSS Frameworks

For offline use, download and bundle the framework CSS:

```html
<!-- Inline critical CSS; reference bundled file for the rest -->
<link rel="stylesheet" href="./vendor/tailwind.min.css" />
```

Avoid CDN links (`cdn.tailwindcss.com`) for presentations without guaranteed internet access.

### JavaScript Dependencies

Bundle dependencies inline or copy minified files:

```html
<!-- Copy into mock directory -->
<script src="./vendor/chart.umd.min.js"></script>

<!-- Or inline small utilities directly in the HTML -->
<script>
  // Inline utility (< 1KB): no network dependency
  function formatNumber(n) { return n.toLocaleString() }
</script>
```

---

## Worked Example: Standalone Dashboard Mock

A complete, offline-capable dashboard mock in a single HTML file:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Dashboard Mock</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --brand: #4f46e5;
      --surface: #ffffff;
      --bg: #f1f5f9;
      --border: #e2e8f0;
      --text: #1e293b;
      --muted: #64748b;
      --success: #16a34a;
      --danger: #dc2626;
    }

    html, body { height: 100%; overflow: hidden; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      font-size: 13px;
      background: var(--bg);
      color: var(--text);
    }

    .app { display: grid; grid-template-rows: 44px 1fr; height: 100%; }

    header {
      background: var(--text);
      color: white;
      display: flex;
      align-items: center;
      gap: 0.75rem;
      padding: 0 1rem;
    }

    header h1 { font-size: 0.9rem; font-weight: 600; }

    .status-dot {
      width: 8px;
      height: 8px;
      background: var(--success);
      border-radius: 50%;
      animation: pulse 2s infinite;
    }

    @media (prefers-reduced-motion: no-preference) {
      @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.4; }
      }
    }

    main {
      display: grid;
      grid-template-columns: 160px 1fr;
      overflow: hidden;
    }

    nav {
      background: var(--surface);
      border-right: 1px solid var(--border);
      padding: 0.75rem 0;
    }

    nav a {
      display: block;
      padding: 0.5rem 1rem;
      color: var(--muted);
      text-decoration: none;
      border-left: 3px solid transparent;
      cursor: pointer;
    }

    nav a.active {
      color: var(--brand);
      border-left-color: var(--brand);
      background: #ede9fe;
      font-weight: 600;
    }

    nav a:focus-visible {
      outline: 2px solid var(--brand);
      outline-offset: -2px;
    }

    .content { padding: 1rem; overflow-y: auto; }

    .metrics {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 0.75rem;
      margin-bottom: 1rem;
    }

    .metric-card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 0.75rem 1rem;
    }

    .metric-card .label { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--muted); }
    .metric-card .value { font-size: 1.6rem; font-weight: 700; margin-top: 0.2rem; }
    .metric-card .delta { font-size: 0.75rem; margin-top: 0.1rem; }
    .delta.up { color: var(--success); }
    .delta.down { color: var(--danger); }

    table {
      width: 100%;
      border-collapse: collapse;
      background: var(--surface);
      border-radius: 8px;
      overflow: hidden;
      border: 1px solid var(--border);
    }

    th, td { padding: 0.5rem 0.75rem; text-align: left; border-bottom: 1px solid var(--border); }
    th { background: var(--bg); font-weight: 600; font-size: 0.75rem; }
    td { font-size: 0.8rem; }
    tr:last-child td { border-bottom: none; }

    .badge {
      display: inline-block;
      padding: 0.1rem 0.4rem;
      border-radius: 4px;
      font-size: 0.7rem;
      font-weight: 600;
    }
    .badge.active { background: #dcfce7; color: var(--success); }
    .badge.inactive { background: #fee2e2; color: var(--danger); }
  </style>
</head>
<body>
  <div class="app" role="application" aria-label="Dashboard">
    <header>
      <div class="status-dot" aria-hidden="true"></div>
      <h1>Operations Dashboard</h1>
    </header>
    <main>
      <nav aria-label="Sections">
        <a class="active" tabindex="0" aria-current="page">Overview</a>
        <a tabindex="0">Services</a>
        <a tabindex="0">Alerts</a>
        <a tabindex="0">Settings</a>
      </nav>

      <div class="content">
        <div class="metrics" role="region" aria-label="Key metrics">
          <div class="metric-card">
            <div class="label">Requests/s</div>
            <div class="value" id="rps" aria-live="polite" aria-atomic="true">—</div>
            <div class="delta up" id="rps-delta" aria-live="polite">—</div>
          </div>
          <div class="metric-card">
            <div class="label">Error Rate</div>
            <div class="value" id="err" aria-live="polite" aria-atomic="true">—</div>
            <div class="delta" id="err-delta" aria-live="polite">—</div>
          </div>
          <div class="metric-card">
            <div class="label">P95 Latency</div>
            <div class="value" id="lat" aria-live="polite" aria-atomic="true">—</div>
            <div class="delta" id="lat-delta" aria-live="polite">—</div>
          </div>
        </div>

        <table aria-label="Service status">
          <thead>
            <tr><th>Service</th><th>Status</th><th>Uptime</th></tr>
          </thead>
          <tbody id="service-table">
            <tr><td>API Gateway</td><td><span class="badge active">Active</span></td><td>99.98%</td></tr>
            <tr><td>Auth Service</td><td><span class="badge active">Active</span></td><td>99.95%</td></tr>
            <tr><td>Job Queue</td><td><span class="badge inactive">Degraded</span></td><td>97.12%</td></tr>
          </tbody>
        </table>
      </div>
    </main>
  </div>

  <script>
    let prevRps = 0

    function update() {
      const rps = 800 + Math.floor(Math.random() * 400)
      const err = (Math.random() * 2).toFixed(2)
      const lat = 45 + Math.floor(Math.random() * 60)

      document.getElementById('rps').textContent = rps.toLocaleString()
      document.getElementById('err').textContent = err + '%'
      document.getElementById('lat').textContent = lat + 'ms'

      const delta = rps - prevRps
      const deltaEl = document.getElementById('rps-delta')
      deltaEl.textContent = (delta >= 0 ? '+' : '') + delta + ' from last'
      deltaEl.className = 'delta ' + (delta >= 0 ? 'up' : 'down')

      const errDelta = document.getElementById('err-delta')
      errDelta.textContent = parseFloat(err) < 1 ? 'Within threshold' : 'Above threshold'
      errDelta.className = 'delta ' + (parseFloat(err) < 1 ? 'up' : 'down')

      prevRps = rps
    }

    update()
    setInterval(update, 1500)

    // Keyboard nav for sidebar links
    document.querySelectorAll('nav a').forEach(link => {
      link.addEventListener('keydown', e => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          document.querySelectorAll('nav a').forEach(l => {
            l.classList.remove('active')
            l.removeAttribute('aria-current')
          })
          link.classList.add('active')
          link.setAttribute('aria-current', 'page')
        }
      })

      link.addEventListener('click', () => {
        document.querySelectorAll('nav a').forEach(l => {
          l.classList.remove('active')
          l.removeAttribute('aria-current')
        })
        link.classList.add('active')
        link.setAttribute('aria-current', 'page')
      })
    })
  </script>
</body>
</html>
```
