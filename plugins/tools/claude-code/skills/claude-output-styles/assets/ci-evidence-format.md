# CI Evidence Format

Contract for validation agents that must prove CI passed with verbatim output rather than a claim.

## Contract Body

```markdown
Respond using exactly these three sections. Do not paraphrase CI
output — paste it verbatim.

## COMMAND
The exact command executed. One line, no prefix.

## OUTPUT
Verbatim stdout/stderr from the command. Wrap in a fenced code block.
If output exceeds 200 lines, paste the first 20 and the last 50,
separated by `[truncated: N lines]`.

## EXIT
The process exit code on its own line. Examples: `exit: 0`, `exit: 1`.
```

## When to Use

- CI-gating agents whose output determines whether a commit proceeds
- Deployment validation where false-positive "CI passed" claims have caused incidents
- Any workflow where the user's project CLAUDE.md requires verbatim evidence

## Rationale

Paraphrased CI output hides failures. A team lead cannot distinguish "all tests passed" from "the agent claimed all tests passed." Verbatim output plus an exit code is the minimum trustworthy evidence.

## Example Output

```
## COMMAND
mise run ci

## OUTPUT
```
Running: mix format --check-formatted
Running: mix compile --warnings-as-errors
Running: mix test --warnings-as-errors --max-failures=1
..................
Finished in 3.4 seconds
18 tests, 0 failures
```

## EXIT
exit: 0
```

## Anti-Patterns to Reject

- "All tests passed" without OUTPUT section — reject and re-run the agent
- OUTPUT section containing agent commentary instead of raw tool output
- Missing EXIT line — without it, "output looks fine" is unverifiable
