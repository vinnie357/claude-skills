---
name: kina-microvm
description: Run microVM-isolated Kubernetes workloads on Apple Silicon using kina, the Kubernetes-in-Apple-Containers analogue of kind. Use when developing kubernetes-sigs/agent-sandbox workloads on macOS where Kata Containers cannot run, when each k8s node must be an Apple Container microVM, or when applying SandboxTemplates without a per-pod runtimeClassName because the cluster itself is the microVM isolation tier.
license: MIT
---

# kina-microvm

`kina` is to Apple Container what `kind` is to Docker: a CLI that creates local Kubernetes clusters where each node is a microVM. On macOS Apple Silicon, Kata Containers cannot run (no nested KVM via Hypervisor.framework), so kina + Apple Container fills the role Kata plays on Linux.

The structural difference matters: with kata-on-kind, isolation lives at the **pod** level via `runtimeClassName: kata-qemu` on a Linux container node. With kina, isolation lives at the **node** level — every node IS already an Apple Container microVM, so every pod on the cluster is already inside a microVM. There is no per-pod `runtimeClassName` swap.

## When to use

- Developing `kubernetes-sigs/agent-sandbox` workloads on a Mac (Apple Silicon or Intel).
- Wanting microVM isolation locally without requiring a Linux host.
- Needing parity between local dev and a future Linux+Kata or GKE deployment.

## Why not kata-on-kind on macOS

Apple Silicon's Hypervisor.framework does not expose nested KVM to guest Linux VMs. Docker Desktop and Colima both run a Linux VM under the hood; that VM cannot itself host KVM-accelerated Kata microVMs. Symptom if you try: `qemu-system-x86_64: failed to access /dev/kvm`.

Apple Container is the macOS-native analogue: a microVM runtime that uses Virtualization.framework instead of KVM. It's not compatible with the Kata RuntimeClass spec, but it can serve as the microVM substrate for k8s nodes — which is what kina does.

## kina ↔ kind ↔ kata

| | Substrate | Isolation tier |
|---|---|---|
| `kind` (Linux/macOS) | Docker container per node | None per pod (vanilla containerd) |
| `kind` + `kata-deploy` (Linux only) | Docker container per node | microVM per pod via `kata-qemu` |
| `kina` (macOS) | Apple Container microVM per node | Node IS the microVM; pods share that VM's kernel |

The kina model gives macOS developers microVM isolation at a different granularity. For agent-sandbox, the cluster is hardware-isolated from the host macOS — the security posture matches kata-on-kind, with the isolation boundary placed at the node layer instead of the pod layer.

See `references/cluster-is-vm.md` for the implications when authoring SandboxTemplates.

## Prerequisites

- macOS 26+ (Apple Silicon or Intel). kina's README documents limitations on macOS 15.6 — verify by running `kina` against the older version before depending on it.
- Apple Container 0.5.0+. **Currently kina is pinned at 0.5.0+ while Apple Container is at 0.10.0** — verify compatibility before depending on it (see "Version drift" below).
- `kubectl` on the host.
- `mise` if you want kina's task automation.

Install Apple Container:

```bash
# Download the .pkg from https://github.com/apple/container/releases
# Install, then start the API server:
container system start
container --version
```

## Version drift (kina ↔ apple-container)

kina's README says it requires "Apple Container 0.5.0+" and "automatically detects and validates" the installed version. Apple Container has moved to 0.10.0. **Before depending on kina in any plugin workflow, verify it actually runs against the installed `container` version.**

```bash
container --version
# Compare to kina's expected range.
kina --help 2>&1 | head -5
# kina validates Apple Container at startup; a mismatch will fail loudly here.
```

If kina errors with an unsupported-version message:

1. Check the kina repo for a newer release that handles the latest Apple Container.
2. If none exists, file an issue (or PR) at https://github.com/vinnie357/kina asking for compatibility with Apple Container 0.x.
3. Pin to a known-good Apple Container version in your local dev setup (`brew tap apple/container@<version>` if Apple ships that, otherwise install the matching `.pkg` from the GitHub releases page).

Do NOT proceed with the rest of this skill until `kina --help` and `kina create` work end-to-end. The plugin must not claim a working macOS path on an untested version pair.

## Install kina

```bash
git clone https://github.com/vinnie357/kina.git
cd kina

# With mise (recommended for this marketplace per /core:mise):
mise run kina:install

# Or directly:
cargo install --path kina-cli
```

Verify:

```bash
kina
# Prints kina version + detected Apple Container version
```

## Step 1 — create a cluster

```bash
kina create agent-sandbox
kina export agent-sandbox --format kubeconfig --output ~/.kube/agent-sandbox
export KUBECONFIG=~/.kube/agent-sandbox
kubectl get nodes
```

Each node listed is an Apple Container microVM. The kubelet, kube-proxy, and containerd all run inside that VM.

For an ingress-equipped cluster:

```bash
kina create agent-sandbox --cni cilium --wait 300
kina install nginx-ingress --cluster agent-sandbox
```

## Step 2 — install agent-sandbox

```bash
VERSION=v0.4.6
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/manifest.yaml
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/extensions.yaml

kubectl get crd | grep agents.x-k8s.io
```

## Step 3 — apply a SandboxTemplate without runtimeClassName

Because the cluster is already inside Apple Container microVMs, the SandboxTemplate omits `runtimeClassName`. Use the plugin's `templates/SandboxTemplate.kina.yaml`:

```yaml
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxTemplate
metadata:
  name: claude-code-kina
spec:
  networkPolicyManagement: Managed
  networkPolicy:
    egress:
      - to: [ { namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: kube-system } } } ]
        ports: [ { protocol: UDP, port: 53 } ]
      - to: [ { ipBlock: { cidr: 0.0.0.0/0 } } ]
        ports: [ { protocol: TCP, port: 443 } ]
  podTemplate:
    spec:
      # No runtimeClassName — the node is already the microVM tier.
      securityContext: { runAsNonRoot: true, runAsUser: 1000 }
      automountServiceAccountToken: false
      containers:
        - name: claude
          image: REGISTRY/claude-code:TAG
          env:
            - name: ANTHROPIC_API_KEY
              valueFrom: { secretKeyRef: { name: anthropic, key: api-key } }
```

Apply a `SandboxClaim` per the `k8s-agent-sandbox` skill. The pod schedules inside the Apple Container microVM node; the workload is isolated from macOS by Virtualization.framework, not Kata.

## Verify isolation

```bash
kubectl exec -it sandbox/session-${SESSION_ID} -- uname -a
# Reports the Apple Container microVM's Linux kernel, NOT macOS.
```

This is the proof the workload is isolated. If `uname -a` reports a Darwin kernel, you're not actually in a microVM — investigate kina's cluster setup.

## Teardown

```bash
kina delete agent-sandbox
container system stop  # optional
```

## See also

- `references/cluster-is-vm.md` — implications for SandboxTemplate authoring.
- `core:container` — Apple Container CLI fundamentals (start the runtime, manage VMs, build images on macOS).
- `k8s-agent-sandbox` — the controller-side install + CRD model.
- `kata-on-kind` — the Linux equivalent of this skill (microVM via Kata, pod-level RuntimeClass).
- `claude-code-on-sandbox` — workload packaging that targets all three substrates.
- Upstream: https://github.com/vinnie357/kina

## Anti-fabrication

- Don't claim kina works against the currently installed Apple Container until `kina --help` succeeds. Version drift is the most likely failure mode — verify first.
- Don't claim Apple Container microVMs provide the same isolation guarantees as Kata. The mechanism differs (Virtualization.framework vs KVM); the security posture is comparable for typical AI agent workloads but not identical.
- Don't add `runtimeClassName: apple-container` to a SandboxTemplate. There is no such RuntimeClass — Apple Container isn't wire-compatible with k8s RuntimeClass.
- Don't paste this skill's commands on Linux. Use `kata-on-kind` instead.
