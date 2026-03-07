# Skill Design Patterns

> Reference file for the `claude-skills` skill. Design patterns sourced from Anthropic's "The Complete Guide to Building Skills for Claude" (PDF).

## Table of Contents

- [Degree of Freedom Framework](#degree-of-freedom-framework)
- [Validation Loop Pattern](#validation-loop-pattern)
- [Checklist-Based Workflows](#checklist-based-workflows)
- [Conditional Workflows](#conditional-workflows)
- [Script Execution vs Reading](#script-execution-vs-reading)
- [Self-Documenting Constants](#self-documenting-constants)
- [Visual Analysis Pattern](#visual-analysis-pattern)

## Degree of Freedom Framework

Balance specificity against fragility when writing skill instructions. The bridge analogy: overly rigid specifications break under stress (model updates, edge cases), while too-loose guidance provides no value.

**Principle**: Specify constraints, not implementations.

### Spectrum

| Too Rigid | Balanced | Too Loose |
|-----------|----------|-----------|
| "Always use exactly 3 paragraphs" | "Keep responses concise, typically 2-4 paragraphs" | "Write some paragraphs" |
| "Return JSON with fields x, y, z in that order" | "Return structured data with required fields: x, y, z" | "Return some data" |
| "Use setTimeout with 500ms delay" | "Add a brief delay to prevent race conditions" | "Handle timing" |

### Guidelines

- **Constrain outcomes, not methods**: "Ensure commit messages follow conventional format" not "Run git commit -m with prefix type(scope):"
- **Allow model adaptation**: Instructions that work across Haiku, Sonnet, and Opus without modification
- **Test fragility**: If a minor model update breaks your skill, it is too rigid
- **Test looseness**: If Claude produces inconsistent results, it is too loose
- **Prefer patterns over prescriptions**: Show the shape of correct output rather than dictating exact steps

### Anti-Pattern: Brittle Instructions

```markdown
# Bad — breaks if model behavior changes
Step 1: Output exactly "Analyzing..." on line 1
Step 2: Wait 2 seconds
Step 3: Output results in a 3-column table with headers "Name", "Value", "Status"
```

```markdown
# Good — resilient across model versions
Analyze the input and present results in a structured table.
Include columns for identification, measurement, and status.
Indicate progress to the user before presenting results.
```

## Validation Loop Pattern

Structure skills to include self-checking mechanisms that verify output quality before presenting results.

### Components

1. **Success criteria**: Define what correct output looks like
2. **Self-check step**: Verify output meets criteria before presenting
3. **Error handling**: Explicit guidance for common failure modes
4. **Iteration prompt**: Instructions for refining if validation fails

### Example

```markdown
## Code Review Process

1. Read the file and identify changes
2. Check each change against the style guide
3. **Validate**: Before presenting review, verify:
   - [ ] All flagged issues include file path and line number
   - [ ] Each issue has a concrete fix suggestion
   - [ ] No false positives from standard library usage
   - [ ] Severity levels (error, warning, info) are assigned
4. If any check fails, revise the review before presenting
```

### When to Use

- Tasks with measurable correctness criteria
- Multi-step processes where errors compound
- Output that will be consumed by other tools or processes
- Skills that generate structured data (JSON, YAML, tables)

## Checklist-Based Workflows

Use structured checklists for multi-step processes to ensure completeness and consistency.

### Pattern

```markdown
## Deployment Checklist

Before deploying:
- [ ] All tests pass locally
- [ ] Environment variables are configured
- [ ] Database migrations are prepared
- [ ] Rollback plan is documented

During deployment:
- [ ] Run migrations
- [ ] Deploy application
- [ ] Verify health checks

After deployment:
- [ ] Monitor error rates for 15 minutes
- [ ] Verify critical user flows
- [ ] Update deployment log
```

### Benefits

- Prevents skipped steps in complex workflows
- Provides clear progress tracking
- Works as both instruction and verification tool
- Naturally supports the validation loop pattern

## Conditional Workflows

Branch logic explicitly within skills to handle different scenarios without ambiguity.

### Pattern

```markdown
## Error Handling Strategy

**If the error is a compilation error:**
1. Read the error message and identify the source file
2. Fix the syntax or type error
3. Re-run the compiler

**If the error is a runtime error:**
1. Check the stack trace for the originating function
2. Add logging at the failure point
3. Reproduce and diagnose

**If the error is a test failure:**
1. Run the failing test in isolation
2. Compare expected vs actual output
3. Determine if the test or implementation is wrong
```

### Guidelines

- Use "If X, then Y" structure explicitly
- Cover all expected branches
- Include a fallback for unexpected cases
- Avoid nested conditionals deeper than 2 levels

## Script Execution vs Reading

Skills can include scripts, but Claude interacts with them differently depending on the platform.

### Key Distinction

- **Script Execution**: Claude runs the script via Bash or shell tool. Use for deterministic tasks (validation, formatting, data processing).
- **Script Reading**: Claude reads the script content for reference. Use for patterns, templates, or logic that Claude should adapt contextually.

### When to Execute

- Validation checks (linting, schema validation)
- Data transformations (JSON processing, file manipulation)
- Environment detection (installed tools, OS features)
- Repeatable operations with exact output requirements

### When to Read

- Code patterns to adapt to the current context
- Templates that need modification before use
- Reference implementations for understanding approach
- Configuration examples to customize

### Platform Considerations

- **Claude Code (CLI)**: Full Bash access, can execute scripts directly
- **Claude.ai (Web)**: Code execution sandbox, limited filesystem
- **API**: Depends on tool configuration; may not have shell access
- **Mobile**: Read-only; no script execution

Document which mode each script supports in the skill's SKILL.md.

## Self-Documenting Constants

Define values with clear naming and immediate context so Claude understands their purpose without external references.

### Pattern

```markdown
## Configuration

| Constant | Value | Purpose |
|----------|-------|---------|
| MAX_RETRIES | 3 | API call retry limit before failing |
| TIMEOUT_MS | 5000 | Request timeout in milliseconds |
| BATCH_SIZE | 100 | Records per processing batch |
```

### Anti-Pattern

```markdown
# Bad — magic numbers without context
Set retries to 3, timeout to 5000, and batch to 100.
```

## Visual Analysis Pattern

Provide structured templates for analyzing visual content (diagrams, charts, screenshots).

### Pattern

```markdown
## Diagram Analysis

When analyzing a diagram:
1. **Identify type**: Flowchart, sequence diagram, architecture diagram, etc.
2. **Extract components**: List all nodes, actors, or services
3. **Map relationships**: Document connections and data flows
4. **Note annotations**: Capture labels, conditions, and notes
5. **Summarize**: Describe the overall system or process
```

### Use Cases

- Architecture review skills
- UI/UX analysis skills
- Data visualization interpretation
- Technical diagram documentation
