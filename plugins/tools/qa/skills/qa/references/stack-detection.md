# Stack Detection

How `qa-lead` decides which worker handles each scenario.

## Probe Tree

The lead runs probes in this order, from the target repo root, before decomposing scenarios. Each probe is read-only.

```
1. Phoenix?           → look for mix.exs AND (config/runtime.exs OR lib/<app>_web/)
2. Web UI?            → look for package.json AND (playwright.config.{ts,js,mjs} OR a web framework dep)
3. Generic backend?   → look for Cargo.toml, go.mod, pyproject.toml, build.zig, Gemfile, pom.xml
4. Container runtime? → look for Dockerfile, docker-compose.yml (informational only)
```

The result is recorded as a triple:

```
{ ui: <bool>, phoenix: <bool>, generic_backend: <bool> }
```

## Probe Commands

```bash
# Phoenix
test -f mix.exs && echo "mix-present"
test -f config/runtime.exs && echo "phx-runtime-present"
ls lib/*_web 2>/dev/null

# Web UI
test -f package.json && echo "node-present"
ls playwright.config.* 2>/dev/null

# Generic backends
for f in Cargo.toml go.mod pyproject.toml build.zig Gemfile pom.xml; do
  test -f "$f" && echo "$f"
done
```

The lead runs these via the Bash tool. Do not infer presence from memory — always probe.

## Worker Assignment Matrix

| Stack triple | UI scenario step | Backend scenario step | Mixed scenario |
|---|---|---|---|
| `{ui: true, phoenix: true}` | qa-playwright | qa-tidewave | qa-playwright + qa-tidewave |
| `{ui: true, phoenix: false}` | qa-playwright | qa-backend | qa-playwright + qa-backend |
| `{ui: false, phoenix: true}` | qa-tidewave (read-only headless asserts only) or reject | qa-tidewave | qa-tidewave |
| `{ui: false, phoenix: false}` | qa-backend (curl + WebFetch only) or reject | qa-backend | qa-backend |

A "UI scenario step" mentions clicks, page elements, navigation, or visible text. A "backend scenario step" mentions DB rows, log lines, internal state, HTTP status codes, or response payloads. The hints come from `references/gherkin-format.md`.

## Mixed-Scenario Correlation

When a single `Scenario:` block has both UI and backend `Then` clauses, the lead spawns two workers and correlates by exact scenario name (case- and whitespace-preserving). The bees-manager batch deduplicates by external-ref + title so a delta filed by both workers does not double-file.

The lead waits for BOTH workers to complete before routing to `bees-manager`. A scenario passes only if both workers report PASS.

## Reject Conditions

The lead refuses to proceed if:

- The story has UI scenarios but the stack triple has `ui: false` AND `phoenix: false`. There is nothing to drive.
- The story has no scenarios applicable to the detected stack.
- A required runtime is not running (Playwright MCP unreachable, Phoenix app not responding on its declared URL). The lead probes the URL with a short curl before dispatching.

Reject reports name the missing piece so the user can start the app or install the MCP.

## URL Resolution

The `Background:` block of the story is the authoritative source for the app URL. The lead extracts URLs from `Given the <app|storefront|service> is running at <url>` patterns. If the Background omits the URL, the lead falls back to:

- `localhost:4000` for Phoenix
- `localhost:3000` for Node/React/Next
- `$QA_APP_URL` environment variable as a last resort

If no URL can be resolved, the lead rejects with a "missing app URL" error and points the user to the `Background:` convention.
