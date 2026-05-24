# Elixir TDD discipline

Rules that extend `/core:tdd` with Elixir-specific defaults.

## `@cmd_mod` compile-time seam is the default

Every Elixir module in `lib/` that calls `System.cmd/3`, `System.find_executable/1`, or `Port.open/2` routes through a compile-time adapter:

```elixir
defmodule <App>.<Module> do
  @cmd_mod Application.compile_env(:<app>, :cmd_module, System)

  def shell_out(args) do
    @cmd_mod.cmd("<binary>", args)
  end
end
```

Test config (`config/test.exs`) wires `:cmd_module` to a mock:

```elixir
config :<app>, :cmd_module, <App>.MockCmd
```

`<App>.MockCmd` (at `test/support/mock_cmd.ex`) implements the same interface as `System` (`cmd/3`, `find_executable/1`, etc.) with per-test stubbed responses.

Same pattern for HTTP boundaries (`@http_mod`), file boundaries (`@file_mod`), and other externals. No naked `System.cmd` in `lib/` — no exceptions. See `references/os-subprocess-adapter.md` for the full behavior + Mox shape (recommended for new code).

## All tests `async: true`

Every `ExUnit.Case` declares `async: true`. The exception requires a documented code comment explaining the shared mutable state that forces serialization (e.g., a global registry the test mutates).

`async: false` as a default is a smell: it hides isolation bugs by serializing them out of existence. The right fix is to find and remove the shared state.

## Mock ALL external boundaries

External boundaries to mock:
- HTTP clients (Bypass or Mox + behavior)
- OS subprocesses (Mox + behavior — see `references/os-subprocess-adapter.md`)
- Third-party APIs (Mox + behavior)
- Time (`DateTime` injection or a clock adapter)
- Filesystem when test deals with absolute or shared paths (consider `tmp_dir` for owned paths)

Internal contexts (your own application's modules calling your own application's modules) run real against the Ecto sandbox. Mocking internal code is the "mocking what you own" anti-pattern.

## No `@tag :integration` / `@moduletag :integration`

Tests are not categorized as "integration" vs "unit" for the purpose of selective exclusion. Every test runs on every CI invocation. The two acceptable responses to "this test is slow / flaky / environment-dependent":

1. Mock the boundary that causes the slowness / flakiness / dependency. Test stays in the suite.
2. Delete the test. The behavior it covered moves to a different test that does not have the constraint.

Tagging-as-integration to skip is hiding the cost, not paying it.

## No log noise in test output

`config/test.exs` sets `config :logger, level: :none` (or equivalent quiet level). Log output during tests obscures actual failures; CI logs become hard to grep when every test prints incidental Logger output.

Tests that EXPLICITLY verify logging behavior capture log output via `ExUnit.CaptureLog.capture_log/1` rather than allowing the default sink.

## Graceful error handling, no `else _ -> :ok`

Application code does not swallow errors with `else _ -> :ok` (or `try / rescue _ -> :ok`). Every error path either:

- Returns `{:error, reason}` with a structured reason atom or tuple.
- Logs via `Logger.warning/2` or `Logger.error/2` AND returns `{:error, reason}`.
- Re-raises after annotation if the error is genuinely fatal.

`else _ -> :ok` hides bugs; the test that should have caught the error path silently passes.

## No pre-existing failures

Per `references/ci-discipline.md` in `/core:tdd`: every failing test in the current CI run is the current worker's responsibility, regardless of which prior commit introduced it.
