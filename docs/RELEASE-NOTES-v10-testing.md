> **AI disclosure:** this document was prepared by an AI agent (OpenHands) on behalf of INFIYOP.

# v10-testing — pre-release, a first-boot image whose log survives the reboot

**Status: testing build. Not a release candidate. Nothing has been booted.**

v9 made the kernel a real clang build. v10 changes nothing in the compiler path: it
fixes the two things that would have made the first boot test on the phone unreadable.

1. **`patches/0005`** — tulip's `ramoops` node now uses the same region and layout as the
   stock E7T/E7S DTBs (`0xa0000000`, 4 MB, console 2 MB, pmsg 2 MB, no dmesg records).
   Before this, tulip used 128 KiB buffers plus dmesg records, so a 4.19 kernel reading
   the region after a warm reboot looked in the wrong place.
2. **`tests/minimal-initramfs/init.c`** — rewritten. It creates `/dev`, `/proc` and
   `/sys` before mounting (without that the mounts failed and it printed nothing),
   writes to `/dev/kmsg`, `/dev/console` and `/dev/tty0`, prints `/proc/version` and
   `/proc/cmdline`, repeats the marker for 60 s so it can be photographed, then
   **warm-restarts** instead of powering off so RAM (and therefore pstore) survives.
3. **`scripts/make-bootimg.sh`** — the default cmdline now adds `ignore_loglevel panic=5`
   so a panic is visible on screen and reboots into the normal OS instead of hanging.
4. **`docs/FIRST_BOOT_TEST.md`** — the procedure and what each outcome would mean.

| | |
|---|---|
| Tag | `v10-testing` |
| Kernel | Linux **7.2.3**, `sdm660-mainline/linux` @ `qcom-sdm660-7.2.y` (release `v7.2.3-sdm660-r1`) |
| Compiler | **Neutron Clang** tag `06092026`, `clang version 24.0.0git` |
| Build | `make LLVM=1 ARCH=arm64`, fresh clone, `patches/0001`–`0005` |
| Devices | Redmi Note 6 Pro (`tulip`), Redmi Note 5 Pro (`whyred`, tianma + shenchao) |
| Booted? | **No.** |

## Result

| | v9-testing | v10-testing |
|---|---:|---:|
| `Image.gz` (local build) | 13,240,624 | 13,240,704 |
| Warnings / errors | 0 / 0 | **0 / 0** |
| Modules | 688 | 688 |
| `modules.tar` | 147,896,320 | 147,896,320 |
| `sdm636-xiaomi-tulip.dtb` | 58,733 | 58,733 (**content changed**) |
| `sdm636-xiaomi-whyred-*.dtb` | 56,933 | 56,933 (identical) |
| `boot-*-test.img` | 13,598,720 | 13,598,720 |

`Image.gz` differs from v9 by a few bytes only because the version string carries the
build timestamp; no source outside the device trees changed.

The DTBs are the measurable part:

```
tulip          f9e2fe80655523ac...   changed by 0005 (ramoops layout)
whyred-tianma  2244afca6379141e...   identical to v9
whyred-shenchao 7939123194d0fa15...  identical to v9
```

whyred already had the stock layout (it comes from the shared whyred dtsi), so only
tulip needed the patch. Decompiling the built DTBs confirms both now say:

```
ramoops@a0000000 {
        reg = <0x00 0xa0000000 0x00 0x400000>;
        console-size = <0x200000>;
        record-size = <0x00>;
        ftrace-size = <0x00>;
        pmsg-size = <0x200000>;
};
```

## Verification

Both boot images were checked with `scripts/verify-bootimg.py`:

```
boot-tulip-test.img   page 4096, kernel 13,299,437 B @ 0x8000, header v0
  cmdline: console=tty0 no_console_suspend printk.devkmsg=on ignore_loglevel panic=5 deferred_probe_timeout=30
  appended DTB: "Xiaomi Redmi Note 6 Pro", compatible xiaomi,tulip
  qcom,msm-id = <0x159 0x0>      qcom,board-id = <0x40008 0x0>              PASS

boot-whyred-test.img  page 4096, kernel 13,297,637 B @ 0x8000, header v0
  appended DTB: "Xiaomi Redmi Note 5 Pro (Tianma)"
  qcom,msm-id = <0x159 0x0>      qcom,board-id = <0x30008 0x0 0x10008 0x0>   PASS
```

The ramdisk `init` was built with `aarch64-linux-gnu-gcc -static -Os` (ELF class 64,
machine `0xb7`).

CI run [45538359182](https://github.com/INFIYOP/sdm660-android-kernel/actions/runs/45538359182)
reproduced the clang build from a clean clone: 0 warnings, both boot images PASS,
`Image.gz` 13,240,597 B (timestamp-only difference from the local build). The GCC workflow
([45538355221](https://github.com/INFIYOP/sdm660-android-kernel/actions/runs/45538355221))
also passed on the same commit.

## How to test

```bash
fastboot boot boot-tulip-test.img     # writes nothing to the phone
```

The ramdisk is a minimal static init — not postmarketOS, not Android. Success is
`MAINLINE BOOT OK - kernel reached userspace` plus the version/cmdline lines on screen,
then a 60 s countdown and a restart.

After the phone boots its normal OS:

```bash
adb shell su -c 'ls -l /sys/fs/pstore'
adb shell su -c 'cat /sys/fs/pstore/console-ramoops-0' > mainline-console.log
```

Copy it immediately: the file exists for that boot only. A long-press power-off or a
battery pull loses RAM and with it the log.

`docs/FIRST_BOOT_TEST.md` lists what each outcome (fastboot error, black screen, panic,
60 s countdown) would mean.

## Assets

| Asset | Bytes | SHA-256 (first 16) |
|---|---:|---|
| `Image.gz` | 13,240,704 | `95263448a49a0251` |
| `Image.gz-dtb-tulip` | 13,299,437 | `88e00737a12a74c4` |
| `sdm636-xiaomi-tulip.dtb` | 58,733 | `f9e2fe80655523ac` |
| `sdm636-xiaomi-whyred-tianma.dtb` | 56,933 | `2244afca6379141e` |
| `sdm636-xiaomi-whyred-shenchao.dtb` | 56,933 | `7939123194d0fa15` |
| `modules.tar` | 147,896,320 | `ebcfaa84b0dcacef` |
| `sdm660_android_defconfig.built` | 229,314 | `698e8864e086d176` |
| `toolchain-config.txt` | 105 | `f663c59e5f8d58b7` |
| `boot-tulip-test.img` | 13,598,720 | `0e14096deccbe575` |
| `boot-whyred-test.img` | 13,598,720 | `27f2781a87fbcc96` |
| `SHA256SUMS` | — | full digests |

## Known issues

- Nothing booted; `FEATURE_MATRIX.md` is still all `untested`.
- The pstore read-back depends on the bootloader preserving RAM across a warm reset and
  on the normal kernel having pstore/ramoops enabled. Neither is verified on hardware.
- ThinLTO not attempted (`CONFIG_LTO_NONE=y`).
- whyred still has no sound card in its DTS; tulip does.
