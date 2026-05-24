# N2 Ubuntu node pool for Kata on GKE

Reference for the GCE-side configuration needed before kata-deploy + agent-sandbox.

## Machine type rationale

Kata's tested path on GKE is **N2 Intel** running Ubuntu. The full filter:

- **N2** family — Cascade Lake / Ice Lake. Supports nested virt.
- **Intel** — `vmx` flag. AMD's `svm` works for KVM but Kata's GKE recipe is Intel-tested.
- **Ubuntu** image (`UBUNTU_CONTAINERD`) — kata-deploy's GKE overlay targets Ubuntu. COS works in theory but the upstream example doesn't ship the COS overlay.

Recommended SKUs:

- Small dev: `n2-standard-2` (2 vCPU, 8 GB).
- Small prod: `n2-standard-4` (4 vCPU, 16 GB) — minimum if running a few concurrent SandboxClaims.
- Bigger: `n2-standard-8`+ when running a SandboxWarmPool with several replicas.

## Nested virtualization org policy

GCP organizations sometimes block nested virtualization via the org policy `constraints/compute.disableNestedVirtualization`. Check:

```bash
gcloud resource-manager org-policies describe \
  constraints/compute.disableNestedVirtualization \
  --organization=${ORG_ID}
```

If the constraint is enforced, ask the org policy admin to create a project-level exception:

```bash
gcloud resource-manager org-policies set-policy policy.yaml \
  --project=${PROJECT_ID}
```

Where `policy.yaml`:

```yaml
constraint: constraints/compute.disableNestedVirtualization
booleanPolicy:
  enforced: false
```

## Quota

Nested-virt-enabled VMs count against the standard `N2_CPUS` quota. Check:

```bash
gcloud compute project-info describe --project=${PROJECT_ID} \
  --format="value(quotas.metric, quotas.usage, quotas.limit)" \
  | grep N2_CPUS
```

If you're running 2 `n2-standard-4` nodes, that's 8 N2 CPUs. Request quota increase via the GCP console if your project sits at default (typically 24 per region).

## Image type

```bash
gcloud container node-pools create kata-pool \
  --image-type=UBUNTU_CONTAINERD \
  ...
```

`UBUNTU_CONTAINERD` runs containerd as the CRI, which is what kata-deploy targets. Do not use `UBUNTU` (deprecated, Docker shim) or `COS_CONTAINERD` (the upstream `setup.sh` doesn't ship a COS overlay).

## Node labels and taints

The upstream `kata-gke-sandbox` example labels the Kata pool so workloads can gate to it:

```bash
gcloud container node-pools update kata-pool \
  --cluster=${CLUSTER_NAME} --location=${LOCATION} \
  --node-labels="agent-sandbox.x-k8s.io/kata=true"
```

Then SandboxTemplates pin to it via `nodeSelector`:

```yaml
podTemplate:
  spec:
    runtimeClassName: kata-qemu
    nodeSelector:
      agent-sandbox.x-k8s.io/kata: "true"
```

Optionally taint the pool so only Kata workloads land there:

```bash
gcloud container node-pools update kata-pool \
  --cluster=${CLUSTER_NAME} --location=${LOCATION} \
  --node-taints="kata=true:NoSchedule"
```

With a corresponding toleration in the SandboxTemplate's podTemplate.

## Mixed pool option

If you don't want to dedicate a whole pool to Kata, run a mixed cluster: one Ubuntu-N2 pool for Kata workloads, one standard COS pool for everything else (system pods, gVisor workloads, ingress controllers). The SandboxTemplate's `nodeSelector` gates Kata pods to the right pool.

## Upgrading the kata-pool

GKE node-pool upgrades replace nodes. After an upgrade, kata-deploy's DaemonSet reinstalls Kata on the new nodes — but during the reinstall window, SandboxClaims targeting the upgraded pool are unschedulable until the new nodes report the `kata-qemu` RuntimeClass. Plan upgrades outside peak hours, or run a SandboxWarmPool that absorbs the gap.

## Tearing down

```bash
gcloud container node-pools delete kata-pool --cluster=${CLUSTER_NAME} --location=${LOCATION}
gcloud container clusters delete ${CLUSTER_NAME} --location=${LOCATION}
```

If the project has the nested-virt exception, leave the org policy in place for future Kata work — removing it doesn't save money.
