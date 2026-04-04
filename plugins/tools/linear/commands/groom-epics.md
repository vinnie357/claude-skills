---
description: "Fix VantageEx compatibility issues found by audit-epics"
argument-hint: "[--project=<slug>] [--issue=<key>] [--auto]"
---

Fix VantageEx compatibility issues found by the audit.

## Steps

1. Load the `/linear` skill
2. Read the epic format spec at `references/epic-format.md`
3. Read the team definition template at `templates/0.1.0/team-definition.md`

## Get Audit Results

Either:
- Accept prior audit output if available in the conversation
- Run a fresh audit (same as `/linear:audit-epics`) for the specified scope

Only process findings with severity `error` or `warning`. Info-level findings are reported but not auto-fixed.

## Fix Each Finding

For each error/warning finding, apply the appropriate fix:

### Missing Objective
- If the title is descriptive, generate a 2-3 sentence objective from the title and any existing description content
- Ask the user to confirm before applying

### Missing Skills
- Analyze the issue title and description to suggest relevant skills
- Validate suggestions against marketplace.json
- Ask the user to confirm the skill list

### Missing Repos
- Check if the issue mentions repository names in its description or comments
- Ask the user to specify target repos if none can be inferred

### Missing Team
- Insert the default team definition: `lead: sonnet, default_model: haiku, escalation: haiku -> sonnet -> opus`
- Apply without asking (this is a safe default)

### Core Skills Listed
- Remove core skills from the skills list automatically

### Missing PR on Completed
- Search for matching PRs using `gh pr list --search "<issue-identifier>"` and `gh pr list --search "<title>"`
- If a matching PR is found, attach it via `attachmentLinkGitHubPR` and add `## PR` section
- If no PR found, flag for manual resolution

### Implementation Details in Description
- Flag the specific content for user review
- Do not auto-remove (user may have intentional content)

## Apply Updates

Use Linear MCP tools (preferred) or GraphQL to:
1. Update issue descriptions with added/fixed sections
2. Create/attach labels for skills
3. Attach PR URLs where found

## Verify

After applying fixes:
1. Re-run the audit checks on modified issues
2. Report what was changed and what remains unfixed
3. Present a before/after summary

## Auto Mode

If `--auto` is specified:
- Apply all safe fixes without asking (team defaults, core skill removal)
- Still ask for confirmation on content changes (objective, skills, repos)
