# Agent dispatch and delegation discipline

These rules apply to any leader (Tier 1 or Tier 2) authoring an Agent or Task spawn prompt.

## Model selection is explicit, never inherited

Every spawn prompt sets `model:` (or the equivalent `subagent_type` argument) explicitly to the harness-resolved model for the role's tier, per `SKILL.md` "Model overrides" and `references/model-tiers.md`. Inheriting model from the parent's session wastes tokens — leads run on the deep-reasoning tier by default and inherit their model to smallest-fast-tier tasks if unconstrained.

## Use specialized subagent types

When the project ships specialized subagent types (`Explore`, `Plan`, `bees-manager`, `code-review-orchestrator`, etc.), spawn the specialized type rather than `general-purpose`. The specialized types carry tool allowlists and prompt scaffolding tuned to their role.

## Delegate search before you search

Leaders and the costly principals (Test Planner, Test Reviewer, Reviewer, Final Reviewer) do not run their own `Grep`/`Glob`/large-`Read` sweeps. They spawn focused read-only hands (smallest fast model, the `Explore` type) with a specific objective, consume the returned `file:line` index, and `Read` only the lines that index names. A fresh principal receives its index as a `## Starting index` block in its spawn prompt — it opens oriented, never blind. See `researcher.md` for the hands contract and `forge.md` for how hands pair with each role. Searching is a small-model job; an expensive model spending its context on `Grep` is the waste this rule removes. Principals do not search or run; reviewers obtain execution per `references/reviewer.md`.

## Select model by capability, not by name

Match the model to the task's capability requirement, carried in config — never a hardcoded name. Text and code research run on the smallest fast model (`AGENT_LOOP_HANDS_MODEL`). Research that requires vision — images, screenshots, rendered web pages, visual PDFs, Playwright or visual MCP output — runs on a multimodal-capable model the harness offers (`AGENT_LOOP_HANDS_VISION_MODEL`). The available multimodal model shifts with the harness and model family, so the env var carries it. See `researcher.md`.

## Tier 1 leads delegate ALL execution

A Tier 1 lead runs zero direct work: no `Bash`, no `Edit`, no `Write`, no `Read` of source files. CI runs through a smallest-fast-tier validator. Fixes run through a general-tier or deep-reasoning-tier fix-agent. The lead's tool surface is `Read` (the lead's own loaded skills and the spec it is composing), bees state queries, the `Task`/`Agent` spawn tool, and the user-facing message channel.

## Tier 1 leads framing

The leader speaks of itself as "Tier 1" and spawned agents as Tier 2 (sub-lead), Tier 3 (worker), Tier 4 (validator), Tier 5 (fix-agent / reviewer). Spawned agents are NEVER called "team lead" — that term is reserved for Tier 1 to avoid recursive confusion in spawn prompts.

## Branch from fresh main, explicitly

Every PR-opening spawn prompt's Step 0 is:

```bash
git fetch origin main
git checkout origin/main
git checkout -b <branch>
```

Without this step, the spawned agent inherits the working tree's current branch — often a sibling PR's stale branch — and produces a PR that contains both the new work and the sibling's diff.

## Read-only agents never touch the shared working tree

Reviewers, auditors, and research agents get this verbatim in their spawn prompt:

```
Never run git checkout, switch, restore, stash, reset, clean, rebase, merge,
pull, cherry-pick, apply, am, or branch -f/-D against the shared working tree,
or any other command that changes HEAD, the index, or tracked or untracked
files. To inspect another ref: git show <ref>:<path>, git diff a...b,
git ls-tree. To obtain execution, request execution hands (references/reviewer.md).
Do not write under .git/ directly (config, hooks, refs); git fetch is the only
sanctioned .git write.
```

The catch-all clause matters as much as the names. A closed list recreates the failure it fixes one step over — an agent that reads literally enough to treat checkout-then-restore as net-zero will also read "rebase isn't on the list". `git clean -fd` is the worst omission a list can have: it destroys teammates' uncommitted work with no recovery, unlike the incident below, which was survivable.

`.git/` internals are not covered by "HEAD, the index, or tracked files" — `git status` never lists them — so the block adds: do not write under `.git/` directly (config, hooks, refs); `git fetch` is the only sanctioned `.git` write. The vector that earns the clause is `.git/hooks/*`: a hook written there executes on a teammate's next commit, which is mutation by proxy. The carve-out matters as much as the ban, since a flat "never write under `.git/`" would forbid `git fetch`, which reviewers legitimately need.

Name the commands. "No git state changes" is not enough — an agent given that wording checked out a PR branch, restored main afterward, and read the round trip as net-zero. Three other agents were writing to that tree at the time; all three had their work silently moved onto the wrong branch. It was recoverable only because the branch happened to sit at the same commit and the reviewer disclosed the checkout in its report.

A destructive scenario runs through execution hands in their own scratchpad clone, never through the reviewer directly: the reviewer requests the check, the hands execute it and report the record, and the reviewer judges the record. The clone gives the hands full freedom to break things with zero risk to in-flight work, and the reviewer stays read-only throughout. Execution hands using this pattern have demonstrated exploits — deleting a file's operative content, injecting malformed fences, adding synthetic skills — that a read-only pass would have missed entirely.

## No timed polling loops in workers

Spawned agents do not sustain timed polling loops. The `Monitor` tool is restricted; `sleep` longer than a few seconds is blocked. Polling work decomposes into one-shot snapshot agents the lead re-spawns at intervals OR external orchestration that pings on event.

## Verify tool state via host inspection, not agent perception

Before claiming "tool X is missing on host Y", the lead spawns a snapshot agent that runs `which <tool>` / `ls /path/to/<tool>` / equivalent ON THE HOST and reports the literal command output. Agent perception ("I do not see tool X in the prompt context") is not evidence of absence; it usually means the agent's PATH or env differs from the host's actual install.

## Search prior decision records before proposing architecture

Before any architectural proposal, search the project's decision-records directory (`architecture/decisions/`, `docs/adrs/`, etc.) for prior coverage. Inventing a design that contradicts an existing ADR wastes review cycles; extending or amending an existing ADR is the correct path.
