# Product Requirements Document (PRD)

## Overview

**Product Name:** Agent Skills for Claude
**Author:** Michael Dimmitt
**Date:** 2026-05-28
**Version:** 1.0
**Status:** Draft

---

## Background

### Problem Summary
Claude is a general-purpose assistant, but many users have specialized, repeatable workflows — document creation, code generation with specific patterns, brand-consistent design — that benefit from persistent, domain-specific instructions and bundled resources. Without a structured extension mechanism, users must re-explain context on every conversation, and Claude reinvents the wheel on every invocation.

### Link to Project Brief
[agentskills.io/specification](https://agentskills.io/specification)

---

## Objectives

### Goals
- Provide a reference library of high-quality skills demonstrating what the Agent Skills system can do
- Enable developers and power users to create, test, and iterate on their own custom skills
- Support skills across Claude Code (CLI), Claude.ai, and the Claude API
- Make the skill authoring experience accessible to both non-technical users and engineers

### Non-Goals
- Not a plugin marketplace (skills are installed separately via `/plugin` commands or API)
- Not a general-purpose Claude configuration system — skills are task-scoped, not global behavior changes
- Not a runtime execution environment — skills provide instructions and resources; Claude executes

---

## User Stories

### Persona: Developer / AI Engineer

Builds AI-powered tools and custom Claude workflows. Wants to encode repeatable patterns once and measure whether skills actually improve output quality. Highest-value entry points from Anthropic's reference repo:

- **skill-creator** — the meta-skill for building, testing, and iterating on skills with an eval loop and benchmark viewer
- **claude-api** — opinionated guide for building apps with the Anthropic SDK (Python/TypeScript/Go/etc.), defaults to Opus 4.6 + adaptive thinking + streaming
- **mcp-builder** — guide for creating MCP servers that expose external APIs as Claude tools (FastMCP / TypeScript MCP SDK)
- **webapp-testing** — Playwright-based toolkit for testing local web apps, capturing screenshots, and debugging UI behavior

| ID | As a... | I want to... | So that... | Priority |
|----|---------|--------------|------------|----------|
| US-001 | developer | install a skill from the reference repo into my Claude Code project | Claude follows specialized workflows without me re-explaining them | Must Have |
| US-002 | developer | create a custom skill with a SKILL.md and bundled scripts | I can encode my team's repeatable workflows once and reuse them | Must Have |
| US-003 | developer | run evals comparing with-skill vs. without-skill outputs | I can measure whether my skill actually improves Claude's output | Must Have |
| US-004 | developer | optimize a skill's description field | Claude triggers the skill reliably when relevant | Should Have |
| US-005 | developer | package a skill into a `.skill` file | I can share or install it easily | Should Have |

### Persona: Power User / Non-Engineer

Knows what they want Claude to do but doesn't want to write code or YAML. Wants to install pre-built skills and describe new ones conversationally. Highest-value entry points:

- **skill-creator** — conversational skill builder; handles the SKILL.md authoring, test runs, and eval viewer so the user only needs to give feedback
- **document-skills plugin bundle** (`docx`, `pdf`, `pptx`, `xlsx`) — install once via `/plugin install document-skills@anthropic-agent-skills`, get document creation across all major formats
- **brand-guidelines** — applies Anthropic visual style to any artifact; good template for building a company-specific brand skill
- **internal-comms** — communication drafting skill; useful model for encoding writing style preferences

| ID | As a... | I want to... | So that... | Priority |
|----|---------|--------------|------------|----------|
| US-006 | power user | browse existing skills and install one via `/plugin` | I get specialized Claude behavior without writing code | Must Have |
| US-007 | power user | use the skill-creator skill to build a custom skill conversationally | I can encode my own workflow without knowing YAML or Markdown deeply | Should Have |
| US-008 | power user | review skill eval outputs in a browser viewer | I can give feedback and guide iterative improvement without reading JSON | Should Have |

### Persona: JavaScript Front-End Developer / Bash Scripter

This persona works primarily in Node.js/TypeScript frontends and automates tasks with shell scripts. They want Claude to enforce cloud-native patterns and project conventions without needing to re-explain them each session. Their highest-value entry points from community skill repos (e.g., [vinnie357/claude-skills](https://github.com/vinnie357/claude-skills)) are:

- **twelve-factor** — enforces 12-factor app methodology for cloud-native JS services (env vars, stateless processes, port binding, structured stdout logs)
- **twelve-factor / references/infrastructure-conventions.md** — extends twelve-factor with opinionated defaults: NGINX upstream ingress, Kustomize+Helm layout, 1Password as universal secret store, IaC-only deployments
- **security** — pre-commit hook via gitleaks that blocks commits containing secrets/API keys; auto-detects Docker/Colima/Apple Container runtime
- **git-operations** — conventional commits, branch management, conflict resolution
- **tdd** — test-first discipline, red-green-refactor, walking skeleton pattern
- **container** — Docker patterns for JS apps; natural companion to twelve-factor (multi-stage builds, non-root users, health checks)
- **accessibility** — WCAG/a11y guidance for frontend; catches common violations before they ship
- **code-review** — automated code review discipline and checklist conventions
- **mise** — version manager for Node/runtime toolchains; common in JS/bash workflows
- **webapp-testing** (Anthropic repo) — Playwright-based UI testing for the frontends being built
- **claude-code tools** (claude-hooks, claude-commands, claude-plugins, claude-statusline, claude-teams) — compose hooks + commands together to automate Claude Code configuration for the whole team

| ID | As a... | I want to... | So that... | Priority |
|----|---------|--------------|------------|----------|
| US-011 | JS/bash developer | load a twelve-factor skill | Claude enforces env-var config, stateless processes, and stdout logging in all my Node.js code without me repeating the rules | Must Have |
| US-012 | JS/bash developer | use the infrastructure-conventions reference | Claude knows to use nginx.org ingress (not community), Kustomize+Helm layout, and 1Password as the secret store for my k8s deploys | Must Have |
| US-013 | JS/bash developer | install the security skill with its pre-commit hook | Every `git commit` is automatically scanned for leaked API keys/secrets before they hit git history | Must Have |
| US-014 | JS/bash developer | use the container skill alongside twelve-factor | Claude generates correct multi-stage Dockerfiles with non-root users and health check endpoints without me specifying every detail | Must Have |
| US-015 | JS/bash developer | use the accessibility skill on frontend components | Claude flags WCAG violations inline instead of me running a separate audit tool after the fact | Should Have |
| US-016 | JS/bash developer | use webapp-testing (Playwright) for UI verification | I can ask Claude to run and screenshot the app to confirm frontend changes work before I push | Should Have |
| US-017 | JS/bash developer | browse Vinny's community skills repo for conventions (git, tdd, code-review, mise) | I can assemble a personal skill set from existing community work rather than writing conventions from scratch | Should Have |
| US-018 | JS/bash developer | compose skills from multiple repos (Anthropic reference + community) | My Claude Code setup reflects both standard Anthropic patterns and my team's specific conventions in one plugin install | Should Have |
| US-019 | JS/bash developer | wire up claude-hooks + claude-commands together as a team plugin | My whole team gets the same Claude Code behavior without each person configuring it manually | Nice to Have |

### Persona: Enterprise / Document Workflow User

Produces business documents at scale — reports, decks, spreadsheets — and needs consistent formatting and brand compliance without manual cleanup. Highest-value entry points from Anthropic's reference repo:

- **docx** — create and edit Word documents; source-available, production-grade (powers Claude.ai's document feature)
- **pdf** — PDF extraction and creation; same production-grade provenance as docx
- **pptx** — PowerPoint creation and editing with slide layout awareness
- **xlsx** — Excel creation with formula and data model support
- **brand-guidelines** — enforces Anthropic brand colors and typography; fork as a template for company-specific style rules
- **doc-coauthoring** — collaborative document editing patterns; useful for workflows where Claude drafts and humans revise

| ID | As a... | I want to... | So that... | Priority |
|----|---------|--------------|------------|----------|
| US-009 | enterprise user | use docx/pdf/pptx/xlsx skills to create and edit documents | Claude produces well-formatted files matching our templates | Must Have |
| US-010 | enterprise user | apply brand guidelines consistently across artifacts | All Claude-generated outputs match company visual standards | Should Have |
| US-017 | enterprise user | use doc-coauthoring skill for draft-and-revise workflows | Claude and I can iterate on a document without losing formatting or structure | Should Have |

---

## Functional Requirements

### Feature 1: Skill Structure and Loading

**Description:** Each skill is a self-contained folder with a `SKILL.md` file (YAML frontmatter + markdown instructions) and optional bundled resources (scripts, references, assets). Claude loads skills via a three-level progressive disclosure system.

**Acceptance Criteria:**
- [ ] Every skill has a `SKILL.md` with `name` and `description` frontmatter fields
- [ ] Metadata (name + description, ~100 words) is always in Claude's context when the skill is available
- [ ] SKILL.md body (target <500 lines) loads when the skill is triggered
- [ ] Bundled resources (scripts/, references/, assets/) load on demand or execute without loading
- [ ] Skills with >500-line SKILL.md provide internal table of contents and pointers to reference files

**Edge Cases:**
- Skill installed in read-only path — Claude must copy to writable location before editing
- Multiple skills with overlapping trigger descriptions — Claude must select the most specific match

### Feature 2: Skill Triggering

**Description:** Claude decides whether to consult a skill based on matching the user's query against the `description` field in SKILL.md frontmatter.

**Acceptance Criteria:**
- [ ] Description field encodes both what the skill does and when to use it
- [ ] Simple one-step queries do not trigger skills unnecessarily (Claude handles them directly)
- [ ] Complex, multi-step, or specialized queries reliably trigger matching skills
- [ ] Description optimization tooling (`run_loop.py`) measurably improves trigger accuracy

**Edge Cases:**
- User query that partially matches multiple skills — most specific description wins
- User query that names a file type but doesn't need specialized processing — should not trigger

### Feature 3: Skill Creator (Meta-Skill)

**Description:** A skill for creating, testing, benchmarking, and iteratively improving other skills. Guides the user through: intent capture → skill draft → test case generation → eval runs (with/without skill) → human review → iteration.

**Acceptance Criteria:**
- [ ] Skill creator captures user intent and produces a valid SKILL.md draft
- [ ] Test cases saved to `evals/evals.json` with prompts and expected outputs
- [ ] With-skill and baseline subagent runs launched in parallel in the same turn
- [ ] Eval viewer (`generate_review.py`) launched after each iteration for human review
- [ ] Benchmark aggregation produces `benchmark.json` with pass rate, timing, and token metrics
- [ ] Description optimizer (`run_loop.py`) runs after skill is finalized, reports before/after scores
- [ ] Skill packaged into `.skill` file when `present_files` tool is available

**Edge Cases:**
- Claude.ai environment (no subagents, no browser) — runs test cases inline, skips benchmarking
- Cowork environment (subagents available, no display) — uses `--static` flag for viewer output
- User wants to update an existing skill — preserve original name and directory

### Feature 4: Document Skills (docx, pdf, pptx, xlsx)

**Description:** Source-available skills that power Claude's built-in document creation and editing capabilities. Used by Claude.ai's document features in production.

**Acceptance Criteria:**
- [ ] Each skill produces valid, well-formatted output files of the target type
- [ ] Skills handle both creation (from scratch) and editing (modifying existing files)
- [ ] Brand guidelines skill applies Anthropic colors and typography when invoked

**Edge Cases:**
- Large documents that exceed context — skill references bundled scripts to handle processing in chunks
- Unsupported formatting features — skill degrades gracefully and notes limitations

### Feature 5: Plugin Marketplace Integration (Claude Code)

**Description:** This repository is registered as a Claude Code Plugin marketplace, allowing users to browse and install skill sets via `/plugin` commands.

**Acceptance Criteria:**
- [ ] `document-skills` and `example-skills` plugin sets installable via `/plugin install`
- [ ] Repository registerable as a marketplace via `/plugin marketplace add anthropics/skills`
- [ ] Individual skills invocable by mentioning them in conversation after installation

---

## Non-Functional Requirements

### Performance
- SKILL.md body should remain under 500 lines to keep loading fast; large reference content lives in `references/`
- Skill metadata (~100 words) should add negligible latency to every Claude request

### Security
- Skills must not contain malware, exploit code, or content designed to compromise system security
- Skills should not facilitate unauthorized access, data exfiltration, or deceptive behavior
- Skill contents should match their description — no hidden behavior

### Accessibility
- Skill-creator eval viewer supports keyboard navigation (arrow keys for prev/next)
- Feedback collection works in both browser and headless (static HTML download) environments

### Platform Support
- Claude Code (CLI) — full feature support including subagents, browser, packaging
- Claude.ai — core workflow supported; subagent-dependent features (parallel evals, blind comparison) not available
- Claude API — skills uploadable and usable via Skills API

---

## User Interface

### Skill Creator Eval Viewer
- Browser-based viewer launched via `generate_review.py`
- "Outputs" tab: one test case at a time, prompt + output + optional previous output + feedback textbox
- "Benchmark" tab: pass rates, timing, token usage per configuration with per-eval breakdown
- Headless fallback: `--static <path>` writes a standalone HTML file; feedback downloads as `feedback.json`

### Plugin Installation (Claude Code)
```
/plugin marketplace add anthropics/skills
/plugin install document-skills@anthropic-agent-skills
/plugin install example-skills@anthropic-agent-skills
```

---

## Data Requirements

### Data Model
- **Skill**: `name` (slug), `description`, optional `license`, `compatibility`; SKILL.md body; optional `scripts/`, `references/`, `assets/`
- **Eval Set**: `skill_name`, array of `{id, prompt, expected_output, files, assertions[]}`
- **Run Output**: files produced by the skill for a given prompt, saved to `workspace/iteration-N/eval-ID/with_skill/outputs/`
- **Grading**: per-assertion `{text, passed, evidence}` saved to `grading.json`
- **Benchmark**: per-configuration `{pass_rate, mean±stddev timing, mean±stddev tokens}` in `benchmark.json`

### Data Sources
- User-provided prompts and files (eval inputs)
- Claude API (model outputs during eval runs)
- Human feedback via eval viewer (`feedback.json`)

---

## Dependencies

| Dependency | Type | Owner | Status |
|------------|------|-------|--------|
| Claude API / claude CLI | External | Anthropic | Active |
| Python 3.x (eval scripts) | External | Open Source | Active |
| Playwright (webapp-testing skill) | External | Microsoft | Active |
| p5.js (algorithmic-art skill) | External | Processing Foundation | Active |
| agentskills.io specification | External | Anthropic | Active |

---

## Release Criteria

### Must Have for Launch
- [ ] All 17 skills have valid SKILL.md with name and description
- [ ] skill-creator eval loop works end-to-end in Claude Code environment
- [ ] document skills (docx, pdf, pptx, xlsx) produce valid output files
- [ ] Plugin marketplace registration and install commands work
- [ ] README covers Claude Code, Claude.ai, and API installation paths

### Success Metrics
| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Skill trigger accuracy | >85% on held-out eval set | `run_loop.py` test score |
| With-skill vs. baseline improvement | Measurable pass rate delta | `benchmark.json` per skill |
| Skill creator end-to-end completion rate | User reaches packaged `.skill` file | Usage telemetry |
| Document skill output validity | 0 corrupt output files | File format validation in evals |

---

## Open Questions

- [ ] Should skill evals be included in the public repo or kept in user workspaces only?
- [ ] What is the right cadence for exporting/updating the bundled skills (currently via `chore: export latest skills` commits)?
- [ ] Should the description optimizer (`run_loop.py`) be exposed as a standalone tool separate from skill-creator?
- [ ] Are there plans to support skill versioning / pinning in the plugin system?

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-28 | Michael Dimmitt | Initial draft |
