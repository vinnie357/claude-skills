# Graphify CLI Reference

Captured from `graphify --help` on graphify 0.8.36. Run `graphify --help` to confirm against the installed version. Default graph path is `graphify-out/graph.json`; default output directory is `graphify-out/`.

## Table of Contents

- [Build & maintain](#build--maintain)
- [Query & inspect](#query--inspect)
- [Export & visualize](#export--visualize)
- [Headless extraction](#headless-extraction)
- [Cross-repo (global) graphs](#cross-repo-global-graphs)
- [Git hooks & merge](#git-hooks--merge)
- [Assistant registration](#assistant-registration)

## Build & maintain

Build is the bare path form: `graphify <path>` (e.g. `graphify .`). Build-time export flags (`--graphml`, `--svg`, `--neo4j`, `--wiki`, `--mcp`, `--mode deep`, `--update`) attach to this form.

| Command | Purpose | Key flags |
|---------|---------|-----------|
| `graphify <path>` | Build/refresh the graph | `--mode deep`, `--update`, `--watch`, export flags |
| `graphify update <path>` | Re-extract code via AST and update the graph (no LLM) | `--force`, `--no-cluster` |
| `graphify cluster-only <path>` | Rerun clustering on an existing `graph.json`, regenerate report | `--no-viz`, `--no-label`, `--backend=<name>`, `--graph <path>` |
| `graphify label <path>` | (Re)name communities with the configured LLM backend | `--backend=<name>` |
| `graphify add <url>` | Fetch a URL, save to `./raw`, then update the graph | `--author "Name"`, `--contributor "Name"`, `--dir <path>` |
| `graphify watch <path>` | Watch a folder and rebuild on code changes | — |
| `graphify check-update <path>` | Cron-safe check of the `needs_update` flag | — |
| `graphify clone <github-url>` | Clone a GitHub repo locally and print its path | `--branch <branch>`, `--out <dir>` |

`update --force` overwrites `graph.json` even if the rebuild has fewer nodes (also `GRAPHIFY_FORCE=1`); use after refactors that delete code.

## Query & inspect

| Command | Purpose | Key flags |
|---------|---------|-----------|
| `graphify query "<question>"` | BFS traversal of `graph.json` for a question | `--dfs`, `--context C` (repeatable), `--budget N` (default 2000), `--graph <path>` |
| `graphify path "A" "B"` | Shortest path between two nodes | `--graph <path>` |
| `graphify explain "X"` | Plain-language explanation of a node and its neighbors | `--graph <path>` |
| `graphify affected "X"` | Reverse traversal: nodes impacted by X | `--relation R` (repeatable), `--depth N` (default 2), `--graph <path>` |
| `graphify save-result` | Save a Q&A result to `graphify-out/memory/` for the feedback loop | `--question`, `--answer`, `--type query\|path_query\|explain`, `--nodes N1 N2 ...`, `--memory-dir` |
| `graphify diagnose multigraph` | Report same-endpoint edge collapse risk | `--json`, `--max-examples N`, `--directed`/`--undirected`, `--extract-path` |
| `graphify benchmark [graph.json]` | Measure token reduction vs naive full-corpus reading | — |

`query`, `path`, and `explain` operate on a raw AST-extracted graph. `affected` requires a clustered build (errors with `could not load graph: 'links'` on an unclustered extraction).

## Export & visualize

| Command / flag | Output |
|----------------|--------|
| `graphify . --graphml` | GraphML (Gephi, yEd) |
| `graphify . --svg` | SVG vector graph |
| `graphify . --neo4j` | Neo4j/Cypher MERGE statements |
| `graphify . --wiki` | Wikipedia-style markdown |
| `graphify . --mcp` | MCP stdio server |
| `graphify export callflow-html` | Mermaid-based architecture / call-flow HTML |
| `graphify tree` | D3 v7 collapsible-tree HTML (`--graph`, `--output`, `--root`, `--max-children` default 200, `--top-k-edges` default 12, `--label`) |

## Headless extraction

`graphify extract <path>` — headless full extraction (AST + semantic LLM) for CI/scripts.

| Flag | Purpose |
|------|---------|
| `--backend B` | `gemini\|kimi\|claude\|openai\|deepseek\|ollama` (default: whichever API key is set) |
| `--model M` | Override backend default model |
| `--mode deep` | Aggressive INFERRED-edge semantic extraction |
| `--max-workers N` | AST extraction subprocess count (default: cpu_count) |
| `--token-budget N` | Per-chunk token cap for semantic extraction (default: 60000) |
| `--max-concurrency N` | Parallel semantic chunks (default: 4; set 1 for local LLMs) |
| `--api-timeout S` | Per-request LLM timeout (default: 600) |
| `--out DIR` | Output dir (default: `<path>`); writes `<DIR>/graphify-out/` |
| `--no-cluster` | Skip clustering, write raw extraction only |
| `--postgres DSN` | Extract schema from a live PostgreSQL database |
| `--global` / `--as <tag>` | Also merge the result into the global graph under a tag |

## Cross-repo (global) graphs

| Command | Purpose |
|---------|---------|
| `graphify global add <graph.json> [--as <tag>]` | Add/update a project graph in `~/.graphify/global-graph.json` |
| `graphify global remove <tag>` | Remove a repo's nodes from the global graph |
| `graphify global list` | List repos in the global graph |
| `graphify global path` | Print the path to the global graph file |
| `graphify merge-graphs <g1> <g2> [--out <path>]` | Merge two or more `graph.json` files into one cross-repo graph |

## Git hooks & merge

| Command | Purpose |
|---------|---------|
| `graphify hook install` | Install post-commit/post-checkout git hooks |
| `graphify hook uninstall` | Remove git hooks |
| `graphify hook status` | Check whether git hooks are installed |
| `graphify merge-driver <base> <current> <other>` | Git merge driver: union-merge two `graph.json` files (set up via `hook install`) |

## Assistant registration

`graphify install [--platform P]` copies the graphify skill into a platform's config dir. `graphify uninstall [--purge]` removes it from all detected platforms. Per-platform subcommands write assistant-specific config:

- `graphify claude install` — writes a graphify section to `CLAUDE.md` + a PreToolUse hook (Claude Code)
- `graphify codex install` / `graphify aider install` / `graphify claw install` / `graphify droid install` — write a graphify section to `AGENTS.md`
- `graphify cursor install` — writes `.cursor/rules/graphify.mdc`
- `graphify gemini install` — writes a `GEMINI.md` section + BeforeTool hook
- `graphify opencode install` — writes an `AGENTS.md` section + plugin
- `graphify copilot install` / `graphify vscode install` — GitHub Copilot CLI / VS Code Copilot Chat

Platform list (from `--help`): `claude|windows|codebuddy|codex|opencode|aider|amp|claw|droid|trae|trae-cn|gemini|cursor|antigravity|hermes|kiro|pi|devin`.
