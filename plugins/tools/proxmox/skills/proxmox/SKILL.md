---
name: proxmox
description: "Operates a Proxmox VE estate — API-token access for steady-state VM/storage/lifecycle operations, host root SSH for host-level operations (dist-upgrades, Ceph, disk import, cloud-init clean), pure-API golden-image builds, PVE 8-to-9 major upgrades, and PDM/PBS estate services. Use when managing Proxmox nodes, building or templating VM images, planning or executing a PVE major-version upgrade, choosing between clustering and PDM for multi-node management, or automating Proxmox via its REST API, CLI tools, or Terraform."
license: MIT
---

# Proxmox VE Operations

Operates a Proxmox Virtual Environment (PVE) estate: hypervisor lifecycle, golden-image builds, major-version upgrades, and multi-node estate services (PDM, PBS).

Claims in this skill are labeled by provenance: **doc-sourced** (cited to an official Proxmox source), or **session-proven 2026-07-09** (observed live against two production nodes during a same-day 8.x-to-9.2.4 / Debian-13.5 modernization). Neither label is a guarantee against future PVE releases — re-verify against the authoritative docs below before relying on version-specific behavior.

## Authoritative docs rule

PVE's API and CLI surface drifts across versions faster than training data tracks. Before implementing anything version-sensitive (parameter names, content types, breaking changes), consult the node-served documentation instead of guessing:

- **`https://<node>:8006/pve-docs/index.html`** — version-matched to the exact PVE build running on that node. Always current for that node; never stale.
- **`https://<node>:8006/pve-docs/api-viewer/apidoc.js`** — the live API schema for that node's exact version (parameters, methods, return shapes).

Substitute the node's LAN IP or hostname. These pages require the self-signed cert or `-k`/`--insecure` when fetched with `curl`. Prefer them over memory for any claim about parameter availability, content-type gating, or breaking changes between versions — see `references/upgrade-8-to-9.md` for a documented case (`import-from` vs `import`) where getting this wrong breaks the golden-image pipeline.

## Two-tier access model

Two access tiers cover every operation. Escalate to the higher tier only when the lower tier cannot perform the operation.

| Tier | Credential | Covers |
|---|---|---|
| **API token** | `op://<vault>/<pve-api-token>` (1Password) | VM/LXC lifecycle (create, clone, start, stop, destroy), storage inspection, node/version queries, disk import via `import-from`, cloud-init config, templating (`qm template` over the API) |
| **Host root SSH** | node root, out-of-band (AMT/console for recovery) | `apt`/`dist-upgrade`, `pve8to9`, Ceph administration, `qm importdisk` from local files, in-guest provisioning over SSH, anything touching the host OS below the PVE API surface |

**Escalation rule:** default to the API token. Escalate to host SSH only for operations the PVE REST API does not expose — package management, OS-level upgrades, and Ceph cluster administration are the primary cases. `scripts/proxmox.nu` (the existing implementation, see `~/github/infra/scripts/proxmox.nu`) wraps the API-token tier: `nodes`, `storage`, `vms`, `nextid`, `version`, `preflight`, `status <vmid>`, `destroy <vmid>`. The `preflight` subcommand snapshots version + running-guest state before any upgrade — run it before escalating to the SSH tier for a `pve8to9` pass.

**Secret safety** (per `/core:security`): confirm the token exists without printing its value —

```bash
test -n "$(op read 'op://<vault>/<pve-api-token>/credential' 2>/dev/null)" && echo "set" || echo "empty"
```

Never `op read --reveal` or echo the credential in agent output, logs, or PR descriptions.

## Golden-image builds (pure-API, PVE 9.x)

`scripts/golden-image.nu` builds a golden Ubuntu template using only the API token — no SSH to the PVE host, no netboot-install of what Canonical already ships (reuse-first). Pipeline: enable `import`+`images` content on a storage → download the Canonical cloud image → create a VM via disk `import-from` + cloud-init → SSH into the *guest* (not the host) to provision → `qm template` → clone-and-verify. See `references/golden-image.md` for the full recipe, the `import-from`-vs-`import` version trap, and templating rules (cloud-init clean, machine-id reset, linked vs full clone).

## PVE 8-to-9 upgrade

The 8→9 jump is a Debian major upgrade (12 Bookworm → 13 Trixie), not a point-release `dist-upgrade`. It requires host root SSH throughout and has blockers beyond what Proxmox's own upgrade guide documents. See `references/upgrade-8-to-9.md` for the full sequence, the blocker checklist (systemd-boot, Ceph version gate, GRUB/EFI), and four session-proven operational gotchas (reboot backgrounding, kernel-based reboot polling, slow first boot, zsh word-splitting).

## Estate services — PDM and PBS

For a 2-node (or generally sub-3-node) estate, Proxmox Datacenter Manager (PDM) delivers single-pane management and cross-node live migration **without** the quorum fragility of a PVE cluster. Proxmox Backup Server (PBS) provides deduplicated backups independent of clustering. See `references/estate-services.md` for the cluster-vs-PDM decision table and the version pairing with PVE 9.x.

## Automation surfaces

Four ways to drive Proxmox programmatically — REST API + CLI tools, the `bpg/proxmox` Terraform/OpenTofu provider, Packer, and the existing nushell helpers — plus a Runex-specific parameter-naming gotcha. See `references/automation.md`.

## Anti-fabrication

Every claim in this skill and its references is labeled doc-sourced (cited to an official Proxmox source or a file in this repository) or session-proven 2026-07-09 (observed live, not documented elsewhere) — never presented as fact from unverified memory. Before asserting a PVE parameter, content type, or breaking change not covered here, consult the authoritative docs rule above rather than guessing. Load `/core:anti-fabrication` for the full validation discipline.

## Reuse-first defaults

- Golden images: reuse Canonical's published cloud image via `import-from`; do not netboot-install a distro PVE already has an official cloud image for.
- Multi-node management: reuse PDM before standing up a PVE cluster (`references/estate-services.md`) — clustering earns its keep only at ≥3 nodes.
- Terraform: reuse the `bpg/proxmox` provider already wired in `~/github/infra/terraform/proxmox/` (verified present: `main.tf`, `variables.tf`, `versions.tf` pin `bpg/proxmox`, two per-node `k3s_node` resources) rather than hand-rolling API calls for anything Terraform-managed already covers.
- Existing scripts: `~/github/infra/scripts/proxmox.nu` (API wrapper), `golden-image.nu` (image pipeline), `proxmox-template.nu` (legacy netboot-build template helper, superseded by `golden-image.nu`'s pure-API path for new builds) already implement the patterns in this skill — extend them before writing new API-calling code.

## References

- `references/golden-image.md` — pure-API golden-image build recipe, `import-from`/`import` version trap, templating rules, macOS/libguestfs caveat
- `references/upgrade-8-to-9.md` — full 8→9 sequence, blocker checklist, session-proven operational gotchas, PDM/PBS version pairing
- `references/estate-services.md` — cluster vs. PDM decision, PBS backup role
- `references/automation.md` — REST/CLI, Terraform, Packer vs. pure-API import, nushell helpers, Runex param-naming gotcha
