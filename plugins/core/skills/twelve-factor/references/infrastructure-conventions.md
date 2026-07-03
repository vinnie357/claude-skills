# Infrastructure conventions

These rules extend `/core:twelve-factor` with operational defaults for deployments running on a Kubernetes + ingress + secrets-store stack.

## NGINX upstream (nginx.org), not the community ingress controller

For Kubernetes ingress, use the NGINX upstream's controller (`nginx.org/nginx-ingress`), not the community `kubernetes/ingress-nginx`. The two are different projects with different feature sets, annotation namespaces, and release cadences. Pick one and stay on it; do not mix annotations across them.

## Kustomize + Helm together for k8s

Use Helm for upstream chart consumption and Kustomize for environment overlays. The chart is the base; the overlay carries env-specific values. Only NON-SECRET values live in repo; secrets reference the secrets store (see below).

Layout:

```
deploy/
  base/                    # Helm chart values OR rendered manifests
    kustomization.yaml
  overlays/
    dev/
      kustomization.yaml
      values-dev.yaml
    prod/
      kustomization.yaml
      values-prod.yaml
```

## 1Password (or equivalent) as the universal secret source

A single secrets store backs every deployment target: dev, prod, CI. Pick one (1Password, Vault, AWS Secrets Manager) and use it everywhere. Do NOT split: "dev uses .env files, prod uses AWS, CI uses GitHub Actions secrets". The split multiplies surface area for drift and rotation lapses.

Verification command for any secret reference at deploy time: confirm the value is non-empty without revealing the value:

```bash
test -n "$(<secret-store-cli> read <ref>)" && echo "set" || echo "empty"
```

## Infrastructure as Code (IaC) for every service

Every deployment is described in code (Kustomize / Helm / Terraform / Pulumi / etc.). Manual UI changes against the deployment target are forbidden EXCEPT for emergency break-glass scenarios that get codified back into IaC within the same operator session.

Two user classes for IaC:
- **Administrators** maintain the IaC: write Helm charts, Kustomize overlays, secret references, IAM policies.
- **General users** author epics that describe WHAT they want; the IaC layer translates intent into resources. General users do not edit IaC directly.

Default to velocity for non-sensitive changes (config tweaks, image tag bumps); gate only secret rotation and data-destruction operations.

## Production services bind all interfaces

Services reachable over a network (overlay or otherwise) bind ALL interfaces in prod (`0.0.0.0` for IPv4, `::` for IPv6), NOT `127.0.0.1`. Loopback binds are dev-only.

For Phoenix endpoints specifically, the unconditional-at-top-level-of-runtime.exs pattern is documented in `/elixir:phoenix` (elixir plugin; reference resolves only when installed — the principle stands without it) "Runtime configuration" → "Phoenix Endpoint `:ip` bind config". Other frameworks have equivalent settings; the principle (bind all interfaces, env-driven, unconditional) generalizes.
