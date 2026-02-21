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

**Common security issues:**

```elixir
# BAD: SQL injection vulnerability
query = "SELECT * FROM users WHERE id = #{user_id}"

# GOOD: Use parameterized queries
query = from u in User, where: u.id == ^user_id

# BAD: XSS vulnerability
raw("<div>#{user_input}</div>")

# GOOD: Escape user input
<div><%= user_input %></div>

# BAD: Hardcoded secrets
api_key = "sk_live_123456789"

# GOOD: Use environment variables
api_key = System.get_env("API_KEY")

# BAD: Mass assignment vulnerability
User.changeset(%User{}, params)

# GOOD: Whitelist allowed fields
User.changeset(%User{}, params)
# Where changeset only casts allowed fields:
# cast(user, attrs, [:name, :email])
```

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

**Common performance issues:**

```elixir
# BAD: N+1 query
posts = Repo.all(Post)
Enum.map(posts, fn post ->
  author = Repo.get(User, post.author_id)  # Query for each post!
  {post, author}
end)

# GOOD: Preload associations
posts = Post |> preload(:author) |> Repo.all()

# BAD: Loading entire dataset
users = Repo.all(User)  # Loads all millions of users
Enum.filter(users, & &1.active)

# GOOD: Query in database
users = User |> where(active: true) |> Repo.all()

# BAD: Inefficient data structure
list = [1, 2, 3, 4, 5]
if 3 in list do  # O(n) lookup in list
  # ...
end

# GOOD: Use set/map for lookups
set = MapSet.new([1, 2, 3, 4, 5])
if MapSet.member?(set, 3) do  # O(1) lookup
  # ...
end
```

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

**Code quality issues:**

```elixir
# BAD: Unclear names
def calc(x, y, z) do
  r = x * y / z
  r * 1.2
end

# GOOD: Clear names
def calculate_discounted_price(quantity, unit_price, discount_percentage) do
  subtotal = quantity * unit_price
  discount_amount = subtotal * (discount_percentage / 100)
  subtotal - discount_amount
end

# BAD: Long function with multiple responsibilities
def process_order(order) do
  # Validate order (responsibility 1)
  # Calculate totals (responsibility 2)
  # Update inventory (responsibility 3)
  # Send email (responsibility 4)
  # Log analytics (responsibility 5)
end

# GOOD: Single responsibility functions
def process_order(order) do
  with {:ok, order} <- validate_order(order),
       {:ok, order} <- calculate_totals(order),
       {:ok, order} <- update_inventory(order),
       :ok <- send_confirmation_email(order),
       :ok <- log_order_analytics(order) do
    {:ok, order}
  end
end

# BAD: Magic numbers
if user.age >= 13 do
  # ...
end

# GOOD: Named constants
@minimum_age_coppa 13

if user.age >= @minimum_age_coppa do
  # ...
end
```

### 5. Error Handling

**Are errors handled properly?**

- Errors don't crash the system unexpectedly
- Error messages are helpful
- Errors are logged appropriately
- Happy path and error paths are both tested
- No swallowed errors (empty catch blocks)
- Proper error types are used

**Error handling patterns:**

```elixir
# BAD: Silent failure
try do
  dangerous_operation()
rescue
  _ -> nil  # Error is swallowed!
end

# GOOD: Handle errors explicitly
case dangerous_operation() do
  {:ok, result} -> result
  {:error, reason} ->
    Logger.error("Operation failed: #{inspect(reason)}")
    {:error, reason}
end

# BAD: Generic error message
{:error, "failed"}

# GOOD: Specific error
{:error, :invalid_email_format}
{:error, {:validation_failed, errors}}

# BAD: Let it crash when shouldn't
def parse_config(path) do
  File.read!(path)  # Crashes if file missing
  |> Jason.decode!()  # Crashes if invalid JSON
end

# GOOD: Handle expected errors
def parse_config(path) do
  with {:ok, content} <- File.read(path),
       {:ok, config} <- Jason.decode(content) do
    {:ok, config}
  else
    {:error, :enoent} -> {:error, :config_file_not_found}
    {:error, %Jason.DecodeError{}} -> {:error, :invalid_config_format}
  end
end
```

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

**Testing concerns:**

```elixir
# BAD: Unclear test name
test "test1" do
  # ...
end

# GOOD: Descriptive test name
test "create_user/1 returns error when email is invalid" do
  # ...
end

# BAD: Testing too much at once
test "user workflow" do
  # Creates user
  # Updates user
  # Deletes user
  # All in one test!
end

# GOOD: Focused tests
test "create_user/1 creates user with valid attributes" do
  # ...
end

test "update_user/2 updates user name" do
  # ...
end

test "delete_user/1 removes user from database" do
  # ...
end

# BAD: Non-deterministic test
test "async operation completes" do
  start_async_operation()
  Process.sleep(100)  # Race condition!
  assert operation_completed?()
end

# GOOD: Deterministic test
test "async operation completes" do
  start_async_operation()
  assert_receive {:completed, _result}, 1000
end
```

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
