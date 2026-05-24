---
name: kata-on-kind
description: Install Kata Containers on a local kind cluster via the kata-deploy DaemonSet, registering the kata-qemu RuntimeClass so agent-sandbox SandboxTemplates can request microVM isolation. Use when standing up a Linux dev loop for microVM-isolated pods, verifying nested-KVM prerequisites, or pairing kind with kubernetes-sigs/agent-sandbox for local hacking.
license: MIT
---

# kata-on-kind

`kind` runs Kubernetes nodes as Docker containers. `kata-deploy` is a DaemonSet that installs the Kata Containers runtime + VM artifacts onto every node it lands on and reconfigures containerd to register the `kata-qemu`, `kata-clh`, and `kata-fc` RuntimeClasses. Combining the two on a Linux host gives microVM-isolated pods for local development.

## When to use

- Setting up a local microVM dev loop for `kubernetes-sigs/agent-sandbox` workloads.
- Verifying that `/dev/kvm` is exposed and nested virtualization works.
- Reproducing a GKE Standard + Kata production setup on a laptop before pushing to GKE.

## Host prerequisites — Linux only

Kata-on-kind requires the host to expose `/dev/kvm` to the kind node container. macOS hosts (Apple Silicon or Intel) cannot do this — Hypervisor.framework does not expose nested KVM to a guest Linux VM. For macOS, use `kina-microvm` (Apple Container nodes) instead.

Linux host checklist:

```bash
# Kernel supports KVM
ls /dev/kvm

# Current user can use KVM (or run kind under sudo)
groups | grep -E '\b(kvm|libvirt)\b'

# Nested virt enabled on the CPU (Intel)
cat /sys/module/kvm_intel/parameters/nested  # expect Y or 1
# or AMD
cat /sys/module/kvm_amd/parameters/nested

# QEMU available on host (kata-deploy copies its own qemu into the node, but
# host-side qemu helps with debugging)
qemu-system-x86_64 --version
```

If `/dev/kvm` is missing, install KVM:

```bash
sudo apt-get install -y qemu-kvm libvirt-clients libvirt-daemon-system
sudo usermod -aG kvm $USER
# log out and back in for the group to take effect
```

## Step 1 — create the kind cluster

```bash
cat <<'EOF' >kind-kata.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: /dev/kvm
        containerPath: /dev/kvm
        propagation: HostToContainer
EOF

kind create cluster --name kata --config kind-kata.yaml --image kindest/node:v1.31.0
kubectl cluster-info --context kind-kata
```

The `extraMounts` block passes `/dev/kvm` from the host into the kind node container. Without it, kata-deploy will install but pods will fail to start with `qemu` errors about KVM access.

## Step 2 — install kata-deploy

```bash
# Canonical manifest from the kata-containers repo
kubectl apply -k "github.com/kata-containers/kata-containers/tools/packaging/kata-deploy/kata-deploy/overlays/k3s"

# Or the base (works on most distros including kind):
kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-deploy/base/kata-deploy.yaml

# Wait for the DaemonSet to install Kata on every node
kubectl rollout status -n kube-system ds/kata-deploy --timeout=10m
```

kata-deploy mounts the host root and writes:

- `/opt/kata/` — Kata binaries, kernel, initrd, default config.
- `/etc/containerd/config.toml` — adds containerd runtime entries.
- Restarts containerd on the node.

Once the rollout completes, label-gates the node:

```bash
kubectl label node kata-control-plane katacontainers.io/kata-runtime=true --overwrite
```

## Step 3 — verify RuntimeClasses

```bash
kubectl get runtimeclass
# Expect: kata-qemu, kata-clh, kata-fc
```

If only `kata-qemu` is needed, the others can stay registered without cost.

## Step 4 — smoke test

```bash
kubectl run kata-test --image=busybox \
  --overrides='{"spec":{"runtimeClassName":"kata-qemu"}}' \
  -- sh -c "uname -a; sleep 5"

kubectl logs kata-test
# Expect: Linux <hostname> <kata-kernel-version> ...
# Kata kernel will differ from the kind node kernel — that proves microVM isolation.

kubectl delete pod kata-test
```

If the pod stays in `ContainerCreating` and `kubectl describe pod kata-test` shows `qemu: failed to access /dev/kvm`, the `extraMounts` step was missed.

## Step 5 — install agent-sandbox on top

```bash
VERSION=v0.4.6
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/manifest.yaml
kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/extensions.yaml

kubectl get crd | grep agents.x-k8s.io
```

Apply a SandboxTemplate that pins `runtimeClassName: kata-qemu` (see the `templates/SandboxTemplate.kata.yaml` template in this plugin). Then apply a `SandboxClaim` per the `k8s-agent-sandbox` skill.

## Three RuntimeClass variants

| RuntimeClass | Hypervisor | Use case |
|---|---|---|
| `kata-qemu` | QEMU/KVM | Default. Most compatible, slowest. |
| `kata-clh` | Cloud Hypervisor | Lighter than QEMU; faster boot. |
| `kata-fc` | Firecracker | Minimal attack surface. Skips some Kata features (no GPU, limited devices). |

For Claude Code-as-agent workloads, `kata-qemu` is the default. Switch to `kata-fc` for hardened production if the workload doesn't need the broader QEMU device support.

## Teardown

```bash
kind delete cluster --name kata
```

The cluster + containerd + Kata install are all inside the kind node container, so deleting the cluster removes everything.

## See also

- `references/verify-kvm.md` — fuller checklist for the host KVM prereqs.
- `k8s-agent-sandbox` — the controller-side install + CRD model.
- `claude-code-on-sandbox` — workload packaging.
- `kata-on-gke` — production GKE variant of the same pattern.
- Upstream: https://github.com/kata-containers/kata-containers

## Anti-fabrication

- Don't claim a pod is running in Kata without `kubectl exec` showing a kernel version that differs from the host's. Same kernel == not Kata.
- Don't paste these commands on macOS. They won't work; the user needs `kina-microvm`.
- The kata-deploy URL pattern occasionally moves between branches. Verify the link resolves before pasting in a script.
