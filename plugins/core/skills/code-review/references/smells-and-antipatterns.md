# Common Code Smells and Anti-Patterns

Named smells to recognize during review, and worked BAD/GOOD examples for three recurring anti-patterns.

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
