# Epic Audit Checklist

Structured validation checks for VantageEx epic compatibility. Each check has a severity level and remediation guidance.

## Severity Levels

| Level | Meaning |
|-------|---------|
| **error** | Epic cannot be consumed by VantageEx. Must fix before moving to `up_next`. |
| **warning** | Epic is consumable but may cause suboptimal results. Should fix. |
| **info** | Style or convention suggestion. Fix when convenient. |

## Structure Checks

### Objective Present
- **Severity**: error
- **Check**: Description contains `## Objective` section
- **Remediation**: Add a `## Objective` section with 2-3 sentences defining success criteria

### Objective Quality
- **Severity**: warning
- **Check**: Objective is 2-3 sentences (not a one-liner or a paragraph)
- **Remediation**: Rewrite to be concise but specific. Define what "done" looks like.

### Skills Present
- **Severity**: error
- **Check**: Description contains `## Skills` section
- **Remediation**: Add a `## Skills` section listing domain-specific skills needed

### Skills Valid
- **Severity**: warning
- **Check**: Each skill listed exists in the marketplace (https://github.com/vinnie357/claude-skills/blob/main/.claude-plugin/marketplace.json) or in the project's local skills directory
- **Remediation**: Replace unknown skills with valid marketplace skill names, or create the skill if it does not exist

### Skills Not Listing Core
- **Severity**: info
- **Check**: Skills list does not include core skills (anti-fabrication, git, tdd, twelve-factor, security, mise, nushell)
- **Remediation**: Remove core skills from the list — they are always loaded

### Repos Present
- **Severity**: error
- **Check**: Description contains `## Repos` section with at least one repository
- **Remediation**: Add a `## Repos` section listing target repositories

## Team Checks

### Team Defined
- **Severity**: warning
- **Check**: Description contains `## Team` section with lead model and default model
- **Remediation**: Add a `## Team` section. Use template: `lead: sonnet`, `default_model: haiku`, `escalation: haiku -> sonnet -> opus`

### Escalation Policy
- **Severity**: info
- **Check**: Team section or `## Escalation` section defines escalation policy
- **Remediation**: Add escalation line to Team section or separate `## Escalation` section

## Naming Checks

### Title Quality
- **Severity**: warning
- **Check**: Title is an imperative statement (not vague like "Fix stuff" or "Updates")
- **Remediation**: Rewrite title as a clear imperative statement of what gets built

### Slug Present
- **Severity**: warning
- **Check**: Epic has a slug or the title can derive a clean kebab-case slug
- **Remediation**: Ensure the title produces a slug under 30 chars in kebab-case

### Branch Convention
- **Severity**: warning
- **Check**: If a branch exists for this epic, it follows `feature/<slug>` pattern
- **Remediation**: Rename branch to `feature/<epic-slug>`

## State Consistency Checks

### PR on Completed
- **Severity**: error
- **Check**: If epic status is Done/Complete/In Review, description contains `## PR` section with a URL or the issue has a GitHub PR attachment
- **Remediation**: Attach the PR URL via `attachmentLinkGitHubPR` mutation and add `## PR` section

### PR URL Valid
- **Severity**: warning
- **Check**: If `## PR` section exists, the URL points to a valid GitHub pull request
- **Remediation**: Update the PR URL. Use `gh pr view <url>` to verify.

### Needs Help Has Summary
- **Severity**: warning
- **Check**: If epic status is Needs Help, there is a comment or description section explaining the blocker
- **Remediation**: Add a comment documenting what failed and what was attempted

## Content Quality Checks

### No Implementation Details
- **Severity**: warning
- **Check**: Description does not contain file paths, code blocks (outside skill/constraint YAML), or step-by-step instructions
- **Remediation**: Remove implementation details. The team leader handles decomposition.

### No Core Skills Listed
- **Severity**: info
- **Check**: Same as "Skills Not Listing Core" above
- **Remediation**: Remove core skills from skills list

### Constraints Are Real
- **Severity**: info
- **Check**: Constraints section (if present) contains meaningful boundaries, not just defaults
- **Remediation**: Remove constraint section if it only restates defaults (mise run ci, no attribution, squash merge)

## Running an Audit

1. Fetch issues from Linear (by project, state, or specific key)
2. Parse each issue's description into sections
3. Run each check against the parsed sections
4. For state consistency checks, cross-reference with GitHub PRs via `gh` CLI
5. For skills validation, read marketplace.json
6. Generate report using `templates/0.1.0/audit-report.md` format
7. Sort findings by severity (errors first, then warnings, then info)
