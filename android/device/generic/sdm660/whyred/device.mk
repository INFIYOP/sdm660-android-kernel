PRODUCT_COPY_FILES := \
    $(LOCAL_PATH)/fstab.ramdisk:$(TARGET_COPY_OUT_RAMDISK)/fstab.whyred \
    $(LOCAL_PATH)/fstab.ramdisk:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.whyred \
    $(LOCAL_PATH)/init.modules.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.modules.rc \
    device/generic/sdm660/shared/etc/audio.sdm660.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio.whyred.xml \
    device/generic/sdm660/shared/init.sdm660.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.whyred.rc \
    device/generic/sdm660/shared/init.sdm660.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.whyred.usb.rc \
    device/generic/sdm660/shared/key_layout.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/whyred.kl

# Build generic Audio HAL
PRODUCT_PACKAGES := audio.primary.whyred

# Build generic lights HAL
PRODUCT_PACKAGES += lights.whyred

# Firmware staged from YOUR stock images by scripts/stage-firmware.sh (not redistributed)
$(call inherit-product-if-exists, device/generic/sdm660/whyred/firmware/device.mk)
