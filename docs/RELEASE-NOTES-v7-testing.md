> **AI disclosure:** this document was prepared by an AI agent (OpenHands) on behalf of INFIYOP. Verify anything before acting on it.

# v7-testing — pre-release

**Status: testing build. Not a release candidate. Nothing has been booted on hardware.**

This is the first build whose DTBs carry the bootloader IDs, and the first that ships a
`fastboot boot` image per device. Published as a GitHub pre-release on purpose.

| | |
|---|---|
| Tag | `v7-testing` |
| Kernel | Linux **7.2.3**, `sdm660-mainline/linux` @ `qcom-sdm660-7.2.y`, commit `5690ded61` |
| Release string | `7.2.3-sdm660+` |
| Toolchain | `gcc-14` `aarch64-linux-gnu` |
| Devices | Redmi Note 6 Pro (`tulip`), Redmi Note 5 Pro (`whyred`, tianma + shenchao) |
| Booted? | **No.** |

---

## What changed since v5-testing

| Change | Detail |
|---|---|
| **Patch 0004** | `qcom,msm-id` / `board-id` / `pmic-id` added to the tulip and whyred DTS, copied from your stock `boot.img`. This was the blocker on the bootloader accepting an appended DTB. |
| **New DTBs** | tulip 58,733 B (+123), whyred 56,933 B (+147). |
| **Test boot images** | `boot-tulip-test.img`, `boot-whyred-test.img` — legacy A-only `boot.img`, header v0, for `fastboot boot` (writes nothing). |
| **`scripts/make-bootimg.sh`** | Packs kernel + appended DTB + optional ramdisk. Defaults confirmed against your stock image. |
| **`docs/STOCK_BOOT_PARAMS.md`** | Page size, load addresses, cmdline and the LK ids read from your `boot.img`. |
| **`xt_quota2.c` kernel-doc fixed** | `struct xt_quota_counter` documented properly, `q2_get_counter` params corrected. kernel-doc warnings: 16 → **0**. |
| **Fetch script preflight** | Fails immediately with `missing dependency: zstd` instead of after a 200 MB download. |
| **CI builds boot images** | Per-device `boot-*-test.img` now built and checksummed on every run. |

`Image.gz` and `modules.tar` are **unchanged** from v5-testing. Patch 0004 touches only
DTS files, and the 0001 edit is comments only — verified by rebuilding the object and
comparing every code section (`.text`, `.rodata`, `.data`, `.init.text` all identical;
only `.debug_info` grew by 2 bytes).

## The LK IDs, and where they came from

Read from `/workspace/project/boot.img` (36,368,384 B, 52 appended DTBs, downstream 4.19):

| Stock DTB | model | msm-id | board-id |
|---|---|---|---|
| #43 @0x1e80a75 | SDM 636 PM660 + PM660L MTP **E7T** | `0x159 0x00` | `0x40008 0x00` |
| #12 @0x158c09b | SDM 636 PM660 + PM660L **E7S** | `0x159 0x00` | `0x30008 0x00 0x10008 0x00` |

After applying patch 0004 and rebuilding, each DTB reports exactly those values:

```
tulip            msm-id = <0x159 0x00>  board-id = <0x40008 0x00>
whyred-tianma    msm-id = <0x159 0x00>  board-id = <0x30008 0x00 0x10008 0x00>
whyred-shenchao  msm-id = <0x159 0x00>  board-id = <0x30008 0x00 0x10008 0x00>
```

**One assumption to check on the phone:** E7T = tulip and E7S = whyred rests on the Xiaomi
model numbers (M1806E7T / M1803E7S). It is not printed in the image. Run
`getprop ro.product.model` on the device before flashing anything persistent.

## Assets

| Asset | Bytes | SHA-256 (first 16) |
|---|---:|---|
| `Image.gz` | 13,443,377 | `e464a8d2fc09221a` |
| `Image.gz-dtb-tulip` | 13,502,110 | `075a5826e4021667` |
| `sdm636-xiaomi-tulip.dtb` | 58,733 | `2f97928ccf63690a` |
| `sdm636-xiaomi-whyred-tianma.dtb` | 56,933 | `2244afca6379141e` |
| `sdm636-xiaomi-whyred-shenchao.dtb` | 56,933 | `7939123194d0fa15` |
| `modules.tar` | 182,220,800 | `e1cd810111124a91` |
| `sdm660_android_defconfig.built` | 228,582 | `b8ffdf5df92da9f7` |
| `boot-tulip-test.img` | 13,836,288 | `7b249b20977bd738` |
| `boot-whyred-test.img` | 13,832,192 | `b05bfdb00db960f7` |
| `SHA256SUMS` | — | full digests for all of the above |

Boot images: page 4096, kernel at `0x8000`, ramdisk at `0x01000000`, tags at `0x100`,
header v0 — identical to your stock image's layout.

## What the boot images prove, and what they do not

They carry a **minimal 325 KB initramfs** (`tests/minimal-initramfs/init.c`, a static
init) — **not** postmarketOS and **not** Android. On success the console shows:

```
MAINLINE BOOT OK - kernel reached userspace
```

then the phone powers off so `fastboot boot` returns. That proves the bootloader accepted
the appended DTB and the kernel reached userspace. It does **not** prove display, touch,
Wi-Fi, modem, audio or storage work.

The default cmdline is `console=tty0 ...`. For a headless run, override it:

```bash
CMDLINE="console=ttyMSM0,115200n8 no_console_suspend deferred_probe_timeout=30" \
  bash scripts/make-bootimg.sh --kernel Image.gz \
       --dtb sdm636-xiaomi-tulip.dtb --ramdisk initramfs.cpio.gz --out boot.img
```

## How to test

```bash
fastboot boot boot-tulip-test.img     # writes nothing, reboots on failure
```

If it returns instantly with no output, the bootloader rejected the image — capture the
fastboot error text. If it hangs, the kernel started but the console is wrong; retry with
`console=ttyMSM0`.

## Known issues

- **2 checkpatch errors remain** in patch 0001 (`code indent should use tabs`), inherited
  from the 4.19 source. Style only.
- **whyred audio**: the whyred DTS enables no sound card. Tulip does.
- **`FEATURE_MATRIX.md` is all `untested`.** That is accurate, not an oversight.
- **AOSP build** not attempted: needs ~300 GB disk and 32 GB+ RAM.
- **`boot-whyred-test.img` uses the tianma DTB.** For a shenchao panel, rebuild with
  `--dtb sdm636-xiaomi-whyred-shenchao.dtb`.

## Scope

Vulkan remains out of scope (decision **D003**). Adreno 509 is a5xx: 32-bit GPU VA blocks
Vulkan 1.2, no DP4A for 1.3, no tile local read for 1.4, `libllvm-glnext` is closed.
Freedreno **OpenGL** is the graphics path.
