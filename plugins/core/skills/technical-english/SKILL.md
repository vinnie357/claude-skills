---
name: technical-english
description: Controlled-language rules for technical writing in two registers — strict mode for procedural text and flavored mode for explanatory prose. Strict mode covers skill descriptions, procedure steps, agent definitions, output contracts, error text, and issue acceptance criteria. Flavored mode covers references, READMEs, ADR rationale, and PR bodies. Use when authoring or editing a SKILL.md, a skill description, an agent definition, a bees issue, an ADR, or a README. Use when reviewing prose for passive voice, hedged directives, terms used with two meanings, or overlong sentences.
license: MIT
---

# Technical English

Technical English is a controlled-language discipline for procedural and explanatory writing. It sets one strict register for instructions and a second, looser register for context and rationale.

## Two registers

Pick the register from the artifact, not from taste.

| Artifact | Register | Why |
|---|---|---|
| Skill descriptions | Strict | Claude parses these at load; ambiguity misfires activation |
| Procedure steps | Strict | A step is an instruction, not a discussion |
| Agent definitions | Strict | Dispatch logic runs unattended; one meaning per term |
| Slash commands | Strict | Arguments and flags need exact, repeatable wording |
| Output contracts | Strict | A caller parses a worker's report by its shape |
| Error and CI-failure text | Strict | A reader hits this under time pressure |
| Bees titles and acceptance criteria | Strict | Criteria must be checkable, not interpreted |
| Commit subjects | Strict | One line, one fact, searchable history |
| ADR Decision lines | Strict | The decision is the artifact; hedging voids it |
| SKILL.md explanatory sections | Flavored | Context needs nuance and connecting prose |
| `references/*.md` | Flavored | Depth material rewards variety and color |
| READMEs | Flavored | A README sells the project before it instructs |
| ADR Context and Consequences | Flavored | Trade-offs need qualification, not a checklist |
| PR bodies | Flavored | A reviewer wants the story, not a manual |

## The strict rule set

1. Give every term exactly one meaning and one part of speech, and hold that meaning across the whole document set.
2. Write every instruction and every procedure step in active voice.
3. Reserve passive voice for description, and only when no one knows the actor.
4. Use five tenses only: imperative, simple present, simple past, simple future, infinitive.
5. Put one instruction in each sentence.
6. Cap procedure sentences at 20 words and description sentences at 25.
7. Cap each paragraph at 6 sentences and one topic.
8. Never drop an article, a subject, or a verb.
9. State a warning, a caution, or a precondition before the step it governs.
10. Choose the short word, the concrete noun, and the verb over its noun form.
11. Cut a qualifier or an adverb that only restates its verb.
12. Reread the draft once, and cut what the first pass missed.

Worked before/after pairs for eleven of the twelve, several pulled from this repo's own text: [references/strict-mode-rules.md](references/strict-mode-rules.md).

## Word choice

Pick the plainest available word, and use it the same way every time. The pairs below recur in this repo; the plain form wins in strict-mode text.

Substitute only where the plain word carries the same meaning. A term of art stays: `implement` names a tier and a Behaviour relationship here, and `ensure` states a guarantee that `confirm` (a verification) does not.

| Wordy | Plain |
|---|---|
| leverage | use |
| perform | do |
| additional | more |
| functionality | feature |
| modify | change |
| currently | now |

## Hedges vs directives

A directive states what to do. A hedge states an unconfirmed claim. Mixing the two inside a procedure buries the actual instruction under a guess.

- A step is a directive: `Run mise run ci.` Never `You might want to run mise run ci.`
- Keep a hedge only where the evidence is thin, and name the gap: "requires verification" carries more information than "may work."
- `/core:anti-fabrication` sets the canonical rule for uncertainty markers, banned superlatives, and evidence-based claims. Follow that skill directly; this section is a pointer, not a restatement.

## Warnings precede the step

State a warning, a caution, or a precondition before the step it governs, never after. A reader who executes line by line has already acted by the time a trailing warning arrives. `plugins/core/skills/security/SKILL.md:45` states its warning immediately before the command table it governs — copy that placement.

## Where this binds

| Context | Binds to |
|---|---|
| Main-loop conversation | The active output style — `core` ships **Plain Technical**, opt-in |
| Subagent prompts and reports | This skill plus the response contract |
| Authored artifacts (skills, ADRs, READMEs) | This skill plus review |
| CI | Vale, via `mise run test:prose` |

Select the shipped style with `/config` → Output style → **Plain Technical**, or set `"outputStyle": "Plain Technical"` in `.claude/settings.local.json`. It takes effect after `/clear` or in a new session. It is never forced on you: it does not override a style you already chose. The style ships with the `core` plugin and with `all-skills`; a plugin that vendors this skill alone does not carry it.

## What CI checks and what it cannot

Vale runs as `mise run test:prose`, inside `mise run test`. It checks banned superlatives, clutter phrases, weak qualifiers, hedged directives, sentence length, and nominalizations. Rule files live in `styles/Strict/` and `styles/Flavored/`; `.vale.ini` picks the register by path. See `/vale:vale` for the tool itself — extension points, scopes, alert levels, and how to author a rule.

A rule reports at `warning` while its findings burn down, then moves to `error` once it reaches zero. Clutter gates today; the rest report. Burn-down is claude-skills-307.

Sentence length skips code. Headings, table rows, and list items all count, because a reader parses each of them the same way.

Two things stay a review-time judgment call whatever the tooling does. Vale cannot tell whether a sentence carries exactly one instruction. It cannot tell whether a paragraph needed to exist. Both belong to review.

## Anti-fabrication

This skill inherits `/core:anti-fabrication` in full. Every claim about a tool's behavior, a file's content, or a test's result needs tool verification before it reaches a document. Mark an unverified claim as unverified; never round a guess up to a fact. See `/core:anti-fabrication` for the complete rule set and its worked examples.

## References

- [references/strict-mode-rules.md](references/strict-mode-rules.md) — each of the 12 rules with a before/after pair, several drawn from real lines in this repo.
- [references/flavored-prose.md](references/flavored-prose.md) — Zinsser's four principles restated for this repo, the clutter/qualifier guidance, the rewriting loop, and why strict mode gives up Humanity.
- [references/repo-glossary.md](references/repo-glossary.md) — the one-term-one-meaning list for this repo's own vocabulary.
- [references/attribution.md](references/attribution.md) — sourcing and copyright for the material this skill draws on.
