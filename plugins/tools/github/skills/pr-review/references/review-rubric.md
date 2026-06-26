# Review Rubric and Verdict Format

What the per-PR reviewer checks, and the structured verdict it returns. The reviewer reads
`git diff main...<headRefName>` and verifies claims against the real source — it never edits
code and never merges.

## Rubric

Check each dimension against the diff and the surrounding code:

- **Correctness** — the change does what the PR says; edge cases and error paths are handled;
  no obvious logic inversion, off-by-one, or dropped result. For the diff's language, apply
  the loaded stack skill (idiomatic error handling, ownership, async safety, etc.).
- **Security** — no leaked secrets, no command injection, no unsafe deserialization, no
  loosened permissions. For Actions/supply-chain PRs, confirm every action is pinned to a
  full commit SHA (not a moving tag) and every image is pinned to a digest; verify the pin
  resolves to the claimed version.
- **Tests** — behavior changes carry tests; the diff does not delete or weaken coverage
  without cause; tests assert the new behavior, not a tautology.
- **No secrets** — corroborate with the repo's secret scanner (`mise run gitleaks` or
  equivalent) under the baseline-diff discipline.
- **Intent match** — the diff matches its title and description; no unrelated drive-by
  changes smuggled in; docs claims match the code they describe.
- **Scope and size** — the change is reviewable; unexpectedly large or cross-cutting diffs
  get called out for the operator.

## Findings

Report each finding as `file:line — <what and why>`, ordered by severity. Distinguish:

- **Blocking** — correctness or security defect, or a gate regression. Drives
  `request-changes`.
- **Non-blocking** — style, naming, a suggested simplification. Note it; does not block.

## Verdict format

```
PR #<n> REVIEW
- Verdict: approve | request-changes
- Baseline gates (main vs branch):
  <gate>: main=<PASS/FAIL> branch=<PASS/FAIL> -> regression | pre-existing | clean
- Gate evidence: <verbatim lines; pre-existing failures shown on both sides>
- Diff review findings:
  - <file:line — blocking — note>
  - <file:line — non-blocking — note>
  (or "none")
- Notes: <anything the operator needs to know before merge>
```

`approve` requires: every gate clean or pre-existing (no regression) AND no blocking finding.
Anything else is `request-changes`. The reviewer presents the verdict; the operator decides
the merge.
