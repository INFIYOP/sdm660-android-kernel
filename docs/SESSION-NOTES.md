# Session notes — 2026-11-22

Everything done in the session that produced `v7.2.3-sdm660-r1`, in order, with the
reasoning and the dead ends. Written so a future session does not have to rediscover it.

---

## 0. Starting point

`mainline-port-kit-v3.zip` (73 KB) was dropped into the workspace. It contained:

- Docs: `README`, `PLAN`, `PORTING`, `FINDINGS`, `FEATURE_MATRIX`, `JOURNAL`
- Scripts: `00-backup-partitions.sh`, `01-pmos-bringup.sh`, `02-build-kernel.sh`
- Patches: `0001-netfilter-add-xt_quota2.patch`, `0002-misc-add-uid_sys_stats.patch`,
  `0003-fs-add-fsync-counter-to-task_io_accounting.patch`
- Config: `sdm660_android_defconfig`, `android-base-6.12.config`, `android-mainline.fragment`
- Prebuilt DTBs: `sdm636-xiaomi-tulip.dtb`, `-whyred-tianma.dtb`, `-whyred-shenchao.dtb`
- CI: `build-kernel.yml`

The kit's own `JOURNAL.md` said a full `Image` build had **not** been run ("1-core
sandbox"), and that the DTBs and config merge were the only verified artifacts.

## 1. Environment

| Item | Value |
|---|---|
| CPU | 4 cores |
| RAM | 15 GiB |
| Disk | 55 GiB free on `/`, 25 GiB on `/workspace` |
| Network | GitHub reachable, fast (~2.1 GB clone in 22 s) |
| Missing at start | `aarch64-linux-gnu-gcc`, `flex`, `bison`, `bc`, `dtc`, `libssl-dev`, `libelf-dev` |

Installed:

```bash
sudo apt-get install -y gcc-aarch64-linux-gnu flex bison bc libssl-dev libelf-dev \
                        device-tree-compiler
```

Added later, because the build failed without them:

```bash
sudo apt-get install -y zstd kmod
```

`unzip` is not present in this image; Python's `zipfile` was used instead.

## 2. Source

```bash
git clone --depth 1 --branch qcom-sdm660-7.2.y \
  https://github.com/sdm660-mainline/linux.git linux
```

- Commit: `5690ded6161e97967f9a5c23cc22a93e022c3c62` (`wifi: ath10k: don't reset TxBF on disassociation`)
- `Makefile`: `VERSION=7 PATCHLEVEL=2 SUBLEVEL=3`
- 2.1 GB checkout, 94,931 files

The commit matched the one recorded in the kit's `FINDINGS.md` (`5690ded61`), so the kit
was built from this exact tree.

## 3. Patches

Applied in order with `git apply --check` first, then `git apply`:

| Patch | Result |
|---|---|
| `0001-netfilter-add-xt_quota2.patch` | applied |
| `0002-misc-add-uid_sys_stats.patch` | applied |
| `0003-fs-add-fsync-counter-to-task_io_accounting.patch` | applied |

`git diff --stat` after all three:

```
 drivers/misc/Kconfig                   |  9 +++++++++
 drivers/misc/Makefile                  |  1 +
 fs/sync.c                              |  2 ++
 include/linux/task_io_accounting.h     |  2 ++
 include/linux/task_io_accounting_ops.h | 10 ++++++++++
 net/netfilter/Kconfig                  | 20 ++++++++++++++++++++
 net/netfilter/Makefile                 |  1 +
 7 files changed, 45 insertions(+)
```

No fuzz, no rejects. This confirms `PORTING.md`'s claim that the 4.19 sources were
properly adapted to 7.2 APIs (`proc_ops`, `pde_data`, `strscpy`, `for_each_process_thread`,
`sched_process_exit` tracepoint).

## 4. Config

```bash
cp sdm660_android_defconfig arch/arm64/configs/
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- sdm660_android_defconfig
```

Note the kit's `02-build-kernel.sh` merges the fragment in advance and ships the result
as `sdm660_android_defconfig`; the `android-base-6.12.config` and
`android-mainline.fragment` files are the inputs that produced it, not something you
merge at build time.

Then verified all 36 fragment options individually. Every one is `=y`:

```
ANDROID_BINDER_IPC, ANDROID_BINDERFS, PSI, DMABUF_HEAPS(+_SYSTEM,_CMA),
USB_CONFIGFS(+_F_FS), DRM_MSM, DRM_PANEL_SIMPLE, DRM_PANEL_NOVATEK_NT36672A,
F2FS_FS, EROFS_FS, FUSE_FS, BPF_SYSCALL, CGROUP_BPF,
NETFILTER_XTABLES, NF_CONNTRACK, NF_NAT, IP_NF_IPTABLES, IP6_NF_IPTABLES,
IP_NF_IPTABLES_LEGACY, IP6_NF_IPTABLES_LEGACY,
QCOM_AOSS_QMP, QCOM_OCMEM, QCOM_LLCC, QCOM_COMMAND_DB,
NETFILTER_XT_MATCH_QUOTA2(+_LOG), UID_SYS_STATS,
CRYPTO_ADIANTUM, CRYPTO_HCTR2, CRYPTO_XTS, CRYPTO_CTS
```

Also checked the alternatives the kit relies on: `FS_ENCRYPTION=y`, `MEMFD_CREATE=y`.

The three documented gotchas all held:

1. 7.x moved iptables behind `*_LEGACY` — without them the `=y` netfilter options are
   silently dropped.
2. `DRM_MSM` needs `QCOM_AOSS_QMP`, `QCOM_OCMEM`, `QCOM_LLCC`, `QCOM_COMMAND_DB` all
   `=y`; the stock defconfig had `LLCC=m`, which capped `DRM_MSM` at `=m`.
3. Netfilter parents must be `=y` or Android's `=y` options get demoted to `=m`.

## 5. Build

```bash
make -j4 Image.gz qcom/sdm636-xiaomi-tulip.dtb \
                  qcom/sdm636-xiaomi-whyred-tianma.dtb \
                  qcom/sdm636-xiaomi-whyred-shenchao.dtb
```

~25 minutes. Finished with:

```
OBJCOPY arch/arm64/boot/Image
GZIP    arch/arm64/boot/Image.gz
```

Verified:

- `Image` 33,423,872 bytes; `Image.gz` 13,443,377 bytes
- `ARMd` magic at offset 0x38; `image_size` = 0x2070000
- `PE header offset` (`res5`) = 0x40, as expected
- DTBs: 58,610 / 56,786 / 56,786 — **identical to the kit's prebuilt sizes**
- 0 `error:`, 0 `warning:`

The DTB match is the interesting result: it independently confirms the kit's DTBs were
produced from this tree with this toolchain, i.e. the kit is internally consistent.

## 6. Modules — where the kit broke

`grep -c '=m$' .config` → **532**. Including things that matter:

```
CONFIG_QCOM_IPA=m              # modem data path
CONFIG_QCOM_FASTRPC=m          # modem / sensors RPC
CONFIG_ARM_QCOM_CPUFREQ_HW=m   # cpufreq
CONFIG_QRTR(_SMD,_TUN)=m       # IPC router for the modem
CONFIG_ATH10K_SNOC=m           # WCN3990 Wi-Fi
CONFIG_QCOM_Q6V5_PAS=m         # remoteproc loader
```

But `build-kernel.yml` builds and uploads only `Image.gz` + DTBs. So CI artifacts would
have been unusable from Phase 3 onward. Fixed in this release.

Second break: `make modules_install` died with

```
make[2]: *** [.../sm4-ce-cipher.ko.zst] Error 127
```

Error 127 = command not found = `zstd`. The config sets `CONFIG_MODULE_COMPRESS_ZSTD`,
so modules are installed as `.ko.zst` and the kernel Makefile shells out to `zstd`.
Installing `zstd` fixed it; `kmod` was then needed for `depmod`.

After the fix:

```bash
make -j4 modules                                   # 688 .ko
make INSTALL_MOD_PATH=out/modules modules_install   # 688 installed, 175 MB
depmod -b out/modules 7.2.3-sdm660+                 # modules.dep + .bin
```

Vermagic check on `ipa.ko.zst`:

```
vermagic: 7.2.3-sdm660+ SMP preempt mod_unload modversions aarch64
```

## 7. What could not be done

**`boot.img`.** `02-build-kernel.sh` requires `PAGESIZE`, `BASE`, `KERNEL_OFFSET` and
`CMDLINE` and fails loudly if unset:

```bash
: "${PAGESIZE:?set PAGESIZE from stock boot.img}" ...
```

That is the right behaviour. These values are device- and ROM-specific; guessing them
produces a boot image that silently does nothing. They come from the user's own
`boot.img`:

```bash
unpackbootimg -i backup-*/boot.img -o stock/
```

**Hardware test.** Not possible here; no device attached, and the kit's Phase 0 gate is
a postmarketOS boot first anyway.

## 8. Decisions

- **Built `Image.gz` + DTBs + modules**, not just the Image. Modules are half the
  deliverable for an Android kernel.
- **Fixed the workflow instead of shipping it broken.** Two one-line-ish changes, both
  documented in the release notes.
- **Did not invent boot.img parameters.** Left the build step gated.
- **Did not commit build outputs to git** except the small prebuilt DTBs the kit already
  shipped; `Image.gz` and `modules.tar` are release assets, not repo files.
- **Left `CONFIG_MODULE_COMPRESS_ZSTD` alone.** Turning compression off would have made
  the CI simpler but changed the shipped config; adding `zstd` is the smaller fix.

## 9. Gotchas for the next session

- `ARCH=arm64`, not `aarch64`. `CROSS_COMPILE=aarch64-linux-gnu-` is correct.
- `unzip` is absent; use `python3 -c "import zipfile; ..."`.
- `xxd` is absent; use `od -An -tx1`.
- The kernel Makefile needs `zstd` **and** `kmod` for `modules_install` here.
- `make qcom/<board>.dtb` from the kernel root works; no need for `make dtbs`.
- A full build is ~25 min on 4 cores; modules ~12 min. Run them in the background and
  poll the log rather than blocking on a single long command.
- `/tmp` may be cleared between sessions — re-extract the kit if needed.
- The kit's `02-build-kernel.sh` assumes `KDIR=linux` in the current directory and
  patches from `../000*.patch`; the repo layout now puts them in `patches/`.

## 10. Where things live

| Thing | Path |
|---|---|
| Kernel tree (built) | `/workspace/kbuild/linux` |
| Build outputs | `/workspace/kbuild/out` |
| This repo checkout | `/workspace/kbuild/repo` |
| Original kit zip | `/workspace/project/Bookfolio/mainline-port-kit-v3.zip` |
