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

### Agents Valid
- **Severity**: warning
- **Check**: If `## Agents` section is present, every entry is in the canonical set `{claude, codex, antigravity, local}`
- **Remediation**: Replace unknown values with canonical agents. `gemini` should be written as `antigravity` (the Google CLI runs Gemini).

### Agents Section Non-Empty
- **Severity**: info
- **Check**: If a `## Agents` header is present, the body lists at least one agent identifier
- **Remediation**: Either remove the empty `## Agents` header (the default `[claude]` will apply) or list at least one agent.

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

## Epic Sizing Checks

### Epic Not Oversized
- **Severity**: warning
- **Check**: If the epic has child issues in Linear, count them. Flag if the count exceeds the sizing convention (target: approximately 6–8 issues per epic — an adopted convention, not a measured limit). See the "Epic Sizing Heuristics" section of the epic format specification.
- **Remediation**: Split the epic into multiple epics, each covering a smaller independently-deliverable scope.

### No Multi-Repo Sprawl
- **Severity**: warning
- **Check**: If the `## Repos` section lists three or more repositories and the objective describes large cross-cutting changes affecting all of them, flag as a potential oversized epic.
- **Remediation**: Consider splitting into repo-scoped epics, each targeting one or two repositories, linked by Linear URL.

## Dependency Ordering Checks

### Dependencies Declared
- **Severity**: warning
- **Check**: If the epic has two or more child issues in Linear, verify that at least one `blockedBy` dependency edge exists among them. If no dependency edges are declared and the issues are not logically independent of each other, flag as missing dependency ordering.
- **Remediation**: Declare `blockedBy` edges in Linear to establish execution order. The epic body's `## Dependencies` section (if present) should guide this. See "Dependency Ordering" in the epic format specification.

### No Dependency Cycles
- **Severity**: error
- **Check**: Verify that the dependency edges among the epic's child issues form a valid DAG (no cycles). A cycle exists when issue A directly or transitively depends on itself.
- **Remediation**: Halt. Remove the cycle by eliminating one or more dependency edges and, if needed, restructuring the issue decomposition.

### Foundational Work First
- **Severity**: info
- **Check**: Verify that issues with no incoming dependencies (DAG sources) are not themselves marked as `blockedBy` another issue. A source issue that is also blocked indicates an inconsistent dependency declaration.
- **Remediation**: Review and correct `blockedBy` edges to ensure foundational work is unblocked and can start immediately.

## Running an Audit

1. Fetch issues from Linear (by project, state, or specific key)
2. Parse each issue's description into sections
3. Run each check against the parsed sections
4. For state consistency checks, cross-reference with GitHub PRs via `gh` CLI
5. For skills validation, read marketplace.json
6. Generate report using `templates/0.1.0/audit-report.md` format
7. Sort findings by severity (errors first, then warnings, then info)
