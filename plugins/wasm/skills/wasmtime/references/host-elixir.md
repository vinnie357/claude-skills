# Host Language: Elixir (Wasmex)

Embed WebAssembly in Elixir applications using Wasmex, which wraps the Wasmtime runtime via Rust NIFs.

## Setup

### Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:wasmex, "~> 0.9"}
  ]
end
```

Wasmex ships pre-compiled Wasmtime NIFs for major platforms (macOS, Linux). Rust toolchain is not required for installation.

```bash
mix deps.get
```

## Basic Usage

### Loading and Calling a Module

```elixir
# Load from file
{:ok, bytes} = File.read("module.wasm")
{:ok, module} = Wasmex.Module.compile(store, bytes)

# Or load from binary
{:ok, store} = Wasmex.Store.new()
{:ok, module} = Wasmex.Module.compile(store, wasm_bytes)
{:ok, instance} = Wasmex.Instance.new(store, module, %{})

# Call an exported function
{:ok, [result]} = Wasmex.Instance.call_function(store, instance, "add", [2, 3])
# result => 5
```

### Using Wasmex Convenience API

```elixir
{:ok, pid} = Wasmex.start_link(%{bytes: wasm_bytes})

# Call exported functions
{:ok, [result]} = Wasmex.call_function(pid, "add", [2, 3])
```

## Store Configuration

```elixir
# Basic store
{:ok, store} = Wasmex.Store.new()

# Store with fuel metering
{:ok, store} = Wasmex.Store.new(%{fuel: 100_000})

# WASI-enabled store
{:ok, store} = Wasmex.Store.new_wasi(%Wasmex.Wasi.WasiOptions{
  args: ["app", "--verbose"],
  env: %{"KEY" => "VALUE"},
  preopen: [%Wasmex.Wasi.PreopenOptions{
    path: "/sandbox",
    alias: "data"
  }]
})
```

## Host Callbacks (Imported Functions)

Define Elixir functions callable from wasm:

```elixir
imports = %{
  "env" => %{
    "host_log" =>
      {:fn, [:i32, :i32], [], fn context ->
        # Read string from guest memory
        {:ok, memory} = Wasmex.Instance.memory(context.store, context.instance, "memory")
        {:ok, data} = Wasmex.Memory.read_binary(context.store, memory, context.params |> List.first(), context.params |> List.last())
        IO.puts("Guest says: #{data}")
        []
      end},

    "host_random" =>
      {:fn, [], [:i32], fn _context ->
        [:rand.uniform(1_000_000)]
      end}
  }
}

{:ok, instance} = Wasmex.Instance.new(store, module, imports)
```

### Callback Signature Format

```elixir
{:fn, param_types, return_types, callback_fn}
```

Types: `:i32`, `:i64`, `:f32`, `:f64`

## Memory Access

### Reading from Guest Memory

```elixir
{:ok, memory} = Wasmex.Instance.memory(store, instance, "memory")

# Read binary data
{:ok, binary} = Wasmex.Memory.read_binary(store, memory, offset, length)

# Read string
{:ok, binary} = Wasmex.Memory.read_binary(store, memory, offset, length)
string = binary |> :binary.bin_to_list() |> to_string()
```

### Writing to Guest Memory

```elixir
{:ok, memory} = Wasmex.Instance.memory(store, instance, "memory")

# Write binary data
:ok = Wasmex.Memory.write_binary(store, memory, offset, binary_data)

# Write a string
:ok = Wasmex.Memory.write_binary(store, memory, offset, "hello")
```

### Memory Size

```elixir
{:ok, memory} = Wasmex.Instance.memory(store, instance, "memory")

# Get size in bytes
size = Wasmex.Memory.size(store, memory)

# Grow memory (in pages, 1 page = 64KB)
:ok = Wasmex.Memory.grow(store, memory, 1)
```

## String Passing Pattern

Wasm only supports numeric types at the boundary. Use a shared memory protocol:

```elixir
defmodule WasmStringHelper do
  @doc """
  Write a string to guest memory and return {pointer, length}.
  Requires the guest to export an `allocate(size) -> ptr` function.
  """
  def write_string(store, instance, string) do
    binary = string |> :binary.bin_to_list()
    length = byte_size(string)

    # Ask guest to allocate memory
    {:ok, [ptr]} = Wasmex.Instance.call_function(store, instance, "allocate", [length])

    # Write string into allocated memory
    {:ok, memory} = Wasmex.Instance.memory(store, instance, "memory")
    :ok = Wasmex.Memory.write_binary(store, memory, ptr, string)

    {ptr, length}
  end

  @doc """
  Read a string from guest memory at the given pointer and length.
  """
  def read_string(store, instance, ptr, length) do
    {:ok, memory} = Wasmex.Instance.memory(store, instance, "memory")
    {:ok, binary} = Wasmex.Memory.read_binary(store, memory, ptr, length)
    binary
  end
end
```

## GenServer Integration

### Wasm Worker

```elixir
defmodule MyApp.WasmWorker do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def call_function(pid, func_name, params) do
    GenServer.call(pid, {:call, func_name, params})
  end

  @impl true
  def init(opts) do
    wasm_bytes = File.read!(opts[:wasm_path])
    {:ok, store} = Wasmex.Store.new()
    {:ok, module} = Wasmex.Module.compile(store, wasm_bytes)
    {:ok, instance} = Wasmex.Instance.new(store, module, opts[:imports] || %{})

    {:ok, %{store: store, instance: instance}}
  end

  @impl true
  def handle_call({:call, func_name, params}, _from, state) do
    result = Wasmex.Instance.call_function(state.store, state.instance, func_name, params)
    {:reply, result, state}
  end
end
```

### Supervised Wasm Pool

```elixir
defmodule MyApp.WasmSupervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {MyApp.WasmWorker, name: :wasm_worker_1, wasm_path: "priv/wasm/plugin.wasm"},
      {MyApp.WasmWorker, name: :wasm_worker_2, wasm_path: "priv/wasm/plugin.wasm"},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### Poolboy Integration

For high-throughput scenarios, use a worker pool:

```elixir
# In application supervisor
children = [
  :poolboy.child_spec(:wasm_pool, [
    name: {:local, :wasm_pool},
    worker_module: MyApp.WasmWorker,
    size: System.schedulers_online(),
    max_overflow: 2
  ], [wasm_path: "priv/wasm/plugin.wasm"])
]
```

```elixir
# Usage
:poolboy.transaction(:wasm_pool, fn pid ->
  MyApp.WasmWorker.call_function(pid, "process", [input])
end, :timer.seconds(5))
```

## WASI Support

```elixir
# Create WASI-enabled store
{:ok, store} = Wasmex.Store.new_wasi(%Wasmex.Wasi.WasiOptions{
  args: ["my-app", "--config", "/data/config.toml"],
  env: %{
    "LOG_LEVEL" => "info",
    "APP_ENV" => "production"
  },
  preopen: [
    %Wasmex.Wasi.PreopenOptions{path: "./data", alias: "data"},
    %Wasmex.Wasi.PreopenOptions{path: "./tmp", alias: "tmp"}
  ]
})

{:ok, module} = Wasmex.Module.compile(store, wasm_bytes)
{:ok, instance} = Wasmex.Instance.new(store, module, %{})

# Call WASI _start for command modules
{:ok, _} = Wasmex.Instance.call_function(store, instance, "_start", [])
```

## Error Handling

```elixir
case Wasmex.Instance.call_function(store, instance, "process", [ptr, len]) do
  {:ok, [result]} ->
    {:ok, result}

  {:error, "unreachable" <> _} ->
    {:error, :wasm_trap}

  {:error, "out of bounds memory access" <> _} ->
    {:error, :memory_violation}

  {:error, "all fuel consumed" <> _} ->
    {:error, :fuel_exhausted}

  {:error, reason} ->
    {:error, {:wasm_error, reason}}
end
```

## Fuel Metering

```elixir
# Create store with fuel
{:ok, store} = Wasmex.Store.new(%{fuel: 1_000_000})

# Execute with fuel limit
case Wasmex.Instance.call_function(store, instance, "expensive_op", []) do
  {:ok, result} -> {:ok, result}
  {:error, "all fuel consumed" <> _} -> {:error, :timeout}
end
```

## Phoenix Integration

### LiveView with Wasm Processing

```elixir
defmodule MyAppWeb.ProcessorLive do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, result: nil, processing: false)}
  end

  @impl true
  def handle_event("process", %{"input" => input}, socket) do
    socket = assign(socket, processing: true)

    # Offload to wasm worker
    task = Task.async(fn ->
      MyApp.WasmWorker.call_function(:wasm_worker, "process", [input])
    end)

    {:noreply, assign(socket, task: task)}
  end

  @impl true
  def handle_info({ref, {:ok, [result]}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, result: result, processing: false)}
  end
end
```

## Common Patterns

### Module Preloading at Application Start

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    # Preload wasm modules into ETS for fast access
    :ets.new(:wasm_modules, [:named_table, :public, read_concurrency: true])

    wasm_bytes = File.read!(Application.app_dir(:my_app, "priv/wasm/plugin.wasm"))
    :ets.insert(:wasm_modules, {"plugin", wasm_bytes})

    children = [
      MyApp.WasmSupervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

### Loading Wasm from Priv Directory

```elixir
wasm_path = Application.app_dir(:my_app, "priv/wasm/module.wasm")
wasm_bytes = File.read!(wasm_path)
```

Place `.wasm` files in `priv/wasm/` so they are included in releases.
