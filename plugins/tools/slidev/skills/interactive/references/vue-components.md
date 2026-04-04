# Vue Component Patterns for Slidev

Detailed patterns for building interactive Vue 3 components within Slidev presentations.

## Table of Contents

1. [Basic Interactive Components](#basic-interactive-components)
2. [Form Mock with Validation](#form-mock-with-validation)
3. [Dashboard with SVG Charts](#dashboard-with-svg-charts)
4. [Multi-Step Wizard](#multi-step-wizard)
5. [Slide-Aware Behavior](#slide-aware-behavior)
6. [Click-to-Advance Integration](#click-to-advance-integration)
7. [Props from Slide Frontmatter](#props-from-slide-frontmatter)
8. [Hot Reload Behavior](#hot-reload-behavior)
9. [Worked Example: Interactive API Explorer](#worked-example-interactive-api-explorer)

---

## Basic Interactive Components

### Toggle

```vue
<!-- components/ToggleDemo.vue -->
<script setup>
import { ref } from 'vue'
const enabled = ref(false)
</script>

<template>
  <button
    role="switch"
    :aria-checked="enabled"
    @click="enabled = !enabled"
    class="toggle"
    :class="{ active: enabled }"
  >
    <span class="track" aria-hidden="true" />
    <span class="thumb" aria-hidden="true" />
    <span class="label">{{ enabled ? 'On' : 'Off' }}</span>
  </button>
</template>

<style scoped>
.toggle {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  background: none;
  border: 2px solid #94a3b8;
  border-radius: 999px;
  padding: 0.25rem 0.75rem;
}
.toggle.active {
  border-color: #4f46e5;
  background: #ede9fe;
}
.track {
  width: 2rem;
  height: 1rem;
  background: #cbd5e1;
  border-radius: 999px;
  transition: background 0.2s;
}
.toggle.active .track { background: #4f46e5; }
.thumb {
  width: 0.75rem;
  height: 0.75rem;
  background: white;
  border-radius: 50%;
  margin-left: -2rem;
  transition: transform 0.2s;
}
.toggle.active .thumb { transform: translateX(1rem); }
</style>
```

### Counter

```vue
<!-- components/Counter.vue -->
<script setup>
import { ref } from 'vue'
const props = defineProps({
  min: { type: Number, default: 0 },
  max: { type: Number, default: 10 },
  step: { type: Number, default: 1 },
})
const count = ref(props.min)
const decrement = () => { if (count.value > props.min) count.value -= props.step }
const increment = () => { if (count.value < props.max) count.value += props.step }
</script>

<template>
  <div class="counter" role="group" aria-label="Counter">
    <button @click="decrement" :disabled="count <= min" aria-label="Decrease">−</button>
    <output class="value" aria-live="polite">{{ count }}</output>
    <button @click="increment" :disabled="count >= max" aria-label="Increase">+</button>
  </div>
</template>
```

---

## Form Mock with Validation

Demonstrates input validation with accessible error feedback:

```vue
<!-- components/LoginForm.vue -->
<script setup>
import { ref, computed } from 'vue'

const email = ref('')
const password = ref('')
const submitted = ref(false)
const loading = ref(false)
const success = ref(false)

const emailError = computed(() => {
  if (!submitted.value) return null
  if (!email.value) return 'Email is required'
  if (!email.value.includes('@')) return 'Enter a valid email address'
  return null
})

const passwordError = computed(() => {
  if (!submitted.value) return null
  if (!password.value) return 'Password is required'
  if (password.value.length < 8) return 'Password must be at least 8 characters'
  return null
})

const isValid = computed(() => !emailError.value && !passwordError.value && email.value && password.value)

async function handleSubmit() {
  submitted.value = true
  if (!isValid.value) return
  loading.value = true
  await new Promise(r => setTimeout(r, 1200))
  loading.value = false
  success.value = true
}
</script>

<template>
  <div class="form-demo">
    <div v-if="success" role="status" class="success-banner">
      Signed in as {{ email }}
    </div>

    <form v-else @submit.prevent="handleSubmit" novalidate aria-label="Login form demonstration">
      <div class="field">
        <label for="login-email">Email address</label>
        <input
          id="login-email"
          v-model="email"
          type="email"
          autocomplete="email"
          :aria-invalid="!!emailError"
          :aria-describedby="emailError ? 'email-error' : undefined"
          aria-required="true"
        />
        <p v-if="emailError" id="email-error" role="alert" class="field-error">
          {{ emailError }}
        </p>
      </div>

      <div class="field">
        <label for="login-password">Password</label>
        <input
          id="login-password"
          v-model="password"
          type="password"
          autocomplete="current-password"
          :aria-invalid="!!passwordError"
          :aria-describedby="passwordError ? 'password-error' : undefined"
          aria-required="true"
        />
        <p v-if="passwordError" id="password-error" role="alert" class="field-error">
          {{ passwordError }}
        </p>
      </div>

      <button type="submit" :disabled="loading" :aria-busy="loading">
        {{ loading ? 'Signing in…' : 'Sign in' }}
      </button>
    </form>
  </div>
</template>
```

---

## Dashboard with SVG Charts

Use inline SVG for charts without external dependencies:

```vue
<!-- components/MetricsDashboard.vue -->
<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'

const history = ref(Array.from({ length: 20 }, () => Math.floor(Math.random() * 80 + 20)))
let interval

onMounted(() => {
  interval = setInterval(() => {
    history.value = [...history.value.slice(1), Math.floor(Math.random() * 80 + 20)]
  }, 800)
})

onUnmounted(() => clearInterval(interval))

const svgPoints = computed(() => {
  const w = 200, h = 60
  return history.value
    .map((v, i) => `${(i / (history.value.length - 1)) * w},${h - (v / 100) * h}`)
    .join(' ')
})
</script>

<template>
  <div class="dashboard" role="region" aria-label="Metrics dashboard">
    <h3>Request Throughput</h3>
    <svg viewBox="0 0 200 60" aria-hidden="true" class="sparkline">
      <polyline :points="svgPoints" fill="none" stroke="#4f46e5" stroke-width="2" />
    </svg>
    <p aria-live="polite" aria-atomic="true">
      Current: {{ history[history.length - 1] }} req/s
    </p>
  </div>
</template>
```

---

## Multi-Step Wizard

State machine for a multi-step flow:

```vue
<!-- components/SetupWizard.vue -->
<script setup>
import { ref, computed } from 'vue'

const steps = [
  { id: 'account', label: 'Account', fields: ['name', 'email'] },
  { id: 'plan', label: 'Plan', fields: ['tier'] },
  { id: 'review', label: 'Review', fields: [] },
  { id: 'done', label: 'Done', fields: [] },
]
const current = ref(0)
const formData = ref({ name: '', email: '', tier: 'starter' })

const isFirst = computed(() => current.value === 0)
const isLast = computed(() => current.value === steps.length - 1)
const isDone = computed(() => current.value === steps.length - 1)

function next() { if (!isLast.value) current.value++ }
function back() { if (!isFirst.value) current.value-- }
</script>

<template>
  <div class="wizard" role="region" aria-label="Setup wizard">
    <nav aria-label="Wizard progress">
      <ol class="step-indicators">
        <li
          v-for="(step, i) in steps"
          :key="step.id"
          :aria-current="i === current ? 'step' : undefined"
          :class="{ active: i === current, done: i < current }"
        >
          {{ step.label }}
        </li>
      </ol>
    </nav>

    <div class="step-body" role="group" :aria-labelledby="`step-heading-${current}`">
      <h3 :id="`step-heading-${current}`">{{ steps[current].label }}</h3>

      <!-- Account step -->
      <template v-if="current === 0">
        <label for="wiz-name">Full name</label>
        <input id="wiz-name" v-model="formData.name" type="text" aria-required="true" />
        <label for="wiz-email">Email</label>
        <input id="wiz-email" v-model="formData.email" type="email" aria-required="true" />
      </template>

      <!-- Plan step -->
      <template v-else-if="current === 1">
        <fieldset>
          <legend>Choose a plan</legend>
          <label><input type="radio" v-model="formData.tier" value="starter" /> Starter</label>
          <label><input type="radio" v-model="formData.tier" value="pro" /> Pro</label>
          <label><input type="radio" v-model="formData.tier" value="enterprise" /> Enterprise</label>
        </fieldset>
      </template>

      <!-- Review step -->
      <template v-else-if="current === 2">
        <dl>
          <dt>Name</dt><dd>{{ formData.name || '(not set)' }}</dd>
          <dt>Email</dt><dd>{{ formData.email || '(not set)' }}</dd>
          <dt>Plan</dt><dd>{{ formData.tier }}</dd>
        </dl>
      </template>

      <!-- Done step -->
      <template v-else>
        <p role="status">Account created. Welcome, {{ formData.name || 'User' }}!</p>
      </template>
    </div>

    <div class="wizard-actions">
      <button @click="back" :disabled="isFirst">Back</button>
      <button @click="next" :disabled="isDone">
        {{ current === steps.length - 2 ? 'Create Account' : 'Next' }}
      </button>
    </div>
  </div>
</template>
```

---

## Slide-Aware Behavior

Use `useSlideContext` to read Slidev navigation state:

```vue
<script setup>
import { useSlideContext } from '@slidev/client'
import { computed } from 'vue'

const { $slidev } = useSlideContext()

// Current click count on this slide (increments with each v-click)
const clicks = computed(() => $slidev.nav.clicks)

// Total slides
const total = computed(() => $slidev.nav.total)

// True when in presenter mode
const isPresenter = computed(() => $slidev.nav.isPresenter)

// Detect export rendering (disable timers/animations in export)
const isExporting = computed(() => $slidev.nav.isExporting)
</script>

<template>
  <div>
    <!-- Show different content based on click count -->
    <div v-if="clicks >= 1" class="step">Step 1 revealed</div>
    <div v-if="clicks >= 2" class="step">Step 2 revealed</div>

    <!-- Suppress live updates during export -->
    <LiveChart v-if="!isExporting" />
    <StaticChartImage v-else />
  </div>
</template>
```

---

## Click-to-Advance Integration

Two approaches for binding component state to slide clicks:

### Approach 1: Pass $clicks as prop

```markdown
<!-- slides.md -->
<WorkflowStepper :step="$clicks" :max-steps="4" />
```

```vue
<!-- components/WorkflowStepper.vue -->
<script setup>
defineProps({ step: Number, maxSteps: { type: Number, default: 4 } })
</script>

<template>
  <div class="stepper">
    <div
      v-for="i in maxSteps"
      :key="i"
      class="step-node"
      :class="{ active: step === i - 1, done: step > i - 1 }"
      :aria-current="step === i - 1 ? 'step' : undefined"
    >
      Step {{ i }}
    </div>
  </div>
</template>
```

### Approach 2: v-click wrapper

```markdown
<!-- Reveal entire component on first click -->
<v-click>
  <InteractiveDemo />
</v-click>

<!-- Reveal sections within a component -->
<ProgressiveForm :reveal-fields="$clicks" />
```

---

## Props from Slide Frontmatter

Pass configuration from slide frontmatter into components:

```markdown
---
layout: default
demoEndpoint: /api/v2/widgets
demoTheme: dark
---

<ApiExplorer
  :endpoint="$frontmatter.demoEndpoint"
  :theme="$frontmatter.demoTheme"
/>
```

```vue
<script setup>
const props = defineProps({
  endpoint: { type: String, default: '/api/example' },
  theme: { type: String, default: 'light' },
})
</script>
```

---

## Hot Reload Behavior

During development with `npx slidev`:

- Vite HMR reloads components on save
- Component state resets on HMR reload — this is expected behavior
- Interval timers must be cleared in `onUnmounted` to avoid memory leaks after hot reload
- `useSlideContext()` reconnects automatically after reload

```vue
<script setup>
import { onMounted, onUnmounted } from 'vue'

let timer = null

onMounted(() => {
  timer = setInterval(tick, 1000)
})

onUnmounted(() => {
  // Always clear — prevents duplicate intervals after HMR
  if (timer) clearInterval(timer)
})
</script>
```

---

## Worked Example: Interactive API Explorer

A complete component that demonstrates REST API calls with request/response display:

```vue
<!-- components/ApiExplorer.vue -->
<script setup>
import { ref, computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $slidev } = useSlideContext()

const props = defineProps({
  endpoint: { type: String, default: '/api/widgets' },
  method: { type: String, default: 'GET' },
})

const phase = ref('idle')     // idle | sending | success | error
const response = ref(null)
const statusCode = ref(null)
const requestBody = ref('{\n  "name": "My Widget"\n}')

const showBody = computed(() => ['POST', 'PUT', 'PATCH'].includes(props.method))
const isDisabled = computed(() => phase.value === 'sending' || $slidev.nav.isExporting)

async function sendRequest() {
  phase.value = 'sending'
  response.value = null
  statusCode.value = null

  // Simulate network call
  await new Promise(r => setTimeout(r, 900 + Math.random() * 400))

  // Mock response
  statusCode.value = 200
  response.value = {
    id: Math.floor(Math.random() * 1000),
    name: 'My Widget',
    createdAt: new Date().toISOString(),
    status: 'active',
  }
  phase.value = 'success'
}

function reset() {
  phase.value = 'idle'
  response.value = null
  statusCode.value = null
}
</script>

<template>
  <div class="api-explorer" role="region" aria-label="API explorer">
    <!-- Request Panel -->
    <div class="request-panel">
      <div class="request-line">
        <span class="method" :class="method.toLowerCase()">{{ method }}</span>
        <code class="endpoint">{{ endpoint }}</code>
        <button
          @click="sendRequest"
          :disabled="isDisabled"
          :aria-busy="phase === 'sending'"
        >
          {{ phase === 'sending' ? 'Sending…' : 'Send' }}
        </button>
      </div>

      <div v-if="showBody" class="body-editor">
        <label for="req-body">Request body (JSON)</label>
        <textarea
          id="req-body"
          v-model="requestBody"
          :disabled="phase === 'sending'"
          rows="4"
          aria-label="Request body JSON"
        />
      </div>
    </div>

    <!-- Response Panel -->
    <div
      class="response-panel"
      aria-live="polite"
      :aria-busy="phase === 'sending'"
    >
      <template v-if="phase === 'idle'">
        <span class="placeholder">Response will appear here</span>
      </template>

      <template v-else-if="phase === 'sending'">
        <span class="loading" aria-label="Loading">Waiting for response…</span>
      </template>

      <template v-else>
        <div class="response-header">
          <span
            class="status-badge"
            :class="statusCode < 300 ? 'ok' : 'error'"
          >
            {{ statusCode }}
          </span>
          <button @click="reset" class="reset-btn" aria-label="Clear response">
            Clear
          </button>
        </div>
        <pre class="response-body">{{ JSON.stringify(response, null, 2) }}</pre>
      </template>
    </div>
  </div>
</template>

<style scoped>
.api-explorer {
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 1rem;
  font-family: monospace;
}

.request-line {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.method {
  font-weight: 700;
  padding: 0.1rem 0.4rem;
  border-radius: 4px;
  font-size: 0.75rem;
}
.method.get { background: #dcfce7; color: #16a34a; }
.method.post { background: #dbeafe; color: #1d4ed8; }
.method.put { background: #fef3c7; color: #d97706; }
.method.delete { background: #fee2e2; color: #dc2626; }

.response-panel {
  min-height: 6rem;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 0.75rem;
  background: #f8fafc;
}

.response-body {
  margin: 0;
  white-space: pre-wrap;
  font-size: 0.8rem;
}

.status-badge.ok { color: #16a34a; }
.status-badge.error { color: #dc2626; }

.response-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}
</style>
```
