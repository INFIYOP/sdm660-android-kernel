> **AI disclosure:** this document was prepared by an AI agent (OpenHands) on behalf of INFIYOP. Verify anything before acting on it.

# Compile-agent report — v5 drop

Results for `docs/OPENHANDS_TASKS.md`. Only what was actually run is reported. Nothing
here was booted on a phone, and no AOSP build was attempted.

Environment: Debian container, 4 cores, 15 GiB RAM. Note that the container was reset
mid-session, which removed the apt packages installed earlier (`zstd`, `dtc`, `kmod`,
`gcc-aarch64-linux-gnu`). They were reinstalled. That reset is why the first
`fetch-prebuilt-kernel.sh` run failed — see task 3.

---

## Task 1 — merge

Merged into the repo root:

| Added | Notes |
|---|---|
| `android/device/generic/sdm660/**` | 141 files, AOSP device tree |
| `docs/FIRMWARE.md`, `docs/LK_IDS.md`, `docs/OPENHANDS_TASKS.md`, `docs/JOURNAL_APPEND.md` | |
| `docs/dt-coverage/*.txt` | 3 files |
| `scripts/select-modules.py`, `fetch-prebuilt-kernel.sh`, `stage-firmware.sh`, `extract-lk-ids.py` | made executable |
| `tests/test-stage-firmware.sh` | new, task 9 |

Not overwritten: `patches/`, `configs/`, `.github/` (I edited the workflow deliberately,
see task 5), and the archive's own top-level `README.md`, which describes the archive
rather than the project. `scripts/00-02` were left untouched.

## Task 2 — syntax and lint

```
bash -n   7/7 scripts OK (4 new + 3 existing + 2 device-tree helpers)
py_compile 4/4 OK
shellcheck 0.10.0 (static build; not in this image's apt sources)
```

shellcheck findings — **0 errors**, 1 warning, 11 notes. Nothing was rewritten.

| Code | Where | What |
|---|---|---|
| SC3028 ×5 | `shared/bin/set_wlan_mac.sh:16` | `$RANDOM` undefined in POSIX sh |
| SC2006 ×3 | `set_wlan_mac.sh:12,22,26` | backticks instead of `$( )` |
| SC2086 ×2 | `set_wlan_mac.sh:22,29` | unquoted expansion |
| SC2002 | `set_wlan_mac.sh:12` | useless `cat` |
| SC2035 | `00-backup-partitions.sh:17` | glob may be read as options |
| SC2012 | `fetch-prebuilt-kernel.sh:34` | `ls \| wc -l` |
| SC2015 | `start_remoteprocs.sh:10` | `A && B \|\| C` |

The SC3028 warning is very likely a false positive: the shebang is `#! /system/bin/sh`,
which on Android is mksh, and mksh does implement `RANDOM`. The rest are cosmetic.

## Task 3 — fetch the release

First run failed at the decompress step:

```
scripts/fetch-prebuilt-kernel.sh: line 31: zstd: command not found
```

Not a script bug — `zstd` was missing from the container. It is a **missing preflight
check**, though: the header documents the dependency, but the script downloads ~200 MB
before discovering it. A `command -v zstd >/dev/null || die` at the top would fail fast.
Not changed, per the "do not rewrite silently" rule.

Second run:

```
Image.gz: OK
sdm636-xiaomi-tulip.dtb: OK
sdm636-xiaomi-whyred-shenchao.dtb: OK
sdm636-xiaomi-whyred-tianma.dtb: OK
modules.tar: OK
installed: 83 modules, kernel + dtbs in .../shared/prebuilt-kernel/android-mainline
kernel release in the modules: 7.2.3-sdm660+
```

- sha256: **5/5 pass** against the release's own `SHA256SUMS`.
- `modules.all` names: **all present**. The script exits 1 on a missing name and it did
  not, and the CI guard (task 5) independently confirmed 83/83.
- `modules/` total uncompressed size: **181,681,771 bytes** (174 MiB).
- 83 unique names = 78 (tulip) ∪ 68 (whyred), overlap 63.

## Task 4 — module selection re-run

No kernel config changed, so this was a consistency check. Re-ran
`select-modules.py` for all three DTBs against the release's module tree:

| DTB | enabled compatibles | direct | with deps | compressed |
|---|---:|---:|---:|---:|
| tulip | 130 | 34 | 78 | 45.7 MB |
| whyred-tianma | 126 | 31 | 68 | 42.1 MB |
| whyred-shenchao | 126 | 31 | 68 | 42.1 MB |

| Compared | Result |
|---|---|
| `tulip/modules.all` | identical, 78 lines |
| `whyred/modules.all` | same 68 names, different order only |
| `docs/dt-coverage/*` | identical, 10 lines each |

The order difference is cosmetic: the committed `whyred/modules.all` is alphabetical,
the script emits dependency-closure order. `tulip/modules.all` is in closure order, so
the two files were produced differently. The fetch script reads line by line, so nothing
depends on it. **Nothing committed** — there is no semantic change to record.

## Task 5 — CI guard

Added to `.github/workflows/build-kernel.yml`, after the build and before checksums:
unpacks `modules.tar`, resolves the module root from `modules.dep`, and fails with an
annotated error for any name in `{tulip,whyred}/modules.all` that has no `.ko`/`.ko.zst`.

Tested locally against the real `modules.tar`:

- positive: all 83 unique names found → pass
- negative: injected `definitely_not_a_module` → `MISSING definitely_not_a_module (tulip)`, rc=1

## Task 6 — LK IDs: still blocked

No stock `boot.img` was provided, so patch 0004 was not written and no values were
invented. The premise was verified with `extract-lk-ids.py`:

```
sdm636-xiaomi-tulip.dtb      model=Xiaomi Redmi Note 6 Pro            msm-id=- board-id=- pmic-id=-
sdm636-xiaomi-whyred-tianma  model=Xiaomi Redmi Note 5 Pro (Tianma)   msm-id=- board-id=- pmic-id=-
Image.gz-dtb-tulip           DTB found at offset 0xcd2131, same three properties absent
```

So the extractor works on both a bare DTB and an appended-DTB image, and the mainline
DTBs really do lack the properties. To unblock:

```
adb shell su -c 'dd if=/dev/block/by-name/boot of=/sdcard/boot.img'   # or pull from a ROM zip
python3 scripts/extract-lk-ids.py boot.img --dump stock-dtbs/
```

## Task 7 — AOSP build

Not attempted, as instructed. It needs ~300 GB disk and 32 GB+ RAM; the runner has
55 GB free and 15 GiB.

## Task 8 — checkpatch and W=1

`scripts/checkpatch.pl --no-tree`, per patch:

| Patch | Errors | Warnings | Checks |
|---|---:|---:|---:|
| 0001 xt_quota2 (+LOG) | **2** | 12 | 12 |
| 0002 uid_sys_stats | 0 | 6 | 0 |
| 0003 fsync counter | 0 | 0 | 0 |

The two 0001 errors are `code indent should use tabs where possible`. Warnings include
`simple_strtoull is obsolete, use kstrtoull instead`, `do not add new typedefs`, two
`no space before tabs`, block-comment style, and a missing SPDX identifier. 0002's
warnings are `Prefer kzalloc_obj/kmalloc_obj over ... with sizeof` (a 7.x check),
missing SPDX, filename in file, and a missing blank line after declarations. All of this
is inherited 4.19-era code, and all of it is style.

`make W=1` on the touched translation units (`uid_sys_stats.o`, `xt_quota2.o`, `sync.o`):

```
gcc-format warnings: 0
gcc-format errors:   0
kernel-doc warnings: 16   (all in net/netfilter/xt_quota2.c)
```

The kernel-doc ones are real but documentation-only: the `struct xt_quota_counter`
comment block is malformed for kernel-doc, and `q2_get_counter`'s doc names the wrong
parameters (`q` not described, `name` excess). Worth fixing in the source; no runtime
effect.

## Task 9 — stage-firmware test

`tests/test-stage-firmware.sh` builds a fake stock tree (14 files across
`firmware_mnt/image`, `vendor/firmware`, `vendor/firmware/qcom/venus-4.4`,
`vendor/firmware/ath10k/WCN3990/hw1.0`, `bt_firmware/qca`), runs the script into a temp
device dir, and checks:

- `device.mk` header and `PRODUCT_COPY_FILES += \`
- each of the 14 files staged **and** listed with the exact
  `...:<$(TARGET_COPY_OUT_VENDOR)/firmware/...` pair
- sibling `.b00`/`.b01` fragments copied from the same directory as the `.mdt`
- no `MISSING` for a complete tree; `MISSING` reported for an empty one
- empty tree still writes a valid, empty `device.mk`
- unknown device name rejected
- re-running clears stale files instead of appending

Result: **PASS**. No real firmware is in the repo; the fake files are text.
It is wired into CI as the `Lint scripts and run tests` step.

---

## Summary

| Task | Status |
|---|---|
| 1 merge | done |
| 2 syntax/lint | done, findings reported, nothing rewritten |
| 3 fetch + verify | done: 5/5 sha256, 83/83 modules, 181,681,771 B |
| 4 module re-run | done: no semantic change, nothing committed |
| 5 CI guard | done, tested positive and negative |
| 6 LK ids | **blocked on your stock boot.img** |
| 7 AOSP build | not attempted (by instruction) |
| 8 checkpatch / W=1 | done: 2 errors, 18 warnings, 0 compile diagnostics |
| 9 firmware test | done, passing, in CI |

Open items: the stock `boot.img` for LK ids; a decision on the two tab-indent errors and
the kernel-doc block in `xt_quota2.c`; and a preflight dependency check in
`fetch-prebuilt-kernel.sh`.

---

# v7 drop — LK ids unblocked

Your stock `boot.img` arrived at `/workspace/project/boot.img` (36,368,384 B). v7 adds
patch 0004, `scripts/make-bootimg.sh`, `docs/STOCK_BOOT_PARAMS.md`, and updates
`LK_IDS.md`, `OPENHANDS_TASKS.md`, `JOURNAL_APPEND.md`. `android/` is byte-identical to
v5 (`diff -r` clean).

## Task 6 — patch 0004 applied and verified

Parsed the stock image with `extract-lk-ids.py`: **52 DTBs**, matching
`STOCK_BOOT_PARAMS.md`. The two Xiaomi ones:

| Stock DTB | model | msm-id | board-id |
|---|---|---|---|
| #43 @0x1e80a75 | SDM 636 PM660 + PM660L MTP **E7T** | `0x159 0x00` | `0x40008 0x00` |
| #12 @0x158c09b | SDM 636 PM660 + PM660L **E7S** | `0x159 0x00` | `0x30008 0x00 0x10008 0x00` |

`git apply --check` then `git apply` of `patches/0004-*.patch` on the kernel tree:
clean. Rebuilt the three DTBs (`make qcom/sdm636-xiaomi-*.dtb`):

| DTB | before | after |
|---|---:|---:|
| tulip | 58,610 | 58,733 |
| whyred-tianma | 56,786 | 56,933 |
| whyred-shenchao | 56,786 | 56,933 |

`extract-lk-ids.py` on each rebuilt DTB reports exactly the stock values above, including
the full `pmic-id` lists. Values were not altered.

## Task 10 — test boot images

No postmarketOS initramfs exists in this environment, so I built a **minimal** one rather
than pretend: `tests/minimal-initramfs/init.c`, a static init that mounts
devtmpfs/proc/sys, prints `MAINLINE BOOT OK`, and powers off. 758,984 B binary,
325,505 B `cpio.gz`. It is labelled as not-postmarketOS everywhere it appears.

`scripts/make-bootimg.sh` (mkbootimg from Debian's `mkbootimg` package) produced:

| Image | Bytes | Header |
|---|---:|---|
| `boot-tulip-test.img` | 13,836,288 | page 4096, kernel `0x8000`, ramdisk `0x01000000`, tags `0x100`, v0 |
| `boot-whyred-test.img` | 13,832,192 | same (tianma DTB) |

Parsed the `ANDROID!` header of both to confirm those fields, and re-ran
`extract-lk-ids.py` on `boot-tulip-test.img` — the appended DTB carries the IDs.
CI now builds and checksums both images.

## Task 11 — source fixes

**Preflight** in `fetch-prebuilt-kernel.sh`. Negative test with a PATH lacking `zstd`:

```
missing dependency: zstd
exit=1
```

**kernel-doc** in patch 0001: gave `struct xt_quota_counter` a proper short description
and documented all six members; `q2_get_counter` now documents `@q` instead of a
non-existent `@name`.

```
kernel-doc warnings before: 16
kernel-doc warnings after:   0
```

Regenerated the patch with `git diff` and verified it applies to a pristine tree
(`git apply --check` after reverting Kconfig/Makefile and deleting the new files), then
reproduced the edited files byte for byte.

Proving the comment edit cannot change the shipped kernel: rebuilt `xt_quota2.o` and
compared every code section against the pre-edit object.

```
.text: identical (2348 B)   .rodata: identical (196 B)
.data: identical (28 B)     .init.text: identical (288 B)
only .debug_info grew: 0x2118a -> 0x2118c
```

So `Image.gz` is unchanged, and it is shipped unchanged.

## Checks re-run

- `bash -n` 6/6 scripts OK; `python3 -m py_compile` OK.
- shellcheck (0.10.0) on `scripts/*.sh`: 3 notes (SC2012, SC2015, SC2035), **0 warnings,
  0 errors**. Nothing rewritten.
- `select-modules.py`: not re-run — no kernel config changed. `modules.all` and
  `docs/dt-coverage/*` are unchanged, which is why `modules.tar` is the same file.

## Not done

AOSP build (by instruction), anything on hardware. `FEATURE_MATRIX.md` remains untested.
