# Providers

Rig provides built-in client modules under `rig_core::providers::{anthropic, openai, gemini,
ollama, azure, cohere, deepseek, groq, xai, perplexity, openrouter, together, huggingface,
mistral, ...}`. AWS Bedrock is not one of them — it ships as the separate `rig-bedrock`
companion crate, not a `rig_core::providers` module. This reference covers the four most
common in a hybrid Rust harness — Anthropic, OpenAI, Gemini, and ollama — plus the pattern
for wiring them together.

## `ProviderClient` and `from_env()`

Every provider client implements `from_env()`, which reads credentials and an optional base
URL from environment variables and returns a ready client:

| Provider | Required env var | Optional base-URL env var |
|---|---|---|
| Anthropic | `ANTHROPIC_API_KEY` | `ANTHROPIC_BASE_URL` |
| OpenAI | `OPENAI_API_KEY` | `OPENAI_BASE_URL` |
| Gemini | `GEMINI_API_KEY` | none |
| Ollama | none (default `http://localhost:11434`) | `OLLAMA_API_BASE_URL` (+ optional `OLLAMA_API_KEY`) |

```rust
use rig_core::prelude::*;
use rig_core::providers::{anthropic, openai, gemini};

let claude = anthropic::Client::from_env()?;
let gpt = openai::Client::from_env()?;
let gemini_client = gemini::Client::from_env()?;
```

Gemini has no base-URL environment variable — `from_env()` reads `GEMINI_API_KEY` only.

## Model IDs: constants vs raw strings

`.agent(model)` and `.completion_model(model)` take `impl Into<String>`, so a raw string
model ID always works. The `anthropic::completion` module ships constants for the current
Claude line:

```rust
use rig_core::providers::anthropic::completion::{
    CLAUDE_OPUS_4_8, CLAUDE_OPUS_4_7, CLAUDE_OPUS_4_6, CLAUDE_SONNET_4_6, CLAUDE_HAIKU_4_5,
};
```

No `CLAUDE_3_*` constants exist in the current crate — the module tracks the current model
line only. `rig_core::providers::gemini::completion` ships its own set (10 total): stable tiers
`GEMINI_2_5_FLASH`, `GEMINI_2_0_FLASH`, `GEMINI_2_0_FLASH_LITE`, dated 2.5-pro/flash preview
constants, and the newest `GEMINI_3_1_FLASH_LITE_PREVIEW` / `GEMINI_3_FLASH_PREVIEW`
(preview-only for the 3.x line); `GEMINI_2_5_FLASH_IMAGE` is gated behind the `image`
feature. Preview constants track the SDK's release cadence more closely than stable ones —
the durable pattern for production code is an env-var-supplied raw string across every
provider, with constants as a convenience default:

```rust
let model_id = std::env::var("ANTHROPIC_MODEL")
    .unwrap_or_else(|_| CLAUDE_SONNET_4_6.to_string());
let agent = claude.agent(model_id).build();
```

## Anthropic API version

The Anthropic client ships `ANTHROPIC_VERSION_LATEST = "2023-06-01"` as the default
`anthropic-version` header value, overridable via `ClientBuilder::anthropic_version()`.

## Custom base URL — the shared integration point

`ClientBuilder` exposes `.base_url()` across providers, independent of the `from_env()`
default:

```rust
let client = openai::Client::builder()
    .api_key(&api_key)
    .base_url("http://localhost:1234/v1")
    .build()?;
```

This one pattern — plus its `OPENAI_BASE_URL` env-var form — is the integration path for
every OpenAI-wire-compatible target: LM Studio, LiteLLM, and Bifrost gateways. See
`local-and-gateways.md` for the full walkthrough.

## Worked example — hybrid multi-provider harness

Rig has no built-in multi-tier harness type; this pattern combines rig's client and
`AgentBuilder` primitives into a small harness struct owned by the application. It is
original guidance, not a rig-shipped recipe.

`CompletionModel` is `Clone`-bound (`pub trait CompletionModel: Clone + WasmCompatSend +
WasmCompatSync`) with no dyn-compatible variant — there is no `Box<dyn CompletionModel>` and
no `CompletionModelDyn` type. A harness holding agents backed by different concrete provider
types cannot store them in one homogeneous collection of trait objects. Route with enum
dispatch instead — the rig repository ships an `enum_dispatch` example demonstrating this
exact shape:

`openai::Client` (the type `.agent()` gets by default) is the Responses API client, backed by
`openai::responses_api::ResponsesCompletionModel`, not `openai::completion::CompletionModel`.
The example below uses `openai::CompletionsClient` instead — the Chat Completions client —
because it is backed by `openai::completion::CompletionModel`, giving the smallest, most
readable enum variant type; either client works for a review tier.

```rust
use rig_core::prelude::*;
use rig_core::agent::Agent;
use rig_core::providers::{anthropic, ollama, openai};

enum Tier {
    Fast(Agent<ollama::CompletionModel>),
    Main(Agent<anthropic::completion::CompletionModel>),
    Review(Agent<openai::completion::CompletionModel>),
}

impl Tier {
    async fn prompt(&self, text: &str) -> Result<String, rig_core::completion::PromptError> {
        match self {
            Tier::Fast(agent) => agent.prompt(text).await,
            Tier::Main(agent) => agent.prompt(text).await,
            Tier::Review(agent) => agent.prompt(text).await,
        }
    }
}

struct Harness {
    fast: Tier,
    main: Tier,
    review: Tier,
}

async fn build_harness() -> Result<Harness, Box<dyn std::error::Error>> {
    let fast_model = std::env::var("AGENT_FAST_MODEL").unwrap_or_else(|_| "llama3.1:8b-instruct-q4_0".into());
    let main_model = std::env::var("AGENT_MAIN_MODEL")
        .unwrap_or_else(|_| anthropic::completion::CLAUDE_SONNET_4_6.to_string());
    let review_model = std::env::var("AGENT_REVIEW_MODEL").unwrap_or_else(|_| "gpt-5.2".into());

    let ollama_client = ollama::Client::from_env()?;
    let anthropic_client = anthropic::Client::from_env()?;
    let openai_client = openai::CompletionsClient::from_env()?;

    Ok(Harness {
        fast: Tier::Fast(ollama_client.agent(fast_model).build()),
        main: Tier::Main(anthropic_client.agent(main_model).build()),
        review: Tier::Review(openai_client.agent(review_model).build()),
    })
}
```

Alternatives to enum dispatch for the same constraint: a generic function bounded by
`M: CompletionModel` when the caller already knows which concrete tier it needs, or plain
concrete fields on the harness struct (as shown above) when the tier set is fixed at compile
time. Choose enum dispatch when call sites need to select a tier dynamically at runtime.

`VectorStoreIndexDyn` exists for vector stores and does support dynamic dispatch — the
dyn-object pattern is available for vector stores today, not for `CompletionModel`.
