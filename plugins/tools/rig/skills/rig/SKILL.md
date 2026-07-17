---
name: rig
description: Guide for building LLM clients in Rust with rig (rig-core) — AgentBuilder, providers, tools, extractors, RAG, and streaming. Use when writing Rust LLM clients with rig or rig-core, building multi-provider or hybrid clients that mix Anthropic, OpenAI, Gemini, or local models, integrating ollama, LM Studio, or an OpenAI-compatible gateway (LiteLLM, Bifrost) from Rust, or implementing rig agents, tools, extractors, or RAG pipelines.
license: MIT
---

# Rig

Rig (crate `rig-core`) is a Rust library for building LLM-powered applications: provider
clients, agents with tools, structured extractors, RAG pipelines, and streaming completions.
This skill covers `rig-core` 0.40.0, workspace edition 2024, repo-pinned toolchain 1.94.0.

## Setup

```bash
cargo add rig-core
```

Feature flags relevant to agent work:

- `derive` — enables the `rig-derive` macros (schema derivation for tool/extractor types)
- `rmcp` — enables MCP (Model Context Protocol) tool integration via the `rmcp` crate

```toml
[dependencies]
rig-core = { version = "0.40", features = ["rmcp"] }
```

`derive` and `reqwest`/`rustls` ship in rig-core's default feature set; add `rmcp` explicitly
for MCP tools.

## AgentBuilder quickstart

Every provider client exposes `.agent(model)`, returning an `AgentBuilder`:

```rust
use rig_core::prelude::*;
use rig_core::providers::anthropic;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = anthropic::Client::from_env()?;

    let agent = client
        .agent(anthropic::completion::CLAUDE_SONNET_4_6)
        .preamble("Answer concisely.")
        .temperature(0.0)
        .build();

    let answer = agent.prompt("What is Rig?").await?;
    println!("{answer}");
    Ok(())
}
```

`from_env()` reads provider credentials from environment variables — no API key touches
application code. `.agent()` takes `impl Into<String>` for the model argument: a provider
module constant (`anthropic::completion::CLAUDE_SONNET_4_6`) or a raw string both work. See
`references/providers.md` for the constants available per provider and the env-var contract
each `from_env()` reads.

## Hybrid multi-provider harness

A single Rust process commonly needs several models at once — a cheap model for extraction,
a mid-tier model for the main loop, a strong model for review, one of them local. Rig
provides the primitives (clients, `AgentBuilder`, the `CompletionModel` trait) — it does not
ship a built-in multi-tier harness type. The tier-selection pattern in
`references/providers.md` is guidance built on those primitives, not a first-party rig
recipe.

The load-bearing constraint: `CompletionModel` is `Clone`-bound with no dyn-compatible
variant (no `Box<dyn CompletionModel>`, no `CompletionModelDyn`). Route between tiers with
enum dispatch over concrete `Agent<M>` types, generic functions bounded by
`M: CompletionModel`, or concrete per-tier fields on your own harness struct — never a
trait-object collection of agents. `references/providers.md` works through this with a
worked example spanning Anthropic, OpenAI, Gemini, and a local ollama tier.

## 12-factor model configuration

Read model IDs from environment variables, never hardcode them in application code:

```rust
let model_id = std::env::var("AGENT_MODEL").unwrap_or_else(|_| {
    anthropic::completion::CLAUDE_HAIKU_4_5.to_string()
});
let agent = client.agent(model_id).build();
```

This applies per tier in a hybrid harness — `AGENT_FAST_MODEL`, `AGENT_MAIN_MODEL`,
`AGENT_REVIEW_MODEL`, or equivalent names read at startup, not compiled in. Base URLs follow
the same rule: `ANTHROPIC_BASE_URL`, `OPENAI_BASE_URL`, `OLLAMA_API_BASE_URL` are read by
`from_env()` directly, or set explicitly via `ClientBuilder::base_url()` when a config value
comes from somewhere other than the environment.

## Reference map

- `references/providers.md` — per-provider client construction, env vars, model-ID strings
  vs constants, and the worked multi-provider/hybrid-tier harness example
- `references/local-and-gateways.md` — ollama (built-in), remote ollama, LM Studio, LiteLLM,
  and Bifrost via the OpenAI-compatible client + base URL, and the local-model typed
  tool-args gotcha
- `references/agents-tools.md` — full `AgentBuilder` surface, the `Tool` trait, extractors,
  and MCP integration via the `rmcp` feature
- `references/rag-embeddings.md` — `EmbeddingModel`, vector-store companion crates, and the
  RAG agent pattern
- `references/streaming-pipelines.md` — streaming completions and `rig::pipeline` `Op` chains

## Adversarial TDD

When implementing rig code under adversarial TDD, the `rust` plugin's
`rust-test-author`/`rust-implementer` pair applies unchanged — load this skill into both
workers. This skill is fully usable on its own without that pair.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Every client construction pattern, trait bound,
and constant cited here is verified against the `rig-core` 0.40.0 source tree (see
`sources.md`) — not inferred from training-data familiarity with an earlier rig version.
Before asserting a trait signature or constant this skill and its references do not cover,
check the installed `rig-core` version's source or docs.rs rather than guessing.
