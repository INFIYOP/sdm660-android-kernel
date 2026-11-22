# Shared board config for mainline-kernel AOSP on SDM636/SDM660-family phones.
# Derived from aospm/android_device_generic_sdm845 (Apache-2.0), adapted for SDM636.
# Arch/partition/kernel-base values follow LineageOS android_device_xiaomi_sdm660-common.
# UNVERIFIED on hardware. Compare BOARD_KERNEL_* against the stock boot.img (tools/extract-lk-ids.sh).

# Primary Arch (Kryo 260 = A73/A53 class)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a73

# Secondary Arch
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a73

TARGET_USES_64_BIT_BINDER := true

TARGET_NO_BOOTLOADER := true
TARGET_NO_KERNEL := false
TARGET_NO_RECOVERY := true

# Kernel/boot.img Configuration (A-only device, Xiaomi LK bootloader)
BOARD_KERNEL_BASE        := 0x00000000
BOARD_KERNEL_PAGESIZE    := 4096
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
BOARD_RAMDISK_OFFSET     := 0x01000000
BOARD_KERNEL_CMDLINE     := console=tty0 androidboot.console=ttyMSM0 no_console_suspend
BOARD_KERNEL_CMDLINE     += firmware_class.path=/vendor/firmware/ init=/init printk.devkmsg=on
BOARD_KERNEL_CMDLINE     += deferred_probe_timeout=30 androidboot.selinux=permissive
# Per-device: androidboot.boot_devices=..., androidboot.hardware=...

# Image Configuration
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 0x04000000
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4

# Enable Treble
PRODUCT_FULL_TREBLE := true
BOARD_VNDK_VERSION := current

# Mesa DRM hwcomposer (Adreno 509 -> freedreno a5xx; no Vulkan expected)
BOARD_USES_DRM_HWCOMPOSER := true
BOARD_GPU_DRIVERS := freedreno
TARGET_USES_HWC2 := true

# WiFi (WCN3990 via ath10k/nl80211)
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_WLAN_DEVICE := qcwcn
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)

# BT
BOARD_HAVE_BLUETOOTH := true

# TinyHAL
BOARD_USES_TINYHAL_AUDIO := true

BOARD_SEPOLICY_DIRS += \
    device/generic/sdm660/shared/sepolicy \
    system/bt/vendor_libs/linux/sepolicy

DEVICE_MANIFEST_FILE := device/generic/sdm660/shared/manifest.xml
DEVICE_MATRIX_FILE := device/generic/sdm660/shared/compatibility_matrix.xml

# Enable dex pre-opt to speed up initial boot
ifeq ($(HOST_OS),linux)
  ifeq ($(WITH_DEXPREOPT),)
    WITH_DEXPREOPT := true
    WITH_DEXPREOPT_PIC := true
  endif
endif
