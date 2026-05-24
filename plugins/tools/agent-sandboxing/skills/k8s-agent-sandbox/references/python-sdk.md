# Python SDK: agentic-sandbox-client / k8s-agent-sandbox

The upstream project ships a Python client (`agentic-sandbox-client` on PyPI; importable as `k8s_agent_sandbox`) that wraps the CRD lifecycle. Useful when the laptop-side caller is Python rather than shell.

## Install

```bash
pip install k8s-agent-sandbox
# or
mise exec python -- pip install k8s-agent-sandbox
```

The SDK reads kubeconfig from `$KUBECONFIG` / `~/.kube/config` by default.

## Provision a sandbox

```python
from k8s_agent_sandbox import SandboxClient
from k8s_agent_sandbox.models import SandboxLocalTunnelConnectionConfig

client = SandboxClient(connection_config=SandboxLocalTunnelConnectionConfig())

sandbox = client.create_sandbox(
    template="claude-code-kata",
    namespace="default",
    env={"ANTHROPIC_API_KEY": os.environ["ANTHROPIC_API_KEY"]},
)

# sandbox is the Bound claim with a stable endpoint
print(sandbox.endpoint)
```

The SDK creates a `SandboxClaim`, waits for `phase: Bound`, and returns a handle.

## Run a command

```python
result = sandbox.commands.run("echo 'hello'", timeout=30)
print(result.stdout)
```

## Release

```python
sandbox.delete()
```

`shutdownPolicy: Delete` on the underlying claim means the pod tears down.

## When to use the SDK vs shell

- **Shell / kubectl**: simplest, no Python dependency, fits CI scripts and `mise run` tasks. Use this when the orchestrator is the operator at a terminal or a shell-based CI job.
- **Python SDK**: when the orchestrator is already a Python application (a LangChain agent, a Vertex AI Agentic SDK loop, a custom Python harness). Avoids shelling out to `kubectl` and gives typed responses.

## Local tunnel connection config

`SandboxLocalTunnelConnectionConfig` proxies sandbox traffic over a kubectl port-forward — useful when the sandbox's network isn't directly reachable from the laptop. The SDK manages the tunnel lifecycle.

## Caveat

The SDK targets the same CRD API version as the controller. If the controller is `v1alpha1` and the SDK expects `v1beta1` (or vice versa), claims fail with deserialization errors. Pin the SDK version to match the controller release.
