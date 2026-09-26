# SUSFS provenance and compatibility

- Upstream project: https://gitlab.com/simonpunk/susfs4ksu
- Linux branch: `kernel-4.14`
- Implementation in this tree: **SUSFS v2.3.0**, variant `NON-GKI`
  (see `SUSFS_VERSION` / `SUSFS_VARIANT` in `include/linux/susfs.h`)
- Original import was based on the 4.14 patch of the
  [Star-Seven/susfs4ksu mirror](https://github.com/Star-Seven/susfs4ksu), then
  upgraded to the v2.x kernel-side API. The v2.x userspace ABI passes
  `void __user **user_info` to every command handler, which is what
  `drivers/kernelsu/supercall/dispatch.c` calls.

## What is actually implemented

Compiled with `CONFIG_KSU_SUSFS` plus:

| Feature | Config | Kernel-side entry point |
|---|---|---|
| sus_path (+ looped variant) | `CONFIG_KSU_SUSFS_SUS_PATH` | `susfs_add_sus_path()`, `susfs_add_sus_path_loop()` |
| sus_mount | `CONFIG_KSU_SUSFS_SUS_MOUNT` | `susfs_set_hide_sus_mnts_for_non_su_procs()` |
| sus_kstat (static + dynamic) | `CONFIG_KSU_SUSFS_SUS_KSTAT` | `susfs_add_sus_kstat()`, `susfs_update_sus_kstat()` |
| uname spoofing | `CONFIG_KSU_SUSFS_SPOOF_UNAME` | `susfs_set_uname()` |
| cmdline / bootconfig spoofing | `CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG` | `susfs_set_cmdline_or_bootconfig()` |
| open_redirect | `CONFIG_KSU_SUSFS_OPEN_REDIRECT` | `susfs_add_open_redirect()` |
| sus_map | `CONFIG_KSU_SUSFS_SUS_MAP` | `susfs_add_sus_map()` |
| AVC log spoofing | always on when SUSFS is on | `susfs_set_avc_log_spoofing()` (wired into `security/selinux/avc.c`) |
| symbol hiding | `CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS` | kallsyms filter |
| logging | `CONFIG_KSU_SUSFS_ENABLE_LOG` | `susfs_enable_log()` |
| version / feature report | always on | `susfs_show_version()`, `susfs_get_enabled_features()` |

SELinux context hiding is **not** a SUSFS feature — it is the KernelSU-side
`selinux_hide` feature. See `drivers/kernelsu/UPSTREAM.md`.

## Compatibility with the integrated root solution

- Integrated against **KernelSU-Next v3.4.0-legacy** (manual hook mode). The susfs
  command handlers are dispatched by `ksu_handle_susfs_cmd()` in
  `drivers/kernelsu/supercall/dispatch.c`, reached from
  `ksu_handle_sys_reboot()` when `magic2 == SUSFS_MAGIC`, and match the v2.x ABI
  one-to-one.
- KernelSU-Next dropped SUSFS upstream (`kernel: purge SuSFS remnants`), so the
  driver side is a local re-addition; `drivers/kernelsu/UPSTREAM.md` §4 lists
  exactly which files carry it.
- The driver additionally expects these per-task helpers from susfs, provided as
  static inlines in `include/linux/susfs_def.h`:
  `susfs_is/set_current_proc_no_su()`, `susfs_is/set/clear_current_proc_umounted()`,
  `susfs_is/set/clear_current_proc_umounted_for_zygote_next()`
  (backed by `TIF_PROC_NO_SU` / `TIF_PROC_UMOUNTED_FOR_ZYGOTE_NEXT`).
  Only `susfs_is_current_proc_umounted()` is currently read by `fs/susfs.c`; the
  flag is set on the umount path in `drivers/kernelsu/feature/kernel_umount.c`.
- The KSU driver in turn provides `ksu_cred`, `setup_selinux()` and
  `susfs_is_current_ksu_domain()` for the susfs kernel side, plus
  `susfs_start_sdcard_monitor_fn()` on boot-completed.

Because this is SUSFS v2.3.0 (not the v1.5.x that BRENE's README calls out), BRENE's
SUSFS-version gate is satisfied; the earlier warning in this file claiming otherwise
described the original v1.5.5 import and no longer applies.
