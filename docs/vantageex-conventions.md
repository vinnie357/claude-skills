# VantageEx Project Conventions

Project-specific conventions for the VantageEx codebase. These conventions apply to agents working on VantageEx epics and are **not** part of the universal `/linear:plan-epic` or `/linear:audit-epics` skills.

## vantage_ex Read-Only Docs Adjunct

### When to Include

Include the `vantage_ex` repository as a docs adjunct **only when the epic's work touches the VantageEx codebase**. Epics scoped entirely to other repositories do not require it.

Indicators that an epic touches VantageEx:

- The epic description references VantageEx features, services, or infrastructure components
- Issues target files in the `vantage_ex` repo
- The work must align with existing VantageEx architecture decisions (ADRs)

### Read-Only Constraint

The `vantage_ex` adjunct repo is **reference material only**.

- **Never edit, commit, or push** inside `vantage_ex`
- Do not create branches, stage files, or run `git add`/`git commit`/`git push` within it
- If a grep or read reveals something that needs to change in VantageEx itself, surface it as a separate issue — do not act on it in-place

### Purpose

Agents grep and read ADRs and design docs in `vantage_ex` while implementing, to align implementation decisions with existing VantageEx architecture. This prevents drift from established patterns for things like:

- Secret management (ADR 008, ADR 026)
- Execution and deployment models (ADR 030, ADR 035, ADR 071)
- Multi-repo workspace conventions (ADR 043, ADR 095)
- Bundle and source resolution (ADR 029, ADR 045, ADR 056, ADR 081)

### Workspace Layout

The `vantage_ex` repo appears as a **sibling clone** alongside the primary working repo in the agent workspace:

```
<workspace>/
├── claude-skills/        # primary repo being modified
└── vantage_ex/           # read-only adjunct (clone separately, do not modify)
```

To clone into position:

```bash
git clone <vantage_ex-remote> <workspace>/vantage_ex
```

### Where to Find ADRs and Design Docs

**Architecture Decision Records (ADRs):**

```
vantage_ex/architecture/decisions/
```

Files follow the pattern `NNN-kebab-title.md` (e.g., `043-multi-repo-workspace-layout-convention.md`). As of the time this document was written, 95 ADRs exist (001 through 095). Always grep for relevant keywords rather than guessing numbers.

**Design docs and conventions:**

```
vantage_ex/docs/
```

Notable subdirectories:

- `docs/conventions/` — authoring conventions and patterns
- `docs/audit/` — audit records
- `docs/research/` — research notes

Individual design docs in `docs/` include `loop-architecture.md`, `team-shapes.md`, `when-to-use-teams.md`, `bundle-authoring-conventions.md`, and others. Grep for relevant topics.

### Recommended Grep Patterns

Before implementing a feature that touches VantageEx conventions, run:

```bash
# Search ADRs for relevant patterns
grep -rl "<keyword>" vantage_ex/architecture/decisions/

# Search design docs
grep -rl "<keyword>" vantage_ex/docs/

# Read a specific ADR
cat vantage_ex/architecture/decisions/<NNN>-<title>.md
```

Replace `<keyword>` with terms specific to the work at hand (e.g., `bundle`, `secrets`, `deployment`, `workspace`).
