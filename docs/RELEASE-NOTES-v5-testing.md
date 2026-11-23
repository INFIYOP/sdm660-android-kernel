> **AI disclosure:** this document was prepared by an AI agent (OpenHands) on behalf of INFIYOP. Verify anything before acting on it.

# v5-testing — pre-release

**Status: testing build. Not a release candidate. Nothing has been booted on hardware.**

This is the first build that carries the **v5 tree**: the AOSP device tree for `tulip`
and `whyred`, the firmware/module tooling, and the CI guards. It is published as a
GitHub pre-release on purpose — it exists to be flashed, tested and broken, not to be
recommended to anyone.

| | |
|---|---|
| Tag | `v5-testing` |
| Kernel | Linux **7.2.3**, `sdm660-mainline/linux` @ `qcom-sdm660-7.2.y`, commit `5690ded61` |
| Release string | `7.2.3-sdm660+` |
| Toolchain | `gcc-14` `aarch64-linux-gnu` |
| Devices | Redmi Note 6 Pro (`tulip`), Redmi Note 5 Pro (`whyred`, tianma + shenchao) |
| Booted? | **No.** |

---

## The kernel binaries are byte-identical to r1

v5 changes **no kernel source**: `patches/`, `configs/` and the kernel tree are untouched
since `v7.2.3-sdm660-r1`. Rather than assert that, it was measured — all seven artifacts
were verified against r1's published `SHA256SUMS`:

```
Image.gz: OK
Image.gz-dtb-tulip: OK
sdm636-xiaomi-tulip.dtb: OK
sdm636-xiaomi-whyred-shenchao.dtb: OK
sdm636-xiaomi-whyred-tianma.dtb: OK
modules.tar: OK
sdm660_android_defconfig.built: OK
```

So this is a **packaging release**: the same kernel, attached to the tree that describes
how to install and boot it. If you already have r1's binaries, you gain nothing by
re-downloading them; you gain the device tree, the tooling and the docs.

## What changed in the tree since r1

- `android/device/generic/sdm660/` — AOSP device tree, 141 files, `tulip` and `whyred`
  products, sepolicy, audio/media configs, gralloc, health, light, memtrack HALs,
  `init.modules.rc`, `fstab.ramdisk`, `modules.all`. Derived from
  `aospm/android_device_generic_sdm845`. **Source only, never built.**
- `scripts/fetch-prebuilt-kernel.sh` — installs a release into the device tree, verifies
  sha256, decompresses only the modules the devices need.
- `scripts/select-modules.py` — derives the module list from enabled DT nodes and
  `modules.dep`, and reports DT nodes with no driver.
- `scripts/stage-firmware.sh` — stages the firmware the mainline drivers request from
  your own stock images. Nothing is redistributed.
- `scripts/extract-lk-ids.py` — reads `qcom,msm-id` / `board-id` / `pmic-id` from a stock
  boot image.
- `docs/FIRMWARE.md`, `docs/LK_IDS.md`, `docs/dt-coverage/`, `docs/COMPILE-AGENT-REPORT.md`.
- `tests/test-stage-firmware.sh` — fake stock tree, checks the generated `device.mk`.
- CI: lint + test step, and a step that **fails the build** if any name in
  `{tulip,whyred}/modules.all` is missing from `modules.tar`.
- CI: the uploaded artifact no longer swallows the kernel source. `modules_install` now
  runs in `$RUNNER_TEMP` and the `build`/`source` symlinks are deleted, so the artifact
  is ~196 MB instead of 2.4 GB.

---

## Verification

### Run in CI (GitHub Actions, ubuntu-24.04)

| Run | Commit | Result |
|---|---|---|
| [45061804388](https://github.com/INFIYOP/sdm660-android-kernel/actions/runs/45061804388) | `0cc37eb` | success — kernel, DTBs, modules built and uploaded |
| [45065023853](https://github.com/INFIYOP/sdm660-android-kernel/actions/runs/45065023853) | `b6d8cef` | success — lint + tests, build, `modules.all` guard |

### Run locally

| Check | Result |
|---|---|
| `fetch-prebuilt-kernel.sh v7.2.3-sdm660-r1` | 5/5 sha256 OK, 83 modules, **181,681,771 B** uncompressed |
| `select-modules.py`, all three DTBs | tulip 78, whyred 68 each; matches the committed lists |
| `bash -n` / `py_compile` | 7/7 and 4/4 OK |
| shellcheck 0.10.0 | 0 errors, 1 warning (`$RANDOM` under mksh → false positive), 11 notes |
| checkpatch 0001 / 0002 / 0003 | 2E+12W / 0E+6W / clean |
| `make W=1` on the 3 touched objects | **0 compiler diagnostics**, 16 kernel-doc warnings in `xt_quota2.c` |
| `tests/test-stage-firmware.sh` | PASS |
| `modules.all` guard | passes with the real `modules.tar`; fails on an injected bogus name |

---

## Assets

| Asset | Size (bytes) |
|---|---:|
| `Image.gz` | 13,443,377 |
| `Image.gz-dtb-tulip` | 13,501,987 |
| `sdm636-xiaomi-tulip.dtb` | 58,610 |
| `sdm636-xiaomi-whyred-tianma.dtb` | 56,786 |
| `sdm636-xiaomi-whyred-shenchao.dtb` | 56,786 |
| `modules.tar` | 182,220,800 (688 modules + `modules.dep`) |
| `sdm660_android_defconfig.built` | 228,582 |
| `SHA256SUMS` | 623 |
| `RELEASE-NOTES-v5-testing.md`, `COMPILE-AGENT-REPORT.md`, `CHAT-TRANSCRIPT.md`, `SESSION-NOTES.md` | — |

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

## Not verified, and not going to be guessed

- **Nothing booted.** `FEATURE_MATRIX.md` is still all `untested`. No display, no touch,
  no Wi-Fi, no modem, no audio has been observed working on this kernel.
- **No `boot.img`.** `PAGESIZE`, `BASE`, `KERNEL_OFFSET` and `CMDLINE` come from your own
  stock image. The build script refuses to guess them.
- **No LK ids.** The mainline DTBs carry no `qcom,msm-id`/`board-id`/`pmic-id`, so an
  appended-DTB image may be rejected by the bootloader. Patch 0004 is blocked until a
  stock `boot.img` is supplied.
- **AOSP not built.** Needs ~300 GB disk and 32 GB+ RAM; the runner has 55 GB and 15 GiB.
- **whyred audio.** The whyred DTS enables no sound card; tulip does.

## How to test

```bash
# 1. Back up. Non-optional.
bash scripts/00-backup-partitions.sh

# 2. Get the boot image parameters from YOUR stock boot.img
python3 scripts/extract-lk-ids.py backup-*/boot.img --dump stock-dtbs/
unpackbootimg -i backup-*/boot.img -o stock/

# 3. Install kernel + DTBs + the modules the tree asks for
bash scripts/fetch-prebuilt-kernel.sh v5-testing

# 4. Boot it without writing anything
fastboot boot boot-tulip-test.img
```

If it dies before USB enumerates, `pstore`/ramoops is where the reason will be.

## Known issues

- **16 kernel-doc warnings** in `xt_quota2.c`: a malformed `struct xt_quota_counter`
  comment and wrong parameter names on `q2_get_counter`. Documentation only.
- **2 checkpatch errors** in patch 0001: `code indent should use tabs`. Style, inherited
  from the 4.19 sources.
- **`fetch-prebuilt-kernel.sh` has no dependency preflight** — it downloads ~200 MB
  before failing on a missing `zstd`.

## Scope

Vulkan remains out of scope (decision **D003**). Adreno 509 is a5xx: 32-bit GPU VA blocks
Vulkan 1.2, there is no DP4A or subgroup-size control for 1.3, no tile local read for 1.4,
and `libllvm-glnext` is a closed SPIR-V compiler. Freedreno **OpenGL** is the graphics
path. Minecraft Java 26.2+ will keep falling back to OpenGL on these phones.
