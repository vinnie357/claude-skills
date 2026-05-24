# Claude Code authentication in sandboxed pods

Two auth modes and the k8s-native secret patterns for each.

## Mode 1: `ANTHROPIC_API_KEY`

Direct Anthropic API key. Simplest, no OAuth dance, no per-user state.

```bash
kubectl create secret generic anthropic \
  --from-literal=api-key=sk-ant-...
```

Reference from a `SandboxClaim`:

```yaml
spec:
  env:
    - name: ANTHROPIC_API_KEY
      valueFrom:
        secretKeyRef:
          name: anthropic
          key: api-key
```

`spec.env` on the claim is per-session; the controller appends it to every container in the template. Keep the env injection on the claim (not the template) so the template stays generic — useful when one template serves multiple tenants, each with its own API key secret.

For per-tenant secrets:

```bash
kubectl create secret generic anthropic-tenant-a --from-literal=api-key=sk-ant-...
kubectl create secret generic anthropic-tenant-b --from-literal=api-key=sk-ant-...
```

Then the claim picks the right one based on context.

## Mode 2: `CLAUDE_CODE_OAUTH_TOKEN`

OAuth token from `claude setup-token`. Ties usage to a specific Anthropic Console account.

Generate the token on a host with TUI access (typically the operator's laptop):

```bash
# Outside the sandbox, on a workstation:
claude setup-token
# Follow the OAuth flow in the browser.
# Output: paste the token into a k8s secret.
```

Then:

```bash
kubectl create secret generic claude-oauth \
  --from-literal=token=...
```

```yaml
spec:
  env:
    - name: CLAUDE_CODE_OAUTH_TOKEN
      valueFrom:
        secretKeyRef:
          name: claude-oauth
          key: token
```

## Which to choose

| Concern | `ANTHROPIC_API_KEY` | `CLAUDE_CODE_OAUTH_TOKEN` |
|---|---|---|
| Setup | One env var | OAuth flow per operator |
| Billing/usage attribution | At project level (Anthropic Console) | Per-user (operator's account) |
| Rotation | Rotate the key | Rotate via `claude setup-token` again |
| Multi-tenant | One key per tenant in separate secrets | One token per operator; harder to scope |
| Headless CI | ✓ Native | ✗ Requires browser for setup |

For CI / autonomous loops / programmatic use → `ANTHROPIC_API_KEY`.
For interactive operator-driven sandboxes → either works; OAuth keeps usage tied to a human.

## Secret rotation

`ANTHROPIC_API_KEY`:

```bash
# Generate a new key in Anthropic Console.
# Patch the secret:
kubectl create secret generic anthropic \
  --from-literal=api-key=sk-ant-NEW \
  --dry-run=client -o yaml | kubectl apply -f -
# In-flight SandboxClaims keep using the old key (env is injected at pod start).
# Delete the claims to force new pods to pick up the new key.
```

`CLAUDE_CODE_OAUTH_TOKEN`:

```bash
claude setup-token  # re-run, paste new token
kubectl create secret generic claude-oauth \
  --from-literal=token=NEW --dry-run=client -o yaml | kubectl apply -f -
```

## SecretProviderClass (CSI Secret Store) — production pattern

For production, drop the literal secret in favor of a `SecretProviderClass` that pulls from an external secret manager (Vault, AWS Secrets Manager, GCP Secret Manager). The SandboxTemplate's `volumeMounts` + `containers.env.valueFrom.secretKeyRef` pattern stays the same; only the secret source changes.

Example (GCP Secret Manager):

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: anthropic-gcp
spec:
  provider: gke
  parameters:
    secrets: |
      - resourceName: "projects/${PROJECT_ID}/secrets/anthropic-api-key/versions/latest"
        path: "api-key"
```

Mount into the pod and the Anthropic key arrives as a file at `/mnt/secrets/api-key`. Either:

- Set `ANTHROPIC_API_KEY=$(cat /mnt/secrets/api-key)` in an entrypoint script, or
- Use `SecretProviderClass`'s `secretObjects` to sync to a k8s Secret which the env then references.

CSI Secret Store config is outside this skill's scope; see your cloud provider's docs.

## Don't bake keys into the image

Never paste an API key or OAuth token into the Dockerfile or the image filesystem. Every layer survives forever (in the registry, in build caches); rotation becomes impossible. Always inject at runtime via `spec.env` or volume-mounted secret.
