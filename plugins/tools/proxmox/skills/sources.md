# Sources

## proxmox skill

### Private infra repo Nushell scripts
- **Source**: `~/github/infra/scripts/` (local repository)
- **Files consulted**:
  - `proxmox.nu` — API-token wrapper (`pve` function, auth header, self-signed cert handling), `nodes`/`storage`/`vms`/`nextid`/`version`/`preflight`/`status`/`destroy` subcommands
  - `golden-image.nu` — pure-API golden-image pipeline (`enable-import-storage`, `download-image`, `create-vm`, `bake`, `finalize-template`, `verify-clone`, `build`)
  - `proxmox-template.nu` — legacy netboot-autoinstall template builder (`create-build-vm`, `attach-cloudinit-disk`, `finalize-template`, `clone`, `wait-task`, `wait-stopped`)
- **Key topics**: API-token access pattern, disk import via `import-from`, cloud-init drive attachment timing (build VM vs. clone), templating sequence, task polling

### Private infra repo runbooks
- **Source**: `~/github/infra/docs/runbooks/` (local repository)
- **Files consulted**:
  - `proxmox-upgrade.md` — 8.0.3→8.4 upgrade sequence, `import-from`/`import` version staging table, `pve8to9` pre-flight overview, 8→9 breaking-change summary. **Stale as of 2026-07-09**: recommends deferring the 8→9 jump; superseded by the live upgrade completed that day. The systemd-boot removal, Ceph purge/upgrade branch, and `grub-efi-amd64`/`force_efi_extra_removable` blockers are NOT documented in this file — they are session-proven 2026-07-09, not doc-sourced.
  - `proxmox-datacenter-manager.md` — PDM deployment runbook: what PDM is, auth model (PDM realm vs. per-remote API token), cluster-vs-PDM decision table, PBS/PDM version pairing with PVE 9.x
- **Key topics**: repository configuration (enterprise vs. no-subscription), version-gated feature availability, cluster quorum fragility, PDM/PBS estate services

### Private infra repo Terraform
- **Source**: `~/github/infra/terraform/proxmox/` (local repository)
- **Files consulted**: `main.tf`, `variables.tf`, `versions.tf`, `outputs.tf` — confirmed `bpg/proxmox` provider pin, two `provider "proxmox"` blocks (both production nodes), two per-node `proxmox_virtual_environment_vm.k3s_node` resources cloning from the golden template
- **Key topics**: Terraform-managed VM lifecycle, provider configuration for a multi-node estate

### Private infra repo provisioning scripts
- **Source**: `~/github/infra/images/provision/` (local repository, existence verified via `find`)
- **Files consulted (existence only, not full content)**: `install-base.sh`, `generalize.sh` — referenced by `golden-image.nu`'s `bake` subcommand as the guest-side provisioning scripts run over SSH
- **Key topics**: guest provisioning order (install-base before generalize), generalize.sh's poweroff-on-completion behavior

### Session-proven operational knowledge (2026-07-09)
- **Source**: live operation against two production nodes, both upgraded PVE 8.x → 9.2.4 / Debian 13.5 the same day. Not captured in any file in this repository or `~/github/infra/`; reported directly by the operating session and recorded in bees issue `claude-skills-112`.
- **Key topics**: 8→9 blocker checklist (systemd-boot removal, Ceph version gate, `grub-efi-amd64`/`force_efi_extra_removable`), foreground-vs-backgrounded reboot behavior over SSH, kernel-based reboot-completion polling vs. ping, first-boot duration after a major upgrade, zsh word-splitting of unquoted variables holding SSH options

### Node-served authoritative docs (referenced by the "Authoritative docs rule" in SKILL.md, not fetched during authoring — no live node was reachable from this session)
- `https://<node>:8006/pve-docs/index.html` — version-matched PVE docs for the exact PVE build running on that node
- `https://<node>:8006/pve-docs/api-viewer/apidoc.js` — live REST API schema for that node's exact version
- **Purpose**: cited in SKILL.md as the primary authority to consult over training data for any version-sensitive claim; `<node>` is a placeholder for the real hostname/IP, so this pair is documented as a pattern, not a fetchable URL.

### Proxmox official documentation (verified reachable via `curl -s -o /dev/null -w '%{http_code}'`, HTTP 200 confirmed 2026-07-13)
- Package repositories: `https://pve.proxmox.com/wiki/Package_Repositories`
- 8→9 upgrade guide: `https://pve.proxmox.com/wiki/Upgrade_from_8_to_9`
- Cluster manager / QDevice: `https://pve.proxmox.com/wiki/Cluster_Manager`
- PVE 8.4 press release: `https://www.proxmox.com/en/about/company-details/press-releases/proxmox-virtual-environment-8-4`
- PVE 9.0 press release: `https://www.proxmox.com/en/about/company-details/press-releases/proxmox-virtual-environment-9-0`
- PDM 1.0 press release: `https://www.proxmox.com/en/about/company-details/press-releases/proxmox-datacenter-manager-1-0`
- PDM 1.1 press release: `https://www.proxmox.com/en/about/company-details/press-releases/proxmox-datacenter-manager-1-1`
- PDM downloads page: `https://www.proxmox.com/en/downloads/proxmox-datacenter-manager`
- PDM docs: `https://pdm.proxmox.com/docs/`
- PDM remotes doc (no-cluster-required managed nodes): `https://pdm.proxmox.com/docs/remotes.html`
- PBS product page: `https://www.proxmox.com/en/proxmox-backup-server`
- `import-from`/`import` staging: Proxmox bugzilla `https://bugzilla.proxmox.com/show_bug.cgi?id=4141` (+ comment 20)
- **Key topics**: repository format, 8→9 breaking changes, PVE/PDM/PBS version history and pairing, cluster quorum/QDevice guidance, `import-from` vs. `import` version gate

### Canonical cloud images
- `https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img` — the image `golden-image.nu` downloads via `download-url`
- `https://cloud-images.ubuntu.com/` — index of all Ubuntu release cloud images
- **Verified reachable**: HTTP 200, checked 2026-07-13
- **Key topics**: reuse-first rationale for the golden-image pipeline (import Canonical's published image rather than netboot-installing)

### Terraform provider
- `https://github.com/bpg/terraform-provider-proxmox` — provider source
- `https://registry.terraform.io/providers/bpg/proxmox/latest/docs` — provider docs
- **Verified reachable**: HTTP 200, checked 2026-07-13
- **Key topics**: `proxmox_virtual_environment_vm` resource shape, used by `~/github/infra/terraform/proxmox/main.tf`

### Proxmox Backup Server documentation (verified reachable via `curl -s -o /dev/null -w '%{http_code}'`, HTTP 200 confirmed 2026-07-13; content spot-checked with `curl | sed -e 's/<[^>]*>//g' | grep` to confirm claims before citing)
- PBS docs index: `https://pbs.proxmox.com/docs/`
- Introduction / architecture (client-server model, deduplication, compression, authenticated encryption over TLS): `https://pbs.proxmox.com/docs/introduction.html`
- Installation (ISO installer, `apt install` on Debian, `apt install proxmox-backup-server` directly on a PVE node, system-requirements guidance on separate OS/backup storage): `https://pbs.proxmox.com/docs/installation.html`
- Storage / datastore concept: `https://pbs.proxmox.com/docs/storage.html`
- PVE integration (Datacenter → Storage, `pvesm set <storage-id> --fingerprint`, `proxmox-backup-manager cert info`): `https://pbs.proxmox.com/docs/pve-integration.html`
- Maintenance (pruning vs. garbage collection, two-phase reclaim model): `https://pbs.proxmox.com/docs/maintenance.html`
- Backup client (client-side encryption, master key, `PBS_ENCRYPTION_PASSWORD`): `https://pbs.proxmox.com/docs/backup-client.html`
- **Key topics**: PBS product description, deployment options, datastore concept, PVE-side wiring, backup job/restore paths, prune/GC retention model, client-side encryption

### PDM access-control documentation (additional page consulted for the 2026-07-13 estate-services.md expansion; HTTP 200 confirmed)
- `https://pdm.proxmox.com/docs/access-control.html` — the `pdm` realm, PAM/OIDC/LDAP/AD/2FA support, separation from per-node PVE user databases
- **Key topics**: PDM's own auth layer vs. its per-remote PVE API-token auth layer

### Private infra repo runbook re-read (2026-07-13, for the estate-services.md PDM expansion)
- **Source**: `~/github/infra/docs/runbooks/proxmox-datacenter-manager.md` (re-read in full; already listed above but re-consulted specifically for the ISO-vs-apt install options, the `pveum user token add ... --privsep 1` / `pveum acl modify` commands, and the "Add both nodes as remotes" deployment steps quoted in the expanded estate-services.md)

### Corrections to a prior source list (anti-fabrication)
A source list handed off mid-session guessed four press-release URLs under the pattern `proxmox.com/en/news/press-release-proxmox-virtual-environment-{82,84,90,92}` and a PDM product page at `proxmox.com/en/proxmox-datacenter-manager`. All five returned HTTP 404 when checked (`curl -s -o /dev/null -w '%{http_code}'`, 2026-07-13) and are NOT cited above. The correct, verified URL pattern for Proxmox press releases is `proxmox.com/en/about/company-details/press-releases/<slug>` (see the PVE 8.4/9.0 and PDM 1.0/1.1 entries above), and the correct PDM overview lives at the downloads page and `pdm.proxmox.com/docs/`, not a `proxmox.com/en/proxmox-datacenter-manager` product page.
