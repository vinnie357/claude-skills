---
name: claude-skills
description: Guide for creating Agent Skills with progressive disclosure and best practices. Use when creating new skills, understanding skill structure, or implementing progressive disclosure.
---

# Agent Skills

Guide for creating modular, self-contained Agent Skills that extend Claude's capabilities with specialized knowledge.

## How skills load

A skill is a directory of instructions and resources that Claude discovers and loads on demand. Loading happens in tiers, and the tier a fact lands in decides whether Claude ever sees it:

- **Level 1 — discovery.** Only the `name` and `description` reach the system prompt. Claude decides relevance from these alone.
- **Level 2 — activation.** The full `SKILL.md` body loads. Every line costs on every activation.
- **Level 3+ — deep context.** Bundled `references/` files load only when a specific scenario calls for one.

Write to that structure: the body carries decisions, gotchas, and enforced constraints; references carry look-it-up material. A body that holds everything upfront defeats the mechanism.

Skills also fall into two categories, and the category sets testing and maintenance expectations. **Capability uplift** builds on general model abilities (a structured code-review procedure) and stays stable across model versions. **Encoded preference** captures local conventions (a team's commit format) and needs revisiting when models change.

## Skill structure

```
skill-name/
├── SKILL.md           # Required: frontmatter + body
├── scripts/           # Optional: executable code for deterministic tasks
├── references/        # Optional: documentation loaded on-demand
└── assets/            # Optional: templates, images, boilerplate
```

`SKILL.md` is the only required file: YAML frontmatter, then Markdown body.

## Frontmatter

Source: [Claude Code Skills documentation](https://code.claude.com/docs/en/skills#frontmatter-reference). All fields are optional; only `description` is recommended.

- `name`: Display name. Defaults to the directory name if omitted. Lowercase letters, numbers, and hyphens only (max 64 characters). Reflect the domain in clear hyphen-case — `git-operations`, `elixir-phoenix`.
- `description` (recommended): What the skill does and when to use it. Two distinct limits apply: Claude Code truncates the combined `description` + `when_to_use` at 1,536 characters in the skill listing — put the key use case first — and this marketplace enforces a stricter 1024-character cap on `description` in `test/validate-skills-quality.nu`.
- `when_to_use`: Additional trigger phrases or example requests, appended to `description` in the listing.
- `license`: License name or filename reference.

The full upstream reference — `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `effort`, `context: fork`, `agent`, `hooks`, `paths`, `shell`, `arguments`, `argument-hint`, `metadata` — is in `references/frontmatter-fields.md`. Load it when authoring a skill that needs anything beyond name/description/license.

Write the description in third person, stating both what the skill does and when to use it: `[What it does]. Use when [trigger conditions].`

> **Critical**: The `description` is the ONLY text Claude sees during skill discovery (Level 1). The body's "When to Use" section only loads AFTER activation (Level 2) and cannot trigger it. All activation triggers belong in the description.

Tune a description by failure mode: too broad produces false positives — add domain-specific terms; too narrow produces false negatives — add synonyms and trigger scenarios. Activation-rate targets and eval prompt counts live in `/claude-code:claude-skills-benchmark`.

### Frontmatter policy for THIS marketplace

The upstream spec allows `allowed-tools` on a skill, pre-approving listed tools while it is active. **This marketplace's `test/validate-plugin.nu` rejects `allowed-tools` on skills as a hard validation failure.** Tool filtering belongs on **agents** — the `tools:` frontmatter on an agent file — not on the skills an agent loads. Skills here stay capability-driven and inherit tools from the calling context; an agent needing constrained access defines its own allowlist.

Keep skill frontmatter to `name`, `description`, optional `license`, optional `metadata`. In another project that does not enforce this policy, upstream `allowed-tools` is valid.

## Pre-edit checklist

Before writing or editing any SKILL.md, verify each item. Named checks live in `test/validate-skills-quality.nu` unless noted.

| Item | Enforced by |
|------|-------------|
| Description uses third person and includes a `Use when ...` trigger pattern | `third_person` + `use_when` checks |
| No `allowed-tools` field in frontmatter (use agents for tool allowlists) | `allowed_tools` check; also `test/validate-plugin.nu` |
| Body under 500 lines; split into `references/` once exceeded | `lines` check |
| References stay one level deep (SKILL.md → reference, not reference → reference) | `ref_depth` check |
| Anti-fabrication rules present — and every claim about a tool, file, or behavior verifiable | `anti_fab` check (presence only; soundness is on the author) |
| Combined `description` + `when_to_use` under 1,536 characters (Claude Code's listing truncation) | judgment — no check; the `desc` check caps `description` alone at 1024 |
| Zero hedging verbs: should, may, might, consider, try to, offer to, it would be good to | judgment — no check |

A failed enforced item is a blocker — the validator rejects it. A failed judgment item is a review-time flag: fix it or state why it stays.

Style beyond the checklist follows `references/context-engineering-claude-5.md` — judgment over rules, single statements, schema over prose — including its boundary test for which rules stay prescriptive.

## Skill content types

Three patterns from the upstream docs guide what to put in the body:

- **Reference content** — knowledge, conventions, style guides. Loads inline alongside conversation context. Example: API design patterns for a codebase.
- **Task content** — step-by-step instructions for a specific action (deploy, commit, generate). Often pair with `disable-model-invocation: true` to prevent automatic invocation.
- **Subagent-fork content** — runs in an isolated context (`context: fork` + `agent: Explore|Plan|...`). Skill body becomes the task prompt; skill produces a self-contained result.

## Dynamic context and substitutions

Skills support runtime substitution before content reaches the model. Source: [Claude Code Skills docs](https://code.claude.com/docs/en/skills#inject-dynamic-context).

**This section documents syntax that executes or expands at load time — including the load of this very skill.** Three different markers keep it intact, because no single escape covers every form:

- **A `KEY=` prefix** immediately before a `!` shell-injection trigger. Drop `KEY=` for the real syntax.
- **A leading backslash** before a bare `\$ARGUMENTS` placeholder — the documented escape for a literal `$`. Drop the backslash.
- **Bare names** for the `CLAUDE_*` variables, because the backslash does **not** escape the braced form (see below).

Digit-indexed forms (`$0`, `$1`, `$N`) and an undeclared `$name` need no marker — with no arguments declared or passed, they render unchanged rather than expanding.

**Changing anything in this section means verifying by loading the skill, not by reading the diff** — see `references/verifying-skill-content.md` for the loop, the session-snapshot trap that silently defeats it, and the table of what does and does not protect content.

**Shell injection** — Claude Code can run shell commands embedded in a skill before the body reaches the model; the command's stdout replaces the placeholder. Two forms:

- **Inline**: a bang character followed by a backtick-quoted command on a single line.
- **Fenced**: a code fence whose opening line is three backticks followed by a bang.

`````markdown
## Current diff
KEY=!`git diff HEAD`

```KEY=!
node --version
npm --version
```
`````

Fencing does not protect this example — nesting it inside a five-backtick outer fence was tested and it still executed, which is why the `KEY=` markers above are load-bearing, not decorative.

**String substitutions** in skill content:
- `\$ARGUMENTS` — full arguments string
- `\$ARGUMENTS[N]` or `$N` — argument by 0-based index
- `$name` — named argument when `arguments:` declared in frontmatter
- `CLAUDE_SESSION_ID` — current session ID
- `CLAUDE_EFFORT` — current effort level
- `CLAUDE_SKILL_DIR` — absolute path to this skill's directory (use for bundled scripts: `bash <CLAUDE_SKILL_DIR>/scripts/foo.sh`)

The three `CLAUDE_*` names are written bare because they are used as brace expansions in real files and **the leading-backslash escape does not work on the braced form** — verified by loading: the backslash survives and the token still expands, printing the live session ID and paths. See `/claude-code:claude-commands` "Argument Substitution" for the full rule.

Disable shell injection across user/project/plugin skills via `"disableSkillShellExecution": true` in settings — useful for managed environments.

## Authoring workflow

1. **Collect real use cases first.** Concrete examples reveal what the skill must support; theoretical requirements do not.
2. **Decide what each resource is for** — `scripts/` for deterministic work that would otherwise be rewritten each time, `references/` for material loaded on demand, `assets/` for output templates that never enter context.
3. **Create the directory**, with its name matching the `name` property exactly.
4. **Write the body in imperative form.** Keep procedure in `SKILL.md`, detail in references.
5. **Record every source** in the plugin's `sources.md` — URL, what was taken from it, why, and the date accessed where currency matters. This is what makes a claim auditable later.
6. **Validate before publishing.** Write eval prompts that should and should not activate the skill, run them, record actual pass/fail counts, and confirm references load when needed. Full methodology in `references/evaluation-guide.md`.
7. **Iterate on evidence.** Optimize the description against observed false positives and negatives, and test across Haiku, Sonnet, and Opus. Capture approaches that worked and mistakes that recurred back into the skill, asking Claude which context actually changed its behavior. If the base model passes the evals with the skill unloaded, the skill is unnecessary — deprecate it.

Write the evals before the content, and compare output with the skill loaded against output without it. Measure pass rates and token usage rather than judging quality subjectively; a single run proves nothing. `references/evaluation-guide.md` covers eval-driven development and blind A/B comparison, and `templates/evaluation-checklist.md` is a copyable checklist.

**Specify constraints, not implementations** — "ensure commit messages follow conventional format", not "run git commit -m with prefix type(scope):". Instructions rigid enough to break on a minor model update are too rigid; loose enough to produce inconsistent results, too loose. `references/design-patterns.md` has the full degree-of-freedom framework, the platform-capability matrix, and guidance on when to execute a bundled script versus read it for patterns to adapt.

## Five-tier authoring pipeline

If a skill defines or modifies agent behavior (dispatch patterns, model selection, multi-agent coordination), cross-link `/core:agent-loop` "Five-Tier Decomposition Pipeline" — the canonical decomposition for complex tasks.

Skill updates that only edit markdown skip P2 (test author) — content-grep tests on markdown are tautological. Updates touching agent definitions (`agents/*.md` with dispatch logic) follow the full five-tier pipeline since those files are executable specifications.

The pipeline runs inside ONE bees issue per skill update slice. The Sub-team Leader (or bees-worker acting as one) spawns the five stages as separate Task invocations; intermediate artifacts go to bees comments on that issue and git commits on the feature branch. Skill updates do not produce five chained bees rows.

## Sizing a skill

The context window is shared, and a skill's body loads in full on every activation — so justify each line's presence rather than each file's.

**Compaction behavior sets the real budget.** A skill loads as a single message and stays for the session. Auto-compaction keeps the first 5,000 tokens of each invoked skill, with a 25,000-token combined budget filled from most-recently-invoked first, so older skills can drop after compaction. Re-invoke a skill if it stops influencing behavior.

## Security

Install skills only from trusted sources. A skill body is executable input: it can carry shell-injection lines that run before anyone reads the output. Before installing an unfamiliar skill, audit its bundled files and scripts, its code dependencies, any instruction directing Claude to an external service, and any request for credentials or destructive operations.

### Disclosure discipline for public repositories

Skill content ships to public repositories; secret *references* disclose infrastructure even when no credential leaks, and secret scanners do not catch them. In every SKILL.md, reference, and template:

- Use placeholder vault names in secret-manager references: `op://<vault>/item/field`, never a real vault name
- Use RFC5737 documentation IP ranges in examples (`192.0.2.x`, `198.51.100.x`, `203.0.113.x`), not RFC1918 addresses from a real network — quote an RFC1918 literal only when it is an upstream tool's documented default
- Use generic hostnames (`node1`, `host.example.com`), never real estate hostnames as ssh/URL/mount targets
- Apply the same rules to issue-tracker descriptions when the tracker exports to a tracked file (e.g. bees `issues.jsonl`)

Enforce with a repo lint in CI where available (this marketplace runs `mise test:disclosure`).

## Anti-fabrication requirements

Every SKILL.md must include anti-fabrication rules — either inline or by referencing `core:anti-fabrication`. The authoritative rules (evidence-based claims via tool execution, no superlatives, no unsubstantiated metrics, no unmeasured time estimates, explicit uncertainty markers) live in the `core:anti-fabrication` skill; skill-creation-specific guidance is in `references/anti-fabrication.md`.

## References

Annotated examples of simple and complex skills, category classifications, and common pitfalls are in `references/examples.md`.

```
claude-skills/
├── references/
│   ├── design-patterns.md    # Degree of freedom, platform matrix, script execution, reference structure
│   ├── evaluation-guide.md   # Eval-driven development, A/B testing, description optimization
│   ├── anti-fabrication.md   # Skill-creation-specific anti-fab guidance
│   ├── context-engineering-claude-5.md  # What changed for Claude 5 generation models
│   ├── frontmatter-fields.md # Full upstream frontmatter reference
│   ├── verifying-skill-content.md  # Verify by loading; the session-snapshot trap
│   └── examples.md           # Annotated skill examples and common pitfalls
└── templates/
    ├── evaluation-checklist.md  # Copyable eval checklist
    ├── level1.md                # Example skill metadata
    ├── level2.md                # Example skill body
    ├── level3.md                # Example skill folder structure
    └── skill.md                 # Example basic skill
```

For more information:
- **Agent Skills Blog**: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- **Building Skills Guide (PDF)**: https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf
- **Improving Skill Creator Blog**: https://claude.com/blog/improving-skill-creator-test-measure-and-refine-agent-skills
- **Example Skills**: https://github.com/anthropics/skills
- **Skills Cookbook**: https://github.com/anthropics/claude-cookbooks/tree/main/skills
- **Skill Creator Guide**: https://github.com/anthropics/skills/blob/main/skill-creator/SKILL.md
- **Agent Skills Specification**: https://github.com/anthropics/skills/blob/main/agent_skills_spec.md
