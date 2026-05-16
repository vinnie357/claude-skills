# Sources

## qa skill

Internal sources — this skill is composed of conventions from other skills in this marketplace.

- **`/core:tdd`** — Test-Driven Development methodology. Source of the Red-Green-Refactor cycle quoted verbatim in `references/validation-loop.md`. Path: `plugins/core/skills/tdd/SKILL.md`.
- **`/core:bees`** — Bees issue tracker CLI. Source of the `bees new`/`bees close`/`bees dep add` syntax referenced from `references/delta-format.md`. Path: `plugins/core/skills/bees/SKILL.md`.
- **`/core:bees` bees-manager agent** — The serialized-writer agent that consumes `BEES REQUESTS:` blocks. Source of the input contract grammar mirrored in `references/delta-format.md`. Path: `plugins/core/skills/bees/agents/bees-manager.md`.
- **`/playwright:playwright`** — Playwright MCP server skill. Source of the MCP tool names used by the `qa-playwright` agent. Path: `plugins/tools/playwright/skills/playwright/SKILL.md`.
- **`/elixir:tidewave`** — Tidewave MCP skill for Phoenix runtime introspection. Source of the MCP tool names used by the `qa-tidewave` agent. Path: `plugins/languages/elixir/skills/tidewave/SKILL.md`.
- **`/elixir:phoenix`** — Phoenix application conventions. Loaded by `qa-tidewave` for context on Phoenix module layout, Ecto schemas, and LiveView assertions. Path: `plugins/languages/elixir/skills/phoenix/SKILL.md`.
- **`/core:anti-fabrication`** — Required by every QA agent. Source of the "every claim requires tool output" rule. Path: `plugins/core/skills/anti-fabrication/SKILL.md`.

## External

- **Gherkin reference syntax** — Cucumber's Gherkin specification. The dialect in `references/gherkin-format.md` is a strict subset: Feature / Background / Scenario / Scenario Outline / Examples / Given / When / Then / And / But, single-line steps, no doc strings, no data tables in v0.1.0. URL: https://cucumber.io/docs/gherkin/reference/ (accessed during plan authoring, 2026-05-16).

## Plugin metadata

- **Plugin**: qa
- **Version**: 0.1.0
- **Description**: QA team that validates a running application against Gherkin user stories using Playwright and Tidewave
- **Skills count**: 1 (qa)
- **Agents count**: 7 (qa-lead, qa-author, qa-playwright, qa-tidewave, qa-backend, qa-test-writer, qa-implementer)
- **Commands count**: 2 (qa, new-story)
- **Created**: 2026-05-16
