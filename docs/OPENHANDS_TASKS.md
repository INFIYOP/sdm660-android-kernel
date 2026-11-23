# Tasks for the compile agent (OpenHands / GitHub Actions)

Rules: do not claim anything boots; only report what you actually ran. Keep the "AI disclosure" line on generated docs.
Claude writes source; this agent compiles, runs checks and reports logs.

1. Merge this archive into the repo root (new dirs: `android/`, `docs/`; new scripts in `scripts/`). Do not overwrite `patches/`, `configs/`, `.github/`.
2. Run `bash -n scripts/*.sh` and `python3 -m py_compile scripts/*.py`; run `shellcheck` if available. Report findings, do not rewrite the scripts silently.
3. Run `scripts/fetch-prebuilt-kernel.sh v7.2.3-sdm660-r1` and confirm: sha256 check passes, every name in `android/device/generic/sdm660/{tulip,whyred}/modules.all` exists in the release, and report the total uncompressed size of `modules/`.
4. After any kernel config change, re-run `scripts/select-modules.py --modroot <lib/modules/REL> --dtb <dtb> --out <dir>` for tulip and both whyred DTBs. Commit the new `modules.all` and `docs/dt-coverage/*` and report what changed.
5. In CI, add a step that fails the build if a module in `modules.all` is missing from `modules.tar`.
6. Kernel patch 0004 (LK ids) is UNBLOCKED: values come from the user's stock boot.img (docs/STOCK_BOOT_PARAMS.md). Add `patches/0004-*.patch`, make sure CI applies it, rebuild, then check each DTB with `python3 scripts/extract-lk-ids.py <dtb>` (tulip must show msm-id 0x159 0x00, board-id 0x40008 0x00; whyred 0x159 0x00 and 0x30008 0x00 0x10008 0x00). Report the result; do not change the values.
7. Do NOT try the AOSP build on a hosted runner: it needs roughly 300 GB disk and 32 GB+ RAM. It is a separate step on a larger machine.
8. For each patch 0001-0003, also run `scripts/checkpatch.pl --no-tree` from the kernel tree and `make W=1` on the touched files; report warnings.
9. Add a unit-style test for scripts/stage-firmware.sh that builds a fake stock tree (as in docs/FIRMWARE.md) and checks the generated device.mk. Do not add real firmware to the repo.
10. Have CI output a test boot.img per device: `scripts/make-bootimg.sh --kernel Image.gz --dtb <dtb> --ramdisk <postmarketOS initramfs> --out boot-<dev>.img`. Publish it in the release next to Image.gz. Do not publish an AnyKernel3 zip yet.
11. Known issues from your own report worth fixing in source (do not change kernel binaries without telling the user): add a dependency preflight (curl, tar, zstd, sha256sum) at the top of scripts/fetch-prebuilt-kernel.sh; fix the kernel-doc comment on struct xt_quota_counter and the q2_get_counter parameter names in patch 0001.
12. After step 6, publish the new DTBs (they change; Image.gz does not need to) as the next testing release.
