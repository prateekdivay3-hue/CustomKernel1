# Stormbreaker — curtana (Redmi Note 9 Pro / 9S) · AOSP Android 16 (Infinity X)

Linux 4.14.357-openela · A-only flash

## Features

### Root & control
- **KernelSU-Next v3.4.0-legacy** (KernelSU fork, vendored in `drivers/kernelsu`) — built-in,
  **manual hook mode** (`CONFIG_KSU_MANUAL_HOOK=y`, no kprobes, no daemon, no `/su` binary)
- Hooks are already in the kernel sources (`fs/exec.c`, `fs/open.c`, `fs/stat.c`,
  `kernel/reboot.c`); setuid is picked up through the LSM `task_fix_setuid` hook,
  so `kernel/sys.c` needs no patch either
- KernelSU-Next manager app bundled with the release, version-matched to the kernel
  (driver `KSU_VERSION` 33294 = manager `versionCode` 33294)

### Hiding stack
- **SUSFS v2.3.0** (kernel side in `fs/susfs.c`) — full feature set:
  - sus_path (+ looped variant) — hide configured paths
  - sus_mount — hide configured mounts per app
  - sus_kstat — spoof file metadata
  - uname spoofing
  - cmdline / bootconfig spoofing
  - open_redirect — redirect file opens
  - sus_map — /proc/maps and fdinfo spoofing
  - KSU/SUSFS symbol hiding
  - AVC log spoofing
- **NoMount v2.0.0** — per-app directory hiding via keyring rules
- **SELinux hiding** — provided by the KernelSU-Next driver's own `selinux_hide`
  feature (`drivers/kernelsu/feature/selinux_hide.c`), which patches the SELinux
  userspace interfaces at runtime. This is a KernelSU-side feature, **not** part
  of SUSFS.
- **BRENE v0.0.68** module bundled — SUSFS rules control panel

### Networking
- **TCP BBR** congestion control — compiled in and set as the system default (CUBIC still available)
- BPF / eBPF support (syscall + JIT)

### Filesystems & compatibility
- EROFS support
- NTFS support
- F2FS with compression (LZO / LZ4 / ZSTD) + encryption + security labels
- Loadable module support with SHA512 signature verification (unsigned modules load with taint)
- Ships kernel + dtb + dtbo; preserves your ROM's ramdisk and existing root setup

## Assets

| File | What it is | |
|---|---|---|
| `Stormbreaker-miatoll-*.zip` | Flashable AnyKernel3 zip (kernel + dtb + dtbo) | |
| `KernelSU-Next-manager.apk` | KernelSU-Next manager v3.4.0 — install **after** flashing + booting | |
| `BRENE-v0.0.68.zip` | SUSFS rules module — install inside the KernelSU-Next manager, then reboot | |
| `NoMount-v2.0.0.zip` | NoMount module — install inside the KernelSU-Next manager, then reboot | |

## Install

1. Flash the zip.
2. Boot the ROM.
3. Install `KernelSU-Next-manager.apk`.
4. In the manager: install the BRENE and NoMount modules, then reboot.

## Toolchain note

CI builds with **Clang 18 only** — the LLVM that ships on the Ubuntu 24.04 runner
(`LLVM=1 LLVM_IAS=1`, `CROSS_COMPILE=aarch64-linux-gnu-`), and the workflow
asserts the compiler major version so a runner-image change fails the build
instead of silently switching toolchains. The local `build.sh` fetches the
crdroid clang prebuilts and is not part of CI.
