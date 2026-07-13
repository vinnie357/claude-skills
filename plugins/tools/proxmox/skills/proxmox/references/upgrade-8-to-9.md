# PVE 8-to-9 Upgrade

PVE 9 is a Debian major bump (12 Bookworm → 13 Trixie) — a real migration, not a `dist-upgrade` point release. It requires the host-SSH access tier throughout; the API-token tier cannot perform any step below.

**Provenance note:** `~/github/infra/docs/runbooks/proxmox-upgrade.md` documents the pre-upgrade planning state and recommends deferring 9.x ("8.x now, defer 9.x — restraint"). That recommendation is now superseded — both production nodes completed the 8.x→9.2.4/Debian-13.5 upgrade live on 2026-07-09. Steps 1-6 below are doc-sourced from that runbook (still accurate for the mechanical sequence); the blocker checklist in step 4 and the gotchas in the final section are session-proven 2026-07-09 and are not documented in that runbook.

## Version landscape (doc-sourced, confirmed 2026-07-09)

| Track | Version | Debian base |
|---|---|---|
| Latest 8.x (final) | 8.4 | 12 Bookworm |
| PVE 9 current | 9.2 | 13 Trixie |
| PDM paired with PVE 9 | 1.1 | — |
| PBS paired with PVE 9 | 4.x | — |

Source: `~/github/infra/docs/runbooks/proxmox-upgrade.md` version table (cites Proxmox roadmap and press releases).

## Sequence

### 1. Repository fix (if still on enterprise repo)

Disable the enterprise repo (401s without a subscription), add no-subscription:

```bash
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
echo 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' \
  > /etc/apt/sources.list.d/pve-no-subscription.list
```

PVE 8 (Bookworm) uses the legacy single-line `.list` format — do not create deb822 `.sources` files on an 8.x box (that format is Trixie/PVE-9-era).

### 2. Upgrade to latest 8.x first

`pve8to9` requires the node already on 8.4 before it will proceed:

```bash
apt update
apt dist-upgrade
reboot
```

### 3. `pve8to9` pre-flight (read-only)

Run before touching repos for the major jump. Confirms: node on 8.4, all cluster nodes on 8.4 (N/A standalone), Ceph on Squid 19.2 if hyper-converged (N/A if no Ceph), LVM/LVM-thin autoactivation, deprecated-config flags, tested backup, ≥5 GB free root (10+ recommended).

### 4. Resolve blockers

`pve8to9` surfaces warnings; three specific blockers must be resolved before proceeding (**session-proven 2026-07-09** — not documented in the stale runbook, which predates encountering them):

- **Remove the `systemd-boot` meta-package.** PVE 9/Trixie's boot tooling conflicts with a systemd-boot install; remove the meta-package before the repo switch.
- **Ceph version gate.** If Ceph is installed but unused, purge it. If in active use, it must be upgraded to Squid 19.2 *before* the PVE major upgrade (two-step: Ceph first, then PVE) — this repo's estate had no active Ceph, so purge was the applicable branch.
- **Install `grub-efi-amd64` with `force_efi_extra_removable`.** Required for the EFI boot path to survive the Trixie kernel/bootloader changes; without it, a UEFI system can fail to find a bootable EFI entry post-upgrade. Set this before the reboot into Trixie, not after.

### 5. Switch repos bookworm → trixie

Trixie uses the deb822 `.sources` format, not the legacy `.list`:

```bash
# repo lines change from 'bookworm' to 'trixie' AND from .list to .sources
# confirm exact suite/component strings against the node's own /pve-docs before writing
```

### 6. Major dist-upgrade and reboot

```bash
apt update
apt dist-upgrade
```

Reboot **in the foreground**, not backgrounded (see gotcha below).

## Session-proven operational gotchas (2026-07-09)

Encountered live during both nodes' upgrades; none of these are documented in `proxmox-upgrade.md`.

1. **Backgrounded `systemctl reboot &` gets SIGHUP-killed when the SSH session closes.** The reboot command must run in the foreground of the SSH session — backgrounding it and disconnecting kills the reboot before it completes on some configurations. Run `ssh <host> systemctl reboot` and let the connection close naturally (the reboot itself severs it), rather than `ssh <host> 'systemctl reboot &'`.

2. **Poll reboot completion by the NEW KERNEL over SSH, not by `ping`.** `ping` succeeds as soon as the NIC is up, which can be well before `sshd` and the new kernel are actually ready — a ping-based poll loop reports "back up" prematurely. Instead, poll SSH itself and check the kernel version changed:

   ```bash
   until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no <host> 'uname -r' 2>/dev/null | grep -q '<new-kernel-version>'; do
     sleep 5
   done
   ```

   A refused SSH connection during the reboot window fails fast (good) rather than hanging like a dropped ping does — but a naive loop that doesn't handle the refused-connection case as "not ready yet, keep polling" will spin or exit early. Handle both the connection-refused and connection-timeout cases as "still rebooting."

3. **First boot after a major upgrade is slow — ~2-3 minutes observed.** Both nodes took noticeably longer than a normal reboot to become SSH-reachable after the Trixie kernel first boot (filesystem/service migration work happens on first boot). Do not treat 2-3 minutes of unreachability as a failure signal; only escalate past ~5 minutes.

4. **zsh does not word-split unquoted variables — inline SSH options, never stuff them in a `$VAR`.** A pattern like `OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"; ssh $OPTS host cmd` silently fails under zsh (the whole `$OPTS` value is passed as one argument, not split into separate `-o` flags) even though it works under bash. Inline the options directly in the `ssh` invocation instead of building them in a variable first.

## After the upgrade

Verify per-node with the API-tier `preflight`/`version` subcommands (`~/github/infra/scripts/proxmox.nu`) cross-checked against the pre-upgrade baseline, then confirm the estate-services versions (PDM 1.1, PBS 4.x) match what's documented in `estate-services.md` before deploying either.
