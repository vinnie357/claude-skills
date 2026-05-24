---
description: "Build the Claude Code OCI image from the plugin's mise-driven Dockerfile template and (optionally) push to a registry."
argument-hint: "[--registry=<registry>] [--tag=<tag>] [--push] [--load]"
---

Build the workload image that SandboxTemplates reference.

## Skills to load

- `/agent-sandboxing:claude-code-on-sandbox`
- `/core:mise`
- `/core:anti-fabrication`

## Steps

### 1. Resolve build context

The plugin ships:

- `templates/Dockerfile.claude-code` — mise-driven Dockerfile, non-root agent user, BuildKit cache mounts.
- `templates/mise.toml.claude-code` — pins `node = "lts"` + `claude-code = "latest"` via the mise registry short name. **Do not switch to `npm:@anthropic-ai/claude-code`** — the short name is the convention here.

Stage them into a build context:

```bash
BUILD_DIR=$(mktemp -d)
cp ${CLAUDE_PLUGIN_ROOT}/templates/Dockerfile.claude-code $BUILD_DIR/Dockerfile
cp ${CLAUDE_PLUGIN_ROOT}/templates/mise.toml.claude-code $BUILD_DIR/mise.toml
```

### 2. Build

Pick `--load` for local-only iteration, `--push` for registry publication. Default to `--load` if neither is specified.

```bash
REGISTRY=${REGISTRY:-ghcr.io/$USER}
TAG=${TAG:-$(date +%Y%m%d)}

docker buildx build \
  --tag ${REGISTRY}/claude-code:${TAG} \
  ${PUSH:+--push} ${LOAD:+--load} \
  --file $BUILD_DIR/Dockerfile \
  $BUILD_DIR
```

### 3. Verify

```bash
docker run --rm ${REGISTRY}/claude-code:${TAG} --version
```

Expected: a Claude Code version string (the image's CMD is `--print --output-format json`, so passing `--version` overrides it).

If the image returns no output or fails, inspect the Dockerfile — likely the mise install step couldn't reach the npm registry from inside the build, or the `node = "lts"` resolved to an unsupported version.

### 4. Update the SandboxTemplate

Once the image is built and pushed, edit the installed SandboxTemplate to use it:

```bash
kubectl set image sandboxtemplate/claude-code-kata claude=${REGISTRY}/claude-code:${TAG}
```

Or re-apply from the plugin template with placeholders substituted:

```bash
sed -e "s|REGISTRY/claude-code:TAG|${REGISTRY}/claude-code:${TAG}|" \
  ${CLAUDE_PLUGIN_ROOT}/templates/SandboxTemplate.kata.yaml | kubectl apply -f -
```

### 5. Clean up

```bash
rm -rf $BUILD_DIR
```

## Anti-fabrication

- Don't claim the image built without verifying the final `docker images` lists it (for `--load`) or the registry shows the tag (for `--push`).
- Don't claim the version verifies without running the container and observing the actual version string.
- If `docker buildx` isn't available, surface that and tell the user to install Docker Desktop or buildkit standalone; don't silently fall back to `docker build` (which won't honor the BuildKit cache mounts in the Dockerfile).
