# Verifying KVM and nested virtualization for kata-on-kind

Checklist for confirming the Linux host can actually run Kata before sinking time into kata-deploy.

## `/dev/kvm` exists and is accessible

```bash
ls -l /dev/kvm
# crw-rw---- 1 root kvm 10, 232 ... /dev/kvm
```

If missing: kernel doesn't have KVM. Check `/boot/config-$(uname -r) | grep CONFIG_KVM` for the relevant flags. On most distros, install `qemu-kvm`:

```bash
sudo apt-get install -y qemu-kvm
```

## User is in the `kvm` group

```bash
groups $USER | grep -q kvm && echo "OK" || echo "NEEDS ADD"

# If needed:
sudo usermod -aG kvm $USER
# Log out and back in for the group to take effect.
```

Without this, `kind create cluster` runs as $USER but the node container can't open `/dev/kvm` even with `extraMounts`.

## Nested virt enabled (when host is itself a VM)

If you're running on a cloud VM or a hypervisor (KVM-on-KVM), nested virt must be enabled.

```bash
# Intel
cat /sys/module/kvm_intel/parameters/nested
# Expect Y or 1

# AMD
cat /sys/module/kvm_amd/parameters/nested
# Expect 1
```

If `N` / `0`, the host hypervisor needs to enable nested virt on the VM. On GCE: `--enable-nested-virtualization` at instance creation. On EC2: bare-metal instance types (`*.metal`) or recent `i3en.*`. On a desktop Linux running KVM directly, set the module parameter:

```bash
sudo modprobe -r kvm_intel
sudo modprobe kvm_intel nested=1
# Persist via /etc/modprobe.d/kvm.conf
```

## CPU supports virtualization

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
# > 0 means YES (vmx = Intel, svm = AMD)
```

If 0, the CPU itself doesn't support hardware virt. Kata won't run without an emulated fallback that defeats the point of microVM isolation.

## kvm-ok (Ubuntu/Debian)

```bash
sudo apt-get install -y cpu-checker
sudo kvm-ok
# "KVM acceleration can be used" is the green light.
```

## Quick QEMU bare-metal test

Before involving kind + Kata, confirm raw KVM works:

```bash
qemu-system-x86_64 -enable-kvm -nographic -m 256 -kernel /boot/vmlinuz-$(uname -r) -append "console=ttyS0" -serial mon:stdio
```

If this boots a kernel message stream, KVM is functional and kata-deploy will succeed. If it errors with "Could not access KVM kernel module", revisit the steps above before continuing.

## kind node container can see `/dev/kvm`

After the cluster is up:

```bash
docker exec -it kata-control-plane ls -l /dev/kvm
```

If `/dev/kvm` is missing inside the node container, the `extraMounts` block in the kind config was missed or the cluster predates this skill's recipe — recreate with the config from the SKILL.md.
