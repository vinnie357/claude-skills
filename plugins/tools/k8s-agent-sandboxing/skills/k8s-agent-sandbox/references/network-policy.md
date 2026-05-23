# NetworkPolicy patterns for agent sandboxes

Default-deny egress + a narrow allowlist is the recommended posture. `SandboxTemplateSpec.networkPolicy` + `networkPolicyManagement: Managed` lets the controller install the policy from the template instead of relying on a side-channel manifest.

## Default-deny baseline

Egress to nothing, ingress from nothing:

```yaml
spec:
  networkPolicyManagement: Managed
  networkPolicy:
    podSelector: {}
    policyTypes: [Ingress, Egress]
    egress: []
    ingress: []
```

Use this as the starting point. Then add the minimum allowances the agent actually needs.

## DNS + Anthropic API

Agent needs DNS (kube-system) and outbound HTTPS to Anthropic:

```yaml
spec:
  networkPolicyManagement: Managed
  networkPolicy:
    policyTypes: [Egress]
    egress:
      # DNS to CoreDNS
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: kube-system
        ports:
          - protocol: UDP
            port: 53
          - protocol: TCP
            port: 53
      # HTTPS to Anthropic
      - to:
          - ipBlock:
              cidr: 0.0.0.0/0  # placeholder — narrow in prod
        ports:
          - protocol: TCP
            port: 443
```

## Narrowing `0.0.0.0/0:443` to Anthropic ranges

`api.anthropic.com` resolves to a small set of CIDRs (typically behind Cloudflare or AWS). The plugin does NOT bake CIDRs into templates because they change. Recipe to resolve at install time:

```bash
dig +short api.anthropic.com | sort -u
```

Then encode the returned IPs as `/32` blocks in the NetworkPolicy:

```yaml
egress:
  - to:
      - ipBlock: { cidr: 203.0.113.10/32 }
      - ipBlock: { cidr: 203.0.113.11/32 }
    ports: [{ protocol: TCP, port: 443 }]
```

Re-resolve and re-apply when Anthropic publishes a new range. Schedule a cron job inside the cluster (or a CI step) to refresh the policy weekly.

## Defense in depth: Claude Code's `init-firewall.sh`

The Anthropic reference devcontainer ships `init-firewall.sh` which uses `iptables` inside the pod (NET_ADMIN/NET_RAW caps) to allow only Anthropic egress. Layering this on top of the Kubernetes NetworkPolicy means an attacker who pivots inside the pod still can't reach internal services.

To enable inside the SandboxTemplate, the container needs the capabilities:

```yaml
containers:
  - name: claude
    image: ...
    securityContext:
      capabilities:
        add: [NET_ADMIN, NET_RAW]
    command: ["/usr/local/bin/init-firewall.sh"]
    args: ["claude", "--print", ...]
```

Note the tension with `runAsNonRoot: true` — NET_ADMIN/NET_RAW often require root inside the pod. If running Kata or gVisor, the host kernel is still isolated from the pod's namespace, so root-in-pod is much lower risk than root-on-host. Document the tradeoff in your prod template.

## Composing policies

Upstream ships `examples/composing-sandbox-nw-policies/` as a pattern for layering multiple SandboxTemplates' policies. The basic idea: keep one default-deny baseline template and inherit from it. Inspect that example before authoring a custom composition.

## Verifying the policy is in effect

From inside the pod:

```bash
# Should succeed: DNS resolution
nslookup api.anthropic.com

# Should succeed: HTTPS to Anthropic
curl -sI https://api.anthropic.com/v1/models -H "x-api-key: $ANTHROPIC_API_KEY" | head -1

# Should fail: arbitrary outbound HTTPS
curl -sS --max-time 5 https://example.com/  # expect timeout/refused
```

If the third curl succeeds, the policy is too loose; tighten the `ipBlock`.
