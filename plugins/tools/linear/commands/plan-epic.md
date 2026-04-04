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
