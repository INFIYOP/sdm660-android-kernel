# Findings (2026-11-22)

## Base tree
- sdm660-mainline/linux @ qcom-sdm660-7.2.y, Linux 7.2.3, commit 5690ded61.
- Already has: sdm636-xiaomi-tulip.dts, sdm636-xiaomi-whyred-common.dtsi + -tianma / -shenchao variants.
- tulip dts enables (from reading it): simple-framebuffer, ramoops, GPU (A509; zap fw name "a512_zap.mbn"),
  novatek nt36672a touchscreen, tianma tl063fvmc43-02 panel (nt36672a), TAS2557 amp, WCN3990 Bluetooth + Wi-Fi,
  modem remoteproc (mba.mbn/modem.mdt), Venus (venus-4.4), audio sound card (qcom,sdm660-sndcard), charger + fuel gauge,
  haptics, WLED, USB3, eMMC + SD.
- tulip has a /delete-node/ of zap_shader_region and defines its own at 0xfbc00000.

## Verified here (not on a phone)
- sdm636-xiaomi-tulip.dtb, whyred-tianma.dtb, whyred-shenchao.dtb all compile cleanly with the cross compiler. (58610 / 56786 / 56786 bytes)
- sdm660_defconfig + AOSP android-base (6.12 line, from LineageOS/android_kernel_configs) + our fragment merges and resolves.
- NOT done: a full Image build (needs hours on 1 core; use build-kernel.yml in GitHub Actions). NOT booted on hardware.

## Config gotchas found (all fixed in android-mainline.fragment)
1. 7.x moved iptables tables behind CONFIG_IP_NF_IPTABLES_LEGACY / CONFIG_IP6_NF_IPTABLES_LEGACY. Without them every Android netfilter =y silently becomes absent/module.
2. DRM_MSM can only be =y if QCOM_AOSS_QMP, QCOM_OCMEM, QCOM_LLCC and QCOM_COMMAND_DB are =y (sdm660_defconfig has LLCC=m, which capped DRM_MSM at =m).
3. Netfilter parents (NETFILTER_XTABLES, NF_CONNTRACK, NF_NAT) must be =y or Android's =y options get capped to =m.

## UPDATE: see PORTING.md. quota2 and uid_sys_stats are now ported (patches 0001-0003); ashmem, cpufreq_times, dm-default-key have alternatives.

## Android base options that do NOT exist in mainline 7.2 (original list, before the ports)
- CONFIG_ASHMEM (removed; Android uses memfd instead)
- CONFIG_CPU_FREQ_TIMES, CONFIG_UID_SYS_STATS, CONFIG_NETFILTER_XT_MATCH_QUOTA2(_LOG), CONFIG_DM_DEFAULT_KEY: ACK-only out-of-tree features
- CONFIG_NF_CT_PROTO_DCCP/UDPLITE, CONFIG_SCHED_DEBUG: removed/renamed upstream
- CONFIG_LD_IS_LLD: compiler detection, only true if you build with LLD (GCC build here)
- CONFIG_HID_PLAYSTATION stays =m (dependency); irrelevant for the phone.
Android userspace that expects quota2 / uid_sys_stats / cpufreq_times will need eBPF-based replacements. Check this in Phase 3.
