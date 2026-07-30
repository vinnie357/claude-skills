# Graphify Plugin Sources

This file documents the sources used to create the graphify plugin skills.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there. Entries: `graphify` (the graphify PyPI/GitHub/CLI sections below), `core:mise` (the mise pipx backend section below).

## graphify Skill

### graphify on PyPI (primary)
- **URL**: https://pypi.org/pypi/graphifyy/json
- **Purpose**: Authoritative package name, version, license, Python floor, and optional-dependency extras
- **Date Accessed**: 2026-06-08
- **Key Topics**:
  - Package `graphifyy` (CLI command `graphify`), version 0.8.36, MIT, requires Python >= 3.10
  - Extras: pdf, office, google, video, mcp, neo4j, svg, leiden, ollama, openai, gemini, anthropic, bedrock, azure, sql, postgres, dm, terraform, chinese, all

### graphify GitHub repository
- **URL**: https://github.com/safishamsi/graphify
- **Purpose**: Project overview, install path, build/query/export command examples, published benchmark figures
- **Date Accessed**: 2026-06-08
- **Key Topics**:
  - `pip install graphifyy && graphify install`
  - Build/export/query commands; `.graphifyignore`; MCP server; 71.5x / 5.4x / ~1x token-reduction figures

### `graphify --help` (installed 0.8.36, primary)
- **URL**: local execution — `graphify --help` after `mise install` of `pipx:graphifyy@0.8.36`
- **Purpose**: Authoritative command and flag surface captured into references/cli.md
- **Date Accessed**: 2026-06-08
- **Key Topics**:
  - build / update / cluster-only / label / add / watch / check-update / clone
  - query / path / explain / affected / diagnose / benchmark / save-result
  - extract backends; global cross-repo graphs; merge-graphs; hook install; per-platform install targets

### mise pipx backend (install path)
- **URL**: https://mise.jdx.dev (pipx backend) — verified via `/core:mise`
- **Purpose**: Installing a PyPI package through mise; uvx-mode requirement
- **Date Accessed**: 2026-06-08
- **Key Topics**:
  - `[settings.pipx] uvx = true` + `uv` tool so a single `mise install` resolves uv then `pipx:graphifyy`
  - `mise ls-remote pipx:graphifyy` to verify versions

## graphify-agents Skill

### graphify GitHub repository (agent integration)
- **URL**: https://github.com/safishamsi/graphify
- **Purpose**: Query-the-graph-instead-of-reading-files model, MCP server, benchmark figures
- **Date Accessed**: 2026-06-08
- **Key Topics**: query/path/explain/affected; token budget; MCP stdio server; `graphify claude install`
