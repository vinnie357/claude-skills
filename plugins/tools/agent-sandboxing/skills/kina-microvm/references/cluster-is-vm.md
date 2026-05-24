# The cluster IS the microVM (kina model)

Why SandboxTemplates targeting kina look different from SandboxTemplates targeting Kata.

## Two isolation models

**Kata-on-Linux**: pod-level isolation. The k8s node is a Linux container (Docker, in the kind case); pods on that node share the node's kernel by default. Setting `runtimeClassName: kata-qemu` on a pod tells containerd to launch that pod inside its own microVM with its own kernel.

```
host Linux ─┬─ Docker container (kind node) ─┬─ runc pod (no isolation, shares node kernel)
            │                                 └─ kata pod (own microVM, own kernel) ← isolated
            └─ ...
```

**kina-on-macOS**: node-level isolation. Each k8s node is an Apple Container microVM. Pods on that node share the VM's kernel, but the VM itself is isolated from macOS via Virtualization.framework.

```
macOS ─┬─ Apple Container microVM (kina node) ─┬─ runc pod (shares VM kernel)
       │                                        └─ runc pod (shares VM kernel)
       └─ ...
```

Both give the operator "agent workloads are kernel-isolated from the host." The difference is granularity:

- Kata: pod-level. Pod A and Pod B on the same node have separate kernels.
- kina: node-level. Pod A and Pod B on the same kina node share a kernel; only the cluster as a whole is hardware-isolated from macOS.

## Implications for SandboxTemplate

**Omit `runtimeClassName`.** kina doesn't register a Kata-equivalent RuntimeClass, and adding `runtimeClassName: apple-container` (or similar) will fail because no such class exists. Just let the pod schedule with the node's default runtime (runc inside the microVM).

**Per-pod NetworkPolicy still works.** kina nodes run a standard kubelet + CNI (PTP by default, optional Cilium). `SandboxTemplate.networkPolicy` with `networkPolicyManagement: Managed` installs a standard NetworkPolicy that the CNI enforces — same as on any cluster.

**Tenancy decisions matter.** Because pods on a kina node share a kernel, multi-tenant separation between SandboxClaims requires pinning claims to separate nodes. The direct approach: one node per concurrent claim (run kina with multiple worker nodes). Without that, two claims for two different tenants on the same node share kernel state and can read each other via syscall-based escape if a kernel CVE is exploited.

## Sizing kina nodes

The microVM size determines pod-level resource limits transitively. Defaults are reasonable for one Claude Code session (~2 GB RAM, 2 CPU). For heavier workloads or multiple concurrent claims per node, configure kina with bigger VM specs — see `kina --help` for the per-node resource flags.

## Comparison with kata-on-kind

| Concern | kata-on-kind (Linux) | kina (macOS) |
|---|---|---|
| Isolation granularity | per pod | per node |
| RuntimeClass | `kata-qemu` | (none) |
| Hypervisor | QEMU + KVM | Virtualization.framework |
| Host requirement | Linux + nested virt | macOS 26+ |
| Tenant separation in template | inherent | requires node-pinning |
| Microvm boot time per pod | ~3–5s | (0 — node-warmed) |
| Cold-start for first SandboxClaim | seconds (kata start) | seconds (Pod schedule only) |

For laptop dev where the operator runs one Claude Code session at a time, kina's "share-the-VM-kernel-between-pods" tradeoff is acceptable — there is no cross-tenant attack surface to worry about. For production with mutually-distrusting tenants, pair with multi-node clusters or use `kata-on-gke`.
