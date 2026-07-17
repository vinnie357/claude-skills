# Rig Plugin Sources

This file documents the sources used to create the rig plugin skill.

## Rig Skill

### Rig Project Site
- **URL**: https://rig.rs/
- **Purpose**: Project landing page for the rig Rust LLM framework
- **Date Accessed**: 2026-07-16

### Rig Documentation
- **URL**: https://docs.rig.rs/
- **Purpose**: Concept and guide documentation
- **Date Accessed**: 2026-07-16
- **Key Topics**: completion, chains, provider_clients, write_your_own_provider, rag_system

### Rig API Reference (docs.rs)
- **URL**: https://docs.rs/crate/rig-core/latest
- **Purpose**: Generated API reference for the `rig-core` crate
- **Date Accessed**: 2026-07-16

### Rig Source Repository
- **URL**: https://github.com/0xPlaygrounds/rig
- **Purpose**: Ground truth for every factual claim in this skill — client builders, model
  constants, the `CompletionModel` trait, `AgentBuilder` surface, `Extractor`, and MCP
  (`rmcp`) integration
- **Date Accessed**: 2026-07-16/17
- **Verified against**: `rig-core` 0.40.0, workspace layout `crates/rig-core/`, edition 2024
- **Key files read**: `providers/anthropic/client.rs`, `providers/anthropic/completion.rs`,
  `providers/openai/client.rs`, `providers/gemini/client.rs`, `providers/ollama.rs`,
  `agent/builder.rs`, `agent/tool.rs`, `client/mod.rs`, `client/completion.rs`,
  `extractor.rs`, `completion/mod.rs`, `completion/request.rs`, `Cargo.toml` (workspace and
  `rig-core`)

### Rig MCP Support Discussion
- **URL**: https://github.com/0xPlaygrounds/rig/discussions/635
- **Purpose**: Confirms MCP support landed in rig 0.16.0 (2025-07-30)
- **Date Accessed**: 2026-07-17

### Third-Party Field Report — Local Model Tool-Arg Typing
- **URL**: https://malachid.com (blog post, 2025-04-06)
- **Purpose**: Field report of small local models (via ollama) returning tool-call
  arguments as strings instead of typed values, breaking rig's typed `Args` deserialization
- **Date Accessed**: 2026-07-17
- **Note**: cited as a third-party observation, not a first-party rig claim

## Plugin Information

- **Name**: rig
- **Version**: 0.1.0
- **Description**: Building multi-provider and hybrid LLM clients in Rust with rig-core
- **Skills**: 1 skill covering setup, the AgentBuilder quickstart, multi-provider/hybrid
  harness guidance, local models and OpenAI-compatible gateways, agents/tools/extractors/MCP,
  RAG/embeddings, and streaming/pipelines
- **Created**: 2026-07-17
