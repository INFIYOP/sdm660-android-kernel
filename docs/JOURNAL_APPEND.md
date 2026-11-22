## 2026-11-23 - Android tree, module split, release review (append to JOURNAL.md)
- Release v7.2.3-sdm660-r1 (built by OpenHands) reviewed: SHA256SUMS fetched; DTB from release is byte-identical to the one built here.
- Boot-critical drivers (eMMC, USB, display, panel, clocks, pinctrl) are built in, so the ramdisk needs no modules.
- Needed modules (from enabled DT nodes via of: aliases + modules.dep): tulip 78 (~177 MB uncompressed), whyred 68. Too big for the 64 MB boot partition, so all go to /vendor/lib/modules and are loaded by init.modules.rc (modprobe).
- Every enabled tulip/whyred DT node has a driver (built-in or module); leftovers are child nodes of other drivers (docs/dt-coverage/).
- whyred mainline dts enables no sound card/codec: audio on whyred needs new dts work, tulip has it.
- Mainline tulip/whyred DTBs have no qcom,msm-id/board-id: boot image may be rejected by LK. See docs/LK_IDS.md. BLOCKED on stock boot.img.
- Android device tree source added at android/device/generic/sdm660 (derived from aospm/android_device_generic_sdm845). Source only, never built. Audio routing, remoteproc order, keylayout, boot image offsets are inherited/unverified.
- Next: user runs backup script, extract-lk-ids.py on stock boot.img; compile agent does tasks in docs/OPENHANDS_TASKS.md.
- 2026-11-23 (later): Added scripts/stage-firmware.sh + docs/FIRMWARE.md (file names read from the mainline dts/drivers; tested only on a fake tree) and shared/bin/start_remoteprocs.sh (starts offline remoteprocs by name/state instead of hard-coded remoteproc0/1/2). Open questions to settle with dmesg on hardware: GPU zap `.mbn` vs split mdt, exact ath10k files, BT ROM version.
