# Animation and Interaction Patterns for Slidev

Patterns for CSS transitions, Vue animations, and click-triggered state changes in interactive slide demos.

## Table of Contents

1. [CSS Transitions for State Changes](#css-transitions-for-state-changes)
2. [Vue Transition and TransitionGroup](#vue-transition-and-transitiongroup)
3. [Click-Triggered State Machines](#click-triggered-state-machines)
4. [Keyframe Animations](#keyframe-animations)
5. [Slidev-Specific: v-click and $clicks](#slidev-specific-v-click-and-clicks)
6. [Sequenced Animations](#sequenced-animations)
7. [Common Animation Patterns](#common-animation-patterns)
8. [Performance in Export Mode](#performance-in-export-mode)
9. [Accessibility: Reduced Motion](#accessibility-reduced-motion)

---

## CSS Transitions for State Changes

Apply transitions to interactive element states using CSS classes:

```vue
<script setup>
import { ref } from 'vue'
const active = ref(false)
</script>

<template>
  <button
    @click="active = !active"
    class="state-button"
    :class="{ active }"
    :aria-pressed="active"
  >
    {{ active ? 'Active' : 'Inactive' }}
  </button>
</template>

<style scoped>
.state-button {
  padding: 0.5rem 1.5rem;
  border-radius: 6px;
  background: #e2e8f0;
  border: 2px solid transparent;
  cursor: pointer;
  font-weight: 600;
  color: #475569;
}

@media (prefers-reduced-motion: no-preference) {
  .state-button {
    transition: background 0.25s ease, color 0.25s ease, border-color 0.25s ease;
  }
}

.state-button.active {
  background: #4f46e5;
  color: white;
  border-color: #3730a3;
}

.state-button:focus-visible {
  outline: 2px solid #4f46e5;
  outline-offset: 3px;
}

/* Hover states for users who can hover */
@media (hover: hover) {
  .state-button:hover:not(.active) { background: #cbd5e1; }
}
</style>
```

### Hover, Active, and Focus States

Define all three interaction states for interactive controls:

```css
.interactive {
  background: #f1f5f9;
  cursor: pointer;
}

@media (prefers-reduced-motion: no-preference) {
  .interactive { transition: background 0.15s, transform 0.1s; }
  .interactive:active { transform: scale(0.97); }
}

@media (hover: hover) {
  .interactive:hover { background: #e2e8f0; }
}

.interactive:focus-visible {
  outline: 2px solid #4f46e5;
  outline-offset: 2px;
}
```

---

## Vue Transition and TransitionGroup

### Enter/Leave for Single Elements

```vue
<template>
  <Transition name="fade">
    <div v-if="show" class="notification" role="status">
      Changes saved
    </div>
  </Transition>
</template>

<style scoped>
/* Default classes: v-enter-from, v-enter-active, v-enter-to, v-leave-from, v-leave-active, v-leave-to */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

/* Apply transitions only when motion is allowed */
@media (prefers-reduced-motion: reduce) {
  .fade-enter-active,
  .fade-leave-active {
    transition: none;
  }
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
```

### Slide-in Transition

```css
.slide-enter-active { transition: transform 0.3s ease, opacity 0.3s ease; }
.slide-leave-active { transition: transform 0.2s ease, opacity 0.2s ease; }

@media (prefers-reduced-motion: reduce) {
  .slide-enter-active, .slide-leave-active { transition: none; }
}

.slide-enter-from { transform: translateY(12px); opacity: 0; }
.slide-leave-to   { transform: translateY(-8px);  opacity: 0; }
```

### TransitionGroup for Lists

```vue
<script setup>
import { ref } from 'vue'
const items = ref([
  { id: 1, label: 'First item' },
  { id: 2, label: 'Second item' },
])

function addItem() {
  const id = Date.now()
  items.value.push({ id, label: `Item ${items.value.length + 1}` })
}

function removeItem(id) {
  items.value = items.value.filter(i => i.id !== id)
}
</script>

<template>
  <div>
    <button @click="addItem">Add</button>
    <TransitionGroup name="list" tag="ul" aria-label="Dynamic list">
      <li v-for="item in items" :key="item.id">
        {{ item.label }}
        <button @click="removeItem(item.id)" :aria-label="`Remove ${item.label}`">×</button>
      </li>
    </TransitionGroup>
  </div>
</template>

<style scoped>
@media (prefers-reduced-motion: no-preference) {
  .list-enter-active { transition: all 0.3s ease; }
  .list-leave-active { transition: all 0.2s ease; position: absolute; }
  .list-move         { transition: transform 0.3s ease; }
}
.list-enter-from, .list-leave-to { opacity: 0; transform: translateX(20px); }
</style>
```

---

## Click-Triggered State Machines

Model interactive workflows as explicit state objects:

```vue
<script setup>
import { ref, computed } from 'vue'

const STATE = {
  IDLE: 'idle',
  LOADING: 'loading',
  SUCCESS: 'success',
  ERROR: 'error',
}

const current = ref(STATE.IDLE)

const transitions = {
  [STATE.IDLE]: { send: STATE.LOADING },
  [STATE.LOADING]: { resolve: STATE.SUCCESS, reject: STATE.ERROR },
  [STATE.SUCCESS]: { reset: STATE.IDLE },
  [STATE.ERROR]: { retry: STATE.LOADING, reset: STATE.IDLE },
}

function send(action) {
  const next = transitions[current.value]?.[action]
  if (next) current.value = next
}

const label = computed(() => ({
  [STATE.IDLE]: 'Send Request',
  [STATE.LOADING]: 'Sending…',
  [STATE.SUCCESS]: 'Reset',
  [STATE.ERROR]: 'Retry',
}[current.value]))

const primaryAction = computed(() => ({
  [STATE.IDLE]: () => simulateSend(),
  [STATE.SUCCESS]: () => send('reset'),
  [STATE.ERROR]: () => simulateSend(),
}[current.value] ?? (() => {})))

async function simulateSend() {
  send('send')
  await new Promise(r => setTimeout(r, 1200))
  Math.random() > 0.3 ? send('resolve') : send('reject')
}
</script>

<template>
  <div class="state-machine" role="region" aria-label="Request state machine">
    <p>State: <strong>{{ current }}</strong></p>
    <div class="status-indicator" :class="current" aria-live="polite" aria-atomic="true">
      <span v-if="current === STATE.IDLE">Ready to send</span>
      <span v-else-if="current === STATE.LOADING">Processing request…</span>
      <span v-else-if="current === STATE.SUCCESS" role="status">Request succeeded</span>
      <span v-else-if="current === STATE.ERROR" role="alert">Request failed</span>
    </div>
    <div class="actions">
      <button @click="primaryAction" :disabled="current === STATE.LOADING"
              :aria-busy="current === STATE.LOADING">
        {{ label }}
      </button>
      <button v-if="current === STATE.ERROR" @click="send('reset')">
        Cancel
      </button>
    </div>
  </div>
</template>
```

---

## Keyframe Animations

### Attention Pulse

Draw focus to an element without relying on color alone:

```css
@keyframes attention-pulse {
  0%, 100% { box-shadow: 0 0 0 0 rgba(79, 70, 229, 0.4); }
  50%       { box-shadow: 0 0 0 8px rgba(79, 70, 229, 0); }
}

@media (prefers-reduced-motion: no-preference) {
  .highlight {
    animation: attention-pulse 2s ease-in-out 3;
  }
}

/* Reduced motion: static highlight instead */
@media (prefers-reduced-motion: reduce) {
  .highlight {
    outline: 3px solid #4f46e5;
    outline-offset: 2px;
  }
}
```

### Skeleton Loading

```css
@keyframes shimmer {
  0%   { background-position: -200% 0; }
  100% { background-position:  200% 0; }
}

.skeleton {
  background: linear-gradient(90deg, #e2e8f0 25%, #f1f5f9 50%, #e2e8f0 75%);
  background-size: 200% 100%;
  border-radius: 4px;
}

@media (prefers-reduced-motion: no-preference) {
  .skeleton { animation: shimmer 1.5s infinite; }
}

@media (prefers-reduced-motion: reduce) {
  .skeleton { background: #e2e8f0; } /* Static placeholder */
}
```

---

## Slidev-Specific: v-click and $clicks

### Animating with $clicks in Components

```vue
<script setup>
import { useSlideContext } from '@slidev/client'
import { computed } from 'vue'

const { $slidev } = useSlideContext()
const clicks = computed(() => $slidev.nav.clicks)

const steps = ['Define', 'Build', 'Test', 'Deploy']
const activeStep = computed(() => Math.min(clicks.value, steps.length - 1))
</script>

<template>
  <div class="workflow" role="list" aria-label="Deployment workflow">
    <div
      v-for="(step, i) in steps"
      :key="step"
      class="workflow-step"
      :class="{
        active: i === activeStep,
        done: i < activeStep,
        upcoming: i > activeStep,
      }"
      role="listitem"
      :aria-current="i === activeStep ? 'step' : undefined"
    >
      <span class="step-number" aria-hidden="true">{{ i + 1 }}</span>
      <span class="step-label">{{ step }}</span>
    </div>
  </div>
</template>

<style scoped>
.workflow { display: flex; gap: 0; }

.workflow-step {
  flex: 1;
  padding: 0.75rem;
  text-align: center;
  border-bottom: 3px solid #e2e8f0;
  color: #94a3b8;
}

@media (prefers-reduced-motion: no-preference) {
  .workflow-step { transition: all 0.3s ease; }
}

.workflow-step.active {
  border-bottom-color: #4f46e5;
  color: #4f46e5;
  font-weight: 700;
}

.workflow-step.done {
  border-bottom-color: #16a34a;
  color: #16a34a;
}
</style>
```

### Slide Markup

```markdown
---
layout: default
---

# Deployment Pipeline

<WorkflowStepper />

<!-- 4 clicks advance through the 4 steps -->
<v-click v-for="_ in 4" />
```

---

## Sequenced Animations

### Step-by-Step with CSS Delays

```vue
<script setup>
import { ref } from 'vue'
const reveal = ref(false)
</script>

<template>
  <button @click="reveal = !reveal">
    {{ reveal ? 'Hide' : 'Show sequence' }}
  </button>
  <div class="sequence" :class="{ active: reveal }">
    <div class="seq-item step-1">Step 1: Receive request</div>
    <div class="seq-item step-2">Step 2: Validate payload</div>
    <div class="seq-item step-3">Step 3: Persist to database</div>
    <div class="seq-item step-4">Step 4: Emit event</div>
  </div>
</template>

<style scoped>
.seq-item {
  opacity: 0;
  transform: translateX(-16px);
  padding: 0.5rem 1rem;
  margin: 0.25rem 0;
  background: #f1f5f9;
  border-radius: 6px;
}

@media (prefers-reduced-motion: no-preference) {
  .seq-item { transition: opacity 0.3s ease, transform 0.3s ease; }
  .sequence.active .step-1 { opacity: 1; transform: none; transition-delay: 0ms; }
  .sequence.active .step-2 { opacity: 1; transform: none; transition-delay: 150ms; }
  .sequence.active .step-3 { opacity: 1; transform: none; transition-delay: 300ms; }
  .sequence.active .step-4 { opacity: 1; transform: none; transition-delay: 450ms; }
}

@media (prefers-reduced-motion: reduce) {
  .seq-item { opacity: 0; transform: none; transition: opacity 0.1s; }
  .sequence.active .seq-item { opacity: 1; }
}
</style>
```

---

## Common Animation Patterns

### Workflow Walkthrough

Highlight the current step, dim completed and upcoming steps:

```css
.step { opacity: 0.4; filter: grayscale(1); }

@media (prefers-reduced-motion: no-preference) {
  .step { transition: opacity 0.3s, filter 0.3s; }
}

.step.active  { opacity: 1; filter: none; }
.step.done    { opacity: 0.7; filter: grayscale(0.3); }
```

### Data Loading Simulation

Skeleton → loaded state transition:

```vue
<script setup>
import { ref, onMounted } from 'vue'
const loaded = ref(false)

onMounted(async () => {
  await new Promise(r => setTimeout(r, 1500))
  loaded.value = true
})
</script>

<template>
  <Transition name="fade" mode="out-in">
    <div v-if="!loaded" key="skeleton" class="skeleton" style="height:80px" aria-label="Loading content" />
    <div v-else key="content" class="content" role="region">
      Loaded content here
    </div>
  </Transition>
</template>
```

### Form Submission Flow

Input → Validate → Submit → Success:

```vue
<script setup>
import { ref } from 'vue'
const phase = ref('input')  // input | validating | submitting | success

async function submit() {
  phase.value = 'validating'
  await new Promise(r => setTimeout(r, 600))
  phase.value = 'submitting'
  await new Promise(r => setTimeout(r, 1000))
  phase.value = 'success'
}
</script>

<template>
  <div class="form-flow" role="region" aria-label="Form submission flow">
    <Transition name="fade" mode="out-in">
      <form v-if="phase === 'input'" key="form" @submit.prevent="submit">
        <input type="text" aria-label="Name" required />
        <button type="submit">Submit</button>
      </form>
      <div v-else-if="phase === 'validating'" key="validating" role="status">
        Validating…
      </div>
      <div v-else-if="phase === 'submitting'" key="submitting" role="status" aria-busy="true">
        Submitting…
      </div>
      <div v-else key="success" role="status" class="success">
        Submitted successfully
      </div>
    </Transition>
  </div>
</template>
```

### Navigation Demo

Sidebar click → content change:

```vue
<script setup>
import { ref } from 'vue'
const sections = ['Overview', 'Settings', 'Billing', 'Team']
const active = ref('Overview')
</script>

<template>
  <div class="nav-demo">
    <nav aria-label="Section navigation">
      <button
        v-for="section in sections"
        :key="section"
        @click="active = section"
        :aria-current="active === section ? 'page' : undefined"
        :class="{ active: active === section }"
      >
        {{ section }}
      </button>
    </nav>
    <Transition name="fade" mode="out-in">
      <div :key="active" class="section-content" role="region" :aria-label="active + ' section'">
        <h3>{{ active }}</h3>
        <p>Content for the {{ active }} section.</p>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
nav { display: flex; flex-direction: column; gap: 0.25rem; }
nav button { text-align: left; padding: 0.4rem 0.75rem; border-radius: 4px; cursor: pointer; border: none; background: none; }
nav button.active { background: #ede9fe; color: #4f46e5; font-weight: 600; }
nav button:focus-visible { outline: 2px solid #4f46e5; outline-offset: 2px; }
.nav-demo { display: grid; grid-template-columns: 140px 1fr; gap: 1rem; }
</style>
```

---

## Performance in Export Mode

Detect Slidev's export rendering and disable resource-intensive animations:

```vue
<script setup>
import { useSlideContext } from '@slidev/client'
import { computed, onMounted, onUnmounted } from 'vue'

const { $slidev } = useSlideContext()
const isExporting = computed(() => $slidev.nav.isExporting)

let interval = null

onMounted(() => {
  if (!isExporting.value) {
    interval = setInterval(tick, 1000)
  }
})

onUnmounted(() => {
  if (interval) clearInterval(interval)
})
</script>

<template>
  <div>
    <!-- Live chart visible only during presentation -->
    <AnimatedChart v-if="!isExporting" />
    <!-- Static fallback for PDF/PPTX export -->
    <img v-else src="/chart-snapshot.png" alt="Chart showing Q4 growth trend" />
  </div>
</template>
```

Avoid CSS `animation` on elements that appear in exported slides — they render at frame 0 of the animation cycle.

---

## Accessibility: Reduced Motion

### The CSS Media Query

Always gate animations behind this media query:

```css
/* Default: no animation for safety */
.animated-element {
  opacity: 1;
  transform: none;
}

/* Animation only when user has not requested reduced motion */
@media (prefers-reduced-motion: no-preference) {
  .animated-element {
    transition: opacity 0.3s ease, transform 0.3s ease;
  }
  .animated-element.hidden {
    opacity: 0;
    transform: translateY(8px);
  }
}

/* Explicit reduced-motion alternative */
@media (prefers-reduced-motion: reduce) {
  .animated-element.hidden {
    opacity: 0; /* Keep functional visibility change, remove motion */
  }
}
```

### JavaScript Check

```javascript
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches

function animateIn(el) {
  if (prefersReducedMotion) {
    el.style.opacity = '1'  // Instant show, no motion
    return
  }
  el.animate([
    { opacity: 0, transform: 'translateY(8px)' },
    { opacity: 1, transform: 'translateY(0)' },
  ], { duration: 300, easing: 'ease', fill: 'forwards' })
}
```

### Vue Reduced Motion Composable

```vue
<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

// Reactive reduced motion preference
const prefersReducedMotion = ref(false)
let mq

onMounted(() => {
  mq = window.matchMedia('(prefers-reduced-motion: reduce)')
  prefersReducedMotion.value = mq.matches
  mq.addEventListener('change', e => { prefersReducedMotion.value = e.matches })
})

onUnmounted(() => {
  mq?.removeEventListener('change', () => {})
})
</script>

<template>
  <!-- Bind transition duration to 0 when reduced motion is preferred -->
  <Transition :duration="prefersReducedMotion ? 0 : 300" name="slide">
    <slot />
  </Transition>
</template>
```

### Non-Animated Fallbacks

Every animated pattern must have a functional fallback:
- Fade transitions: element remains visible, just no fade effect
- Slide-in sequences: all items visible simultaneously
- Progress animations: show final state immediately
- Skeleton loaders: static placeholder color, no shimmer
- Pulsing indicators: static border or underline instead
