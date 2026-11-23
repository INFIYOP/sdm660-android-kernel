# Boot image parameters read from the uploaded boot.img (2026-11-23)

Parsed from the ANDROID! header and the 52 appended DTBs (scripts/extract-lk-ids.py). This is a downstream 4.19 kernel image.

| Field | Value |
|---|---|
| Header version | 0 (legacy, A-only) |
| Page size | 4096 |
| Kernel load addr | 0x8000  -> base 0x0, kernel_offset 0x8000 |
| Ramdisk addr | 0x1000000 -> ramdisk_offset 0x01000000 |
| Tags | 0x100 |
| Second stage | none |
| DTBs | 52 appended after the kernel (raw, uncompressed) |
| Stock cmdline boot device | `androidboot.boot_devices=soc/c0c4000.sdhci` (downstream name; mainline path is `soc@0/c0c4000.mmc`) |

These match the defaults in scripts/make-bootimg.sh and BoardConfig.mk (which came from LineageOS), so nothing needed changing there.

## Bootloader IDs of the Xiaomi DTBs in this image
| DTB | model string in stock DTB | qcom,msm-id | qcom,board-id | qcom,pmic-id |
|---|---|---|---|---|
| #43 | SDM 636 PM660 + PM660L MTP **E7T** | 0x159 0x00 | 0x40008 0x00 | 0x1001b 0x101011a 0x00 0x00 / 0x1001b 0x201011a 0x00 0x00 |
| #12 | SDM 636 PM660 + PM660L **E7S** | 0x159 0x00 | 0x30008 0x00 0x10008 0x00 | 0x1001b 0x101011a 0x00 0x00 / 0x1001b 0x201011a 0x00 0x00 / 0x1001b 0x102001a 0x00 0x00 |

Mapping to phones (E7T = tulip, E7S = whyred) is by Xiaomi model number (tulip M1806E7T, whyred M1803E7S); it is not printed anywhere in the image.
Verify on the phone: `getprop ro.product.model` or the label in the stock ROM should end in E7T for tulip.

Patch 0004 (patches/0004-arm64-dts-qcom-add-lk-ids-for-tulip-and-whyred.patch) copies these values into the mainline dts.
