> **AI disclosure:** prepared by an AI agent (OpenHands) on behalf of INFIYOP.

# Neutron Clang build — results

First real clang build of this kernel. Everything below was run, not predicted.

| | |
|---|---|
| Toolchain | Neutron Clang tag `06092026`, `clang version 24.0.0git` |
| Kernel | 7.2.3, `qcom-sdm660-7.2.y`, patches 0001–0004 |
| Host | Debian 13 container, `LLVM=1`, in-tree build in a fresh clone |
| Result | **build passed**, 0 warnings, 0 errors |

## 1. Toolchain config — `out-neutron/toolchain-config.txt`

```
CONFIG_CC_IS_CLANG=y
CONFIG_AS_IS_LLVM=y
CONFIG_LD_IS_LLD=y
CONFIG_SHADOW_CALL_STACK=y
CONFIG_LTO_NONE=y
```

`LD_IS_LLD=y` is the one that was unmet under GCC. `LTO` stays `NONE` — the
`configs/neutron-lto-thin.fragment` step was not taken.

## 2. Build and warnings

- `make -j$(nproc) Image.gz modules` then the three DTBs: **passed**.
- Full build: **0** `warning:` lines, **0** `error:` lines.
- Rebuilt the ported files with `W=1` (stricter than the default build):
  `xt_quota2.o`, `uid_sys_stats.o`, `fs/sync.o` — **0 warnings**.
- `out-neutron/clang-warnings.txt` is empty because there was nothing to list.

The kernel-doc cleanup in patch 0001 mattered here: clang's `W=1` pass over
`xt_quota2.c` is clean, where GCC's kernel-doc check reported 16 issues before it.

## 3. Size and modules

| | GCC (v7-testing) | Neutron Clang |
|---|---:|---:|
| `Image.gz` | 13,443,377 | **13,240,624** (−202,753, −1.5%) |
| `.config` | 228,582 | 229,293 |
| modules built | 688 | 688 |
| `modules.tar` | 182,220,800 | 147,896,320 |
| tulip DTB | 58,733 | 58,733 |
| whyred DTBs | 56,933 | 56,933 |

DTBs are byte-identical in size, as expected — they do not depend on the C compiler.

`scripts/select-modules.py` was re-run against the clang modules for all three DTBs:

```
tulip            78 modules   identical to android/device/generic/sdm660/tulip/modules.all
whyred-tianma    68 modules   identical to android/device/generic/sdm660/whyred/modules.all
whyred-shenchao  68 modules   same set as tianma
```

No update to `modules.all` was needed.

## 4. Boot-image verification

Both images were packed with `scripts/make-bootimg.sh` and checked with
`scripts/verify-bootimg.py`:

```
boot-tulip-test.img    page 4096, kernel 13,299,357 B @ 0x8000, header v0
  kernel area starts with Image.gz - ok
  appended DTB: model "Xiaomi Redmi Note 6 Pro", compatible xiaomi,tulip
  qcom,msm-id = <0x159 0x0>        - matches
  qcom,board-id = <0x40008 0x0>    - matches        PASS

boot-whyred-test.img   page 4096, kernel 13,297,557 B @ 0x8000, header v0
  appended DTB: model "Xiaomi Redmi Note 5 Pro (Tianma)"
  qcom,msm-id = <0x159 0x0>                          - matches
  qcom,board-id = <0x30008 0x0 0x10008 0x0>          - matches        PASS
```

## Gaps found in the v9 archive

`build-kernel-neutron.yml` calls `scripts/verify-bootimg.py`, which was not in the
archive and did not exist in the repo. Written for this run: it parses the `ANDROID!`
header, confirms the kernel area starts with the given `Image.gz`, locates the appended
DTB, parses it without needing `dtc`, and compares `qcom,msm-id` / `qcom,board-id`
against the expected cells. Negative test (tulip image against `0x30008`) fails as it
should.

`scripts/select-modules.py` documents an output file `unmatched-dt-compatibles.txt`
that it does not write; the real name is `dt-gaps.txt`. Docstring corrected.

## Not done

- Nothing booted.
- ThinLTO not attempted (deliberately second step).
- `out-neutron/clang-warnings.txt` from the full build was overwritten by the
  incremental re-run that finished `modules.tar` after `depmod` was installed; the
  warning counts above were taken from the complete log before that.
