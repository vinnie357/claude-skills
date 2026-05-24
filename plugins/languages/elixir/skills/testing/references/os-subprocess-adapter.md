# OS-subprocess adapters in Elixir

The Elixir implementation of the cross-language "mock OS subprocesses at the boundary" rule (see `/core:tdd` `references/os-subprocess-boundary.md`).

## Pattern

For each subprocess type your application calls:

1. Define a `@callback` behavior:

   ```elixir
   defmodule <App>.<Domain>.<Thing>Executor do
     @callback run(args :: [String.t()], opts :: keyword()) ::
       {:ok, output :: String.t()} | {:error, term()}
   end
   ```

2. Implement the real adapter (`lib/<app>/<domain>/<thing>_executor/system.ex`):

   ```elixir
   defmodule <App>.<Domain>.<Thing>Executor.System do
     @behaviour <App>.<Domain>.<Thing>Executor

     def run(args, opts \\ []) do
       case System.cmd("<binary>", args, opts) do
         {output, 0} -> {:ok, output}
         {output, code} -> {:error, {code, output}}
       end
     end
   end
   ```

3. Wire a Mox-based mock for tests (`test/support/mocks.ex`):

   ```elixir
   Mox.defmock(<App>.<Domain>.<Thing>ExecutorMock,
     for: <App>.<Domain>.<Thing>Executor)
   ```

4. Consumer modules read the adapter from config:

   ```elixir
   defmodule <App>.<Domain>.Caller do
     @executor Application.compile_env(:<app>, :<thing>_executor,
                                       <App>.<Domain>.<Thing>Executor.System)

     def do_thing(args) do
       case @executor.run(args) do
         {:ok, _} -> :ok
         {:error, reason} -> {:error, reason}
       end
     end
   end
   ```

5. `config/test.exs` wires the mock:

   ```elixir
   config :<app>, :<thing>_executor, <App>.<Domain>.<Thing>ExecutorMock
   ```

6. Tests `expect` / `stub` responses:

   ```elixir
   import Mox
   setup :verify_on_exit!

   test "does the thing" do
     expect(<App>.<Domain>.<Thing>ExecutorMock, :run, fn _args, _opts ->
       {:ok, "expected output"}
     end)
     assert :ok = <App>.<Domain>.Caller.do_thing(["arg"])
   end
   ```

## When Mox vs hand-rolled fake

- **Mox** (default) — full `expect` / `stub` ergonomics, async-safe with `verify_on_exit!`. Requires `:mox` in deps.
- **Hand-rolled fake** — acceptable for surfaces with one or two functions and no need for per-test expectations.

## Delete conditional-skip patterns

Migrating to the adapter pattern: DELETE any prior `setup_all` blocks that check `System.find_executable(...)` and skip the module. The mock removes the environmental dependency; the skip is no longer needed and was hiding bugs on partial-install hosts.

## Confirm determinism

After landing the adapter, run the project's CI suite three times. Flaky behavior in the previously-subprocess-driven tests indicates a remaining shared-state leak (see the `/elixir:testing` skill body on test isolation).
