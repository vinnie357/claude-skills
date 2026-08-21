---
name: allium
description: Allium behavioral specs integrated with /core:agent-loop. Use when attaching a formal spec to an epic, propagating tests from a spec before TDD, or weed-checking spec/code divergence after CI passes.
license: MIT
---

# Allium

Opinionated integration between [juxt/allium](https://github.com/juxt/allium) and the `/core:agent-loop` workflow. Allium captures observable behavior in `.allium` files using `entity`, `rule`, and `config` blocks — implementation-agnostic, co-located with code.

## Prerequisites

Upstream Allium Claude plugin must be installed separately:

```
/plugin install allium@juxt
```

The CLI (`allium-tools` binary) installs via mise — see `references/installation.md`.

## Spec Location Convention

Recommended convention for projects adopting this skill: specs live at `docs/specs/<epic-slug>.allium` with shared specs in `docs/specs/shared/`. A project-root `allium.config.json` declares `specPaths: ["docs/specs"]` so the CLI and LSP resolve them. Copy `templates/allium.config.json` into the project root to bootstrap this layout.

## Integration Points by Tier

See `references/agent-loop-integration.md` for the complete 6-tier breakdown. Summary:

| Tier | Allium action |
|---|---|
| Epic Author | Run `/allium:elicit` or copy a template from `templates/`; set `spec:` field in epic markdown |
| Team Leader | If refactor label and no spec: run `/allium:distill` for baseline |
| Worker | If spec attached: run `/allium:propagate` to seed failing tests BEFORE implementing |
| Validator | After CI passes: run `/allium:weed`; divergences route to fix-agent same as CI failures |

## Spec Syntax (v3)

```allium
entity Order {
    status: pending | confirmed | shipped | delivered | cancelled
    tracking_number: String when status = shipped | delivered

    transitions status {
        pending -> confirmed
        confirmed -> shipped
        terminal: delivered, cancelled
    }

    invariant NonNegativeTotal { this.total >= 0 }
}

rule ShipOrder {
    when: ShipOrder(order, tracking)
    requires: order.status = confirmed
    ensures:
        order.status = shipped
        order.tracking_number = tracking
}
```

Key constructs:
- `entity` — domain object with typed fields, conditional attributes (`when`), state transitions, and invariants
- `rule` — behavioral rule with `when` (trigger), `requires` (preconditions), `ensures` (postconditions)
- `config` — project-level settings (thresholds, retry counts, timeout values)
- `use` — import another spec: `use "./shared/oauth.allium" as oauth`

## Templates

Copy-pasteable specs in `templates/`:

- `oauth-pkce-flow.allium` — OAuth2 PKCE flow matching the agent-loop epic-authoring example
- `circuit-breaker.allium` — infrastructure contract with `entity` + `config` + `rule`
- `runex-workflow.allium` — spec for a Runex workflow step
- `epic-with-spec.md` — VantageEx epic showing the `spec:` field in use

See `references/epic-spec-template.md` for a guided walkthrough.

## Anti-Fabrication

All claims about spec content must derive from reading actual `.allium` files with Read tool. Never assert that a spec covers a behavior without verifying the `ensures` or `invariant` blocks. See `/core:anti-fabrication`.

## References

- `references/installation.md` — mise backend details and upstream plugin install
- `references/agent-loop-integration.md` — 6-tier integration procedure
- `references/epic-spec-template.md` — template walkthrough
- `references/distilling-legacy-code.md` — `/allium:distill` procedure for existing modules
