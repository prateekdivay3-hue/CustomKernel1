# Upstream provenance — `drivers/kernelsu`

## What this is

KernelSU-Next **v3.4.0-legacy**, vendored from
<https://github.com/KernelSU-Next/KernelSU-Next>.

| | |
|---|---|
| tag | `v3.4.0-legacy` |
| commit | `8af3d4fec33be32fa5d3f8dae4f380fac45bf2cd` |
| branch | `legacy` |
| imported from | `kernel/` (the whole driver tree, minus build helpers) |
| licence | GPL-2.0 (`LICENSE` is upstream's, unmodified) |
| driver version | `33294` = `30000 + 3005 (commits) + 289`, matching the v3.4.0 manager `versionCode` |

### Why the `-legacy` tag and not plain `v3.4.0`

`v3.4.0` (and `v3.3.0`) are **GKI-only**. Their `Kconfig` gates `KSU` on
`KPROBES && EXT4_FS`, they ship no manual-hook mode at all, and the oldest
kernel version referenced anywhere in their sources is **5.9**. Their releases
only contain prebuilt `.ko` modules for 5.10 – 6.18.

Non-GKI support lives on the separate `legacy` branch, which is tagged
`v3.0.1-legacy`, `v3.1.0-legacy`, `v3.2.0-legacy`, `v3.4.0-legacy` (there is no
`v3.3.0-legacy`). The legacy line carries the compat layer for old kernels
(version gates down to 3.16/3.18, an explicit `LINUX_VERSION_CODE < 4.17`
"native syscall ABI" branch in `include/util.h`) and three hook modes:

| mode | config | usable on this 4.14 tree? |
|---|---|---|
| manual hooks | `CONFIG_KSU_MANUAL_HOOK` | **yes** — this is what we use |
| kprobes/tracepoints | `CONFIG_KSU_KPROBES_HOOK` | no (GKI 5.10+ only) |
| syscall table patching | `CONFIG_KSU_SYSCALL_TABLE_HOOK` | **no** — `hook/syscall_table_hook.c` `#error`s below 4.17 because the `__arm64_sys_*` pt_regs ABI does not exist |

`KSU_MANUAL_HOOK` defaults to `y if !KPROBES`, and its only build-time
requirement is a `ksu_handle_sys_reboot` hook in `kernel/reboot.c`, which this
tree has had since the original KernelSU integration.

## Local deviations

Everything below is *ours*, not upstream's. `INTERNAL.md` covers the kernel-tree
side.

### 1. Vendored-build version detection (`Kbuild`)

Upstream derives the reported version from `git rev-list --count HEAD` of the
driver's own repository. A vendored copy has no such repository, so the Kbuild
now reads `.ksu-version` / `.ksu-tag` (shipped next to it) and back-computes the
equivalent commit count, leaving the rest of the upstream logic — including the
`KSU_VERSION_OVERRIDE` / `KSU_VERSION_TAG_OVERRIDE` escape hatches — untouched.

`.ksu-commit` and `.ksu-branch` are informational only (nothing in the build
reads them).

### 2. No build-time patching of the kernel tree

Upstream's Kbuild `sed`-patches the kernel sources for old-kernel gaps. On this
tree **none of them are needed**, because the relevant compatibility already
exists upstream in 4.14.357-openela:

* `fs/namespace.c` already has `can_umount()` and `path_umount()`
* `security/selinux/include/objsec.h` already has `selinux_inode()`,
  `selinux_cred()` and `current_sid()`, and `hooks.c`/`selinuxfs.c`/`xfrm.c`
  already use them
* `security/selinux/include/security.h` already has `struct selinux_state`

The one patch that *would* have fired adds `atomic_t filter_count;` to
`struct seccomp`. That field is only read by `infra/seccomp_cache.c`, which is
compiled out below 5.10, so it was dead weight — and it would have silently
modified the kernel sources on every build. It is removed and the Kbuild no
longer rewrites the tree at all, so the build is reproducible from what is
committed.

### 3. `disable_seccomp()` prototype conflict (`hook/setuid_hook.c`)

Upstream declares

```c
extern void disable_seccomp(struct task_struct *tsk);
```

but the only definition in the driver, `policy/app_profile.c`, is
`void disable_seccomp(void)`. Two prototypes for one symbol is a hard compile
error, and the branch that declares it is exactly the `< 5.10` branch a 4.14
kernel takes. Fixed here by declaring the real `(void)` prototype.

### 4. SUSFS support (re-added)

KernelSU-Next **removed** SUSFS upstream (`kernel: purge SuSFS remnants`), so
`v3.4.0-legacy` has no SUSFS code at all. This tree keeps the full SUSFS v2.3.0
feature set (`fs/susfs.c`), so the driver side is re-added here:

* `Kconfig` — `CONFIG_KSU_SUSFS` plus the ten feature switches. Upstream's
  legacy Kconfig keeps SUSFS as a separate driver *version*; here it is a
  standalone option so it combines with whichever hook mode is selected.
* `supercall/supercall.c` + `supercall/dispatch.c` — `magic2 == SUSFS_MAGIC`
  dispatches to `ksu_handle_susfs_cmd()`, which forwards to `fs/susfs.c`.
* `selinux/selinux.c` — the `susfs_*` SID helpers `fs/susfs.c` calls back into.
* `core/init.c` — `susfs_init()`.
* `runtime/boot_event.c` — `susfs_start_sdcard_monitor_fn()`.
* `feature/kernel_umount.c` — mark the process `TIF_PROC_UMOUNTED` and schedule
  `susfs_extra_works`.

The reference for how KSUN and SUSFS coexist is the same approach used by
KernelSU-Next's own `susfs/legacy` lineage and by crDroid's 4.14.357 sm8150
kernel (which runs KSUN + SUSFS v2.3.0 on the identical base version): the
umount marking is deliberately made independent of `ksu_kernel_umount_enabled`
/`ksu_module_mounted`, otherwise hiding silently breaks when umount is disabled
or no module is mounted.

### 5. `ksu_init_rc_hook` duplicate symbol (`runtime/ksud_integration.c`)

`fs/susfs.c` exports

```c
DEFINE_STATIC_KEY_FALSE(ksu_init_rc_hook_key_false);
extern struct static_key_false ksu_init_rc_hook
        __attribute__((alias("ksu_init_rc_hook_key_false")));
```

while the driver defines `bool ksu_init_rc_hook __read_mostly = true;`. With
SUSFS enabled that is a duplicate symbol at link time, so under
`CONFIG_KSU_SUSFS` the driver uses its own static key
(`ksu_is_init_rc_hook_enabled`) instead and `stop_init_rc_hook()` disables that
key.

## Hook ABI

The driver's signatures match this tree's kernel-core hooks exactly, so no
kernel-core changes were needed for the swap:

| kernel core | driver |
|---|---|
| `fs/exec.c` | `ksu_handle_execveat(int *, struct filename **, void *, void *, int *)` |
| `fs/open.c` | `ksu_handle_faccessat(int *, const char __user **, int *, int *)` |
| `fs/stat.c` | `ksu_handle_stat(int *, const char __user **, int *)` |
| `fs/stat.c` | `ksu_handle_newfstat_ret(unsigned int *, struct stat __user **)` |
| `fs/stat.c` | `ksu_handle_fstat64_ret(unsigned long *, struct stat64 __user **)` |
| `kernel/reboot.c` | `ksu_handle_sys_reboot(int, int, unsigned int, void __user **)` |

`ksu_handle_setresuid()` is reached through the LSM `task_fix_setuid` hook, so
`kernel/sys.c` needs no patch either.
