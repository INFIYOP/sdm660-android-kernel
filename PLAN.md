# Plan

**Out of scope: Vulkan.** The a5xx GPU cannot exceed Vulkan 1.1 (see D003 in
JOURNAL.md). Do not spend time on driver ports, version spoofs or vendor blob swaps;
the graphics path is freedreno OpenGL via Mesa.

## Phase 0 - Setup  (gate: pmOS mainline kernel boots on tulip, ssh works)
- Back up partitions (00-backup-partitions.sh): persist, modemst1/2, fsg, modem, dsp, bluetooth, boot, recovery.
- Use `fastboot boot` for test kernels; never overwrite the working boot partition.
- Bring up via postmarketOS (01-pmos-bringup.sh). No UART: use USB networking, pstore/ramoops, simpledrm.
- Extract firmware (modem, adsp, wifi/bt, venus, gpu zap) from the backups.

## Phase 1 - Baseline mainline  (gate: every item in FEATURE_MATRIX has a status)
- Fork sdm660-mainline/linux @ qcom-sdm660-7.2.y; confirm sdm636-xiaomi-tulip dts builds and boots.
- Keep changes as a small patch queue on top of that branch (cheap rebases).
- Add whyred via a shared sdm636 xiaomi common dtsi.

## Phase 2 - Android kernel  (gate: Android first-stage init runs, adb works)
- Merge AOSP's kernel/configs android-base.config (+ android-recommended) with our fragment.
- Needs: binderfs, PSI + lmkd, dma-buf heaps (not ION), memfd (not ashmem), cgroups, f2fs/ext4/erofs, FUSE, eBPF, USB configfs + FunctionFS.
- Boot image: verify header version, DTB placement, and whether the device is A-only or A/B.
- CI: build boot.img on every commit.

## Phase 3 - Android userspace  (gate: lockscreen with touch + GPU)
- AOSP/LineageOS base with own device tree. Mesa freedreno (a5xx), minigbm_msm, drm_hwcomposer, generic audio/wifi/bt/sensor/gnss HALs.
- Build system + vendor yourself; reuse only firmware.

## Phase 4 - Features, priority order
Wi-Fi, Bluetooth, charging -> audio -> modem (IPA v2.6L, rmtfs, QRTR) -> sensors/GPS/fingerprint -> camera (last).

## Phase 5 - Maintenance
Rebase per stable release, keep a changelog, upstream dts patches.

## Known risks
Modem/IPA not upstream; audio status unknown; camera long pole; no active AOSP-on-mainline project to copy;
tulip may have panel/touch variants.
