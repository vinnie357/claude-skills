---
description: "Bootstrap a sandboxing-capable Kubernetes cluster: pick substrate (kata-on-kind, kata-on-gke, kina-microvm), install kubernetes-sigs/agent-sandbox controller, install the first SandboxTemplate."
argument-hint: "[--substrate=kind-kata|gke-kata|kina] [--template=kata|gvisor|kina] [--registry=<registry>] [--tag=<tag>]"
---

Bring up a Kubernetes cluster ready to host Claude Code workloads in microVM-isolated pods.

## Skills to load (explicit, no globs)

- `/agent-sandboxing:k8s-agent-sandbox`
- `/agent-sandboxing:kata-on-kind`
- `/agent-sandboxing:kata-on-gke`
- `/agent-sandboxing:kina-microvm`
- `/agent-sandboxing:claude-code-on-sandbox`
- `/core:nushell`
- `/core:mise`
- `/core:anti-fabrication`

## Steps

### 1. Pick the substrate

If `--substrate=<value>` is not in arguments, ask the user which path:

- `kind-kata` — Linux host with `/dev/kvm`; local microVM dev loop via kind + kata-deploy. See `/agent-sandboxing:kata-on-kind`.
- `gke-kata` — GKE Standard with Ubuntu N2 nodes + nested virt + upstream `examples/kata-gke-sandbox/setup.sh`. See `/agent-sandboxing:kata-on-gke`.
- `kina` — macOS Apple Silicon via kina (Kubernetes-in-Apple-Containers). See `/agent-sandboxing:kina-microvm`.

Detect the host's OS via `uname -s`. Steer the user away from kind-kata on macOS (won't work without nested KVM) and toward kina instead.

### 2. Verify prerequisites

For the chosen substrate, run the skill's prerequisites checklist verbatim. **Do not skip this.** If a prereq fails, stop and report; the user fixes it before continuing.

- `kind-kata` → `references/verify-kvm.md` checks (`ls /dev/kvm`, KVM group, nested-virt CPU flags).
- `gke-kata` → confirm `gcloud auth`, project, nested-virt org policy, N2 quota.
- `kina` → `container --version` and `kina --help` both succeed; verify Apple Container version drift caveat documented in the skill.

### 3. Create the cluster

Follow the relevant skill's "Step 1" commands verbatim. Examples:

- `kind-kata`: render and apply the `kind-kata.yaml` cluster config with `/dev/kvm` `extraMounts`, then `kind create cluster ...`.
- `gke-kata`: `gcloud container clusters create` + `node-pools create --enable-nested-virtualization`.
- `kina`: `kina create agent-sandbox && kina export ... && export KUBECONFIG=...`.

### 4. Install the agent-sandbox controller

```bash
VERSION=v0.4.6
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/manifest.yaml
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/extensions.yaml
kubectl wait --for=condition=Available deploy/agent-sandbox-controller -n agent-sandbox-system --timeout=5m
```

Verify with:

```bash
kubectl get crd | grep agents.x-k8s.io
kubectl api-resources | grep agents
```

**Pin templates to whatever API version the controller registers** (the upstream README shows `v1alpha1`; `docs/api.md` documents `v1beta1`). If the installed version differs from the plugin's template defaults, point it out.

### 5. Install RuntimeClass (kind-kata and gke-kata only)

- `kind-kata`: `kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-deploy/base/kata-deploy.yaml`, then label the node and wait for the DaemonSet rollout.
- `gke-kata`: `git clone https://github.com/kubernetes-sigs/agent-sandbox.git && cd agent-sandbox/examples/kata-gke-sandbox && ./setup.sh`.
- `kina`: skip — the cluster IS the microVM tier.

Verify the RuntimeClass:

```bash
kubectl get runtimeclass
```

Expected: `kata-qemu` for kata paths; nothing for kina.

### 6. Install the SandboxTemplate

Pick the template matching the substrate:

- `kind-kata` / `gke-kata` → `templates/SandboxTemplate.kata.yaml`
- `kina` → `templates/SandboxTemplate.kina.yaml`
- gVisor-only clusters (e.g. GKE managed Agent Sandbox) → `templates/SandboxTemplate.gvisor.yaml`

Override the placeholder image:

```bash
TEMPLATE=${CLAUDE_PLUGIN_ROOT}/templates/SandboxTemplate.kata.yaml
REGISTRY=${REGISTRY:-ghcr.io/$USER}
TAG=${TAG:-latest}
sed -e "s|REGISTRY/claude-code:TAG|${REGISTRY}/claude-code:${TAG}|" $TEMPLATE | kubectl apply -f -
```

If `--registry` / `--tag` were not passed and no image is built yet, tell the user to run `/agent-sandboxing:build-image` first.

### 7. Create the Anthropic secret

```bash
kubectl create secret generic anthropic --from-literal=api-key=${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY env var required}
```

### 8. Verify end-to-end

```bash
kubectl get sandboxtemplate
kubectl get crd | grep agents.x-k8s.io
```

Report back to the user: substrate, RuntimeClass, controller version, SandboxTemplate name. Tell them the next command is `/agent-sandboxing:provision` to create their first session.

## Anti-fabrication

- Don't report success on a step without observing the corresponding `kubectl get` or `kubectl wait` output.
- Don't claim a node is microVM-isolated without `kubectl exec ... uname -a` confirming a kernel that differs from the host.
- If any verification step fails, stop and report — don't proceed past a failed gate.
