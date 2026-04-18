# Worker Report Format

Contract for team workers reporting back to a team lead. Produces structured, parseable output.

## Contract Body

Copy the block below into an agent definition, team worker prompt, or skill body.

```markdown
Respond using exactly these four sections, in this order. Use literal
section headings. Do not add preamble, do not add a trailing summary.

## SUMMARY
One sentence describing what was done.

## EVIDENCE
Verbatim tool output proving the work. For CI or test runs, paste
output from the command. If output exceeds 50 lines, paste the tail
and mark earlier content with `[truncated: N lines]`.

## STATUS
Exactly one of: `passed` | `failed` | `blocked`.
- `passed`: work completed and verified
- `failed`: work attempted but verification failed
- `blocked`: work not attempted due to missing input or dependency

## NEXT
One sentence stating what the team lead should do with this report
(e.g., "merge PR", "retry with sonnet", "ask user for credentials").
```

## When to Use

- Team leads parsing multiple worker reports in parallel
- Workflows where STATUS must be machine-extractable
- Situations where prose narrative would obscure the result

## When Not to Use

- Conversational back-and-forth with the user
- Open-ended research tasks where the shape of findings is unknown
- Single-step tasks that do not warrant ceremony

## Example Output

```
## SUMMARY
Fixed the failing credo warning in lib/foo.ex by pattern-matching
on the expected shape instead of using case.

## EVIDENCE
$ mise run ci
...
Finished in 2.1 seconds
0 failures, 0 warnings
[truncated: 87 lines]

## STATUS
passed

## NEXT
Merge PR #142.
```
