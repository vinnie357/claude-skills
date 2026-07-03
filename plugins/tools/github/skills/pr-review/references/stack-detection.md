# Stack Detection and Gate Discovery

How to classify a PR's stack and discover the repo's gate tasks, so the reviewer loads the
right skills and runs the right gates — on any repo, not just Rust.

## Stack classification

Read the PR's changed file paths (`gh pr view <n> --json files`) and the repo's manifests.
Classify from the files, never the title. A PR touching more than one stack loads the union
of skill sets.

| Signal (extensions / manifest) | Stack | Reviewer skills (beyond the always-load set) |
|--------------------------------|-------|----------------------------------------------|
| `.rs`, `Cargo.toml`, `Cargo.lock` | rust | `/rust:rust`, `/rust:testing`, `/rust:error-handling` (add `/rust:async`, `/rust:ownership` for concurrency/lifetime-heavy diffs) |
| `.ex`, `.exs`, `mix.exs`, `mix.lock` | elixir | `/elixir:phoenix`, `/elixir:testing`, `/elixir:style`, `/elixir:ecto`, `/elixir:otp` (pick by what the diff touches) |
| `.zig`, `build.zig` | zig | `/zig:zig`, `/zig:testing`, `/zig:build` |
| `.ts`, `.js`, `package.json` | js | (no language skill in this marketplace — review with the always-load set; add `/ui:daisyui` for UI work) |
| `.md`, `docs/` only | documentation | `/core:documentation` |
| `.github/workflows/`, action pins, image digests | gh-actions/security | `/github:workflows`, `/github:actions`, `/core:security` |

Language-skill rows resolve only when the corresponding plugin is installed; otherwise review with the always-load set.

Always-load set (every reviewer, every PR): `/core:git`, `/core:mise`, `/core:security`,
`/core:anti-fabrication`.

## Gate discovery via /core:mise

Discover the repo's own gate tasks instead of assuming a toolchain. Run `mise tasks` and pick
the PR-gating tasks that exist:

| Task name | Typical contents |
|-----------|------------------|
| `ci` | the canonical gate (format check, lint, test) |
| `pre-commit` | `ci` plus security (audit, secret scan) |
| `test` | unit + integration tests |
| `lint` | linter (clippy, credo, etc.) |
| `fmt:check` | formatter in check mode |
| `audit` | dependency vulnerability audit |
| `gitleaks` | secret scanner |

Run `mise run <task>` for the discovered tasks. A haiku agent handles this discovery — the
task list is structured data from one command.

### When the repo has no mise

Fall back to the language-native gate the manifest implies (`cargo test`/`cargo clippy`,
`mix test`/`mix credo`, `zig build test`, `npm test`). The baseline-diff discipline is
identical regardless of the runner.

## Hosted CI vs local gates

Hosted CI sometimes runs a subset (for example, only format + lint) because the full suite
needs hardware the runner lacks — macOS, Apple Container, a GPU. In that case the **local**
`mise run ci` / `mise run pre-commit` is the real gate. Run the full local set under the
baseline-diff discipline — gate on `main` first, then the branch, blocking only on a new
failure. kina is exactly this shape: its
hosted CI runs `fmt`+`clippy` only; integration tests run locally against Apple Container.
