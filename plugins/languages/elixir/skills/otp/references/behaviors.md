# OTP Behaviors

GenServer, Supervisor, Task, and Agent — the four behaviors this skill's body points you toward. See the `/elixir:otp` skill body for the Agent-vs-GenServer decision and Supervisor restart-strategy semantics.

## GenServer - Generic Server

Use GenServer for stateful processes:

```elixir
defmodule MyApp.Counter do
  use GenServer

  # Client API

  def start_link(initial_value) do
    GenServer.start_link(__MODULE__, initial_value, name: __MODULE__)
  end

  def increment do
    GenServer.call(__MODULE__, :increment)
  end

  def get_value do
    GenServer.call(__MODULE__, :get)
  end

  # Server Callbacks

  @impl true
  def init(initial_value) do
    {:ok, initial_value}
  end

  @impl true
  def handle_call(:increment, _from, state) do
    {:reply, state + 1, state + 1}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end
end
```

### GenServer Best Practices

- Use `call` for synchronous requests that need a response
- Use `cast` for asynchronous fire-and-forget messages
- Use `handle_info` for receiving regular messages
- Keep server callbacks fast - delegate heavy work to Tasks
- Name processes with `via` tuples or Registry for dynamic naming
- Implement timeouts to prevent client processes from hanging

### GenServer Patterns

**Background Work:**
```elixir
def init(state) do
  schedule_work()
  {:ok, state}
end

def handle_info(:work, state) do
  do_work(state)
  schedule_work()
  {:noreply, state}
end

defp schedule_work do
  Process.send_after(self(), :work, 5000)
end
```

**State Timeouts:**
```elixir
def handle_call(:get, _from, state) do
  {:reply, state, state, {:state_timeout, 30_000, :cleanup}}
end

def handle_state_timeout(:cleanup, state) do
  {:stop, :normal, state}
end
```

## Supervisor - Process Supervision

Build supervision trees for fault tolerance:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Database connection pool
      {MyApp.Repo, []},

      # PubSub system
      {Phoenix.PubSub, name: MyApp.PubSub},

      # Custom supervisor
      {MyApp.WorkerSupervisor, []},

      # Individual workers
      {MyApp.Cache, []},
      {MyApp.RateLimiter, []},

      # Web endpoint
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Supervision Strategies

**:one_for_one** - If a child dies, only that child is restarted
```elixir
Supervisor.start_link(children, strategy: :one_for_one)
```

**:one_for_all** - If any child dies, all children are terminated and restarted
```elixir
Supervisor.start_link(children, strategy: :one_for_all)
```

**:rest_for_one** - If a child dies, it and all children started after it are restarted
```elixir
Supervisor.start_link(children, strategy: :rest_for_one)
```

### Dynamic Supervisors

For dynamically creating processes:

```elixir
defmodule MyApp.WorkerSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_worker(args) do
    spec = {MyApp.Worker, args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
```

### Restart Strategies

Configure child restart behavior:

```elixir
children = [
  # Always restart (default)
  {MyApp.CriticalWorker, restart: :permanent},

  # Never restart
  {MyApp.OneTimeTask, restart: :temporary},

  # Only restart on abnormal exit
  {MyApp.OptionalWorker, restart: :transient}
]
```

## Task - Concurrent Work

### Fire-and-forget Tasks

For concurrent work without needing results:

```elixir
Task.start(fn ->
  send_email(user, "Welcome!")
end)
```

### Awaited Tasks

For concurrent work with results:

```elixir
task = Task.async(fn ->
  expensive_computation()
end)

# Do other work...

result = Task.await(task, 5000)  # 5 second timeout
```

### Supervised Tasks

For long-running tasks under supervision:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: MyApp.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

# Use the supervised task
Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
  long_running_operation()
end)
```

### Concurrent Map

Process collections concurrently:

```elixir
# Sequential
results = Enum.map(urls, &fetch_url/1)

# Concurrent
results = Task.async_stream(urls, &fetch_url/1, max_concurrency: 10)
         |> Enum.to_list()
```

## Agent - Simple State Management

Use Agent for simple state:

```elixir
{:ok, agent} = Agent.start_link(fn -> %{} end, name: MyApp.Cache)

# Get state
value = Agent.get(MyApp.Cache, fn state -> Map.get(state, :key) end)

# Update state
Agent.update(MyApp.Cache, fn state -> Map.put(state, :key, value) end)

# Get and update atomically
Agent.get_and_update(MyApp.Cache, fn state ->
  {Map.get(state, :key), Map.delete(state, :key)}
end)
```
