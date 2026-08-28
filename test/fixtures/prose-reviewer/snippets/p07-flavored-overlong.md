# ADR context: single-writer queue

We chose a single-writer queue instead of one writer per shard because the
shard boundaries shift under rebalancing, and pinning a writer to a shard
that later moves would silently orphan its queue while a new shard spun up
with no writer at all, a failure mode we only discovered after tracing a
production stall back to an unowned partition.
