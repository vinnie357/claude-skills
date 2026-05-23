---
name: kata-on-gke
description: Install Kata Containers on a self-managed GKE node pool to run microVM-isolated agent workloads via kubernetes-sigs/agent-sandbox. Use when managed GKE Agent Sandbox (gVisor-only) is not enough, when running Claude Code or similar agents on GKE with hardware-level isolation, or when configuring N2 Intel Ubuntu nodes with nested virtualization for the upstream kata-gke-sandbox recipe.
license: MIT
---

# kata-on-gke

GKE ships a managed "Agent Sandbox" add-on, but it pins `runtimeClassName: gvisor`. There is no managed Kata path. For microVM isolation on GKE, follow the upstream `examples/kata-gke-sandbox/` recipe: a standard (non-Autopilot) GKE cluster, an Ubuntu N2 node pool with nested virtualization, and a `setup.sh` that installs Kata onto those nodes.

## When to use

- Running agent workloads on GKE with hardware-level isolation, not userspace-kernel (gVisor) isolation.
- Reproducing a `kata-on-kind` dev setup in a real GKE cluster.
- Pairing GKE with `kubernetes-sigs/agent-sandbox` upstream (not the managed addon) so SandboxTemplates can pin `runtimeClassName: kata-qemu`.

## Prerequisites

- GCP project with billing enabled.
- APIs enabled: Compute Engine, Kubernetes Engine, Artifact Registry.
- IAM on the operator: `roles/container.admin`, `roles/compute.instanceAdmin.v1`, `roles/serviceusage.serviceUsageAdmin`.
- **Nested virtualization org policy** allowed for the project. The constraint to disable is `constraints/compute.disableNestedVirtualization`.

Verify the constraint is not enforced:

```bash
gcloud resource-manager org-policies describe \
  constraints/compute.disableNestedVirtualization \
  --project=${PROJECT_ID}
# If returns "booleanPolicy.enforced: true", request the policy admin to unset it.
```

## Machine type constraints

Kata on GKE requires **N2 Intel** machines (e.g. `n2-standard-4`). The upstream recipe lists hard exclusions:

- ❌ `e2-*` — no nested virt.
- ❌ `n2d-*` (AMD) — Kata's tested path is Intel.
- ❌ `t2a-*` (ARM) — no nested virt.
- ❌ Autopilot clusters — no control over machine type / image.

Use N2 (Cascade Lake / Ice Lake Intel) Ubuntu nodes only.

## Step 1 — create the cluster (Standard, Ubuntu node pool)

```bash
PROJECT_ID=...
LOCATION=us-central1
CLUSTER_NAME=kata-sandbox-cluster

gcloud container clusters create ${CLUSTER_NAME} \
  --project=${PROJECT_ID} \
  --location=${LOCATION} \
  --num-nodes=0 \
  --cluster-version=latest \
  --release-channel=regular

gcloud container node-pools create kata-pool \
  --project=${PROJECT_ID} \
  --location=${LOCATION} \
  --cluster=${CLUSTER_NAME} \
  --machine-type=n2-standard-4 \
  --image-type=UBUNTU_CONTAINERD \
  --enable-nested-virtualization \
  --num-nodes=2
```

`--enable-nested-virtualization` is the critical flag — without it, the underlying GCE instances boot without `/dev/kvm` and kata-deploy will install but pods will fail to start.

Verify nested virt on a node:

```bash
gcloud compute ssh gke-${CLUSTER_NAME}-kata-pool-... --command "ls /dev/kvm && egrep -c '(vmx|svm)' /proc/cpuinfo"
```

Expect `/dev/kvm` listed and a count > 0.

## Step 2 — kubeconfig

```bash
gcloud container clusters get-credentials ${CLUSTER_NAME} \
  --location=${LOCATION} --project=${PROJECT_ID}
```

## Step 3 — clone the upstream kata-gke-sandbox example

```bash
git clone https://github.com/kubernetes-sigs/agent-sandbox.git
cd agent-sandbox/examples/kata-gke-sandbox
```

The directory ships:

- `README.md` — operator-facing notes.
- `setup.sh` — installs Kata onto the Ubuntu nodes via a kata-deploy variant tuned for GKE.
- `sandbox-kata-gke.yaml` — example Sandbox pinning `runtimeClassName: kata-qemu`.

Read `setup.sh` before running it; it edits node-level config via a DaemonSet.

## Step 4 — run the upstream setup

```bash
./setup.sh
```

What it does (read the script for current details):

- Applies a kata-deploy DaemonSet that targets the Ubuntu pool (`cloud.google.com/gke-os-distribution: ubuntu`).
- Waits for the rollout to complete.
- Verifies the `kata-qemu` RuntimeClass is registered.

```bash
kubectl get runtimeclass
# Expect kata-qemu (and possibly kata-clh, kata-fc)
```

## Step 5 — install agent-sandbox

```bash
VERSION=v0.4.6
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/manifest.yaml
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/extensions.yaml

kubectl get crd | grep agents.x-k8s.io
```

Apply the plugin's `templates/SandboxTemplate.kata.yaml` (drop the `cloud.google.com/gke-os-distribution: ubuntu` node selector from upstream's example only if you have a single mixed node pool — usually leave it in to gate to the Kata-enabled pool).

## Step 6 — smoke test

Apply the upstream's `sandbox-kata-gke.yaml` first to validate Kata works end-to-end:

```bash
kubectl apply -f sandbox-kata-gke.yaml
kubectl wait --for=condition=Ready sandbox/kata-example --timeout=5m
kubectl exec -it sandbox/kata-example -- uname -a
# The kernel reported here differs from the GKE node's kernel.
kubectl delete -f sandbox-kata-gke.yaml
```

Then move to a `SandboxTemplate` + `SandboxClaim` pattern per the `k8s-agent-sandbox` skill.

## Why not Autopilot?

GKE Autopilot doesn't expose node-pool configuration, so you can't add `--enable-nested-virtualization` or pick a specific machine type. Autopilot users are stuck with the managed gVisor Agent Sandbox. If Kata is a hard requirement, use Standard.

## Cost notes

N2 Intel nodes with nested virt enabled are billed at standard GCE rates. There's no surcharge for nested virt itself, but Kata workloads can consume more memory than equivalent runc pods (each microVM has its own kernel + initramfs). Size node memory accordingly.

## See also

- `references/n2-ubuntu-pool.md` — fuller config walkthrough including the org-policy exception and quota considerations.
- `k8s-agent-sandbox` — CRDs + lifecycle.
- `kata-on-kind` — local Linux dev loop with the same RuntimeClass.
- Upstream: https://github.com/kubernetes-sigs/agent-sandbox/tree/main/examples/kata-gke-sandbox
- GKE managed Agent Sandbox (gVisor only): https://docs.cloud.google.com/kubernetes-engine/docs/how-to/how-install-agent-sandbox

## Anti-fabrication

- Don't claim a node has nested virt enabled without `gcloud compute ssh ... ls /dev/kvm`. The `--enable-nested-virtualization` flag silently no-ops on machine types that don't support it.
- Don't use `e2-*`, `n2d-*`, or `t2a-*` machine types. Kata won't work and the failure mode is delayed (pods fail at start, not at apply).
- Don't claim GKE Autopilot supports Kata. The managed Agent Sandbox is gVisor-only; Kata requires Standard + Ubuntu nodes + the upstream recipe.
- The upstream `setup.sh` evolves; always read it before running and pin to a specific commit if you depend on it in CI.
