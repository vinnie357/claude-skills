# Agent dispatch and delegation discipline

These rules apply to any leader (Tier 1 or Tier 2) authoring an Agent or Task spawn prompt.

## Model selection is explicit, never inherited

Every spawn prompt sets `model:` (or the equivalent `subagent_type` argument) explicitly to the harness-resolved model for the role's tier, per `SKILL.md` "Model overrides" and the model-tiers reference. Inheriting model from the parent's session wastes tokens — leads run on the deep-reasoning tier by default and inherit their model to smallest-fast-tier tasks if unconstrained.

## Use specialized subagent types

When the project ships specialized subagent types (`Explore`, `Plan`, `bees-manager`, `code-review-orchestrator`, etc.), spawn the specialized type rather than `general-purpose`. The specialized types carry tool allowlists and prompt scaffolding tuned to their role.

## Delegate search before you search

Leaders and the costly principals (Test Planner, Test Reviewer, Reviewer, Final Reviewer) do not run their own `Grep`/`Glob`/large-`Read` sweeps. They spawn focused read-only hands (smallest fast model, the `Explore` type) with a specific objective, consume the returned `file:line` index, and `Read` only the lines that index names. A fresh principal receives its index as a `## Starting index` block in its spawn prompt — it opens oriented, never blind. See `researcher.md` for the hands contract and `forge.md` for how hands pair with each role. Searching is a small-model job; an expensive model spending its context on `Grep` is the waste this rule removes. Principals do not search or run; reviewers obtain execution per the reviewer reference.

## Select model by capability, not by name

Match the model to the task's capability requirement, carried in config — never a hardcoded name. Text and code research run on the smallest fast model (`AGENT_LOOP_HANDS_MODEL`). Research that requires vision — images, screenshots, rendered web pages, visual PDFs, Playwright or visual MCP output — runs on a multimodal-capable model the harness offers (`AGENT_LOOP_HANDS_VISION_MODEL`). The available multimodal model shifts with the harness and model family, so the env var carries it. See `researcher.md`.

## Tier 1 leads delegate ALL execution

A Tier 1 lead runs zero direct work: no `Bash`, no `Edit`, no `Write`, no `Read` of source files. CI runs through a smallest-fast-tier validator. Fixes run through a general-tier or deep-reasoning-tier fix-agent. The lead's tool surface is `Read` (the lead's own loaded skills and the spec it is composing), bees state queries, the `Task`/`Agent` spawn tool, and the user-facing message channel.

## Tier 1 leads framing

The leader speaks of itself as "Tier 1" and spawned agents as Tier 2 (sub-lead), Tier 3 (worker), Tier 4 (validator), Tier 5 (fix-agent / reviewer). Spawned agents are NEVER called "team lead" — that term is reserved for Tier 1 to avoid recursive confusion in spawn prompts.

## Start in a fresh worktree off origin/main, explicitly

Every PR-opening spawn prompt's Step 0 is:

```bash
git fetch origin
git worktree add "$WORKTREE_ROOT/<repo>-<slug>" -b <branch> origin/main
```

`$WORKTREE_ROOT` and the location rules are `/core:git`'s "Worktrees" section — never
`/tmp`, `/private/tmp`, or a harness scratchpad. Without a fresh worktree off
`origin/main`, a spawned agent that instead `cd`s into the shared checkout inherits its
current branch — often a sibling PR's stale branch — and produces a PR that contains
both the new work and the sibling's diff. A second guarantee follows from the worktree
itself: no other agent's uncommitted or committed-but-unpushed work can leak into this
PR, because nothing else writes to this tree.

## Read-only agents never touch the shared repository or its worktrees

Reviewers, auditors, and research agents get this verbatim in their spawn prompt:

```
Never run git checkout, switch, restore, stash, reset, clean, rebase, merge,
pull, cherry-pick, apply, am, or branch -f/-D against the shared repository or
any of its worktrees, or any other command that changes HEAD, the index, or
tracked or untracked files. Refs are shared across every worktree of one
repository, so branch -D from any of them deletes the ref for everyone. To
inspect another ref: git show <ref>:<path>, git diff a...b, git ls-tree,
gh pr diff <number>. To obtain execution, request execution hands (see the
reviewer reference). Do not write under .git/ directly (config, hooks, refs);
git fetch and writing under .git/worktrees/<name>/evidence/ (see the
researcher reference) are the only sanctioned .git writes.
```

A per-issue worktree does not loosen this ban — "not my worktree" reads as license the
same way "not my working tree" once did, and the shared object database and refs mean a
write there still lands on everyone.

The catch-all clause matters as much as the names. A closed list recreates the failure it fixes one step over — an agent that reads literally enough to treat checkout-then-restore as net-zero will also read "rebase isn't on the list". `git clean -fd` is the worst omission a list can have: it destroys teammates' uncommitted work with no recovery, unlike the incident below, which was survivable.

`.git/` internals are not covered by "HEAD, the index, or tracked files" — `git status` never lists them — so the block adds two named carve-outs, not a general "writes under `.git` are fine": `git fetch`, and writing evidence records under `.git/worktrees/<name>/evidence/` (`researcher.md` "Evidence files"). The vector that earns the ban is `.git/hooks/*`: a hook written there executes on a teammate's next commit, which is mutation by proxy — an inert evidence-log directory is not that vector. Both carve-outs matter as much as the ban itself, since a flat "never write under `.git/`" would forbid `git fetch`, which reviewers legitimately need, and now the evidence files hands need too.

Name the commands. "No git state changes" is not enough — an agent given that wording checked out a PR branch, restored main afterward, and read the round trip as net-zero. Three other agents were writing to that tree at the time; all three had their work silently moved onto the wrong branch. It was recoverable only because the branch happened to sit at the same commit and the reviewer disclosed the checkout in its report.

A destructive scenario runs through execution hands in their own scratchpad clone, never through the reviewer directly: the reviewer requests the check, the hands execute it and report the record, and the reviewer judges the record. The clone gives the hands full freedom to break things with zero risk to in-flight work, and the reviewer stays read-only throughout. Execution hands using this pattern have demonstrated exploits — deleting a file's operative content, injecting malformed fences, adding synthetic skills — that a read-only pass would have missed entirely.

## No timed polling loops in workers

Spawned agents do not sustain timed polling loops or background any command. The `Monitor` tool is restricted; `sleep` longer than a few seconds is blocked. Polling work decomposes into one-shot snapshot agents the lead re-spawns at intervals OR external orchestration that pings on event.

**Post-hand-back sweep.** After EVERY hand-back — not only before dispatching a writer — the lead runs `pgrep -fl -- <worktree path>` against the worktree. Verified on macOS; on Linux procps-ng, `-l` prints the process name rather than argv, so use `pgrep -fa` there for the full command line instead — documented, not tested in the originating session. `pgrep` returns a PID and its argv (or name) only, not provenance, so the lead does not kill on sight: it kills a PID matching a command it dispatched, and investigates one it does not recognize (parent PID, start time) before acting, since a wrong kill can destroy another agent's in-flight work. Two further caveats, both verified in the originating session: the harness blocks a bare long `sleep` (`sleep 25` is refused), which is why this rule once read as sufficient, but that block does not reach an `until <check>; do sleep 2; done` loop or a backgrounded command (`&`, `nohup`, a background-run flag) — the shape that survived hand-back. And `pgrep -f` matches argv, so a process whose cwd is the worktree but whose argv never names it does not appear.

## Verify tool state via host inspection, not agent perception

Before claiming "tool X is missing on host Y", the lead spawns a snapshot agent that runs `which <tool>` / `ls /path/to/<tool>` / equivalent ON THE HOST and reports the literal command output. Agent perception ("I do not see tool X in the prompt context") is not evidence of absence; it usually means the agent's PATH or env differs from the host's actual install.

## Search prior decision records before proposing architecture

Before any architectural proposal, search the project's decision-records directory (`architecture/decisions/`, `docs/adrs/`, etc.) for prior coverage. Inventing a design that contradicts an existing ADR wastes review cycles; extending or amending an existing ADR is the correct path.

## Worktree exclusivity during review

Once an issue's writer and its reviewer share one worktree (`/core:git` "Worktrees" —
one worktree per issue or PR, reused across rounds), the lead is the enforcer of who may
touch it and when. This closed a real collision: a reviewer's execution hands ran `mise
run ci` in a PR's worktree while the lead resumed the writer in that same tree; the
writer committed mid-run and the reviewer's result was void.

1. A reviewer's execution hands run builds or CI in the worktree only while the writer
   is stopped. The lead enforces this exclusivity — it is not the reviewer's or the
   writer's to negotiate.
2. The hands — not the reviewer — check before and after the run: `git rev-parse HEAD`
   equals the reviewed SHA and `git status --short` is empty. Either check failing
   marks the run void; this is the hands' own report contract, in `researcher.md`
   "Evidence files".
3. Never resume or dispatch a writer into a worktree while a reviewer or its hands is
   still running there. Stop them first and run the post-hand-back sweep above (`pgrep
   -fl -- <worktree path>`) to confirm no build/test process still references the
   worktree.
4. Never act on a reviewer's in-progress draft; wait for its handback (see
   `reviewer.md`).
5. A detached per-review worktree (`git worktree add --detach <root>/<repo>-review-<sha7>
   <sha>`) was considered and rejected: full isolation, but every review pays a cold
   build. Reuse the writer's worktree under clauses 1-4 instead.

A reviewer's spawn prompt must never offer an escape hatch to self-execution — never
phrase it as "delegate to hands, or run it directly if they stall." There is no
fallback to the reviewer running a command itself, ever; see `reviewer.md` "Reviewers
never execute" for the reviewer's own stall protocol.
