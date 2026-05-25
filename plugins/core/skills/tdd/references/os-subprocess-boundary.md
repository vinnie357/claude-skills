# OS subprocess calls are external boundaries

Any application code that shells out to an OS subprocess (`git`, `tmux`, `ssh`, `scp`, `docker`, `kubectl`, etc.) is interacting with an external boundary. Under `/core:tdd` and the broader "mock at the boundary" principle, these calls get a mockable seam: a real adapter for dev and production, a mock or fake for tests.

## The seam pattern

For each subprocess your code invokes:

1. Define a behavior / interface for the operation (e.g., `GitExecutor` with `run/2`).
2. Implement the real adapter using the language's subprocess primitive.
3. Implement a mock or fake adapter that returns canned responses.
4. The consumer module reads its adapter from project config; production wires the real one, tests wire the mock.

## Anti-pattern: gating tests on `find_executable`

A common bad pattern is to gate a test module on whether the binary is present:

```text
setup_all do
  case System.find_executable("tmux") do
    nil -> {:skip, "tmux not installed"}
    _path -> :ok
  end
end
```

This hides the test on machines without the binary and runs it on machines where the binary IS in PATH but the runtime environment cannot actually drive it ("found-but-not-usable"). The mock removes the environmental dependency entirely.

## When the rule applies

- Any subprocess call from `lib/` (or equivalent application source dir).
- CLI invocations the app makes for orchestration, deployment, or remote ops.
- Anything that uses a language-level `cmd` / `spawn` / `exec` primitive against an external binary.

## When the rule does NOT apply

- In-VM language primitives (`File.read`, `Path.expand`, `Process.send_after` in Elixir; equivalents in other languages). These run inside the runtime, not as subprocesses.
- Internal application contexts (your own modules calling your own modules). Mocking internal code is "mocking what you own" — covered separately under `/core:tdd` design feedback signals.

## Pairs with

- The mock-boundaries rule under `/core:tdd`: external boundaries (HTTP, OS subprocesses, third-party APIs, time) get mocked; internal code runs real.
- Language-specific implementations live in the language's testing skill (e.g., `/elixir:testing` `references/os-subprocess-adapter.md` for the Elixir behavior + Mox shape).
