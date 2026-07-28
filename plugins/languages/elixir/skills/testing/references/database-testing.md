# Database Testing

Factories and changeset test patterns. See the `/elixir:testing` skill body's Database Testing section for Sandbox Mode setup that these tests run under.

## Test Factories

Use ExMachina for test data:

```elixir
# test/support/factory.ex
defmodule MyApp.Factory do
  use ExMachina.Ecto, repo: MyApp.Repo

  def user_factory do
    %MyApp.User{
      name: "Jane Smith",
      email: sequence(:email, &"email-#{&1}@example.com"),
      age: 25
    }
  end

  def admin_factory do
    struct!(
      user_factory(),
      %{role: :admin}
    )
  end

  def post_factory do
    %MyApp.Post{
      title: "A title",
      body: "Some content",
      author: build(:user)
    }
  end
end

# In tests
defmodule MyApp.UserTest do
  use MyApp.DataCase
  import MyApp.Factory

  test "creates user" do
    user = insert(:user)
    assert user.id
  end

  test "creates admin" do
    admin = insert(:admin)
    assert admin.role == :admin
  end

  test "builds without inserting" do
    user = build(:user, name: "Custom Name")
    assert user.name == "Custom Name"
    refute user.id
  end
end
```

## Testing Changesets

```elixir
defmodule MyApp.UserTest do
  use MyApp.DataCase

  describe "changeset/2" do
    test "valid changeset with valid attributes" do
      attrs = %{name: "Alice", email: "alice@example.com", age: 25}
      changeset = User.changeset(%User{}, attrs)

      assert changeset.valid?
    end

    test "invalid without email" do
      attrs = %{name: "Alice", age: 25}
      changeset = User.changeset(%User{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email
    end

    test "invalid with short password" do
      attrs = %{email: "test@example.com", password: "123"}
      changeset = User.changeset(%User{}, attrs)

      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end
  end
end

# Helper function
def errors_on(changeset) do
  Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
    Regex.replace(~r"%{(\w+)}", message, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end)
end
```
