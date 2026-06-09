---
name: graphify-agents
description: Use a graphify knowledge graph to give agents low-token codebase context — query the graph instead of reading raw files during research, decomposition, and impact analysis. Use when wiring graphify into an agent-loop, an Explore/research subagent, or an MCP-enabled agent, or when deciding when a graph query beats grepping and reading files.
license: MIT
---

# Graphify for Agents

Reading raw files into context is the dominant token cost of codebase-understanding work. Graphify builds a knowledge graph once (`graphify-out/graph.json`) and answers structural questions by traversing it — returning the relevant nodes and edges instead of whole files. This skill covers using that graph to make agent workflows cheaper and more targeted.

The project's published benchmark reports "**71.5x** fewer tokens per query vs reading raw files" on a mixed corpus, with smaller gains (≈5.4x on a 4-file corpus, ≈1x on a 6-file library) — the advantage scales with corpus size. Measure a specific repo with `graphify benchmark` before quoting a number; small repos see little benefit, so reserve the graph for large corpora.

For installing graphify and the full CLI surface, load the `graphify` skill.

## When to Use This Skill

Activate when:
- Giving a research or Explore subagent codebase context without reading every file
- Adding a graph-build + graph-query step to a `/core:agent-loop` Phase 1 pre-flight
- Doing impact analysis ("what breaks if I change X") before decomposing an epic
- Exposing the graph to an agent through the graphify MCP server
- Deciding between a graph query and grep+read for a given question

## The Core Pattern: Query, Don't Read

| Question shape | Without graphify | With graphify |
|----------------|------------------|---------------|
| "How does auth connect to the request pipeline?" | Grep, open 6–10 files, read each | `graphify query "how does auth connect to the request pipeline?"` → relevant nodes + edges |
| "What is `SwinTransformer` and what touches it?" | Read the class + every caller | `graphify explain "SwinTransformer"` |
| "What breaks if I change `add`?" | Trace callers by hand | `graphify affected "add"` |
| "How do these two modules connect?" | Read both, infer | `graphify path "DigestAuth" "Response"` |

`query` returns within a token budget (`--budget`, default 2000), so an agent gets a bounded, relevant slice rather than unbounded file contents.

## Integration with /core:agent-loop

Graphify slots into the loop's existing phases without replacing them. Load `/core:agent-loop` for the phase model.

**Phase 1 (Pre-flight / research).** Before decomposition, build or refresh the graph, then have the research/Explore subagent query it instead of fanning out file reads:

```bash
mise run graphify:update      # AST-only refresh, no API key needed
graphify query "where is <epic-area> implemented and what does it depend on?"
```

Feed the query result into the Team Leader's decomposition. The graph names the real files and symbols to reference in worker prompts — which the agent-loop prompt template already requires ("reference existing code and functions to reuse").

**Phase 2 (Working).** Give each worker the `path`/`explain` output for its slice instead of pre-reading files into the prompt. Workers still read the specific files they edit.

**Impact analysis before slicing.** `graphify affected "<symbol>"` (needs a full clustered build) surfaces the blast radius of a change, which informs dependency edges between bees issues.

## Keeping the Graph Fresh

A stale graph misleads agents the way stale docs do. Keep it current:

```bash
graphify hook install    # rebuild on post-commit / post-checkout
graphify watch .         # rebuild live during a session
```

The agent that relies on the graph confirms freshness — `graphify check-update .` reports whether a semantic re-extraction is pending. Treat graph claims like any other: an agent verifies a graph answer against the actual file before acting on it (anti-fabrication).

## Exposing the Graph via MCP

`graphify . --mcp` starts an MCP stdio server (the `[mcp]` extra / `graphify-mcp` console script). An MCP-enabled agent then calls graphify tools directly rather than shelling out. See `/claude-code:claude-agents` (MCP-enabled agent pattern) for declaring the server in an agent's tool set.

## Registering graphify with Claude Code

`graphify claude install` writes a graphify section to `CLAUDE.md` and a PreToolUse hook so a Claude Code session reaches for the graph automatically. This is graphify's own integration; this marketplace's `graphify`/`graphify-agents` skills are the alternative, progressive-disclosure path that does not modify `CLAUDE.md`.

## When NOT to Use the Graph

- Small repos (the benchmark shows ≈1x on a 6-file library) — grep+read is simpler.
- Questions about the exact current contents of one known file — read it.
- Anything where the graph has not been rebuilt since the relevant code changed — refresh first or read directly.

## Anti-Fabrication Requirements

- Run `graphify benchmark` (or cite the project's published figures as such) before stating a token-savings number — never present a benchmark figure as independent measurement.
- Verify a graph answer against the actual source file before an agent acts on it.
- Confirm graph freshness (`graphify check-update`) before trusting a query in a long session.
- State which commands require a full clustered build vs a raw AST extraction (`affected` and community labels need clustering).
