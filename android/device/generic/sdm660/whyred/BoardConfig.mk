include device/generic/sdm660/shared/BoardConfig.mk

TARGET_BOOTLOADER_BOARD_NAME := whyred
TARGET_BOARD_PLATFORM := sdm660
TARGET_SCREEN_DENSITY := 440
TARGET_OTA_ASSERT_DEVICE := whyred

# eMMC controller from sdm630.dtsi (mmc@c0c4000); SD card is mmc@c084000
BOARD_KERNEL_CMDLINE += androidboot.boot_devices=soc@0/c0c4000.mmc androidboot.hardware=whyred

# Sizes from LineageOS device tree for this phone (stock partition layout)
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 3221225472
BOARD_VENDORIMAGE_PARTITION_SIZE := 838860800
