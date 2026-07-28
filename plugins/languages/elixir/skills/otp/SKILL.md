---
name: otp
description: Guide for OTP and Elixir concurrency. Use when implementing GenServers, designing supervision trees, or building fault-tolerant concurrent systems.
---

# Elixir OTP and Concurrency

This skill activates when working with OTP behaviors, building concurrent systems, managing processes, or implementing fault-tolerant architectures in Elixir.

## When to Use This Skill

Activate when:
- Implementing GenServer, GenStage, Supervisor, or other OTP behaviors
- Designing supervision trees and fault-tolerance strategies
- Working with Tasks, Agents, or process management
- Building concurrent or distributed systems
- Managing application state
- Troubleshooting process-related issues

## OTP Behaviors

Full catalogs for GenServer, Supervisor, Task, and Agent — client/server structure, dynamic supervision, restart configuration — live in `references/behaviors.md`. Two decisions from that catalog are worth keeping here:

- **Agent vs GenServer**: use Agent for simple key-value state; use GenServer when you need complex logic, callbacks, or process lifecycle management.
- **Supervisor restart strategies**: `:one_for_one` restarts only the crashed child; `:one_for_all` restarts every child; `:rest_for_one` restarts the crashed child and every child started after it.

## Process Communication

### send/receive

Basic message passing:

```elixir
# Send message
send(pid, {:hello, "world"})

# Receive message
receive do
  {:hello, msg} -> IO.puts(msg)
after
  5000 -> IO.puts("Timeout")
end
```

### Process Registration

Register processes by name:

```elixir
# Local registration
Process.register(self(), :my_process)
send(:my_process, :hello)

# Via Registry
{:ok, _} = Registry.start_link(keys: :unique, name: MyApp.Registry)

{:ok, pid} = GenServer.start_link(MyWorker, nil,
  name: {:via, Registry, {MyApp.Registry, "worker_1"}}
)

# Look up process
[{pid, _}] = Registry.lookup(MyApp.Registry, "worker_1")
```

### Process Links and Monitors

**Links** - Bidirectional, propagate exits:

```elixir
# Link processes
Process.link(pid)

# Spawn linked
spawn_link(fn -> do_work() end)
```

**Monitors** - Unidirectional, receive DOWN messages:

```elixir
ref = Process.monitor(pid)

receive do
  {:DOWN, ^ref, :process, ^pid, reason} ->
    IO.puts("Process died: #{inspect(reason)}")
end
```

## Concurrency Patterns

### Pipeline Pattern

Chain operations with concurrency:

```elixir
defmodule Pipeline do
  def process(data) do
    data
    |> async(&step1/1)
    |> async(&step2/1)
    |> async(&step3/1)
    |> await_all()
  end

  defp async(input, fun) do
    Task.async(fn -> fun.(input) end)
  end

  defp await_all(tasks) when is_list(tasks) do
    Enum.map(tasks, &Task.await/1)
  end
end
```

### Worker Pool

Implement a worker pool:

```elixir
defmodule MyApp.WorkerPool do
  use GenServer

  def start_link(opts) do
    pool_size = Keyword.get(opts, :size, 10)
    GenServer.start_link(__MODULE__, pool_size, name: __MODULE__)
  end

  def execute(fun) do
    GenServer.call(__MODULE__, {:execute, fun})
  end

  @impl true
  def init(pool_size) do
    workers = for _ <- 1..pool_size do
      {:ok, pid} = Task.Supervisor.start_link()
      pid
    end

    {:ok, %{workers: workers, index: 0}}
  end

  @impl true
  def handle_call({:execute, fun}, _from, state) do
    worker = Enum.at(state.workers, state.index)
    task = Task.Supervisor.async_nolink(worker, fun)

    new_index = rem(state.index + 1, length(state.workers))
    {:reply, task, %{state | index: new_index}}
  end
end
```

### Backpressure with GenStage

For producer-consumer pipelines:

```elixir
defmodule Producer do
  use GenStage

  def start_link(initial) do
    GenStage.start_link(__MODULE__, initial, name: __MODULE__)
  end

  def init(initial) do
    {:producer, initial}
  end

  def handle_demand(demand, state) do
    events = Enum.to_list(state..state + demand - 1)
    {:noreply, events, state + demand}
  end
end

defmodule Consumer do
  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:consumer, :ok}
  end

  def handle_events(events, _from, state) do
    Enum.each(events, &process_event/1)
    {:noreply, [], state}
  end
end
```

## ETS - Erlang Term Storage

In-memory key-value storage:

```elixir
# Create table
:ets.new(:my_table, [:named_table, :public, read_concurrency: true])

# Insert
:ets.insert(:my_table, {:key, "value"})

# Lookup
[{:key, value}] = :ets.lookup(:my_table, :key)

# Delete
:ets.delete(:my_table, :key)

# Match patterns
:ets.match(:my_table, {:"$1", "value"})

# Iterate
:ets.foldl(fn {k, v}, acc -> [{k, v} | acc] end, [], :my_table)
```

### ETS Best Practices

- Use `read_concurrency: true` for read-heavy workloads
- Use `write_concurrency: true` for write-heavy workloads
- Prefer `:set` (default) for unique keys
- Use `:bag` or `:duplicate_bag` for multiple values per key
- Always own ETS tables in a GenServer or Supervisor to prevent data loss

## Error Handling and Fault Tolerance

Let-it-crash philosophy, when to handle errors explicitly instead, and a circuit-breaker pattern live in `references/fault-tolerance.md`.

## Testing Concurrent Systems

### Testing GenServers

```elixir
defmodule MyApp.CounterTest do
  use ExUnit.Case, async: true

  test "increments counter" do
    {:ok, pid} = MyApp.Counter.start_link(0)

    assert MyApp.Counter.increment(pid) == 1
    assert MyApp.Counter.increment(pid) == 2
    assert MyApp.Counter.get_value(pid) == 2
  end
end
```

### Testing Asynchronous Processes

```elixir
test "process receives message" do
  parent = self()

  spawn(fn ->
    receive do
      :ping -> send(parent, :pong)
    end
  end)

  send(pid, :ping)

  assert_receive :pong, 1000
end
```

### Testing Supervision

```elixir
test "supervisor restarts crashed worker" do
  {:ok, sup} = Supervisor.start_link([MyApp.Worker], strategy: :one_for_one)

  [{_, worker_pid, _, _}] = Supervisor.which_children(sup)

  # Crash the worker
  Process.exit(worker_pid, :kill)

  # Wait for restart
  Process.sleep(100)

  # Verify new worker started
  [{_, new_pid, _, _}] = Supervisor.which_children(sup)
  assert new_pid != worker_pid
  assert Process.alive?(new_pid)
end
```

## Debugging Concurrent Systems

### Observer

Launch Observer for visual process inspection:

```elixir
:observer.start()
```

### Process Info

Inspect running processes:

```elixir
# List all processes
Process.list()

# Process information
Process.info(pid)

# Message queue length
{:message_queue_len, count} = Process.info(pid, :message_queue_len)

# Current function
{:current_function, {mod, fun, arity}} = Process.info(pid, :current_function)
```

### Tracing

Use `:sys` module for debugging:

```elixir
# Enable tracing
:sys.trace(pid, true)

# Get state
:sys.get_state(pid)

# Get status
:sys.get_status(pid)
```

## Performance Considerations

### Process Spawning

- Processes are lightweight (< 2KB overhead)
- Spawning thousands/millions of processes is normal
- Use process pools when spawn rate is very high

### Message Passing

- Messages are copied between processes
- Large messages are expensive - consider ETS or persistent_term
- Use binary for efficient large data transfer

### Bottlenecks

- Single GenServer can become bottleneck
- Solution: shard state across multiple processes
- Use ETS with `read_concurrency` for read-heavy workloads

## Key Principles

- **Embrace concurrency**: Use processes liberally, they're cheap
- **Let it crash**: Don't write defensive code, use supervision
- **Isolate failures**: Design supervision trees to contain failures
- **Communicate via messages**: Avoid shared state between processes
- **Use the right tool**: GenServer for state, Task for work, Agent for simple state
- **Test at boundaries**: Test process APIs, not internal implementation
- **Monitor and observe**: Use Observer and logging to understand system behavior

## References

- `references/behaviors.md` — Full GenServer, Supervisor, Task, and Agent catalog
- `references/fault-tolerance.md` — Let-it-crash philosophy, explicit error handling, circuit breaker pattern
