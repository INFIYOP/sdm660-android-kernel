ifndef TARGET_KERNEL_USE
TARGET_KERNEL_USE := mainline
endif

# Explicit module list for this device (see whyred/modules.all). All modules go to /vendor/lib/modules:
# the full set is far too large (~170 MB uncompressed) for the 64 MB boot/ramdisk partition.
PREBUILT_KMOD_DIR := device/generic/sdm660/shared/prebuilt-kernel/android-$(TARGET_KERNEL_USE)/modules
KERNEL_MODS := $(addprefix $(PREBUILT_KMOD_DIR)/,$(addsuffix .ko,$(shell cat device/generic/sdm660/whyred/modules.all)))
BOARD_VENDOR_KERNEL_MODULES := $(KERNEL_MODS)
BOARD_GENERIC_RAMDISK_KERNEL_MODULES :=

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, device/generic/sdm660/whyred/device.mk)
$(call inherit-product, device/generic/sdm660/shared/device.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

PRODUCT_NAME := whyred
PRODUCT_DEVICE := whyred
PRODUCT_BRAND := AOSP
PRODUCT_MODEL := Redmi Note 5 Pro
PRODUCT_MANUFACTURER := Xiaomi
