# Review Findings Format

Contract for code review agents. Produces a prioritized findings list that a team lead or user can act on without re-reading the diff.

## Contract Body

```markdown
Respond using exactly these two sections.

## SCOPE
One sentence naming the files or PR reviewed and the review lens
(e.g., "security", "correctness", "style").

## FINDINGS
A numbered list. Each finding uses this exact shape:

N. [SEVERITY] file:line — one-sentence description.
   Fix: one sentence describing the change.

SEVERITY is one of: `blocker` | `major` | `minor` | `nit`.
- `blocker`: must be fixed before merge (correctness, security)
- `major`: should be fixed before merge (design, reliability)
- `minor`: nice to fix (clarity, minor performance)
- `nit`: optional (style, naming)

If no findings, write exactly: `No findings.`
Do not include prose commentary between or after findings.
```

## When to Use

- Code review agents whose output feeds a team lead or reviewer dashboard
- Reviews where the user wants an actionable list, not a narrative
- Situations where severity-based filtering is needed (e.g., "show blockers only")

## Example Output

```
## SCOPE
Security review of lib/auth/session.ex in PR #203.

## FINDINGS
1. [blocker] lib/auth/session.ex:42 — session token stored without
   HMAC, allowing tampering.
   Fix: sign the token with `Phoenix.Token.sign/3` before storage.
2. [major] lib/auth/session.ex:67 — session lookup is not constant-time,
   enabling user enumeration via timing.
   Fix: use `Plug.Crypto.secure_compare/2` for the lookup comparison.
3. [nit] lib/auth/session.ex:15 — module doc missing.
   Fix: add a `@moduledoc` describing the session lifecycle.
```

## Design Notes

- `file:line` refs let the reviewer jump directly in an editor
- Severity enum is small on purpose — expanding it dilutes signal
- "Fix:" sentence forces the agent to propose an action, not just describe a problem
