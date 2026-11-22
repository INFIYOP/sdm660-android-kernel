> **AI disclosure:** this document was prepared by an AI agent (OpenHands) on behalf of INFIYOP. Verify anything before acting on it.

# v7.2.3-sdm660-r1

**First build release.** Mainline Linux 7.2.3 compiled as an Android kernel for
SDM636 (Redmi Note 6 Pro `tulip`, Redmi Note 5 Pro `whyred`).

- Base: `sdm660-mainline/linux` @ `qcom-sdm660-7.2.y`, commit `5690ded61`, Linux 7.2.3
- Kernel release string: `7.2.3-sdm660+`
- Toolchain: `gcc-14-aarch64-linux-gnu` (GCC, not clang/LLD)
- Built: 2026-11-22, 4 cores, ~25 min for `Image.gz`, ~12 min for modules
- Result: **0 errors, 0 warnings**

> This release proves the kit builds. It has **not** been booted on hardware.
> Nothing here has touched a phone.

---

## Assets

| Asset | Size (bytes) | Purpose |
|---|---:|---|
| `Image.gz` | 13,443,377 | arm64 kernel image, gzip |
| `Image.gz-dtb-tulip` | 13,501,987 | `Image.gz` + tulip DTB concatenated (kit format) |
| `sdm636-xiaomi-tulip.dtb` | 58,610 | device tree, Redmi Note 6 Pro |
| `sdm636-xiaomi-whyred-tianma.dtb` | 56,786 | device tree, Note 5 Pro (tianma panel) |
| `sdm636-xiaomi-whyred-shenchao.dtb` | 56,786 | device tree, Note 5 Pro (shenchao panel) |
| `modules.tar` | 182,220,800 | 688 modules + `modules.dep` (uncompressed tar; payload is `.ko.zst`) |
| `sdm660_android_defconfig.built` | 228,582 | the resolved `.config` actually used |
| `SHA256SUMS` | — | checksums for everything above |

```
e464a8d2fc09221afe2c6ab9a9b79c18ae47c46173197bf5699c043d99bc5392  Image.gz
5a9dd5864a76d88577de87840e0e4f4bb3e7100d24dd2d92f144d10cb368cc73  Image.gz-dtb-tulip
5c7221fecaa87bc660fa4586cc5904d17773967148d5f0fc4ba5c27ca048d97a  sdm636-xiaomi-tulip.dtb
0219022ec7d76e983e00df79789c7c294a3c9ee94bc52308be635fc5db61b6b1  sdm636-xiaomi-whyred-tianma.dtb
77dc8c4acf05804f3cf58031cb3248abc39e00856726aa25a44c77b781e95659  sdm636-xiaomi-whyred-shenchao.dtb
e1cd810111124a919781ffadd394ec1a2ecb4706bce52724d79152276d91ab0d  modules.tar
b8ffdf5df92da9f78bc15045d8352d8f62d51596f3f74d6c9776b4d3c4b4ea51  sdm660_android_defconfig.built
```

---

## What was verified

### Build

| Check | Result |
|---|---|
| Patches 0001-0003 apply to clean `5690ded61` | 3/3 clean, 45 insertions / 7 files |
| `make sdm660_android_defconfig` | exit 0 |
| `make Image.gz` | 13.4 MB, `ARMd` magic at 0x38, `image_size` 0x2070000 |
| `make modules` | 688 `.ko` |
| `modules_install` + `depmod` | 688 installed, `modules.dep` generated |
| Module vermagic | `7.2.3-sdm660+ SMP preempt mod_unload modversions aarch64` |
| DTBs | 3/3, byte-identical sizes to the kit (58610 / 56786 / 56786) |
| Compiler diagnostics | 0 errors, 0 warnings |

The DTB size match is the strongest signal here: it means the kit's prebuilt DTBs came
from this exact tree and toolchain, so the kit is self-consistent.

### Config

All 36 options from `android-mainline.fragment` resolve to `=y`, including the three
gotchas the kit documents:

- `CONFIG_IP_NF_IPTABLES_LEGACY=y` / `CONFIG_IP6_NF_IPTABLES_LEGACY=y`
- `CONFIG_QCOM_LLCC=y` (and `QCOM_AOSS_QMP`, `QCOM_OCMEM`, `QCOM_COMMAND_DB`) so
  `CONFIG_DRM_MSM=y` instead of `=m`
- netfilter parents `NETFILTER_XTABLES` / `NF_CONNTRACK` / `NF_NAT` = `y`

Ported features are linked, not merely applied: `uid_sys_stats` and `xt_quota2`
initcalls are present in `vmlinux`.

---

## Fixes to the kit in this release

Two real bugs in `build-kernel.yml` were found while doing this build. Both are fixed
in `.github/workflows/build-kernel.yml`:

1. **CI never built modules.** 532 options are `=m` in this config, including
   `QCOM_IPA`, `QCOM_FASTRPC`, `ARM_QCOM_CPUFREQ_HW`, `QRTR`, `ath10k_snoc` and
   `qcom_q6v5_pas`. The old workflow uploaded only `Image.gz` + DTBs, so its artifacts
   were unusable for Phase 3.
2. **Missing build deps.** The config enables `CONFIG_MODULE_COMPRESS_ZSTD`, so
   `modules_install` shells out to `zstd`; `depmod` comes from `kmod`. Neither was in
   the apt line. Symptom: `Error 127` at the very end of a 30-minute build.

The workflow also now triggers on `v*` tags and uses the `patches/`, `configs/` layout.

---

## Not done

- **Not booted.** No hardware was touched. `FEATURE_MATRIX.md` is still all `untested`.
- **No `boot.img`.** `PAGESIZE`, `BASE`, `KERNEL_OFFSET` and `CMDLINE` must come from
  the user's own stock `boot.img` (`unpackbootimg -i boot.img -o stock/`). Guessing them
  is how you get a silent black screen, so the build script refuses.
- **No runtime test of the ported features.** `xt_quota2`, `uid_sys_stats` and the fsync
  counter are compile-tested only.
- **`Image.gz-dtb-tulip`** uses the kit's plain concatenation. Whether your bootloader
  wants appended-DTB or a `--dtb` section depends on the stock boot.img; check with
  `mkbootimg` before flashing.

---

## How to test on hardware

```bash
# 1. Back up first. This is not optional.
adb devices            # phone in TWRP/OrangeFox, adb root
bash scripts/00-backup-partitions.sh

# 2. Read boot.img parameters from YOUR stock image
unpackbootimg -i backup-*/boot.img -o stock/

# 3. Pack a test image with those values (see scripts/02-build-kernel.sh)
#    and boot it without writing anything:
fastboot boot boot-tulip-test.img
```

`fastboot boot` does not overwrite the boot partition, so a bad kernel is a reboot
away from recovery. Watch `pstore`/ramoops for the panic if it dies before USB comes up.

---

## Why this does not solve the Vulkan question

The original goal was to raise Vulkan on these phones (for Minecraft Java 26.2+, which
now requires **Vulkan 1.2 + `VK_KHR_dynamic_rendering` + `VK_KHR_push_descriptor`** and
falls back to OpenGL with `vulkan_device_version_too_low`).

This kernel does not change that:

- Adreno 509 is `a5xx`. It has a **32-bit GPU virtual address space**, so
  `bufferDeviceAddress` — mandatory in Vulkan 1.2 — cannot be implemented. Not a driver
  gap; a silicon limit. `a6xx` moved to 48-bit.
- Vulkan 1.3 additionally needs DP4A and subgroup-size control; 1.4 needs dynamic
  rendering local read. None exist on `a5xx`.
- Mesa **turnip** (the open Vulkan driver) targets `a6xx`/`a7xx`. There is no `a5xx`
  turnip, and there is no realistic path to one.

What mainline *does* give you is freedreno **OpenGL** (well supported on `a5xx`) and a
maintainable kernel — which is exactly what an Android bring-up needs, but it leaves the
Vulkan version at 1.1.

For Minecraft Java on these phones the practical answer stays: OpenGL path, i.e.
GL4ES on 1.12.2/1.8.9, or Zink-over-Vulkan-1.1 for 1.17+ at single-digit fps.

---

## Reproduce

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
make -j"$(nproc)" qcom/sdm636-xiaomi-tulip.dtb \
                  qcom/sdm636-xiaomi-whyred-tianma.dtb \
                  qcom/sdm636-xiaomi-whyred-shenchao.dtb
make INSTALL_MOD_PATH=../out/modules modules_install
depmod -b ../out/modules "$(make -s kernelrelease)"
```

Builds are reproducible in the sense that the DTBs come out byte-identical in size and
the config resolves identically; the `Image.gz` bytes will differ with compiler version.
