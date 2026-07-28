# ExUnit Reference

Assertion patterns, setup/teardown forms, and coverage tooling for ExUnit. See the `/elixir:testing` skill body for test module structure, organization, and the `on_exit` isolation rule these setup forms rely on.

## Assertions

Common assertion patterns:

```elixir
# Equality
assert actual == expected
refute actual == unexpected

# Boolean
assert is_binary(value)
assert is_integer(value)
refute is_nil(value)

# Pattern matching
assert {:ok, result} = function_call()
assert %User{name: "Alice"} = user

# Exceptions
assert_raise ArgumentError, fn ->
  String.to_integer("not a number")
end

assert_raise ArgumentError, "invalid argument", fn ->
  dangerous_function()
end

# Messages
send(self(), :hello)
assert_received :hello

assert_receive :message, 1000  # With timeout

refute_received :unwanted
refute_receive :unwanted, 100
```

## Setup and Teardown

### Test context

```elixir
defmodule MyApp.UserTest do
  use ExUnit.Case

  setup do
    user = %User{name: "Alice", email: "alice@example.com"}
    {:ok, user: user}
  end

  test "user has name", %{user: user} do
    assert user.name == "Alice"
  end

  test "user has email", %{user: user} do
    assert user.email == "alice@example.com"
  end
end
```

### Setup with describe

```elixir
describe "authenticated user" do
  setup do
    user = insert(:user)
    token = generate_token(user)
    {:ok, user: user, token: token}
  end

  test "can access protected resource", %{token: token} do
    # ...
  end
end
```

### Module setup

```elixir
setup_all do
  # Runs once before all tests in module
  start_supervised!(MyApp.Cache)
  :ok
end

setup do
  # Runs before each test
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
end
```

### Conditional setup

```elixir
setup context do
  if context[:integration] do
    start_external_service()
    on_exit(fn -> stop_external_service() end)
  end

  :ok
end

@tag :integration
test "integration test" do
  # ...
end
```

## Test Coverage

### Generate Coverage Reports

```bash
mix test --cover

# Detailed coverage
MIX_ENV=test mix coveralls
MIX_ENV=test mix coveralls.html
```

### Coverage Configuration

```elixir
# mix.exs
def project do
  [
    # ...
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.html": :test
    ]
  ]
end
```
