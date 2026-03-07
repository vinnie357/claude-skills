# Anti-Fabrication for Skill Creation

> Reference file for the `claude-skills` skill. Guidance for maintaining factual integrity when creating, testing, and documenting skills. For the authoritative anti-fabrication guide, see the `core:anti-fabrication` skill.

## Validating Skill Descriptions

Before claiming a description triggers correctly:

- **Test activation**: Send representative prompts and verify the skill activates
- **Test non-activation**: Send out-of-scope prompts and verify the skill does not activate
- **Report actual rates**: State observed activation counts, not estimated percentages
- **Mark untested claims**: Use "requires testing" for activation claims without verification

## Testing Skills Without Fabrication

- **Run evals before claiming pass rates**: Never state "95% pass rate" without actual eval execution
- **Report actual results**: "Passed 8 of 10 evals" not "high pass rate"
- **Document failures**: Record which evals failed and why, not just successes
- **Distinguish tested from untested**: Clearly mark which model tiers have been tested
- **Avoid assumed compatibility**: Do not claim "works across Haiku/Sonnet/Opus" without testing each

## Minimum Anti-Fabrication Template

Every SKILL.md must include anti-fabrication rules. Use this as the minimum template:

```markdown
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
```

## Common Fabrication Risks in Skill Development

| Risk | Example | Prevention |
|------|---------|------------|
| Claiming activation accuracy | "Triggers correctly 95% of the time" | Run actual eval suite and report counts |
| Fabricated examples | Showing output Claude never produced | Test examples and include actual output |
| Assumed model compatibility | "Works on all model tiers" | Test on each tier and report results |
| Fabricated performance gains | "Reduces errors by 50%" | Measure baseline vs skill and report data |
| Untested reference files | "References load correctly" | Verify progressive disclosure through testing |
