# Error Handling and Fault Tolerance

Let-it-crash philosophy, when to handle errors explicitly instead, and a circuit-breaker pattern for cascading-failure prevention. See the `/elixir:otp` skill body's Key Principles for the "let it crash" summary this expands on.

## Let It Crash Philosophy

Design for failure:

```elixir
# Don't do defensive programming
def process_order(order_id) do
  # Let it crash if order doesn't exist
  order = Repo.get!(Order, order_id)

  # Let it crash if validation fails
  {:ok, processed} = process(order)

  processed
end
```

## Proper Error Handling

When to handle errors vs let crash:

```elixir
# Handle expected errors
def fetch_user(id) do
  case HTTPoison.get("#{@api_url}/users/#{id}") do
    {:ok, %{status_code: 200, body: body}} ->
      Jason.decode(body)

    {:ok, %{status_code: 404}} ->
      {:error, :not_found}

    {:ok, %{status_code: status}} ->
      {:error, {:unexpected_status, status}}

    {:error, reason} ->
      {:error, {:network_error, reason}}
  end
end

# Let unexpected errors crash
def update_user!(id, params) do
  user = Repo.get!(User, id)  # Crash if not found

  user
  |> User.changeset(params)
  |> Repo.update!()  # Crash if invalid
end
```

## Circuit Breaker

Prevent cascading failures:

```elixir
defmodule CircuitBreaker do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{status: :closed, failures: 0}, name: __MODULE__)
  end

  def call(fun) do
    case GenServer.call(__MODULE__, :status) do
      :open -> {:error, :circuit_open}
      :closed -> execute(fun)
    end
  end

  defp execute(fun) do
    try do
      result = fun.()
      GenServer.cast(__MODULE__, :success)
      {:ok, result}
    rescue
      e ->
        GenServer.cast(__MODULE__, :failure)
        {:error, e}
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_cast(:success, state) do
    {:noreply, %{state | failures: 0, status: :closed}}
  end

  @impl true
  def handle_cast(:failure, state) do
    new_failures = state.failures + 1

    if new_failures >= 5 do
      Process.send_after(self(), :half_open, 30_000)
      {:noreply, %{state | failures: new_failures, status: :open}}
    else
      {:noreply, %{state | failures: new_failures}}
    end
  end

  @impl true
  def handle_info(:half_open, state) do
    {:noreply, %{state | status: :closed, failures: 0}}
  end
end
```
