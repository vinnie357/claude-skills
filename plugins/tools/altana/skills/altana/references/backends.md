# altana Backends Reference

## Executors

altana supports two executors, selected per harness preset.

### awman (sandboxed)

```toml
executor = "awman"
```

Runs the agent binary inside an Apple Container VM using awman. The agent:
- Sees only the env vars declared in `[harness.<name>.env]`.
- Cannot access the host filesystem unless `write = true` grants cwd access.
- Reaches network endpoints via the container's virtual network interface.

**Requirements:**
- awman installed and on `PATH`.
- Apple Container runtime (macOS 26+).

**VM networking:** Inside the container, `localhost` refers to the VM, not the host. To reach a server on the host machine (e.g. a local model server), use the host gateway IP as seen from inside the VM. Find it with:

```bash
container run --rm alpine ip route show default
# Example output: default via 192.168.65.1 dev eth0
```

Use the gateway address in `ANTHROPIC_BASE_URL`:

```toml
ANTHROPIC_BASE_URL = "http://192.168.65.1:8000"
```

The exact address varies per machine — run the command above to discover it rather than copying this example value.

### raw (direct subprocess)

```toml
executor = "raw"
```

Runs the agent binary directly as a subprocess on the host, with no container wrapping. Useful for:
- Agent CLIs that provide their own isolation.
- Local servers where container networking is inconvenient.
- Debugging harness configurations before adding container overhead.

No awman or Apple Container is required for `raw` harnesses.

## Local Model Server Example

Generic pattern for pointing a harness at a locally-running Anthropic-compatible endpoint (replace placeholder values with your own):

```toml
[harness.local-model]
agent     = "claude"
executor  = "awman"
timeout_s = 1800

[harness.local-model.env]
# Replace with the host gateway IP discovered via:
# container run --rm alpine ip route show default
ANTHROPIC_BASE_URL  = "http://HOST_GATEWAY_IP:PORT"
ANTHROPIC_AUTH_TOKEN = "op://your-vault/your-item/your-field"
```

For a raw executor (no container, reaching localhost directly):

```toml
[harness.local-raw]
agent     = "claude"
executor  = "raw"
timeout_s = 1800

[harness.local-raw.env]
ANTHROPIC_BASE_URL  = "http://localhost:8000"
ANTHROPIC_AUTH_TOKEN = "op://your-vault/your-item/your-field"
```

## Council Compatibility

`council` rejects harnesses that have `write = true`. Only read-only presets participate in a council fan-out.

When selecting harnesses for council, prefer presets pointing to different models or executors. Diverse execution environments make disagreement detection meaningful — two harnesses running the same model with the same config add little synthesis value.

## Model Discovery

Before setting `model =` in a preset, list the models available for that endpoint:

```bash
altana models <harness-name>
```

This fetches `GET <ANTHROPIC_BASE_URL>/v1/models` using the harness's auth config and prints one model per line with type annotation. Use the printed model IDs in the `model =` field.

## Troubleshooting Non-done Results

All executors write the full agent subprocess stdout and stderr to:

```
$TMPDIR/altana/<run_id>/<harness-name>.log
```

The `log_path` field in the JSON result gives the exact path. Inspect it for:
- `crash` — look for spawn errors, missing binary, or agent exit codes.
- `missing_sentinel` — the agent ran but did not emit `=== ALTANA DONE <run_id> ===`; look for truncated output or tool errors.
- `timeout` — look for partial responses; consider increasing `timeout_s`.

Run `altana doctor` to verify prerequisites are in place before debugging further.
