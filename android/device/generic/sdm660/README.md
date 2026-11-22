# device/generic/sdm660 - AOSP for SDM636/SDM660-family phones on a mainline Linux kernel

Targets: tulip (Redmi Note 6 Pro), whyred (Redmi Note 5 Pro). Status: SOURCE ONLY, never built, never booted.

Derived from https://github.com/aospm/android_device_generic_sdm845 (commit fc93ee2), which already runs AOSP on a mainline
kernel on SDM845 phones. Reused as-is: gralloc (minigbm-style), health, lights, memtrack HALs, sepolicy, and the Android.bp
ports of qrtr, rmtfs, pd-mapper and tqftpserv (the userspace the mainline modem stack needs).
Board values (arch, A-only, page size, partition sizes) follow LineageOS android_device_xiaomi_sdm660-common / twolip / whyred.

## Changed from the SDM845 original
- sdm845 -> sdm660 naming; eMMC (soc@0/c0c4000.mmc) instead of UFS in fstab, boot_devices and rmtfs path
- arch variant armv8-a / cortex-a73 (not kryo385); freedreno only (virgl dropped)
- kernel.mk appends the right DTB(s) per device; no per-device kernel build, CI drops prebuilt files into shared/prebuilt-kernel
- encryption: no inlinecrypt (no inline crypto engine assumed)

## NOT validated for SDM660 (inherited from SDM845, expect to change)
- shared/etc/mixer_paths.xml, audio.sdm660.xml, audio_policy_configuration*.xml (SDM845 sound card routing)
- shared/init.sdm660.rc: remoteproc0/1/2 start order and cpusets assume the SDM845 layout; check /sys/class/remoteproc on the phone
- key_layout.kl, overlay config.xml (audio jack input device), media_codecs.xml (Venus)
- Boot image offsets and cmdline: compare with the stock boot.img
- Bootloader: the mainline tulip/whyred DTBs have no qcom,msm-id / qcom,board-id. Xiaomi LK may refuse an appended DTB without them.
  Run tools/extract-lk-ids.sh on your stock boot.img and add the values to the dts (see docs/LK_IDS.md).
