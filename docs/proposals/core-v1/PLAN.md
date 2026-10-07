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

One file: `core/SKILL.md` (20 lines). No references, assets, agents, hooks or commands.
Everything else comes from provider skills and plugins (Anthropic, Codex, Antigravity) or the
project itself (`AGENTS.md`, `mise.toml`). An addition to core must show, by experiment, an
outcome the 20 lines fail to produce.

Delivery: symlink the skill folder into the harness user skill dir (`~/.claude/skills`,
`~/.agents/skills`, `~/.gemini/config/skills`, `~/.gemini/antigravity-cli/skills`), or install
the Claude Code plugin wrapping the same folder.

## Baby gates

Agents move with confidence because gates, not agents, read test output. `tools/gate.nu`
wraps any command: `nu gate.nu test -- mise run test` prints `PASS test 1.2s`, or
`FAIL test exit 3 log:.gates/test.log` followed by failure lines deduplicated with `×N` counts.
`--json` emits the same as a record. Full output stays in `.gates/<name>.log` for `rg` on demand.
Tested by `tools/gate_test.nu`. Ideas taken from rtk (failures only, collapsed passes) and
headroom (originals kept, retrieved on demand), built with mise and Nushell instead of a
dependency. It ships with the skill repo as the reference gate runner, not inside SKILL.md.

### Fail fast

- Warnings are errors, and each tool stops at its first failure. The gate cannot make a tool
  stop early, so the tool flags do it (for example `mix test --max-failures=1
  --warnings-as-errors`, `pytest -x`, `cargo clippy -- -D warnings`, `eslint --max-warnings 0`).
  `ci` runs gates in sequence and stops at the first red one.
- `gate.nu` shows one failure line by default (`--max 1`): one problem, one focused fix,
  small output.
- Three outcomes: `PASS`; `FAIL` (the check ran and found a problem); `ERROR` (the check never
  ran: exit 126/127, missing tool). An `ERROR` is fixed in the environment, not the code.

### Review budget

Reviewer context = window − loaded skills − instructions − room to read surrounding code and
write findings. Leads run with 200k–1M token windows, so the budget is set by the smallest
reviewer. `tools/size.nu` estimates diff tokens as bytes / 4 and fails when the diff exceeds
`REVIEW_WINDOW × REVIEW_SHARE` (defaults 200000 × 0.1 = 20000 tokens; a proposed policy to
tune by experiment, not a measured threshold). A diff over budget is split into smaller issues.

### Proportional review

The same review for a one-line change and a 1,000-line change wastes tokens. `tools/size.nu`
now names a review tier per diff: `gates` (≤ 500 tokens, passing gates are the review),
`light` (≤ 4,000, one reviewer, diff only, low effort), `full` (larger, or any file matching
the project's `REVIEW_RISK_PATHS`), `split` (over budget, not reviewed). Thresholds are starting
points to tune by experiment; risk paths are project rules and belong in `mise.toml` env.

## Build rule (11)

Kept in core because models do not default to these opinions: MVP first and change on
breakage or request; name the trade-off; micro-VM / Wasm runtime order (Wasm/WASI, Cloud
Hypervisor, Firecracker, then bare containers); no Kubernetes by default; token cost only.

Left out on purpose: the per-language tax list (Rust compile time, Node long-run memory,
Go repetition, Elixir distribution, Zig, Python). Models know these; core only requires the
trade-off be stated. Language detail comes from provider or language skills when a task needs it.

## Modes and merges

- Two modes share one tracker. Interactive: a human co-develops and the session ends by filing
  issues (spirit of https://github.com/mattpocock/skills: grill, to-spec, to-tickets, handoff).
  Autonomous: agents work issues and ask only through `BLOCKED`.
- Agents merge feature work into the integration branch once gates and review pass. Humans gate
  only production (`dev`→`main`, or `main` in low-risk repos), unless the operator enables auto-merge.

## Handoff (2026-10-07, end of session)

Resume from this section and the open issues on vinnie357/skills. Do not replay the session.

**Decisions since the grilling table below:**
- Trunk-based: `main` always current; every green `main` releases. Only a major waits for the user. High-risk or interactive work may use its own branch.
- Versions: every PR bumps `version` in `plugin.json` and `marketplace.json` (claude-skills practice); `test:version-bumps` enforces; release tags that version (#11). This replaces #25's commit-type computation; keep #25's major hold.
- The skill ships `core/SKILL.md` plus `core/tasks/` (Nushell mise file tasks). `install.sh` links them to `~/.config/mise/tasks/core/`, so projects run `mise run core:find`, `core:env`, `core:gate`, `core:ci-time` (#28, #29). Tasks wrap asdb, jev-select, altana, awman with fallbacks; the skill names only the tasks. Replaces `scripts/skills.nu` (clashed with `mise skills` and `npx skills`).
- Gates: cheapest first, parallel where independent, stop on first failure (#4). Cost is tokens and CI minutes.
- Branches `<type>/<issue>-<slug>`; squash merges; commit as the owner; no attribution in commits, PRs or comments (`authors` gate, #23). The GitHub tooling appends a footer to every new PR or comment: edit it out after creating.
- Prose, not gates, for repo setup, branch naming, pinned merges (distilled `git` skill, #17).
- Compaction: avoid it. State lives in the tracker and worktree list; end and resume fresh.

**Open PRs on vinnie357/skills (target `main`):** #22 scratch, #23 authors, #21 budget, #20 env, #19 find, #15 install.sh (`feat!`). #25 release policy needs rework under #11 first. Each PR needs a manifest version bump once #11 lands. Review each sized to its diff; resolve `tests/run.nu` conflicts with a merge from `main`.

**Open issues:** #3 issue template, #4 gate runner and stages, #5 sync core to this draft, #10 test-path gate, #11 manifest versions, #12 env model line, #13 agy probe, #14 old vs new experiment, #17 always-on bundle, #27 port claude-skills validation, #28 core mise tasks, #29 core:ci-time, #18 distill all 108 (blocked on complete core), #30 distill-skill (blocked on #18).

**User actions in GitHub UI:** delete the `dev` branch; repo settings (squash only, PR title as message, delete head branches, protect `main`); cloud environment setup script sets git `user.name`/`user.email`; optional `gh release edit v0.1.0 --target main`.

**Open ideas:** mise `packslip:` as distribution (check whether a skill-only release is valid at packslip.dev); managed-agents notes (credential isolation wording, lead list as append-only log, lazy hands). Core draft is ~790 words: trim target.

## Decisions (grilling, 2026-10-07)

| Area | Decision |
|---|---|
| Home | `vinnie357/skills`; claude-skills stays untouched; install one core, never both |
| Name | skill `core`; namespace `vinnie357` only in install paths (`~/.local/share/vinnie357/`) |
| Contents | `core/SKILL.md` plus `core/scripts/`; ~612+ words for now |
| Tools required | git, mise, Nushell to run gates; install needs only `sh`, `curl`, `git` |
| Warnings | always fixed; cleanup is one tracker issue, slices ephemeral |
| System of record | inferred from the task source, else ask once; one line in `AGENTS.md` |
| Item loop | test author → implementer (never edits tests) → local CI → remote CI → one sized review → merge |
| Models | role and capability tier from existing harness config; low effort for work, high for review, larger model only for risk |
| Escalation | 2 failures promote one tier, at most twice, then `BLOCKED` |
| Dropped from agent-loop | six tiers, five-stage pipeline, multiple reviewers, forced decomposition, unavailability fallback |
| Merge | agents merge into integration branch; production waits for a human or `auto-merge`; `main` only for now |
| Distribution | standard skill folder; POSIX `install.sh` via `curl | sh`, tag resolved to commit and locked, moved tags refused; plugin is a thin wrapper whose version release writes; no Node |
| Harness paths | `~/.claude/skills`, `~/.agents/skills`, `~/.config/opencode/skills`, `~/.gemini/config/skills`, `~/.gemini/antigravity-cli/skills` (agy, per docs; probe records version) |
| Ownership | installer owns only links into `~/.local/share/vinnie357/`; anything else is reported, never overwritten |
| Activation | one plain line per harness user file, exact match, never duplicated |
| Experiment | Claude cloud sessions after the build; old core as published plugin vs `core` via `install.sh`; same model and prompt; no push |
| Logs | per-run, untracked, deleted with the worktree; logs and large files read with filters only |
| Dropped | comment-ratio gate, HTML markers, deprecating claude-skills core, skills.sh in docs |

Open from the managed-agents article: credential isolation stated structurally in rule 9; the lead's list as an append-only event log; lazy hands (provision a worktree or sandbox only when a brief runs code).

## Three layers of tracking

1. Persistent (tracker): epics and issues with global ids.
2. Lead (ephemeral, per worktree): the lead's breakdown, or a pre-decomposed list it received.
   Items are named `<issue>.<n>` after the parent, so two worktrees never mint colliding numbers.
3. Worker (a brief): one item handed to a worker with goal, files in scope, done-when, gate
   command, skill paths and budget. A curated world: everything the task needs, nothing else.
   The worker validates with the same baby gates as the lead and returns the diff and one line.

Output discipline: no justification prose and no comments restating code. Ten comment lines on a
one-line change cost tokens now and on every later read. Candidate gate: flag diffs whose added
comment lines outnumber added code lines.

## Two levels of tracking (superseded by three layers above)

- Persistent (GitHub Issues or Linear): epics and issues, decisions, `BLOCKED` asks, report
  lines, and merge authority. A user grants auto-merge by labelling an issue or its epic
  `auto-merge`; an issue inherits from its epic. No label: stop before production.
- Ephemeral (per worktree): the lead's breakdown of one issue into steps, kept in the worktree
  with bees or a plain file. It survives compaction and harness restarts, unlike harness task
  tools, and is never committed (the `.bees/issues.jsonl` disclosure incident is why). At merge
  the worktree goes and the issue keeps one `DONE` line.

## Use what is present

Not every setup can sandbox, and each harness has its own concepts. `skills env` (vinnie357/skills#6)
prints one line per capability present (harness, mode, sandbox, tracker, find tier, work list,
output filter, gates) and nothing for what is absent. Leads run it once; interactive pairs use it
to see what the session can do. Rules name capabilities, not tools, so absent tools cost no tokens.

## Containment, not prompts

Where a sandbox exists, autonomous loops run with harness permissions skipped and safety comes from the boundary, not
from per-action prompts or harness classifiers (Claude auto mode, Codex approvals), which
differ per harness and change often:

- Sandbox: awman (container plus worktree per agent) and altana's `awman` executor (Apple
  Container micro-VM, declared env only, `op://` secrets resolved by reference).
- Exit: a push is the only way out. Branch protection and required checks on the remote enforce
  the merge rules and the `auto-merge` label, so an agent that ignores rule 5 still cannot merge
  to production.
- Always-risky actions (production merge, history rewrite, secret reads, remote deletes,
  gate or risk-config changes) are blocked by the sandbox or the remote, not by asking the agent.

altana already supplies parts of the loop: `goal` with a crew runs an issue to completion,
`council` fans a review out to several harnesses, results are structured JSON. Gap: `altana
stats` reports tokens as `n/a`, and rule 11 measures cost in tokens.

## Distill, don't import

Public skills are often verbose or produce verbose output. When one cannot be used as-is, take
its spirit into one line and link the source, as was done for restraint. Depend on files, git,
mise and the tracker; treat harness-specific features (invocation flags, hooks, agent formats)
as optional because they change often.

## Agents

None in core. All three harnesses spawn general subagents from a prompt; rule 5 needs only a
fresh context, which any subagent provides. Agent definitions are harness-specific and stay out.

## Manifesto content sources

| Source | Kept as |
|---|---|
| Fail forward | dev always current; main semver-released per merge; low-risk repos target main; fix forward, never rewrite history |
| Core loops (agent-loop, git) | issue → worktree → focused workers → three merge guards → operator merge |
| Modern App Manifesto | V errors carry a path forward (gates emit the failure, not the log); VII bounded merge authority; VIII idempotent, resumable tasks; IX evidence on demand; X secrets out of reach; XI budgets per worker; XII verify outcomes |
| tdd, anti-fabrication, restraint | one line each |

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
