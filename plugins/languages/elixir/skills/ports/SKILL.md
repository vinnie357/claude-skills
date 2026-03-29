---
name: ports
description: Guide for Elixir/Erlang Ports — communicating with external OS processes. Use when spawning external programs, implementing port protocols, wrapping ports in GenServer, or choosing between Port, NIF, System.cmd, and C Nodes.
license: MIT
---

# Elixir Ports

Ports are Elixir's mechanism for communicating with external OS programs via stdin/stdout. A Port is not a network port — it is a process-like entity that manages an external OS program, forwarding messages as bytes and delivering responses back to the owning Elixir process.

## When to Use This Skill

Activate when:
- Spawning and communicating with external programs or scripts
- Implementing binary protocols over stdin/stdout
- Wrapping a port in a GenServer for lifecycle management
- Deciding between Port, NIF, C Node, or `System.cmd`
- Handling port crashes, exit status, or monitoring ports
- Working with long-running external processes

## Port Fundamentals

Open a port with `Port.open/2`. The most common name forms are `{:spawn, command}` and `{:spawn_executable, path}`.

```elixir
# Spawn by shell command string (uses shell, PATH lookups apply)
port = Port.open({:spawn, "cat"}, [:binary])

# Spawn executable directly (no shell, preferred for security)
port = Port.open({:spawn_executable, "/usr/bin/python3"}, [
  :binary,
  args: ["-u", "my_script.py"]
])
```

Send data to the port and receive from it:

```elixir
# Send bytes to the external process's stdin
Port.command(port, "hello\n")

# Receive response — messages arrive in the process mailbox
receive do
  {^port, {:data, data}} ->
    IO.puts("Got: #{data}")
end
```

Close the port explicitly or let it close when the owner process exits:

```elixir
Port.close(port)
# The port will reply {port, :closed} after the external process exits
```

## Port Options Reference

| Option | Description |
|--------|-------------|
| `:binary` | Deliver data as binaries (recommended; default is charlists) |
| `{:packet, N}` | Prefix each message with N-byte length header (N = 1, 2, or 4) |
| `{:line, L}` | Deliver complete lines up to L bytes; partial lines flagged |
| `:stream` | No framing — raw bytes delivered as received (default) |
| `:exit_status` | Send `{port, {:exit_status, code}}` when the program exits |
| `:use_stdio` | Use stdin/stdout for communication (default) |
| `:stderr_to_stdout` | Merge stderr into stdout stream |
| `{:cd, dir}` | Set working directory for the external process |
| `{:env, env_list}` | Set environment variables (REPLACES the entire environment) |
| `{:args, arg_list}` | Argument list when using `:spawn_executable` |
| `{:arg0, string}` | Override argv[0] for the external process |
| `:parallelism` | Hint to scheduler for improved throughput |

**Note on `{:env, env_list}`**: This option completely replaces the OS environment, it does not merge with the current environment. To extend the current environment, merge explicitly before passing it.

## Communication Patterns

### Stream Mode (default)

Bytes are delivered as they arrive with no framing. Use `:binary` to get binaries instead of charlists.

```elixir
port = Port.open({:spawn_executable, "/bin/cat"}, [:binary, :stream])

Port.command(port, "some data")

receive do
  {^port, {:data, chunk}} -> IO.inspect(chunk)
end
```

### Packet Mode

Use `{:packet, N}` for message framing. The external program must also implement the same N-byte big-endian length prefix.

```elixir
# Elixir side
port = Port.open({:spawn_executable, "/usr/local/bin/my_worker"}, [
  :binary,
  {:packet, 4}
])

Port.command(port, encode_message("hello"))

receive do
  {^port, {:data, response}} -> decode_message(response)
end
```

The external program reads a 4-byte big-endian integer as the message length, then reads that many bytes. It writes responses with the same framing.

### Line Mode

```elixir
port = Port.open({:spawn_executable, "/usr/bin/python3"}, [
  :binary,
  {:line, 4096},
  args: ["script.py"]
])

receive do
  {^port, {:data, {:eol, line}}} ->
    IO.puts("Complete line: #{line}")

  {^port, {:data, {:noeol, partial}}} ->
    IO.puts("Partial line (too long): #{partial}")
end
```

### Receiving Exit Status

```elixir
port = Port.open({:spawn, "false"}, [:binary, :exit_status])

receive do
  {^port, {:exit_status, code}} ->
    IO.puts("Exited with code #{code}")
end
```

## GenServer Port Wrapper

Wrapping a port in a GenServer is the standard OTP pattern for managing external processes. The GenServer owns the port, handles messages, and exposes a clean API.

```elixir
defmodule MyApp.ExternalWorker do
  use GenServer

  @timeout 5_000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def call(payload) do
    GenServer.call(__MODULE__, {:call, payload}, @timeout)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    executable = System.find_executable("my_worker") ||
      raise "my_worker not found in PATH"

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        {:packet, 4},
        :exit_status
      ])

    ref = Port.monitor(port)

    {:ok, %{port: port, ref: ref, caller: nil}}
  end

  @impl true
  def handle_call({:call, payload}, from, %{port: port} = state) do
    encoded = :erlang.term_to_binary(payload)
    Port.command(port, encoded)
    {:noreply, %{state | caller: from}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port, caller: caller} = state) do
    response = :erlang.binary_to_term(data)
    GenServer.reply(caller, {:ok, response})
    {:noreply, %{state | caller: nil}}
  end

  @impl true
  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    {:stop, {:port_exited, code}, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :port, _port, reason}, %{ref: ref} = state) do
    {:stop, {:port_down, reason}, state}
  end

  @impl true
  def terminate(_reason, %{port: port}) do
    if Port.info(port) != nil do
      Port.close(port)
    end

    :ok
  end
end
```

Key points in this pattern:
- Store the port in GenServer state
- Monitor the port with `Port.monitor/1` to receive `:DOWN` messages
- Use `{:packet, N}` for reliable message framing
- Store the calling `from` pid when waiting for a response
- Reply via `GenServer.reply/2` from `handle_info` when data arrives
- Always check `Port.info(port)` before closing in `terminate/2`

### Supervision

Add the GenServer to a supervision tree:

```elixir
children = [
  {MyApp.ExternalWorker, []},
  # ...
]

Supervisor.start_link(children, strategy: :one_for_one)
```

When the external process crashes, the port sends an exit message, the GenServer stops, and the supervisor restarts it.

## Port Lifecycle and Error Handling

### Port Monitor

Use `Port.monitor/1` (available since Elixir v1.6) to receive a `{:DOWN, ref, :port, object, reason}` message when a port closes:

```elixir
port = Port.open({:spawn, "my_cmd"}, [:binary])
ref = Port.monitor(port)

receive do
  {:DOWN, ^ref, :port, _port, reason} ->
    IO.puts("Port closed: #{inspect(reason)}")
end
```

### Checking if a Port is Alive

```elixir
case Port.info(port) do
  nil -> :port_closed
  info -> {:alive, info}
end
```

### Port Ownership Transfer

Transfer ownership with `Port.connect/2`. The old owner receives `{port, :connected}`:

```elixir
Port.connect(port, new_owner_pid)
```

### Crash Semantics

- When the port owner process terminates, the port closes automatically, and the external program receives SIGTERM.
- When the external program exits, the port sends `{port, {:exit_status, code}}` (if `:exit_status` was set) and closes.
- Ports are linked to their owning process by default.

## Decision Guide: Port vs NIF vs C Node vs System.cmd

| Aspect | Port | NIF | C Node | System.cmd |
|--------|------|-----|--------|-----------|
| Crash isolation | Yes — OS process | No — crashes the VM | Yes — OS process | Yes — subprocess |
| Latency | IPC overhead | Near zero | Message passing | Blocking, high |
| Complexity | Low–Medium | High | Very high | Very low |
| Scheduler impact | None | Blocks (use dirty NIFs for >1ms) | None | Blocks caller only |
| Security boundary | OS process isolation | Full VM access | OS process isolation | OS process isolation |
| Best for | Long-running, streaming | Sub-millisecond sync calls | Legacy C integration | One-shot commands |

**Use Port when**: the external program runs continuously, streams data, or must be isolated from VM crashes.

**Use `System.cmd/3` when**: running a command once, synchronously, and the result is needed before proceeding. Returns `{output, exit_status}`.

**Use NIF when**: calling a C function with sub-millisecond latency requirements. Use dirty NIFs (`ERL_NIF_DIRTY_JOB_CPU_BOUND` or `ERL_NIF_DIRTY_JOB_IO_BOUND`) for work exceeding ~1ms to avoid blocking schedulers.

**Use C Node when**: integrating with an existing large C codebase that uses `erl_interface`/`ei`.

### System.cmd Example

```elixir
{output, 0} = System.cmd("ls", ["-la", "/tmp"],
  cd: "/",
  stderr_to_stdout: true
)
```

`System.cmd/3` blocks the calling process until the command completes. It does not stream data.

## Security Considerations

### Prefer `:spawn_executable` Over `:spawn`

`{:spawn, command}` passes the command through a shell, which enables shell injection:

```elixir
# UNSAFE — shell injection risk
user_input = "file.txt; rm -rf /"
Port.open({:spawn, "cat #{user_input}"}, [:binary])

# SAFE — no shell, arguments passed directly
Port.open({:spawn_executable, "/bin/cat"}, [
  :binary,
  args: [user_input]
])
```

Always use `{:spawn_executable, path}` with `args:` when any part of the command comes from user input or external data.

### Validate Executable Paths

```elixir
# Find and validate the executable at startup, not per-request
executable = System.find_executable("my_tool") ||
  raise "my_tool executable not found in PATH"
```

Store the validated path in process state so it is resolved once at startup.

### Environment Variable Replacement

`{:env, env_list}` completely replaces the OS environment. To avoid accidentally stripping PATH or other required variables:

```elixir
# Merge with current environment
base_env = System.get_env() |> Map.to_list()
Port.open({:spawn_executable, executable}, [
  :binary,
  env: base_env ++ [{"MY_VAR", "value"}]
])
```

Note: `{:env, env_list}` expects a list of `{charlist, charlist}` or `{binary, binary}` tuples. Use `String.to_charlist/1` if mixing types.

### Windows Batch File Injection

On Windows, spawning `.bat` or `.cmd` files via `:spawn` passes through `cmd.exe`, which has its own injection vectors. Use explicit executable paths and validate all arguments.

## Testing Port-Based Code

### Mock the Port Interaction

Test the GenServer wrapper by sending fake port messages directly:

```elixir
defmodule MyApp.ExternalWorkerTest do
  use ExUnit.Case, async: true

  test "call sends to port and returns response" do
    {:ok, pid} = MyApp.ExternalWorker.start_link([])

    # Retrieve the port from state for inspection
    %{port: port} = :sys.get_state(pid)

    # Simulate the port sending a response
    fake_response = :erlang.term_to_binary({:ok, "result"})
    send(pid, {port, {:data, fake_response}})

    # Verify state updated (caller cleared)
    %{caller: nil} = :sys.get_state(pid)
  end

  test "handles port exit" do
    {:ok, pid} = MyApp.ExternalWorker.start_link([])
    ref = Process.monitor(pid)

    %{port: port} = :sys.get_state(pid)
    send(pid, {port, {:exit_status, 1}})

    assert_receive {:DOWN, ^ref, :process, ^pid, {:port_exited, 1}}
  end
end
```

### Integration Test with a Real Port

For integration tests, use a real external program:

```elixir
test "communicates with cat process" do
  port = Port.open({:spawn_executable, "/bin/cat"}, [:binary, :stream])

  Port.command(port, "hello")

  assert_receive {^port, {:data, "hello"}}, 1_000

  Port.close(port)
end
```

Use `assert_receive` with a timeout rather than bare `receive` in tests to avoid hanging on failure.

## Common Pitfalls

**Orphan processes on VM crash**: If the BEAM VM is killed with SIGKILL (not SIGTERM), external port processes may not receive SIGTERM and can persist. Design external programs to detect closed stdin and exit.

**Charlists vs binaries**: Without `:binary`, data arrives as charlists (lists of integers). Always use `:binary` unless working with legacy code that expects charlists.

**Environment replacement**: `{:env, list}` replaces the entire environment. See the Security section for how to merge with the current environment.

**Blocking the GenServer**: A GenServer that sends a command and awaits a reply synchronously in `handle_call` will block the entire GenServer during the wait. The pattern above avoids this by storing the `from` and replying in `handle_info`.

**Not monitoring the port**: Without `Port.monitor/1` or `:exit_status`, a silently exiting external process leaves the GenServer in a state where it will never receive a reply.

**Packet mode mismatch**: If the Elixir side uses `{:packet, 4}` but the external program uses a different framing, all messages will be corrupted or silently dropped. Verify the framing protocol matches on both sides.

## References

See `references/erlang-ports.md` for:
- Complete `open_port/2` Erlang option reference
- Binary protocol wire format and byte calculations
- `erl_interface` / `ei` C library overview
- Port driver architecture (linked-in drivers)
- ERTS scheduling and backpressure options

## Anti-Fabrication

Verify all port behavior claims through tool execution. Use `Port.info/1` to confirm port state before asserting properties. Run actual port commands and check exit statuses rather than assuming behavior. Reference `core:anti-fabrication` for the complete validation methodology.

## Key Principles

- **Use `:spawn_executable`**: Avoid shell injection by passing arguments directly
- **Wrap ports in GenServer**: Follow OTP patterns for lifecycle management and supervision
- **Monitor the port**: Use `Port.monitor/1` to detect unexpected port closure
- **Use `{:packet, N}` for framing**: Stream mode requires external framing logic
- **Design for orphan processes**: External programs should detect stdin closure and exit
- **Test with `assert_receive`**: Avoid bare `receive` in tests to prevent hangs
- **Prefer Port over NIF for isolation**: NIF crashes bring down the entire VM
