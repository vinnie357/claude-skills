# RAG and Embeddings

## `EmbeddingModel`

Rig's `embeddings::EmbeddingModel` trait is implemented per provider (for example
`gemini::EmbeddingModel`, backing `gemini::EMBEDDING_001` / `gemini::EMBEDDING_004`). Key
surface:

- `const MAX_DOCUMENTS: usize` — batching limit per request
- `fn ndims(&self) -> usize` — output vector dimensionality
- `async fn embed_texts(&self, documents) -> Result<Vec<Embedding>, EmbeddingError>` —
  batch-embeds a set of documents

Construct one from a client via `EmbeddingsClient`:

```rust
use rig_core::client::EmbeddingsClient;
use rig_core::providers::gemini;

let client = gemini::Client::from_env()?;
let embedder = client.embedding_model(gemini::EMBEDDING_001);
let vectors = embedder.embed_texts(vec!["some document text".to_string()]).await?;
```

`embedding_model_with_ndims(model, ndims)` overrides the default dimensionality for models
that support variable output size.

## Vector store companion crates

Rig ships vector store integrations as separate companion crates, not bundled into
`rig-core`: `rig-mongodb`, `rig-qdrant`, `rig-lancedb`, `rig-postgres`, `rig-neo4j`,
`rig-surrealdb`. Add the crate matching your vector database and implement or use its
`VectorStoreIndex` integration to back retrieval.

## `VectorStoreIndexDyn` — the one dyn-compatible pattern

Unlike `CompletionModel` (see `providers.md` — no dyn-compatible variant),
`vector_store::VectorStoreIndexDyn` is dyn-compatible and is exactly what `AgentBuilder`
uses internally to hold retrieval indexes:
`Arc<dyn VectorStoreIndexDyn + Send + Sync>`. Attach a vector store to an agent for
retrieval-augmented generation via `.dynamic_context()`:

```rust
let agent = client
    .agent(model_id)
    .dynamic_context(my_vector_store_index)
    .build();
```

`my_vector_store_index` must implement `VectorStoreIndexDyn + Send + Sync + 'static` — the
companion crates above provide this for their respective backends.

## Examples in the rig repository

`examples/rag` and `examples/rag_ollama` (repo root `examples/`) demonstrate a full RAG
pipeline; `examples/vector_search_ollama` demonstrates vector search backed by a local
ollama embedding model.
