# Firmware the mainline kernel asks for (tulip / whyred)

Only firmware is reused from the stock vendor side. Names below are taken from the mainline device trees and driver source
in qcom-sdm660-7.2.y; "stock location" is where such files are typically found on Xiaomi SDM660 images and must be checked on
your own images. Kernel search path is /vendor/firmware (cmdline `firmware_class.path=/vendor/firmware/`).

| Consumer | File requested | Where the name comes from | Typical stock location | Notes |
|---|---|---|---|---|
| Modem (remoteproc_mss) | `mba.mbn`, `modem.mdt` (+ `modem.bNN`) | `firmware-name` in tulip.dts / whyred-common.dtsi | firmware_mnt/image (NON-HLOS) | verified in dts |
| ADSP (adsp_pil) | `adsp.mdt` (+ `adsp.bNN`) | default in `qcom_q6v5_pas.c` (`adsp_resource_init`) | firmware_mnt/image | dts sets no override |
| GPU zap shader | `a512_zap.mbn` | `&adreno_gpu_zap firmware-name` | vendor/firmware | stock often has `a512_zap.mdt` + `.bNN` instead of one `.mbn`. UNVERIFIED: if only split files exist, try copying `a512_zap.mdt` to the `.mbn` name and read dmesg |
| Venus video | `qcom/venus-4.4/venus.mdt` (+ `.bNN`) | `&venus firmware-name` | vendor/firmware/venus.* | verified in dts |
| Wi-Fi (WCN3990, ath10k_snoc) | files under `ath10k/WCN3990/hw1.0/` (`firmware-5.bin`, `board-2.bin`, `wlanmdsp.mbn`) | `WCN3990_HW_1_0_FW_DIR` in ath10k hw.h | wlanmdsp.mbn in firmware_mnt/image | UNVERIFIED which of the three the driver needs on this board. Stock board data (bdwlan.*) is not the same format as `board-2.bin`; ath10k firmware is also available from linux-firmware. Read dmesg |
| Bluetooth (WCN3990) | `qca/crbtfw<rom>.tlv`, `qca/crnv<rom>.bin` | name pattern in `btqca.c` for WCN399x | bt_firmware / vendor/firmware | `<rom>` = chip ROM version, known only at runtime |
| rmtfs (modem storage) | partitions `modemst1`, `modemst2`, `fsg`, `fsc` | `rmtfs -P` in init.vendor.rc; file_contexts | eMMC partitions, not files | back up with scripts/00-backup-partitions.sh first |

## Use
1. Extract/mount your stock images so one directory holds vendor/firmware, firmware_mnt (NON-HLOS) and bt_firmware.
2. `scripts/stage-firmware.sh <that_dir> tulip` (or `whyred`). It reports found/missing per pattern and writes
   `android/device/generic/sdm660/<device>/firmware/device.mk`. Files go to a git-ignored `vendor-firmware/` and are not redistributed.
3. On the phone: `dmesg | grep -i -E "firmware|fw"` shows the exact filenames requested; fix any mismatch here, not by guessing.

The staging logic was tested only against a fake file tree, not against real stock images.
