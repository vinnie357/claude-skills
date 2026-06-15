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

# Optional: string altana waits for to detect that an interactive-council
# turn is complete. Required when this harness participates in council --interactive.
# For Claude Code the value is: ← for agents
ready_marker = "← for agents"

# Optional: environment variables injected into the agent process.
# op:// values are resolved at dispatch time via the 1Password CLI.
[harness.my-harness.env]
ANTHROPIC_BASE_URL = "https://api.anthropic.com"
ANTHROPIC_API_KEY  = "op://<vault>/<item>/credential"
```

### Field Reference

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `agent` | string | yes | — | Agent binary name (awman) or path (raw) |
| `executor` | `awman` or `raw` | yes | — | Execution mode |
| `model` | string | no | null | Model ID; omit to trigger picker |
| `write` | bool | no | `false` | Write access inside container (awman only) |
| `timeout_s` | integer | no | `1800` | Wall-clock timeout in seconds |
| `ready_marker` | string | no (required for interactive council) | null | Marker string signaling an interactive-session turn is complete; Claude Code uses `← for agents` |
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

### Interactive-council member

When a harness participates in `council --interactive`, altana opens a persistent tmux session and polls for `ready_marker` after each turn. The interactive Claude Code loop is significantly slower than a direct API call; set `timeout_s` high (1800 or more) to avoid premature timeouts.

A harness reaching a local model server via an Apple Container network needs the host gateway IP. For the `default` apple-container network (192.168.64.0/24) the gateway is `192.168.64.1`. Discover it at runtime with:

```bash
container run --rm alpine ip route show default
```

Example interactive-council member using a local model endpoint:

```toml
[harness.claude-local]
agent        = "claude"
executor     = "awman"
model        = "local-model-id"
timeout_s    = 1800
ready_marker = "← for agents"

[harness.claude-local.env]
ANTHROPIC_BASE_URL = "http://192.168.64.1:8000"
ANTHROPIC_API_KEY  = "op://<vault>/<item>/credential"
```

A harness using a cloud subscription (no API token required) still needs `ready_marker` but does not need `ANTHROPIC_BASE_URL` or `ANTHROPIC_API_KEY`:

```toml
[harness.claude-cloud]
agent        = "claude"
executor     = "awman"
model        = "claude-sonnet-4-5"
timeout_s    = 1800
ready_marker = "← for agents"
```

## Example: Multiple Harnesses

```toml
# Harness using local model server (e.g. a local model running at host gateway)
[harness.local]
agent     = "claude"
executor  = "awman"
timeout_s = 1800

[harness.local.env]
ANTHROPIC_BASE_URL = "http://192.168.64.1:8000"
ANTHROPIC_API_KEY  = "op://<vault>/<item>/credential"

# Harness calling the upstream API directly (raw executor, no container)
[harness.upstream]
agent     = "claude"
executor  = "raw"
model     = "claude-opus-4-5"
timeout_s = 600

[harness.upstream.env]
ANTHROPIC_API_KEY = "op://<vault>/<item>/credential"
```

`ANTHROPIC_API_KEY` is the standard env var for most agent CLIs. Check your agent's documentation for which env var it reads; some agents read `ANTHROPIC_AUTH_TOKEN` instead.
