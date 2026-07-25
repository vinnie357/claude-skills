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

The check list, pass criteria, and failure keys are defined in `test/validate-skills-quality.nu` — that script is the single source of truth; do not restate its checks here. Run `mise run test:skills-quality` to produce the current scorecard.

The checks' intent: descriptions that trigger accurately (length caps, "Use when" triggers, third person), spec-compliant naming, bounded body size, working examples, resolvable links, one-level reference depth with no orphaned files, anti-fabrication rules present, and sources documented in the plugin's `sources.md`.

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

```
In-scope:     "Benchmark the elixir plugin's skills"    → skill activates
Out-of-scope: "Write an ExUnit test for this module"    → skill stays silent
```

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

The validator prints one row per skill: line count, score, and the failure keys for any failed checks. It also diffs results against the shrink-only ratchet in `test/quality-baseline.json`, so pre-existing failures are waived while new ones fail the run.

## Running Benchmarks

- **Static analysis**: `mise run test:skills-quality` — runs all static checks, produces scorecard
- **Command**: `/benchmark-skills` — full analysis with category classification and quality assessment
- **Manual evals**: Use `/claude-code:claude-skills`'s `templates/evaluation-checklist.md`

## Iteration

Follow the cycle: Test, Measure, Analyze, Refine, Verify.

Stop iterating when:
- Eval pass rates meet targets across model tiers
- Description triggers accurately
- Token usage is reasonable relative to benefit
- No user-reported issues for 2+ model versions

## Anti-Fabrication Requirements

Report only measured results: run the validator or the evals before quoting any score, pass rate, or count, and mark unmeasured values as "requires analysis". The full rules live in the `core:anti-fabrication` skill.
