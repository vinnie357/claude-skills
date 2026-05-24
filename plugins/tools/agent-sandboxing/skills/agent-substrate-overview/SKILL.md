---
name: agent-substrate-overview
description: Reference for the alpha agent-substrate/substrate project as an alternative ultra-scale control plane that shares snapshot and runtime primitives with kubernetes-sigs/agent-sandbox. Use when comparing agent-sandbox vs Substrate, evaluating the WorkerPool + ActorTemplate multiplexing model, reviewing the kubectl-ate CLI, or deciding which control plane fits a workload that needs millions of sub-second agent tool calls.
license: MIT
---

# agent-substrate-overview

Agent Substrate is an Apache-2.0 Kubernetes runtime for agent-like workloads that multiplexes many stateful actors onto fewer worker pods, preserving in-memory + disk state via gVisor checkpoint/restore. It is **explicitly alpha** (v0.0.0, README quote: "VERY early development… APIs are almost guaranteed to change"). This skill is a short reference so you can evaluate it against `k8s-agent-sandbox`, not an operational guide.

## When to use this skill

- Comparing Substrate's control plane to `kubernetes-sigs/agent-sandbox` before choosing one.
- Reading a Substrate `ActorTemplate` / `WorkerPool` YAML and wanting to know the field semantics.
- Looking at the `demos/claude-code-multiplex/` example to understand Substrate's Claude Code integration shape.

If the operational decision is already "use Substrate," read the upstream README directly — this skill is intentionally not a step-by-step install guide because Substrate's APIs change too fast to pin a reliable recipe.

## What Substrate is

From the upstream README: "Agent substrate is a system built on top of Kubernetes which manages agent-like workloads to achieve higher scale and efficiency than Kubernetes alone can offer, with lower latency."

Architectural diff vs `kubernetes-sigs/agent-sandbox`:

| | `agent-sandbox` (kubernetes-sigs) | `agent-substrate` |
|---|---|---|
| Maturity | v0.4.6 (released) | v0.0.0 (alpha) |
| Control plane | k8s controller + CRDs only | k8s controller + dedicated gRPC `ateapi` |
| Workload model | One sandbox per claim | Many actors multiplexed onto fewer pods |
| Suspend/resume | Pod snapshots (GKE feature) | gVisor `runsc checkpoint/restore` first-class |
| CLI | `kubectl` + Python SDK | `kubectl-ate` plugin |
| Use case | per-session ephemeral agents | high-density actor swarms |

Per Google's 2026-05-20 blog: "Substrate is the open-source ultra-scale tier sharing Sandbox's core secure runtime and snapshotting capabilities with a minimal control plane designed to bypass some of the limitations of Kubernetes for millions of sub-second tool calls."

## Components

- `ateapi` — gRPC control plane.
- `atelet` — node-level DaemonSet supervising workers and snapshots.
- `atecontroller` — k8s controller reconciling Substrate CRDs.
- `atenet` — networking controller: DNS, Envoy routing, proxy sidecars.
- `ateom-gvisor` — interior helper running `runsc checkpoint/restore`.
- `podcertcontroller` — Pod Certificate signer polyfill.
- `kubectl-ate` — operator CLI plugin.

External deps: gVisor, Valkey (Redis-compatible), RustFS.

## CRDs

- `WorkerPool` — N pods that will host actors. Configures pod sizing and oversubscription.
- `ActorTemplate` — describes a workload container image + boot/snapshot config; many actors instantiate from one template.

`SessionIdentity` (not a CRD; a service exposed by `ateapi`) exchanges ephemeral kubelet credentials for stable JWT/cert identities that persist across worker migrations.

## Claude Code on Substrate

Substrate's `demos/claude-code-multiplex/` ships a working example:

- A `WorkerPool` of 2 pods is oversubscribed by 3 `ActorTemplate`s (`luna`, `mars`, `orion`).
- Each agent is a container built from `workload/` (Dockerfile + Python wrapper around Claude Code) and referenced by `sha256` digest in `claude-code-multiplex.yaml.tmpl`.
- A Go dashboard in `ui/` calls the `ateapi` gRPC + Kubernetes API.

Substrate is **not** an MCP server — it's a workload host. Claude Code packaged as an OCI container is just another actor.

## Install summary (do not paste verbatim — read upstream first)

The upstream uses shell scripts under `hack/`, not Helm or Kustomize. Examples:

- Kind: `hack/create-kind-cluster.sh`, `hack/install-ate-kind.sh --deploy-ate-system`
- GKE: `go run ./tools/setup-gcp --all`, `hack/install-ate.sh --deploy-ate-system`

The exact scripts change frequently in alpha. Read the README at https://github.com/agent-substrate/substrate before running any of them.

## Which to pick

- **Use `kubernetes-sigs/agent-sandbox`** for: per-session Claude Code pods on a laptop or GKE; production workloads now; integration with the broader k8s ecosystem (NetworkPolicy, StorageClass, etc.).
- **Use `agent-substrate`** for: ultra-high-density actor workloads where standard k8s scheduling is the bottleneck; experimentation with checkpoint/restore migration; research environments where alpha APIs are acceptable.

For this plugin's Claude Code-on-sandbox use case (one operator, one session at a time, microVM isolation): **stick with `k8s-agent-sandbox`**. Substrate's multiplexing is overkill and its alpha status means upgrade churn.

## See also

- `k8s-agent-sandbox` — the primary path this plugin recommends.
- Upstream Substrate: https://github.com/agent-substrate/substrate
- 2026-05-20 GCP blog: https://cloud.google.com/blog/products/containers-kubernetes/bringing-you-agent-sandbox-on-gke-and-agent-substrate

## Anti-fabrication

- Substrate is at v0.0.0; do not claim it is production-ready.
- The `kubectl-ate` plugin and `ateapi` are different things from agent-sandbox's `kubectl` + Python SDK — do not paste agent-sandbox CRDs into a Substrate cluster or vice versa.
- The "shares snapshot primitives" relationship is documented in Google's blog post; the actual code-level overlap is not enumerated upstream. Don't claim deeper code-level equivalence than that.
- Substrate's install scripts change frequently. Read the current README before invoking them.
