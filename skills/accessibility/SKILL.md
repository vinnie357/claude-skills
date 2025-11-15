---
name: accessibility
description: Guide for implementing web accessibility following W3C WAI principles (WCAG) when designing, developing, or reviewing web interfaces
---

# Web Accessibility

Apply W3C Web Accessibility Initiative (WAI) principles when working on web interfaces to ensure usability for people with disabilities.

## When to Activate

Use this skill when:
- Designing or implementing user interfaces
- Reviewing code for accessibility compliance
- Creating or editing web content (HTML, CSS, JavaScript)
- Working with forms, navigation, multimedia, or interactive components
- Conducting code reviews with accessibility considerations
- Refactoring existing interfaces for better accessibility

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

For detailed guidance on text alternatives, multimedia, and color contrast, see `references/perceivable.md`.

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

For keyboard patterns, focus management, and navigation, see `references/operable.md`.

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

For form patterns, error handling, and content clarity, see `references/understandable.md`.

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

For ARIA patterns and custom components, see `references/robust.md`.

## Common Tasks

### Making Forms Accessible

Consult `references/forms.md` for comprehensive form accessibility including:
- Label association
- Error identification and suggestions
- Required field indication
- Input validation patterns

### Implementing ARIA

See `references/aria.md` for:
- When to use ARIA vs semantic HTML
- Common ARIA patterns (tabs, accordions, modals)
- ARIA states and properties
- Live regions for dynamic content

### Testing for Accessibility

Consult `references/testing.md` for:
- Keyboard navigation testing
- Screen reader testing procedures
- Automated testing tools
- Color contrast checking

### Common Patterns

See `references/patterns.md` for accessible implementations of:
- Modal dialogs
- Dropdown menus
- Tabs and accordions
- Loading states and notifications
- Skip links and landmarks

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

- **WCAG 2.1 Guidelines**: https://www.w3.org/WAI/WCAG21/quickref/
- **ARIA Authoring Practices**: https://www.w3.org/WAI/ARIA/apg/
- **WebAIM**: https://webaim.org/
- **MDN Accessibility**: https://developer.mozilla.org/en-US/docs/Web/Accessibility
