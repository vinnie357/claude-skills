# Design-Related Anti-Patterns

## 1. Alternative Return Types
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

## 2. Boolean Obsession
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

## 3. Exceptions for Control-Flow
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

## 4. Primitive Obsession
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

## 5. Unrelated Multi-Clause Function
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

## 6. Using Application Configuration for Libraries
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
