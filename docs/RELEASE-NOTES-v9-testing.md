> **AI disclosure:** this document was prepared by an AI agent (OpenHands) on behalf of INFIYOP.

# v9-testing — pre-release, first Neutron Clang build

**Status: testing build. Not a release candidate. Nothing has been booted.**

The goal in `docs/NEUTRON_CLANG.md` was to make the final kernel a clang build. This is
the first one that worked, and it is the first build where the compiler is what the
config asks for.

| | |
|---|---|
| Tag | `v9-testing` |
| Kernel | Linux **7.2.3**, `sdm660-mainline/linux` @ `qcom-sdm660-7.2.y` |
| Compiler | **Neutron Clang** tag `06092026`, `clang version 24.0.0git` (kernel needs ≥ 17.0.1) |
| Build | `make LLVM=1 ARCH=arm64`, in-tree, fresh clone |
| Devices | Redmi Note 6 Pro (`tulip`), Redmi Note 5 Pro (`whyred`, tianma + shenchao) |
| Booted? | **No.** |

## Result

| | GCC (v7-testing) | Neutron Clang (this) |
|---|---:|---:|
| `Image.gz` | 13,443,377 | **13,240,624** (−202,753, −1.5%) |
| Warnings / errors | — | **0 / 0** |
| Modules | 688 | 688 |
| `modules.tar` | 182,220,800 | 147,896,320 |
| DTBs (tulip / whyred) | 58,733 / 56,933 | 58,733 / 56,933 |

```
CONFIG_CC_IS_CLANG=y
CONFIG_AS_IS_LLVM=y
CONFIG_LD_IS_LLD=y
CONFIG_SHADOW_CALL_STACK=y
CONFIG_LTO_NONE=y
```

`LD_IS_LLD=y` is the setting that was unmet under GCC. `LTO` stays `NONE`: the ThinLTO
fragment (`configs/neutron-lto-thin.fragment`) is deliberately a second step and was not
taken.

A `W=1` rebuild of the ported files (`xt_quota2.c`, `uid_sys_stats.c`, `fs/sync.c`) is
also warning-free, so there was nothing to send back for source fixes.

Module selection was re-run against the clang modules for all three DTBs and came out
identical to the committed `modules.all` (78 tulip / 68 whyred) — the module set does not
depend on the compiler here.

## Assets

| Asset | Bytes | SHA-256 (first 16) |
|---|---:|---|
| `Image.gz` | 13,240,624 | `2abe2d3412d33f71` |
| `Image.gz-dtb-tulip` | 13,299,357 | `ec47e1ffb15ef489` |
| `sdm636-xiaomi-tulip.dtb` | 58,733 | `2f97928ccf63690a` |
| `sdm636-xiaomi-whyred-tianma.dtb` | 56,933 | `2244afca6379141e` |
| `sdm636-xiaomi-whyred-shenchao.dtb` | 56,933 | `7939123194d0fa15` |
| `modules.tar` | 147,896,320 | `6f24f6174f523e19` |
| `sdm660_android_defconfig.built` | 229,293 | `df3ffc774ed6b943` |
| `toolchain-config.txt` | — | `f663c59e5f8d58b7` |
| `boot-tulip-test.img` | 13,598,720 | `164e0c3485036a6b` |
| `boot-whyred-test.img` | 13,598,720 | `98879565d4f47e35` |
| `SHA256SUMS` | — | full digests |

The three DTBs hash **identically** to the GCC release, which is the expected result: a
device tree does not depend on the C compiler. That also means the bootloader IDs are
unchanged.

## Verification

Both boot images were checked with `scripts/verify-bootimg.py`:

```
boot-tulip-test.img   page 4096, kernel 13,299,357 B @ 0x8000, header v0
  kernel area starts with Image.gz - ok
  appended DTB: "Xiaomi Redmi Note 6 Pro", compatible xiaomi,tulip
  qcom,msm-id = <0x159 0x0>      qcom,board-id = <0x40008 0x0>        PASS

boot-whyred-test.img  page 4096, kernel 13,297,557 B @ 0x8000, header v0
  appended DTB: "Xiaomi Redmi Note 5 Pro (Tianma)"
  qcom,msm-id = <0x159 0x0>      qcom,board-id = <0x30008 0x0 0x10008 0x0>  PASS
```

## How to test

```bash
fastboot boot boot-tulip-test.img     # writes nothing
```

The ramdisk is the same minimal static init as before — not postmarketOS, not Android.
Success is `MAINLINE BOOT OK - kernel reached userspace` on the console. Confirm the
model first with `getprop ro.product.model` (should end in **E7T**); the tulip/whyred
mapping is still inferred from the Xiaomi model numbers.

For serial output: `CMDLINE="console=ttyMSM0,115200n8 no_console_suspend"` when packing.

## Notes

- The v9 archive's workflow calls `scripts/verify-bootimg.py`, which was not included and
  did not exist. It was written for this build and is in the repo now.
- `modules.tar` is 34 MB smaller than the GCC one at the same 688 modules.
- The neutron workflow is `workflow_dispatch` only — it does not run on pushes.

## Known issues

- Nothing booted; `FEATURE_MATRIX.md` is still all `untested`.
- ThinLTO not attempted.
- 2 checkpatch style errors remain in patch 0001 (tab indentation), inherited from 4.19.
- whyred still has no sound card in its DTS; tulip does.
