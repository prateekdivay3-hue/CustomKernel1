# Kernel-tree quirks — KernelSU-Next + SUSFS integration

Notes about how the vendored driver in `drivers/kernelsu/` interacts with *this*
kernel tree. See `UPSTREAM.md` for provenance and the list of local deviations
inside the driver.

## Configuration

* `CONFIG_KSU=y` (built-in, not `m`) — the driver's `KSU_SUSFS` option depends
  on `KSU != m`, and so does the vendored-build path.
* `CONFIG_KSU_MANUAL_HOOK=y` — the only hook mode that works on 4.14.
* `CONFIG_KSU_KPROBES_HOOK` / `CONFIG_KSU_SYSCALL_TABLE_HOOK` are explicitly
  disabled. The syscall-table mode is not merely untested here: it `#error`s
  below 4.17.
* `CONFIG_KPROBES` stays off, so `KSU_MANUAL_HOOK`'s `default y if !KPROBES`
  picks the right mode automatically.
* SUSFS is enabled as a *feature*, independent of the hook mode:
  `CONFIG_KSU_SUSFS` plus the ten `CONFIG_KSU_SUSFS_*` switches. The kernel-side
  implementation is `fs/susfs.c` (v2.3.0) with `include/linux/susfs.h` and
  `include/linux/susfs_def.h`.

## Kernel-core hooks (already present, unchanged by the swap)

| file | hook |
|---|---|
| `fs/exec.c` | `ksu_handle_execveat` |
| `fs/open.c` | `ksu_handle_faccessat` |
| `fs/stat.c` | `ksu_handle_stat` (three call sites) |
| `fs/stat.c` | `ksu_handle_newfstat_ret`, `ksu_handle_fstat64_ret` |
| `kernel/reboot.c` | `ksu_handle_sys_reboot` |
| `fs/stat.c` | `__ksu_is_allow_uid_for_current` (SUSFS branch) |

`fs/stat.c` carries two declarations of `ksu_handle_stat`; the
`struct filename **` one is inside `#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 1, 0)`
and is not compiled here, so the driver's `const char __user **` signature is
the one that links.

`ksu_handle_fstat64_ret` is compiled because arm64 defines
`__ARCH_WANT_COMPAT_STAT64`.

## SUSFS specifics

* TIF flags: `TIF_PROC_UMOUNTED` 33, `TIF_PROC_NO_SU` 34,
  `TIF_PROC_UMOUNTED_FOR_ZYGOTE_NEXT` 35 — all free in
  `arch/arm64/include/asm/thread_info.h` and defined in
  `include/linux/susfs_def.h`.
  The driver itself uses 61/62/63 for its own TIFs, so there is no overlap.
* Only `susfs_is_current_proc_umounted()` is actually read by `fs/susfs.c`
  (plus `susfs_is_current_proc_umounted_app()`, which is derived from it), so
  `TIF_PROC_NO_SU` / `TIF_PROC_UMOUNTED_FOR_ZYGOTE_NEXT` are defined but not
  consumed. That matches the reference KSUN+SUSFS integration, which does not
  touch `hook/setuid_hook.c` at all.
* The driver does **not** keep its own SUSFS SID variables. `susfs_*_domain()`
  reuse the driver's `cached_*_sid` values populated by `cache_sid()`, so no
  extra SID bookkeeping is needed.
* `fs/susfs.c` defines `ksu_init_rc_hook` as an alias of its own static key;
  the driver therefore uses `ksu_is_init_rc_hook_enabled` when SUSFS is on.
  See `UPSTREAM.md` §5.

## Things that are intentionally absent

* No `CONFIG_KPM` / KPM support. KernelSU-Next dropped it upstream (command ids
  102/200 are marked deprecated) and it was never wanted here.
* No build-time `sed` patching of the kernel tree (see `UPSTREAM.md` §2). If a
  future kernel bump removes `path_umount()`, `selinux_inode()` or friends,
  they have to be added to the tree explicitly rather than by the Kbuild.
* No `CONFIG_KSU_SUSFS_TRY_UMOUNT`: that command (`0x55580`) is deprecated in
  SUSFS v2.x and `fs/susfs.c` does not implement it.

## Verifying a change

The build is the only real test; the CI workflow asserts the config block, the
driver object files and the `vmlinux` symbols listed in
`.github/workflows/build-miatoll.yml`. When adding a new SUSFS command, add it
in three places: `include/linux/susfs_def.h` (number), `fs/susfs.c` (handler)
and `drivers/kernelsu/supercall/dispatch.c` (dispatch).
