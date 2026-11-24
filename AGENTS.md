# AGENTS.md

Kernel build/release repo for mainline Linux on SDM636 Xiaomi devices
(`tulip` = Redmi Note 6 Pro, `whyred` = Redmi Note 5 Pro).

## Release policy

**Always publish as a beta.** Every build goes out as a GitHub **pre-release**
(`gh release create <tag> --prerelease`). Do not create a normal (stable) release and
do not ask first. Stable promotion is a separate, explicit decision by the maintainer.

- Tag naming: `<version>-testing`, e.g. `v9-testing`.
- Title states it is a beta/testing build.
- Assets: `Image.gz`, `Image.gz-dtb-tulip`, the three DTBs, `modules.tar`,
  `sdm660_android_defconfig.built`, `SHA256SUMS`, boot-test images, and the relevant
  release-notes/report docs.
- Only non-prereleases become "Latest" on GitHub, so a beta will not displace the
  current stable release. That is intended.

## Builds

| Path | Command |
|---|---|
| GCC (fast iteration) | `.github/workflows/build-kernel.yml`, or `scripts/build-kernel.sh` |
| Neutron Clang (release) | `.github/workflows/build-kernel-neutron.yml`, or `scripts/setup-neutron-clang.sh` then `scripts/build-kernel-clang.sh` |

Both use the same sources, `patches/000*.patch` and
`configs/sdm660_android_defconfig`. Never build clang in the GCC tree — use a fresh
clone (`KDIR=.../linux-clang`).

Host deps the kit does not install: `zstd`, `kmod` (depmod), `flex`, `bison`, `bc`,
`dtc`, `cpio`, `mkbootimg` (or the `scripts/pack-bootimg.py` fallback).

## Verification before publishing

1. `scripts/verify-bootimg.py <img> --image Image.gz --expect-msm-id 0x159 --expect-board-id <0x40008|0x30008>`
   must PASS for tulip and whyred.
2. DTB ids must match the stock image: tulip `board-id 0x40008 0x00`,
   whyred `0x30008 0x00 0x10008 0x00`.
3. If the module set changed, re-run `scripts/select-modules.py` and update
   `android/device/generic/sdm660/*/modules.all`.

## Ground rules

- Do not silence compiler or kernel-doc warnings with flags; fix the source or report it.
- Nothing in this repo has booted on hardware. Do not describe a build as working.
- Vulkan is out of scope (decision D003); Adreno 509 tops out at Vulkan 1.1.
