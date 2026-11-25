# Journal (append newest at the bottom; a new chat should read this first)

## Project state
- Target devices: tulip (Redmi Note 6 Pro) first, whyred (Redmi Note 5 Pro) second
- Kernel base: github.com/sdm660-mainline/linux, branch qcom-sdm660-7.2.y
- Current phase: 1-2 (config + DTB verified; no hardware test yet)
- Repo: https://github.com/INFIYOP/sdm660-android-kernel (GitHub connector was read-only; kit uploaded manually)

## Decisions
- D001: Mainline port only, no backport of downstream 4.19.
- D002: Android userspace is generic/open (Mesa, minigbm, drm_hwcomposer); reuse only firmware blobs.
- D003: Vulkan work is DROPPED (2026-11-22). Adreno 509 is a5xx: 32-bit GPU VA blocks Vulkan 1.2
  (bufferDeviceAddress), DP4A and subgroup-size control block 1.3, tile local read blocks 1.4, and the
  SPIR-V->a5xx compiler (libllvm-glnext) is closed. Mesa turnip is a6xx+. No path to >1.1 exists, so
  effort goes to the mainline Android bring-up instead. Freedreno OpenGL is the graphics path.

## Log
- (date): Research done, plan written, Phase 0 kit created.
- 2026-11-22: Cloned sdm660-mainline/linux qcom-sdm660-7.2.y (Linux 7.2.3). tulip + whyred dts already exist. Built tulip/whyred DTBs cleanly. Created sdm660_android_defconfig by merging sdm660_defconfig + AOSP android-base (6.12) + fragment; fixed 3 config gotchas (see FINDINGS.md). Full Image build NOT run (1-core sandbox); added build-kernel.yml for GitHub Actions. Boot image params left to be read from the user's stock boot.img. Next: run 00-backup-partitions.sh, push repo + workflow, get CI Image, `fastboot boot` test on tulip.
- 2026-11-22 (later): Handled Android-required features missing from mainline 7.2 (see PORTING.md). Ported xt_quota2 (+LOG) and uid_sys_stats from the 4.19 tree; wrote fsync counter for task_io_accounting. All three compile cleanly against 7.2.3 and apply cleanly to a clean checkout (patches 0001-0003). Alternatives: ashmem->memfd, cpufreq_times->eBPF, dm-default-key->plain FBE. Workflow and build script now apply the patches. Still NOT built as a full Image, NOT run on hardware. Next: CI build, backups, fastboot boot test.
- 2026-11-22 (build session): Full Image + modules build done for the first time, on a 4-core box.
  Installed gcc-aarch64-linux-gnu/flex/bison/bc/libssl-dev/libelf-dev/dtc, then zstd+kmod (needed
  for modules_install: CONFIG_MODULE_COMPRESS_ZSTD). Cloned qcom-sdm660-7.2.y @ 5690ded61 (7.2.3).
  Patches 0001-0003 applied cleanly (45 insertions / 7 files). All 36 fragment options verified =y.
  Image.gz 13,443,377 bytes; DTBs 58610 / 56786 / 56786 (identical to the kit's prebuilt ones);
  688 modules, vermagic "7.2.3-sdm660+ SMP preempt mod_unload modversions aarch64". 0 errors, 0 warnings.
  Found and fixed two kit bugs: build-kernel.yml built/uploaded no modules although 532 options are =m
  (ipa, fastrpc, cpufreq-hw, qrtr, ath10k_snoc, q6v5_pas), and its apt list was missing zstd+kmod.
  Released as v7.2.3-sdm660-r1. STILL NOT BOOTED. boot.img still blocked on stock boot.img params.

## 2026-11-23 - Android tree, module split, release review
- Release v7.2.3-sdm660-r1 reviewed: SHA256SUMS fetched; DTB from the release is byte-identical to the one built here.
- Boot-critical drivers (eMMC, USB, display, panel, clocks, pinctrl) are built in, so the ramdisk needs no modules.
- Needed modules (enabled DT nodes via of: aliases + modules.dep): tulip 78, whyred 68. Too big for the 64 MB boot partition,
  so all go to /vendor/lib/modules and are loaded by init.modules.rc (modprobe).
- Every enabled tulip/whyred DT node has a driver (built-in or module); leftovers are child nodes of other drivers.
- whyred mainline dts enables no sound card/codec: audio on whyred needs new dts work; tulip has it.
- Mainline tulip/whyred DTBs have no qcom,msm-id/board-id, so LK may reject an appended-DTB boot image. BLOCKED on stock boot.img.
- Android device tree source added at android/device/generic/sdm660 (derived from aospm/android_device_generic_sdm845). Source only, never built.
- Added scripts/stage-firmware.sh + docs/FIRMWARE.md, and shared/bin/start_remoteprocs.sh.
- Compile agent (OpenHands) ran docs/OPENHANDS_TASKS.md: merge done; bash -n 7/7; py_compile 4/4; shellcheck 0 errors
  (1 mksh false positive + notes); fetch-prebuilt-kernel.sh 5/5 sha256, 83 modules, 181,681,771 B uncompressed;
  select-modules re-run identical for tulip and docs/dt-coverage (whyred same 68 names, order only);
  CI guard for modules.all added and tested both ways; checkpatch 0001 2E/12W, 0002 0E/6W, 0003 clean;
  make W=1 0 compile diagnostics, 16 kernel-doc warnings in xt_quota2.c; tests/test-stage-firmware.sh added, PASS, in CI.
  Details: docs/COMPILE-AGENT-REPORT.md. Nothing booted; AOSP build not attempted.

## 2026-11-23 - v7: bootloader ids, test boot images
- User's stock boot.img parsed (36,368,384 B, 52 DTBs). E7T = tulip: msm-id 0x159 0x00, board-id 0x40008 0x00.
  E7S = whyred: board-id 0x30008 0x00 0x10008 0x00. pmic-id copied verbatim. E7T/E7S mapping is an
  inference from Xiaomi model numbers - verify with getprop ro.product.model.
- Patch 0004 applied cleanly; DTBs rebuilt (tulip 58,733, whyred 56,933) and each reports the stock ids.
- Added scripts/make-bootimg.sh + boot-tulip-test.img / boot-whyred-test.img (header v0, page 4096,
  kernel 0x8000, ramdisk 0x1000000). Ramdisk is a minimal static init, NOT postmarketOS: it only proves
  LK accepted the DTB and the kernel reached userspace.
- Fixed kernel-doc in patch 0001 (16 warnings -> 0) and regenerated the patch; code sections of
  xt_quota2.o identical, only .debug_info +2 B, so Image.gz is unchanged and shipped unchanged.
- Added a dependency preflight to fetch-prebuilt-kernel.sh (fails before downloading).
- CI builds both boot images and checksums them.

## 2026-11-24 - v9: Neutron Clang build
- Neutron tag 06092026 / clang 24.0.0git via antman. Build with LLVM=1 in a fresh clone
  (/workspace/kbuild/linux-clang) so the GCC tree stayed intact.
- CC_IS_CLANG=y, LD_IS_LLD=y, AS_IS_LLVM=y, SHADOW_CALL_STACK=y, LTO_NONE=y.
- 0 warnings, 0 errors; W=1 on xt_quota2/uid_sys_stats/fs/sync also 0.
- Image.gz 13,240,624 B (GCC 13,443,377). 688 modules; select-modules output identical
  to the committed modules.all (78 tulip, 68 whyred).
- Both boot images PASS verify-bootimg.py with the stock msm-id/board-id.
- v9 archive referenced scripts/verify-bootimg.py but did not ship it; wrote it (pure
  Python FDT parse, no dtc dependency).
- Neutron installer needs zstd and bsdtar on the host; kernel build needs flex/bison/bc.

## 2026-11-25 - v10: pstore-readable first-boot test
- Patch 0005: tulip ramoops moved to the stock layout (0xa0000000, 4 MB, console 2 MB,
  pmsg 2 MB, no dmesg records) so a 4.19 kernel can read the mainline log after a warm
  reboot. whyred already had this layout; its DTBs hash identically to v9.
- Test init rewritten: mkdir+mount /dev /proc /sys first (the old one mounted into
  non-existent dirs, so /dev/console never opened), log to kmsg+console+tty0, print
  /proc/version and /proc/cmdline, 60 s countdown, warm restart (POWER_OFF_AT_END to opt out).
- make-bootimg.sh default cmdline adds ignore_loglevel panic=5.
- Added docs/FIRST_BOOT_TEST.md.
- Build: Neutron Clang 06092026 (clang 24.0.0git), LLVM=1, fresh clone, patches 0001-0005.
  0 warnings/0 errors, Image.gz 13,240,704 B, 688 modules, tulip DTB f9e2fe80 (changed),
  whyred DTBs identical to v9. Both boot images PASS verify-bootimg.py.
- CI: build-kernel 45538355221 (GCC) and build-kernel-neutron 45538359182 (clang, success).
- Published v10-testing as a pre-release.
