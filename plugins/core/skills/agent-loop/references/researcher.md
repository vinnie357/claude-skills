# Research hands (the hands pattern)

There are two kinds of hands. **Research hands** are read-only agents any principal spawns to do
its searching, indexing, and knowledge-gathering — the main contract of this file. **Execution
hands** run one bounded command in a scratchpad clone and report evidence; see "Execution hands"
below.

Research hands run on the smallest fast model; the principal stays on the expensive model and
spends its context on judgment, not on `Grep`/`Glob`/large `Read` sweeps. Hands gather; the
principal decides.

This is the Forge mechanism for "planners and reviewers do not search." A principal is *handed* the
relevant `file:line` pointers instead of discovering them. See `forge.md` for how hands pair with
each principal role, and `dispatch-discipline.md` for the delegate-search-before-you-search rule.

## Two invocation modes

1. **Startup / onboarding.** A lead runs a hands pass *before* spawning a fresh principal, then
   embeds the resulting index in the principal's spawn prompt under a `## Starting index` section.
   The principal opens already-oriented — it reads the pointers and starts judging immediately.
2. **On-demand.** A working principal spawns new focused hands for a follow-up objective it
   discovers mid-task. Follow-ups default to *new* hands (fresh context, one objective each, per
   the no-SendMessage-continuation rule). Continue the same hands via `SendMessage` only for a
   tightly-related follow-up where the harness supports it.

Spawn as many focused hands as the job needs. One hands agent answers one specific objective.

## Spawn contract

The caller gives hands a *specific* objective, not "go understand the repo":

- Bad: "research the codebase."
- Good: "find where `serialize_workflow/1` is defined and every caller; report the definition and
  each call site."

## Output contract — an index, not a narrative

Hands return a structured index: a list of `{file, lines, why}` pointers plus a short excerpt
(≤ ~15 lines) per pointer. Never whole-file dumps. Never prose that drops the `file:line`
provenance. The principal `Read`s only the lines the index names.

```json
[
  { "file": "lib/runex/workflows.ex", "lines": "28-34",
    "why": "serialize_workflow/1 — reuse for the import path",
    "excerpt": "def serialize_workflow(%Workflow{} = w) do ... end" },
  { "file": "docs/adrs/0007-bundle-import.md", "lines": "12-19",
    "why": "prior decision: imports are multipart, not JSON",
    "excerpt": "We accept tar.gz multipart uploads at POST /api/bundles/import ..." }
]
```

## Model selection — by capability, set by config

- **Text / code research** runs on the smallest fast model — the `Explore` subagent type — via
  `AGENT_LOOP_HANDS_MODEL`.
- **Vision-requiring research** runs on a multimodal-capable model the current harness offers, via
  `AGENT_LOOP_HANDS_VISION_MODEL`. The trigger is the *artifact type*, decided when the principal
  spawns the hands: images, screenshots, rendered web pages, visual PDFs, or Playwright / visual
  MCP output.

Select by capability, never by a hardcoded name. The available multimodal model shifts with the
harness and the model family; the env var carries it (12-factor config), the same way the
`AGENT_LOOP_*_MODEL` tier vars do. An empty-string value falls through to the default.

## Tool surface (research hands)

Read-only. Text hands: `Read`, `Grep`, `Glob` (and `Bash` for `which` / `ls` host inspection).
Vision hands add the harness's visual tools — `WebFetch`, the Playwright MCP, or an image-capable
reader. Research hands never `Edit`, `Write`, or commit.

## Forbidden (research hands)

- No design decisions, architecture recommendations, or test/implementation choices.
- No code, no edits, no commits.
- No whole-file dumps and no provenance-free summaries — the index is the deliverable.

## Execution hands

Execution hands run exactly one bounded command per record and report evidence — they never
research, judge, or fix.

**Tool surface**: research hands' surface plus `Bash`, for the one command being run.

**Skills first**: an execution hand loads the task's skills before running its command, same as
any other spawned agent.

**In a PR's worktree, execution hands are writers by execution.** Running `mise run ci`
or a build there needs the writer stopped first, per `dispatch-discipline.md`'s
"Worktree exclusivity during review" — the hands run in the foreground only once that
exclusivity holds.

### Evidence files (worktree review)

Evidence for a hands run inside a PR's own worktree lives on disk, so the record does
not depend on the hands agent's reply surviving a stall or an idle timeout.

**Location** — the worktree's own git dir, never the scratchpad and never committed.
This mechanism applies only to hands running inside a PR's own worktree, never the
primary — that follows from "Worktree exclusivity during review" restricting review to a
PR's worktree in the first place:

```bash
$(git rev-parse --absolute-git-dir)/evidence/   # <repo>/.git/worktrees/<name>/evidence/
```

Run from the primary instead, `--absolute-git-dir` resolves to `<repo>/.git` — outside
this carve-out and never auto-removed. Treat a hands run that resolves there as a
dispatch error, not a valid evidence location.

This sits outside the working tree, so writing here leaves `git status --short` empty —
the clean-tree check in `dispatch-discipline.md` "Worktree exclusivity during review"
stays valid. The directory survives a reboot but not cleanup — `git worktree remove`
deletes it with the worktree, which is why nothing orphans, but also why a record citing
only a path under it stops being checkable once the PR's worktree is gone. This is
scratch storage for a review in flight, never the archive; a record quotes what it cites
before cleanup runs.

**Files, named by commit** — `<sha7>-<check>.log` is the raw output, exit code appended
(e.g. `mise run ci > <dir>/<sha7>-ci.log 2>&1; echo "exit: $?" >> <dir>/<sha7>-ci.log`);
`<sha7>-<check>.md` is the terse record.

**Protocol** — the hands agent first writes a stub `.md` with `status: running`, runs the
check with output redirected to the `.log`, then completes the `.md`. Its reply is one
line: the path and the status. A check that runs more than one command writes each exact
command into the `.log` immediately before that command's own capture, so `command:`
names the single command the check is invoked by, while the `.log` carries the full
sequence it ran.

**Record format** (`.md`, key: value, no prose):

```
sha:
tree_clean_before:
command:
started:              # date -u +%FT%TZ, run at that moment
exit:
finished:             # date -u +%FT%TZ, run at that moment
summary:             # the runner's final summary line, verbatim
failures:             # - <unit>: <n> <compile|runtime> - <one-clause reason>
sha_after:
tree_clean_after:
status:               # complete | partial | void
```

`status: void` means the SHA or tree changed during the run — the record itself catches
that. `status: partial` means the hands agent completed the stub and started the check
but did not finish it (a `.log` with no matching `exit:` line, or a run cut short); a
subsequent hands run overwrites it with `complete` or `void`. `status: complete` is the
only status a reviewer accepts as a finished result. Neither status catches a writer that
edits and reverts inside the run window, leaving both snapshots clean — that case is
caught only by clause 3's lead enforcement (never resume a writer while hands are
running), not by the record.

The reviewer reads the `.md` and `.log`, never the hands' reply — see `reviewer.md`
"Reading evidence". This is the contract for hands running inside a PR's own worktree
specifically; an execution hand running a one-off bounded command elsewhere (a
scratchpad clone, a non-review context) keeps using the generic contract in "Report"
below. The two coexist by context — neither replaces the other.

**Scratchpad clone only for destructive commands** — never the shared working tree or a
PR's worktree:

```
git clone <repo> "$SCRATCHPAD/repo"
git -C "$SCRATCHPAD/repo" remote remove origin
```

Removing `origin` is not optional. `git clone` from a local path sets origin to the shared repo,
so a push from the scratchpad writes refs back into it; a `cp -R` that carries `.git` keeps the
GitHub remote and pushes to the real one.

**Report**: for a hands run inside a PR's own worktree, the evidence-file record above
IS the report. Otherwise, one record per command, per `/claude-code:claude-output-styles`
`assets/ci-evidence-format.md` "Execution evidence".

**Forbidden**: never fixes, never judges, never posts to GitHub, never writes files other than its
own logs (the worktree evidence files above, or its scratchpad-clone logs), and never backgrounds a
command or starts a polling loop (`&`, `nohup`, a background-run flag) — a foreground instruction is
not satisfied by a loop that outlives the hand-back.

**Model selection**: per `SKILL.md` "Model overrides" (hands row).

## Worked examples

**Text/code (startup index for a planner).** Objective: "for issue repo-42, index the existing
HTTP controller, its router entry, and the serializer the new endpoint reuses." Hands return three
`{file, lines, why, excerpt}` pointers. The planner reads those ~40 lines, never the whole repo,
and writes its test list from them.

**Visual (on-demand for a reviewer).** A LiveView issue ships a screenshot of the expected layout.
The reviewer spawns vision hands (`AGENT_LOOP_HANDS_VISION_MODEL`) with the objective "describe the
header layout and the empty-state copy in this screenshot," then judges the implementation against
the returned description — without loading a multimodal model into its own review context.
