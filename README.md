# sdm660-android-kernel

> **AI disclosure:** this document was prepared by an AI agent (OpenHands) on behalf of INFIYOP. Verify anything before acting on it.


Mainline Linux kernel (7.2.3) ported to run as an **Android** kernel on SDM636 devices.

| Device | Codename | Status |
|---|---|---|
| Redmi Note 6 Pro | `tulip` | primary target |
| Redmi Note 5 Pro | `whyred` | second target (tianma / shenchao panel variants) |

Base tree: `github.com/sdm660-mainline/linux`, branch `qcom-sdm660-7.2.y`
(commit `5690ded61`, Linux 7.2.3).

Only firmware blobs are reused from the stock vendor partition. Everything above that
is mainline + Mesa/freedreno + minigbm + drm_hwcomposer + generic Android HALs.

## Status

**Builds cleanly. Has not booted on hardware yet.**

Verified 2026-11-22 on a 4-core x86-64 machine:

- `Image.gz` — 13,443,377 bytes
- `sdm636-xiaomi-tulip.dtb` — 58,610 bytes
- `sdm636-xiaomi-whyred-tianma.dtb` / `-shenchao.dtb` — 56,786 bytes each
- 688 modules, vermagic `7.2.3-sdm660+ SMP preempt mod_unload modversions aarch64`
- All 36 Android config options in the fragment resolve to `=y`
- Patches 0001-0003 apply cleanly (45 insertions / 7 files)

DTB sizes are byte-identical to the ones shipped in `mainline-port-kit-v3.zip`,
which confirms the kit was built from this tree with this toolchain.

## Layout

```
README.md                    this file
PLAN.md                      phases and gates
PORTING.md                   per-feature decisions for Android-only kernel features
FINDINGS.md                  verified facts and config gotchas
FEATURE_MATRIX.md            per-feature status table (fill in on hardware)
JOURNAL.md                   running log - update after every session
docs/RELEASE-NOTES.md        release notes for v7.2.3-sdm660-r1
docs/SESSION-NOTES.md        what was done, how, and what broke
docs/CHAT-TRANSCRIPT.md      condensed transcript of the working session
docs/COMPILE-AGENT-REPORT.md results of the v5 task list: lint, fetch, modules, checkpatch
docs/FIRMWARE.md             firmware the mainline drivers ask for, and how to stage it
docs/LK_IDS.md               bootloader IDs (blocked on a stock boot.img)
patches/0001..0003           xt_quota2 (+LOG), uid_sys_stats, fsync counter
configs/                     sdm660_android_defconfig, android-base-6.12, android-mainline.fragment
dtbs/                        prebuilt DTBs for tulip / whyred
android/device/generic/sdm660 AOSP device tree for tulip/whyred (source only, never built)
tests/                       tests for the tooling (no real firmware)
scripts/                     backup, postmarketOS bring-up, local build
.github/workflows/           CI build
```

## Build locally

```bash
sudo apt-get install -y gcc-aarch64-linux-gnu flex bison bc libssl-dev libelf-dev \
                        device-tree-compiler zstd kmod
git clone --depth 1 --branch qcom-sdm660-7.2.y https://github.com/sdm660-mainline/linux.git linux
cd linux
for p in ../patches/000*.patch; do git apply "$p"; done
cp ../configs/sdm660_android_defconfig arch/arm64/configs/
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
make sdm660_android_defconfig
make -j"$(nproc)" Image.gz modules
make -j"$(nproc)" qcom/sdm636-xiaomi-tulip.dtb
make INSTALL_MOD_PATH=../out/modules modules_install
depmod -b ../out/modules "$(make -s kernelrelease)"
```

`scripts/02-build-kernel.sh` does the same and adds the boot.img step.

## Boot image

`boot.img` is **not** built here on purpose: `PAGESIZE`, `BASE`, `KERNEL_OFFSET`
and `CMDLINE` must be read from your own stock `boot.img`, not guessed.

```bash
unpackbootimg -i backup-*/boot.img -o stock/     # prints the exact values
```

Then pass them to `mkbootimg` (see `scripts/02-build-kernel.sh`).

## Hardware bring-up

Read `PLAN.md` and run the scripts in order. `scripts/00-backup-partitions.sh`
first - it saves `persist`, `modemst1/2`, `fsg`, `modem`, `dsp`, `bluetooth`,
`boot`, `recovery` over adb.

## Scope

**Vulkan is out of scope (decision D003).** Adreno 509 (`a5xx`) tops out at Vulkan 1.1 in
hardware: 32-bit GPU VA blocks `bufferDeviceAddress` (Vulkan 1.2), there is no DP4A or
subgroup-size control (1.3), no tile local read (1.4), and `libllvm-glnext` is a closed
SPIR-V compiler. Mesa turnip targets `a6xx` and newer, so there is no path above 1.1.
Freedreno **OpenGL** is the graphics path here. Minecraft Java 26.2+ requires Vulkan 1.2
and will keep falling back to OpenGL on these phones. See `docs/RELEASE-NOTES.md`.
