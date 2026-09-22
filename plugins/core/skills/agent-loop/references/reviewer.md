# Reviewer evidence mechanism

Policy: ADR 0001 decision 4. This file covers how a reviewer obtains evidence and reports.

## Reviewers never execute

A reviewer never runs the test suite, a build, or `mise run ci` itself — not even when
its hands agent stalls. There is no fallback to self-execution; a verdict built on
self-run evidence is not a legitimate handback, whatever the result says. Every command
goes to execution hands on the smallest fast model. `dispatch-discipline.md` carries the
matching ban on a lead's spawn prompt offering an "or run it directly" escape hatch.

**Stall protocol.** If the hands agent stalls, the reviewer pings it once. If it still
does not report, the reviewer hands back its verdict with the CI evidence marked "not
obtained" — a legitimate handback — and the lead re-dispatches fresh hands for that
evidence.

## Judging inputs

Read-only inspection counts as judging, not execution: `Read`, `git show <oid>:<path>`,
`git diff a...b`, `gh pr view` / `gh pr diff` pinned to `headRefOid`. A reviewer does as
much of this directly as the task needs before reaching for execution hands. A reviewer
without shell tools judges artifacts its lead provides — a pinned diff and source snapshots,
each named with its path and oid. It confirms each snapshot's oid by reading
`<snapshot>/.git/HEAD` and comparing it with the stated oid; for the diff it relies on the
runner's `DIFF` line oids.

## With spawning

A reviewer that can spawn agents dispatches execution hands (see the researcher reference,
"Execution hands" section) with one bounded command per hand and the question that command answers.

When the target is a PR's own worktree (`/core:git` "Worktrees"), the hands run in the
foreground once `dispatch-discipline.md`'s "Worktree exclusivity during review" holds
(the writer stopped). The before/after tree-state check is the hands' own report
contract, not the reviewer's to perform — see `researcher.md` "Evidence files". The
reviewer's obligation is to refuse a hands report that lacks it, and to never let the
lead or a writer act on an in-progress draft — a verdict is only real once handed back
complete.

## Without spawning

A reviewer that cannot spawn agents returns verdict `WAIT` with an `evidenceRequests` list
of `{command, question}` pairs. The lead dispatches execution hands, then re-invokes the
reviewer once with the resulting records. A second request set escalates to the lead's
upstream rather than issuing a third round.

## Reading evidence

For hands running in a PR's own worktree, read the evidence files directly — the `.md`
record and, by line range, the `.log` — never the hands' reply (`researcher.md`
"Evidence files"). Wait for `status: complete` or `status: void`; a `status: running` or
`partial` record is not yet a result. `status: void` means the SHA or tree state changed
mid-run — treat it as missing evidence, not as a failure. A fabricated `started` or
`finished` field in that `.md` record is missing evidence, not a result to judge: a
placeholder such as `00:00:00Z`, a `finished` earlier than its `started`, or a time ahead
of now. Reject the record and ask the lead to re-dispatch the check.

For every other execution-hands record, validate before reading: `COMMAND` matches the
request, `REVISION` matches the target (the baseline oid for a baseline run), and `CWD`
and an integer `EXIT` are present. Set aside a record that fails any check and name it as
missing evidence. Then read `RESULT` and `EXCERPT`; open `LOG` by line range when a
finding needs more than `EXCERPT` carries — never the whole file.

## Output

Findings follow `/claude-code:claude-output-styles` `assets/review-findings-format.md`. The
durable verdict record follows the Gate 3 record layout in `/core:git` Gate 3. That record
quotes the `.md` record in full and, for the `.log` lines each finding cites, an excerpt
bounded the same way as `EXCERPT` above — at most 30 verbatim lines, each with its log line
number, never the whole log — because the evidence directory dies with the worktree; a
record carrying only paths is not durable.
