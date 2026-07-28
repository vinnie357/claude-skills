# API Documentation

Patterns for documenting functions, modules, and REST endpoints across languages.

## Documenting Functions

**Elixir (@doc):**
```elixir
@doc """
Calculates the sum of two numbers.

## Parameters

- `a` - The first number (integer or float)
- `b` - The second number (integer or float)

## Returns

The sum of `a` and `b`.

## Examples

    iex> Math.add(2, 3)
    5

    iex> Math.add(2.5, 3.7)
    6.2

"""
@spec add(number(), number()) :: number()
def add(a, b) do
  a + b
end
```

**JavaScript (JSDoc):**
```javascript
/**
 * Calculates the sum of two numbers.
 *
 * @param {number} a - The first number
 * @param {number} b - The second number
 * @returns {number} The sum of a and b
 *
 * @example
 * add(2, 3)
 * // => 5
 */
function add(a, b) {
  return a + b
}
```

**Python (docstring):**
```python
def add(a: float, b: float) -> float:
    """
    Calculate the sum of two numbers.

    Args:
        a: The first number
        b: The second number

    Returns:
        The sum of a and b

    Examples:
        >>> add(2, 3)
        5
        >>> add(2.5, 3.7)
        6.2

    Raises:
        TypeError: If arguments are not numbers
    """
    return a + b
```

**Rust (doc comments):**
```rust
/// Calculates the sum of two numbers.
///
/// # Arguments
///
/// * `a` - The first number
/// * `b` - The second number
///
/// # Returns
///
/// The sum of `a` and `b`
///
/// # Examples
///
/// ```
/// use mylib::add;
///
/// assert_eq!(add(2, 3), 5);
/// assert_eq!(add(2.5, 3.7), 6.2);
/// ```
pub fn add(a: f64, b: f64) -> f64 {
    a + b
}
```

## Module/Class Documentation

Document the purpose, usage, and public API:

```elixir
defmodule MyApp.UserManager do
  @moduledoc """
  Manages user accounts and authentication.

  The UserManager provides functions for creating, updating, and authenticating
  users. It handles password hashing, session management, and user validation.

  ## Usage

      # Create a new user
      {:ok, user} = UserManager.create_user(%{
        email: "alice@example.com",
        password: "secure_password"
      })

      # Authenticate
      {:ok, user} = UserManager.authenticate("alice@example.com", "secure_password")

      # Update user
      {:ok, updated} = UserManager.update_user(user, %{name: "Alice Smith"})

  ## Configuration

  Configure in `config/config.exs`:

      config :my_app, MyApp.UserManager,
        password_min_length: 8,
        session_timeout: 3600

  """
end
```

## API Endpoint Documentation

Document RESTful APIs clearly:

```markdown
## Endpoints

### Create User

Creates a new user account.

**Endpoint:** `POST /api/users`

**Authentication:** Not required

**Request Body:**

```json
{
  "email": "alice@example.com",
  "password": "secure_password",
  "name": "Alice Smith"
}
```

**Response (201 Created):**

```json
{
  "id": "123",
  "email": "alice@example.com",
  "name": "Alice Smith",
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Error Responses:**

- `400 Bad Request` - Invalid input
  ```json
  {
    "error": "validation_error",
    "details": {
      "email": ["must be a valid email address"],
      "password": ["must be at least 8 characters"]
    }
  }
  ```

- `409 Conflict` - Email already exists
  ```json
  {
    "error": "email_taken",
    "message": "An account with this email already exists"
  }
  ```

**Example:**

```bash
curl -X POST https://api.example.com/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@example.com",
    "password": "secure_password",
    "name": "Alice Smith"
  }'
```
```
