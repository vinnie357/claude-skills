---
name: graphify
description: Build and query a knowledge graph of a codebase, docs, and mixed media with the graphify CLI. Use when installing graphify via mise, building or updating a code graph, exporting it (GraphML, SVG, Neo4j, Obsidian, call-flow HTML), or querying it with query/path/explain/affected instead of reading raw files.
license: MIT
---

# Graphify

Graphify converts a folder of code, docs, PDFs, images, and videos into a queryable knowledge graph. It extracts symbols and relationships locally with tree-sitter (no code leaves the machine for AST extraction), writes the graph to `graphify-out/graph.json` plus an interactive `graph.html`, and answers questions by traversing the graph instead of re-reading files.

PyPI package: **`graphifyy`** (double-y). CLI command: **`graphify`**. License: MIT. Requires Python >= 3.10.

## When to Use This Skill

Activate when:
- Installing graphify in a project via mise
- Building or refreshing a knowledge graph of a repository or document corpus
- Exporting a graph to GraphML, SVG, Neo4j/Cypher, an Obsidian vault, or call-flow HTML
- Querying a codebase with `query`, `path`, `explain`, or `affected`
- Setting up `graphify hook install` to rebuild the graph on git commits
- Wiring graphify into an AI assistant via `graphify install` / `graphify claude install`

For using graphify to reduce agent token usage during research and decomposition, load `graphify-agents`.

## Installation

### Using mise (recommended for this project)

Copy `templates/mise.toml` from this skill into the project's `mise.toml`, then run `mise install`. graphify is a PyPI package, so mise installs it through its `pipx` backend; the template pins `uv` as the backend installer and enables uvx mode so one `mise install` resolves `uv` then `graphifyy`:

```toml
[settings.pipx]
uvx = true

[tools]
python = "3.12"
uv = "latest"
"pipx:graphifyy" = "0.8.36"
```

```bash
mise trust && mise install     # installs python, uv, then graphifyy
graphify --version             # → graphify 0.8.36
```

Verify the backend sees the package before pinning a different version:

```bash
mise ls-remote pipx:graphifyy | tail -5
```

### Alternative installation (upstream)

The project's own documented install (outside mise):

```bash
pip install graphifyy && graphify install
```

`pip install graphifyy` also accepts extras, e.g. `pip install "graphifyy[all]"`. Available extras: `pdf, office, google, video, mcp, neo4j, svg, leiden, ollama, openai, gemini, anthropic, bedrock, azure, sql, postgres, dm, terraform, chinese, all`.

## How Graphify Works

1. **Scan + extract** — walks the target path, classifies files (code, docs, papers, images), and runs tree-sitter AST extraction locally. AST extraction needs no LLM and no network.
2. **Infer relationships** — semantic edge inference uses a configured LLM backend (`gemini|kimi|claude|openai|deepseek|ollama`, auto-detected from available API keys). Skippable with `--no-cluster` / `update`.
3. **Cluster + label** — community detection groups related nodes; an LLM names the communities (skippable with `--no-label`).
4. **Write outputs** — `graphify-out/graph.json` (NetworkX node-link JSON), `graph.html` (interactive viz), and a markdown report.
5. **Query** — `query`/`path`/`explain`/`affected` traverse `graph.json` with no LLM call for the traversal itself.

Default output directory: `graphify-out/`. Default graph path: `graphify-out/graph.json`.

## Building a Graph

```bash
graphify .                       # build the graph for the current directory
graphify ./raw                   # build for a specific path
graphify ./raw --mode deep       # aggressive INFERRED-edge semantic extraction
graphify update .                # re-extract code via AST only — no LLM, no API key
graphify cluster-only .          # rerun clustering/report on an existing graph.json
graphify add https://arxiv.org/abs/1706.03762   # fetch a URL into ./raw, then update
```

`update` is the offline path: it rebuilds the graph from code with no LLM backend, which is what runs without any API key configured.

## Exporting

Export flags run on a build invocation:

```bash
graphify . --graphml             # GraphML (Gephi, yEd)
graphify . --svg                 # SVG vector graph
graphify . --neo4j               # Neo4j/Cypher MERGE statements
graphify . --wiki                # Wikipedia-style markdown
graphify . --mcp                 # start the MCP stdio server
graphify export callflow-html    # Mermaid-based architecture / call-flow HTML
graphify tree                    # D3 collapsible-tree HTML of the module hierarchy
```

## Querying

```bash
graphify query "what connects attention to the optimizer?"   # BFS traversal, default 2000-token budget
graphify query "..." --budget 1500     # cap output at N tokens
graphify query "..." --dfs             # depth-first instead of breadth-first
graphify path "DigestAuth" "Response"  # shortest path between two nodes
graphify explain "SwinTransformer"     # plain-language explanation of a node + neighbors
graphify affected "add"                # reverse traversal: nodes impacted by a change to "add"
```

`query`, `path`, and `explain` work on a raw AST-extracted `graph.json`. `affected` and community labels need a full clustered build (it errors with `could not load graph: 'links'` on an unclustered raw extraction).

## Continuous Updates

```bash
graphify watch .                 # watch a folder, rebuild on code changes
graphify hook install            # install post-commit/post-checkout git hooks
graphify hook status             # check whether hooks are installed
graphify check-update .          # cron-safe check of the needs_update flag
```

## Excluding Files

graphify honors a `.graphifyignore` file (gitignore syntax) in the target directory to skip dependencies, build output, caches, and secrets. Keep generated graphs and secrets out of the corpus.

## CLI Reference

For the full command and flag surface (extraction backends, `global` cross-repo graphs, `merge-graphs`, per-platform `install` targets, and every flag captured from `graphify --help`), see `references/cli.md`.

## Anti-Fabrication Requirements

- Run `graphify --version` before stating the installed version.
- Run `graphify --help` (or read `references/cli.md`) before documenting a command or flag — do not infer flags from blog posts.
- Run `mise ls-remote pipx:graphifyy` before pinning a version.
- Build a real graph and run an actual `query` before claiming a graph answers a given question.
- Report token-reduction numbers only from `graphify benchmark` output or the project's own published figures, attributed as such — never as independent measurement.
