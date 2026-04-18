---
name: allium-db
description: Allium behavioral spec store for querying specs at propagate/weed time via Dolt-backed database. Use when registering behavioral specs, resolving epic specs, comparing code against stored specs, or capturing new specs interactively.
license: MIT
---

# Allium-db Skill

Allium-db is a behavioral specification store built on Dolt (version-controlled SQL database). It provides four primary commands for managing and querying behavioral specs: `/allium-db:register` (ingest `.allium` files), `/allium-db:resolve` (fetch specs for epics), `/allium-db:weed` (compare code against specs), and `/allium-db:elicit` (interactive spec capture).

This skill wraps the underlying `allium-db` CLI binary (vinnie357/allium-db, private repo). The CLI implements the actual Dolt-backed storage; this skill provides Claude agents access via Nushell wrappers.

## When to Use This Skill

Activate when:
- Registering or ingesting `.allium` behavioral spec files into the database
- Resolving/fetching stored behavioral specs for a given epic
- Comparing existing code against stored behavioral specifications (weed step)
- Capturing new behavioral specs interactively during spec authoring (elicit step)
- Using `/core:agent-loop` with Allium integration for TDD workflows

## Commands

This skill exposes four sub-commands via `/allium-db:<command>`:

### `/allium-db:register <spec-path>`

Ingest a `.allium` behavioral spec file into the Allium-db database.

**When to use:**
- After writing a new `.allium` file in an ADR or epic specification
- When seeding the database with baseline specs from existing epics
- During CI/CD to version-lock specs alongside code

**Arguments:**
- `<spec-path>`: Relative or absolute path to `.allium` file

**Returns:**
Structured output (record) confirming registration: epic ID, spec hash, timestamp, commit SHA

**Example:**
```bash
/allium-db:register ./docs/adr/ADR-035-deployment-model.allium
```

Expected output:
```
epic_id    spec_hash                    registered_at            git_sha
VIN-52     a7f2d8e1c4b9f3e6a2d5c8b1f4  2026-04-18T10:30:00Z     abc1def2ghi3jkl4mno5pqr6stu
```

### `/allium-db:resolve <epic-slug>`

Fetch the behavioral specification record for a given epic from the database.

**When to use:**
- When an agent needs to load a spec before implementing a feature (propagate step)
- To verify what spec is currently registered for an epic
- During code review to cross-reference implementation against stored spec

**Arguments:**
- `<epic-slug>`: VantageEx epic slug (e.g., VIN-52, VIN-72)

**Returns:**
Structured output: epic slug, spec content (`.allium` TOML), registered timestamp, commit SHA

**Example:**
```bash
/allium-db:resolve VIN-72
```

Expected output:
```
epic_slug  spec_content                          registered_at
VIN-72     [title]                               2026-04-18T10:30:00Z
           name = "Allium-db Plugin Scaffold"
           ...
```

### `/allium-db:weed <code-path>`

Compare code in a given path against the stored behavioral specification, reporting divergence.

**When to use:**
- During the weed phase of TDD to detect code-spec misalignment
- When auditing implementation against original design intent
- To catch scope creep or unintended feature additions

**Arguments:**
- `<code-path>`: Relative or absolute path to code file/directory

**Returns:**
Structured output: divergence report with sections (missing implementations, extra code, mismatches), severity, and remediation suggestions

**Example:**
```bash
/allium-db:weed ./lib/allium_db/register.ex
```

Expected output:
```
status      violations  severity  comment
mismatch    3           high      Code implements features not in spec
```

### `/allium-db:elicit`

Interactive spec capture prompt. Guides agents through structured behavioral spec authoring.

**When to use:**
- When designing a new feature and no spec yet exists
- To systematically capture "what should happen" before coding
- In pair programming or design review sessions

**Arguments:**
None (interactive)

**Returns:**
Draft `.allium` specification (TOML format) ready for registration

**Example:**
```bash
/allium-db:elicit
```

This launches an interactive flow:
```
[Allium Elicit - Interactive Spec Capture]
Epic slug? VIN-72
Feature name? Allium-db Plugin
Description? Scaffold a Claude plugin...
Success criteria? 
  1. Plugin structure mirrors runex layout
  2. Four commands (register/resolve/weed/elicit) defined
  3. marketplace.json updated
  4. All tests pass
...
```

## Integration with Allium Workflow

Allium-db is part of the larger Allium system (see `/allium:allium` skill for full workflow). In the agent-loop lifecycle:

1. **Spec Design** — ADR author writes `.allium` file (or uses `/allium-db:elicit`)
2. **Register** — `/allium-db:register` seeds database, locks spec with git_sha
3. **Propagate** — Agents `/allium-db:resolve` to fetch spec before implementation
4. **Code** — Agents implement to spec
5. **Weed** — `/allium-db:weed` checks code against spec at PR time
6. **Complete** — Merge PR; spec and code are versioned together

## Nushell Wrapper Scripts

Versioned Nushell wrappers live in `scripts/0.1.0/` and translate Claude commands to CLI invocations.

The wrapper scripts are stubs initially — they print "not yet implemented — install allium-db from vinnie357/allium-db first" and delegate to the underlying CLI binary once available.

### Installation

The `allium-db` CLI binary is installed via `mise` from the `vinnie357/allium-db` repository (private, in development). Add to your `mise.toml` or use:

```bash
mise exec allium-db -- allium-db --version
```

(Once the private repo is configured in your mise setup.)

## See Also

- `/allium:allium` — Full Allium behavioral spec integration with `/core:agent-loop`
- `references/commands.md` — Detailed command reference and examples
- `vinnie357/allium-db` — Underlying Zig CLI (private repo, in development)
