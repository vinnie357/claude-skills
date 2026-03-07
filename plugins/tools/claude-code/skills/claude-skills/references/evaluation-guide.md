# Skill Evaluation Guide

> Reference file for the `claude-skills` skill. Evaluation methodology sourced from Anthropic's "Improving skill-creator: Test, measure, and refine Agent Skills" (Blog Post).

## Table of Contents

- [Evaluation-Driven Development](#evaluation-driven-development)
- [Writing Evals](#writing-evals)
- [Claude A/B Testing](#claude-ab-testing)
- [Description Optimization](#description-optimization)
- [Multi-Model Testing](#multi-model-testing)
- [Observations Checklist](#observations-checklist)
- [Iteration Cycle](#iteration-cycle)

## Evaluation-Driven Development

Build skills using an evaluation-first approach: define test prompts, describe expected behavior, then verify the skill produces correct results.

### Core Methodology

1. **Define test prompts**: Create representative inputs that exercise the skill
2. **Describe expected behavior**: Specify what correct output looks like
3. **Run evaluations**: Test the skill against the prompts
4. **Measure results**: Track pass/fail, timing, and token usage
5. **Iterate**: Refine the skill based on evaluation results

### Two Testing Purposes

**Regression detection**: Run evals against new model versions to detect behavioral shifts before they impact work. Model updates can change how skills are interpreted.

**Capability assessment**: Track when the base model passes evals without the skill loaded. This signals the skill may no longer be necessary — the model has internalized the capability.

### When to Run Evals

- After creating or modifying a skill
- After model updates (new Claude versions)
- When users report unexpected behavior
- Before publishing or distributing a skill
- Periodically as part of maintenance

## Writing Evals

Each eval consists of a test prompt, optional context files, and expected behavior criteria.

### Eval Structure

```markdown
## Eval: [Name]

**Prompt**: [The input to send to Claude]

**Context files** (if needed):
- [file1.ext]: [description]
- [file2.ext]: [description]

**Expected behavior**:
- [ ] [Specific observable outcome 1]
- [ ] [Specific observable outcome 2]
- [ ] [Specific observable outcome 3]

**Failure indicators**:
- [What incorrect behavior looks like]
```

### Guidelines

- Write 5-10 evals per skill minimum
- Cover common cases AND edge cases
- Include at least one "should NOT activate" eval (tests false positive rate)
- Test with and without the skill loaded for comparison
- Keep prompts realistic — use actual user requests, not synthetic tests

### Example Evals

```markdown
## Eval: Git Commit Message

**Prompt**: "Create a commit for adding user authentication with bcrypt"

**Expected behavior**:
- [ ] Uses conventional commit format (type(scope): description)
- [ ] Selects "feat" as the type
- [ ] Mentions authentication in the description
- [ ] Uses imperative mood

## Eval: False Positive Check

**Prompt**: "What's the weather in Tokyo?"

**Expected behavior**:
- [ ] Skill does NOT activate
- [ ] No git-related content in response
```

## Claude A/B Testing

Compare skill versions or skill-vs-no-skill performance using independent comparator agents.

### Setup

1. **Agent A**: Runs with the skill loaded
2. **Agent B**: Runs without the skill (or with an alternative version)
3. **Comparator**: Judges outputs without knowing which agent produced them

### Process

1. Send the same eval prompt to both agents
2. Collect outputs independently (clean contexts, no cross-contamination)
3. Present both outputs to the comparator agent
4. Record which output better meets the eval criteria
5. Track metrics: token usage, execution time, output quality

### Key Principles

- Each agent runs in a clean context — no accumulated state between evals
- Track token and timing metrics independently per agent
- The comparator must not know which output came from which agent
- Run sufficient evals (10+) to establish statistical significance

### What to Compare

- **Skill vs no skill**: Does the skill improve output quality?
- **Skill v1 vs v2**: Did the revision improve behavior?
- **Different descriptions**: Which description triggers more accurately?
- **Cross-model**: Does the skill work consistently across Haiku/Sonnet/Opus?

## Description Optimization

The description is the most impactful field — it determines when Claude activates the skill during discovery (Level 1).

### False Positive Reduction

A description that is too broad causes the skill to activate for unrelated prompts, wasting context window.

**Symptoms**: Skill activates for prompts outside its domain.

**Fix**: Add specificity to the description. Replace general terms with domain-specific triggers.

```yaml
# Too broad — triggers on any code question
description: Guide for writing code

# Optimized — triggers only for Git operations
description: Guide for Git operations including commits, branches, rebasing, and conflict resolution. Use when working with version control or the user mentions git, commits, or branches.
```

### False Negative Reduction

A description that is too narrow causes the skill to miss prompts it should handle.

**Symptoms**: Skill fails to activate for prompts within its domain.

**Fix**: Add more trigger scenarios. Include synonyms and related terms.

```yaml
# Too narrow — misses synonym prompts
description: Guide for Phoenix LiveView. Use when implementing LiveView.

# Optimized — covers related terms
description: Guide for Phoenix web applications with LiveView, contexts, and Ecto. Use when building Elixir web apps, implementing real-time features, or designing Phoenix contexts.
```

### Testing Descriptions

1. Create 10+ eval prompts covering the skill's domain
2. Create 5+ eval prompts outside the skill's domain
3. Test activation rates: target 90%+ true positives, <5% false positives
4. Iterate on description wording until targets are met

## Multi-Model Testing

Test skills across Haiku, Sonnet, and Opus to ensure consistent behavior.

### Why Multi-Model Matters

- **Capability uplift** skills: Should work uniformly across model sizes. If a skill only helps Opus but not Haiku, the instructions may be too implicit.
- **Encoded preference** skills: May degrade gracefully on smaller models. Verify that core behavior is preserved even if nuance is lost.

### Testing Matrix

| Model | Eval Pass Rate | Notes |
|-------|---------------|-------|
| Haiku | Target: 70%+ | Core behavior preserved |
| Sonnet | Target: 85%+ | Full behavior expected |
| Opus | Target: 95%+ | Complete behavior with nuance |

### What Model Differences Reveal

- **Haiku fails, others pass**: Instructions may rely on implicit reasoning. Make instructions more explicit.
- **All models fail**: The skill instructions need fundamental revision.
- **Opus passes without skill**: The capability may now be built into the model. Consider deprecating.

## Observations Checklist

Track these metrics during skill evaluation:

### Performance Metrics

- [ ] Eval pass/fail rate (per eval and overall)
- [ ] Elapsed execution time per eval
- [ ] Token usage (input + output) per eval
- [ ] False trigger frequency (activated when it should not)
- [ ] Missed trigger frequency (did not activate when it should)

### Quality Indicators

- [ ] Output follows skill instructions consistently
- [ ] Edge cases handled appropriately
- [ ] No fabricated or hallucinated content
- [ ] Structured output matches expected format
- [ ] Progressive disclosure loads correctly (references accessed when needed)

### Maintenance Signals

- [ ] Model version compatibility (current + previous)
- [ ] Base model now passes evals without skill (deprecation signal)
- [ ] User-reported issues or confusion
- [ ] Context window impact (skill size vs benefit)

## Iteration Cycle

Follow this cycle to continuously improve skills:

```
Test → Measure → Analyze → Refine → Verify
  ↑                                    |
  └────────────────────────────────────┘
```

### Steps

1. **Test**: Run eval suite against the skill
2. **Measure**: Record all metrics from the observations checklist
3. **Analyze**: Identify failures, patterns, and improvement opportunities
4. **Refine**: Update skill content, description, or structure
5. **Verify**: Re-run evals to confirm improvement without regressions

### When to Stop Iterating

- Eval pass rates meet targets across all model tiers
- Description triggers accurately (low false positives and negatives)
- Token usage is reasonable relative to benefit
- No user-reported issues for 2+ model versions

### Storage

Store evals and results locally, integrate with a dashboard, or plug into CI. The evaluation data belongs to the skill author and should be versioned alongside the skill.
