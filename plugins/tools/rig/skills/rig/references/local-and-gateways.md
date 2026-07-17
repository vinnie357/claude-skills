# Local Models and Gateways

Rig ships a built-in ollama client. Every other OpenAI-wire-compatible local runtime or
gateway — LM Studio, LiteLLM, Bifrost — goes through the OpenAI client plus a custom base
URL. This reference covers both paths and a gotcha specific to small local models.

## Ollama (built-in)

`rig::providers::ollama` reads `OLLAMA_API_BASE_URL` (default `http://localhost:11434`) and
an optional `OLLAMA_API_KEY` — ollama has no auth by default:

```rust
use rig_core::client::Nothing;
use rig_core::providers::ollama;

// No auth needed for a default local ollama install
let client = ollama::Client::new(Nothing)?;
let agent = client.agent("llama3.1:8b-instruct-q4_0").build();
```

Or via environment, matching every other provider's `from_env()` contract:

```rust
let client = ollama::Client::from_env()?;
```

## Remote ollama

Point at a non-default host by setting `OLLAMA_API_BASE_URL` before `from_env()`, or by
constructing the client explicitly with a base URL through the shared `ClientBuilder`
pattern (see `providers.md`).

## LM Studio, LiteLLM, Bifrost — via the OpenAI client

LM Studio, LiteLLM, and Bifrost all expose an OpenAI-wire-compatible `/v1` endpoint. Rig has
no dedicated client module for any of them — the integration path is the OpenAI client with
a custom base URL, the same `ClientBuilder::base_url()` mechanism documented in
`providers.md`:

```rust
use rig_core::providers::openai;

// LM Studio's default local endpoint
let client = openai::Client::builder()
    .api_key("not-needed-locally")
    .base_url("http://localhost:1234/v1")
    .build()?;

let agent = client.agent("local-model-id").build();
```

The same shape covers a LiteLLM or Bifrost gateway — substitute the gateway's base URL and
its API key. Setting `OPENAI_BASE_URL` before calling `openai::Client::from_env()` achieves
the same result without a custom builder call, useful when the gateway URL is deployment
configuration rather than a compile-time constant.

## Local-model typed tool-arg gotcha

A third-party field report (malachid.com blog, 2025-04-06) observed small local models
served through ollama — specifically `llama3.2` — returning tool-call arguments as strings
where rig's typed `Args` deserialization expected integers, breaking the tool call.
`llama3.1:8b-instruct-q4_0` returned correctly typed arguments in the same report. This is
model behavior, not a rig defect: small local models can violate the typed tool-argument
contract a `Tool` implementation declares via its `Args` type.

Pin and test the specific local model against your `Tool` schemas before depending on it in
a tool-calling agent — don't assume every locally-served model honors typed tool arguments
the way a hosted frontier model does.

## Examples in the rig repository

`examples/rag_ollama` and `examples/vector_search_ollama` (repo root `examples/`, not
`rig-core/examples`) demonstrate ollama-backed RAG and vector search end to end.
