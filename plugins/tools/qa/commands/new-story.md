---
description: "Author a persona-aware Gherkin user story compatible with /qa, saved to docs/user-stories/<persona>/<slug>.md"
argument-hint: "<persona>/<slug> [--feature=<short-title>]   OR   <slug> --persona=<persona> [--feature=...]"
---

Author a new Gherkin user story compatible with the `/qa` validator. Runs the `qa-author` agent (haiku) which asks a short questionnaire and writes a parser-valid file to `docs/user-stories/<persona>/<slug>.md`. The resulting story can be validated end-to-end against the running application by running `/qa docs/user-stories/<persona>/<slug>.md`.

**What it does:**

1. **Resolve persona + slug** — accept either `<persona>/<slug>` shorthand or a bare `<slug>` paired with `--persona=<name>`. Validate persona against the repo's allowlist at `.qa/personas.toml` (fall back to a default set if absent). Validate slug against `^[a-z0-9]+(-[a-z0-9]+)*$`.
2. **Confirm the file does not exist** at `docs/user-stories/<persona>/<slug>.md`. Slug uniqueness is scoped per-persona — the same slug under two different personas is allowed and produces two distinct files.
3. **Spawn `qa-author`** — Reads the parser spec at `/qa:qa` `references/gherkin-format.md` and the skeleton at `templates/user-story.md`, then runs the questionnaire.
4. **Questionnaire** — Asks for the feature title, primary actor, app URL, optional shared seed data, golden-path scenario name + steps, and optional edge scenarios + steps. Uses `AskUserQuestion` when available. Persona is pre-filled; confirms only when ambiguous.
5. **Compose + self-validate** — Builds the Gherkin (including the `@persona:<name>` tag and a `**Persona**: <name>` prose line above the fence), re-checks it against the parser rules, and only writes the file when the output is valid.
6. **Write** — Writes `docs/user-stories/<persona>/<slug>.md`. Refuses to overwrite if the file already exists.

**Arguments:**

- `<persona>/<slug>` (shorthand) or `<slug> --persona=<name>` — the persona segment selects the destination directory; the slug becomes the file name.
- `--feature=<short-title>` — optional default offer for the feature-title question.

**Examples:**

```
/qa:new-story editor/cell-regenerate
/qa:new-story cell-regenerate --persona=editor --feature="Editor regenerates a presentation cell"
/qa:new-story owner/share-workbook
/qa:new-story administrator/audit-log --feature="Admin exports the audit log"
```

The same slug under two personas is valid:

```
/qa:new-story owner/cell-create        # writes docs/user-stories/owner/cell-create.md
/qa:new-story editor/cell-create       # writes docs/user-stories/editor/cell-create.md
```

**Skills the author loads (no globs — explicit names):**

- `/qa:qa`
- `/core:anti-fabrication`
- `/core:nushell`

**Task instructions:**

Use the `qa-author` subagent. Parse the argument:

- If the first positional contains exactly one `/`, split into `PERSONA` / `SLUG`. If it contains zero `/`, the first positional is `SLUG`; require `--persona=<name>`. Multiple `/` is an error.
- Validate `PERSONA` against `<REPO_ROOT>/.qa/personas.toml` (or the default set `{owner, editor, viewer, cross-persona, administrator}` if the file is absent).
- Validate `SLUG` against `^[a-z0-9]+(-[a-z0-9]+)*$`.
- Compute the resolved target path: `<REPO_ROOT>/docs/user-stories/<PERSONA>/<SLUG>.md`.

Verify the resolved target does not exist before spawning the agent — refuse to overwrite. Pass `RAW_SLUG`, `PERSONA`, the `--feature` value if provided, and the repo root (current working directory unless the path is in a subrepo) to the agent.
