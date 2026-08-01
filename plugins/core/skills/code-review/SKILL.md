---
name: code-review
description: Guide for conducting code reviews. Use when reviewing pull requests, auditing code quality, identifying security issues, or providing code feedback.
---

# Code Review Best Practices

This skill activates when reviewing code for quality, correctness, security, and maintainability.

## When to Use This Skill

Activate when:
- Reviewing pull requests
- Conducting code audits
- Providing feedback on code quality
- Identifying security vulnerabilities
- Suggesting refactoring improvements
- Checking adherence to coding standards

## Anti-fabrication

This skill follows `core:anti-fabrication`, but genuinely has little to verify against an
external source: the checklist, review-etiquette, and anti-pattern content is house
convention and general engineering practice (Google's review guide is cited in
`sources.md` for the checklist's shape), not versioned claims about a specific tool or
API. The "Language-Specific Considerations" section is broad, stable idioms (pattern
matching, ownership, type hints) rather than anything that drifts release to release —
still, don't assert a language- or framework-specific rule this skill doesn't cover
without checking that language's own style skill first.

## Code Review Checklist

### 1. Correctness and Functionality

**Does the code do what it's supposed to do?**

- Logic is correct and handles all cases
- Edge cases are considered
- Error handling is appropriate
- No obvious bugs or logical errors
- Assertions and validations are present
- Return values are correct

**Questions to ask:**
- What happens if this receives null/nil?
- What if the list is empty?
- What if the number is negative/zero?
- Are there off-by-one errors?
- Are comparisons correct (>, >=, <, <=)?

### 2. Security

**Is the code secure?**

- No SQL injection vulnerabilities
- No XSS (Cross-Site Scripting) vulnerabilities
- No CSRF vulnerabilities (CSRF protection in place)
- User input is validated and sanitized
- Sensitive data is not logged
- Authentication and authorization are properly implemented
- No hardcoded secrets or credentials
- File uploads are validated (type, size, content)
- External URLs are validated
- Rate limiting is in place for APIs

Worked BAD/GOOD examples (SQL injection, XSS, hardcoded secrets, mass assignment): [references/checklist-examples.md](references/checklist-examples.md).

### 3. Performance

**Is the code efficient?**

- No N+1 query problems
- Appropriate data structures chosen
- Algorithms are efficient
- Database indexes are used
- Caching is implemented where appropriate
- Large datasets are paginated or streamed
- Unnecessary computations are avoided
- Resources are cleaned up properly

Worked BAD/GOOD examples (N+1 queries, loading full datasets, list vs set lookups): [references/checklist-examples.md](references/checklist-examples.md).

### 4. Code Quality and Maintainability

**Is the code readable and maintainable?**

- Clear, descriptive variable and function names
- Functions are small and focused (single responsibility)
- No code duplication (DRY principle)
- Comments explain "why", not "what"
- Code follows project conventions and style guide
- Magic numbers are replaced with named constants
- Complexity is minimized
- Code is self-documenting

Worked BAD/GOOD examples (unclear names, multi-responsibility functions, magic numbers): [references/checklist-examples.md](references/checklist-examples.md).

### 5. Error Handling

**Are errors handled properly?**

- Errors don't crash the system unexpectedly
- Error messages are helpful
- Errors are logged appropriately
- Happy path and error paths are both tested
- No swallowed errors (empty catch blocks)
- Proper error types are used

Worked BAD/GOOD examples (swallowed errors, generic error messages, bang functions that crash): [references/checklist-examples.md](references/checklist-examples.md).

### 6. Testing

**Is the code properly tested?**

- New functionality has tests
- Edge cases are tested
- Error conditions are tested
- Tests are clear and focused
- Tests are deterministic (no flaky tests)
- Test names describe what they test
- Mocks are used appropriately
- Test coverage is adequate

Worked BAD/GOOD examples (unclear test names, over-broad tests, non-deterministic sleeps): [references/checklist-examples.md](references/checklist-examples.md).

### 7. Documentation

**Is the code documented?**

- Public APIs have documentation
- Complex logic has explanatory comments
- README is updated if needed
- Changelog is updated for user-facing changes
- API documentation is accurate
- Examples are provided

### 8. Dependencies

**Are dependencies handled properly?**

- New dependencies are justified
- Dependencies are up-to-date and maintained
- Licenses are compatible with project
- Security vulnerabilities are checked
- Dependency versions are pinned or bounded

### 9. Restraint and Scope

**Does every new symbol earn its place in the diff?**

For each NEW symbol introduced by the diff (function, class, config, dependency), check it against the restraint ladder before approving:

- Does this need to exist at all, or is it speculative scaffolding? (YAGNI)
- Is it a duplicate of an existing helper, stdlib function, or already-installed dependency? (Reuse-First)
- Could it be expressed in a smaller form — fewer lines, no new abstraction?

Flag speculative abstractions (interfaces with one implementation, config for values that never change, factories for one product) and unrequested features as findings, not nits. See `/core:restraint`.

## Review Process

### Before Reviewing

1. **Understand the context**
   - Read the PR description
   - Understand the problem being solved
   - Check related issues

2. **Build and test locally**
   - Pull the branch
   - Run tests
   - Test the functionality manually

### During Review

1. **Start with the big picture**
   - Is the approach sound?
   - Does it fit the architecture?
   - Is there a better way?

2. **Review for correctness**
   - Does it work as intended?
   - Are edge cases handled?
   - Is error handling appropriate?

3. **Check security and performance**
   - Are there security vulnerabilities?
   - Will it perform well at scale?

4. **Review code quality**
   - Is it readable and maintainable?
   - Does it follow conventions?
   - Is it well-tested?

### Providing Feedback

**Be constructive and specific:**

```markdown
# BAD: Vague criticism
"This function is bad."

# GOOD: Specific, actionable feedback
"This function has three responsibilities: validation, database update, and email sending. Consider splitting it into separate functions for better testability and maintainability:

```elixir
def update_user(user, attrs) do
  with {:ok, changeset} <- validate_user_update(user, attrs),
       {:ok, user} <- save_user(changeset),
       :ok <- send_update_notification(user) do
    {:ok, user}
  end
end
```

# BAD: Demanding
"You must change this."

# GOOD: Collaborative
"What do you think about extracting this into a separate function? It would make the code easier to test."

# BAD: Nitpicking without context
"Use single quotes instead of double quotes."

# GOOD: Explain reasoning
"Our style guide prefers single quotes for consistency (see CONTRIBUTING.md section 3.2)."
```

**Use labels to categorize feedback:**

- **[blocking]**: Must be fixed before merging
- **[suggestion]**: Optional improvement
- **[question]**: Asking for clarification
- **[nit]**: Very minor, cosmetic issue
- **[security]**: Security concern
- **[performance]**: Performance concern

**Example:**

```markdown
[blocking] This creates a SQL injection vulnerability. Use parameterized queries:

```elixir
# Instead of:
query = "SELECT * FROM users WHERE name = '#{name}'"

# Use:
from(u in User, where: u.name == ^name)
```

[suggestion] Consider extracting this logic into a separate function for reusability.

[question] Why are we using a map here instead of a struct?

[nit] Extra blank line here.
```

### After Review

1. **Respond to author's questions**
2. **Re-review after changes**
3. **Approve when satisfied**
4. **Celebrate good code**

## Language-Specific Considerations

### Elixir

- Pattern matching is used effectively
- Functions leverage pipe operator for readability
- Atoms aren't created dynamically from untrusted input
- `with` statements handle errors properly
- Changesets validate all input
- No direct database queries in controllers/LiveViews (use contexts)

### JavaScript/TypeScript

- Types are properly defined (TypeScript)
- Promises are handled with .catch() or try/catch
- == vs === is used correctly
- Arrays/objects aren't mutated unexpectedly
- this binding is correct
- Async operations are properly awaited

### Python

- Type hints are used
- List comprehensions aren't overly complex
- Exceptions are specific (not bare except:)
- Resources are closed (use with statements)
- Code follows PEP 8

### Rust

- Ownership and borrowing are correct
- Error handling uses Result/Option properly
- Unsafe blocks are justified and minimal
- Clone/copy is used appropriately
- Lifetimes are correctly specified

## Common Code Smells

### Complexity Smells

- **Long functions** - Function does too much
- **Long parameter list** - Too many parameters
- **Deep nesting** - Too many levels of indentation
- **Complex conditionals** - Hard to understand if statements

### Duplication Smells

- **Copy-paste code** - Same code in multiple places
- **Similar functions** - Functions that do almost the same thing
- **Magic numbers** - Repeated literal values

### Naming Smells

- **Unclear names** - Variables like x, tmp, data
- **Misleading names** - Name doesn't match behavior
- **Inconsistent names** - Same concept called different things

### Design Smells

- **God object** - Class/module doing everything
- **Feature envy** - Function using another object's data more than its own
- **Inappropriate intimacy** - Too much coupling between modules

## Anti-Patterns to Watch For

### Premature Optimization

```elixir
# BAD: Optimizing before measuring
def calculate(data) do
  # Complex, hard-to-read optimization
  # that saves 0.1ms
end

# GOOD: Start simple, optimize if needed
def calculate(data) do
  # Clear, simple code
  # Optimize later if profiling shows bottleneck
end
```

### Premature Abstraction

```elixir
# BAD: Abstract after one use
defmodule AbstractDataProcessorFactoryBuilder do
  # Complex abstraction for single use case
end

# GOOD: Wait for second use case
def process_user_data(data) do
  # Simple, direct implementation
  # Abstract when pattern emerges
end
```

### Error Swallowing

```elixir
# BAD: Hiding errors
try do
  risky_operation()
rescue
  _ -> :ok  # What went wrong?
end

# GOOD: Handle explicitly
case risky_operation() do
  {:ok, result} -> {:ok, result}
  {:error, reason} ->
    Logger.error("Operation failed: #{inspect(reason)}")
    {:error, reason}
end
```

## Review Etiquette

### DO:

- Be respectful and constructive
- Assume good intent
- Ask questions instead of making demands
- Praise good code
- Explain the "why" behind suggestions
- Offer to pair program on complex issues
- Respond promptly to author's replies

### DON'T:

- Be sarcastic or condescending
- Bike-shed on minor style issues
- Block on personal preferences
- Review your own code without another reviewer
- Approve code you don't understand
- Nitpick excessively

## Self-Review Checklist

Before submitting code for review:

- [ ] Code compiles and runs
- [ ] All tests pass
- [ ] Added tests for new functionality
- [ ] No commented-out code
- [ ] No debug print statements
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] No secrets or sensitive data
- [ ] Code follows project style guide
- [ ] Changes are focused (no unrelated changes)

## Key Principles

- **Correctness first**: Code must work correctly
- **Security matters**: Always consider security implications
- **Be specific**: Provide actionable, concrete feedback
- **Be respectful**: Kind, constructive communication
- **Focus on important issues**: Don't bike-shed
- **Explain reasoning**: Help author learn, don't just dictate
- **Approve good code**: Don't let perfect be enemy of good
- **Collaborate**: You're on the same team
- **Check restraint**: Every new symbol earns its place on the ladder — see `/core:restraint`

## References

- `references/no-todos-scan.md` — Scan PR diffs for new `TODO`/`FIXME`/`XXX`/`HACK`/`KLUDGE`/`DEFERRED` markers; treat as BLOCKER, not nit
