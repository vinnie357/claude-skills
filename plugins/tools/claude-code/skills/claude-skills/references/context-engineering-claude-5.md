# Context engineering for Claude 5 generation models

Source: https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models
(Thariq Shihipar, Anthropic). The article names Claude Opus 5 and Claude Fable 5; it is written for
the Claude 5 generation broadly.

Anthropic reports: "We removed over 80% of Claude Code's system prompt for models like Claude Opus 5
and Claude Fable 5 with no measurable loss on our coding evaluations."

The article describes six shifts. Five of them govern skill authoring and are covered below. The
remaining one — moving memory out of CLAUDE.md and into auto-memory — is product behaviour rather
than authoring guidance, so it is not covered here.

## 1. Judgment over rules

Prefer contextual guidance to explicit prohibition lists. The article contrasts an old-style rule,
"Never write multi-paragraph docstrings or multi-line comment blocks — one short line max," with
the guidance that replaced it: "Write code that reads like the surrounding code: match its comment
density, naming, and idiom." The general instruction covers cases the list would miss, and the model
infers the specific rule from it.

Applies to: style guidance, best-practice bullets, do/don't tables.

## 2. Tool design over examples

The article reports that "giving examples actually constrains them to a certain exploration space."

Invest in parameter and enum design rather than walkthrough examples. A field table with valid values
teaches more than a worked example, and does not narrow the model's approach to the one path the
example took.

Keep an example only when it carries information no schema can: a non-obvious composition, or a
gotcha. Delete examples that merely restate a field table in annotated form.

## 3. Progressive disclosure over upfront loading

The article's advice for CLAUDE.md is to "consider having a tree of files that can be loaded at the
right time." Our restatement of the contrast: a skill is that tree, not a central repository holding
everything at once.

It also advises keeping CLAUDE.md lightweight and spending most of the tokens on gotchas — not on
patterns the model can observe directly in the code or in a tool schema. A body that summarises each
of its own references, then links to them, pays for that content on every activation and again on
the drill-down.

In this repo, `/claude-code:claude-teams` (96 lines, 4 references) is the shape to imitate;
`/claude-code:claude-workflows` (114 lines, 3 references) is the second example. A body that promises
a reference which does not exist is worse than a long body: the detail is advertised and unavailable.

## 4. Single statements over repetition

State a rule once, where the thing it governs is defined. The article's example is to "put
instructions on how to use tools in the tool descriptions rather than the system prompt."

The repo-level corollary: a number asserted in prose drifts from the number enforced in code. Cite
the enforcing constant instead of restating its value.

## 5. Prefer code and schema over prose specs

The article observes that "a HTML mockup of a design will generally produce better results than a
description of the design or a screenshot."

Where a format can be shown as a schema, a table, or runnable code, prefer that to prose.

## The boundary — this repo's own conclusion, not the article's

The article describes tuning a **product system prompt**. Rule 1 does not extend to rules that
something else depends on:

- **Rules a validator enforces.** Softening "skills never use `allowed-tools`" into guidance breaks
  the check in `test/validate-plugin.nu` that assumes the rule holds.
- **Facts a model will otherwise invent.** Valid hook event names, required frontmatter keys, and
  enum values are not style. Softened, they get fabricated.
- **Standing disciplines, which must be pushed rather than pulled.** A skill's `Use when` description
  is a pull mechanism: the model decides it applies. That fails for a discipline whose absence is the
  trigger condition. `/core:tdd` reads "Use when writing code test-first" — it presupposes the
  test-first intent the skill exists to instill, so the agent that most needs it is the one whose
  framing will not match. `/core:twelve-factor` names microservices and Kubernetes while the everyday
  demand is env-var config discipline. Both under-fire under description-driven activation, which is
  why they stay in the mandatory always-load set in `/core:agent-loop` "Core Skills (Mandatory)"
  rather than activating on demand.
- **Quoted source material.** A verbatim blockquote attributed to an external source is not eligible
  for softening at all — altering a direct quotation is a fabrication risk in the opposite direction,
  regardless of how the other three clauses would score it. `/core:twelve-factor` SKILL.md's blockquote
  from 12factor.net (`plugins/core/skills/twelve-factor/SKILL.md:263`, "A twelve-factor app never
  relies on implicit existence of state on the filesystem...") is the worked example: paraphrasing it
  to read more naturally would misrepresent what the source actually says.

Test for the boundary: if removing the prescription would break a check, permit a fabrication,
misrepresent quoted source material, or rely on an agent recognising a need it does not yet have,
keep it prescriptive.

## Related: the `/doctor` checkup

Verified verbatim against `github.com/anthropics/claude-code/CHANGELOG.md`:

- "`/doctor` is now a full setup checkup that can diagnose and fix issues; `/checkup` is its alias"
- "Added a `/doctor` check that proposes trimming checked-in `CLAUDE.md` files by cutting content
  Claude could derive from the codebase" — rule 3 applied to project instructions.
- "raised the listing cap from 250 to 1,536 characters and added a startup warning when descriptions
  are truncated". Note this repo's own validator enforces a stricter 1024-character cap on
  `description` (`test/validate-skills-quality.nu:389`).

Changelog entries show the non-interactive `claude doctor` CLI covering installation, settings, auth,
and MCP diagnostics. No changelog line states that scope is exhaustive.

Unverified: third-party claims that `/checkup` finds unused skills or duplicate CLAUDE.md content do
not appear in the primary changelog.
