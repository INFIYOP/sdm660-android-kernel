# Tasks for the compile agent (OpenHands / GitHub Actions)

Rules: do not claim anything boots; only report what you actually ran. Keep the "AI disclosure" line on generated docs.
Claude writes source; this agent compiles, runs checks and reports logs.

1. Merge this archive into the repo root (new dirs: `android/`, `docs/`; new scripts in `scripts/`). Do not overwrite `patches/`, `configs/`, `.github/`.
2. Run `bash -n scripts/*.sh` and `python3 -m py_compile scripts/*.py`; run `shellcheck` if available. Report findings, do not rewrite the scripts silently.
3. Run `scripts/fetch-prebuilt-kernel.sh v7.2.3-sdm660-r1` and confirm: sha256 check passes, every name in `android/device/generic/sdm660/{tulip,whyred}/modules.all` exists in the release, and report the total uncompressed size of `modules/`.
4. After any kernel config change, re-run `scripts/select-modules.py --modroot <lib/modules/REL> --dtb <dtb> --out <dir>` for tulip and both whyred DTBs. Commit the new `modules.all` and `docs/dt-coverage/*` and report what changed.
5. In CI, add a step that fails the build if a module in `modules.all` is missing from `modules.tar`.
6. Kernel patch 0004 (LK ids) is BLOCKED until the user supplies output of `scripts/extract-lk-ids.py` from their stock boot.img (docs/LK_IDS.md). Do not invent values.
7. Do NOT try the AOSP build on a hosted runner: it needs roughly 300 GB disk and 32 GB+ RAM. It is a separate step on a larger machine.
8. For each patch 0001-0003, also run `scripts/checkpatch.pl --no-tree` from the kernel tree and `make W=1` on the touched files; report warnings.
9. Add a unit-style test for scripts/stage-firmware.sh that builds a fake stock tree (as in docs/FIRMWARE.md) and checks the generated device.mk. Do not add real firmware to the repo.
