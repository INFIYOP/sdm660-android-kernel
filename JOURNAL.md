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
