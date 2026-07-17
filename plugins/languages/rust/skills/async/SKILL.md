---
name: async
description: Guide for async and concurrent Rust programming. Use when writing async functions, using tokio, spawning threads, working with channels, or sharing state with Arc/Mutex.
---

# Rust Async and Concurrency

Async functions, tokio runtime, streams, threads, channels, and shared state.

## When to Use This Skill

Activate when:
- Writing async functions with tokio
- Running concurrent async operations with join! or spawn
- Processing async streams
- Spawning OS threads
- Using channels (mpsc) for message passing
- Sharing state with Arc and Mutex

For async patterns, concurrency primitives, and shared state examples, see `references/async.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Every claim about async/await behavior, the
tokio runtime, and std concurrency primitives is verified against the Async Book and tokio
documentation cited in `sources.md` — not inferred from generic familiarity with the
ecosystem. Before asserting a tokio API or concurrency behavior this skill and its
references do not cover, check the installed crate version's docs.rs page rather than
guessing.
