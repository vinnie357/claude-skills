# Estate Services — PDM and PBS

Managing more than one PVE node raises two independent decisions: how to manage them together (PDM vs. a cluster) and where backups live (PBS). Source: `~/github/infra/docs/runbooks/proxmox-datacenter-manager.md`, `https://pdm.proxmox.com/docs/`, and `https://pbs.proxmox.com/docs/` (all URL citations below verified reachable, HTTP 200, checked 2026-07-13).

## Cluster vs. PDM decision

| | PVE cluster (`pvecm`) | PDM |
|---|---|---|
| What it is | Nodes share one corosync/pmxcfs config, one login, quorum-gated | External manager over independent remotes |
| Quorum | Required. At 2 nodes, losing either drops below quorum — the surviving node's management goes read-only. Proxmox recommends a QDevice (3rd vote) for a 2-node HA cluster. | None. No quorum, no corosync; each node stays standalone. |
| Failure blast radius | A node/network blip can freeze the *other* node's management | A dead node shows as a red remote; the survivor is unaffected |
| Extra hardware | Needs a 3rd corosync vote (QDevice) to be safe at 2 nodes | Just the PDM appliance |
| Live migration | Yes, within the cluster | Yes, cross-remote, no cluster required |
| Single pane | Yes (shared UI) | Yes (PDM UI) |

**Decision rule:**

- **2 nodes → PDM, not a cluster.** A 2-node cluster gives single-pane + live-migration but drags in quorum fragility (either node down puts the cluster read-only) for a home-lab-scale estate. PDM delivers the same single-pane + cross-node live migration with zero quorum and survives one node dying.
- **≥3 nodes (or 2 nodes + a QDevice as a 3rd vote) → clustering becomes viable.** A real cluster at that scale gives HA + shared storage (Ceph) that PDM alone does not provide. Cluster the ≥3 nodes and keep PDM on top as the multi-cluster management pane.

Source: Proxmox Cluster Manager docs ("Corosync External Vote Support") — the documented stance is an affirmative recommendation to add a QDevice for 2-node HA clusters, not a blanket prohibition on 2-node clusters; the recommendation above is this skill's synthesis for an estate that has not yet reached 3 nodes.

## PDM — Proxmox Datacenter Manager

Central management layer: one dashboard over multiple PVE remotes (standalone nodes and clusters) plus PBS, with cross-cluster live VM migration and native RBAC. Manages standalone nodes with no cluster network requirement.

- **Version pairing:** PDM 1.1 (released 2026-05-28) pairs with PVE 9.x. PDM is stable/GA as of 1.0 (2025-12-04). PDM 1.x tracks the PVE 9.x release line — expect PDM point releases to follow PVE 9.x point releases rather than a fixed independent cadence.
- **Deployment options** (`https://pdm.proxmox.com/docs/`, `~/github/infra/docs/runbooks/proxmox-datacenter-manager.md`): (1) **hybrid ISO appliance** — download the PDM ISO (bundled Debian 13 + packages) and install onto a VM or bare metal; the documented turnkey path. (2) **`apt install` on an existing Debian 13 (Trixie) host** — add PDM's own apt repo (Enterprise/No-Subscription/Test, same model as PVE, deb822 `.sources` format) and install the PDM packages; use only if PDM needs to live on a Debian host already managed as code. PDM must run as its own appliance, never as a guest on a node it manages — losing that node would also lose the tool managing the survivor.
- **Initial setup:** first boot sets the PDM admin password; enable 2FA on the PDM login immediately (PDM has its own `pdm` realm plus PAM/OIDC/LDAP/AD/2FA support, entirely separate from any PVE node's user database — `https://pdm.proxmox.com/docs/access-control.html`).
- **Adding a remote — two auth paths:** (1) **manual privilege-separated token (recommended)** — on each PVE node, create a scoped token and grant it a role rather than handing PDM root:
  ```bash
  pveum user token add root@pam pdm --privsep 1
  pveum acl modify / --tokens 'root@pam!pdm' --roles PVEAdmin
  ```
  Store the resulting token the same way as the steady-state API token (`op://<vault>/...`). (2) **one-time root/Administrator handoff** — hand PDM root or Administrator credentials once during remote setup and it auto-provisions its own token; less operator effort, less privilege-separated. In the PDM UI (Remotes → Add), each node is added as a **standalone remote** (`https://<node>:8006`, the node's API token, accept/import its self-signed cert fingerprint) — no cluster membership required either direction. Source: `https://pdm.proxmox.com/docs/remotes.html`.
- **What PDM covers day-to-day:** unified real-time dashboard across all remotes' guests/storage/status, cross-remote guest table, cross-cluster/cross-node live migration, cross-remote snapshot management, unified Ceph monitoring, central subscription registry, unattended-install answer files (all shipped in 1.0/1.1). **What still requires the per-node UI or API-token tier:** anything PDM deep-links out to rather than hosts itself — per-node storage configuration, guest console access, and any host-level operation this skill's two-tier access model already routes to host SSH (dist-upgrades, Ceph administration) stays on the node, not PDM. PDM is a management/migration pane, not a replacement for the node-level API or SSH tiers.

## PBS — Proxmox Backup Server

Deduplicated, incremental, client-server backup solution — describing the product, not this estate's actual backup deployment state (unconfirmed as deployed against either production node as of this writing). PBS 4.x pairs with PVE 9.x. Source: `https://pbs.proxmox.com/docs/introduction.html`.

- **What it is:** a client-server backup target for VMs, containers, and physical hosts. The server stores backup data and exposes an API to create and manage datastores; deduplication, compression, and authenticated encryption run over TLS-secured client-server communication. Deduplication specifically targets the redundancy in periodic backups — repeated full backups of mostly-unchanged data consume only the delta in storage.
- **Deployment options** (`https://pbs.proxmox.com/docs/installation.html`): a hybrid ISO installer (burn to DVD or `dd` to a USB stick) for a dedicated host or VM, an `apt install proxmox-backup-server` path on an existing Debian host, or `apt install proxmox-backup-server` directly on a PVE node (documented as "Install Proxmox Backup Server on Proxmox VE"). Co-hosting on a PVE node is a documented option; the installation docs' own system-requirements guidance recommends dedicating OS storage separately from backup storage and notes that periodic incremental datastore synchronization "decrease[s] the impact of a failed host" — the same failure-isolation logic behind this skill's PDM placement guidance argues for a dedicated host/VM with its own storage over co-hosting PBS on a node it also backs up.
- **Datastore concept:** the fundamental storage unit — a directory tree PBS manages chunks and snapshot metadata (manifest, indices, blobs, log, notes) within. Source: `https://pbs.proxmox.com/docs/storage.html`.
- **Wiring PVE to PBS:** in the PVE UI, add PBS as a storage under **Datacenter → Storage** (type `pbs`). If the PBS server uses a self-signed certificate, fetch its fingerprint on the PBS host and add it to the PVE storage config:
  ```bash
  # on the PBS host
  proxmox-backup-manager cert info | grep Fingerprint
  # on the PVE host, via CLI (or the equivalent Datacenter -> Storage UI field)
  pvesm set <storage-id> --fingerprint <fingerprint>
  ```
  Source: `https://pbs.proxmox.com/docs/pve-integration.html`.
- **Backup jobs:** scheduled from the PVE UI (Datacenter → Backup) against the `pbs`-type storage, same scheduling model as any other PVE backup target.
- **Restore paths:** full VM/container restore from a snapshot via the PVE UI, or single-file restore (browse a snapshot's filesystem and pull individual files) also via the PVE UI, without restoring the whole guest.
- **Prune / GC retention basics** (`https://pbs.proxmox.com/docs/maintenance.html`): pruning removes snapshot *metadata* per a retention policy (keep-last/keep-daily/keep-weekly/etc.) but not the underlying chunks — a pruned snapshot's data chunks remain on disk, referenced or not, until a separate garbage-collection run reclaims genuinely unreferenced chunks. Two-phase by design: prune decides what to keep, GC reclaims space.
- **Client-side encryption:** PBS supports encrypting backup data before it leaves the client, using a master key or a password-protected key (`PBS_ENCRYPTION_PASSWORD` env var) — data can be sent to a PBS target that isn't fully trusted, since the server never sees the plaintext. Source: `https://pbs.proxmox.com/docs/backup-client.html`.

PBS is not a substitute for PDM's live-management role, and PDM is not a substitute for PBS's backup role — use both, independent of the cluster-vs-standalone decision above.
