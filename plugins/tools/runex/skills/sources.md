# Sources

## runex skill

### Runex Source Code
- **Source**: `~/github/runex/` (local repository — private GitHub repo `vinnie357/runex`)
- **Files consulted**:
  - `mix.exs` -- Application version pinning (`@version`)
  - `lib/runex_web/router.ex` -- API route definitions
  - `lib/runex_web/controllers/api/health_controller.ex` -- Health and readiness endpoints
  - `lib/runex_web/controllers/api/run_controller.ex` -- Run CRUD and step log endpoints
  - `lib/runex_web/controllers/api/workflow_controller.ex` -- Workflow listing and detail
  - `lib/runex_web/controllers/api/heartbeat_controller.ex` -- Step heartbeat endpoint
  - `lib/runex_web/controllers/api/bundle_controller.ex` -- Bundle list/import/reload/sync/webhook
  - `lib/runex_web/controllers/api/federation_controller.ex` -- Federation node and run endpoints
  - `lib/runex_web/plugs/api_auth.ex` -- Bearer token authentication
  - `lib/runex/paths.ex` -- Workflow path resolution and bundle discovery
  - `lib/runex/driver.ex` -- Driver registry and behaviour
  - `lib/runex/drivers/*.ex` -- Per-driver implementations (shell, mise, nushell, runex, wasm, container, flame, workflow)
  - `lib/runex/parser/toml.ex` -- Workflow and step schema (step fields, defaults)
  - `lib/runex/bundles/loader.ex` -- Bundle scan/upsert pipeline
  - `config/runtime.exs` -- Environment variable defaults (port, bind, RUNEX_MASKED_VARS, etc.)
  - `docs/openapi.yaml` -- Authoritative API contract
  - `docs/federation.md` -- Federation deployment guide
  - `docs/workflow-format.md` -- TOML workflow schema reference
  - `docs/bundle-loading.md` -- Bundle pipeline doc
  - `CLAUDE.md` -- Architecture overview, environment variables, conventions
- **Key topics**: REST API endpoints, request/response shapes, workflow resolution order, authentication, database modes, federation, bundle pull-mode distribution

### Update history
- **2026-05-17**: Bumped target version to Runex v0.0.7 (`mix.exs @version`) before the v0.0.6 refresh was merged. Renamed `templates/0.0.6/` -> `templates/0.0.7/` and `scripts/0.0.6/` -> `scripts/0.0.7/`. Removed all `agent_runs` documentation, scripts commands, and debugging guidance — upstream commit `5dbffbc` ("chore: delete unused Runex.Agents subsystem per YAGNI") removed `lib/runex/agents.ex`, `lib/runex_web/controllers/api/agent_runs_controller.ex`, the `/api/agent_runs[/:id]` routes, `AgentMonitor`, and the `agent_runs` table. No external callers had materialized — VantageEx tracks agent sessions in its own `Epic` schema instead. Re-add docs only if a future Runex release reintroduces the subsystem with a real first caller.
- **2026-05-16**: Refreshed against Runex v0.0.6 (initial sweep — superseded by the 2026-05-17 0.0.7 rename). Created versioned `templates/0.0.6/` + `scripts/0.0.6/`; froze `templates/0.1.0/` + `scripts/0.1.0/` for older deployments. Added drivers (`runex`, `wasm`, `container`, `flame`, `workflow`), step heartbeat endpoint, federation endpoints, `BUNDLE_SOURCES` pull-mode bundle import. Default port corrected to `4000` (was documented as `4001` — that's an operator convention, not the app default). `RUNEX_MASKED_VARS` env replaces hardcoded sensitive-pattern list. Added `templates/<version>/mise.toml` pinning Runex via the github backend.

### VantageEx Autonomous Loop
- **Source**: `~/github/vantage_ex/AUTONOMOUS-LOOP.md`
- **Key topics**: Runex API usage patterns, bundle locations, workflow submission examples, health check patterns, debugging procedures

### Runex Workflow Bundles
- **Source**: `~/github/runex-workflows/bundles/`
- **Bundles examined**: core, deploy-to-mini, postgres, tool-verify
- **Files consulted**:
  - `bundles/core/workflow.toml` -- Root dispatcher pattern with ACTION param
  - `bundles/core/workflows/system-info.toml` -- Sub-workflow example
  - `bundles/core/mise.toml` -- Tool dependency declaration
  - `bundles/postgres/workflow.toml` -- Multi-action dispatcher with optional params
  - `bundles/tool-verify/scripts/` -- Script invocation patterns
- **Key topics**: Bundle directory structure, dispatcher pattern, sub-workflow invocation, script organization, mise tool deps
