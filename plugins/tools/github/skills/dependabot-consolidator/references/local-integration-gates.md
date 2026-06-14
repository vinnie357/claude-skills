# Local Integration Gates

Gates that cannot run inside GitHub CI but are still required for verifying dependency bumps.

## Why local gates exist

GitHub CI runners are ephemeral Linux containers. Certain validation steps require:

- **Hardware/hypervisor access**: Apple Container (macOS-only, requires Apple Silicon), Kata Containers (kernel isolation), microVM spawning
- **Long-running cluster state**: Kubernetes cluster provisioning takes minutes and is not cached between CI runs
- **Operator-local services**: test doubles or mocks running on the operator's LAN

These gates are not "optional" — they are the primary correctness signal for repos that use these technologies. They simply cannot run in hosted CI.

## Baseline-diff discipline still applies

Local gates follow the same rule as remote CI gates: run on `main` first, then on the consolidated branch, classify only `PASS → FAIL` as blocking.

```
main:    local-cluster-spawn → FAIL  (XPC not running in the operator's session)
branch:  local-cluster-spawn → FAIL  (same reason)
→ pre-existing; not a regression from the bump
```

```
main:    local-cluster-spawn → PASS
branch:  local-cluster-spawn → FAIL  (a new kube-rs API was removed in the bumped crate)
→ blocking regression; stop and report
```

## Apple Container gates (kina example)

For repos using Apple Container for cluster operations:

1. Ensure Apple Container daemon is running: `container system info`
2. Run the local test suite that spawns a cluster:
   ```bash
   cargo test --test cluster_tests -- --nocapture 2>&1 | tee /tmp/gate-branch-cluster.txt
   ```
3. Compare output to the main baseline captured in `/tmp/gate-main-cluster.txt`

See `/core:container` for Apple Container lifecycle patterns (start, stop, inspect, cleanup).

## Mise task integration

Repos with a `mise.toml` may expose local-integration gates as tasks:

```bash
mise run test:cluster
mise run test:integration
```

Run `mise tasks` to discover available tasks. Prefer `mise run <task>` over raw script invocation for consistency.

## Reporting local gate results

Include in the PR description and in any consolidation report:

```
## Local integration gates (baseline-diff)

| Gate                  | main    | branch  | Classification  |
|-----------------------|---------|---------|-----------------|
| mise run test:cluster | FAIL    | FAIL    | pre-existing    |
| mise run test:unit    | PASS    | PASS    | not a regression |
```

Paste the captured output files as evidence. Do not summarize without the raw output.
