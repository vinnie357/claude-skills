# Ecto Data Shapes

One worked-example chain: the changeset-as-gatekeeper principle, then its continuation into
embedded schemas for non-DB data.

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
