# One-Pager Formats Reference

Two formats for single-document presentations: Executive Summary PDF and Single-Slide Overview.

## Table of Contents

1. [Choosing the Right Format](#choosing-the-right-format)
2. [Executive Summary PDF](#executive-summary-pdf)
3. [Single-Slide Overview](#single-slide-overview)
4. [Slidev Export Configuration](#slidev-export-configuration)

---

## Choosing the Right Format

| Situation | Format |
|-----------|--------|
| Audience reads before the meeting | Executive Summary PDF |
| No live presenter — document sent via email | Executive Summary PDF |
| Deck will be dropped in a chat or Slack | Single-Slide Overview |
| Slide will be shown on screen during a meeting | Single-Slide Overview |
| Audience needs to reference it after the meeting | Executive Summary PDF |
| Needs to work when printed | Executive Summary PDF |
| Will be shared alongside a larger deck | Single-Slide Overview |

---

## Executive Summary PDF

A multi-section single-page document structured for reading without a presenter. Follows the Pyramid Principle: recommendation first, then supporting structure.

### Section Structure

```
┌─────────────────────────────────────────────────────┐
│  [HEADLINE — the governing thought / recommendation] │
│  1-2 sentences, assertion style                      │
├──────────────────┬──────────────────────────────────┤
│  PROBLEM /       │  PROPOSED SOLUTION                │
│  OPPORTUNITY     │                                   │
│                  │  3-4 bullets of what changes      │
│  Why action is   │  No technical implementation      │
│  needed now      │  detail at this level             │
├──────────────────┼──────────────────────────────────┤
│  IMPLEMENTATION  │  VISUAL SUPPORT                   │
│  PLAN            │                                   │
│                  │  Chart, diagram, or key metric    │
│  3-phase max     │  that proves the recommendation   │
│  Key milestones  │                                   │
├──────────────────┴──────────────────────────────────┤
│  CALL TO ACTION                                      │
│  Single clear ask with decision deadline             │
│  Contact: [name, email]                             │
└─────────────────────────────────────────────────────┘
```

### Section Guidelines

**Headline**
- Declarative sentence stating the recommendation and its primary business outcome
- 15-20 words maximum
- Example: "Migrating to AWS reduces infrastructure cost by $400K/year and eliminates the hardware refresh cycle"

**Problem / Opportunity**
- 3-4 sentences describing the current state and why it creates urgency
- Business framing: cost, risk, customer impact, competitive pressure
- One specific metric to anchor the problem (e.g., "$640K current annual cost", "2.3s average load time")

**Proposed Solution**
- 3-4 bullet points describing what changes
- Outcome-oriented language: what the audience gains, not what the team does
- No acronyms or technical jargon without inline definition

**Implementation Plan**
- 3 phases maximum with a name and milestone for each
- Timeline in natural language: "Q2 2026", "6 months after approval"
- Call out what the stakeholder must do or approve to unblock each phase

**Visual Support**
- Single visual that proves the recommendation (ROI chart, risk matrix, before/after comparison)
- Self-explanatory without captions — labels and legend must be on the visual itself
- High contrast, readable when printed in black and white

**Call to Action**
- Single sentence stating what the audience must do
- Include a deadline if one exists
- Include contact name and email for follow-up

### Design Principles for PDF Export

- Headlines guide reading — font size hierarchy: headline 24pt, section headers 14pt, body 10pt minimum
- Brand-consistent imagery and color palette — use the organization's primary and secondary colors
- Bullets for scannability — no paragraphs longer than 3 sentences
- Whitespace between sections — dense layout reduces reading speed and comprehension
- Print-safe design: avoid gradients or colors that will not distinguish in grayscale

### Slidev Implementation

Use the `executive-summary` template in `templates/executive-summary.md`. Configure for single-slide export:

```yaml
---
theme: default
layout: full
exportFilename: executive-summary
export:
  format: pdf
  timeout: 30000
  dark: false
---
```

Use CSS Grid to create the multi-section layout within a single slide:

```html
<div class="grid grid-cols-2 grid-rows-3 gap-4 h-full text-sm">
  <div class="col-span-2 bg-blue-50 p-4 rounded">
    <!-- Headline -->
  </div>
  <div class="bg-gray-50 p-4 rounded">
    <!-- Problem -->
  </div>
  <div class="bg-gray-50 p-4 rounded">
    <!-- Solution -->
  </div>
  <div class="bg-gray-50 p-4 rounded">
    <!-- Plan -->
  </div>
  <div class="bg-gray-50 p-4 rounded">
    <!-- Visual -->
  </div>
  <div class="col-span-2 bg-blue-100 p-4 rounded">
    <!-- Call to Action -->
  </div>
</div>
```

---

## Single-Slide Overview

A dense single slide designed for sharing or screen display. Applies Assertion-Evidence methodology strictly: declarative assertion at top, visual evidence in body.

### Structure

```
┌─────────────────────────────────────────────────────┐
│  ASSERTION (2 lines max, ~10-15 words)               │
├─────────────┬──────────────┬────────────────────────┤
│  KEY        │  KEY         │  KEY                   │
│  METRIC 1   │  METRIC 2    │  METRIC 3              │
│             │              │                        │
│  [number]   │  [number]    │  [number]              │
│  [label]    │  [label]     │  [label]               │
├─────────────┴──────────────┴────────────────────────┤
│  VISUAL EVIDENCE                                     │
│  (chart, diagram, or timeline)                       │
│                                                      │
│  [self-annotated with labels]                        │
└─────────────────────────────────────────────────────┘
```

### Design Rules

- **Assertion**: Top section, 2 lines maximum, declarative sentence with a verb
- **Key metrics**: 3 callouts maximum — large number, small label — placed between assertion and visual
- **Visual evidence**: Occupies the majority of slide area (60-70% of height)
- **Total word count**: ≤20 words (assertion + metric labels + any visual labels)
- **Font**: Assertion at 28-32pt, metrics at 36-48pt (numbers), 14pt (labels), visual labels at 12pt minimum

### Metric Callout Pattern

```html
<div class="grid grid-cols-3 gap-8 my-4 text-center">
  <div>
    <div class="text-5xl font-bold text-blue-600">$400K</div>
    <div class="text-sm text-gray-600">Annual savings</div>
  </div>
  <div>
    <div class="text-5xl font-bold text-blue-600">8mo</div>
    <div class="text-sm text-gray-600">Migration timeline</div>
  </div>
  <div>
    <div class="text-5xl font-bold text-blue-600">99.9%</div>
    <div class="text-sm text-gray-600">Uptime maintained</div>
  </div>
</div>
```

### Visual Evidence Selection

- **Trend or comparison over time**: Line chart or grouped bar chart
- **Part-to-whole**: Donut chart (not pie — donut is more readable at small sizes)
- **System architecture**: Mermaid flowchart at C4 Level 1 (context only)
- **Process flow**: Horizontal swimlane with 3-5 steps
- **Before/after**: Side-by-side comparison with arrow indicating direction of change

All visuals must be self-annotating — labels embedded in the chart or diagram, not in a separate legend box.

### When Not to Use Single-Slide Overview

- When the audience needs to act on detailed implementation steps — use Executive Summary PDF instead
- When the visual requires explanation beyond 20 words — add a second slide or use Executive Summary
- When the metric numbers require disclaimers or methodology notes — embed methodology in the callout label or use Executive Summary

---

## Slidev Export Configuration

### PDF Export for One-Pagers

```bash
# Export single slide as PDF
npx slidev export executive-summary.md --format pdf --output executive-summary.pdf

# With timeout for complex renders (mermaid diagrams)
npx slidev export executive-summary.md --format pdf --timeout 60000
```

### PNG Export for Single-Slide Sharing

```bash
# Export as high-resolution PNG for Slack/email sharing
npx slidev export single-slide-overview.md --format png --output overview.png
```

### Slide Dimension Considerations

- **Standard widescreen (16:9)**: Default Slidev output, good for screen sharing
- **Letter/A4 (4:3 or close)**: Better for PDF printing — configure via `aspectRatio` in headmatter

```yaml
---
aspectRatio: '4/3'
canvasWidth: 1024
---
```

For printable executive summaries, use letter proportions with `canvasWidth: 816` (816px = 8.5 inches at 96dpi).
