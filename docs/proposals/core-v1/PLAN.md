# Proposal: core v1 — one portable skill

## Goal

Derive the essence of fail-forward delivery, our existing core loops, and the
[Modern App Manifesto](https://github.com/vinnie357/modern-apps-manifesto) into a minimal,
harness-agnostic skill set that any agent can load on any project without teaching it our
patterns each session.

## Constraints

- One core skill, ≤25 lines, Agent Skills spec fields only (`name`, `description`, `license`, `metadata`).
- Enforceable rules become mise tasks, lint rules or hooks, not prose.
- No forced context injection (no SessionStart skill dumps).
- `AGENTS.md` holds project-specific rules only. Process rules live in the skill.
- Tracking lives in an external tracker (GitHub Issues or Linear); one issue = one branch = one worktree.

## Harness research (official docs, 2026-10-07)

| | Claude Code | Codex CLI | Antigravity (IDE + CLI) |
|---|---|---|---|
| Skill format | `SKILL.md`, agentskills.io supported | `SKILL.md`, builds on agentskills.io | `SKILL.md`, "open standard" |
| Startup context | name + description only | name + description + path, capped at 2% of context / 8,000 chars | name + description only |
| User skill dir | `~/.claude/skills/` | `~/.agents/skills/` (symlinks followed) | IDE `~/.gemini/config/skills/`, CLI `~/.gemini/antigravity-cli/skills/` |
| Project skill dir | `.claude/skills/` | `.agents/skills/` (cwd up to repo root) | `.agents/skills/` |
| Instruction file | `CLAUDE.md`; reads `AGENTS.md` only when no CLAUDE.md exists, else `@AGENTS.md` import | `AGENTS.md` global → root → cwd, 32 KiB cap | `AGENTS.md` / `GEMINI.md`, root and subdirs |
| Plugin | skills, agents, hooks, MCP; plugin CLAUDE.md is ignored | skills, MCP, hooks via marketplace | `plugin.json` with skills, agents, rules, MCP, hooks |
| Subagent skills | `skills:` frontmatter preloads bodies | custom agent TOML `skills.config` | subagents exist; skill scoping not verified |

Sources: code.claude.com/docs/en/{skills,memory,sub-agents,plugins-reference,hooks};
developers.openai.com/codex/{skills,guides/agents-md,plugins,hooks,subagents};
antigravity.google/docs/{skills,rules,plugins,cli/features}.

Not verified: the `agy` command name; Antigravity hook events and symlink handling;
Codex install-from-arbitrary-repo syntax.

## Findings that shape the design

1. All three harnesses use progressive disclosure: only the description is always loaded.
   The description is the activation contract; the body can stay short.
2. `.agents/skills/` is shared by Codex and Antigravity. Claude Code uses `.claude/skills/`.
   One source directory plus per-harness symlinks or plugin packaging covers all three.
3. All three read `AGENTS.md` (Claude Code via `@AGENTS.md` when CLAUDE.md exists), so project
   rules stay in one file and process rules never go there.
4. Plugin `CLAUDE.md` is ignored by Claude Code; plugin instructions must be skills. This rules
   out the current SessionStart injection as the delivery mechanism.
5. Codex caps the skill index at 2% of context; a large skill set gets truncated. Fewer skills
   with sharper descriptions is a requirement, not a preference.

## Proposed shape

```
core/
├── SKILL.md            # ~25-line manifesto, spec-only frontmatter
├── references/         # loaded on demand: gate catalog, release flow, review checklist
└── assets/
    ├── mise.toml       # gate template: ci, test, lint, lint:prose, lint:secrets, release
    └── vale/           # prose rules replacing anti-fabrication / technical-english
```

Delivery per harness (minimal instructions):

- Claude Code: plugin `core` in this marketplace, or symlink to `~/.claude/skills/core`.
- Codex: symlink to `~/.agents/skills/core`.
- Antigravity: symlink to `~/.gemini/config/skills/core` and `~/.gemini/antigravity-cli/skills/core`,
  or a plugin under `~/.gemini/config/plugins/`.
- A `mise run install:<harness>` task does the linking, so installation is itself a gate.

## Manifesto content sources

| Source | Kept as |
|---|---|
| Fail forward | dev always current; main semver-released per merge; low-risk repos target main; fix forward, never rewrite history |
| Core loops (agent-loop, git) | issue → worktree → focused workers → three merge guards → operator merge |
| Modern App Manifesto | V errors carry a path forward (gates emit the failure, not the log); VII bounded merge authority; VIII idempotent, resumable tasks; IX evidence on demand; X secrets out of reach; XI budgets per worker; XII verify outcomes |
| tdd, anti-fabrication, restraint | one line each, enforced by tests and Vale where possible |

## Experiment

Run representative past issues twice in fresh sessions per harness: current core vs. core v1.
Exact measures: tokens, wall-clock, first-push CI result, fix-forward commit count, merged.
Judgment measures (review findings, scope creep) are scored on thresholds across repeated runs.
No conclusion until both arms have run.

## Open questions

- Ship as core 1.0 in this repo, or a new standalone skills repo?
- GitHub Issues, Linear, or a thin adapter for both?
- Worker skill selection: description matching alone, or a task → skills index?
- Arm B run in progress (vinnie357/skills bootstrap) used the 25-line draft; compare against the 20-line cut.
