# mise sandboxing — runnable examples

Source: https://mise.jdx.dev/sandboxing.html (accessed 2026-05-22)

## Constrain a task to write only to ./dist with no network

Add sandbox policy directly in `mise.toml`:

```toml
[tasks.build]
run = "npm run build"
deny_net = true
allow_write = ["./dist"]
```

Run with:

```bash
mise run build
```

## Ad-hoc sandboxed npm install

Deny everything, then allow only the specific paths and host needed:

```bash
mise x --deny-all --allow-read=. --allow-write=./dist --allow-net=registry.npmjs.org -- npm install
```

This grants read access to the current directory, write access to `./dist`, and outbound network access to `registry.npmjs.org` only (macOS per-host filtering; Linux applies network access as all-or-nothing).

## Enable the feature flag

```bash
mise settings experimental=true
```

Without this, all deny/allow flags are silently no-ops — commands run unsandboxed with no error.
