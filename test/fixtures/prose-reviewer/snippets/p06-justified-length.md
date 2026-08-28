# Dev-server restart warning

Restart the dev server before verifying this change. Phoenix live reload does
not reload compiled Elixir modules, so a stale process keeps serving old
behavior. Testing against a stale process produces a false pass that will
not reproduce once the real deploy loads the new code. Kill the running
session and start a fresh one before testing.
