---
description: "Audit Linear epics for VantageEx compatibility and produce a findings report"
argument-hint: "[--project=<slug>] [--state=<state>] [--issue=<key>]"
---

Audit existing Linear epics for VantageEx compatibility.

## Steps

1. Load the `/linear` skill
2. Read the audit checklist at `references/audit-checklist.md`
3. Read the audit report template at `templates/0.1.0/audit-report.md`

## Fetch Issues

Determine scope from arguments:

- `--issue=<key>`: Audit a single issue by key (e.g., MT-123)
- `--project=<slug>`: Audit all issues in a project
- `--state=<state>`: Filter by Linear state type (e.g., "started", "unstarted", "completed")
- No arguments: Ask the user which project or issues to audit

Use Linear MCP tools (preferred) or GraphQL to fetch issues with their full descriptions, states, labels, and attachments.

## Run Checks

For each issue, run every check from the audit checklist:

### Structure Checks
- Parse description for `## Objective`, `## Skills`, `## Repos` sections
- Validate objective quality (2-3 sentences)
- Validate skills exist in marketplace (read marketplace.json)
- Check for core skills that should not be listed

### Team Checks
- Check for `## Team` section
- Check for escalation policy

### Naming Checks
- Evaluate title quality (imperative statement)
- Check slug derivability
- Check branch naming convention if branch exists

### State Consistency Checks
- For completed/review issues: check for `## PR` section or GitHub PR attachment
- For needs_help issues: check for blocker documentation
- Use `gh pr list` and `gh pr view` to cross-reference PR URLs

### Epic-Sizing Checks

See `references/epic-sizing.md` for thresholds.

- Flag epics with > 8 issues — signal to split the epic
- Flag issues with > ~10 target files — exceeds one worker session
- Flag multi-deliverable issue titles (joined by "and", "also", "then", "plus") — split them
- Flag acceptance criteria that cannot be verified in a single worker session
- Flag issues with cross-subsystem or cross-repo scope — split candidates

### Dependency-Ordering Checks

See `references/epic-sizing.md` for conventions.

- Flag issues with implicit or missing dependency declarations (no blocking relations / bees deps)
- Flag dependency cycles — halt: re-decompose required before queueing
- Flag dependency chains deeper than 5 levels — serializes workers unnecessarily
- Flag independent issues that are serialized without cause — reduces worker fan-out

### Content Quality Checks
- Check for implementation details (file paths, code blocks outside YAML)
- Check that constraints are meaningful (not just defaults)

## Generate Report

Use the `templates/0.1.0/audit-report.md` format:

1. Summary table with counts by severity
2. Per-issue findings sorted by error count (most errors first)
3. Each finding includes: check name, severity, status, detail
4. Remediation actions for each failing check

## Output

Present the report to the user. Suggest running `/linear:groom-epics` to fix errors and warnings automatically.
