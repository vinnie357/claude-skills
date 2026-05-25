---
description: "Fix VantageEx compatibility issues found by audit-epics"
argument-hint: "[--project=<slug>] [--issue=<key>] [--auto] [--max-issues=<N>] [--confirm-bulk]"
---

Fix VantageEx compatibility issues across one epic or a whole project. Scoped, pre-flight-gated, and offloads the audit pass to a haiku mapper so the parent session never holds full descriptions for an entire project.

## Steps

1. Load the `/linear` skill
2. Read the epic format spec at `references/epic-format.md`
3. Read the audit checklist at `references/audit-checklist.md`
4. Read the team definition template at `templates/0.1.0/team-definition.md`

## Phase A — Pre-flight

Run on every invocation. Halt with a clear message if any check fails — never partial-progress.

1. **Verify Linear access**. Pass if either:
   - The Linear MCP server is registered (`claude mcp list` shows a `linear-server` entry), OR
   - `LINEAR_API_KEY` environment variable is set.

   If neither, halt with:
   > Linear access is not configured. Set up one of:
   > - `claude mcp add --transport http linear-server https://mcp.linear.app/mcp` then `/mcp` to authenticate
   > - `export LINEAR_API_KEY=<key>` (see https://linear.app/settings/account/security)

2. **Resolve scope** from arguments:
   - `--issue=<key>` (e.g., `--issue=VIN-42`) → single-issue path. Skip Phase B; audit + groom inline.
   - `--project=<slug>` → project path. Continue to Phase B.
   - Neither → ask the user which scope.

3. **For project scope: identify open-state IDs.** Query the team's `workflowStates` and keep only states whose `type` is in `{triage, backlog, unstarted, started}`. **Exclude any state whose `type` is `completed` or `canceled`** — grooming closed epics is forbidden and would mutate finished work.

4. **Count candidates.** Query the project for issues in the open-state IDs only. Print the count.

5. **Overload gate.** If `count >= --max-issues` (default `50`), refuse to proceed without `--confirm-bulk`. Suggest narrowing with `--issue=<key>` or batching as a follow-up. This is a hard gate — `--auto` does not bypass it.

## Phase B — Mapper (project scope only)

Spawn a single read-only haiku agent to audit all candidates and return a compact digest. The parent session never holds the full descriptions.

Use the Task tool with `subagent_type: Explore` and `model: haiku`. The mapper prompt:

```
## Load skills

Load these by exact name (no globs):
- /linear (provides MCP/GraphQL helpers and the epic format spec)
- /core:anti-fabrication (no claim without tool verification)

Quote one sentence from each loaded skill in your first response.

## Task

You are auditing Linear epics for VantageEx compatibility. READ-ONLY — do not write to Linear.

For each issue in the candidate list, fetch via Linear MCP (preferred) or GraphQL:
  - identifier, url, title, state.name, state.type, labels, attachments
  - full description

Run the structure + content checks from `references/audit-checklist.md`:
  - Objective Present, Objective Quality
  - Skills Present, Skills Valid, Skills Not Listing Core
  - Repos Present
  - Agents Valid, Agents Section Non-Empty
  - Team Defined
  - PR on Completed (only for state.type == "started" with a state.name suggesting review)
  - Implementation Details

Return JSON, sorted by error_count desc, truncated to top 25:

[
  {
    "identifier": "VIN-42",
    "url": "https://linear.app/...",
    "state_type": "started",
    "state_name": "In Progress",
    "error_count": 2,
    "warning_count": 1,
    "info_count": 0,
    "findings": [
      {"check": "Objective Present", "severity": "error"},
      {"check": "Agents Valid", "severity": "warning", "detail": "gemini -> antigravity"}
    ]
  }
]

Do not include description bodies in the response. The groom phase re-fetches them.
```

## Phase C — Groom

For single-issue scope: audit the one issue inline, then proceed to fix.
For project scope: iterate over the mapper digest.

For each entry:

1. **Re-fetch the full issue body** via MCP or GraphQL (only at fix time — Phase B kept tokens cheap).

2. **Apply fixes** per check:

### Missing Objective
- If the title is descriptive, generate a 2-3 sentence objective from the title and any existing content
- Ask the user to confirm before applying
- `--auto` skips this fix (content change requires human review)

### Missing Skills
- Suggest skills from the title and description
- Validate against `marketplace.json`
- Ask the user to confirm the skill list

### Missing Repos
- Check the description and comments for repo names
- Ask the user to specify if none can be inferred

### Missing Team
- Insert the default team definition: `lead: sonnet, default_model: haiku, escalation: haiku -> sonnet -> opus`
- Apply without asking (safe default)

### Core Skills Listed
- Strip core skills (`anti-fabrication, git, tdd, twelve-factor, security, mise, nushell`) automatically

### Invalid Agents
- Confirm with the user before any rewrite
- Rewrite `gemini` → `antigravity` (the Google CLI runs Gemini)
- Flag any other unknown value (e.g., `gpt4`, `bard`) — do not auto-rewrite

### Empty Agents Section
- Ask the user: remove the empty header (default `[claude]` applies) or fill in agents
- No auto-fix — intent is ambiguous

### Missing PR on Completed
- Search via `gh pr list --search "<issue-identifier>"` and `gh pr list --search "<title>"`
- If found, attach via `attachmentLinkGitHubPR` and add `## PR` section
- If no PR found, flag for manual resolution
- (Phase A excludes `completed`/`canceled` epics; this rule fires only for `review`-state work)

### Implementation Details in Description
- Flag the specific content for user review
- Do not auto-remove — user may have intentional content

3. **Apply writes** via Linear MCP (preferred) or GraphQL.

`--auto` semantics: safe fixes (team default insertion, core-skill stripping) apply silently. Content fixes (objective, skills, repos, invalid agents) still confirm with the user.

## Phase D — Verify + Report

1. Re-run the audit checks on touched epics (reuse the same check set from Phase B).
2. Output a summary:
   - Before/after error + warning counts per epic
   - Epics flagged but skipped (user declined a content fix)
   - Any writes that failed (auth, mutation errors) — these get listed individually with error text
3. For project scope, also report the top-25 cap — if more epics had findings, name the next batch the user can target.

## Auto Mode

If `--auto` is specified:
- Apply all safe fixes without asking (team defaults, core skill removal)
- Still ask for confirmation on content changes (objective, skills, repos, invalid agents)
- Empty Agents Section still requires user input (no auto-fix)
- Pre-flight overload gate still applies (`--auto` does not bypass `--confirm-bulk`)
