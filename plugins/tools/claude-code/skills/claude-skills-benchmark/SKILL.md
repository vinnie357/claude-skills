---
name: claude-skills-benchmark
description: Evaluate and benchmark Agent Skills quality using static analysis and evaluation methodology. Use when discussing skill quality, benchmarking skills, measuring activation rates, or reviewing skill effectiveness.
---

# Skill Benchmarking

Evaluate Agent Skills through static analysis and evaluation-driven methodology. Source: Anthropic's skill evaluation guidance.

## When to Use

Activate when:
- Assessing skill quality across a plugin or marketplace
- Measuring skill activation accuracy (false positives/negatives)
- Comparing skill versions or skill-vs-no-skill performance
- Running the `/benchmark-skills` command
- Reviewing skill descriptions for optimization

## Static Analysis Checks

Run these checks against every skill to produce a quality scorecard:

| Check | Pass Criteria |
|-------|--------------|
| Description length | Non-empty, max 1024 chars |
| Description has "Use when" | Contains activation triggers |
| Description third person | No "I can", "You can" |
| Name kebab-case | Matches `^[a-z0-9]+(-[a-z0-9]+)*$` |
| Name max 64 chars | Length check |
| No reserved words | No "anthropic"/"claude" in name |
| SKILL.md max 500 lines | Line count |
| Has examples | Contains code blocks or example sections |
| Reference depth | No nested references (one level only) |
| Anti-fabrication present | Contains anti-fab rules or references `core:anti-fabrication` |
| Source documented | Skill appears in plugin's `sources.md` |

## Skill Categories

Classify each skill for appropriate evaluation:

**Capability Uplift**: Enhances Claude's core abilities (coding, analysis, reasoning). Stable across model versions. Test by comparing base model performance with and without the skill.

**Encoded Preference**: Encodes user-specific workflows, formatting, and conventions. May need updates when models change. Test by verifying fidelity to the encoded workflow.

## Evaluation Methodology

### Writing Evals

For each skill, create:
- 5-10 representative prompts that should trigger the skill
- 3-5 out-of-scope prompts that should NOT trigger the skill
- Expected behavior criteria for each prompt

### A/B Testing

Compare skill performance using independent agents:
1. Agent A runs with the skill loaded
2. Agent B runs without the skill
3. A comparator judges outputs blindly
4. Track: pass rate, token usage, execution time

### Multi-Model Testing

Test across model tiers to verify consistency:

| Model | Target Pass Rate |
|-------|-----------------|
| Haiku | 70%+ |
| Sonnet | 85%+ |
| Opus | 95%+ |

If Haiku fails but others pass, instructions may rely on implicit reasoning — make them more explicit.

## Description Optimization

The description determines activation accuracy. Optimize for:

- **Reducing false positives**: Too-broad descriptions waste context. Add domain-specific terms.
- **Reducing false negatives**: Too-narrow descriptions miss valid prompts. Add synonyms and related terms.
- **Target**: 90%+ true positive rate, <5% false positive rate

## Scorecard Output

The benchmark produces a table per plugin:

```
Skill            | Plugin   | Desc | Lines   | Refs | Examples | Score
─────────────────┼──────────┼──────┼─────────┼──────┼──────────┼──────
git              | core     | Pass | 120/500 | Pass | Pass     | 9/11
claude-skills    | cl-code  | Pass | 380/500 | Pass | Pass     | 10/11
```

## Running Benchmarks

- **Static analysis**: `mise test:skills-quality` — runs all static checks, produces scorecard
- **Command**: `/benchmark-skills` — full analysis with category classification and quality assessment
- **Manual evals**: Use the evaluation checklist template at `templates/evaluation-checklist.md`

## Iteration

Follow the cycle: Test, Measure, Analyze, Refine, Verify.

Stop iterating when:
- Eval pass rates meet targets across model tiers
- Description triggers accurately
- Token usage is reasonable relative to benefit
- No user-reported issues for 2+ model versions

## Anti-Fabrication Requirements

### Core Principles

- Base all outputs on actual analysis using tool execution
- Execute validation tools before making claims
- Mark uncertain information as "requires analysis" or "needs validation"
- Use precise, factual language without superlatives

### Prohibited Language

- **Superlatives**: Avoid "excellent", "comprehensive", "advanced", "optimal", "perfect"
- **Unsubstantiated Metrics**: Never fabricate percentages, success rates, or performance numbers
- **Assumed Capabilities**: Do not claim features exist without tool verification

### Validation Requirements

- **File Claims**: Use Read or Glob tools before claiming files exist
- **Test Results**: Only report test outcomes after actual execution
- **Performance Claims**: Base on actual measurement or analysis
