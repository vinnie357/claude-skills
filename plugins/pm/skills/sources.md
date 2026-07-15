# Sources

## spec-harvest skill

Internal sources — this skill is composed of conventions from other skills in this marketplace.

- **`/qa:qa`** — Gherkin dialect reference for user-story format consistency. Path: `plugins/tools/qa/skills/qa/references/gherkin-format.md`.
- **`/core:bees`** — Bees issue tracker CLI for spec-to-bees workflow integration. Source of read-only query surface: `bees list`, `bees show`, `bees ready`, `bees prime`, `bees dep list`, `bees comment list`. Path: `plugins/core/skills/bees/SKILL.md`.
- **`/core:anti-fabrication`** — Confidence-tagging discipline for specifications. Required for tagging uncertain assumptions in harvested specs. Path: `plugins/core/skills/anti-fabrication/SKILL.md`.
- **`/core:agent-loop`** — Team orchestration model for the pm-lead → pm-discovery → pm-separator → pm-sdlc-assessor → pm-spec-writer → pm-prd-author pipeline. Path: `plugins/core/skills/agent-loop/SKILL.md`.
- **`/core:security`** — SDLC security checklist items (OWASP categories, secret-scanning rules). Source of security assertion vocabulary. Path: `plugins/core/skills/security/SKILL.md`.

## prd skill

Internal sources — this skill is composed of conventions from other skills and domain references.

- **`/core:anti-fabrication`** — Ensures PRD claims about implementation feasibility are evidence-backed. Path: `plugins/core/skills/anti-fabrication/SKILL.md`.
- **`/core:agent-loop`** — Team composition guidance for Implementation Team subsection of the PRD. Path: `plugins/core/skills/agent-loop/SKILL.md`.
- **`/core:twelve-factor`** — Twelve-Factor App methodology informing Infrastructure Requirements section. Path: `plugins/core/skills/twelve-factor/SKILL.md`.
- **`/core:security`** — Security requirements section foundation. Path: `plugins/core/skills/security/SKILL.md`.

## External

- **Gherkin Reference** — Cucumber's Gherkin specification for user-story step format alignment. URL: https://cucumber.io/docs/gherkin/reference/ (accessed 2026-07-15).
- **User Stories — Agile Alliance Glossary** — Story header format, acceptance-criteria practice, and role-based narrative structure. URL: https://www.agilealliance.org/glossary/user-stories/ (accessed 2026-07-15).
- **SPDX License List** — Canonical license identifiers and expressions for License Assignment section. URL: https://spdx.org/licenses/ (accessed 2026-07-15).
- **OWASP Top 10:2025** — The ten 2025 security categories anchoring the Security Checklist section in harvested specs. URL: https://owasp.org/Top10/2025/ (accessed 2026-07-15).
- **Production readiness checklist** — Supportability checklist items for Supportability & Monitoring section. Source: getdx.com production-readiness-checklist (accessed 2026-07-15).
- **The Only PRD Template You Need** — PRD section set including Features Out and Go-No-Go criteria. Product School blog. URL: https://productschool.com/blog/product-strategy/product-template-requirements-document-prd (accessed 2026-07-15).
- **How to write a good spec for AI agents** — PRD-vs-implementation-spec boundary and agent-specific acceptance criteria. Addy Osmani. URL: https://addyosmani.com/blog/good-spec/ (accessed 2026-07-15).

## Plugin metadata

- **Plugin**: pm
- **Version**: 0.1.0
- **Description**: Product management toolkit: harvest implementation-agnostic feature specs from prototypes with SDLC guardrails and author PRDs as implementation contracts
- **Skills count**: 2 (spec-harvest, prd)
- **Agents count**: 6 (pm-lead, pm-discovery, pm-separator, pm-sdlc-assessor, pm-spec-writer, pm-prd-author)
- **Commands count**: 3 (harvest, assess, prd)
- **Created**: 2026-07-15
