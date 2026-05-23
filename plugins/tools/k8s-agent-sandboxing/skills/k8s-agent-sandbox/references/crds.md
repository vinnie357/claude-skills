# agent-sandbox CRD reference

Field reference for the four CRDs shipped by `kubernetes-sigs/agent-sandbox`. Authoritative source: `docs/api.md` in the upstream repo. API group versions noted per-CRD.

## API groups

- `agents.x-k8s.io` — core `Sandbox` CRD.
- `extensions.agents.x-k8s.io` — `SandboxTemplate`, `SandboxClaim`, `SandboxWarmPool`.

Upstream README example YAML uses `v1alpha1`; `docs/api.md` documents `v1beta1`. Run `kubectl api-resources | grep agents` after install and use whichever version the controller registers.

## `Sandbox`

The actual workload pod. Single replica, stateful, stable network identity.

```yaml
apiVersion: agents.x-k8s.io/v1alpha1
kind: Sandbox
metadata:
  name: example
spec:
  podTemplate:
    spec:
      # any standard PodSpec — runtimeClassName, containers, volumes, etc.
      runtimeClassName: kata-qemu
      containers:
        - name: agent
          image: ...
```

Key fields:

- `spec.podTemplate.spec.runtimeClassName` — the isolation tier. `kata-qemu` for microVM, `gvisor` for userspace kernel, omitted for node-level isolation (kina).
- `spec.podTemplate.spec.securityContext` — non-root recommended.
- `status.endpoint` — stable URL exposed via the Sandbox Router once the pod is Ready.

## `SandboxTemplate`

A reusable PodSpec that `SandboxClaim`s reference by name. Templates live in a namespace; claims from any namespace can reference templates in the same namespace.

```yaml
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxTemplate
metadata:
  name: claude-code-kata
spec:
  networkPolicyManagement: Managed
  networkPolicy:
    egress: [ ... ]
  podTemplate:
    spec:
      runtimeClassName: kata-qemu
      containers: [ ... ]
```

Key fields:

- `spec.podTemplate` — the PodSpec template (full PodSpec; not a wrapper).
- `spec.networkPolicy` — embedded `NetworkPolicySpec`. Controller materializes this when `networkPolicyManagement: Managed`.
- `spec.networkPolicyManagement` — `Managed` (default) installs the policy; `Unmanaged` leaves it to the cluster operator.
- `spec.lifecycle.defaultShutdownPolicy` — fallback for claims that don't set their own.

Templates that pin `runtimeClassName: kata-qemu` require the cluster to have the `kata-qemu` RuntimeClass registered (see `kata-on-kind` / `kata-on-gke`).

## `SandboxClaim`

A per-session request. Most callers only ever touch this CRD.

```yaml
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxClaim
metadata:
  name: session-abc123
spec:
  sandboxTemplateRef:
    name: claude-code-kata
  lifecycle:
    shutdownPolicy: Delete
    shutdownTime: "2026-05-23T18:00:00Z"   # optional RFC3339
  env:
    - name: ANTHROPIC_API_KEY
      valueFrom:
        secretKeyRef:
          name: anthropic
          key: api-key
```

Key fields:

- `spec.sandboxTemplateRef.name` — the template to instantiate.
- `spec.lifecycle.shutdownPolicy` — `Delete` reaps the pod; `Retain` leaves it for inspection.
- `spec.lifecycle.shutdownTime` — RFC3339 timestamp; controller deletes at that time.
- `spec.env` — per-claim env injection; appended to the template's containers.
- `spec.warmPoolRef.name` — optional; if set and the pool has a ready replica, the claim binds in sub-second.

Status carries `endpoint`, `phase` (`Pending`, `Bound`, `Terminating`), and `conditions`.

## `SandboxWarmPool`

Pre-warmed replicas for a template.

```yaml
apiVersion: extensions.agents.x-k8s.io/v1alpha1
kind: SandboxWarmPool
metadata:
  name: claude-code-kata-pool
spec:
  sandboxTemplateRef:
    name: claude-code-kata
  replicas: 3
```

Key fields:

- `spec.sandboxTemplateRef.name` — which template to pre-warm.
- `spec.replicas` — desired idle replicas.

`status.readyReplicas` reports how many are bindable. A claim with `warmPoolRef` set will pop from the pool; one without will schedule fresh.

## Cross-CRD invariants

- A `SandboxClaim` referencing a `SandboxTemplate` that pins an unavailable `runtimeClassName` will stick in `Pending` with a condition explaining the missing RuntimeClass.
- A `SandboxWarmPool` whose template changes (image tag, env) will roll the pool — short window of unavailability.
- Deleting a `SandboxTemplate` while claims exist is rejected; delete claims first.
