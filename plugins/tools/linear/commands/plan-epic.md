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

## Validate

Before creating:

- Confirm skills exist in the marketplace (read marketplace.json from the claude-skills repo)
- Confirm core skills are NOT listed (anti-fabrication, git, tdd, twelve-factor, security, mise, nushell)
- Confirm objective is 2-3 sentences
- Confirm slug is kebab-case and under 30 chars
- Confirm at least one repo is specified
- Confirm the body is self-contained: no local-filesystem paths (`~/.claude/...`, `/Users/<name>/...`) used as the source of truth. Embed design plans inline under a `## Design context` section, or link to other epics by Linear URL.
- **Sizing check**: confirm the objective's scope can decompose into approximately 6–8 independently-shippable issues (the adopted sizing convention; see "Epic Sizing Heuristics" in `references/epic-format.md`). If the scope appears to require significantly more issues, spans many repositories with large cross-cutting changes, or contains work that could be separately delivered, prompt the user to consider splitting into multiple epics.
- **Dependency-ordering check**: confirm that the anticipated issues can be ordered topologically (foundational work first, no cycles). If the user has described ordering intent, include a `## Dependencies` section in the epic body; see "Dependency Ordering" in `references/epic-format.md` for format and rules.

## Body Format Rules

Apply the format rules from the `/linear` skill's "Epic Body Format Rules" section to the body you produce in the next step:

- Plain markdown only — no YAML fences in any section.
- Skill labels must exist in the marketplace; core skills (anti-fabrication, git, tdd, twelve-factor, security, mise, nushell) are implicit and not listed.
- Initial state is `Backlog`.
- Bodies are self-contained: embed design context inline, cross-link other epics by Linear URL, never reference local-filesystem paths.

See `plugins/tools/linear/skills/linear/SKILL.md` "Epic Body Format Rules" for the canonical wording.

When the epic's anticipated issue ordering is known, include a `## Dependencies` section in the produced body declaring which issues depend on which others, with foundational issues listed first. The team leader translates this into formal `blockedBy` edges in Linear during decomposition. See "Dependency Ordering" in `references/epic-format.md` for format and rules.

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
