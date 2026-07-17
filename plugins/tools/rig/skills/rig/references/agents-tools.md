# Agents, Tools, Extractors, and MCP

## AgentBuilder surface

`client.agent(model)` returns an `AgentBuilder<M>`. Configuration methods (chainable, all
return `Self`):

- `.name(&str)`, `.description(&str)` — identity, used when the agent is exposed as a tool
- `.preamble(&str)`, `.without_preamble()`, `.append_preamble(&str)` — system prompt
- `.context(&str)`, `.dynamic_context(...)` — additional context injected per call
- `.tool_choice(ToolChoice)`, `.default_max_turns(usize)`
- `.temperature(f64)`, `.max_tokens(u64)`, `.additional_params(serde_json::Value)`
- `.output_schema::<T>()`, `.output_schema_raw(Schema)`, `.output_mode(OutputMode)`
- `.memory(...)`, `.conversation(impl Into<String>)`, `.add_hook(...)`
- `.tool(tool)` — register a statically typed `Tool` implementation
- `.dynamic_tool(...)`, `.dynamic_tools(...)` — register runtime-defined tools
- `.build()` — produces `Agent<M>`

```rust
let agent = client
    .agent(model_id)
    .preamble("You are a research assistant.")
    .temperature(0.2)
    .tool(MyTool)
    .build();

let answer = agent.prompt("Summarize the attached report.").await?;
```

An `Agent<M>` can itself become a tool for another agent via `.into_tool()` — the agent's
`name`/`description`/`preamble` become the sub-agent tool's definition, enabling nested
agent-as-tool composition without a separate wrapper type.

## The `Tool` trait

```rust
pub trait Tool: Sized + WasmCompatSend + WasmCompatSync {
    const NAME: &'static str;
    type Args: for<'de> Deserialize<'de> + WasmCompatSend + WasmCompatSync;
    type Output: IntoToolOutput;
    type Error: std::error::Error + WasmCompatSend + WasmCompatSync + 'static;

    fn description(&self) -> String;
    fn parameters(&self) -> serde_json::Value;

    fn map_error(&self, error: Self::Error) -> ToolExecutionError {
        ToolExecutionError::from_error(error)
    }

    fn call(
        &self,
        context: &mut ToolContext,
        args: Self::Args,
    ) -> impl Future<Output = Result<Self::Output, Self::Error>> + WasmCompatSend;
}
```

There is no `definition()` method on the trait — metadata is two sync methods,
`description()` and `parameters()` (a JSON Schema value), and Rig assembles the model-facing
`ToolDefinition` from them internally. `call()` takes `&mut ToolContext` as its first
argument, ahead of the typed `Args`; `ToolContext` carries both inbound runtime context and
host-only result metadata via `context.insert_result(...)`, for data a caller inspects after
the call without exposing it in the model-visible `Output`. `Output` must implement
`IntoToolOutput`, which every owned serializable value implements automatically — an ordinary
`#[derive(Serialize)]` struct needs no extra work. `map_error` is a default-provided method
normalizing a typed `Self::Error` into `ToolExecutionError`; override it only when the domain
error should report a more specific `ToolErrorKind` or a structured message back to the
model.

```rust
use rig_core::tool::{Tool, ToolContext};
use serde::{Deserialize, Serialize};
use std::convert::Infallible;

#[derive(Deserialize)]
struct AddArgs { left: i64, right: i64 }

#[derive(Serialize)]
struct Sum { value: i64 }

struct Add;

impl Tool for Add {
    const NAME: &'static str = "add";
    type Args = AddArgs;
    type Output = Sum;
    type Error = Infallible;

    fn description(&self) -> String {
        "Add two integers".into()
    }

    fn parameters(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "left": { "type": "integer" },
                "right": { "type": "integer" }
            },
            "required": ["left", "right"]
        })
    }

    async fn call(
        &self,
        _context: &mut ToolContext,
        args: Self::Args,
    ) -> Result<Self::Output, Self::Error> {
        Ok(Sum { value: args.left + args.right })
    }
}
```

Register a `Tool` implementation with `.tool(MyTool)` on `AgentBuilder`. `Args` is
deserialized from the model's tool-call arguments; `Output` is converted into rig's canonical
model-facing presentation via `IntoToolOutput`. See `local-and-gateways.md` for a gotcha
specific to small local models violating this typed `Args` contract.

## Extractors — structured output without a full agent loop

```rust
#[derive(serde::Deserialize, serde::Serialize, schemars::JsonSchema)]
struct Summary {
    headline: String,
    key_points: Vec<String>,
}

let extractor = client.extractor::<Summary>(model_id).build();
let summary: Summary = extractor.extract(raw_text).await?;
```

`T` must implement `JsonSchema + Deserialize + Serialize + Send + Sync`. `ExtractorBuilder`
exposes `.retries(u64)` to bound retry attempts on a failed extraction; `Extractor` exposes:

- `.extract(text)` — single-shot extraction
- `.extract_with_chat_history(...)` — extraction with prior conversation context
- `.extract_with_usage(...)` — extraction plus accumulated token usage across retries
- `.extract_with_chat_history_with_usage(...)` — both combined

## MCP tools via `rmcp`

Enable the `rmcp` Cargo feature to register Model Context Protocol tools on an
`AgentBuilder`. MCP support landed in rig 0.16.0 (2025-07-30):

```toml
rig-core = { version = "0.40", features = ["rmcp"] }
```

```rust
let agent = client
    .agent(model_id)
    .rmcp_tool(mcp_tool_definition, mcp_client_sink)
    .build();
```

Methods available:

- `.rmcp_tool(tool, client_sink)` — register a single MCP tool with the default timeout
  (`DEFAULT_MCP_TOOL_TIMEOUT`)
- `.rmcp_tool_with_timeout(tool, client_sink, timeout)` — same, with an explicit per-call
  timeout
- `.rmcp_tools(tools, client_sink)` / `.rmcp_tools_with_timeout(tools, client_sink, timeout)`
  — batch registration variants

The singular `.rmcp_tool()` / `.rmcp_tool_with_timeout()` are only on the pre-tool
`AgentBuilder` state (before any tool has been registered). Once `.tool()` or an `rmcp`
method has moved the builder into its post-tool state, only the plural batch variants,
`.rmcp_tools()` / `.rmcp_tools_with_timeout()`, remain available — register single MCP tools
before any other tool call, or pass a one-element `Vec` to a plural method afterward.

The `examples/rmcp` example in the rig repository demonstrates a full MCP client
integration.
