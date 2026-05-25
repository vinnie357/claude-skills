# Bundle structure and build workflow rules

Distilled rules for authoring Runex bundles, build workflows, and the runtime expectations a Runex-hosted node enforces.

## Bundle layout

A bundle is a directory under `bundles/*/` containing a `workflow.toml` at the top level.

- The `workflow.name` field MUST match the directory name. Mismatches break path resolution.
- Shared nushell helpers live in `<repo>/lib/` or are vendored into the consumer's `scripts/`. They are NOT bundles.
- Deploy artifacts (templates, manifests, scripts) live in `<repo>/deploy/`. They are NOT bundles.
- Every bundle's `mise.toml` declares a `BUNDLE_VERSION` env var so the runtime can detect drift.
- Workflow DAG dependencies use `depends = [...]`, NOT `needs = [...]`.

## Tool resolution inside bundles

All bundle scripts invoke tools via `mise exec <tool>@<version> -- <command>`. Bare command names (e.g., `claude`, `gh`, `node`) bypass mise resolution and pick up whatever the operator's shell PATH has at the moment — non-portable.

When a tool is installed via npm (e.g., `claude`, `gh` when fetched via npm), the wrapper script re-invokes Node. Pin Node in the same `mise.toml` so the npm-installed binary's runtime is also resolved through mise.

## Build workflow conventions

Build workflows clone into `/tmp/build/<id>/<app>/` from a local source cache, not from the operator's working clone. The pattern:

1. Shallow-clone the canonical clone into `/tmp/build/<id>/<app>/`.
2. `git pull origin main` inside the temp clone (advance HEAD).
3. Build.
4. Deploy.
5. Verify (`/api/info` `git_sha` MUST match the expected sha, not just `/api/health`).
6. Cleanup (`rm -rf /tmp/build/<id>/`).

Building in the operator's clone risks contamination from uncommitted changes and races with sibling workers.

## Burrito-style release caches

After `mix release` (or equivalent), remove the build cache before re-releasing the same version with new content. Burrito and similar release tools cache extracted ERTS by `<app-version>`; the new release inherits the OLD extracted BEAMs and the binary reports a stale `git_sha` even though the cache was rebuilt.

```bash
rm -rf .burrito/
rm -rf _build/prod
mix release
```

## Runtime expectations

- **CLI-first**: Runex is a single-binary CLI. `runex server` is one command; the CLI works standalone with the default SQLite store. Workflows do not assume a server is running.
- **SQLite default**: Runex defaults to SQLite. Postgres mode is enabled only via `RUNEX_DATABASE_URL` for multi-node federation.
- **Per-node, per-engine tool resolution**: Each node resolves tools per the enabled engine; do not flatten all paths into a single PATH for the runtime.
- **Explicit bundle import**: A bundle publish must end with an explicit `POST /api/bundles/import` against every registered target. Polling-based auto-import (`BUNDLE_SOURCES`) is a fallback, not a primary mechanism.
- **No API keys in workflow params**: Agent workflows authenticate via the local agent CLI (Claude Code or equivalent), not via an `ANTHROPIC_API_KEY` workflow param.
- **`/api/runs` shape**: Response objects are wrapped under `.data`. Consumers read `data.<field>`, not `<field>`.
- **System-level service**: Production Runex runs at the system level (launchd / systemd), not in a user-session terminal.
