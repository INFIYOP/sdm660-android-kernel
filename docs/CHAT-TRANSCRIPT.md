> **AI disclosure:** this document was prepared by an AI agent (OpenHands) on behalf of INFIYOP. Verify anything before acting on it.

# Chat transcript — 2026-11-22

Condensed transcript of the session that produced this repository and release.

- **User messages** are reproduced verbatim, typos included, as a record.
- **Assistant replies** are summarised (bullets), not verbatim — the originals were long
  and heavily formatted. Nothing material is omitted.

The session started as a Vulkan-upgrade question and ended as a mainline kernel build.
The middle is worth keeping because it is where the actual limits got established.

---

## Turn 1

**User:**

> I'm thinking of upgrading the Vulcan support of my devices, which are Redmi Note 6 Pro and 5 Pro. But first, we'll focus on 6 Pro, and then we'll do 5 Pro if we succeed. I found out that we can do that by only updating things in the firmware, and the firmware where vendor is. So, make a plan, how should we do this?

**Assistant (summary):**

- Identified both devices as SDM636 / Adreno 509, Android 9 (Pie) vendor, standalone
  `vendor` partition (no `super`), Vulkan 1.0 exposed.
- Key point: Vulkan version is decided by the userspace driver (`libGLESv2_adreno.so`,
  `vulkan.adreno.so`), not the kernel; Pie's `libvulkan.so` loader already understands 1.1.
- Plan: Phase 0 baseline recon (getprop, `dumpsys SurfaceFlinger`, blob inventory) →
  Phase 1 donor selection → Phase 2 Magisk `/vendor` overlay instead of flashing a
  partition (avoids AVB/vbmeta, easy rollback) → Phase 3 verify + stress → Phase 4
  rollback → Phase 5 repeat for whyred.
- Warnings: ARB (never flash older firmware), AVB/dm-verity, don't cross Android majors,
  blobs are a matched set, replace both `lib` and `lib64`.
- Asked for: current MIUI/fingerprint, root status, the actual target app, and whether a
  stock fastboot ROM exists.

## Turn 2

**User:**

> Bro that's the thing we have to port the drivers no same soc has better vulken

**Assistant (summary):**

- Reframed as a port. Split the problem into three axes: GPU family, Android version,
  kernel/KGSL. Ranked them: GPU family is the cheap one (Adreno 5xx driver is chip-ID
  driven, one binary covers 505/506/508/509/510/512), Android version is the expensive one.
- Recommended picking the donor with the smallest **Android** gap, not the smallest SoC
  gap — and noted Nokia 6.1 Plus (`DRG`) is SDM636/Adreno 509 on Android 10.
- Gave the core method: port by **symbol diff**, offline —
  `readelf -d` for `DT_NEEDED`, `readelf --dyn-syms` for undefined symbols, compare
  against the target vendor's exports, `comm -23`. That produces a finite work list
  before anything is flashed.
- Landmines in order of likelihood: `libc++_shared.so` vs `libc++.so` symbol versions,
  `android.hardware.graphics.mapper@3.0` vs `@2.0/@2.1`, `libgrallocusage`/`libqdMetaData`,
  KGSL ioctl gaps.
- 30-minute probe: overlay only `vulkan.adreno.so` + `libgsl` + `libllvm-glnext` +
  `libadreno_utils`, boot, read `logcat | grep -E 'linker|vulkan'`.
- Fallback ladder from "Vulkan blob only" to "abandon vendor-only, use an Android 10+ ROM".

## Turn 3

**User:**

> Adreno 5xx on Android 10 reports Vulkan 1.1 (that's the 512.4xx/512.5xx driver line). 6xx blobs are a dead end — the driver's chip table won't contain 509.
>
> Exactly why we make our own instead of port from sco sdm 660 gpu drivers

**Assistant (summary):**

- Split "make our own" into three different projects: (A) patch the 509 blob,
  (B) write a 1.1 facade ICD over the 1.0 driver, (C) write a driver from scratch.
  C is impossible (no public a5xx ISA/register docs).
- The decisive 2-minute test: does `vulkan.adreno.so` export
  `vkEnumerateInstanceVersion` and the 1.1 `*2` entrypoints? If yes, the 1.1 code is
  compiled in and this is a constant patch. If no, it is a facade project.
- Route A patch sites: `vkEnumerateInstanceVersion` (writes `VK_MAKE_VERSION(1,0,0)`),
  `VkPhysicalDeviceProperties::apiVersion`, and the chip-capability gate function.
  Patching only the first yields a driver that lies.
- Route B: what can be emulated honestly (`GetDeviceQueue2`, `Properties2`,
  `BindBufferMemory2`) vs what cannot (multiview, 16-bit storage, YCbCr, protected memory).
- Corrected the chip-table argument: it rules out **6xx** blobs, not **5xx** blobs. A 5xx
  Android 10 build is still a 5xx build and does contain 509.

## Turn 4

**User:**

> Listen rn we have vulken 1.1 or something right which isant good let's try to port vulken 1.4 or 1.3

**Assistant (summary):**

- Hard no, with reasons: minor versions are cumulative mandatory feature floors.
- 1.2 needs `bufferDeviceAddress` (64-bit shader addresses); 1.3 needs
  `shaderIntegerDotProduct` (DP4A) and `subgroupSizeControl`; 1.4 needs
  `dynamicRenderingLocalRead` and `shaderSubgroupRotate`. None exist on a5xx.
- The deeper wall is `libllvm-glnext.so`: a closed SPIR-V→a5xx compiler that cannot be
  extended. You cannot implement 1.2+ entrypoints without it.
- Evidence: no a5xx device anywhere reports above 1.1; Mesa turnip targets a6xx+.
- 30-second falsification test: `nm -D | grep -E 'CmdBeginRendering|QueueSubmit2|GetBufferDeviceAddress'`.
- Spoofing the number fails on the first real 1.3 call, because the loader builds its
  dispatch table from `vkGetDeviceProcAddr`.

## Turn 5

**User:**

> Vulken 1.2?

**Assistant (summary):**

- 1.2 is the only one of the three worth discussing, because roughly half of it is API
  surface rather than silicon.
- Table: shimmable (`CreateRenderPass2`, `imageless_framebuffer`,
  `separate_depth_stencil_layouts`, timeline semaphores, `draw_indirect_count`) vs
  hardware (`buffer_device_address`) vs compiler (`descriptor_indexing`,
  `shader_float16_int8`, `scalar_block_layout`, SPIR-V 1.4, memory model).
- Verdict: conformant 1.2 impossible; **non-conformant** 1.2 can satisfy a specific app
  that only touches the shimmable rows.
- Loader detail: Pie's `libvulkan.so` caps at 1.1, so a layer must report 1.2 upward and
  pass 1.1 downward in `vkCreateInstance`.

## Turn 6

**User:**

> Bro it's not missing any silicon is it?

**Assistant (summary):**

- Conceded the point partially: split into (1) real silicon, (2) compiler/driver policy,
  (3) pure API surface.
- Real silicon: 32-bit GPU VA (`bufferDeviceAddress`), no DP4A, no tile local read, fixed
  wave64.
- Policy, not silicon: `shaderFloat16` — a5xx *can* do fp16 (it is a GLES 3.2 part),
  Qualcomm's Vulkan backend just doesn't expose it. Also `descriptorIndexing`,
  `scalar_block_layout`, `uniform_buffer_standard_layout`, SPIR-V 1.4, memory model.
- Corrected my own earlier "half silicon" statement: it is ~10 API-surface, ~5 compiler,
  2 silicon — but one silicon item (`bufferDeviceAddress`) is enough.
- Confidence stated: the 32-bit VA claim comes from freedreno's reverse-engineered model,
  not a Qualcomm datasheet.
- Reframed the practical point: whether silicon or firmware, the missing artifact is the
  same closed compiler + driver, so the deliverable and cost are identical.

## Turn 7

**User:**

> Then if we push it how much can we upgrade

**Assistant (summary):**

- Ceiling table: genuine 1.1 (days) → full 1.1 feature set (days) → extension surface
  (1–2 weeks, best value) → non-conformant 1.2 (weeks, narrow) → conformant 1.2 (no) →
  1.3/1.4 native (no) → 1.3/1.4 via software ICD (weekend, 2–10 fps).
- Realistic maximum: **1.1 with a wider extension list**, never a higher number.
- No performance gain from blobs; GPU clock lives in the kernel.
- Flagged that if the current 1.1 is itself a spoof, the real baseline is lower and step
  one is genuine 1.1.

## Turn 8

**User:**

> What dose minecraft need

**Assistant (summary):**

- Bedrock: OpenGL ES 3.1/3.2 (RenderDragon). Vulkan irrelevant. Device already meets it.
- Java via PojavLauncher: ≤1.16 uses GL4ES (GLES), 1.17+ uses Zink (OpenGL on Vulkan),
  which needs **Vulkan 1.1** — already present.
- Expected fps: Bedrock fine at low settings; Java 1.8–1.12 30–60 fps; 1.17+ via Zink 5–20 fps.

## Turn 9

**User:**

> Like java need not pojav

**Assistant (summary):**

- Without Pojav the options are FCL / Zalith / Boardwalk (same Pojav core), Winlator
  (needs Turnip for Vulkan, and Turnip has no a5xx support), or Termux + X11 + Mesa.
- All of them need OpenGL 3.2 for 1.17+, which on this hardware means Zink over Vulkan 1.1.
- Java requirements: JDK 8/17/21 depending on version, 1–2 GB allocated, GL 3.2 core, ~1 GB storage.
- Practical recommendation: FCL + GL4ES on 1.12.2 or 1.8.9.

## Turn 10

**User:**

> Bro pc minecraft java vulken version need

**Assistant (summary):**

- Vanilla PC Java uses **OpenGL 3.2 core, not Vulkan**. No setting changes that.
- The only Vulkan path is the **VulkanMod** mod, documented as requiring **Vulkan 1.2**.
- Therefore: the only Minecraft that wants more than 1.1 wants exactly 1.2, which a5xx
  cannot do. Loop closed.
- Table: vanilla Java ✅ via Zink/GL4ES; Java + VulkanMod ❌; Bedrock ✅.

## Turn 11

**User:**

> Bro it dose now

**Assistant (summary):**

- Checked instead of arguing. Correction: the user was right.
- Timeline from the Minecraft Wiki: **26.2** (2026-06-16) added an experimental Vulkan
  renderer; **26.3** (2026-09-15) kept it; **26.4** snapshots make Vulkan the default and
  drop the "experimental" label.
- Verbatim requirement from the 26.2 notes: *"Vulkan 1.2 with dynamic rendering and push
  descriptors"*, i.e. `VULKAN_CORE_1_2` + `VK_KHR_dynamic_rendering` +
  `VK_KHR_push_descriptor`.
- Failure path: `vulkan_device_version_too_low` → falls back to OpenGL.
- Consequence on the phone: Minecraft rejects Vulkan 1.1, falls back to OpenGL, which
  Pojav/FCL provides via Zink → back to Vulkan 1.1 one layer down.
- Noted the requirement "may increase or decrease over time", so chasing it is a moving target.

## Turn 12

**User:**

> Can you build this
>
> NEW FILES ADDED: mainline-port-kit-v3.zip

**Assistant (summary):**

- Found and unpacked the kit; read all six docs and the scripts.
- Installed the cross toolchain; cloned `sdm660-mainline/linux` @ `qcom-sdm660-7.2.y`
  (7.2.3, `5690ded61`).
- Applied patches 0001-0003 cleanly; generated the config; verified all 36 fragment
  options resolve to `=y`.
- Built `Image.gz` (13.4 MB) and three DTBs whose sizes match the kit byte-for-byte.
- Discovered the kit's CI does not build modules (532 options are `=m`), and that
  `modules_install` fails with `Error 127` without `zstd`; added `zstd` + `kmod`, built
  and installed 688 modules with `depmod`.
- `boot.img` deliberately not built: `PAGESIZE`/`BASE`/`KERNEL_OFFSET`/`CMDLINE` must
  come from the stock `boot.img`.
- Restated that none of this changes the Vulkan ceiling.

## Turn 13

**User:**

> Make got release of this and also about everything you did and your notes and this whole chat

**Assistant (summary):**

- Populated `INFIYOP/sdm660-android-kernel` with the kit (docs, patches, configs, DTBs,
  scripts), a corrected CI workflow, and three new documents:
  `docs/RELEASE-NOTES.md`, `docs/SESSION-NOTES.md`, `docs/CHAT-TRANSCRIPT.md`.
- Cut release `v7.2.3-sdm660-r1` with `Image.gz`, `Image.gz-dtb-tulip`, the three DTBs,
  `modules.tar`, the resolved `.config` and `SHA256SUMS`.

---

## Conclusions, in one place

1. **Vulkan on a5xx stops at 1.1.** 32-bit GPU VA blocks 1.2; DP4A and subgroup-size
   control block 1.3; tile local read blocks 1.4. This is silicon plus a closed compiler,
   not a firmware omission.
2. **Porting does not move the version.** At best it yields genuine 1.1 plus a wider
   extension surface.
3. **Minecraft Java 26.2+ requires Vulkan 1.2** and will fall back to OpenGL on these
   phones forever.
4. **Mainline Linux is a separate, achievable goal** — it gives freedreno OpenGL and a
   maintainable kernel, and it builds cleanly. That is what this release ships.

---

# Session 2 — dropping Vulkan, merging v5, first testing build

Same day, later. The conversation moved from "can we raise Vulkan" to "ship the
mainline tree", which is where session 1's conclusions pointed.

## Turn 14

**User:**

> Also we are developing ng mainline drop vulken for now

**Assistant (summary):**

- Read it as: new mainline drop, Vulkan dropped.
- Recorded decision **D003** in `JOURNAL.md`: a5xx cannot exceed 1.1 — 32-bit GPU VA
  blocks `bufferDeviceAddress`, no DP4A or subgroup-size control, no tile local read,
  `libllvm-glnext` is closed, turnip is a6xx+. Freedreno OpenGL is the graphics path.
- Rewrote the Vulkan sections of `README.md` and `PLAN.md` from "here is the upgrade
  path" to "out of scope", so the next session does not re-litigate it.
- Committed `0cc37eb` and dispatched CI to validate the workflow fixes.

## Turn 15

**User:**

> NEW FILES ADDED: mainline-port-android-v5.zip
> NEW FILES ADDED: mainline-port-android-v5.zip

**Assistant (summary):**

- Unpacked v5: an AOSP device tree for `tulip`/`whyred` (141 files), four scripts
  (`fetch-prebuilt-kernel.sh`, `select-modules.py`, `stage-firmware.sh`,
  `extract-lk-ids.py`), and `docs/FIRMWARE.md`, `LK_IDS.md`, `OPENHANDS_TASKS.md`,
  `JOURNAL_APPEND.md`, `dt-coverage/`.
- Ran the nine tasks in `OPENHANDS_TASKS.md`:
  - merged without touching `patches/`, `configs/` or `scripts/00-02`;
  - `bash -n` 7/7, `py_compile` 4/4, shellcheck 0 errors (one `$RANDOM` false positive
    under mksh, plus notes);
  - `fetch-prebuilt-kernel.sh`: 5/5 sha256, 83 modules, 181,681,771 B uncompressed;
  - `select-modules.py` re-run matched the committed files (whyred differed in ordering
    only);
  - added a CI guard that fails when a `modules.all` name is missing from `modules.tar`,
    tested positive and negative;
  - verified the LK-id premise and left patch 0004 blocked on a stock `boot.img`;
  - checkpatch 0001 2E/12W, 0002 0E/6W, 0003 clean; `make W=1` 0 compiler diagnostics,
    16 kernel-doc warnings in `xt_quota2.c`;
  - wrote `tests/test-stage-firmware.sh` (fake stock tree), passing and in CI.
- Two CI runs went green. Report: `docs/COMPILE-AGENT-REPORT.md`.

## Turn 16

**User:**

> Did you kernel build test and upload it on GitHub with the same way as last time

**Assistant (summary):**

- Answered plainly: built and tested yes, but in CI; released no.
- Showed the state: three green runs, one Actions artifact, and a single release
  (`v7.2.3-sdm660-r1`) whose tag points at `9a7e6a2`, i.e. before the v5 merge.
- Explained why there was no local rebuild: the v5 drop changes no kernel source, so the
  binaries are identical to r1.
- Flagged that the CI artifact is 2.4 GB because `upload-artifact` follows the
  `build`/`source` symlinks into the kernel tree.
- Offered to cut a release.

## Turn 17

**User:**

> These are in testing fase not release candidate
>
> Make a git release of the kernel v5 build with all info and this chat history

**Assistant (summary):**

- Verified the local artifacts against r1's published `SHA256SUMS` — all seven match
  byte for byte, turning "the kernel did not change" into a measured fact.
- Wrote `docs/RELEASE-NOTES-v5-testing.md`, extended this transcript with session 2, and
  published `v5-testing` as a **pre-release**: testing phase, explicitly not a release
  candidate.

## Turn 18

**User:**

> also i have put the boot image in you directorey
>
> NEW FILES ADDED: mainline-port-android-v7 (1).zip

**Assistant (summary):**

- Found `/workspace/project/boot.img` (the earlier search had run before the upload).
- Parsed it: 52 appended DTBs; E7T (#43) `board-id 0x40008 0x00`, E7S (#12)
  `board-id 0x30008 0x00 0x10008 0x00`, both `msm-id 0x159 0x00` — matching
  `docs/STOCK_BOOT_PARAMS.md` exactly, so the values were not taken on trust.
- Merged v7 (android/ byte-identical to v5), applied patch 0004, rebuilt the three DTBs and
  confirmed each now carries the ids.
- Built `boot-tulip-test.img` and `boot-whyred-test.img` with a minimal static initramfs,
  labelled as not-postmarketOS, and verified the `ANDROID!` header against the stock layout.
- Fixed the `xt_quota2.c` kernel-doc (16 → 0 warnings) and proved the change cannot alter
  codegen: every code section of the rebuilt object is identical.
- Added the fetch-script dependency preflight and tested it negatively.
- Published `v7-testing` as a pre-release.
