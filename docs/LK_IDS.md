# Bootloader IDs (qcom,msm-id / qcom,board-id)

**UPDATE 2026-11-23: resolved on paper.** Values extracted from the uploaded stock boot.img are in docs/STOCK_BOOT_PARAMS.md and applied by patches/0004. Still unproven on hardware: whether LK accepts the resulting DTB.


Verified: the mainline `sdm636-xiaomi-tulip.dtb` from release v7.2.3-sdm660-r1 contains NO `qcom,msm-id`, `qcom,board-id` or
`qcom,pmic-id` property (scripts/extract-lk-ids.py reports `-` for all three).

Xiaomi SDM660 phones use an LK bootloader that selects an appended DTB by those IDs. A boot image that appends a DTB without
them may be rejected or fail silently. I do not know the right values and will not guess them.

## Steps (needs your stock boot.img from 00-backup-partitions.sh)
1. `python3 scripts/extract-lk-ids.py backup-*/boot.img --dump stock-dtbs/`
2. Pick the DTB whose model/compatible matches your phone. Copy its three properties.
3. Add them to the root node of `sdm636-xiaomi-tulip.dts` as a new kernel patch (0004), for example:
   ```
   / {
           qcom,msm-id = <...>;      /* from stock */
           qcom,board-id = <...>;    /* from stock */
   };
   ```
   Add `qcom,pmic-id` only if the stock DTB has it. Repeat for whyred-tianma / whyred-shenchao.
4. Rebuild the DTBs in CI, then `fastboot boot` a test image.

If the stock bootloader turns out not to need them (it boots a DTB-less or v2 `--dtb` image), skip this and record it in the journal.
