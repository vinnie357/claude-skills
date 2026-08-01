# Sources

Citations for the `agent-sandboxing` plugin skills. Each entry lists the upstream source, what was extracted from it, and the date of last verification.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there. Entries: `kubernetes-sigs/agent-sandbox` (this section), `gke-agent-sandbox-docs` (the Google Cloud — GKE Agent Sandbox docs section), `kata-containers` (the Kata Containers section), `agent-substrate` (the agent-substrate/substrate section), `claude-code-devcontainer-docs` (the Claude Code section), `kina` (the kina section), `claude-code-devcontainer-reference` (the Anthropic devcontainer reference image section), `gcp-agent-sandbox-substrate-blog` (the Google Cloud blog section), `sandbox-index-skill` (the `sandbox` routing/index skill, which has no external upstream).

## kubernetes-sigs/agent-sandbox

- **URL**: https://github.com/kubernetes-sigs/agent-sandbox
- **Version verified against**: v0.4.6 (2026-05-14)
- **License**: Apache-2.0
- **Used in**: `k8s-agent-sandbox`, `kata-on-kind`, `kata-on-gke`, `kina-microvm`, `claude-code-on-sandbox`
- **Extracted**: CRD shapes (`Sandbox`, `SandboxTemplate`, `SandboxClaim`, `SandboxWarmPool`), install manifest URLs, `SandboxTemplateSpec.networkPolicy` + `networkPolicyManagement` semantics, the `examples/kata-gke-sandbox/` recipe.
- **Date accessed**: 2026-05-23

## Google Cloud — GKE Agent Sandbox docs

- **URLs**:
  - https://docs.cloud.google.com/kubernetes-engine/docs/concepts/machine-learning/agent-sandbox
  - https://docs.cloud.google.com/kubernetes-engine/docs/how-to/how-install-agent-sandbox
  - https://docs.cloud.google.com/kubernetes-engine/docs/how-to/agent-sandbox
  - https://docs.cloud.google.com/kubernetes-engine/docs/reference/crds/agentsandbox
  - https://docs.cloud.google.com/kubernetes-engine/docs/how-to/sandbox-pods
- **Used in**: `k8s-agent-sandbox`, `kata-on-gke`
- **Extracted**: managed GKE Agent Sandbox supports gVisor only (Kata is community-supported via the upstream `kata-gke-sandbox` example), GKE version `1.35.2-gke.1269000` minimum, `--enable-agent-sandbox` flag, `roles/serviceusage.serviceUsageAdmin`, Artifact Registry + GKE API enablement.
- **Date accessed**: 2026-05-23

## Kata Containers

- **URLs**:
  - https://github.com/kata-containers/kata-containers
  - https://github.com/kata-containers/kata-containers/blob/main/docs/install/README.md
  - https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/how-to-use-k8s-with-containerd-and-kata.md
  - https://github.com/kata-containers/kata-containers/tree/main/tools/packaging/kata-deploy
- **Used in**: `kata-on-kind`, `kata-on-gke`
- **Extracted**: kata-deploy DaemonSet behavior, RuntimeClass names (`kata-qemu`, `kata-clh`, `kata-fc`), node-label gating (`katacontainers.io/kata-runtime=true`), nested-virtualization requirement.
- **Date accessed**: 2026-05-23

## agent-substrate/substrate

- **URL**: https://github.com/agent-substrate/substrate
- **Version verified against**: v0.0.0 (2026-05-19) — alpha
- **License**: Apache-2.0
- **Used in**: `agent-substrate-overview`
- **Extracted**: maturity caveat ("VERY early development"), component list (`ateapi`, `atelet`, `atecontroller`, `atenet`, `kubectl-ate`), `WorkerPool` + `ActorTemplate` CRDs, kind + GKE install recipes, `demos/claude-code-multiplex/`. The worked `WorkerPool`/`ActorTemplate` YAML example (added claude-skills-142) is trimmed verbatim from `demos/claude-code-multiplex/claude-code-multiplex.yaml.tmpl` at the same commit.
- **Date accessed**: 2026-05-23 (YAML example re-verified 2026-08-01)

## Claude Code

- **URL**: https://code.claude.com/docs/en/devcontainer
- **Used in**: `claude-code-on-sandbox`
- **Extracted**: `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN` env vars, `~/.claude` named volume + `CLAUDE_CONFIG_DIR`, `--print --output-format json` headless mode, `--dangerously-skip-permissions` non-root requirement, `init-firewall.sh` egress allowlist pattern.
- **Date accessed**: 2026-05-23

## kina

- **URL**: https://github.com/vinnie357/kina (local: `~/github/kina`)
- **Status**: in active development; tracks Apple Container 0.5.0+ (latest container is 1.0.0 — major release with breaking CLI changes; version-drift caveat documented in `kina-microvm` skill)
- **Used in**: `kina-microvm`
- **Extracted**: Rust CLI commands (`kina create|delete|list|status`), cluster-as-microVM model (no per-pod `runtimeClassName`), mise tasks shape, dependency on Apple Container runtime.
- **Date accessed**: 2026-06-10

## Anthropic devcontainer reference image

- **URL**: https://github.com/anthropics/claude-code/tree/main/.devcontainer
- **Used in**: `claude-code-on-sandbox`, `templates/Dockerfile.claude-code`
- **Extracted**: Dockerfile structure, non-root user pattern (UID 1000), `~/.claude` named volume, `init-firewall.sh` NET_ADMIN/NET_RAW egress allowlist. The Dockerfile in this plugin's `templates/` is mise-driven rather than copying Anthropic's npm-driven setup, per [[feedback-mise-first]] + [[feedback-mise-registry-short-names]].
- **Date accessed**: 2026-05-23

## Google Cloud blog — Agent Sandbox + Agent Substrate

- **URL**: https://cloud.google.com/blog/products/containers-kubernetes/bringing-you-agent-sandbox-on-gke-and-agent-substrate
- **Date**: 2026-05-20
- **Used in**: `k8s-agent-sandbox`, `agent-substrate-overview`
- **Extracted**: GKE Agent Sandbox GA announcement, positioning of Substrate vs Sandbox ("ultra-scale control plane" vs "k8s-native GA tier"), the fact that they share runtime/snapshot primitives.
- **Date accessed**: 2026-05-23
