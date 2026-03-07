# Skill Evaluation Checklist

> Copyable checklist for testing a skill. Source: Anthropic "Improving skill-creator" blog post.

## Skill: [NAME]

### Pre-Evaluation

- [ ] Skill has YAML frontmatter with `name` and `description`
- [ ] Description includes "Use when" activation triggers
- [ ] Description uses third person (no "I can" or "You can")
- [ ] SKILL.md is under 500 lines
- [ ] Anti-fabrication rules are present (inline or referenced)

### Eval Prompts

Create 5-10 representative prompts:

| # | Prompt | Expected | Pass? |
|---|--------|----------|-------|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |

### False Positive Prompts

Create 3-5 out-of-scope prompts (skill should NOT activate):

| # | Prompt | Activated? | Pass? |
|---|--------|-----------|-------|
| 1 | | | |
| 2 | | | |
| 3 | | | |

### A/B Comparison

| Metric | With Skill | Without Skill |
|--------|-----------|---------------|
| Eval pass rate | /10 | /10 |
| Avg tokens used | | |
| Avg time | | |

### Multi-Model Results

| Model | Evals Passed | Notes |
|-------|-------------|-------|
| Haiku | /10 | |
| Sonnet | /10 | |
| Opus | /10 | |

### Quality Check

- [ ] Output follows skill instructions consistently
- [ ] Edge cases handled appropriately
- [ ] No fabricated content in outputs
- [ ] Progressive disclosure works (references load when needed)
- [ ] Description triggers accurately (low false positive/negative rate)

### Iteration Notes

**Issues found**: (describe any failures or unexpected behavior)

**Changes made**: (describe revisions to skill content or description)

**Verification**: (results after changes)

### Decision

- [ ] **Ship**: Meets targets across all checks
- [ ] **Iterate**: Needs refinement (see notes above)
- [ ] **Deprecate**: Base model passes evals without skill
