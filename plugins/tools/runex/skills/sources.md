# Sources

## runex skill

### Runex Source Code
- **Source**: `~/github/runex/` (local repository)
- **Files consulted**:
  - `lib/runex_web/router.ex` -- API route definitions
  - `lib/runex_web/controllers/api/health_controller.ex` -- Health and readiness endpoints
  - `lib/runex_web/controllers/api/run_controller.ex` -- Run CRUD and step log endpoints
  - `lib/runex_web/controllers/api/workflow_controller.ex` -- Workflow listing and detail
  - `lib/runex_web/plugs/api_auth.ex` -- Bearer token authentication
  - `lib/runex/paths.ex` -- Workflow path resolution and bundle discovery
  - `CLAUDE.md` -- Architecture overview, environment variables, conventions
- **Key topics**: REST API endpoints, request/response shapes, workflow resolution order, authentication, database modes

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
