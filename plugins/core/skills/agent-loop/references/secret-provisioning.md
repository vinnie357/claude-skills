# Tier 1 plans for env-var-backed features include provisioning

When a Tier 1 plan introduces a feature that reads NEW environment variables at runtime (via `System.get_env`, `Application.get_env` of newly-added config keys, `process.env.<KEY>`, etc.), the plan's operator-actions section MUST cover symmetric provisioning across every environment that runs the binary.

Failure to include this turns the feature INERT after deploy: the binary ships, the build verification (sha + build_time) passes, and the endpoints return `401` / `500` because runtime config is `nil`. The bug surfaces only on first manual probe of the feature.

## Mandatory operator-actions content

For each new env var the feature reads, the Tier 1 spec includes:

1. **Generation command** — verbatim, runnable, producing a value of the correct shape (length, encoding). Prefer commands that work in a portable shell (`openssl rand -hex 32`, `openssl rand 32 | base64`, `head -c 32 /dev/urandom | base64`, `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`). Avoid generation commands that depend on a project-local toolchain unless the spec also documents the toolchain setup.

2. **Secret-store creation** — verbatim commands for the project's secret store (1Password, Vault, AWS Secrets Manager, GitHub Actions secrets, etc.) creating the item AND a verification command that confirms the value is non-empty (not just that the item exists).

3. **Production deploy template diff** — the unified-diff snippet showing the new env-var injection into the production startup script (`start.sh`, systemd unit, Dockerfile ENTRYPOINT, k8s Deployment env, etc.). Tier 1 produces this diff up-front, not as a follow-up.

4. **Developer-local environment diff** — symmetric coverage for the local dev environment (`mise.toml` dev task, `.env.example`, `direnv` config, container compose file, etc.). Missing this means `mise dev` / `npm run dev` / equivalent fails at boot when the developer's environment validation catches the empty env var. Caught in production via dev-side regressions when the prod path is updated but the dev path is not.

5. **Phase ordering** — secret-provisioning + production AND developer template changes are PREREQUISITES for the deploy step. The plan sequences these BEFORE the binary-deploy step, not after.

## Tier 5 reviewer check

The Tier 5 reviewer prompt for any plan that introduces this class of feature includes:

> Scan the diff for new `System.get_env` / `Application.get_env` / `process.env.<KEY>` reads of keys not previously in config. For each new key, verify the spec's operator-actions section includes (a) generation command, (b) secret-store creation, (c) production deploy diff, (d) developer-local environment diff. Missing any of the four = BLOCKER, not NIT.

## Why this exists

Build verification (sha match + build_time after deploy) proves the BINARY shipped. It does NOT prove the binary's RUNTIME CONFIG is populated. The deployed binary reads from env vars that were never set; the binary runs but its endpoints do not work. The smoke test that catches this is "hit the new endpoint with valid creds expecting 200", not "the service responds to `/api/health` with 200".

The cost of provisioning steps in the plan: ~50 lines of documentation + a few minutes of operator action at plan-approval time. The cost without: hours of post-deploy debug + a redeploy cycle + the feature is INERT in production until manually caught.
