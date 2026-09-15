# Reviewer evidence mechanism

Policy: ADR 0001 decision 4. This file covers how a reviewer obtains evidence and reports.

## Judging inputs

Read-only inspection counts as judging, not execution: `Read`, `git show <oid>:<path>`,
`git diff a...b`, `gh pr view` / `gh pr diff` pinned to `headRefOid`. A reviewer does as
much of this directly as the task needs before reaching for execution hands. A reviewer
without shell tools judges artifacts its lead provides — a pinned diff and source snapshots,
each named with its path and oid — and confirms each oid before reading.

## With spawning

A reviewer that can spawn agents dispatches execution hands (see the researcher reference,
"Execution hands" section) with one bounded command per hand and the question that command answers.

## Without spawning

A reviewer that cannot spawn agents returns verdict `WAIT` with an `evidenceRequests` list
of `{command, question}` pairs. The lead dispatches execution hands, then re-invokes the
reviewer once with the resulting records. A second request set escalates to the lead's
upstream rather than issuing a third round.

## Reading evidence

Validate each execution-hands record before reading it: `COMMAND` matches the request,
`REVISION` matches the target (the baseline oid for a baseline run), and `CWD` and an integer
`EXIT` are present. Set aside a record that fails any check and name it as missing evidence.
Then read `RESULT` and `EXCERPT`; open `LOG` by line range when a finding needs more than
`EXCERPT` carries — never the whole file.

## Output

Findings follow `/claude-code:claude-output-styles` `assets/review-findings-format.md`. The
durable verdict record follows the Gate 3 record layout in `/core:git` Gate 3.
