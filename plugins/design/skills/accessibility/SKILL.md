---
name: accessibility
description: Guide for implementing web accessibility (WCAG). Use when designing UI components, reviewing interfaces for accessibility, or ensuring compliance with W3C WAI standards.
---

# Web Accessibility

Apply W3C Web Accessibility Initiative (WAI) principles when working on web interfaces to ensure usability for people with disabilities.

## Anti-fabrication

This skill follows `core:anti-fabrication`. The claim area is the WCAG version cited and
the ARIA Authoring Practices Guide (APG) pattern attributions. Verified against W3C's
live WCAG22 quickref and the APG patterns index (claude-skills-223): the WCAG citation
was bumped from 2.1 to 2.2 (2.2 became a Recommendation 2023-10-05, and per its own text
"content that conforms to WCAG 2.2 also conforms to WCAG 2.0 and WCAG 2.1" — compatibility
runs 2.2-to-2.1, not the reverse this skill previously implied); and "skip links" was
corrected from an APG pattern to what it actually is, a WCAG bypass-blocks technique — the
APG index lists 30 named patterns and skip links is not one of them. Re-verify against
`w3.org/TR/WCAG22/` before citing a WCAG version or success-criterion number this skill
doesn't cover.

## Core Principles (POUR)

Web accessibility is organized around four foundational principles:

### 1. Perceivable

Information must be presentable to users in ways they can perceive.

**Key requirements:**
- Provide text alternatives for non-text content (images, icons, charts)
- Provide captions and transcripts for multimedia
- Create content that can be presented in different ways (responsive, reflow)
- Make content distinguishable (color contrast, text sizing, audio control)

**Quick example:**
```html
<img src="chart.png" alt="Sales increased 40% in Q4 2024">
<button aria-label="Close dialog">
  <span class="icon-close" aria-hidden="true"></span>
</button>
```

### 2. Operable

User interface components must be operable by all users.

**Key requirements:**
- Make all functionality keyboard accessible
- Provide sufficient time for users to complete tasks
- Avoid content that causes seizures (no rapid flashing)
- Help users navigate and find content
- Support various input modalities (touch, voice, keyboard)

**Quick example:**
```html
<button>Click me</button>  <!-- Already keyboard accessible -->

<!-- Custom interactive element needs keyboard support -->
<div role="button" tabindex="0"
     onclick="handleClick()"
     onkeydown="handleKeyDown(event)">
  Custom Button
</div>
```

### 3. Understandable

Information and UI operation must be understandable.

**Key requirements:**
- Make text readable and understandable
- Make web pages appear and operate predictably
- Help users avoid and correct mistakes
- Provide clear labels and instructions

**Quick example:**
```html
<html lang="en">
<label for="email">Email address</label>
<input type="email" id="email"
       aria-describedby="email-help"
       required>
<div id="email-help">We'll never share your email</div>
```

### 4. Robust

Content must work reliably across user agents and assistive technologies.

**Key requirements:**
- Use valid, well-formed markup
- Ensure compatibility with assistive technologies
- Use ARIA correctly for custom components
- Follow semantic HTML practices

**Quick example:**
```html
<!-- Use semantic HTML first -->
<nav aria-label="Main navigation">
  <ul>
    <li><a href="/">Home</a></li>
  </ul>
</nav>

<!-- ARIA for custom components when needed -->
<div role="dialog" aria-labelledby="title" aria-modal="true">
  <h2 id="title">Dialog Title</h2>
</div>
```

## Common Tasks

### Making Forms Accessible

- Associate every label with its input (`for`/`id` or wrapping `<label>`)
- Identify errors in text and link the message to the failing control
- Indicate required fields in the label, not by color alone
- Pair validation with specific correction guidance

### Implementing ARIA

- Use semantic HTML first; add ARIA only when no native element fits
- Keep ARIA states (`aria-expanded`, `aria-selected`) in sync with component state
- Announce dynamic content with live regions (`aria-live`, `role="status"`)
- Follow the ARIA Authoring Practices patterns (linked under Resources) for tabs, accordions, modals, and dropdown menus. Skip links are a WCAG technique (a "skip to main content" link as the first focusable element), not an ARIA APG design pattern — the APG's pattern index has no skip-link entry

### Testing for Accessibility

- Navigate the full interface with keyboard only (Tab, Shift+Tab, Enter, Space, arrows)
- Test with a screen reader (VoiceOver, NVDA, or JAWS)
- Run automated checkers (axe, Lighthouse, WAVE) as a first pass, not a substitute for manual testing
- Check color contrast against the 4.5:1 text and 3:1 UI-component minimums

## Quick Reference Checklist

**Every page should have:**
- [ ] Valid HTML structure
- [ ] Unique, descriptive page title
- [ ] Proper heading hierarchy (h1, h2, h3...)
- [ ] Language attribute on `<html>`
- [ ] Sufficient color contrast (4.5:1 minimum)
- [ ] Keyboard accessibility for all interactive elements
- [ ] Visible focus indicators
- [ ] Text alternatives for images
- [ ] Form labels associated with inputs
- [ ] Semantic landmark regions

**For interactive components:**
- [ ] Keyboard accessible (Tab, Enter, Space, Arrow keys)
- [ ] Proper ARIA roles, states, and properties
- [ ] Focus management (modals, dynamic content)
- [ ] Descriptive labels and instructions
- [ ] Error messages linked to form controls

## Key Principles

- **Semantic HTML first**: Use native HTML elements before adding ARIA
- **Keyboard accessibility is fundamental**: If it works with mouse, it must work with keyboard
- **Test with actual users**: Include people with disabilities in testing
- **Color is not enough**: Never use color alone to convey information
- **Provide alternatives**: Text for images, captions for video, transcripts for audio
- **Make it predictable**: Consistent navigation and behavior across pages
- **Help users recover**: Clear error messages with suggestions for correction

## Resources

- **WCAG 2.2 Guidelines**: https://www.w3.org/WAI/WCAG22/quickref/ (current W3C Recommendation since 2023-10-05; backward-compatible — content conforming to 2.2 also conforms to 2.1 and 2.0)
- **ARIA Authoring Practices**: https://www.w3.org/WAI/ARIA/apg/
- **WebAIM**: https://webaim.org/
- **MDN Accessibility**: https://developer.mozilla.org/en-US/docs/Web/Accessibility
