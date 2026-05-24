---
name: k8s-agent-sandbox
description: Install and operate the kubernetes-sigs/agent-sandbox controller and CRDs for per-session, isolated AI agent pods on Kubernetes. Use when authoring SandboxTemplate / SandboxClaim manifests, configuring SandboxWarmPool for sub-second provisioning, applying default-deny NetworkPolicy, choosing between Kata Containers and gVisor as the RuntimeClass, or comparing managed GKE Agent Sandbox to the upstream open-source path.
license: MIT
---

# k8s-agent-sandbox

The upstream open-source project `kubernetes-sigs/agent-sandbox` ships four CRDs that model "give me a per-session, isolated pod for an AI agent and reap it when the session ends." This skill covers the controller, the CRD model, and the lifecycle. Pair with `kata-on-kind` / `kata-on-gke` / `kina-microvm` for the RuntimeClass install and with `claude-code-on-sandbox` for the workload-side packaging.

## When to use

- Standing up the agent-sandbox controller on a new cluster.
- Authoring a `SandboxTemplate` for an agent workload.
- Provisioning per-session sandboxes via `SandboxClaim` from a shell, CI job, or the Python SDK.
- Configuring `SandboxWarmPool` to get sub-second cold-starts.
- Locking down agent egress with `networkPolicyManagement: Managed`.
- Deciding between managed GKE Agent Sandbox (gVisor only) and self-installed upstream (Kata + gVisor + anything else).

## What it is

`kubernetes-sigs/agent-sandbox` is Apache-2.0 (verified at https://github.com/kubernetes-sigs/agent-sandbox). Latest release v0.4.6 (2026-05-14). API group `agents.x-k8s.io` (core `Sandbox`) and `extensions.agents.x-k8s.io` (templates, claims, warm pools). The upstream README example uses `v1alpha1`; `docs/api.md` documents `v1beta1`. Verify the installed CRD version before authoring manifests:

```bash
kubectl api-resources | grep -E 'agents\.x-k8s\.io'
```

GKE ships a managed variant ("Agent Sandbox") that became GA on 2026-05-20. The managed variant is **gVisor-only**; the upstream open-source project accepts any `runtimeClassName` including Kata. This skill targets the upstream because Kata (microVM isolation) is the primary use case here.

## Install

### Upstream (any conformant cluster: kind, k3s, kops, kubeadm, GKE Standard)

```bash
VERSION=v0.4.6
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/manifest.yaml
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/extensions.yaml
```

Two manifests because the project splits the core `Sandbox` CRD from the higher-level `SandboxTemplate` / `SandboxClaim` / `SandboxWarmPool` extensions. Apply both.

Verify the controller comes up:

```bash
kubectl get pods -n agent-sandbox-system
kubectl get crd | grep agents.x-k8s.io
```

### GKE managed (Autopilot)

```bash
gcloud beta container clusters create-auto ${CLUSTER_NAME} \
  --location=${LOCATION} \
  --cluster-version=${CLUSTER_VERSION} \
  --enable-agent-sandbox
```

GKE version `1.35.2-gke.1269000` or later. IAM: `roles/serviceusage.serviceUsageAdmin`. APIs to enable: Artifact Registry, GKE.

### GKE managed (Standard)

```bash
# Create cluster, then add a sandbox node pool, then enable the addon.
gcloud container clusters create ${CLUSTER_NAME} --location=${LOCATION} --cluster-version=${CLUSTER_VERSION}
gcloud container node-pools create sandbox-pool \
  --cluster=${CLUSTER_NAME} --location=${LOCATION} \
  --image-type=cos_containerd --sandbox=type=gvisor
gcloud beta container clusters update ${CLUSTER_NAME} --location=${LOCATION} --enable-agent-sandbox
```

The managed addon installs the same CRDs but pins `runtimeClassName: gvisor`. For Kata on GKE, use the upstream install instead and follow `kata-on-gke`.

## The four CRDs

See `references/crds.md` for full field reference. One-paragraph summary of each:

- **`Sandbox`** (`agents.x-k8s.io`) — the actual workload. A single stateful pod with a stable network identity.
- **`SandboxTemplate`** (`extensions.agents.x-k8s.io`) — a reusable PodSpec for sandboxes. `podTemplate.spec.runtimeClassName` picks the isolation tier.
- **`SandboxClaim`** (`extensions.agents.x-k8s.io`) — a per-session request that references a `SandboxTemplate` and optionally a `SandboxWarmPool`. Carries `lifecycle.shutdownPolicy: Delete` so the sandbox auto-reaps.
- **`SandboxWarmPool`** (`extensions.agents.x-k8s.io`) — N pre-warmed pods sitting idle so that a `SandboxClaim` resolves in sub-second instead of normal Pod scheduling time.

## Mental model

The plugin's templates assume this flow:

1. Cluster admin: install the controller once.
2. Cluster admin: install a `SandboxTemplate` per agent workload (e.g. one for `claude-code-kata`, one for `python-runtime`).
3. Optional: install a `SandboxWarmPool` per template if cold-start latency matters.
4. Caller (operator, CI job, Python SDK) applies a `SandboxClaim` per session.
5. Controller binds the claim to a warm pod (or schedules a new one) and exposes a stable endpoint via the Sandbox Router.
6. When the session ends, `kubectl delete` on the claim (or `shutdownPolicy: Delete` with a `shutdownTime`) tears down the pod.

See `references/lifecycle.md` for the claim/warm-pool semantics.

## Per-session lifecycle (simplest path)

Apply a `SandboxClaim` from a shell or CI step:

```yaml
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxClaim
metadata:
  name: session-${SESSION_ID}
spec:
  sandboxTemplateRef:
    name: claude-code-kata
  lifecycle:
    shutdownPolicy: Delete
  env:
    - name: ANTHROPIC_API_KEY
      valueFrom:
        secretKeyRef:
          name: anthropic
          key: api-key
```

`spec.env` injects per-claim env vars into the pod — keep `ANTHROPIC_API_KEY` out of the template so the template stays generic across callers.

For the Python SDK alternative (`k8s-agent-sandbox` / `agentic-sandbox-client`), see `references/python-sdk.md`.

## Networking (default-deny + Anthropic egress)

`SandboxTemplateSpec` has first-class `networkPolicy` (NetworkPolicySpec) and `networkPolicyManagement` (`Managed` / `Unmanaged`) fields. With `Managed`, the controller materializes a NetworkPolicy from the template.

Default-deny + DNS + outbound HTTPS to Anthropic:

```yaml
spec:
  networkPolicyManagement: Managed
  networkPolicy:
    egress:
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: kube-system
        ports:
          - protocol: UDP
            port: 53
      - to:
          - ipBlock:
              cidr: 0.0.0.0/0  # narrow to resolved api.anthropic.com CIDRs in prod
        ports:
          - protocol: TCP
            port: 443
```

The `0.0.0.0/0:443` block is a placeholder for development. In production, resolve `api.anthropic.com` and narrow to Anthropic's egress ranges. See `references/network-policy.md` for the resolution recipe and for layering Claude Code's own `init-firewall.sh` on top (defense in depth).

## Choosing a RuntimeClass

| RuntimeClass | Isolation | Where it runs | Skill |
|---|---|---|---|
| `kata-qemu` | Hardware microVM (KVM) | Linux hosts only — kind on Linux, GKE Standard with N2 Ubuntu | `kata-on-kind`, `kata-on-gke` |
| `gvisor` | Userspace kernel | Anywhere — Apple Silicon kind, GKE managed Agent Sandbox | `claude-code-on-sandbox` (gVisor template) |
| _(omit)_ | Cluster-level (each node IS a microVM) | macOS via `kina` (Apple Container nodes) | `kina-microvm` |

The kina case is structurally different: there is no per-pod `RuntimeClass` swap because the cluster itself sits inside Apple Container microVMs. Omit `runtimeClassName` in the SandboxTemplate. See `kina-microvm` for why.

## Verify

After install + template + claim:

```bash
kubectl get sandboxes -A
kubectl get sandboxclaims -A
kubectl describe sandboxclaim session-${SESSION_ID}
kubectl exec -it sandbox/session-${SESSION_ID} -- /bin/sh
```

If the claim sticks in Pending, check the controller logs:

```bash
kubectl logs -n agent-sandbox-system deploy/agent-sandbox-controller -f
```

## API version drift caveat

The upstream README shows `agents.x-k8s.io/v1alpha1` examples; `docs/api.md` documents `v1beta1`. Pin templates to whatever the installed manifest defines. Run `kubectl api-resources | grep agents` after install and use the listed version verbatim. Don't paste templates from this skill without that check.

## See also

- `kata-on-kind` — install Kata Containers on a local Linux kind cluster.
- `kata-on-gke` — install Kata on a self-managed GKE node pool.
- `kina-microvm` — macOS path where the cluster itself is the microVM tier.
- `claude-code-on-sandbox` — build the Claude Code OCI image and deploy as a `SandboxTemplate`.
- `agent-substrate-overview` — alpha alternative control plane sharing the same primitives.
- Upstream: https://github.com/kubernetes-sigs/agent-sandbox
- GKE managed docs: https://docs.cloud.google.com/kubernetes-engine/docs/concepts/machine-learning/agent-sandbox

## Anti-fabrication

Verify before claiming:

- Always run `kubectl api-resources | grep agents` and `kubectl get crd | grep agents.x-k8s.io` before pasting CRD manifests; the API version (`v1alpha1` vs `v1beta1`) differs between upstream README examples and the docs.
- Don't claim a `SandboxWarmPool` is satisfying claims without `kubectl describe sandboxwarmpool` showing `Ready` replicas.
- Don't claim GKE managed Agent Sandbox supports Kata; the docs confirm gVisor only.
- Don't claim a sandbox has Anthropic egress without exec'ing into the pod and curl'ing `https://api.anthropic.com/v1/models` (or equivalent).
