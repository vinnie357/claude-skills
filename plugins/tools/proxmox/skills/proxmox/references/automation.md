# Automation Surfaces

Four ways to drive Proxmox programmatically, in reuse-first order: check whether the existing nushell helpers or the Terraform module already cover the operation before writing new API-calling code.

## REST API + CLI tools

The API-token tier (`op://<vault>/<pve-api-token>`) drives the PVE REST API directly (`https://<node>:8006/api2/json/...`). Equivalent host-side CLI tools exist for the host-SSH tier:

- `pvesh` — CLI wrapper around the same REST API, useful for ad-hoc host-side calls
- `qm` — VM lifecycle (create/clone/start/stop/template/importdisk)
- `pct` — LXC container lifecycle
- `pveam` — appliance/template catalog management
- `pvecm` — cluster membership (estate-services.md covers when to use this vs. PDM)
- `proxmox-backup-*` — PBS client tools for backup/restore operations

`qm importdisk` (host-side CLI) differs from the API's `import-from` config parameter (golden-image.md) — `importdisk` operates on a local file path on the host filesystem and requires host SSH; `import-from` operates through the API against a storage-resident image and needs only the API token. Prefer `import-from` for anything the API-token tier can reach; reserve `qm importdisk` for images that only exist as a local file on the PVE host itself.

## Terraform / OpenTofu — `bpg/proxmox` provider

`~/github/infra/terraform/proxmox/` (verified present) already wires the `bpg/proxmox` provider (pinned in `versions.tf`) against both nodes (`main.tf` declares two `provider "proxmox"` blocks). `outputs.tf` exposes `k3s_nodes` built from the two per-node `proxmox_virtual_environment_vm.k3s_node` resources, both cloning from the golden template built per golden-image.md. Provider docs: `https://registry.terraform.io/providers/bpg/proxmox/latest/docs`. Extend this module for any Terraform-managed VM lifecycle; do not hand-roll API calls for what it already covers.

## Packer vs. pure-API import

Packer's `proxmox-iso` and `proxmox-clone` builders are a documented alternative to the pure-API golden-image pipeline in golden-image.md. Decision: the pure-API path (`golden-image.nu`, `import-from` + cloud-init + SSH provisioning) is the reuse-first choice for this estate because it needs only the API token, has no Packer dependency, and the working implementation already exists. Reach for Packer only if a build requirement needs Packer-specific features the pure-API pipeline does not cover (e.g., driving a full ISO-based interactive install for an OS with no published cloud image) — that is not the common case for cloud-image-based Linux builds this estate targets.

## Existing nushell helpers

`~/github/infra/scripts/`:

- `proxmox.nu` — the `pve` API wrapper function plus `nodes`/`storage`/`vms`/`nextid`/`version`/`preflight`/`status`/`destroy` subcommands. The base import other scripts build on (`use proxmox.nu pve`).
- `golden-image.nu` — the pure-API golden-image pipeline (golden-image.md).
- `proxmox-template.nu` — the legacy netboot-autoinstall template builder (VMID 9000 path) plus the generic `wait-task`/`clone` helpers that `golden-image.nu` also imports (`use proxmox-template.nu wait-task`). Superseded by `golden-image.nu` for new builds, but its task-polling and clone-with-cloud-init-identity helpers remain in active use.

Extend these before writing new scripts — `proxmox.nu`'s `pve` function already handles auth-header construction, self-signed-cert `curl -k`, and JSON parsing for every API call in this estate.

## Runex Shell driver gotcha — parameter naming

If wiring any of the above into a Runex workflow (see `/runex:runex`), the Shell driver's `@default_sensitive_patterns` silently strips workflow parameters whose name contains `KEY`, `SECRET`, or `TOKEN` before the subprocess sees them. A parameter named `API_KEY` or `PVE_TOKEN` arrives empty downstream with no error. Name Proxmox-related workflow parameters to avoid these substrings — e.g., `PVE_CREDENTIAL` instead of `PVE_TOKEN`, `PVE_AUTH` instead of `PVE_API_KEY`.
