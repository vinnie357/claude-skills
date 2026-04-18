---
name: elicit
description: Interactive behavioral spec capture
---

# /allium-db:elicit

Launch an interactive prompt to guide systematic behavioral spec authoring.

## Command

```
/allium-db:elicit
```

## When to Use

- When designing a new feature and no spec yet exists
- To systematically capture "what should happen" before coding
- In pair programming or design review sessions
- When spec discovery is needed before implementation begins

## Arguments

None (command is fully interactive)

## Returns

A draft `.allium` specification file (TOML format) ready for editing and registration via `/allium-db:register`.

## Interactive Flow

The command prompts for:

1. **Epic slug** — VantageEx epic identifier (e.g., VIN-72)
2. **Feature name** — Brief title of the feature
3. **Description** — Detailed description of the feature
4. **Success criteria** — Multi-line list of measurable completion criteria
5. **Edge cases** — Boundary conditions and error scenarios
6. **Dependencies** — Related skills or epics (`/core:agent-loop`, etc.)
7. **Deliverables** — Code artifacts, docs, or other outputs

## Example

```bash
/allium-db:elicit
```

Interactive prompts:
```
[Allium Elicit - Interactive Spec Capture v0.1.0]

Epic slug? VIN-72
Feature name? Allium-db Plugin Scaffold
Description? Create a Claude plugin for Allium-db that provides agents with
register/resolve/weed/elicit commands for behavioral spec management.

Success criteria? 
  1. Plugin structure mirrors runex layout
  2. Four commands are defined and working
  3. marketplace.json includes allium-db entry
  4. All tests pass locally and in CI

Edge cases?
  1. Missing .allium file
  2. Invalid TOML syntax
  3. Dolt database unavailable

Dependencies?
  /core:agent-loop
  /allium:allium

Deliverables?
  - .claude-plugin/plugin.json
  - skills/allium-db/SKILL.md
  - skills/allium-db/scripts/0.1.0/allium-db.nu
  - commands/{register,resolve,weed,elicit}.md

Generating spec...

[DRAFT SPEC CREATED]
Path: /tmp/allium-spec-VIN-72.allium
Ready for review, editing, and registration via /allium-db:register
```

## Errors

- **Prompt timeout**: No input received within timeout window
- **Database error**: Cannot connect to Allium-db
- **Parse error**: Invalid input format

## References

- See `SKILL.md` for Allium workflow overview
- See `references/commands.md` for detailed command reference
- See `/allium:allium` for full Allium system integration
