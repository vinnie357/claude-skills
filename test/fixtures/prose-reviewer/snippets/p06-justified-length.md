# Dev-server restart warning

Restart the dev server before verifying this change. Phoenix live reload does
not reload compiled Elixir modules, so a stale dev server keeps serving old
behavior. Testing against a stale dev server produces a false pass that will
not reproduce once the real deploy loads the new code. Kill the dev server
and start a fresh one before testing.
