---
theme: default
title: "[Replace: Initiative Name] — Overview"
author: "[Replace: Author Name]"
exportFilename: single-slide-overview
export:
  format: png
  timeout: 30000
  dark: false
---

<!-- ASSERTION: 2 lines max, ~10-15 words, declarative sentence with a verb -->
<div class="text-2xl font-bold text-gray-900 mb-4 leading-tight">
  [Replace: Declarative assertion — e.g., "Migrating to AWS reduces annual cost by $400K and eliminates the 2027 hardware refresh"]
</div>

<!-- KEY METRICS: 3 callouts maximum -->
<div class="grid grid-cols-3 gap-6 mb-6 text-center">
  <div class="bg-blue-50 rounded-lg p-4">
    <div class="text-5xl font-bold text-blue-700">[Replace: e.g., $400K]</div>
    <div class="text-sm text-gray-600 mt-1">[Replace: e.g., Annual savings]</div>
  </div>
  <div class="bg-blue-50 rounded-lg p-4">
    <div class="text-5xl font-bold text-blue-700">[Replace: e.g., 8mo]</div>
    <div class="text-sm text-gray-600 mt-1">[Replace: e.g., Migration timeline]</div>
  </div>
  <div class="bg-blue-50 rounded-lg p-4">
    <div class="text-5xl font-bold text-blue-700">[Replace: e.g., 99.9%]</div>
    <div class="text-sm text-gray-600 mt-1">[Replace: e.g., Uptime maintained]</div>
  </div>
</div>

<!-- VISUAL EVIDENCE: occupies 60-70% of slide body -->
<!-- Replace the placeholder below with a mermaid diagram, chart, or table -->
<!-- Every diagram element MUST be labeled inline — no separate legend -->

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#dbeafe', 'primaryTextColor': '#1e3a5f', 'lineColor': '#3b82f6'}}}%%
flowchart LR
    %% [Replace: describe left element — e.g., "Current infrastructure"]
    A["[Replace: e.g., On-Prem]\n$640K/yr"] -->|"[Replace: e.g., Migration]"| B["[Replace: e.g., AWS]\n$240K/yr"]
    %% [Replace: describe outcome element]
    B --> C["[Replace: e.g., $400K saved]\nper year"]
```

<!-- DIAGRAM ANNOTATION: required for every diagram -->
- **[Replace: Left element]**: [Replace: what it represents — e.g., "Current on-premises infrastructure, $640K/year, approaching end-of-life"]
- **[Replace: Middle/transition]**: [Replace: what the arrow/process represents — e.g., "8-month phased migration, zero downtime"]
- **[Replace: Right element]**: [Replace: outcome — e.g., "AWS cloud infrastructure at $240K/year, scales to 4x current traffic"]

<!-- FOOTER: source and contact — kept to ≤5 words per field -->
<div class="flex justify-between text-xs text-gray-400 mt-3">
  <div>Source: [Replace: e.g., "AWS TCO calculator, Mar 2026"]</div>
  <div>[Replace: Owner name] · [Replace: email]</div>
</div>

<!--
Word count target: ≤20 words total (assertion + metric labels + diagram labels)
Count: Replace all [Replace:] tokens and recount before sharing.

Export command:
  npx slidev export single-slide-overview.md --format png --output overview.png

For Slack/email: PNG is preferred (renders inline)
For presentation reference slide: include as last slide of a deck
-->
