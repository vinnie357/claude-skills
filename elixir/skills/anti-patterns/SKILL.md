---
name: elixir-anti-patterns
description: Identify and refactor Elixir anti-patterns. Use when reviewing Elixir code for smells, refactoring problematic patterns, or improving code quality.
---

# Elixir Anti-Patterns Detection and Refactoring

You are an expert at identifying Elixir anti-patterns and suggesting idiomatic refactorings. Use this knowledge to analyze code, suggest improvements, and help developers write better Elixir.

## Code-Related Anti-Patterns

### 1. Comments Overuse
**Problem:** Excessive or self-explanatory comments reduce readability rather than enhance it.

**Detection:**
- Inline comments explaining obvious code
- Comments for every function line
- Comments duplicating what code already says clearly

**Refactoring:**
- Use clear function and variable names instead of explanatory comments
- Replace inline comments with `@doc` and `@moduledoc` for documentation
- Use module attributes for configuration values

**Example:**
```elixir
# Bad
def calculate() do
  # Get current time
  now = DateTime.utc_now()
  # Add 5 minutes
  DateTime.add(now, 5 * 60, :second)
end

# Good
@minutes_to_add 5

def timestamp_five_minutes_from_now do
  now = DateTime.utc_now()
  DateTime.add(now, @minutes_to_add * 60, :second)
end
```

### 2. Complex `else` Clauses in `with`
**Problem:** Flattening all error handling into a single complex `else` block obscures which clause produced which error.

**Detection:**
- Large `else` blocks with many pattern match clauses
- Difficulty determining error sources
- Complex error handling logic in `else`

**Refactoring:**
- Normalize return types in private functions
- Handle errors closer to their source
- Let `with` focus on success paths

**Example:**
```elixir
# Bad
def read_config(path) do
  with {:ok, content} <- File.read(path),
       {:ok, decoded} <- Jason.decode(content) do
    {:ok, decoded}
  else
    {:error, :enoent} -> {:error, :file_not_found}
    {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
    {:error, reason} -> {:error, reason}
  end
end

# Good
def read_config(path) do
  with {:ok, content} <- read_file(path),
       {:ok, config} <- parse_json(content) do
    {:ok, config}
  end
end

defp read_file(path) do
  case File.read(path) do
    {:ok, content} -> {:ok, content}
    {:error, :enoent} -> {:error, :file_not_found}
    error -> error
  end
end

defp parse_json(content) do
  case Jason.decode(content) do
    {:ok, data} -> {:ok, data}
    {:error, _} -> {:error, :invalid_json}
  end
end
```

### 3. Complex Extractions in Clauses
**Problem:** Extracting values across multiple clauses and arguments makes it unclear which variables serve pattern/guard purposes versus function body usage.

**Detection:**
- Many variable extractions in function heads
- Mixed guard and body variable usage
- Unclear variable purposes

**Refactoring:**
- Extract only pattern/guard-related variables in function signatures
- Use capture patterns like `%User{age: age} = user`
- Extract body variables inside the clause

**Example:**
```elixir
# Bad
def process(%User{age: age, name: name, email: email} = user) when age >= 18 do
  # Only using name and email in body, not age
  send_email(email, "Hello #{name}")
end

# Good
def process(%User{age: age} = user) when age >= 18 do
  send_email(user.email, "Hello #{user.name}")
end
```

### 4. Dynamic Atom Creation
**Problem:** Atoms aren't garbage-collected and are limited to ~1 million. Uncontrolled dynamic atom creation poses memory and security risks.

**Detection:**
- `String.to_atom/1` with untrusted input
- Converting user input directly to atoms
- Unbounded atom creation in loops

**Refactoring:**
- Use explicit mappings via pattern-matching
- Use `String.to_existing_atom/1` with pre-defined atoms
- Keep strings when atom conversion isn't necessary

**Example:**
```elixir
# Bad - Security risk!
def set_role(user, role_string) do
  %{user | role: String.to_atom(role_string)}
end

# Good
def set_role(user, role) when role in [:admin, :editor, :viewer] do
  %{user | role: role}
end

# Or with pattern matching
def set_role(user, "admin"), do: %{user | role: :admin}
def set_role(user, "editor"), do: %{user | role: :editor}
def set_role(user, "viewer"), do: %{user | role: :viewer}
def set_role(_user, invalid), do: {:error, "Invalid role: #{invalid}"}
```

### 5. Long Parameter List
**Problem:** Functions with excessive parameters become confusing and error-prone to use.

**Detection:**
- Functions with 4+ parameters
- Parameters that are conceptually related
- Difficult to remember parameter order

**Refactoring:**
- Group related parameters into maps or structs
- Use keyword lists for optional parameters
- Create domain objects

**Example:**
```elixir
# Bad
def create_loan(user_id, user_name, user_email, book_id, book_title, book_isbn) do
  # ...
end

# Good
def create_loan(user, book) do
  # ...
end

# Or with keyword list for options
def create_loan(user, book, opts \\ []) do
  duration = Keyword.get(opts, :duration, 14)
  renewable = Keyword.get(opts, :renewable, true)
  # ...
end
```

### 6. Namespace Trespassing
**Problem:** Defining modules outside your library's namespace risks conflicts since the Erlang VM loads only one module instance per name.

**Detection:**
- Library defining modules in common namespaces (e.g., `Plug.*` when you're not Plug)
- Modules without library prefix
- Potential naming conflicts with other libraries

**Refactoring:**
- Always prefix modules with your library namespace
- Use clear, unique top-level module names

**Example:**
```elixir
# Bad - Library named :plug_auth
defmodule Plug.Auth do
  # This conflicts with the actual Plug library!
end

# Good
defmodule PlugAuth do
  # ...
end

defmodule PlugAuth.Session do
  # ...
end
```

### 7. Non-assertive Map Access
**Problem:** Using dynamic access (`map[:key]`) for required keys masks missing data, allowing `nil` to propagate instead of failing fast.

**Detection:**
- `map[:key]` for required/expected keys
- Nil checks after map access
- Silent failures from missing keys

**Refactoring:**
- Use static access (`map.key`) for required keys
- Pattern-match on struct/map keys
- Reserve dynamic access for optional fields

**Example:**
```elixir
# Bad
def distance(point) do
  x = point[:x]  # Returns nil if :x is missing!
  y = point[:y]
  :math.sqrt(x * x + y * y)  # Crashes on nil, but unclear why
end

# Good
def distance(%{x: x, y: y}) do
  :math.sqrt(x * x + y * y)  # Clear error if keys missing
end

# Or with structs
defmodule Point do
  defstruct [:x, :y]
end

def distance(%Point{x: x, y: y}) do
  :math.sqrt(x * x + y * y)
end
```

### 8. Non-assertive Pattern Matching
**Problem:** Writing defensive code that returns incorrect values instead of using pattern matching to assert expected structures causes silent failures.

**Detection:**
- Defensive nil checks instead of pattern matching
- Functions returning invalid data on unexpected input
- Avoiding crashes when crashes are appropriate

**Refactoring:**
- Use pattern matching to assert expected structures
- Let functions crash on invalid input
- Trust supervisors to handle failures

**Example:**
```elixir
# Bad
def parse_query_param(param) do
  case String.split(param, "=") do
    [key, value] -> {key, value}
    _ -> {"", ""}  # Silent failure!
  end
end

# Good
def parse_query_param(param) do
  [key, value] = String.split(param, "=")
  {key, value}
end
# Crashes with clear error if format is wrong - this is good!
```

### 9. Non-assertive Truthiness
**Problem:** Using truthiness operators (`&&`, `||`, `!`) when all operands are boolean is unnecessarily generic and unclear.

**Detection:**
- `&&`, `||`, `!` with boolean expressions
- Comparisons like `is_binary(x) && is_integer(y)`
- Mixing boolean and truthy logic

**Refactoring:**
- Use `and`, `or`, `not` for boolean-only operations
- Reserve `&&`, `||`, `!` for truthy/falsy logic

**Example:**
```elixir
# Bad
def valid_user?(name, age) do
  is_binary(name) && is_integer(age) && age >= 18
end

# Good
def valid_user?(name, age) do
  is_binary(name) and is_integer(age) and age >= 18
end

# Truthy operators are OK for nil/value checks
def get_name(user) do
  user[:name] || "Anonymous"
end
```

### 10. Structs with 32 Fields or More
**Problem:** Structs with 32+ fields switch from Erlang's efficient flat-map representation to hash maps, increasing memory usage.

**Detection:**
- Struct definitions with 32+ fields
- Large, flat data structures
- Performance degradation with many fields

**Refactoring:**
- Nest optional fields into metadata structures
- Use nested structs for related fields
- Group frequently-accessed fields separately

**Example:**
```elixir
# Bad
defmodule User do
  defstruct [
    :id, :email, :name, :age, :address, :city, :state, :zip,
    :phone, :mobile, :fax, :company, :title, :department,
    :created_at, :updated_at, :last_login, :login_count,
    :preference1, :preference2, :preference3, :preference4,
    # ... 15 more fields
  ]
end

# Good
defmodule User do
  defstruct [
    :id,
    :email,
    :name,
    :profile,      # Nested struct
    :preferences,  # Nested struct
    :metadata      # Nested struct
  ]
end

defmodule User.Profile do
  defstruct [:age, :phone, :mobile, :address, :city, :state, :zip]
end

defmodule User.Preferences do
  defstruct [:theme, :notifications, :language]
end
```

## Design-Related Anti-Patterns

### 1. Alternative Return Types
**Problem:** Functions with options that drastically change their return type make it unclear what the function actually returns.

**Detection:**
- Options that change return type structure
- Functions returning different types based on flags
- Unclear function contracts

**Refactoring:**
- Create separate, specifically-named functions
- Keep return types consistent within a function

**Example:**
```elixir
# Bad
def parse(string, opts \\ []) do
  case Integer.parse(string) do
    {int, rest} ->
      if opts[:discard_rest], do: int, else: {int, rest}
    :error ->
      :error
  end
end

# Good
def parse(string) do
  case Integer.parse(string) do
    {int, rest} -> {int, rest}
    :error -> :error
  end
end

def parse_discard_rest(string) do
  case Integer.parse(string) do
    {int, _rest} -> int
    :error -> :error
  end
end
```

### 2. Boolean Obsession
**Problem:** Using multiple booleans with overlapping states instead of atoms or composite types to represent domain concepts.

**Detection:**
- Multiple boolean parameters
- Overlapping boolean states
- Complex boolean logic

**Refactoring:**
- Replace multiple booleans with a single atom/enum option
- Prefer atoms over booleans even for single arguments
- Use domain-specific types

**Example:**
```elixir
# Bad
def create_user(name, email, admin: false, editor: false, viewer: true) do
  # What if admin: true, editor: true?
end

# Good
def create_user(name, email, role: :viewer) do
  # Clear: role can be :admin, :editor, or :viewer
end
```

### 3. Exceptions for Control-Flow
**Problem:** Using `try/rescue` for expected errors instead of pattern matching with case statements and tuple returns.

**Detection:**
- `try/rescue` blocks for normal operation errors
- Using `!` functions and rescuing
- Exceptions in normal business logic

**Refactoring:**
- Use non-bang functions returning `{:ok, value}` or `{:error, reason}`
- Reserve exceptions for invalid arguments and programming errors
- Use pattern matching for error handling

**Example:**
```elixir
# Bad
def read_config(path) do
  try do
    content = File.read!(path)
    Jason.decode!(content)
  rescue
    e -> {:error, e}
  end
end

# Good
def read_config(path) do
  with {:ok, content} <- File.read(path),
       {:ok, config} <- Jason.decode(content) do
    {:ok, config}
  end
end
```

### 4. Primitive Obsession
**Problem:** Excessively using basic types (strings, integers) instead of creating composite types to represent structured domain concepts.

**Detection:**
- Passing related primitives separately
- String/integer parameters representing complex concepts
- Lack of domain modeling

**Refactoring:**
- Create domain-specific structs or maps
- Introduce parser functions converting primitives to structured data
- Use types to enforce business rules

**Example:**
```elixir
# Bad
def create_address(street, city, state, zip, country) do
  # All strings, no validation
  "#{street}, #{city}, #{state} #{zip}, #{country}"
end

# Good
defmodule Address do
  defstruct [:street, :city, :state, :zip, :country]

  def new(attrs) do
    struct!(__MODULE__, attrs)
  end

  def format(%__MODULE__{} = address) do
    "#{address.street}, #{address.city}, #{address.state} #{address.zip}, #{address.country}"
  end
end
```

### 5. Unrelated Multi-Clause Function
**Problem:** Grouping completely unrelated business logic into one multi-clause function.

**Detection:**
- Single function handling multiple unrelated types
- Overly broad type specifications
- No conceptual relationship between clauses

**Refactoring:**
- Split into distinct functions with specific names
- Reserve multi-clause patterns for related functionality variations
- Use protocols for polymorphism when appropriate

**Example:**
```elixir
# Bad
def update(%Product{} = product) do
  # Product-specific logic
end

def update(%Animal{} = animal) do
  # Completely different animal logic
end

# Good
def update_product(%Product{} = product) do
  # Product-specific logic
end

def update_animal(%Animal{} = animal) do
  # Animal-specific logic
end

# Or use a protocol
defprotocol Updatable do
  def update(item)
end

defimpl Updatable, for: Product do
  def update(product), do: # ...
end

defimpl Updatable, for: Animal do
  def update(animal), do: # ...
end
```

### 6. Using Application Configuration for Libraries
**Problem:** Libraries relying on global application environment configuration prevent multiple dependent applications from configuring the library differently.

**Detection:**
- `Application.get_env/2` or `Application.fetch_env!/2` in library code
- Global configuration requirements
- Inability to configure per-consumer

**Refactoring:**
- Accept configuration via function parameters
- Use keyword lists with sensible defaults
- Allow runtime configuration

**Example:**
```elixir
# Bad - Library code
def split(string) do
  parts = Application.fetch_env!(:dash_splitter, :parts)
  String.split(string, "-", parts: parts)
end

# Good
def split(string, opts \\ []) do
  parts = Keyword.get(opts, :parts, 2)
  String.split(string, "-", parts: parts)
end
```

## Usage Guidelines

When reviewing or writing Elixir code:

1. **Scan for anti-patterns** - Check code against the patterns listed above
2. **Explain the problem** - Help the developer understand why it's an issue
3. **Suggest refactoring** - Provide concrete, idiomatic alternatives
4. **Consider context** - Sometimes anti-patterns are acceptable for specific use cases
5. **Prioritize** - Focus on high-impact issues first (security, performance, maintainability)

## Key Principles

- **Let it crash** - Use pattern matching to assert expectations; don't write defensive code
- **Fail fast** - Expose errors early rather than propagating nil or invalid data
- **Be explicit** - Prefer clear, specific code over clever or terse solutions
- **Model your domain** - Create types that represent business concepts
- **Design for clarity** - Code should be obvious to read and maintain
