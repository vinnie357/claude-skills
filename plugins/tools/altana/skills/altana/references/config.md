# altana.toml Config Reference

## Config File Discovery

altana resolves its config in this order:

1. `$ALTANA_CONFIG` environment variable — if set, this path is used.
2. `~/.config/altana/altana.toml` — default location.

## Harness Schema

Each harness is a named preset under `[harness.<name>]`.

```toml
[harness.my-harness]
# Required: agent binary name (awman executor) or path (raw executor).
agent = "claude"

# Required: "awman" runs inside an Apple Container sandbox (macOS 26+);
# "raw" runs the binary directly as a subprocess (no container).
executor = "awman"

# Optional: model ID to pass to the agent.
# Omit to use the interactive TTY picker or error in non-TTY contexts.
model = "claude-opus-4-5"

# Optional: grant write access to cwd inside the container (awman only).
# council rejects presets that have write = true.
write = false

# Optional: wall-clock timeout in seconds. Default: 1800.
timeout_s = 1800

# Optional: environment variables injected into the agent process.
# op:// values are resolved at dispatch time via the 1Password CLI.
[harness.my-harness.env]
ANTHROPIC_BASE_URL = "https://api.anthropic.com"
ANTHROPIC_API_KEY  = "op://vault-name/item-name/field-name"
```

### Field Reference

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `agent` | string | yes | — | Agent binary name (awman) or path (raw) |
| `executor` | `awman` or `raw` | yes | — | Execution mode |
| `model` | string | no | null | Model ID; omit to trigger picker |
| `write` | bool | no | `false` | Write access inside container (awman only) |
| `timeout_s` | integer | no | `1800` | Wall-clock timeout in seconds |
| `[harness.<name>.env]` | TOML table | no | empty | Env vars injected into agent process |

## Prompt Templates

Named templates wrap a task string before dispatch. The `{input}` placeholder is substituted with the task.

```toml
[prompt.critique]
template = """You are a careful code reviewer.

Task: {input}

Provide a structured review covering:
1. Correctness — does the logic match the intent?
2. Edge cases — what inputs could break it?
3. Readability — is the code clear and idiomatic?

## Answer
(your review here)

## Evidence
(specific lines or patterns cited)

## Confidence
(high / medium / low)
"""
```

Use a template:

```bash
altana delegate my-harness "the parse function in src/parser.zig" --prompt critique
```

You do not need to include `## Answer` / `## Evidence` / `## Confidence` in a template — the protocol wraps the rendered template. Including them in a template makes them visible to the agent as format instructions rather than duplicates.

## op:// Secret References

Any env value starting with `op://` is resolved by calling `op read <ref>` before the subprocess starts. The resolved value is injected into the child environment and never appears in JSON output, logs, or error messages.

Format: `op://vault-name/item-name/field-name`

The `op` CLI must be installed, signed in to your account, and reachable on `PATH`. Run `altana doctor` to check op availability.

## Example: Multiple Harnesses

```toml
# Harness using local model server (e.g. omlx running at host gateway)
[harness.local]
agent     = "claude"
executor  = "awman"
timeout_s = 1800

[harness.local.env]
ANTHROPIC_BASE_URL = "http://192.168.65.1:8000"
ANTHROPIC_AUTH_TOKEN = "op://my-vault/local-model/token"

# Harness calling the upstream API directly (raw executor, no container)
[harness.upstream]
agent     = "claude"
executor  = "raw"
model     = "claude-opus-4-5"
timeout_s = 600

[harness.upstream.env]
ANTHROPIC_API_KEY = "op://my-vault/anthropic/api-key"
```

The `ANTHROPIC_AUTH_TOKEN` key is also accepted by the models endpoint and by the interactive picker. `ANTHROPIC_API_KEY` is the standard key for most agent CLIs; check your agent's documentation for which it reads.
