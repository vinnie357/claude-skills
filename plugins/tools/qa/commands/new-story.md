---
description: "Author a Gherkin user story compatible with /qa, saved to docs/user-stories/<name>.md"
argument-hint: "<slug> [--feature=<short-title>]"
---

Author a new Gherkin user story compatible with the `/qa` validator. Runs the `qa-author` agent (haiku) which asks a short questionnaire and writes a parser-valid file to `docs/user-stories/<slug>.md`. The resulting story can be validated end-to-end against the running application by running `/qa docs/user-stories/<slug>.md`.

**What it does:**

1. **Validate the slug** — kebab-case, no spaces or slashes; the file must not already exist.
2. **Spawn `qa-author`** — Reads the parser spec at `/qa:qa` `references/gherkin-format.md` and the skeleton at `templates/user-story.md`, then runs the questionnaire.
3. **Questionnaire** — Asks for the feature title, primary actor, app URL, optional shared seed data, golden-path scenario name + steps, and optional edge scenarios + steps. Uses `AskUserQuestion` when available.
4. **Compose + self-validate** — Builds the Gherkin, re-checks it against the parser rules, and only writes the file when the output is valid.
5. **Write** — Writes `docs/user-stories/<slug>.md`. Refuses to overwrite if the file already exists.

**Arguments:**

- `<slug>` — kebab-case identifier; becomes the file name. Required.
- `--feature=<short-title>` — optional default offer for the feature-title question.

**Examples:**

```
/qa:new-story checkout
/qa:new-story user-registration --feature="Email-based signup"
```

**Skills the author loads (no globs — explicit names):**

- `/qa:qa`
- `/core:anti-fabrication`
- `/core:nushell`

**Task instructions:**

Use the `qa-author` subagent. Pass it the resolved slug (rejecting if it does not match `^[a-z0-9]+(-[a-z0-9]+)*$`), the `--feature` value if provided, and the repo root (current working directory unless the path is in a subrepo). Verify `docs/user-stories/<slug>.md` does not exist before spawning the agent — refuse to overwrite.
