# `mise exec` transitive runtime dependencies

`mise exec <runtime>@<version> -- <command>` does NOT auto-install transitive runtime dependencies. When `<runtime>` requires another runtime to function (most commonly: Elixir requires Erlang/OTP), `mise exec` only resolves the explicitly-named runtime; the transitive dep must already be available.

## The specific failure mode

`mise exec elixir@1.19.5-otp-28 -- elixir -e ':crypto.strong_rand_bytes(48) |> Base.encode64() |> IO.puts()'`

The `-otp-28` suffix in the Elixir version string is INFORMATIONAL — it tells mise which OTP release the Elixir binary was BUILT against. It does NOT trigger Erlang installation.

When invoked OUTSIDE a directory whose `mise.toml` declares `erlang`, the command fails:

```
/Users/<user>/.local/share/mise/installs/elixir/1.19.5-otp-28/bin/elixir: line 245: exec: erl: not found
```

But in shell command substitution (`$(...)`) contexts, the consumer captures the EMPTY STDOUT and proceeds as if the command succeeded. Downstream uses (env var assignment, file write, secret-store creation) silently get nothing.

## How to apply

For PORTABLE secret-generation commands in operator-facing documentation, prefer tools with no transitive-runtime requirement:

| Use case | Command |
|---|---|
| Hex string, any length | `openssl rand -hex <bytes>` |
| Base64-encoded random bytes | `openssl rand <bytes> | base64` |
| URL-safe random token | `python3 -c "import secrets; print(secrets.token_urlsafe(<bytes>))"` |
| POSIX-only fallback | `head -c <bytes> /dev/urandom | base64` |

Reserve `mise exec elixir@... -- elixir -e ...` for cases where Elixir-specific behavior is genuinely needed. If used, REQUIRE both `mise.toml` to declare erlang OR explicit dual-tool spec: `mise exec erlang@<ver> elixir@<ver> -- elixir -e ...`.

## Verification pattern (catches empty-secret bugs)

When generating secrets via shell command substitution, verify the OUTPUT is non-empty AND meets the expected shape, not just that the surrounding operation (item create, file write) succeeded:

```bash
VALUE="$(<generation-cmd>)"
SIZE=${#VALUE}
if [ "$SIZE" -lt 10 ]; then
  echo "ERROR: generated value too short ($SIZE chars)"
  exit 1
fi
# Now use VALUE
```

(Threshold of 10 chars is conservative — adjust per the expected output shape.)

## Pairs with

- The session-start contract's rule that secret-provisioning steps in Tier 1 plans (see `/core:agent-loop` `references/secret-provisioning.md`) MUST use generation commands that work in a portable shell context, not assume a project-local mise.toml.
