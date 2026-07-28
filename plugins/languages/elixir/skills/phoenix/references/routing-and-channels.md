# Routing, Channels, and PubSub

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
