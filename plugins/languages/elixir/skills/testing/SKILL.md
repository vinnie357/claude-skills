---
name: testing
description: Guide for Elixir testing with ExUnit. Use when writing unit tests, implementing property-based tests, setting up mocks, or organizing test suites.
---

# Elixir Testing with ExUnit

This skill activates when writing, organizing, or improving tests for Elixir applications using ExUnit and related testing tools.

## ExUnit Basics

### Test Module Structure

```elixir
defmodule MyApp.MathTest do
  use ExUnit.Case, async: true

  describe "add/2" do
    test "adds two positive numbers" do
      assert Math.add(2, 3) == 5
    end

    test "adds negative numbers" do
      assert Math.add(-1, -1) == -2
    end

    test "adds zero" do
      assert Math.add(5, 0) == 5
    end
  end

  describe "divide/2" do
    test "divides two numbers" do
      assert Math.divide(10, 2) == 5.0
    end

    test "returns error for division by zero" do
      assert Math.divide(10, 0) == {:error, :division_by_zero}
    end
  end
end
```

Assertion patterns and the full `setup`/`setup_all`/conditional-setup catalog live in `references/exunit-reference.md`.

### Test Organization

#### Using describe blocks

Group related tests:

```elixir
defmodule MyApp.UserTest do
  use ExUnit.Case

  describe "create_user/1" do
    test "creates user with valid attributes" do
      # ...
    end

    test "returns error with invalid email" do
      # ...
    end
  end

  describe "update_user/2" do
    test "updates user attributes" do
      # ...
    end
  end
end
```

#### Test tags

Categorize and filter tests:

```elixir
@moduletag :integration

@tag :slow
test "expensive operation" do
  # ...
end

@tag :external
test "calls external API" do
  # ...
end

# Run only tagged tests
# mix test --only slow
# mix test --exclude external
```

Setup and teardown forms (`setup`, `setup_all`, describe-scoped setup, conditional setup) live in `references/exunit-reference.md`. Every `setup` that starts an owned resource or mutates shared state pairs it with `on_exit(fn -> ... end)` to restore it — the mechanism behind this workspace's binding test-isolation rules (restore `Application.put_env`, clean up `Process.put` keys, remove temp dirs).

## Database Testing

### Sandbox Mode

Configure for concurrent tests:

```elixir
# config/test.exs
config :my_app, MyApp.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

# test/test_helper.exs
Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :manual)

# test/support/data_case.ex
defmodule MyApp.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias MyApp.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MyApp.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
```

Test factories (ExMachina) and changeset test patterns live in `references/database-testing.md`.

## Phoenix Testing

Controller, LiveView, and Channel test examples live in `references/phoenix-testing.md`.

## Mocking and Stubbing

### Using Mox

Define behaviors and mocks:

```elixir
# Define behaviour
defmodule MyApp.HTTPClient do
  @callback get(String.t()) :: {:ok, map()} | {:error, term()}
end

# In config/test.exs
config :my_app, :http_client, MyApp.HTTPClientMock

# In test/test_helper.exs
Mox.defmock(MyApp.HTTPClientMock, for: MyApp.HTTPClient)

# In application code
defmodule MyApp.UserFetcher do
  @http_client Application.compile_env(:my_app, :http_client)

  def fetch_user(id) do
    @http_client.get("/users/#{id}")
  end
end

# In tests
defmodule MyApp.UserFetcherTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "fetches user successfully" do
    expect(MyApp.HTTPClientMock, :get, fn "/users/1" ->
      {:ok, %{"name" => "Alice"}}
    end)

    assert {:ok, %{"name" => "Alice"}} = MyApp.UserFetcher.fetch_user(1)
  end

  test "handles error" do
    expect(MyApp.HTTPClientMock, :get, fn _ ->
      {:error, :network_error}
    end)

    assert {:error, :network_error} = MyApp.UserFetcher.fetch_user(1)
  end
end
```

### Stubbing Multiple Calls

```elixir
test "calls API multiple times" do
  MyApp.HTTPClientMock
  |> expect(:get, 3, fn url ->
    {:ok, %{"url" => url}}
  end)

  MyApp.batch_fetch([1, 2, 3])
end
```

### Global Stubs

```elixir
setup do
  stub(MyApp.HTTPClientMock, :get, fn _ -> {:ok, %{}} end)
  :ok
end

test "can override stub" do
  expect(MyApp.HTTPClientMock, :get, fn _ ->
    {:error, :timeout}
  end)

  # ...
end
```

## Property-Based Testing

Property-based tests with StreamData, including custom generators, live in `references/property-based-testing.md`.

## Testing Async and Concurrent Code

### Testing Processes

```elixir
test "GenServer handles messages" do
  {:ok, pid} = MyApp.Worker.start_link()

  MyApp.Worker.process(pid, :work)

  assert_receive {:done, :work}, 1000
end
```

### Testing Tasks

```elixir
test "async task completes" do
  parent = self()

  Task.start(fn ->
    result = expensive_computation()
    send(parent, {:result, result})
  end)

  assert_receive {:result, value}, 5000
  assert value == expected
end
```

### Testing Race Conditions

```elixir
test "concurrent updates are handled correctly" do
  {:ok, counter} = Counter.start_link(0)

  tasks = for _ <- 1..100 do
    Task.async(fn -> Counter.increment(counter) end)
  end

  Task.await_many(tasks)

  assert Counter.get(counter) == 100
end
```

## Test Coverage

Generating coverage reports and configuring thresholds lives in `references/exunit-reference.md`.

## Best Practices

### Test Organization

- One test file per module: `lib/my_app/user.ex` → `test/my_app/user_test.exs`
- Use `describe` blocks to group related tests
- Use `test/support` for shared test helpers
- Keep tests focused on one behavior per test

### Naming

- Use descriptive test names that explain what is being tested
- Start with the action being tested
- Include the expected outcome

```elixir
# Good
test "create_user/1 returns error with invalid email"
test "add/2 returns sum of two positive integers"

# Avoid
test "it works"
test "test1"
```

### Setup

- Use `setup` for common test data
- Keep setup focused - don't create unnecessary data
- Use context to pass data between setup and tests
- Use factories for complex data structures

### Assertions

- Prefer pattern matching over multiple assertions
- Use specific assertions (`assert_receive` vs `assert Process.info(...)`)
- Test one logical assertion per test when possible

### Async Tests

```elixir
# Mark tests as async when they don't share state
use ExUnit.Case, async: true

# A test that touches shared state (global config, a shared key, the
# filesystem) is not automatically an async: false candidate — isolate
# the state first (see Test Isolation below); reach for async: false
# only when isolation genuinely is not possible, e.g. real unsandboxed
# database access.
```

### Test Data

- Use factories (ExMachina) for consistent test data
- Avoid hardcoded IDs - use factories and references
- Keep test data minimal - only what's needed for the test
- Use descriptive data that makes tests readable

### External Dependencies

- Mock external APIs and services
- Use Mox for behavior-based mocking
- Stub at the boundary - don't mock internal modules
- Tag tests that require external services

## Test Isolation

Non-deterministic test failures (SQLite "database busy", env-dependent, fails-locally-passes-in-CI) are broken test isolation, not runtime flakiness. Default diagnosis: shared mutable state leaking across tests, not the runtime being unreliable.

- Every test that mutates `Application.put_env/3` saves and restores it in `setup` + `on_exit`.
- Every test that uses `Process.put/2` on a shared key cleans up in `on_exit`.
- Every test that writes files uses a unique temp dir (`System.unique_integer([:positive])`) and removes it via `on_exit`.
- `async: false` is a LAST RESORT, with a comment naming the shared state that forces it.
- The determinism check varies the CONCURRENCY SHAPE, not the repetition count: run the suite normally, then again at a 2-vCPU CI runner's shape via `mix test --max-cases 4`. Repeating identical runs samples the same shape N times and proves nothing.
- Never rerun CI to turn a failure green. A remote-only failure is a reproduction recipe: reproduce locally at the runner's concurrency shape, fix the isolation bug, push the fix.

## Debugging Tests

### Running Specific Tests

```bash
# Run single test file
mix test test/my_app/user_test.exs

# Run specific line
mix test test/my_app/user_test.exs:42

# Run tests matching pattern
mix test --only integration

# Run tests excluding pattern
mix test --exclude slow
```

### Test Output

```elixir
# Add IEx.pry breakpoint
import IEx
test "debugging" do
  user = build(:user)
  IEx.pry()  # Stops here
  # ...
end

# Print during tests
IO.inspect(value, label: "DEBUG")
```

### Failed Test Debugging

```bash
# Re-run only failed tests
mix test --failed

# Show detailed error traces
mix test --trace

# Run tests one at a time
mix test --max-cases 1
```

## Key Principles

- **Test behavior, not implementation**: Test what the code does, not how it does it
- **Keep tests fast**: Use async tests, avoid unnecessary setup, mock slow dependencies
- **Make tests readable**: Use descriptive names, clear assertions, minimal setup
- **Test at the right level**: Unit tests for logic, integration tests for interactions
- **Use factories**: Consistent, reusable test data with ExMachina
- **Mock at boundaries**: Mock external services, not internal modules
- **Property-based testing**: Use StreamData for algorithmic code
- **Embrace the database**: Use Ecto sandbox for fast, isolated database tests

## References

- `references/exunit-reference.md` — Assertion patterns, setup/teardown forms, and coverage tooling
- `references/database-testing.md` — Test factories (ExMachina) and changeset test patterns
- `references/phoenix-testing.md` — Controller, LiveView, and Channel test examples
- `references/property-based-testing.md` — StreamData property tests and custom generators
- `references/os-subprocess-adapter.md` — Elixir @callback + Mox shape for wrapping `System.cmd` / `Port.open` calls behind a mockable seam; config wiring per environment
- `references/elixir-tdd-discipline.md` — Elixir-specific TDD defaults: `@cmd_mod` compile-time seam, `async: true` everywhere, mock external boundaries (HTTP / OS / time / third-party APIs), no `:integration` tags, no log noise, no error-swallowing `else _ -> :ok`
