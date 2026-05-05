---
name: claude-skills
description: Guide for creating Agent Skills with progressive disclosure and best practices. Use when creating new skills, understanding skill structure, or implementing progressive disclosure.
---

# Agent Skills

Guide for creating modular, self-contained Agent Skills that extend Claude's capabilities with specialized knowledge.

## What Are Agent Skills?

Agent Skills are organized directories containing instructions, scripts, and resources that Claude can dynamically discover and load. They enable a single general-purpose agent to gain domain-specific expertise without requiring separate custom agents for each use case.

### Key Concepts

- **Modularity**: Self-contained packages that can be mixed and matched
- **Reusability**: Share and distribute expertise across projects and teams
- **Progressive Disclosure**: Load context only when needed, keeping interactions efficient
- **Specialization**: Deep domain knowledge without sacrificing generality

### Skill Categories

Skills fall into two categories (source: Anthropic PDF Guide):

**Capability Uplift**: Enhances Claude's core abilities (coding, analysis, reasoning). These are stable across model versions because they build on general capabilities. Example: a code review skill that adds structured review steps.

**Encoded Preference**: Encodes user-specific workflows, formatting, and conventions. These need updates when models change because they depend on model behavior for fidelity. Example: a commit message skill that enforces team-specific format.

When creating a skill, identify its category — this determines testing strategy and maintenance expectations.

## How Skills Work

Skills operate on a principle of progressive disclosure across multiple levels:

### Level 1: Discovery
Agent system prompts include only skill names and descriptions, allowing Claude to decide when each skill is relevant based on the task at hand.

### Level 2: Activation
When Claude determines a skill applies, it loads the full `SKILL.md` file into context, gaining access to the complete procedural knowledge and guidelines.

### Level 3+: Deep Context
Additional bundled files (like references, forms, or documentation) load only when needed for specific scenarios, keeping token usage efficient.

This tiered approach maintains efficient context windows while supporting potentially unbounded skill complexity.

## Skill Structure

### Minimal Requirements

Every skill must have:

```
skill-name/
└── SKILL.md
```

### Complete Structure

More complex skills can include additional resources:

```
skill-name/
├── SKILL.md           # Required: Core skill definition
├── scripts/           # Optional: Executable code for deterministic tasks
├── references/        # Optional: Documentation loaded on-demand
└── assets/            # Optional: Templates, images, boilerplate
```

## SKILL.md Format

Each `SKILL.md` file must begin with YAML frontmatter followed by Markdown content:

```markdown
---
name: skill-name
description: Concise explanation of when Claude should use this skill
license: MIT
---

# Skill Name

Main instructional content goes here...
```

### YAML Properties

Source: [Claude Code Skills documentation](https://code.claude.com/docs/en/skills#frontmatter-reference). All fields are optional; only `description` is recommended.

- `name`: Display name. If omitted, defaults to the directory name. Lowercase letters, numbers, and hyphens only (max 64 characters).
- `description` (recommended): What the skill does and when to use it. Claude uses this to decide when to apply the skill. Combined `description` + `when_to_use` is truncated at 1,536 characters in the skill listing — put the key use case first.
- `when_to_use`: Additional trigger phrases or example requests, appended to `description` in the listing.
- `license`: License name or filename reference.

The full upstream frontmatter reference (with `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `effort`, `context: fork`, `agent`, `hooks`, `paths`, `shell`, `arguments`, `argument-hint`, `metadata`) lives in `references/frontmatter-fields.md`. Load that reference when authoring a skill that needs anything beyond name/description/license.

**Description constraints**:
- Use third person (not "I can help you" or "You can use this")
- Include both **what it does** AND **when to use it**
- Pattern: `[What it does]. Use when [trigger conditions].`

> **Critical**: The `description` is the ONLY text Claude sees during skill discovery (Level 1). The body's "When to Use" section only loads AFTER activation (Level 2) and cannot trigger it. All activation triggers belong in the description.

### Frontmatter policy for THIS marketplace

The upstream Claude Code spec allows `allowed-tools` on a skill — it pre-approves listed tools while the skill is active. **This marketplace's `test/validate-plugin.nu` rejects `allowed-tools` on skills as a hard validation failure.** Reasoning:

- Tool filtering belongs on **agents** (the `tools:` frontmatter on an agent file), not on skills the agent loads. See the `claude-agents` skill.
- Skills in this marketplace stay capability-driven (knowledge, procedure) and inherit tools from the calling context.
- An agent that needs constrained tool access defines its own allowlist; skills it consumes do not override that.

When working in this marketplace: keep skill frontmatter to `name`, `description`, optional `license`, optional `metadata`. Use `allowed-tools` on agents instead.

When working in another project that does not enforce this policy, the upstream `allowed-tools` field is valid and documented.

### Markdown Body

The content section has no structural restrictions. Include:

- When to activate the skill
- Core procedural knowledge
- Best practices and guidelines
- Examples and patterns
- References to additional resources (if any)

## Pre-edit checklist

Before writing or editing any SKILL.md, verify:

- [ ] Description uses third person and includes a `Use when ...` trigger pattern
- [ ] Combined `description` + `when_to_use` under 1,536 characters
- [ ] No `allowed-tools` field in frontmatter (this marketplace's validator rejects it; use agents for tool allowlists)
- [ ] Body under 500 lines per upstream guideline; split into `references/` once exceeded
- [ ] References stay one level deep (SKILL.md → reference, not reference → reference)
- [ ] Zero hedging verbs: should, may, might, consider, try to, offer to, it would be good to
- [ ] Anti-fabrication rules apply to this SKILL.md itself — every claim about a tool, file, or behavior is verifiable

A failed checkbox is a blocker, not a preference.

## Skill content types

Three patterns from the upstream docs guide what to put in the body:

- **Reference content** — knowledge, conventions, style guides. Loads inline alongside conversation context. Example: API design patterns for a codebase.
- **Task content** — step-by-step instructions for a specific action (deploy, commit, generate). Often pair with `disable-model-invocation: true` to prevent automatic invocation.
- **Subagent-fork content** — runs in an isolated context (`context: fork` + `agent: Explore|Plan|...`). Skill body becomes the task prompt; skill produces a self-contained result.

## Dynamic context and substitutions

Skills support runtime substitution before content reaches the model. Source: [Claude Code Skills docs](https://code.claude.com/docs/en/skills#inject-dynamic-context).

**Shell injection** — `` !`<command>` `` inline or fenced ` ```! ` blocks run shell commands; output replaces the placeholder before Claude sees the skill:

````markdown
## Current diff
!`git diff HEAD`
````

**String substitutions** in skill content:
- `$ARGUMENTS` — full arguments string
- `$ARGUMENTS[N]` or `$N` — argument by 0-based index
- `$name` — named argument when `arguments:` declared in frontmatter
- `${CLAUDE_SESSION_ID}` — current session ID
- `${CLAUDE_EFFORT}` — current effort level
- `${CLAUDE_SKILL_DIR}` — absolute path to this skill's directory (use for bundled scripts: `bash ${CLAUDE_SKILL_DIR}/scripts/foo.sh`)

Disable shell injection across user/project/plugin skills via `"disableSkillShellExecution": true` in settings — useful for managed environments.

## Creating Skills: Seven-Step Workflow

### 1. Understanding Through Examples

Gather concrete use cases to clarify what the skill needs to support. Real-world examples reveal actual needs better than theoretical requirements.

**Example:**
```
Use Case: Help developers follow Git best practices
Examples:
- Creating conventional commit messages
- Rebasing feature branches
- Resolving merge conflicts
- Creating descriptive branch names
```

### 2. Planning Resources

Analyze examples to identify needed components:

- **Scripts**: For tasks requiring deterministic reliability or that would need repeated rewriting
- **References**: Documentation to load into context as needed
- **Assets**: Output files like templates or boilerplate (not loaded into context)

**Example:**
```
Git skill resources:
- scripts/analyze-commit.sh - Parse git diff for commit message
- references/conventional-commits.md - Detailed commit format spec
- assets/gitignore-templates/ - Common .gitignore files
```

### 3. Initialization

Create the skill directory structure with the required `SKILL.md` file. Ensure the directory name matches the `name` property exactly.

```bash
mkdir -p my-skill/{scripts,references,assets}
touch my-skill/SKILL.md
```

### 4. Editing

Develop resource files and update `SKILL.md` with:
- Purpose and activation criteria
- Usage guidelines and best practices
- Implementation details and examples
- References to supplementary files

**Use imperative/infinitive form** rather than second-person instruction for clarity.

Keep core procedural information in `SKILL.md` and detailed reference material in separate files.

### 5. Documentation

**Document all sources in the plugin's `sources.md`**. For each skill created, record:
- URLs of documentation, guides, and references used
- Purpose of each source
- Key topics and concepts extracted
- Date accessed (if relevant)

This maintains traceability and helps others understand the skill's foundation.

### 6. Validation

Test the skill using the validation loop pattern:

1. Define success criteria (what correct activation and output look like)
2. Create eval prompts — both in-scope (should activate) and out-of-scope (should not)
3. Run evaluations and record pass/fail rates
4. Verify progressive disclosure works (references load when needed)
5. Check token usage remains efficient
6. If any validation fails, iterate on the skill before publishing

For the complete evaluation methodology, see `references/evaluation-guide.md`.

### 7. Iteration

Refine based on real-world usage and evaluation data:
- **Optimize descriptions**: Reduce false positives (too broad) and false negatives (too narrow)
- **Test across models**: Verify behavior on Haiku, Sonnet, and Opus
- **Monitor activation**: Track when the skill triggers correctly vs incorrectly
- **Deprecation signal**: If the base model passes evals without the skill loaded, the skill is unnecessary — deprecate it

For description optimization techniques, see `references/evaluation-guide.md`.

## Best Practices

### Evaluation-Driven Development

Build skills using an evaluation-first approach (source: Anthropic Blog Post):

1. **Write evals first**: Define test prompts and expected behaviors before writing skill content
2. **Test with and without**: Compare Claude's output with the skill loaded vs without it
3. **Measure, don't guess**: Track pass rates, token usage, and timing — not subjective quality
4. **Run A/B comparisons**: Use independent agents to compare skill versions blindly
5. **Detect obsolescence**: When the base model passes evals without the skill, deprecate it

For the complete methodology, see `references/evaluation-guide.md`. For a copyable checklist, see `templates/evaluation-checklist.md`.

### Degree of Freedom

Balance specificity against fragility in skill instructions (source: Anthropic PDF Guide):

- **Specify constraints, not implementations**: "Ensure commit messages follow conventional format" not "Run git commit -m with prefix type(scope):"
- **Allow model adaptation**: Instructions must work across Haiku, Sonnet, and Opus without modification
- **Test fragility**: If a minor model update breaks your skill, instructions are too rigid
- **Test looseness**: If Claude produces inconsistent results, instructions are too loose

For the full framework with examples, see `references/design-patterns.md`.

### Context Window Discipline

The context window is a shared resource (source: [Claude Code Skills docs](https://code.claude.com/docs/en/skills#add-supporting-files)):

- Keep SKILL.md under **500 lines** per upstream guideline. Split detailed content into `references/` once the body exceeds 500 lines.
- Move detailed reference material (API specs, deep-dive docs, examples) to separate files. Load only when needed.
- Monitor cumulative load: skill + prompt + conversation history must all fit.
- Every line in SKILL.md is loaded on every activation — justify each line's presence.

**Skill content lifecycle:** A skill loads as a single message and stays for the session. Auto-compaction keeps the first 5,000 tokens of each invoked skill, with a 25,000-token combined budget filled from most-recently-invoked first. Older skills can be dropped after compaction. Re-invoke a skill if it stops influencing behavior post-compaction.

### Structure for Scale

Split unwieldy `SKILL.md` files into separate referenced documents:
- Keep commonly-used contexts together
- Separate mutually exclusive information to reduce token usage
- Use progressive disclosure to load details only when needed
- **Reference depth**: Keep references one level deep only (SKILL.md → reference, not reference → reference)
- **TOC in long references**: Add a Table of Contents to reference files over 100 lines
- **Scripts**: Execute scripts for deterministic tasks; read scripts for patterns to adapt contextually

For design patterns and detailed guidance, see `references/design-patterns.md`.

### Claude A/B Testing

Compare skill effectiveness using blind evaluation (source: Anthropic Blog Post):

1. Run the same prompt through Agent A (with skill) and Agent B (without skill)
2. Each agent uses a clean context — no accumulated state between tests
3. A comparator agent judges outputs without knowing which is which
4. Track token usage, timing, and quality metrics independently
5. Run 10+ evals for statistical significance

For detailed setup instructions, see `references/evaluation-guide.md`.

### Claude's Perspective

The skill name and description heavily influence when Claude activates it. Pay particular attention to:

- **Name**: Reflects the domain in clear hyphen-case (e.g., `git-operations`, `elixir-phoenix`)
- **Description**: States both what the skill does and when to use it, in third person

> **Critical**: The `description` is the ONLY text Claude sees during skill discovery (Level 1).
> The body's "When to Use" section only loads AFTER activation (Level 2) and cannot trigger it.
> All activation triggers must be in the description using patterns like "Use when [scenarios]".

**Description optimization** (source: Anthropic Blog Post):
- **False positives**: Description too broad — add domain-specific terms
- **False negatives**: Description too narrow — add synonyms and trigger scenarios
- **Target**: 90%+ true positive rate, <5% false positive rate
- Test with 10+ in-scope prompts and 5+ out-of-scope prompts

Monitor real usage patterns and iterate based on actual behavior.

### Platform Constraints

Skills run in different environments with different capabilities (source: Anthropic PDF Guide):

| Platform | Script Execution | Network | Filesystem |
|----------|-----------------|---------|------------|
| Claude Code (CLI) | Full Bash access | Available | Full access |
| Claude.ai (Web) | Sandbox only | Limited | Limited |
| API | Tool-dependent | Tool-dependent | Tool-dependent |
| Mobile | None | None | Read-only |

Document which platform features each skill requires. Never assume external API availability.

### Iterate Collaboratively

Work with Claude to capture successful approaches and common mistakes into reusable skill components. Ask Claude to self-reflect on what contextual information actually matters.

### Write for AI Consumption

Use clear, imperative language that Claude can follow:

- "Follow the Conventional Commits specification"
- "Use descriptive branch names with type prefixes"
- "Run tests before committing"

Avoid hedging language like "You should try to" or "It might be good to" or "Consider following".

Include concrete examples wherever possible to illustrate patterns and approaches.

### Security Considerations

Install skills only from trusted sources. When evaluating unfamiliar skills:
- Thoroughly audit bundled files and scripts
- Review code dependencies
- Examine instructions directing Claude to connect with external services
- Verify the skill doesn't request sensitive information or dangerous operations

## Anti-Fabrication Requirements

All skills MUST adhere to strict anti-fabrication requirements to ensure factual, measurable content. Every SKILL.md must include anti-fabrication rules — either inline (template below) or by referencing `core:anti-fabrication`.

For skill-creation-specific anti-fabrication guidance, see `references/anti-fabrication.md`. For the authoritative anti-fabrication guide, see the `core:anti-fabrication` skill.

### Core Principles

- Base all outputs on actual analysis of real data using tool execution
- Execute Read, Glob, Bash, or other validation tools before making claims
- Mark uncertain information as "requires analysis", "needs validation", or "requires investigation"
- Use precise, factual language without superlatives or unsubstantiated performance claims
- Execute tests before marking tasks complete and report actual results
- Validate integration recommendations through actual framework detection using tool analysis

### Prohibited Language and Claims

- **Superlatives**: Avoid "excellent", "comprehensive", "advanced", "optimal", "perfect"
- **Unsubstantiated Metrics**: Never fabricate percentages, success rates, or performance numbers
- **Assumed Capabilities**: Don't claim features exist without tool verification
- **Generic Claims**: Replace vague statements with specific, measurable observations
- **Fabricated Testing**: Never report test results without actual execution

### Time and Effort Estimation Rule

- Never provide time estimates, effort estimates, or completion timelines without actual measurement or analysis
- If estimates are requested, execute tools to analyze scope (e.g., count files, measure complexity, assess dependencies) before providing data-backed estimates
- When estimates cannot be measured, explicitly state "timeline requires analysis of [specific factors]"
- Avoid fabricated scheduling language like "15 minutes", "2 hours", "quick task" without factual basis

### Validation Requirements

- **File Claims**: Use Read or Glob tools before claiming files exist or contain specific content
- **System Integration**: Use Bash or appropriate tools to verify system capabilities
- **Framework Detection**: Execute actual detection logic before claiming framework presence
- **Test Results**: Only report test outcomes after actual execution with tool verification
- **Performance Claims**: Base any performance statements on actual measurement or analysis

## Skill Examples

For annotated examples of simple and complex skills with category classifications, see `references/examples.md`.

## Common Pitfalls

For common mistakes and how to avoid them, see `references/examples.md`.

## References

claude-skills/
├── references/
│   ├── design-patterns.md    # Degree of freedom, validation loops, conditional workflows
│   ├── evaluation-guide.md   # Eval-driven development, A/B testing, multi-model testing
│   ├── anti-fabrication.md   # Skill-creation-specific anti-fab guidance
│   └── examples.md           # Annotated skill examples and common pitfalls
└── templates/
    ├── evaluation-checklist.md  # Copyable eval checklist
    ├── level1.md                # Example skill metadata
    ├── level2.md                # Example skill body
    ├── level3.md                # Example skill folder structure
    └── skill.md                 # Example basic skill

For more information:
- **Agent Skills Blog**: https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- **Building Skills Guide (PDF)**: https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf
- **Improving Skill Creator Blog**: https://claude.com/blog/improving-skill-creator-test-measure-and-refine-agent-skills
- **Example Skills**: https://github.com/anthropics/skills
- **Skills Cookbook**: https://github.com/anthropics/claude-cookbooks/tree/main/skills
- **Skill Creator Guide**: https://github.com/anthropics/skills/blob/main/skill-creator/SKILL.md
- **Agent Skills Specification**: https://github.com/anthropics/skills/blob/main/agent_skills_spec.md
