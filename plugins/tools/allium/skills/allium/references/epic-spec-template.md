# Epic Spec Template Walkthrough

A guided tour of the four template files in `templates/`, showing how they compose end-to-end.

## The Four Templates

| File | Purpose |
|---|---|
| `epic-with-spec.md` | VantageEx epic with `spec:` field |
| `oauth-pkce-flow.allium` | The spec referenced by the epic |
| `circuit-breaker.allium` | Infrastructure contract example |
| `runex-workflow.allium` | Runex step behavioral model |

## Step 1: Start with the Epic

Open `templates/epic-with-spec.md`. It shows a VantageEx-style epic with a `spec:` field:

```markdown
**spec:** ./docs/specs/vin-42-oauth-pkce.allium
```

This single field is the integration point. When the team leader reads the epic, it finds the spec path, reads the spec, and includes rule names in worker prompts.

## Step 2: Read the Spec

Open `templates/oauth-pkce-flow.allium`. It defines three rules: `InitiatePKCE`, `ExchangeCode`, `RevokeSession`.

Each rule has:
- `when:` — the trigger event
- `requires:` — preconditions (what must be true before the rule fires)
- `ensures:` — postconditions (what must be true after)

The `AuthSession` entity defines all valid states and transitions. The invariants (`HasCodeVerifier`, `AuthorizedHasToken`) will be checked by `allium weed` after CI.

## Step 3: Propagate Tests

The worker runs:

```bash
/allium:propagate docs/specs/vin-42-oauth-pkce.allium
```

Allium generates failing test skeletons — one per rule, one per invariant. Example output for `ExchangeCode`:

```elixir
test "ExchangeCode: valid code_verifier transitions session to authorized" do
  # TODO: implement
  assert false
end

test "ExchangeCode: invalid code_verifier does not transition session" do
  # TODO: implement
  assert false
end
```

The worker implements against these skeletons, not from scratch.

## Step 4: Infrastructure Contracts

The `circuit-breaker.allium` template models infrastructure behavior. It uses a `config` block for threshold values:

```allium
config CircuitBreakerSettings {
    failure_threshold: 5
    recovery_timeout_ms: 30000
}
```

This keeps magic numbers out of rules and makes them inspectable by `allium weed`.

## Step 5: Runex Workflow Specs

The `runex-workflow.allium` template models Runex workflow execution. Key pattern: state machines for async operations.

```allium
entity WorkflowRun {
    status: pending | running | succeeded | failed | timed_out
    ...
}
```

Use this template when writing a Runex workflow TOML bundle — propagate tests from the spec before writing the TOML.

## Composition with `use`

Specs can import each other:

```allium
use "./shared/oauth.allium" as oauth

rule ProtectedEndpoint {
    requires: oauth.AuthSession.status = authorized
    ...
}
```

Shared specs live in `docs/specs/shared/`. The `allium.config.json` at the repo root declares `specPaths: ["docs/specs"]`, so imports resolve correctly.

## Checklist for a New Epic with a Spec

- [ ] Copy the closest template to `docs/specs/<epic-slug>.allium`
- [ ] Edit entity fields, transitions, and rule names for the epic
- [ ] Add `spec: ./docs/specs/<epic-slug>.allium` to the epic markdown
- [ ] Commit the spec on the feature branch before spawning the team
- [ ] Worker: run `/allium:propagate` before writing implementation
- [ ] Validator: run `/allium:weed` after CI passes
