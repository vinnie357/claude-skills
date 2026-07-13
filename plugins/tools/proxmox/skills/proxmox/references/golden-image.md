# Golden Image Builds — Pure API, PVE 9.x

Builds a reusable Ubuntu template using only the API-token tier — no host SSH to the PVE node. The working implementation is `~/github/infra/scripts/golden-image.nu`; this reference documents its pipeline and the version traps behind it.

## Reuse-first: don't netboot-install what Canonical ships

Canonical publishes an official cloud image for every Ubuntu release (`noble-server-cloudimg-amd64.img` for 24.04). Importing that image via the API is the reuse-first path — it replaces a retired netboot-autoinstall build (`proxmox-template.nu`'s `create-build-vm`/`attach-cloudinit-disk` path, VMIDs 9000/9001) that spent 15-25 minutes per build running Subiquity against a netboot ISO. The pure-API path skips OS installation entirely.

## The critical version distinction: `import-from` vs `import`

Two different PVE features, gated at different versions, are easy to conflate:

| Feature | What it is | First available | Source |
|---|---|---|---|
| `import-from` **config parameter** | A disk-config parameter (`scsi0=<storage>:0,import-from=<source>`) that imports an existing disk image as a new VM disk | pve-manager **7.2** (backend landed 8.1-8/libpve-storage-perl 8.1.3+ for the storage-plugin/ESXi-import flavor; the parameter itself is documented from 7.2 onward) | Proxmox bugzilla #4141; `~/github/infra/docs/runbooks/proxmox-upgrade.md` §3 |
| `import` **content type** | A storage content-type (`content=import`) that lets a dir storage hold uploaded/downloaded images specifically for import use, populated via `download-url` or upload | pve-manager **8.2+** (GA import wizard); the full upload-then-`import-from` flow matured in **8.4** | Proxmox 8.2 press release; bugzilla #4141 comment 20 |

Do not conflate the two: a node can support the `import-from` config parameter (7.2+) without supporting the `import` content-type storage flow (8.2+/8.4). `golden-image.nu` uses **both** — `enable-import-storage` adds the `import` content type to a dir storage (needs 8.2+, matured 8.4+), then `create-vm` uses `import-from` pointing at that storage's imported file (needs 7.2+, safe on any node that already passed the first gate). On PVE 9.x both gates are satisfied; this table matters when adapting the pipeline to an older or mixed-version estate. Confirm the running node's actual support via `https://<node>:8006/pve-docs/api-viewer/apidoc.js`, not this table alone — table entries reflect PVE 8.x-era documentation and may not reflect 9.x renames.

## Pipeline (golden-image.nu subcommands)

Runnable step-by-step for debugging, or via `build` for steps 1-3:

1. **`enable-import-storage [--storage local]`** — adds `import`+`images` to a dir storage's content types (additive; preserves existing types like `snippets`/`iso`/`backup`/`vztmpl`).
2. **`download-image [--storage local]`** — pulls the Canonical noble cloud image into that storage via `download-url`, content type `import`. `.qcow2` extension required — PVE's `import` content type gates on file extension, `.img` is rejected (verified against 9.2.4).
3. **`create-vm [--vmid 9002] [--sshkey <path>]`** — creates the VM with `scsi0=<storage>:0,import-from=<import-storage>:import/<file>`, `machine=q35`, `bios=ovmf`, `scsihw=virtio-scsi-single`, `agent=1`. q35+OVMF matches the `k3s_node` clone spec in `~/github/infra/terraform/proxmox/main.tf` — a SeaBIOS clone of an OVMF-built disk does not boot. Attaches a cloud-init drive (`ide2=<storage>:cloudinit`), resizes the disk, starts the VM.
4. **`bake <ip> [--sshkey <path>] [--user vinlab]`** — SCPs `images/provision/install-base.sh` and `images/provision/generalize.sh` to the *guest* (over its DHCP-assigned IP, not the PVE host) and runs them via SSH. `install-base.sh` runs first (idempotent, safe to re-run on partial failure); `generalize.sh` runs last and powers the VM off — a non-zero/broken-pipe SSH exit at that point is expected (the poweroff kills the session), not a failure.
5. **`finalize-template [--vmid 9002]`** — requires the VM to be `stopped` (post-`generalize.sh` poweroff); converts it via `qm template` over the API (`POST /nodes/<node>/qemu/<vmid>/template`).
6. **`verify-clone <newid> [--source 9002] [--sshkey <path>]`** — full-clones the template to a throwaway VMID, boots it, and prints the acceptance-check command: SSH in and confirm `hostname`, `iscsiadm --version`, `systemctl is-active qemu-guest-agent`, and `/sys/kernel/btf/vmlinux` presence. Destroy the throwaway clone afterward (`nu scripts/proxmox.nu destroy <newid>`).

## Templating rules

- **`qm template` is one-way.** Converting a VM to a template is not reversible from the API; clone from it instead of un-templating it.
- **Linked vs full clone.** `golden-image.nu`'s `verify-clone` uses `full=1` (independent disk copy) — appropriate for an acceptance test that will be destroyed. Production clones from `~/github/infra/terraform/proxmox/main.tf`'s two per-node `k3s_node` resources also full-clone from the template (verified: both resources present, targeting different providers/nodes from the same template ID).
- **Cloud-init is a VMware-style customization spec, not a first-boot script.** The `ide2=<storage>:cloudinit` drive holds per-clone identity (`ciuser`, `sshkeys`, `ipconfig0`) that cloud-init on the guest consumes at boot. It is unrelated to any autoinstall/Subiquity cloud-init datasource used during OS installation — conflating the two caused the netboot-build path's datasource hijack bug (documented in `proxmox-template.nu`'s `attach-cloudinit-disk` comment: attaching the Proxmox cloud-init CD to a build VM makes subiquity prefer the local `cidata` datasource over the network autoinstall seed, so autoinstall never runs).
- **MUST clean the guest identity before templating, or clones skip customization.** `generalize.sh` (run before `finalize-template`) must reset machine-id and host SSH keys and clear cloud-init's own state cache (`cloud-init clean`) — a template built without this reuses the same machine-id/host-keys/cloud-init "already ran" marker across every clone, and clones silently skip re-running cloud-init's per-instance customization.

## macOS / libguestfs caveat

`libguestfs`-based tools (`virt-customize`, `virt-sysprep`) require a Linux host with KVM/nested-virtualization access and fail on macOS. This constraint does not apply to `golden-image.nu`'s actual pipeline — it avoids guest-filesystem-level customization entirely, using cloud-init plus SSH-based provisioning (`install-base.sh`, `generalize.sh`) instead. Document this caveat only if evaluating `virt-customize`/`virt-sysprep` as an alternative to the SSH-based approach; it is not a constraint on the documented pipeline above.
