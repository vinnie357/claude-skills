---
description: "Create a new VantageEx-compatible epic in Linear with proper structure and validation"
argument-hint: "<title> [--project=<slug>] [--skills=<list>]"
---

Create a new VantageEx-compatible epic in Linear.

## Steps

1. Load the `/linear` skill
2. Read the epic template at `templates/0.1.0/epic.md`
3. Read the epic format spec at `references/epic-format.md`

## Gather Information

Interactively collect from the user:

- **Title**: Clear, imperative statement of what gets built
- **Slug**: Derive from title (kebab-case, max ~30 chars). Confirm with user.
- **Objective**: 2-3 sentences defining success criteria
- **Skills**: Domain-specific skills needed. Validate each against the marketplace at `https://github.com/vinnie357/claude-skills/blob/main/.claude-plugin/marketplace.json`. Warn if a skill is not found.
- **Repos**: Target repositories
- **Constraints**: Optional. Note that defaults apply (mise run ci, no attribution, squash merge, feature/<slug>)
- **Team**: Optional. Default: lead=sonnet, default_model=haiku, escalation=haiku->sonnet->opus

## Size & Order

Apply `references/epic-sizing.md` to the issues you intend to create:

- **Decompose** the epic into 3–8 independently completable issues. If the count would exceed 8, split the epic.
- **Size each issue** to one worker session: ≤ ~10 target files, one deliverable, one subsystem, verifiable by a single acceptance check. Reject multi-deliverable titles (joined by "and/also/then/plus") — split them.
- **Declare dependencies explicitly** using Linear blocking relations. Never rely on implicit ordering.
- **Order topologically**: foundation issues (schemas, references, interfaces) first, then core, integration, and verification. No cycles — if a cycle is detected, re-decompose before proceeding.
- **Keep chains shallow**: dependency depth < 5 levels; do not serialize issues that can run in parallel.

See `references/epic-sizing.md` for thresholds and the full checklist.

## Validate

Before creating:

- Confirm skills exist in the marketplace (read marketplace.json from the claude-skills repo)
- Confirm core skills are NOT listed (anti-fabrication, git, tdd, twelve-factor, security, mise, nushell)
- Confirm objective is 2-3 sentences
- Confirm slug is kebab-case and under 30 chars
- Confirm at least one repo is specified
- Confirm the body is self-contained: no local-filesystem paths (`~/.claude/...`, `/Users/<name>/...`) used as the source of truth. Embed design plans inline under a `## Design context` section, or link to other epics by Linear URL.

## Body Format Rules

Apply the format rules from the `/linear` skill's "Epic Body Format Rules" section to the body you produce in the next step:

- Plain markdown only — no YAML fences in any section.
- Skill labels must exist in the marketplace; core skills (anti-fabrication, git, tdd, twelve-factor, security, mise, nushell) are implicit and not listed.
- Initial state is `Backlog`.
- Bodies are self-contained: embed design context inline, cross-link other epics by Linear URL, never reference local-filesystem paths.

See `plugins/tools/linear/skills/linear/SKILL.md` "Epic Body Format Rules" for the canonical wording.

## Create in Linear

Use the Linear MCP tools (preferred) or the GraphQL API to:

1. Create the issue with the title
2. Set the description using the template format with all gathered sections
3. Apply skill names as labels (create labels if they do not exist)
4. Set initial state to "Ready" or "Backlog" (the default unstarted state)

## Report

Output:
- Linear issue URL
- Issue identifier (e.g., MT-123)
- Feature branch name: `feature/<slug>`
- Summary of what was created
