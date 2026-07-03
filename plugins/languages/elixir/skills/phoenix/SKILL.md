---
name: phoenix
description: Guide for Phoenix web applications. Use when building Phoenix apps, implementing LiveView, designing contexts, setting up channels, or integrating Tidewave MCP dev tools.
---

# Phoenix Framework Development

This skill activates when working with Phoenix web applications, including setup, development, LiveView, contexts, controllers, and channels.

**Current versions**: Phoenix 1.8.x (current: 1.8.5), Phoenix LiveView 1.1.x (current: 1.1.27). Requires Elixir 1.14+, Erlang/OTP 25+.

## When to Use This Skill

Activate this skill when:
- Creating or modifying Phoenix applications
- Implementing LiveView components or pages
- Working with Phoenix contexts and business logic
- Building real-time features with channels or LiveView
- Configuring Phoenix routers, plugs, or endpoints
- Troubleshooting Phoenix-specific issues

## Phoenix Project Structure

Follow Phoenix conventions:

```
lib/
  my_app/           # Business logic and contexts
    accounts/       # Domain contexts
    repo.ex
  my_app_web/       # Web interface
    controllers/
    live/           # LiveView modules
    components/     # Function components
    router.ex
    endpoint.ex
```

## Runtime configuration

`config/runtime.exs` runs at every boot (dev, test, prod). Three settings have caused production outages when configured incorrectly:

### Phoenix Endpoint `:ip` bind config

The Endpoint's `:ip` bind tuple MUST be set at the TOP LEVEL of `runtime.exs`, env-driven, with a default of `{0, 0, 0, 0}` (all IPv4 interfaces). Do NOT gate it inside `if port = System.get_env("PORT") do ... end`, and do NOT override it later in a prod-only block that hardcodes `{0,0,0,0,0,0,0,0}` (IPv6 wildcard).

CORRECT:

```elixir
# config/runtime.exs (top level, unconditional)
bind_address =
  case System.get_env("BIND_ADDRESS", "0.0.0.0") do
    "0.0.0.0" -> {0, 0, 0, 0}
    "::" -> {0, 0, 0, 0, 0, 0, 0, 0}
    other -> other |> String.to_charlist() |> :inet.parse_address() |> elem(1)
  end

config :<app>, <App>Web.Endpoint, http: [ip: bind_address, port: ...]
```

WRONG (gates on PORT):

```elixir
if port = System.get_env("PORT") do
  config :<app>, <App>Web.Endpoint, http: [ip: {0, 0, 0, 0}, port: ...]
end
# Without PORT, Phoenix falls back to its default 127.0.0.1 — unreachable.
```

WRONG (later prod block clobbers env-driven setting):

```elixir
# Top-level env-driven config OK ...
if config_env() == :prod do
  config :<app>, <App>Web.Endpoint, http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, ...]
end
# IPv6 wildcard binds *:port IPv6 only — IPv4-only overlay networks (Tailscale on macOS) cannot reach it.
```

Default to IPv4 because most overlay networks route IPv4 first on macOS. Add IPv6 only when the deployment target explicitly requires it.

### PHX_HOST matches the public DNS name

Set `PHX_HOST` to the externally-resolvable hostname the load balancer presents to the browser. LiveView's websocket upgrade matches Origin against `PHX_HOST`; a mismatch causes the LiveView socket to fail with `403` and the page reverts to a dead static render.

### Dev-server restart after `lib/**/*.ex` changes

Phoenix live reload covers `.heex` / `.html.eex` templates and `assets/` reliably. It does NOT reliably pick up changes to:

- `lib/**/*.ex` — compiled Elixir modules
- `mix.exs` or any dependency change
- `config/*.exs`, especially `runtime.exs`
- NIFs, native deps, BEAM-level plugins
- DB migrations that change already-loaded schema

After any of those changes, restart the dev server (kill + relaunch the `mise run dev` session or equivalent). `/api/info`-style endpoints report the `git_sha` at server-start time, NOT the currently-compiled-in-memory code, and cannot distinguish stale-dev from fresh-dev. Restart is the only reliable signal.

## Context-Driven Design

Organize business logic into contexts (bounded domains):

### Creating Contexts

Generate contexts with related schemas:
```bash
mix phx.gen.context Accounts User users email:string name:string
```

Structure contexts to encapsulate business logic:

```elixir
defmodule MyApp.Accounts do
  @moduledoc """
  The Accounts context - manages user accounts and authentication.
  """

  alias MyApp.Repo
  alias MyApp.Accounts.User

  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end
end
```

### Context Best Practices

- Keep contexts focused on a single domain
- Avoid cross-context dependencies when possible
- Use public API functions, not direct Repo access in web layer
- Name contexts after business domains, not technical layers

## LiveView Development

LiveView enables rich, real-time experiences without writing JavaScript.

### LiveView Lifecycle

Understand the mount → handle_event → render cycle:

```elixir
defmodule MyAppWeb.UserLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Accounts

  @impl true
  def mount(_params, _session, socket) do
    # Runs on initial page load and live connection
    {:ok, assign(socket, :users, list_users())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Runs after mount and on live patch
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)

    {:noreply, assign(socket, :users, list_users())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.table rows={@users} id="users">
        <:col :let={user} label="Name"><%= user.name %></:col>
        <:col :let={user} label="Email"><%= user.email %></:col>
        <:action :let={user}>
          <.button phx-click="delete" phx-value-id={user.id}>Delete</.button>
        </:action>
      </.table>
    </div>
    """
  end

  defp list_users do
    Accounts.list_users()
  end
end
```

### LiveView Best Practices

- Use `mount/3` for initial data loading
- Handle route changes in `handle_params/3`
- Keep renders fast - compute in event handlers, not render
- Use `assign_new/3` for expensive computations
- Prefer LiveView over JavaScript for interactive UIs
- Use `phx-debounce` and `phx-throttle` for frequent events

### Function Components

Create reusable components:

```elixir
defmodule MyAppWeb.Components.UserCard do
  use Phoenix.Component

  attr :user, :map, required: true
  attr :class, :string, default: ""

  def user_card(assigns) do
    ~H"""
    <div class={"card " <> @class}>
      <h3><%= @user.name %></h3>
      <p><%= @user.email %></p>
    </div>
    """
  end
end
```

Use with `<.user_card user={@current_user} />` in templates.

### Form Handling

Use changesets for validation:

```elixir
@impl true
def mount(_params, _session, socket) do
  changeset = Accounts.change_user(%User{})
  {:ok, assign(socket, form: to_form(changeset))}
end

@impl true
def handle_event("validate", %{"user" => user_params}, socket) do
  changeset =
    %User{}
    |> Accounts.change_user(user_params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, form: to_form(changeset))}
end

@impl true
def handle_event("save", %{"user" => user_params}, socket) do
  case Accounts.create_user(user_params) do
    {:ok, user} ->
      {:noreply,
       socket
       |> put_flash(:info, "User created successfully")
       |> push_navigate(to: ~p"/users/#{user}")}

    {:error, %Ecto.Changeset{} = changeset} ->
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end

def render(assigns) do
  ~H"""
  <.form for={@form} phx-change="validate" phx-submit="save">
    <.input field={@form[:name]} label="Name" />
    <.input field={@form[:email]} label="Email" type="email" />
    <.button>Save</.button>
  </.form>
  """
end
```

## Routing

### Route Organization

Structure routes logically:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/users", UserLive.Index, :index
    live "/users/new", UserLive.Index, :new
    live "/users/:id", UserLive.Show, :show
  end

  scope "/api", MyAppWeb do
    pipe_through :api

    resources "/users", UserController, except: [:new, :edit]
  end
end
```

### LiveView Routes

Use live actions for modal/overlay states:

```elixir
live "/users", UserLive.Index, :index
live "/users/new", UserLive.Index, :new
live "/users/:id/edit", UserLive.Index, :edit
```

Then handle in `handle_params/3`:

```elixir
defp apply_action(socket, :edit, %{"id" => id}) do
  socket
  |> assign(:page_title, "Edit User")
  |> assign(:user, Accounts.get_user!(id))
end

defp apply_action(socket, :new, _params) do
  socket
  |> assign(:page_title, "New User")
  |> assign(:user, %User{})
end

defp apply_action(socket, :index, _params) do
  socket
  |> assign(:page_title, "Listing Users")
  |> assign(:user, nil)
end
```

## Channels and PubSub

### Phoenix Channels

For custom real-time protocols:

```elixir
defmodule MyAppWeb.RoomChannel do
  use MyAppWeb, :channel

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    if authorized?(socket, room_id) do
      {:ok, assign(socket, :room_id, room_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("new_msg", %{"body" => body}, socket) do
    broadcast!(socket, "new_msg", %{body: body, user: socket.assigns.user})
    {:noreply, socket}
  end
end
```

### Phoenix PubSub

For LiveView updates and process communication:

```elixir
# Subscribe in mount
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "users")
  end

  {:ok, assign(socket, :users, list_users())}
end

# Handle broadcasts
def handle_info({:user_created, user}, socket) do
  {:noreply, update(socket, :users, fn users -> [user | users] end)}
end

# Broadcast from context
def create_user(attrs) do
  with {:ok, user} <- do_create_user(attrs) do
    Phoenix.PubSub.broadcast(MyApp.PubSub, "users", {:user_created, user})
    {:ok, user}
  end
end
```

## Testing Phoenix Applications

### Controller Tests

```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase, async: true

  test "GET /users", %{conn: conn} do
    conn = get(conn, ~p"/users")
    assert html_response(conn, 200) =~ "Listing Users"
  end
end
```

### LiveView Tests

```elixir
defmodule MyAppWeb.UserLiveTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest

  test "displays users", %{conn: conn} do
    user = insert(:user)

    {:ok, view, html} = live(conn, ~p"/users")

    assert html =~ user.name
    assert has_element?(view, "#user-#{user.id}")
  end

  test "creates user", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/new")

    assert view
           |> form("#user-form", user: %{name: "Alice", email: "alice@example.com"})
           |> render_submit()

    assert_patch(view, ~p"/users")
  end
end
```

### Channel Tests

```elixir
defmodule MyAppWeb.RoomChannelTest do
  use MyAppWeb.ChannelCase

  test "broadcasts are pushed to the client", %{socket: socket} do
    {:ok, _, socket} = subscribe_and_join(socket, "room:lobby", %{})

    broadcast_from!(socket, "new_msg", %{body: "test"})
    assert_broadcast "new_msg", %{body: "test"}
  end
end
```

## Common Patterns

### Loading Associations

Preload associations efficiently:

```elixir
def list_posts do
  Post
  |> preload([:author, comments: :author])
  |> Repo.all()
end
```

### Pagination

Use Scrivener or custom pagination:

```elixir
def list_users(page \\ 1) do
  User
  |> order_by(desc: :inserted_at)
  |> Repo.paginate(page: page, page_size: 20)
end
```

### File Uploads

Handle uploads in LiveView:

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:uploaded_files, [])
   |> allow_upload(:avatar, accept: ~w(.jpg .jpeg .png), max_entries: 1)}
end

def handle_event("save", _params, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
      dest = Path.join("priv/static/uploads", Path.basename(path))
      File.cp!(path, dest)
      {:ok, "/uploads/" <> Path.basename(dest)}
    end)

  {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
end
```

## Performance Optimization

### Database Query Optimization

- Use `preload/2` to avoid N+1 queries
- Add database indexes for frequently queried fields
- Use `select/3` to load only needed fields
- Consider using `Repo.stream/2` for large datasets

### LiveView Performance

- Move expensive computations to `handle_event` or background jobs
- Use `assign_new/3` for computed values
- Implement `handle_continue/2` for async operations after mount
- Use temporary assigns for large lists: `assign(socket, :items, temporary: true)`

### Caching

Use Cachex or ETS for caching:

```elixir
def get_user!(id) do
  Cachex.fetch(:users, id, fn ->
    {:commit, Repo.get!(User, id)}
  end)
end
```

## Security Best Practices

- Always validate and sanitize user input through changesets
- Use CSRF protection (enabled by default)
- Implement rate limiting for APIs
- Use `put_secure_browser_headers` plug
- Validate file uploads (type, size, content)
- Use prepared statements (Ecto does this automatically)
- Implement proper authentication and authorization

## OpenAPI Contract-First

Define the OpenAPI spec for any HTTP API surface BEFORE implementing the controller. Clients (and Tier 2 test authors) generate from the spec; the implementation makes the spec true.

In Elixir, use `open_api_spex` for spec definitions:

```elixir
defmodule <App>Web.UserSpec do
  alias OpenApiSpex.{Schema, Operation}

  @user_schema %Schema{
    type: :object,
    required: [:id, :email],
    properties: %{
      id: %Schema{type: :integer},
      email: %Schema{type: :string, format: :email}
    }
  }
end
```

Wire the spec to the controller via `@spec` macros and serve it at `/api/openapi`. Tests assert response shapes against the spec rather than against hand-rolled JSON expectations; client SDKs regenerate from the spec on every spec change.

## Tidewave MCP Dev Tools

Tidewave connects AI coding assistants to running Phoenix applications via MCP, exposing runtime introspection tools (Ecto schemas, code execution, docs, logs, SQL queries).

Add to `mix.exs`: `{:tidewave, "~> 0.5", only: :dev}`

Add to `endpoint.ex` before `code_reloading?`: `plug Tidewave` (guarded by `if Mix.env() == :dev`)

Connect Claude Code: `claude mcp add --transport http tidewave http://localhost:4000/tidewave/mcp`

Tidewave is dev-only — never deploy to production. It only accepts localhost requests by default.

For full setup, MCP tools reference, CLI app, editor configs, LiveView annotations, and troubleshooting, load the `tidewave` skill or see `references/tidewave.md`.

## Key Principles

- **Context boundaries**: Keep business logic in contexts, not controllers/LiveViews
- **LiveView first**: Prefer LiveView over JavaScript for interactive features
- **Changesets for validation**: Always validate through Ecto changesets
- **Pub/Sub for communication**: Use Phoenix.PubSub for cross-process updates
- **Test at boundaries**: Test contexts, controllers, and LiveViews separately
- **Follow conventions**: Use Phoenix generators and follow established patterns
