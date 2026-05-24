# Dependency documentation introspection in tier prompts

When a staged pipeline (P1 → P5 per the Five-Tier Decomposition Pipeline in the agent-loop skill body) touches a dependency the lead is not certain the worker has accurate knowledge of, the lead's spawn prompt MUST direct the worker to verify the dep's API via a runtime-introspection tool — not WebFetch, not training-data recall.

## The general rule

For each pipeline stage (Test Author, Implementer, Reviewer) that interacts with an unfamiliar dep, the lead-authored prompt includes:

1. The EXACT names of the runtime-introspection tools available in the project (e.g., a tidewave MCP for an Elixir project; equivalent for other ecosystems).
2. The SPECIFIC dep modules the worker is expected to interact with in this stage.
3. A directive: "verify the API surface before stubbing or implementing", with the explicit chain-of-thought rationale ("the running runtime is the source of truth, not training data").

Abstract instructions ("use the introspection tools") are insufficient — the worker silently skips the step. Naming the tools and the deps activates the use.

## Why this exists

Training-data dep knowledge is point-in-time. Major dep versions change callback signatures, deprecate constructors, and rename modules; a worker stubbing from memory produces code that fails to compile against the running version. The lead's cost of naming tools and deps in the spawn prompt is ~5 lines; the cost of NOT naming them is a failed tier handoff and a re-dispatch.

## Per-ecosystem implementations

- Elixir + Phoenix: `mcp__tidewave-<app>__search_package_docs`, `mcp__tidewave-<app>__get_docs`. See `/elixir:tidewave` "Using tidewave in tier prompts".
- Other ecosystems: name the equivalent runtime-introspection MCP or tool the project provides. Generic web docs (Hex.pm, npmjs.com, crates.io) are LESS reliable than runtime introspection because they may describe a version the project does not actually use.
