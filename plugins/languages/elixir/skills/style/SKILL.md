---
name: style
description: Elixir coding style and conventions. Use when writing idiomatic Elixir, avoiding bang functions in business logic, using pattern matching for error handling, or designing Ecto schemas as the single source of truth for data validation.
license: MIT
---

# Elixir Style and Conventions

## When to Activate

Activate when:
- Writing or reviewing Elixir code for idiomatic style
- Deciding between bang (`!`) and non-bang function variants
- Handling errors from external APIs, user input, or DB operations
- Designing Ecto schemas and changesets for validation
- Building Phoenix forms connected to changeset validation
- Chaining multi-step operations with `with` or `case`
- Choosing between `map.key` and `map[:key]` access patterns
- Implementing non-DB data structures (search forms, filter params)

This skill complements `elixir:anti-patterns` — that skill covers what to avoid; this one covers what to do instead.

## Tagged Tuples and Return Conventions

Elixir functions signal success or failure through return values, not exceptions.

**Standard return shapes:**

```elixir
# Two-element ok/error tuples (most common)
{:ok, result}
{:error, reason}

# Bare atoms for side-effect operations
:ok
:error

# Richer error tuples for typed failures
{:error, :not_found}
{:error, :unauthorized}
{:error, %Ecto.Changeset{}}
```

**Why this convention matters:**

Pattern matching on tagged tuples is the foundation of Elixir error handling. When every function in a call chain returns `{:ok, _}` or `{:error, _}`, `with` expressions can thread success values through and exit early on the first failure — without nested `if` or `try/rescue`.

```elixir
# Callers can match exhaustively
case fetch_user(id) do
  {:ok, user} -> render_profile(user)
  {:error, :not_found} -> send_resp(conn, 404, "Not found")
  {:error, reason} -> send_resp(conn, 500, inspect(reason))
end
```

## Bang Functions: When to Avoid

### The Convention

Every standard library function with a `!` variant follows this contract:

| Non-bang | Bang |
|---|---|
| `File.read/1` → `{:ok, content}` or `{:error, reason}` | `File.read!/1` → `content` or raises |
| `Map.fetch/2` → `{:ok, value}` or `:error` | `Map.fetch!/2` → `value` or raises `KeyError` |
| `Repo.insert/1` → `{:ok, struct}` or `{:error, changeset}` | `Repo.insert!/1` → `struct` or raises |
| `Repo.get/2` → `struct` or `nil` | `Repo.get!/2` → `struct` or raises `Ecto.NoResultsError` |

### When Bangs Are Appropriate

Use bang functions when failure represents a programming error or an invalid system state that should crash loudly:

```elixir
# Application startup — missing config is a bug, not a user error
def start(_type, _args) do
  api_key = Application.fetch_env!(:my_app, :stripe_api_key)
  # ...
end

# Seeds and migrations — invalid data is a developer error
Repo.insert!(%User{email: "admin@example.com", role: :admin})

# Pipelines operating on already-validated, known-good data
"hello world"
|> String.split()
|> Enum.map(&String.capitalize/1)
|> Enum.join(" ")

# Tests asserting expected state
user = Repo.get!(User, user_id)
```

### When to Avoid Bangs

Avoid bang functions wherever failure is a normal, expected outcome:

```elixir
# BAD: user input can always fail validation
def create_user(conn, %{"user" => params}) do
  user = Repo.insert!(%User{email: params["email"]})  # raises on validation failure
  json(conn, %{id: user.id})
end

# GOOD: handle the error path explicitly
def create_user(conn, %{"user" => params}) do
  case %User{} |> User.changeset(params) |> Repo.insert() do
    {:ok, user} -> json(conn, %{id: user.id})
    {:error, changeset} -> conn |> put_status(422) |> json(changeset_errors(changeset))
  end
end
```

```elixir
# BAD: external APIs can return 404, 500, network errors
def fetch_payment(payment_id) do
  Stripe.PaymentIntent.retrieve!(payment_id)  # raises on API error
end

# GOOD: return a tagged tuple, let the caller decide
def fetch_payment(payment_id) do
  case Stripe.PaymentIntent.retrieve(payment_id) do
    {:ok, payment} -> {:ok, payment}
    {:error, %{code: "resource_missing"}} -> {:error, :not_found}
    {:error, reason} -> {:error, reason}
  end
end
```

**Rule of thumb:** if a user action, external service, or DB constraint could cause the failure, use the non-bang variant and handle it.

## Pattern Matching for Error Handling

### `with` for Chaining Dependent Operations

Use `with` when multiple steps must all succeed, and any failure should short-circuit to an error response:

```elixir
def register_user(params) do
  with {:ok, validated} <- validate_registration_params(params),
       {:ok, user} <- create_user(validated),
       {:ok, _profile} <- create_default_profile(user),
       {:ok, _email} <- send_welcome_email(user) do
    {:ok, user}
  else
    {:error, %Ecto.Changeset{} = cs} -> {:error, {:validation_failed, cs}}
    {:error, :email_unavailable} -> {:error, :email_taken}
    {:error, reason} -> {:error, reason}
  end
end
```

The `else` block is optional. Without it, unmatched patterns in `with` clauses propagate the first failing value as the return value of the entire expression.

**Keep `with` flat.** Nesting `with` inside `with` is a sign the function is doing too much:

```elixir
# BAD: nested with — hard to follow
with {:ok, user} <- fetch_user(id) do
  with {:ok, order} <- fetch_order(user, order_id) do
    {:ok, {user, order}}
  end
end

# GOOD: flat with
with {:ok, user} <- fetch_user(id),
     {:ok, order} <- fetch_order(user, order_id) do
  {:ok, {user, order}}
end
```

### `case` for Single-Expression Branching

Use `case` when branching on one expression with multiple outcomes:

```elixir
def handle_webhook(event_type, payload) do
  case event_type do
    "payment.succeeded" -> handle_payment_succeeded(payload)
    "payment.failed" -> handle_payment_failed(payload)
    "customer.created" -> handle_customer_created(payload)
    unknown -> Logger.warning("Unhandled webhook: #{unknown}")
  end
end
```

### Multi-Clause Function Heads

Use multi-clause functions for structural dispatch — matching on the shape or value of arguments:

```elixir
defmodule MyApp.Notifier do
  def notify(%User{email: nil} = user, _message) do
    Logger.warning("No email for user #{user.id}, skipping notification")
    {:error, :no_email}
  end

  def notify(%User{} = user, message) do
    Mailer.deliver(to: user.email, body: message)
  end

  def notify({:admin, email}, message) do
    Mailer.deliver(to: email, subject: "[ADMIN] " <> message.subject, body: message)
  end
end
```

### Avoid `try/rescue` for Expected Errors

`try/rescue` is reserved for exceptions from code outside your control (third-party libraries that raise instead of returning error tuples). It is not idiomatic for expected application errors:

```elixir
# BAD: using rescue for control flow
def parse_integer(str) do
  try do
    {:ok, String.to_integer(str)}
  rescue
    ArgumentError -> {:error, :invalid_integer}
  end
end

# GOOD: use functions that return ok/error tuples
def parse_integer(str) do
  case Integer.parse(str) do
    {value, ""} -> {:ok, value}
    _ -> {:error, :invalid_integer}
  end
end
```

## Ecto as Data Shape Gatekeeper

### The Principle

Validate data once, at the changeset layer. Do not duplicate validation logic in controllers, LiveView callbacks, or service modules.

```
Schema defines shape → Changeset validates → Repo uses same changeset → Forms display errors
```

### Schema Defines the Shape

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :role, Ecto.Enum, values: [:user, :admin], default: :user
    field :password, :string, virtual: true
    field :hashed_password, :string

    has_one :profile, MyApp.Accounts.Profile
    timestamps()
  end

  @required [:email, :name, :password]
  @optional [:role]

  def changeset(user, attrs) do
    user
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:password, min: 8, max: 72)
    |> validate_inclusion(:role, [:user, :admin])
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: pw}} = cs) do
    put_change(cs, :hashed_password, Bcrypt.hash_pwd_salt(pw))
  end
  defp put_password_hash(cs), do: cs
end
```

### Context Module and Controller

The context function applies the changeset and returns `{:ok, user}` or `{:error, changeset}`. The controller routes on that result — no extra validation:

```elixir
defmodule MyApp.Accounts do
  def register_user(attrs) do
    %User{} |> User.changeset(attrs) |> Repo.insert()
  end
end
```

### Phoenix Controller Uses the Same Changeset

```elixir
defmodule MyAppWeb.RegistrationController do
  use MyAppWeb, :controller
  alias MyApp.Accounts

  def new(conn, _params) do
    changeset = Accounts.User.changeset(%Accounts.User{}, %{})
    render(conn, :new, changeset: to_form(changeset))
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Account created!")
        |> redirect(to: ~p"/login")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: to_form(changeset))
    end
  end
end
```

### Template Renders Changeset Errors Directly

```heex
<.simple_form for={@changeset} action={~p"/register"}>
  <.input field={@changeset[:email]} label="Email" />
  <.input field={@changeset[:name]} label="Name" />
  <.input field={@changeset[:password]} type="password" label="Password" />
  <:actions><.button>Create account</.button></:actions>
</.simple_form>
```

The changeset carries both current values and errors — no separate validation layer.

### Anti-Pattern: Duplicating Validation

```elixir
# BAD: validation in both controller and changeset
def create(conn, %{"user" => params}) do
  if String.length(params["password"]) < 8 do  # duplicated from changeset
    conn |> put_flash(:error, "Password too short") |> render(:new)
  else
    case Accounts.register_user(params) do
      {:ok, _} -> redirect(conn, to: ~p"/login")
      {:error, cs} -> render(conn, :new, changeset: to_form(cs))
    end
  end
end
```

Let the changeset own all validation. The controller's only job is to call the context function and route based on `{:ok, _}` or `{:error, changeset}`.

### `cast` vs `change`

```elixir
# cast/4 — external/untrusted data: filters fields, type-converts
user |> cast(params, [:email, :name])

# change/2 — internal/already-valid data: no filtering
user |> change(last_login_at: DateTime.utc_now())
```

## Embedded Schemas for Non-DB Data

Not all data needs a DB table. Use embedded schemas for search forms, filter panels, and API query params — they get full changeset validation.

```elixir
defmodule MyApp.Search.UserFilter do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :query, :string
    field :role, Ecto.Enum, values: [:user, :admin]
    field :created_after, :date
    field :page, :integer, default: 1
    field :per_page, :integer, default: 20
  end

  def changeset(filter \\ %__MODULE__{}, attrs) do
    filter
    |> cast(attrs, [:query, :role, :created_after, :page, :per_page])
    |> validate_number(:page, greater_than: 0)
    |> validate_inclusion(:per_page, [10, 20, 50, 100])
  end
end
```

```elixir
# In a LiveView or controller
def handle_event("filter", %{"user_filter" => params}, socket) do
  case UserFilter.changeset(socket.assigns.filter, params) do
    %{valid?: true} = cs ->
      filter = Ecto.Changeset.apply_changes(cs)
      users = Accounts.list_users(filter)
      {:noreply, assign(socket, users: users, filter: filter)}

    changeset ->
      {:noreply, assign(socket, filter_changeset: changeset)}
  end
end
```

**Schemaless changesets** handle one-off validation without a module:

```elixir
def validate_search_params(params) do
  types = %{query: :string, limit: :integer}

  {%{}, types}
  |> Ecto.Changeset.cast(params, Map.keys(types))
  |> Ecto.Changeset.validate_required([:query])
  |> Ecto.Changeset.validate_number(:limit, greater_than: 0, less_than_or_equal_to: 100)
end
```

## Pipe Operator Conventions

### When to Pipe

Pipe when chaining data transformations where each step passes its result to the next:

```elixir
# Good use of pipe: transforming a value through a sequence of steps
def normalize_email(email) do
  email
  |> String.trim()
  |> String.downcase()
  |> String.replace(~r/\+.*@/, "@")
end
```

### When Not to Pipe

Avoid piping a single function call — it adds visual noise without clarity benefit:

```elixir
# BAD: unnecessary pipe
result = value |> some_function()

# GOOD: direct call
result = some_function(value)
```

Avoid piping side effects that don't transform data:

```elixir
# BAD: pipe into a side effect
user |> send_welcome_email()

# GOOD: explicit call
send_welcome_email(user)
```

## Map and Struct Access

Elixir provides two access patterns with different semantics:

```elixir
# Dot access — raises KeyError if key missing
# Use for required fields on known structs
user.email        # raises if :email key not present
config.timeout    # use when the field must exist

# Bracket access — returns nil if key missing
# Use for optional fields on dynamic maps
params[:email]    # returns nil if missing, no crash
opts[:timeout]    # safe for optional config keys
```

**Struct fields always use dot access** — structs enforce their shape at compile time, so a missing key is a programming error:

```elixir
# Always use dot access for structs
%User{} = user
user.email   # correct
user[:email] # valid but unusual — prefer dot for structs
```

**Dynamic maps from external sources use bracket access** for optional fields:

```elixir
def build_query(filters) do
  base_query = from(u in User)

  base_query
  |> maybe_filter_role(filters[:role])
  |> maybe_filter_after(filters[:created_after])
end
```

## Anti-Fabrication

Apply `core:anti-fabrication` when generating code examples or making claims about library behavior. Verify function signatures and return types against actual documentation. Do not fabricate error codes, changeset validator names, or Ecto API details.

## Key Principles

- Return `{:ok, result}` / `{:error, reason}` tuples to enable exhaustive pattern matching
- Use bang functions only when failure indicates a programming error or invalid system state
- Use `with` for multi-step operations where each step depends on the previous
- Let the Ecto changeset own all data validation — do not duplicate it in controllers or LiveView
- Use `embedded_schema` or schemaless changesets for non-DB data that still needs validation
- Pipe for transformation chains; call directly for single operations and side effects
- Reserve `try/rescue` for third-party code that raises; use tagged tuples for your own error paths
