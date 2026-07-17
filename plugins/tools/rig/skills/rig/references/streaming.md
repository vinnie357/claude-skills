# Streaming

## Streaming completions

`CompletionModel::stream()` returns a `StreamingResponse` stream rather than a single
completion:

```rust
pub trait CompletionModel: Clone + WasmCompatSend + WasmCompatSync {
    // ...
    fn stream(
        &self,
        request: CompletionRequest,
    ) -> impl std::future::Future<
        Output = Result<StreamingCompletionResponse<Self::StreamingResponse>, CompletionError>,
    > + WasmCompatSend;
}
```

Token usage arrives as the final item in the stream rather than a separate call — read the
stream to completion to obtain the full usage total, not just the assistant text.

```rust
let mut stream = model.stream(request).await?;
while let Some(chunk) = stream.next().await {
    // chunk carries incremental assistant content; the final chunk carries usage
}
```

## Examples in the rig repository

Streaming: `examples/agent_stream_chat`, `examples/openai_streaming_per_call_usage`. Provider
recovery behavior: `examples/gemini_default_api_recovery`. A full agentic loop:
`examples/complex_agentic_loop_claude`. All under the repo root `examples/` directory (not
`rig-core/examples`).
