# Phoenix Testing

Controller, LiveView, and Channel test patterns for Phoenix applications. See the `/elixir:testing` skill body for ExUnit basics, database testing, and mocking that these examples build on.

## Controller Tests

```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase
  import MyApp.Factory

  describe "index" do
    test "lists all users", %{conn: conn} do
      user = insert(:user)

      conn = get(conn, ~p"/users")

      assert html_response(conn, 200) =~ "Listing Users"
      assert html_response(conn, 200) =~ user.name
    end
  end

  describe "create" do
    test "creates user with valid data", %{conn: conn} do
      attrs = %{name: "Alice", email: "alice@example.com"}

      conn = post(conn, ~p"/users", user: attrs)

      assert redirected_to(conn) =~ ~p"/users"

      conn = get(conn, redirected_to(conn))
      assert html_response(conn, 200) =~ "Alice"
    end

    test "renders errors with invalid data", %{conn: conn} do
      conn = post(conn, ~p"/users", user: %{})

      assert html_response(conn, 200) =~ "New User"
    end
  end
end
```

## LiveView Tests

```elixir
defmodule MyAppWeb.UserLiveTest do
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest
  import MyApp.Factory

  describe "Index" do
    test "displays users", %{conn: conn} do
      user = insert(:user)

      {:ok, view, html} = live(conn, ~p"/users")

      assert html =~ "Listing Users"
      assert has_element?(view, "#user-#{user.id}")
      assert render(view) =~ user.name
    end

    test "creates new user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/new")

      assert view
             |> form("#user-form", user: %{name: "Alice", email: "alice@example.com"})
             |> render_submit()

      assert_patch(view, ~p"/users")

      html = render(view)
      assert html =~ "Alice"
    end

    test "updates user", %{conn: conn} do
      user = insert(:user)

      {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/edit")

      assert view
             |> form("#user-form", user: %{name: "Updated Name"})
             |> render_submit()

      assert_patch(view, ~p"/users/#{user.id}")

      html = render(view)
      assert html =~ "Updated Name"
    end

    test "deletes user", %{conn: conn} do
      user = insert(:user)

      {:ok, view, _html} = live(conn, ~p"/users")

      assert view
             |> element("#user-#{user.id} a", "Delete")
             |> render_click()

      refute has_element?(view, "#user-#{user.id}")
    end
  end

  describe "form validation" do
    test "validates on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/new")

      result =
        view
        |> form("#user-form", user: %{email: "invalid"})
        |> render_change()

      assert result =~ "must have the @ sign"
    end
  end

  describe "real-time updates" do
    test "receives updates from PubSub", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users")

      user = insert(:user)

      # Trigger PubSub event
      Phoenix.PubSub.broadcast(MyApp.PubSub, "users", {:user_created, user})

      assert render(view) =~ user.name
    end
  end
end
```

## Channel Tests

```elixir
defmodule MyAppWeb.RoomChannelTest do
  use MyAppWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      MyAppWeb.UserSocket
      |> socket("user_id", %{user_id: 42})
      |> subscribe_and_join(MyAppWeb.RoomChannel, "room:lobby")

    %{socket: socket}
  end

  test "ping replies with pong", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to room:lobby", %{socket: socket} do
    push(socket, "shout", %{"hello" => "all"})
    assert_broadcast "shout", %{"hello" => "all"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end
end
```
