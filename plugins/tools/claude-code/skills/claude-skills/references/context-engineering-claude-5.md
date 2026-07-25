# Context engineering for Claude 5 generation models

Source: https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models
(Thariq Shihipar, Anthropic). Applies to Opus 5, Sonnet 5, and Fable 5.

Anthropic reports removing **over 80% of Claude Code's system prompt** for Opus 5 and Fable 5
with no measurable loss of quality. The five practices below are what replaced it.

## 1. Judgment over rules

Prefer contextual guidance to explicit prohibition lists. "Write code that reads like the
surrounding code" outperforms "never write multi-line docstrings" — the model infers the
specific rule from the general one, and the general one covers cases the list would miss.

Applies to: style guidance, best-practice bullets, do/don't tables.

## 2. Tool design over examples

> "giving examples actually constrains them to a certain exploration space"

Invest in parameter and enum design rather than walkthrough examples. A field table with valid
values teaches more than a worked example, and does not narrow the model's approach to the one
path the example took.

Keep an example only when it carries information no schema can: a non-obvious composition, or
a gotcha. Delete examples that merely restate a field table in annotated form.

## 3. Progressive disclosure over upfront loading

> a skill or CLAUDE.md should be "a tree that loads context at the right time, not a central
> repository"

Spend tokens on gotchas, not on patterns the model can observe directly in the code or in a
tool schema. A body that summarises each of its own references — then links to them — pays for
that content on every activation and again on the drill-down.

In this repo, `/claude-code:claude-teams` (96 lines, 4 references) is the shape to imitate;
`/claude-code:claude-workflows` (114 lines, 3 references) is the second example. A body that
promises a reference which does not exist is worse than a long body: the detail is advertised
and unavailable.

## 4. Single statements over repetition

State a rule once, where the thing it governs is defined. The article's example: put usage
instructions in the tool description rather than restating them in the system prompt.

The repo-level corollary: a number asserted in prose drifts from the number enforced in code.
Cite the enforcing constant instead of restating its value.

## 5. Prefer code and schema over prose specs

> "a HTML mockup of a design will generally produce better results than a description"

Where a format can be shown as a schema, a table, or runnable code, prefer that to prose.

## The boundary — this repo's own conclusion, not the article's

The article describes tuning a **product system prompt**. Rule 1 does not extend to rules that
something else depends on:

- **Rules a validator enforces.** Softening "skills never use `allowed-tools`" into guidance
  breaks the check in `test/validate-plugin.nu` that assumes the rule holds.
- **Facts a model will otherwise invent.** Valid hook event names, required frontmatter keys,
  and enum values are not style. Softened, they get fabricated.
- **Standing disciplines, which must be pushed rather than pulled.** A skill's `Use when`
  description is a pull mechanism: the model decides it applies. That fails for a discipline
  whose absence is the trigger condition. `/core:tdd` reads "Use when writing code test-first"
  — it presupposes the test-first intent the skill exists to instill, so the agent that most
  needs it is the one whose framing will not match. `/core:twelve-factor` names microservices
  and Kubernetes while the everyday demand is env-var config discipline. Both under-fire under
  description-driven activation, which is why they stay in the mandatory always-load set in
  `/core:agent-loop` "Core Skills (Mandatory)" rather than activating on demand.

Test for the boundary: if removing the prescription would break a check, permit a fabrication,
or rely on an agent recognising a need it does not yet have, keep it prescriptive.

## Related: the `/doctor` checkup

Verified against `github.com/anthropics/claude-code/CHANGELOG.md`:

- `claude doctor` (CLI, non-interactive) checks installation health only — settings, auth, MCP.
- In-session `/doctor` (alias `/checkup`) is a full setup checkup that can diagnose and fix
  issues, and includes a check that proposes trimming checked-in CLAUDE.md files by cutting
  content Claude could derive from the codebase — rule 3 applied to project instructions.
- The skill-description listing cap was raised from 250 to **1,536 characters**, with a startup
  warning when descriptions truncate. Note this repo's own validator enforces a stricter 1024.

Unverified: third-party claims that `/checkup` finds unused skills or duplicate CLAUDE.md
content do not appear in the primary changelog.
